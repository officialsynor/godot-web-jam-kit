#!/usr/bin/env python3
"""Serve a Godot web export with the headers it needs to actually run.

Godot's threaded web build wants SharedArrayBuffer, and browsers only expose
that on a cross-origin-isolated page. So:

  * Opening index.html from the filesystem never works (file:// has no headers).
  * A plain `python -m http.server` also fails, and fails confusingly.

This script sends the two isolation headers plus the correct wasm MIME type.

    python tools/serve.py build/web 8080

Then open http://127.0.0.1:8080/
"""

from __future__ import annotations

import functools
import sys
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer


class GodotHandler(SimpleHTTPRequestHandler):
    def end_headers(self) -> None:
        # Cross-origin isolation is what unlocks SharedArrayBuffer.
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        # Always test what you just built, never a cached copy.
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def log_message(self, fmt: str, *args) -> None:
        sys.stderr.write("%s %s\n" % (self.address_string(), fmt % args))


# guess_type() reads this at response time, so it must be set before serving.
# Without it, .wasm is served as text/plain and the browser refuses to compile it.
GodotHandler.extensions_map = {
    **SimpleHTTPRequestHandler.extensions_map,
    ".wasm": "application/wasm",
    ".pck": "application/octet-stream",
}


def main() -> int:
    directory = sys.argv[1] if len(sys.argv) > 1 else "build/web"
    port = int(sys.argv[2]) if len(sys.argv) > 2 else 8080

    handler = functools.partial(GodotHandler, directory=directory)
    ThreadingHTTPServer.allow_reuse_address = True

    with ThreadingHTTPServer(("127.0.0.1", port), handler) as httpd:
        print(f"Serving {directory!r} at http://127.0.0.1:{port}/  (Ctrl+C to stop)")
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\nStopped.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
