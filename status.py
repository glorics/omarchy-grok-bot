#!/usr/bin/env python3
"""Local status for the unofficial Grok Bot Linux client.

Prints one JSON object on stdout. Never talks to GitHub unless --fetch is
passed, in which case it asks the grok-bot launcher to refresh its cache.
The Omarchy plugin polls this helper; keep it cheap.
"""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

REPO = os.environ.get("GROKBOT_REPO", "glorics/grok-bot-linux")
HOME = Path.home()
STATE_DIR = Path(os.environ.get("GROKBOT_STATE", str(HOME / ".grokbot")))
STATE_FILE = STATE_DIR / "installed"
CACHE_FILE = STATE_DIR / "latest-release.json"
APPIMAGE = Path(
    os.environ.get(
        "GROKBOT_APPIMAGE", str(HOME / "Applications" / "GrokBot-current.AppImage")
    )
)
MARKER_FILE = HOME / ".config" / "Grok Bot" / "sand-session-marker.json"
GITHUB_URL = f"https://github.com/{REPO}"
RELEASES_URL = f"{GITHUB_URL}/releases"
STALE_AFTER_MS = 45_000


def read_kv(path: Path) -> dict[str, str]:
    out: dict[str, str] = {}
    try:
        text = path.read_text(encoding="utf-8")
    except OSError:
        return out
    for line in text.splitlines():
        if "=" not in line:
            continue
        key, value = line.split("=", 1)
        out[key.strip()] = value.strip()
    return out


def read_json(path: Path) -> dict:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return {}


def version_tuple(value: str) -> tuple[int, ...]:
    text = str(value or "").strip().lstrip("vV")
    parts: list[int] = []
    for piece in text.replace("-", ".").split("."):
        if piece.isdigit():
            parts.append(int(piece))
        else:
            break
    return tuple(parts)


def version_newer(latest: str, installed: str) -> bool:
    left = version_tuple(latest)
    right = version_tuple(installed)
    if not left or not right:
        return False
    n = max(len(left), len(right))
    left += (0,) * (n - len(left))
    right += (0,) * (n - len(right))
    return left > right


def strip_v(value: str) -> str:
    text = str(value or "").strip()
    if text.lower().startswith("v") and len(text) > 1 and text[1].isdigit():
        return text[1:]
    return text


def pid_alive(pid: int) -> bool:
    if pid <= 0:
        return False
    return Path(f"/proc/{pid}").exists()


def which_grok_bot() -> str:
    found = shutil.which("grok-bot")
    return found or ""


def package_version() -> str:
    try:
        proc = subprocess.run(
            ["pacman", "-Q", "grok-bot"],
            check=False,
            capture_output=True,
            text=True,
            timeout=2,
        )
    except (OSError, subprocess.TimeoutExpired):
        return ""
    if proc.returncode != 0:
        return ""
    parts = proc.stdout.strip().split()
    if len(parts) < 2:
        return ""
    return parts[1].split("-", 1)[0]


def hypr_window() -> dict:
    try:
        proc = subprocess.run(
            ["hyprctl", "clients", "-j"],
            check=False,
            capture_output=True,
            text=True,
            timeout=2,
        )
    except (OSError, subprocess.TimeoutExpired):
        return {}
    if proc.returncode != 0 or not proc.stdout.strip():
        return {}
    try:
        clients = json.loads(proc.stdout)
    except json.JSONDecodeError:
        return {}
    for client in clients or []:
        klass = str(client.get("class") or "")
        title = str(client.get("title") or "")
        blob = f"{klass} {title}".lower()
        if "grok-bot" in blob or klass.lower() == "sand" or "grok bot" in blob:
            return {
                "class": klass,
                "title": title,
                "pid": int(client.get("pid") or 0),
            }
    return {}


def fetch_cache() -> None:
    launcher = which_grok_bot()
    if not launcher:
        return
    try:
        subprocess.run(
            [launcher, "--check"],
            check=False,
            capture_output=True,
            text=True,
            timeout=20,
        )
    except (OSError, subprocess.TimeoutExpired):
        return


