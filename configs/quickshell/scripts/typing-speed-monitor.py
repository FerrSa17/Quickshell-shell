#!/usr/bin/env python3
"""System-wide typing speed monitor for Quickshell.

Reads keyboard EV_KEY events from /dev/input (requires `input` group),
computes current / daily WPM, and atomically writes JSON stats.
Does not log key contents — only counts key-down events.
"""
from __future__ import annotations

import fcntl
import json
import os
import select
import struct
import sys
import time
from collections import deque
from pathlib import Path

# input_event on linux x86_64
EVENT_FMT = "llHHi"
EVENT_SIZE = struct.calcsize(EVENT_FMT)
EV_KEY = 0x01
KEY_DOWN = 1

# Modifiers / locks / navigation we ignore for typing speed.
IGNORE_CODES = {
    0, 1,  # reserved / esc
    29, 42, 54, 56, 97, 100, 125, 126, 127,  # ctrl/shift/alt/meta/compose
    58, 69, 70,  # caps/num/scroll lock
    103, 105, 106, 108,  # arrows
    102, 107, 104, 109,  # home/end/pgup/pgdn
    110, 111, 119,  # insert/delete/pause
    183, 184, 185, 186, 187, 188, 189, 190, 191, 192, 193, 194,  # F13+
}

WINDOW_SEC = 45.0
GAP_SEC = 2.0
WRITE_EVERY_SEC = 0.75
KEEP_DAYS = 60

STATE_DIR = Path(os.environ.get("HOME", "/tmp")) / ".local" / "state" / "quickshell"
OUT_PATH = STATE_DIR / "typing-stats.json"
LOCK_PATH = STATE_DIR / "typing-speed-monitor.lock"


def wpm(chars: int, active_ms: float) -> float:
    if active_ms <= 0 or chars <= 0:
        return 0.0
    minutes = active_ms / 60000.0
    if minutes <= 0:
        return 0.0
    return round((chars / 5.0) / minutes, 1)


def today_key(ts: float | None = None) -> str:
    return time.strftime("%Y-%m-%d", time.localtime(ts or time.time()))


def load_state() -> dict:
    if not OUT_PATH.exists():
        return {"days": {}}
    try:
        data = json.loads(OUT_PATH.read_text(encoding="utf-8"))
        if not isinstance(data, dict):
            return {"days": {}}
        days = data.get("days")
        if not isinstance(days, dict):
            data["days"] = {}
        return data
    except Exception:
        return {"days": {}}


def prune_days(days: dict) -> dict:
    if len(days) <= KEEP_DAYS:
        return days
    keys = sorted(days.keys())
    for k in keys[:-KEEP_DAYS]:
        days.pop(k, None)
    return days


def atomic_write(payload: dict) -> None:
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    tmp = OUT_PATH.with_suffix(".tmp")
    text = json.dumps(payload, ensure_ascii=False, separators=(",", ":"))
    with open(tmp, "w", encoding="utf-8") as f:
        f.write(text)
        f.flush()
        os.fsync(f.fileno())
    os.replace(tmp, OUT_PATH)


def list_keyboard_devices() -> list[Path]:
    by_id = Path("/dev/input/by-id")
    found: list[Path] = []
    if by_id.is_dir():
        for p in sorted(by_id.iterdir()):
            name = p.name.lower()
            if "kbd" in name or name.endswith("-event-kbd"):
                try:
                    found.append(p.resolve())
                except Exception:
                    pass
    if found:
        return found

    # Fallback: any event node that looks like a keyboard via name sysfs.
    base = Path("/dev/input")
    for p in sorted(base.glob("event*")):
        name_path = Path("/sys/class/input") / p.name / "device" / "name"
        try:
            n = name_path.read_text(encoding="utf-8", errors="ignore").lower()
        except Exception:
            continue
        if "keyboard" in n or "kbd" in n:
            found.append(p)
    return found


def acquire_lock() -> int:
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    fd = os.open(str(LOCK_PATH), os.O_CREAT | os.O_RDWR, 0o644)
    try:
        fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        os.close(fd)
        sys.stderr.write("typing-speed-monitor: already running\n")
        sys.exit(0)
    os.write(fd, f"{os.getpid()}\n".encode())
    return fd


