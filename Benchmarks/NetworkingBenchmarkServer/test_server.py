import http.client
import threading
import unittest
from http.server import ThreadingHTTPServer

from server import BATCH_UPLOAD_BODY_SIZE, UPLOAD_BODY_SIZE, Handler


class BenchmarkUploadTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        cls.thread = threading.Thread(target=cls.server.serve_forever, daemon=True)
        cls.thread.start()

    @classmethod
    def tearDownClass(cls) -> None:
        cls.server.shutdown()
        cls.server.server_close()
        cls.thread.join()

    def post(self, path: str, body: bytes) -> int:
        connection = http.client.HTTPConnection(
            "127.0.0.1",
            self.server.server_port,
        )
        try:
            connection.request("POST", path, body=body)
            response = connection.getresponse()
            response.read()
            return response.status
        finally:
            connection.close()

    def test_upload_accepts_fixture_payload(self) -> None:
        body = b"\x5a" * UPLOAD_BODY_SIZE

        self.assertEqual(self.post("/upload", body), 200)

    def test_upload_rejects_same_size_corruption(self) -> None:
        body = b"\x5a" * (UPLOAD_BODY_SIZE - 1) + b"X"

        self.assertEqual(self.post("/upload", body), 400)

    def test_batch_upload_accepts_fixture_payload(self) -> None:
        body = b"\x5a" * BATCH_UPLOAD_BODY_SIZE

        self.assertEqual(self.post("/batch-upload", body), 200)

    def test_batch_upload_rejects_same_size_corruption(self) -> None:
        body = b"\x5a" * (BATCH_UPLOAD_BODY_SIZE - 1) + b"X"

        self.assertEqual(self.post("/batch-upload", body), 400)


if __name__ == "__main__":
    unittest.main()
