#!/usr/bin/env python3
"""
Direct TCP client for the Blender MCP addon (ahujasid/blender-mcp).

The addon runs inside Blender and listens on localhost:9876 by default.
It speaks plain UTF-8 JSON over TCP:

    Send:    {"type": "<command>", "params": {...}}
    Receive: {"status": "success", "result": ...}
             {"status": "error", "message": "..."}

This script can be used as a CLI or imported as a module so Kimi (or any
agent without a native MCP client) can control a live Blender instance.
"""

import argparse
import json
import socket
import sys
import time
from typing import Any

DEFAULT_HOST = "127.0.0.1"
DEFAULT_PORT = 9876
DEFAULT_TIMEOUT = 30


class BlenderMCPError(Exception):
    """Raised when Blender reports an error or the connection fails."""

    pass


class BlenderMCPClient:
    """Low-level JSON-over-TCP client for the Blender MCP addon."""

    def __init__(self, host: str = DEFAULT_HOST, port: int = DEFAULT_PORT, timeout: float = DEFAULT_TIMEOUT):
        self.host = host
        self.port = port
        self.timeout = timeout
        self._socket: socket.socket | None = None

    def _connect(self) -> socket.socket:
        if self._socket is not None:
            return self._socket
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.settimeout(self.timeout)
        try:
            s.connect((self.host, self.port))
        except Exception as exc:
            s.close()
            raise BlenderMCPError(
                f"Could not connect to Blender MCP at {self.host}:{self.port}. "
                f"Make sure Blender is open and the Blender MCP addon server is started."
            ) from exc
        self._socket = s
        return s

    def send(self, command: str, params: dict | None = None) -> Any:
        """Send a command and return the parsed result."""
        params = params or {}
        payload = json.dumps({"type": command, "params": params}, ensure_ascii=False)
        sock = self._connect()
        sock.sendall(payload.encode("utf-8"))

        buffer = b""
        deadline = time.time() + self.timeout
        while True:
            remaining = deadline - time.time()
            if remaining <= 0:
                raise BlenderMCPError(f"Timeout waiting for response to '{command}'")
            sock.settimeout(remaining)
            try:
                chunk = sock.recv(8192)
            except socket.timeout as exc:
                raise BlenderMCPError(f"Timeout waiting for response to '{command}'") from exc
            if not chunk:
                raise BlenderMCPError("Blender closed the connection before returning a response")
            buffer += chunk
            try:
                response = json.loads(buffer.decode("utf-8"))
                break
            except json.JSONDecodeError:
                continue

        if response.get("status") == "error":
            raise BlenderMCPError(response.get("message", "Unknown Blender error"))
        return response.get("result")

    def close(self) -> None:
        if self._socket:
            try:
                self._socket.close()
            except Exception:
                pass
            self._socket = None

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        self.close()

    # ------------------------------------------------------------------
    # Built-in helpers matching the addon's handler commands
    # ------------------------------------------------------------------

    def get_scene_info(self) -> dict:
        return self.send("get_scene_info")

    def get_object_info(self, name: str) -> dict:
        return self.send("get_object_info", {"name": name})

    def execute_code(self, code: str) -> dict:
        return self.send("execute_code", {"code": code})

    def get_viewport_screenshot(self, filepath: str, max_size: int = 800, format: str = "png") -> dict:
        return self.send("get_viewport_screenshot", {"filepath": filepath, "max_size": max_size, "format": format})

    def get_polyhaven_status(self) -> dict:
        return self.send("get_polyhaven_status")

    def get_hyper3d_status(self) -> dict:
        return self.send("get_hyper3d_status")

    def get_sketchfab_status(self) -> dict:
        return self.send("get_sketchfab_status")

    def get_hunyuan3d_status(self) -> dict:
        return self.send("get_hunyuan3d_status")


def _print_json(obj: Any) -> None:
    print(json.dumps(obj, indent=2, ensure_ascii=False))


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Send commands to Blender via the Blender MCP addon")
    parser.add_argument("--host", default=DEFAULT_HOST, help="Blender MCP host")
    parser.add_argument("--port", type=int, default=DEFAULT_PORT, help="Blender MCP port")
    parser.add_argument("--timeout", type=float, default=DEFAULT_TIMEOUT, help="Response timeout in seconds")

    sub = parser.add_subparsers(dest="command", required=True)

    sub.add_parser("scene", help="Get scene info")
    sub.add_parser("status", help="Get integration status for PolyHaven, Hyper3D, Sketchfab, Hunyuan3D")

    obj = sub.add_parser("object", help="Get info about a specific object")
    obj.add_argument("name", help="Object name")

    code = sub.add_parser("code", help="Execute arbitrary Python code in Blender")
    code.add_argument("code", help="Python code to execute (use - to read from stdin)")

    shot = sub.add_parser("screenshot", help="Capture the active 3D viewport")
    shot.add_argument("filepath", help="Where to save the image")
    shot.add_argument("--max-size", type=int, default=800)
    shot.add_argument("--format", default="png")

    raw = sub.add_parser("raw", help="Send a raw JSON command")
    raw.add_argument("type", help="Command type")
    raw.add_argument("--params", default="{}", help="JSON object of parameters")

    args = parser.parse_args(argv)

    try:
        client = BlenderMCPClient(host=args.host, port=args.port, timeout=args.timeout)

        if args.command == "scene":
            _print_json(client.get_scene_info())
        elif args.command == "status":
            _print_json({
                "polyhaven": client.get_polyhaven_status(),
                "hyper3d": client.get_hyper3d_status(),
                "sketchfab": client.get_sketchfab_status(),
                "hunyuan3d": client.get_hunyuan3d_status(),
            })
        elif args.command == "object":
            _print_json(client.get_object_info(args.name))
        elif args.command == "code":
            code_text = args.code
            if code_text == "-":
                code_text = sys.stdin.read()
            _print_json(client.execute_code(code_text))
        elif args.command == "screenshot":
            _print_json(client.get_viewport_screenshot(args.filepath, max_size=args.max_size, format=args.format))
        elif args.command == "raw":
            params = json.loads(args.params)
            _print_json(client.send(args.type, params))

        client.close()
        return 0
    except BlenderMCPError as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return 1
    except json.JSONDecodeError as exc:
        print(f"Error: invalid JSON - {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