def main() -> int:
    lock_fd = acquire_lock()
    devices = list_keyboard_devices()
    if not devices:
        sys.stderr.write("typing-speed-monitor: no keyboard devices found\n")
        return 1

    fds: dict[int, Path] = {}
    for path in devices:
        try:
            fd = os.open(str(path), os.O_RDONLY | os.O_NONBLOCK)
            fds[fd] = path
        except PermissionError:
            sys.stderr.write(f"typing-speed-monitor: cannot open {path} (need input group)\n")
        except OSError as e:
            sys.stderr.write(f"typing-speed-monitor: open {path}: {e}\n")

    if not fds:
        return 1

    state = load_state()
    days: dict = state.setdefault("days", {})
    recent: deque[float] = deque()
    last_key_ts: float | None = None
    dirty = True
    last_write = 0.0

    def ensure_day(day: str) -> dict:
        d = days.get(day)
        if not isinstance(d, dict):
            d = {"chars": 0, "activeMs": 0.0}
            days[day] = d
        d.setdefault("chars", 0)
        d.setdefault("activeMs", 0.0)
        return d

    def snapshot() -> dict:
        now = time.time()
        while recent and now - recent[0] > WINDOW_SEC:
            recent.popleft()
        day = today_key(now)
        d = ensure_day(day)
        if recent:
            span = max(1.0, min(WINDOW_SEC, now - recent[0]))
            cur = wpm(len(recent), span * 1000.0)
        else:
            cur = 0.0
        today = wpm(int(d.get("chars", 0)), float(d.get("activeMs", 0.0)))
        d["wpm"] = today
        prune_days(days)
        week = []
        for i in range(6, -1, -1):
            ts = now - i * 86400
            k = today_key(ts)
            entry = days.get(k) or {}
            week.append(
                {
                    "date": k,
                    "label": time.strftime("%a", time.localtime(ts)),
                    "wpm": float(entry.get("wpm", 0.0) or 0.0),
                    "chars": int(entry.get("chars", 0) or 0),
                }
            )
        return {
            "currentWpm": cur,
            "todayWpm": today,
            "todayChars": int(d.get("chars", 0)),
            "todayActiveMs": float(d.get("activeMs", 0.0)),
            "updatedAt": now,
            "days": days,
            "week": week,
        }

    def maybe_write(force: bool = False) -> None:
        nonlocal dirty, last_write
        now = time.time()
        if not dirty and not force:
            return
        if not force and now - last_write < WRITE_EVERY_SEC:
            return
        atomic_write(snapshot())
        last_write = now
        dirty = False

    # Initial file so QML has something to read.
    atomic_write(snapshot())

    poller = select.poll()
    for fd in fds:
        poller.register(fd, select.POLLIN)

    buffers: dict[int, bytes] = {fd: b"" for fd in fds}

    try:
        while True:
            events = poller.poll(500)
            now = time.time()
            # Decay current WPM even without keys.
            if recent and now - last_write >= WRITE_EVERY_SEC:
                dirty = True
                maybe_write()

            for fd, _flag in events:
                try:
                    chunk = os.read(fd, EVENT_SIZE * 32)
                except BlockingIOError:
                    continue
                except OSError:
                    continue
                if not chunk:
                    continue
                buffers[fd] += chunk
                buf = buffers[fd]
                while len(buf) >= EVENT_SIZE:
                    raw = buf[:EVENT_SIZE]
                    buf = buf[EVENT_SIZE:]
                    _sec, _usec, etype, code, value = struct.unpack(EVENT_FMT, raw)
                    if etype != EV_KEY or value != KEY_DOWN:
                        continue
                    if code in IGNORE_CODES:
                        continue
                    # Skip pure function keys F1-F12 for WPM (optional); still count space/enter.
                    if 59 <= code <= 68:  # F1-F10
                        continue
                    if code in (87, 88):  # F11 F12
                        continue

                    ts = time.time()
                    recent.append(ts)
                    while recent and ts - recent[0] > WINDOW_SEC:
                        recent.popleft()

                    day = today_key(ts)
                    d = ensure_day(day)
                    d["chars"] = int(d.get("chars", 0)) + 1
                    if last_key_ts is not None:
                        gap = ts - last_key_ts
                        if 0 < gap <= GAP_SEC:
                            d["activeMs"] = float(d.get("activeMs", 0.0)) + gap * 1000.0
                    last_key_ts = ts
                    d["wpm"] = wpm(int(d["chars"]), float(d["activeMs"]))
                    dirty = True
                buffers[fd] = buf

            maybe_write()
    except KeyboardInterrupt:
        maybe_write(force=True)
        return 0
    finally:
        for fd in list(fds):
            try:
                os.close(fd)
            except OSError:
                pass
        try:
            os.close(lock_fd)
        except OSError:
            pass


if __name__ == "__main__":
    sys.exit(main())
