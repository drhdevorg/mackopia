"""The threaded WebDAV/S3 fixture must answer listings while Kopia renames its own blobs."""

import base64
import http.client
import importlib.util
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


if __name__ == "__main__":
    unittest.main()
