"""Static file HTTP server for mt-http-server, with optional HTTP Basic
Auth and an optional in-process idle-timeout auto-shutdown.

All settings are read from environment variables rather than argv, so
credentials never show up in `ps` output for other local users to see:
  MT_SERVE_PORT          - port to listen on (defaults to 8000)
  MT_SERVE_USER           - Basic Auth username (auth disabled unless this
  MT_SERVE_PASSWORD        and MT_SERVE_PASSWORD are both set)
  MT_SERVE_IDLE_TIMEOUT   - seconds of inactivity before shutting down
                             (auto-shutdown disabled if unset or 0)

Serves the current working directory, matching `python3 -m http.server`'s
own default. Writes its own PID to ~/.bash.d/data/cache/.mt_http_server.pid
on startup so `mt-http-server --stop` can target the real server process
directly, rather than whatever wrapper launched it.

Basic Auth sends credentials base64-encoded, not encrypted -- this keeps
casual LAN users out, it is not a substitute for TLS if the server is
ever reachable from an untrusted network.
"""

import base64
import hmac
import http.server
import os
import sys
import threading
import time

PID_FILE = os.path.expanduser("~/.bash.d/data/cache/.mt_http_server.pid")
IDLE_CHECK_INTERVAL_SEC = 10

_last_activity = time.monotonic()
_last_activity_lock = threading.Lock()


def _touch_activity():
    global _last_activity
    with _last_activity_lock:
        _last_activity = time.monotonic()


def _idle_seconds():
    with _last_activity_lock:
        return time.monotonic() - _last_activity


def build_handler(expected_header):
    class Handler(http.server.SimpleHTTPRequestHandler):
        def _authenticated(self):
            if expected_header is None:
                return True
            provided = self.headers.get("Authorization", "")
            return hmac.compare_digest(provided, expected_header)

        def _require_auth(self):
            self.send_response(401)
            self.send_header("WWW-Authenticate", 'Basic realm="mt-http-server"')
            self.send_header("Content-type", "text/plain")
            self.end_headers()
            self.wfile.write(b"Authentication required.")

        def do_GET(self):
            _touch_activity()
            if self._authenticated():
                super().do_GET()
            else:
                self._require_auth()

        def do_HEAD(self):
            _touch_activity()
            if self._authenticated():
                super().do_HEAD()
            else:
                self._require_auth()

        def log_message(self, fmt, *args):
            sys.stderr.write(f"{self.client_address[0]} - {fmt % args}\n")

    return Handler


def _watch_idle(httpd, idle_timeout):
    while True:
        time.sleep(IDLE_CHECK_INTERVAL_SEC)
        if _idle_seconds() >= idle_timeout:
            sys.stderr.write(f"No activity for {idle_timeout}s -- shutting down.\n")
            httpd.shutdown()
            return


def main():
    port = int(os.environ.get("MT_SERVE_PORT", "8000"))
    username = os.environ.get("MT_SERVE_USER", "")
    password = os.environ.get("MT_SERVE_PASSWORD", "")
    idle_timeout = int(os.environ.get("MT_SERVE_IDLE_TIMEOUT", "0") or "0")

    expected_header = None
    if username and password:
        token = base64.b64encode(f"{username}:{password}".encode()).decode()
        expected_header = f"Basic {token}"

    os.makedirs(os.path.dirname(PID_FILE), exist_ok=True)
    with open(PID_FILE, "w", encoding="utf-8") as f:
        f.write(str(os.getpid()))

    handler = build_handler(expected_header)
    with http.server.ThreadingHTTPServer(("", port), handler) as httpd:
        if idle_timeout > 0:
            watcher = threading.Thread(
                target=_watch_idle, args=(httpd, idle_timeout), daemon=True
            )
            watcher.start()
        httpd.serve_forever()


if __name__ == "__main__":
    main()
