#!/usr/bin/env python3
"""极简自愈触发器：8766 端口，仅本机 + Nginx 反代可访问。"""
from __future__ import annotations

import os
import subprocess
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import parse_qs, urlparse

BUNDLE = os.environ.get("XIAOBAI_BUNDLE", "/opt/xiaobai-tools")
TOKEN_FILE = os.path.join(BUNDLE, "heal.token")
WATCHDOG = os.path.join(BUNDLE, "tools-watchdog.sh")
FIX = os.path.join(BUNDLE, "fix-tools-3-6.sh")
HOST = "127.0.0.1"
PORT = int(os.environ.get("HEAL_PROXY_PORT", "8766"))


def expected_token() -> str:
    if os.path.isfile(TOKEN_FILE):
        return open(TOKEN_FILE, encoding="utf-8").read().strip()
    # 与 install 脚本默认一致（仅触发修复，不含密钥）
    return "xb-heal-d847ad955f2212645dd3053b773e6418"


class Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        sys.stderr.write("[heal-proxy] " + (fmt % args) + "\n")

    def _ok(self, body: bytes, code: int = 200):
        self.send_response(code)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        parsed = urlparse(self.path)
        if parsed.path not in ("/heal", "/health"):
            self._ok(b"not found", 404)
            return
        if parsed.path == "/health":
            self._ok(b"ok")
            return
        qs = parse_qs(parsed.query)
        token = (qs.get("token") or [""])[0]
        if token != expected_token():
            self._ok(b"forbidden", 403)
            return
        if os.path.isfile(FIX):
            subprocess.Popen(["/bin/bash", FIX], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        elif os.path.isfile(WATCHDOG):
            subprocess.Popen(["/bin/bash", WATCHDOG], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        self._ok(b"heal triggered", 202)


def main():
    os.makedirs(BUNDLE, exist_ok=True)
    HTTPServer((HOST, PORT), Handler).serve_forever()


if __name__ == "__main__":
    main()
