from __future__ import annotations

import argparse
import json
import socket
import sys
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser(description="Client for the persistent DetecDiv SAM31 WSL server.")
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, required=True)
    parser.add_argument("--config", type=Path)
    parser.add_argument("--shutdown", action="store_true")
    parser.add_argument("--timeout", type=float, default=86400.0)
    args = parser.parse_args()

    if args.shutdown:
        request = {"command": "shutdown"}
    else:
        if args.config is None:
            raise SystemExit("--config is required unless --shutdown is used")
        request = {"command": "run", "config": str(args.config)}

    with socket.create_connection((args.host, args.port), timeout=30.0) as sock:
        sock.settimeout(args.timeout)
        payload = (json.dumps(request) + "\n").encode("utf-8")
        sock.sendall(payload)
        with sock.makefile("r", encoding="utf-8") as reader:
            for line in reader:
                if not line:
                    break
                result = json.loads(line)
                if "stream" in result:
                    print(str(result.get("stream", "")), end="", flush=True)
                    continue
                output = str(result.get("output", ""))
                if output:
                    print(output, end="" if output.endswith("\n") else "\n", flush=True)
                return int(result.get("status", 1))

    print("SAM31 WSL server returned no response.", file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main())
