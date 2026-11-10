"""The threaded WebDAV/S3 fixture must answer listings while Kopia renames its own blobs."""

import base64
import http.client
import importlib.util
import socket
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
        self.assertTrue(reply.startswith(b"HTTP/1.0 404"), reply)


if __name__ == "__main__":
    unittest.main()