def appimage_present() -> bool:
    if APPIMAGE.is_symlink() or APPIMAGE.is_file():
        return APPIMAGE.exists()
    return False


def status() -> dict:
    state = read_kv(STATE_FILE)
    marker = read_json(MARKER_FILE)
    cache = read_json(CACHE_FILE)
    window = hypr_window()
    launcher = which_grok_bot()
    pkg = package_version()
    installed_version = strip_v(state.get("tag") or "")
    app_version = strip_v(str(marker.get("appVersion") or ""))
    latest = strip_v(str(cache.get("tag_name") or ""))

    source = "none"
    source_label = "Not installed"
    if appimage_present() or (launcher.endswith("/.local/bin/grok-bot") and state):
        source = "appimage"
        source_label = "AppImage"
        if not installed_version:
            installed_version = app_version
    elif pkg:
        source = "package"
        source_label = "Omarchy package"
        if not installed_version:
            installed_version = pkg
    elif launcher:
        source = "path"
        source_label = "grok-bot on PATH"

    installed = source != "none"

    pid = int(marker.get("pid") or 0)
    if pid <= 0 and window.get("pid"):
        pid = int(window["pid"])
    running_proc = pid_alive(pid)
    running_window = bool(window)
    running = running_proc or running_window

    alive_at = int(marker.get("aliveAtMs") or 0)
    now_ms = int(__import__("time").time() * 1000)
    stale_ms = max(0, now_ms - alive_at) if alive_at else 0
    crash_seen = bool(marker.get("crashSeen"))
    crashed = (not running) and (crash_seen or (alive_at > 0 and stale_ms > STALE_AFTER_MS and pid > 0))

    if source == "appimage":
        launch = "uwsm-app -- grok-bot" if launcher else f"uwsm-app -- {APPIMAGE} --no-sandbox --class=grok-bot --ozone-platform-hint=auto"
        focus = "grok-bot"
        can_update = bool(launcher)
    elif source == "package":
        launch = "uwsm-app -- grok-bot"
        focus = window.get("class") or "sand"
        can_update = False
    elif source == "path":
        launch = f"uwsm-app -- {launcher}"
        focus = window.get("class") or "grok-bot"
        can_update = False
    else:
        launch = ""
        focus = "grok-bot"
        can_update = False

    if window.get("class"):
        focus = str(window["class"])

    update_available = False
    if latest and installed_version:
        update_available = version_newer(latest, installed_version)
    elif latest and source == "package" and pkg:
        update_available = version_newer(latest, pkg)

    if not installed:
        status_text = "Not installed"
    elif crashed:
        status_text = "Crashed"
    elif running:
        status_text = "Running"
    elif update_available:
        status_text = "Update available"
    else:
        status_text = "Idle"

    version = app_version or installed_version or pkg

    return {
        "ok": True,
        "installed": installed,
        "source": source,
        "sourceLabel": source_label,
        "running": running,
        "crashed": crashed,
        "pid": pid if running else 0,
        "windowClass": window.get("class") or focus,
        "windowTitle": window.get("title") or "",
        "installedVersion": installed_version or pkg,
        "appVersion": version,
        "latestVersion": latest,
        "updateAvailable": update_available,
        "canSelfUpdate": can_update,
        "launcher": launcher,
        "appImage": str(APPIMAGE) if appimage_present() else "",
        "launchCommand": launch,
        "focusPattern": focus,
        "repo": REPO,
        "githubUrl": GITHUB_URL,
        "releasesUrl": RELEASES_URL,
        "statusText": status_text,
        "staleSeconds": int(stale_ms / 1000) if stale_ms else 0,
        "packageVersion": pkg,
    }


def main() -> int:
    fetch = "--fetch" in sys.argv[1:]
    if fetch:
        fetch_cache()
    print(json.dumps(status(), ensure_ascii=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
