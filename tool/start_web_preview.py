#!/usr/bin/env python3
import os
import re
import subprocess
import time
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CLOUDFLARED = ROOT.parent / "tools/cloudflared"
SERVER_PID = Path("/tmp/opencode/energia-web-server.pid")
TUNNEL_PID = Path("/tmp/opencode/energia-web-tunnel.pid")
LOG_PATH = Path("/tmp/opencode/energia-web-tunnel.log")
URL_PATH = Path("/tmp/opencode/energia-web-tunnel.url")


def alive(path):
    if not path.exists():
        return False
    try:
        os.kill(int(path.read_text().strip()), 0)
        return True
    except (ProcessLookupError, ValueError):
        path.unlink(missing_ok=True)
        return False


def main():
    if alive(TUNNEL_PID) and URL_PATH.exists():
        print(URL_PATH.read_text().strip())
        return
    if not alive(SERVER_PID):
        server_log = open("/tmp/opencode/energia-web-server.log", "ab", buffering=0)
        server = subprocess.Popen(
            [
                "python",
                "-m",
                "http.server",
                "8081",
                "--bind",
                "127.0.0.1",
                "--directory",
                str(ROOT / "build/web"),
            ],
            stdin=subprocess.DEVNULL,
            stdout=server_log,
            stderr=subprocess.STDOUT,
            start_new_session=True,
        )
        SERVER_PID.write_text(str(server.pid))
    LOG_PATH.write_text("")
    with LOG_PATH.open("ab", buffering=0) as log:
        tunnel = subprocess.Popen(
            [
                str(CLOUDFLARED),
                "tunnel",
                "--url",
                "http://127.0.0.1:8081",
                "--no-autoupdate",
            ],
            stdin=subprocess.DEVNULL,
            stdout=log,
            stderr=subprocess.STDOUT,
            start_new_session=True,
        )
    TUNNEL_PID.write_text(str(tunnel.pid))
    pattern = re.compile(r"https://[a-z0-9-]+\.trycloudflare\.com")
    deadline = time.monotonic() + 30
    while time.monotonic() < deadline:
        match = pattern.search(LOG_PATH.read_text(errors="replace"))
        if match:
            URL_PATH.write_text(match.group(0))
            print(match.group(0))
            return
        if tunnel.poll() is not None:
            raise SystemExit(f"Web tunnel stopped; see {LOG_PATH}")
        time.sleep(0.25)
    tunnel.terminate()
    raise SystemExit(f"Timed out waiting for web tunnel; see {LOG_PATH}")


if __name__ == "__main__":
    main()
