"""Loopback fixture startup must never wait for external hostname resolution."""

from http.server import BaseHTTPRequestHandler
from pathlib import Path
import socket
import sys
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).parents[1]))
from loopback_http_server import LoopbackHTTPServer


class LoopbackHTTPServerTests(unittest.TestCase):
    def test_binding_never_resolves_a_hostname(self):
        with patch("socket.getfqdn", side_effect=AssertionError("unexpected DNS lookup")) as resolve:
            with LoopbackHTTPServer(("127.0.0.1", 0), BaseHTTPRequestHandler) as server:
                self.assertEqual(server.server_name, "127.0.0.1")
                self.assertGreater(server.server_port, 0)
                self.assertEqual(server.server_address, ("127.0.0.1", server.server_port))
            resolve.assert_not_called()

    def test_nonloopback_binding_is_rejected(self):
        with self.assertRaisesRegex(ValueError, "loopback"):
            LoopbackHTTPServer(("0.0.0.0", 0), BaseHTTPRequestHandler)

    def test_parallel_connections_wait_instead_of_being_reset(self):
        # Nobody accepts yet, as when the accept loop is starved on a busy runner. Each client still has to
        # finish sending its request, as Kopia does for many parallel PROPFIND listings.
        with LoopbackHTTPServer(("127.0.0.1", 0), BaseHTTPRequestHandler) as server:
            clients = []
            try:
                for _ in range(40):
                    client = socket.create_connection(("127.0.0.1", server.server_port), timeout=5)
                    clients.append(client)
                    client.sendall(b"PROPFIND / HTTP/1.1\r\nHost: 127.0.0.1\r\n\r\n" + b"x" * 200_000)
            finally:
                for client in clients:
                    client.close()
