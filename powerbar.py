#!/usr/bin/python3
# <xbar.title>powerbar</xbar.title>
# <xbar.version>1.0.0</xbar.version>
# <xbar.desc>Total power draw of the Mac (SMC PSTR via macmon), smoothed with a threshold.</xbar.desc>
# <xbar.dependencies>macmon</xbar.dependencies>
# <swiftbar.type>streamable</swiftbar.type>
# <swiftbar.runInBash>false</swiftbar.runInBash>
# <swiftbar.hideRunInTerminal>true</swiftbar.hideRunInTerminal>
# <swiftbar.hideLastUpdated>true</swiftbar.hideLastUpdated>
# <swiftbar.hideAbout>true</swiftbar.hideAbout>
"""
Shows the total system power draw in the menu bar, but calmly:

- A sample is taken every second (macmon pipe, value = SMC key PSTR,
  the same source as "System Total" in Stats).
- The reading is smoothed with an exponential moving average
  (time constant TAU seconds).
- The number in the menu bar only changes once the smoothed value differs
  from the displayed one by at least STEP_ABS watts or STEP_REL (fraction).
- Large jumps (JUMP_ABS watts and JUMP_REL) that persist for JUMP_N seconds
  are shown immediately, without waiting for the smoothing.
"""

import json
import math
import os
import shutil
import subprocess
import sys
import time

# ---- Settings (feel free to change) -----------------------------------------
INTERVAL_MS = 1000   # sampling interval
TAU = 8.0            # smoothing in seconds (higher = calmer)
STEP_ABS = 1.5       # minimum change in W before the number changes
STEP_REL = 0.15      # ...or as a fraction of the displayed value (the larger wins)
JUMP_ABS = 5.0     # a "substantial" jump in W
JUMP_REL = 0.5     # ...and as a fraction of the displayed value
JUMP_N = 3         # number of consecutive samples the jump must persist
MENU_REFRESH = 5     # refresh dropdown details every N seconds
WIDTH = 3          # digit slots in the menu bar; 3 = up to 999 W
MAX_W = 500.0      # readings above this are SMC glitches and are ignored
# ---------------------------------------------------------------------------
# Put your own values in ~/.config/powerbar/config (one KEY=value per line)
# so they survive an update.
CONFIG = os.path.expanduser("~/.config/powerbar/config")


def load_config():
    if not os.path.exists(CONFIG):
        return
    g = globals()
    with open(CONFIG, encoding="utf-8") as f:
        for line in f:
            line = line.split("#", 1)[0].strip()
            if "=" not in line:
                continue
            key, val = (x.strip() for x in line.split("=", 1))
            if key in g and isinstance(g[key], (int, float)) and not isinstance(g[key], bool):
                try:
                    g[key] = type(g[key])(float(val))
                except ValueError:
                    pass


MACMON_CANDIDATES = [
    os.path.expanduser("~/.homebrew/bin/macmon"),
    "/opt/homebrew/bin/macmon",
    "/usr/local/bin/macmon",
]


def find_macmon():
    for p in MACMON_CANDIDATES:
        if os.path.exists(p):
            return p
    return shutil.which("macmon")


def emit(lines):
    sys.stdout.write("~~~\n" + "\n".join(lines) + "\n")
    sys.stdout.flush()


# Fixed width without changing the font: empty digit slots are padded with a
# FIGURE SPACE (U+2007), which is exactly as wide as a digit in the system
# font. This keeps the widget (almost) the same width, so the icons to its
# left don't shift. trim=false stops SwiftBar from stripping the padding.
# The bolt icon sits inline to the right of the number (:bolt.fill:).
FIGSPACE = "\u2007"


def fmt_title(w):
    number = str(int(round(min(w, 10 ** WIDTH - 1))))
    pad = FIGSPACE * (WIDTH - len(number))
    return pad + number + "W :bolt.fill:| trim=false"


def menu(shown, ema, raw, d, peak, source):
    def w(x):
        return f"{x:.1f} W"
    return [
        fmt_title(shown),
        "---",
        f"Smoothed: {w(ema)}",
        f"Last reading: {w(raw)}",
        f"Peak since start: {w(peak)}",
        "---",
        f"CPU: {w(d.get('cpu_power', 0))}",
        f"GPU: {w(d.get('gpu_power', 0))}",
        f"ANE: {w(d.get('ane_power', 0))}",
        f"RAM: {w(d.get('ram_power', 0))}",
        "---",
        f"Source: {source} · smoothing {TAU:g}s · threshold ±{STEP_ABS:g}W/{STEP_REL:.0%} | size=11",
        "---",
        f"Settings… | bash=/usr/bin/open param1=-t param2={CONFIG} terminal=false",
        "Disable | href=swiftbar://disableplugin?name=powerbar",
    ]


def get_power(d):
    # macmon >= 0.8 puts the fields flat in the JSON object
    if "sys_power" not in d and isinstance(d.get("metrics"), dict):
        d = d["metrics"]
    sys_p = float(d.get("sys_power") or 0)
    if sys_p > 0:
        return sys_p, "PSTR (whole system)", d
    return float(d.get("all_power") or 0), "chip only (CPU+GPU+ANE)", d


def run():
    load_config()
    macmon = find_macmon()
    if not macmon:
        emit([FIGSPACE * 2 + "?W :bolt.slash:| trim=false", "---", "macmon not found. Install with: brew install macmon"])
        time.sleep(60)
        return

    proc = subprocess.Popen(
        [macmon, "pipe", "-i", str(INTERVAL_MS)],
        stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True, bufsize=1,
    )

    dt = INTERVAL_MS / 1000.0
    alpha = 1 - math.exp(-dt / TAU)
    ema = None
    shown = None
    peak = 0.0
    jump = []
    last_menu = 0.0

    for line in proc.stdout:
        try:
            raw, source, d = get_power(json.loads(line))
        except (ValueError, TypeError):
            continue
        if raw <= 0 or raw > MAX_W:  # PSTR now and then gives a bogus value (thousands of W)
            continue

        peak = max(peak, raw)
        ema = raw if ema is None else ema + alpha * (raw - ema)

        changed = False
        if shown is None:
            shown, changed = ema, True
        else:
            # fast path: show a large, persistent jump immediately
            if abs(raw - shown) >= max(JUMP_ABS, JUMP_REL * shown):
                jump.append(raw)
            else:
                jump.clear()
            if len(jump) >= JUMP_N:
                ema = sum(jump[-JUMP_N:]) / JUMP_N
                jump.clear()
                shown, changed = ema, True
            # normal path: the smoothed value differs enough
            # (not during a possible jump; we wait that out)
            elif not jump and abs(ema - shown) >= max(STEP_ABS, STEP_REL * shown):
                shown, changed = ema, True

        now = time.monotonic()
        if changed or now - last_menu >= MENU_REFRESH:
            emit(menu(shown, ema, raw, d, peak, source))
            last_menu = now

    proc.wait()


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")  # SwiftBar starts without a locale
    while True:
        try:
            run()
        except Exception as e:  # never silently vanish from the menu bar
            emit([FIGSPACE * 2 + "?W :bolt.slash:| trim=false", "---", f"Error: {e}"])
        time.sleep(3)  # macmon stopped (e.g. after sleep) -> restart
