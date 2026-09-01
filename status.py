#!/usr/bin/env python3
"""Local status for the Grok Bot Linux client.

Cheap path (default): local files and Hyprland. Does not touch the network.
`--fetch` asks Cursor's update API what the current Grok Bot version is, then
looks for a Linux AppImage of that version on the Cursor CDN.
`--update` downloads that AppImage when one is newer than the install.

Does not read Grok Bot tokens, chats, or secret files.
"""

from __future__ import annotations

import json
import os
import re
import select
import shutil
import stat
import subprocess
import sys
import tempfile
import time
from pathlib import Path

PLUGIN_REPO = os.environ.get("GROKBOT_PLUGIN_REPO", "glorics/omarchy-grok-bot")
HOME = Path.home()
STATE_DIR = Path(os.environ.get("GROKBOT_STATE", str(HOME / ".grokbot")))
STATE_FILE = STATE_DIR / "installed"
LATEST_CACHE = STATE_DIR / "latest-official.json"
APPIMAGE = Path(
    os.environ.get(
        "GROKBOT_APPIMAGE", str(HOME / "Applications" / "GrokBot-current.AppImage")
    )
)
APPS = Path(os.environ.get("GROKBOT_APPS", str(HOME / "Applications")))
CONFIG_DIR = HOME / ".config" / "Grok Bot"
MARKER_FILE = CONFIG_DIR / "sand-session-marker.json"
SESSION_HINTS = (
    MARKER_FILE,
    CONFIG_DIR / "window-state.json",
    CONFIG_DIR / "gateway-descriptor.json",
)
PRODUCT_URL = "https://x.ai/bot"
PLUGIN_URL = f"https://github.com/{PLUGIN_REPO}"
DARWIN_PROBE = (
    "https://api2.cursor.sh/updates/download/stable/darwin-arm64/"
    "grok-bot-bd824e1890d8b96f"
)
LINUX_BY_VERSION = {
    "0.20.0": (
        "https://downloads.cursor.com/grokbot/stable/"
        "ca2c2b6f79b6130a4822d8189711b0f79f9d4661/linux/x64/Grok_Bot_0.20.0.AppImage"
    ),
    "0.24.0": (
        "https://downloads.cursor.com/grokbot/stable/"
        "302d75da596fc8d11ee0446a19b31c33c6676c2c/linux/x64/Grok_Bot_0.24.0.AppImage"
    ),
    "0.30.0": (
        "https://downloads.cursor.com/grokbot/stable/"
        "2385d097738b3719cc5ecd9281a107aa106215f1/linux/x64/Grok_Bot_0.30.0.AppImage"
    ),
}
OFFICIAL_APPIMAGE_URL = LINUX_BY_VERSION["0.30.0"]
STALE_AFTER_MS = 45_000
VERSION_RE = re.compile(r"Grok_Bot_(\d+\.\d+\.\d+)")
MAX_PROC_BYTES = 64 * 1024
MAX_FILE_BYTES = 64 * 1024
MAX_HYPR_BYTES = 1024 * 1024
MAX_STDOUT_BYTES = 256 * 1024
MAX_FIELD = 96


def clip(value, n: int = MAX_FIELD) -> str:
    text = str(value or "")
    return text if len(text) <= n else text[:n]


