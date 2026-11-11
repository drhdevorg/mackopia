"""The threaded WebDAV/S3 fixture must answer listings while Kopia renames its own blobs."""

import base64
import contextlib
import io
import http.client
import importlib.util
import socket
import struct
from pathlib import Path
import sys
import tempfile
import threading
import unittest

SCRIPTS = Path(__file__).parents[1]
sys.path.insert(0, str(SCRIPTS))
SPEC = importlib.util.spec_from_file_location("backends", SCRIPTS / "spike-kopia-secrets.py")
BACKENDS = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(BACKENDS)
AUTH = {"Authorization": "Basic " + base64.b64encode(b"user:secret").decode()}


class StorageFixtureConcurrencyTests(unittest.TestCase):
    def test_listing_survives_concurrent_upload_and_rename(self):
        # Kopia uploads log blobs (PUT to a temporary name, then MOVE) during every command, so a listing can
        # see a name that is gone before its metadata is read. Before the fix most of these listings dropped
        # the connection without a response, and Kopia's verify then reported a failed check.
        failures = []
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / "storage"
            root.mkdir()
            with BACKENDS.storage_server(root, "user", "secret", "access", "token", "key") as (port, _):
                setup = http.client.HTTPConnection("127.0.0.1", port, timeout=10)
                setup.request("MKCOL", "/blobs/", headers=AUTH)
                setup.getresponse().read()
                setup.close()

                def write():
                    connection = http.client.HTTPConnection("127.0.0.1", port, timeout=10)
                    for index in range(400):
                        connection.request("PUT", f"/blobs/tmp{index}", body=b"x" * 64, headers=AUTH)
                        connection.getresponse().read()
                        destination = {"Destination": f"http://127.0.0.1:{port}/blobs/blob{index % 4}"}
                        connection.request("MOVE", f"/blobs/tmp{index}", headers=AUTH | destination)
                        connection.getresponse().read()
                    connection.close()

                def list_blobs():
                    for _ in range(400):
                        connection = http.client.HTTPConnection("127.0.0.1", port, timeout=10)
                        try:
                            connection.request("PROPFIND", "/blobs/", headers=AUTH | {"Depth": "1"})
                            response = connection.getresponse()
                            body = response.read()
                            if response.status != 207 or b".partial-" in body:
                                failures.append(response.status)
                        except (http.client.HTTPException, OSError) as error:
                            failures.append(type(error).__name__)
                        finally:
                            connection.close()

                threads = [threading.Thread(target=write), threading.Thread(target=list_blobs)]
                for thread in threads:
                    thread.start()
                for thread in threads:
                    thread.join()
        self.assertEqual(failures, [])

    def test_answers_only_after_reading_the_request_body(self):
        # Kopia sends PROPFIND with an XML body. Answering a missing folder and closing before the body is read
        # resets the connection while the client still writes ("broken pipe" under load in CI).
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / "storage"
            root.mkdir()
            with BACKENDS.storage_server(root, "user", "secret", "access", "token", "key") as (port, _):
                body = b"<propfind/>" * 200_000
                with socket.create_connection(("127.0.0.1", port), timeout=10) as connection:
                    head = ("PROPFIND /missing/ HTTP/1.1\r\nHost: 127.0.0.1\r\nDepth: 1\r\n"
                            + AUTH["Authorization"].join(["Authorization: ", "\r\n"])
                            + "Content-Length: " + str(len(body)) + "\r\n\r\n")
                    connection.sendall(head.encode() + body)
                    reply = connection.recv(64)
        self.assertTrue(reply.startswith(b"HTTP/1.1 404"), reply)

    def test_requests_share_one_persistent_connection(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / "storage"
            root.mkdir()
            with BACKENDS.storage_server(root, "user", "secret", "access", "token", "key") as (port, _):
                connection = http.client.HTTPConnection("127.0.0.1", port, timeout=10)
                connection.request("MKCOL", "/blobs/", headers=AUTH)
                connection.getresponse().read()
                connection.request("PUT", "/blobs/one", body=b"data", headers=AUTH)
                connection.getresponse().read()
                local = connection.sock.getsockname()
                connection.request("GET", "/blobs/one", headers=AUTH)
                response = connection.getresponse()
                self.assertEqual(response.read(), b"data")
                connection.request("GET", "/missing", headers=AUTH)
                connection.getresponse().read()
                connection.request("GET", "/blobs/one", headers={})
                self.assertEqual(connection.getresponse().status, 401)
                self.assertEqual(connection.sock.getsockname(), local)
                connection.close()

    def test_chunked_request_bodies_are_consumed(self):
        # Kopia's PROPFIND body arrives chunked. Unread chunks used to become a garbage request (400 page) that
        # corrupted the next response on the same connection.
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / "storage"
            root.mkdir()
            (root / "blobs").mkdir()
            with BACKENDS.storage_server(root, "user", "secret", "access", "token", "key") as (port, _):
                connection = http.client.HTTPConnection("127.0.0.1", port, timeout=10)
                for _ in range(3):
                    connection.request(
                        "PROPFIND", "/blobs/", body=iter([b"<?xml version=\"1.0\"?>", b"<propfind/>"]),
                        headers=AUTH | {"Depth": "1"}, encode_chunked=True)
                    response = connection.getresponse()
                    self.assertEqual(response.status, 207)
                    self.assertIn(b"multistatus", response.read())
                connection.close()

    def test_client_reset_of_an_idle_connection_is_a_normal_close(self):
        captured = io.StringIO()
        with tempfile.TemporaryDirectory() as directory, contextlib.redirect_stderr(captured):
            root = Path(directory) / "storage"
            root.mkdir()
            with BACKENDS.storage_server(root, "user", "secret", "access", "token", "key") as (port, _):
                connection = http.client.HTTPConnection("127.0.0.1", port, timeout=10)
                connection.request("GET", "/missing", headers=AUTH)
                connection.getresponse().read()
                # SO_LINGER 0 closes with RST, as an exiting Kopia process does with its idle connections.
                connection.sock.setsockopt(socket.SOL_SOCKET, socket.SO_LINGER, struct.pack("ii", 1, 0))
                connection.close()
                follow_up = http.client.HTTPConnection("127.0.0.1", port, timeout=10)
                follow_up.request("GET", "/missing", headers=AUTH)
                self.assertEqual(follow_up.getresponse().status, 404)
                follow_up.close()
        self.assertNotIn("Traceback", captured.getvalue())


if __name__ == "__main__":
    unittest.main()
