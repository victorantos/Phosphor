#!/usr/bin/env python3
"""Simple HTTPS reverse proxy that forwards to the local PIR HTTP server."""
import http.server
import ssl
import urllib.request
import sys
import os

UPSTREAM = "http://127.0.0.1:8080"
LISTEN_PORT = 8443
CERT_DIR = os.path.join(os.path.dirname(__file__), "certs")

class ProxyHandler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        self._proxy("GET")

    def do_POST(self):
        self._proxy("POST")

    def _proxy(self, method):
        url = UPSTREAM + self.path
        body = None
        if method == "POST":
            length = int(self.headers.get("Content-Length", 0))
            body = self.rfile.read(length) if length > 0 else None

        req = urllib.request.Request(url, data=body, method=method)
        # Forward relevant headers
        for header in ["Content-Type", "Accept", "Authorization"]:
            val = self.headers.get(header)
            if val:
                req.add_header(header, val)

        try:
            with urllib.request.urlopen(req) as resp:
                status = resp.status
                data = resp.read()
                self.send_response(status)
                for key, val in resp.getheaders():
                    if key.lower() not in ("transfer-encoding", "connection"):
                        self.send_header(key, val)
                self.end_headers()
                self.wfile.write(data)
        except urllib.error.HTTPError as e:
            self.send_response(e.code)
            self.end_headers()
            self.wfile.write(e.read())
        except Exception as e:
            self.send_response(502)
            self.end_headers()
            self.wfile.write(f"Proxy error: {e}".encode())

    def log_message(self, format, *args):
        print(f"[HTTPS Proxy] {args[0]}")

if __name__ == "__main__":
    server = http.server.HTTPServer(("0.0.0.0", LISTEN_PORT), ProxyHandler)
    ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    ctx.load_cert_chain(
        os.path.join(CERT_DIR, "cert.pem"),
        os.path.join(CERT_DIR, "key.pem"),
    )
    server.socket = ctx.wrap_socket(server.socket, server_side=True)
    print(f"HTTPS proxy listening on https://0.0.0.0:{LISTEN_PORT} -> {UPSTREAM}")
    server.serve_forever()