def run(cmd: list[str], timeout: int = 8, max_bytes: int = MAX_PROC_BYTES) -> subprocess.CompletedProcess:
    try:
        proc = subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            bufsize=0,
        )
    except OSError as exc:
        return subprocess.CompletedProcess(cmd, 1, "", str(exc))

    stdout = bytearray()
    stderr = bytearray()
    streams = {}
    if proc.stdout:
        streams[proc.stdout] = stdout
    if proc.stderr:
        streams[proc.stderr] = stderr
    overflow = False
    deadline = time.monotonic() + max(0.05, float(timeout))
    try:
        while streams:
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                proc.kill()
                break
            ready, _, _ = select.select(list(streams), [], [], remaining)
            if not ready:
                proc.kill()
                break
            stop = False
            for fh in ready:
                buf = streams[fh]
                try:
                    chunk = os.read(fh.fileno(), 4096)
                except OSError:
                    chunk = b""
                if not chunk:
                    try:
                        fh.close()
                    except OSError:
                        pass
                    streams.pop(fh, None)
                    continue
                room = max_bytes - len(buf)
                if room <= 0 or len(chunk) > room:
                    if room > 0:
                        buf.extend(chunk[:room])
                    overflow = True
                    proc.kill()
                    stop = True
                    break
                buf.extend(chunk)
            if stop:
                break
        try:
            proc.wait(timeout=max(0.1, deadline - time.monotonic()))
        except subprocess.TimeoutExpired:
            proc.kill()
            proc.wait(timeout=1)
    finally:
        for fh in (proc.stdout, proc.stderr):
            if fh and not fh.closed:
                try:
                    fh.close()
                except OSError:
                    pass

    code = proc.returncode if proc.returncode is not None else 1
    if overflow and code == 0:
        code = 1
    return subprocess.CompletedProcess(
        cmd,
        code,
        bytes(stdout).decode("utf-8", errors="replace"),
        bytes(stderr).decode("utf-8", errors="replace"),
    )


def emit(obj: dict) -> None:
    raw = json.dumps(obj, ensure_ascii=True)
    if len(raw.encode("utf-8")) > MAX_STDOUT_BYTES:
        raw = json.dumps({"ok": False, "error": "Output too large"}, ensure_ascii=True)
    sys.stdout.write(raw)


def ensure_private_dir(path: Path) -> bool:
    try:
        st = path.lstat()
    except FileNotFoundError:
        st = None
    except OSError:
        return False
    if st is not None:
        if stat.S_ISLNK(st.st_mode):
            try:
                path.unlink()
            except OSError:
                return False
        elif not stat.S_ISDIR(st.st_mode) or st.st_uid != os.getuid():
            return False
    if not path.exists():
        parent = path.parent
        if not parent.exists():
            try:
                parent.mkdir(parents=True, exist_ok=True)
            except OSError:
                return False
        try:
            os.mkdir(path, 0o700)
        except FileExistsError:
            pass
        except OSError:
            return False
    flags = os.O_RDONLY | os.O_DIRECTORY | getattr(os, "O_NOFOLLOW", 0)
    try:
        fd = os.open(str(path), flags)
    except OSError:
        return False
    try:
        st = os.fstat(fd)
        if not stat.S_ISDIR(st.st_mode) or st.st_uid != os.getuid():
            return False
        os.fchmod(fd, 0o700)
        return True
    finally:
        os.close(fd)


def ensure_state_dir() -> bool:
    return ensure_private_dir(STATE_DIR)


def read_bounded(path: Path, max_bytes: int) -> bytes:
    if path.is_symlink():
        return b""
    flags = os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0)
    try:
        fd = os.open(path, flags)
    except OSError:
        return b""
    try:
        st = os.fstat(fd)
        if not stat.S_ISREG(st.st_mode) or st.st_size > max_bytes:
            return b""
        data = os.read(fd, max_bytes + 1)
        if len(data) > max_bytes:
            return b""
        return data
    finally:
        os.close(fd)


def atomic_write(path: Path, text: str) -> None:
    if not ensure_state_dir():
        return
    data = text.encode("utf-8")
    if len(data) > MAX_FILE_BYTES:
        return
    try:
        if path.is_symlink() or (path.exists() and not path.is_file()):
            path.unlink()
    except OSError:
        return
    fd = -1
    tmp = ""
    try:
        fd, tmp = tempfile.mkstemp(prefix=".tmp-", dir=str(STATE_DIR))
        os.write(fd, data)
        os.fsync(fd)
        os.fchmod(fd, 0o600)
        os.close(fd)
        fd = -1
        os.replace(tmp, path)
        tmp = ""
    except OSError:
        if fd >= 0:
            try:
                os.close(fd)
            except OSError:
                pass
        if tmp:
            try:
                os.unlink(tmp)
            except OSError:
                pass


