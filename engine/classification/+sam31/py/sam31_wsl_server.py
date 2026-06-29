from __future__ import annotations

import argparse
import contextlib
import io
import json
import socketserver
import sys
import traceback
from pathlib import Path

import classify_sam31


class Sam31RequestHandler(socketserver.StreamRequestHandler):
    def handle(self) -> None:
        raw = self.rfile.readline()
        if not raw:
            return
        try:
            request = json.loads(raw.decode("utf-8"))
            command = str(request.get("command", "run"))
            if command == "shutdown":
                self.server.should_stop = True
                self._write({"status": 0, "output": "[SAM31 WSL server] shutdown requested\n"})
                return
            if command != "run":
                raise ValueError(f"Unknown command: {command}")
            config_path = request.get("config")
            if not config_path:
                raise ValueError("Missing config path")
            output = io.StringIO()
            with contextlib.redirect_stdout(output), contextlib.redirect_stderr(output):
                classify_sam31.run(config_path)
            self._write({"status": 0, "output": output.getvalue()})
        except BaseException as exc:  # noqa: BLE001 - propagate error details to MATLAB.
            self._write(
                {
                    "status": 1,
                    "output": f"{traceback.format_exc()}\n{exc}",
                }
            )

    def _write(self, payload: dict) -> None:
        self.wfile.write((json.dumps(payload) + "\n").encode("utf-8"))
        self.wfile.flush()


class Sam31Server(socketserver.TCPServer):
    allow_reuse_address = True

    def __init__(self, server_address, RequestHandlerClass):
        super().__init__(server_address, RequestHandlerClass)
        self.should_stop = False


def main() -> None:
    parser = argparse.ArgumentParser(description="Persistent DetecDiv SAM31 WSL server.")
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=0)
    parser.add_argument("--ready-file", type=Path, required=True)
    args = parser.parse_args()

    with Sam31Server((args.host, args.port), Sam31RequestHandler) as server:
        host, port = server.server_address
        args.ready_file.parent.mkdir(parents=True, exist_ok=True)
        args.ready_file.write_text(
            json.dumps({"host": host, "port": int(port), "pid": None}),
            encoding="utf-8",
        )
        print(f"[SAM31 WSL server] listening on {host}:{port}", flush=True)
        while not server.should_stop:
            server.handle_request()


if __name__ == "__main__":
    sys.exit(main())
