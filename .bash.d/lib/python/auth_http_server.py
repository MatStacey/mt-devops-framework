"""Static file HTTP server gated by HTTP Basic Auth, for mt-serve -a.

Credentials and port are read from the MT_SERVE_USER / MT_SERVE_PASSWORD /
MT_SERVE_PORT environment variables rather than argv, so they never show
up in `ps` output for other local users to see. Serves the current
working directory, matching `python3 -m http.server`'s own default.

Basic Auth sends credentials base64-encoded, not encrypted -- this keeps
casual LAN users out, it is not a substitute for TLS if the server is
ever reachable from an untrusted network.
"""

import base64
import hmac
import http.server
import os
import sys


def build_handler(expected_header):
    class AuthHandler(http.server.SimpleHTTPRequestHandler):
        def _authenticated(self):
            provided = self.headers.get("Authorization", "")
            return hmac.compare_digest(provided, expected_header)

        def _require_auth(self):
            self.send_response(401)
            self.send_header("WWW-Authenticate", 'Basic realm="mt-serve"')
            self.send_header("Content-type", "text/plain")
            self.end_headers()
            self.wfile.write(b"Authentication required.")

        def do_GET(self):
            if self._authenticated():
                super().do_GET()
            else:
                self._require_auth()

        def do_HEAD(self):
            if self._authenticated():
                super().do_HEAD()
            else:
                self._require_auth()

        def log_message(self, fmt, *args):
            sys.stderr.write(f"{self.client_address[0]} - {fmt % args}\n")

    return AuthHandler


def main():
    port = int(os.environ.get("MT_SERVE_PORT", "8000"))
    username = os.environ.get("MT_SERVE_USER", "")
    password = os.environ.get("MT_SERVE_PASSWORD", "")

    if not username or not password:
        sys.stderr.write("MT_SERVE_USER and MT_SERVE_PASSWORD must be set.\n")
        sys.exit(1)

    token = base64.b64encode(f"{username}:{password}".encode()).decode()
    handler = build_handler(f"Basic {token}")

    with http.server.ThreadingHTTPServer(("", port), handler) as httpd:
        httpd.serve_forever()


if __name__ == "__main__":
    main()