def read_kv(path: Path) -> dict[str, str]:
    out: dict[str, str] = {}
    raw = read_bounded(path, MAX_FILE_BYTES)
    if not raw:
        return out
    try:
        text = raw.decode("utf-8")
    except UnicodeError:
        return out
    for line in text.splitlines():
        if "=" not in line:
            continue
        key, value = line.split("=", 1)
        out[key.strip()] = value.strip()
    return out


def read_json(path: Path) -> dict:
    raw = read_bounded(path, MAX_FILE_BYTES)
    if not raw:
        return {}
    try:
        data = json.loads(raw.decode("utf-8"))
    except (UnicodeError, json.JSONDecodeError):
        return {}
    return data if isinstance(data, dict) else {}


def write_json(path: Path, data: dict) -> None:
    atomic_write(path, json.dumps(data, indent=2) + "\n")


def strip_v(value: str) -> str:
    text = str(value or "").strip()
    if text.lower().startswith("v") and len(text) > 1 and text[1].isdigit():
        return text[1:]
    return text


def version_tuple(value: str) -> tuple[int, ...]:
    text = strip_v(value)
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


def pid_alive(pid: int) -> bool:
    if pid <= 0:
        return False
    return Path(f"/proc/{pid}").exists()


def which_grok_bot() -> str:
    found = shutil.which("grok-bot")
    return found or ""


def package_version() -> str:
    proc = run(["pacman", "-Q", "grok-bot"], timeout=2)
    if proc.returncode != 0:
        return ""
    parts = proc.stdout.strip().split()
    if len(parts) < 2:
        return ""
    return parts[1].split("-", 1)[0]


def hypr_window() -> dict:
    proc = run(["hyprctl", "clients", "-j"], timeout=2, max_bytes=MAX_HYPR_BYTES)
    if proc.returncode != 0 or not proc.stdout.strip():
        return {}
    try:
        clients = json.loads(proc.stdout)
    except json.JSONDecodeError:
        return {}
    for client in clients or []:
        klass = str(client.get("class") or "").lower()
        title = str(client.get("title") or "")
        if klass in ("grok-bot", "sand"):
            return {
                "class": str(client.get("class") or ""),
                "title": clip(title, 80),
                "pid": int(client.get("pid") or 0),
            }
    return {}


def appimage_present() -> bool:
    if APPIMAGE.is_symlink() or APPIMAGE.is_file():
        return APPIMAGE.exists()
    return False


def curl_headers(url: str, timeout: int = 12) -> str:
    proc = run(
        [
            "curl",
            "-sI",
            "-L",
            "--max-redirs",
            "5",
            "-A",
            "Mozilla/5.0",
            "--max-time",
            str(timeout),
            url,
        ],
        timeout=timeout + 2,
    )
    return cap_text(proc.stdout or "", MAX_PROC_BYTES)


def head_ok(url: str) -> bool:
    proc = run(
        [
            "curl",
            "-sI",
            "-o",
            "/dev/null",
            "-w",
            "%{http_code}",
            "-A",
            "Mozilla/5.0",
            "--max-time",
            "10",
            url,
        ],
        timeout=12,
    )
    return proc.stdout.strip() == "200"


def linux_url_for(version: str) -> str:
    known = LINUX_BY_VERSION.get(version, "")
    if known and head_ok(known):
        return known
    return ""


def ago_text(epoch: float) -> str:
    if epoch <= 0:
        return ""
    seconds = max(0, int(time.time() - epoch))
    if seconds < 45:
        return "just now"
    minutes = seconds // 60
    if minutes < 60:
        return f"{minutes}m ago"
    hours = minutes // 60
    if hours < 48:
        return f"{hours}h ago"
    return f"{hours // 24}d ago"


