#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Start_Pro_Scanner.py

One launcher for the two workspace servers:

  1. Propack VP
     - Flask web/API server on http://localhost:8001
     - Legacy TCP socket on localhost:12345

  2. Folder Scanner
     - FastAPI backend on an internal loopback port
     - React build served inside Propack at http://localhost:8001/scanner/

Usage:
    python Start_Pro_Scanner.py
    python Start_Pro_Scanner.py --propack-only
    python Start_Pro_Scanner.py --scanner-only
    python Start_Pro_Scanner.py --scanner-backend-only
"""

from __future__ import annotations

import argparse
import atexit
import os
import signal
import shutil
import subprocess
import sys
import threading
import time
from pathlib import Path


ROOT_DIR = Path(__file__).resolve().parent
PROPACK_DIR = ROOT_DIR / "propack" / "propack"
SCANNER_DIR = ROOT_DIR / "folderscaner"
SCANNER_BACKEND_DIR = SCANNER_DIR / "backend"
SCANNER_FRONTEND_DIR = SCANNER_DIR / "frontend"
SCANNER_INTERNAL_HOST = "127.0.0.1"
SCANNER_INTERNAL_PORT = "18001"

LOG_DIR = ROOT_DIR / "logs" / "Start_Pro_Scanner"
LOG_DIR.mkdir(parents=True, exist_ok=True)

PROPACK_LOG = LOG_DIR / "propack.log"
SCANNER_BACKEND_LOG = LOG_DIR / "scanner_backend.log"
SCANNER_FRONTEND_LOG = LOG_DIR / "scanner_frontend.log"

processes: list[tuple[str, subprocess.Popen]] = []
lock = threading.Lock()
shutting_down = False


def log(message: str) -> None:
    print(f"[Start_Pro_Scanner] {message}", flush=True)


def ensure_path(path: Path, label: str) -> None:
    if not path.exists():
        raise FileNotFoundError(f"{label} not found: {path}")


def child_process_options() -> dict:
    if sys.platform == "win32":
        return {"creationflags": subprocess.CREATE_NEW_PROCESS_GROUP}
    return {"start_new_session": True}


def open_log(path: Path):
    return path.open("w", encoding="utf-8")


def add_process(name: str, proc: subprocess.Popen) -> None:
    with lock:
        processes.append((name, proc))
    threading.Thread(target=monitor_process, args=(name, proc), daemon=True).start()


def monitor_process(name: str, proc: subprocess.Popen) -> None:
    try:
        proc.wait()
    except Exception:
        return
    if not shutting_down:
        log(f"{name} exited with code {proc.returncode}")


def kill_windows_tree(pid: int) -> None:
    try:
        subprocess.run(
            ["taskkill", "/T", "/F", "/PID", str(pid)],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=False,
        )
    except Exception as exc:
        log(f"Could not kill process tree {pid}: {exc}")


def terminate_process(name: str, proc: subprocess.Popen) -> None:
    if proc.poll() is not None:
        return

    log(f"Stopping {name} (PID {proc.pid})...")
    try:
        if sys.platform == "win32":
            try:
                proc.send_signal(signal.CTRL_BREAK_EVENT)
            except Exception:
                kill_windows_tree(proc.pid)
        else:
            proc.terminate()
    except Exception:
        try:
            proc.kill()
        except Exception:
            pass

    try:
        proc.wait(timeout=8)
    except Exception:
        if sys.platform == "win32":
            kill_windows_tree(proc.pid)
        else:
            try:
                proc.kill()
            except Exception:
                pass


def stop_all() -> None:
    global shutting_down
    shutting_down = True
    with lock:
        current = list(processes)
        processes.clear()
    for name, proc in reversed(current):
        terminate_process(name, proc)


def handle_signal(signum, frame) -> None:
    log(f"Received signal {signum}; shutting down all servers...")
    stop_all()
    raise SystemExit(130)


def install_signal_handlers() -> None:
    for sig in (signal.SIGINT, signal.SIGTERM):
        try:
            signal.signal(sig, handle_signal)
        except (ValueError, OSError):
            pass


def env_with_node(base_dir: Path) -> dict[str, str]:
    env = os.environ.copy()
    node_scripts = str(base_dir / "node_env" / "Scripts")
    if Path(node_scripts).exists() and node_scripts not in env.get("PATH", ""):
        env["PATH"] = node_scripts + os.pathsep + env.get("PATH", "")
    return env


def start_propack() -> subprocess.Popen:
    ensure_path(PROPACK_DIR / "server.py", "Propack server")
    env = os.environ.copy()
    env.setdefault("PYTHONIOENCODING", "utf-8")

    log("Starting Propack VP server...")
    proc = subprocess.Popen(
        [sys.executable, "server.py"],
        cwd=str(PROPACK_DIR),
        env=env,
        stdout=open_log(PROPACK_LOG),
        stderr=subprocess.STDOUT,
        **child_process_options(),
    )
    add_process("Propack VP", proc)
    log(f"Propack VP PID {proc.pid} | http://localhost:8001 | log: {PROPACK_LOG}")
    return proc


def start_scanner_backend() -> subprocess.Popen:
    ensure_path(SCANNER_BACKEND_DIR / "app" / "main.py", "Folder Scanner backend")
    env = os.environ.copy()
    env["PYTHONPATH"] = str(SCANNER_BACKEND_DIR)
    env.setdefault("SERVER_HOST", SCANNER_INTERNAL_HOST)
    env.setdefault("SERVER_PORT", SCANNER_INTERNAL_PORT)
    env.setdefault("PYTHONIOENCODING", "utf-8")

    if not env.get("SMB_ROOT"):
        log("Warning: SMB_ROOT is not set. Scanner backend may stop until .env or env var is configured.")

    log("Starting Folder Scanner backend...")
    proc = subprocess.Popen(
        [
            sys.executable,
            "-m",
            "uvicorn",
            "app.main:app",
            "--reload",
            "--host",
            env["SERVER_HOST"],
            "--port",
            env["SERVER_PORT"],
        ],
        cwd=str(SCANNER_BACKEND_DIR),
        env=env,
        stdout=open_log(SCANNER_BACKEND_LOG),
        stderr=subprocess.STDOUT,
        **child_process_options(),
    )
    add_process("Folder Scanner backend", proc)
    log(f"Scanner backend PID {proc.pid} | http://localhost:{env['SERVER_PORT']} | log: {SCANNER_BACKEND_LOG}")
    return proc


def build_scanner_frontend() -> subprocess.Popen | None:
    dist_index = SCANNER_FRONTEND_DIR / "dist" / "index.html"
    if dist_index.exists():
        log(f"Scanner frontend build already available | http://localhost:8001/scanner/")
        return None

    ensure_path(SCANNER_FRONTEND_DIR / "package.json", "Folder Scanner frontend")
    npm = shutil.which("npm")
    if not npm:
        log("Warning: npm not found; Scanner UI will be available after running npm run build in folderscaner/frontend.")
        return None

    log("Building Folder Scanner frontend for Propack /scanner/...")
    proc = subprocess.Popen(
        [npm, "run", "build"],
        cwd=str(SCANNER_FRONTEND_DIR),
        env=env_with_node(SCANNER_DIR),
        stdout=open_log(SCANNER_FRONTEND_LOG),
        stderr=subprocess.STDOUT,
        shell=(sys.platform == "win32"),
        **child_process_options(),
    )
    proc.wait()
    if proc.returncode == 0:
        log(f"Scanner frontend built | http://localhost:8001/scanner/ | log: {SCANNER_FRONTEND_LOG}")
    else:
        log(f"Scanner frontend build failed with code {proc.returncode} | log: {SCANNER_FRONTEND_LOG}")
    return proc


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Start Propack VP and Folder Scanner servers together.")
    parser.add_argument("--propack-only", action="store_true", help="Start only Propack VP.")
    parser.add_argument("--scanner-only", action="store_true", help="Start only Folder Scanner backend + frontend.")
    parser.add_argument("--scanner-backend-only", action="store_true", help="Start only Folder Scanner backend.")
    parser.add_argument("--no-scanner-frontend", action="store_true", help="Start Scanner backend without the React/Vite frontend.")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    install_signal_handlers()

    start_propack_flag = not args.scanner_only and not args.scanner_backend_only
    start_scanner_flag = not args.propack_only
    start_scanner_frontend_flag = start_scanner_flag and not args.scanner_backend_only and not args.no_scanner_frontend

    if args.propack_only and (args.scanner_only or args.scanner_backend_only):
        raise SystemExit("--propack-only cannot be combined with scanner-only options.")

    if start_propack_flag:
        start_propack()

    if start_scanner_flag:
        start_scanner_backend()
        if start_scanner_frontend_flag:
            build_scanner_frontend()

    log("")
    log("Servers requested:")
    if start_propack_flag:
        log("  Propack VP        : http://localhost:8001")
        log("  Propack TCP       : localhost:12345")
    if start_scanner_flag:
        log(f"  Scanner backend   : internal http://{SCANNER_INTERNAL_HOST}:{SCANNER_INTERNAL_PORT}")
    if start_scanner_frontend_flag:
        log("  Scanner frontend  : http://localhost:8001/scanner/")
    log("Press Ctrl+C to stop all started servers.")

    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        log("Keyboard interrupt received; stopping...")
    finally:
        stop_all()

    return 0


atexit.register(stop_all)


if __name__ == "__main__":
    raise SystemExit(main())