def notify(summary: str, body: str) -> None:
    icon = HOME / ".local/share/pixmaps/grok-bot.png"
    cmd = [
        "notify-send",
        "-a",
        "Grok Bot",
        "-u",
        "normal",
        "-h",
        "string:x-canonical-private-synchronous:grok-bot-update",
        "-i",
        str(icon) if icon.exists() else "grok-bot",
        summary,
        body,
    ]
    run(cmd, timeout=3)


def fetch_latest() -> dict:
    headers = curl_headers(DARWIN_PROBE)
    latest = ""
    match = VERSION_RE.search(headers)
    if match:
        latest = match.group(1)
    linux = linux_url_for(latest) if latest else ""
    prev = read_json(LATEST_CACHE)
    last_notified = strip_v(str(prev.get("lastNotified") or ""))
    installed = strip_v(read_kv(STATE_FILE).get("tag") or "")
    if latest and installed and version_newer(latest, installed) and latest != last_notified:
        if linux:
            notify(
                f"Grok Bot {latest} is out",
                "Linux AppImage is on the Cursor CDN. Open the bar plugin to update.",
            )
        else:
            notify(
                f"Grok Bot {latest} is out",
                "A newer desktop build exists. No Linux AppImage on the CDN yet.",
            )
        last_notified = latest
    data = {
        "tag": latest,
        "linuxUrl": linux,
        "checkedAt": time.time(),
        "lastNotified": last_notified,
    }
    write_json(LATEST_CACHE, data)
    return data


def is_elf(path: Path) -> bool:
    try:
        with path.open("rb") as fh:
            return fh.read(4) == b"\x7fELF"
    except OSError:
        return False


def do_update() -> int:
    cache = fetch_latest()
    latest = strip_v(str(cache.get("tag") or ""))
    linux = str(cache.get("linuxUrl") or "")
    state = read_kv(STATE_FILE)
    installed = strip_v(state.get("tag") or "")
    if not latest:
        print("Could not reach Cursor's update feed", file=sys.stderr)
        return 1
    if installed and not version_newer(latest, installed):
        print(f"Up to date · {installed}")
        return 0
    if not linux:
        print(
            f"Newer Grok Bot {latest} is out, but no Linux AppImage is on the CDN yet",
            file=sys.stderr,
        )
        return 2
    APPS.mkdir(parents=True, exist_ok=True)
    name = f"Grok_Bot_{latest}.AppImage"
    dest = APPS / name
    partial = APPS / f"{name}.partial"
    try:
        proc = subprocess.run(
            [
                "curl",
                "-fL",
                "-A",
                "Mozilla/5.0",
                "--retry",
                "2",
                "--max-time",
                "300",
                "-o",
                str(partial),
                linux,
            ],
            check=False,
            timeout=320,
        )
    except (OSError, subprocess.TimeoutExpired):
        partial.unlink(missing_ok=True)
        print("Download failed", file=sys.stderr)
        return 1
    if proc.returncode != 0 or not partial.exists() or not is_elf(partial):
        partial.unlink(missing_ok=True)
        print("Download was not an AppImage", file=sys.stderr)
        return 1
    partial.chmod(0o755)
    dest.unlink(missing_ok=True)
    partial.rename(dest)
    current = APPS / "GrokBot-current.AppImage"
    if current.exists() or current.is_symlink():
        current.unlink()
    current.symlink_to(name)
    atomic_write(
        STATE_FILE,
        "\n".join(
            [
                f"tag={latest}",
                f"name={name}",
                f"path={current}",
                "source=official-cursor-cdn",
                f"url={linux}",
                "",
            ]
        )
        + "\n",
    )
    print(f"installed {latest}")
    return 0


def status() -> dict:
    state = read_kv(STATE_FILE)
    marker = read_json(MARKER_FILE)
    cache = read_json(LATEST_CACHE)
    window = hypr_window()
    launcher = which_grok_bot()
    pkg = package_version()
    installed_version = strip_v(state.get("tag") or "")
    app_version = strip_v(str(marker.get("appVersion") or ""))
    download_url = state.get("url") or OFFICIAL_APPIMAGE_URL
    state_source = state.get("source") or ""
    latest = strip_v(str(cache.get("tag") or ""))
    linux_latest = str(cache.get("linuxUrl") or "")
    checked_at = float(cache.get("checkedAt") or 0)

    source = "none"
    source_label = "Not installed"
    if appimage_present() or state_source == "official-cursor-cdn" or (
        launcher.endswith("/.local/bin/grok-bot") and state
    ):
        source = "official"
        source_label = "Linux AppImage"
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
    version = app_version or installed_version or pkg

    pid = int(marker.get("pid") or 0)
    if pid <= 0 and window.get("pid"):
        pid = int(window["pid"])
    running_proc = pid_alive(pid)
    running_window = bool(window)
    running = running_proc or running_window

    alive_at = int(marker.get("aliveAtMs") or 0)
    now_ms = int(time.time() * 1000)
    stale_ms = max(0, now_ms - alive_at) if alive_at else 0
    crash_seen = bool(marker.get("crashSeen"))
    crashed = (not running) and (
        crash_seen or (alive_at > 0 and stale_ms > STALE_AFTER_MS and pid > 0)
    )

    if source == "official":
        launch = (
            "uwsm-app -- grok-bot"
            if launcher
            else f"uwsm-app -- {APPIMAGE} --class=grok-bot --ozone-platform-hint=auto"
        )
        focus = "grok-bot"
    elif source == "package":
        launch = "uwsm-app -- grok-bot"
        focus = window.get("class") or "sand"
    elif source == "path":
        launch = f"uwsm-app -- {launcher}"
        focus = window.get("class") or "grok-bot"
    else:
        launch = ""
        focus = "grok-bot"

    if window.get("class"):
        focus = str(window["class"])

    if not installed:
        status_text = "Not installed"
    elif crashed:
        status_text = "Crashed"
    elif running:
        status_text = "Connected"
    else:
        status_text = "Window closed"

    signed_in = any(path.exists() for path in SESSION_HINTS)
    update_available = bool(latest and version and version_newer(latest, version))
    can_update = bool(update_available and linux_latest)

    return {
        "ok": True,
        "installed": installed,
        "source": source,
        "sourceLabel": source_label,
        "running": running,
        "crashed": crashed,
        "pid": pid if running else 0,
        "windowClass": window.get("class") or focus,
        "windowTitle": clip(window.get("title") or "", 80),
        "installedVersion": clip(installed_version or pkg, 32),
        "appVersion": clip(version, 32),
        "latestVersion": clip(latest, 32),
        "updateAvailable": update_available,
        "canSelfUpdate": can_update,
        "linuxUpdateUrl": linux_latest if can_update else "",
        "launcher": launcher,
        "appImage": str(APPIMAGE) if appimage_present() else "",
        "launchCommand": launch,
        "focusPattern": focus,
        "repo": PLUGIN_REPO,
        "githubUrl": PLUGIN_URL,
        "releasesUrl": download_url,
        "productUrl": PRODUCT_URL,
        "statusText": status_text,
        "computerLabel": "Always on",
        "signedIn": signed_in,
        "signedInLabel": "Yes" if signed_in else "No",
        "lastCheckText": ago_text(checked_at),
        "staleSeconds": int(stale_ms / 1000) if stale_ms else 0,
        "packageVersion": pkg,
    }


def main() -> int:
    args = sys.argv[1:]
    if "--update" in args:
        return do_update()
    if "--fetch" in args:
        fetch_latest()
    emit(status())
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
