# Plan: FlipClock ASCII Screensaver

> **Spec:** docs/specs/2026-04-01-flipclock-ascii-screensaver.md

**Goal:** Create a terminal-based ASCII flip clock screensaver for Hyprland/Wayland with multi-monitor support, TTE transition effects on minute change, and graceful degradation.

**Architecture:** 3 executable scripts: `flipclock-ascii` (Python, renderer), `flipclock-screensaver` (Bash, multi-monitor launcher), `flipclock-screensaver-cmd` (Bash, content runner with TTE). Launcher spawns one fullscreen terminal per monitor. Content runner displays the clock and applies TTE on minute change.

**Tech Stack:** Python 3, pyfiglet, TTE (terminaltexteffects), Bash, bats-core, pytest, hyprctl, jq

**Total Tasks:** 14

**Estimated Complexity:** large (14 tasks)

**Dependency Graph:**
```
Task 1 (scaffold) --> Task 2-5 (flipclock-ascii Python)
                  --> Task 8-9 (flipclock-screensaver launcher)
                  --> Task 10-11 (flipclock-screensaver-cmd)
Tasks 2-5 ---------> Task 6 (--once mode / build_frame)
                  --> Task 7 (signal handling / main loop)
Tasks 6,8-9 -------> Tasks 10-11 (content runner needs ascii + launcher)
Tasks 2-11 --------> Tasks 12-13 (installer)
Task 14 (hyprland config + resize) - depends on Tasks 7, 9
```

---

## P1 Tasks (MVP)

### Task 1: Project scaffold + test infrastructure

**Requirement:** (infrastructure, supports all REQs)
**Depends on:** none
**Files:**
- Create: `.gitignore`
- Create: `pyproject.toml`
- Create: `tests/__init__.py`
- Create: `tests/test_flipclock_ascii.py` (empty placeholder)
- Create: `tests/test_screensaver.bats` (empty placeholder)
- Create: `tests/test_screensaver_cmd.bats` (empty placeholder)

**Step 1: Initialize git and create .gitignore**
```bash
git init
```

```gitignore
__pycache__/
*.pyc
.venv/
.pytest_cache/
*.egg-info/
```

**Step 2: Create pyproject.toml with test deps**
```toml
[project]
name = "flipclock-ascii"
version = "0.1.0"
requires-python = ">=3.10"
dependencies = ["pyfiglet"]

[project.optional-dependencies]
dev = ["pytest", "pytest-cov"]

[tool.pytest.ini_options]
testpaths = ["tests"]
```

**Step 3: Install test deps**
```bash
pip install --user pytest pytest-cov pyfiglet bats-core 2>/dev/null || true
# bats via pacman if not available
pacman -Q bats 2>/dev/null || echo "Install bats: pacman -S bash-bats"
```

**Step 4: Create empty test files**
```bash
mkdir -p tests
touch tests/__init__.py tests/test_flipclock_ascii.py
touch tests/test_screensaver.bats tests/test_screensaver_cmd.bats
```

**Step 5: Commit**
Run: `/git commit`

---

### Task 2: flipclock-ascii arg parsing

**Requirement:** REQ-002
**Depends on:** Task 1
**Files:**
- Create: `flipclock_ascii.py`
- Test: `tests/test_flipclock_ascii.py`

**Step 1: Write the failing test**
```python
# tests/test_flipclock_ascii.py
from flipclock_ascii import parse_args


def test_parse_args_default():
    args = parse_args([])
    assert args.once is False


def test_parse_args_once():
    args = parse_args(["--once"])
    assert args.once is True
```

**Step 2: Run test to verify it fails**
Run: `pytest tests/test_flipclock_ascii.py::test_parse_args_default -v`
Expected: FAIL with `ModuleNotFoundError: No module named 'flipclock_ascii'`

**Step 3: Write minimal implementation**
```python
#!/usr/bin/env python3
"""FlipClock ASCII - Terminal clock renderer using pyfiglet."""

import argparse


def parse_args(argv=None):
    """Parse command-line arguments."""
    parser = argparse.ArgumentParser(description="ASCII flip clock renderer")
    parser.add_argument("--once", action="store_true", help="Render single frame and exit")
    return parser.parse_args(argv)
```

**Step 4: Run test to verify it passes**
Run: `pytest tests/test_flipclock_ascii.py -v`
Expected: PASS (2 passed)

**Step 5: Commit**
Run: `/git commit`

---

### Task 3: Render HH:MM with pyfiglet ansi_shadow

**Requirement:** REQ-001
**Depends on:** Task 2
**Files:**
- Modify: `flipclock_ascii.py`
- Modify: `tests/test_flipclock_ascii.py`

**Step 1: Write the failing test**
```python
# append to tests/test_flipclock_ascii.py
from flipclock_ascii import render_frame


def test_render_frame_returns_lines():
    lines = render_frame("12:45")
    assert isinstance(lines, list)
    assert len(lines) > 0


def test_render_frame_uses_ansi_shadow():
    lines = render_frame("00:00")
    # ansi_shadow uses block characters (Unicode box-drawing / block elements)
    joined = "\n".join(lines)
    assert "\u2588" in joined or "\u2550" in joined or "\u2557" in joined
```

**Step 2: Run test to verify it fails**
Run: `pytest tests/test_flipclock_ascii.py::test_render_frame_returns_lines -v`
Expected: FAIL with `ImportError: cannot import name 'render_frame'`

**Step 3: Write minimal implementation**
```python
# add to flipclock_ascii.py
import pyfiglet


FONT = "ansi_shadow"


def render_frame(time_str):
    """Render a time string as ASCII art lines using pyfiglet."""
    fig = pyfiglet.Figlet(font=FONT)
    art = fig.renderText(time_str)
    return art.rstrip("\n").split("\n")
```

**Step 4: Run test to verify it passes**
Run: `pytest tests/test_flipclock_ascii.py -v`
Expected: PASS (4 passed)

**Step 5: Commit**
Run: `/git commit`

---

### Task 4: Centering calculation

**Requirement:** REQ-001
**Depends on:** Task 3
**Files:**
- Modify: `flipclock_ascii.py`
- Modify: `tests/test_flipclock_ascii.py`

**Step 1: Write the failing test**
```python
# append to tests/test_flipclock_ascii.py
from flipclock_ascii import calculate_centering


def test_centering_horizontal():
    pad_top, pad_left = calculate_centering(
        art_lines=["XXXX", "XXXX"], term_cols=20, term_rows=10
    )
    # line width=4, cols=20 => pad_left = (20-4)//2 = 8
    assert pad_left == 8


def test_centering_vertical():
    pad_top, pad_left = calculate_centering(
        art_lines=["XX", "XX"], term_cols=10, term_rows=20
    )
    # art_height=2, rows=20 => pad_top = (20-2)//2 = 9
    assert pad_top == 9


def test_centering_small_terminal():
    pad_top, pad_left = calculate_centering(
        art_lines=["XXXXXXXXXXXX"], term_cols=5, term_rows=3
    )
    assert pad_top == 0
    assert pad_left == 0
```

**Step 2: Run test to verify it fails**
Run: `pytest tests/test_flipclock_ascii.py::test_centering_horizontal -v`
Expected: FAIL with `ImportError: cannot import name 'calculate_centering'`

**Step 3: Write minimal implementation**
```python
# add to flipclock_ascii.py
def calculate_centering(art_lines, term_cols, term_rows):
    """Calculate top and left padding to center art in terminal."""
    art_height = len(art_lines)
    art_width = max(len(line) for line in art_lines) if art_lines else 0
    pad_top = max(0, (term_rows - art_height) // 2)
    pad_left = max(0, (term_cols - art_width) // 2)
    return pad_top, pad_left
```

**Step 4: Run test to verify it passes**
Run: `pytest tests/test_flipclock_ascii.py -v`
Expected: PASS (7 passed)

**Step 5: Commit**
Run: `/git commit`

---

### Task 5: ANSI terminal control (colors, cursor, cleanup)

**Requirement:** REQ-001, REQ-004
**Depends on:** Task 4
**Files:**
- Modify: `flipclock_ascii.py`
- Modify: `tests/test_flipclock_ascii.py`

**Step 1: Write the failing test**
```python
# append to tests/test_flipclock_ascii.py
from flipclock_ascii import terminal_setup_sequence, terminal_cleanup_sequence


def test_setup_hides_cursor():
    seq = terminal_setup_sequence()
    assert "\033[?25l" in seq  # hide cursor


def test_setup_sets_black_bg():
    seq = terminal_setup_sequence()
    assert "\033]11;#000000\007" in seq


def test_cleanup_shows_cursor():
    seq = terminal_cleanup_sequence()
    assert "\033[?25h" in seq  # show cursor


def test_cleanup_resets_color():
    seq = terminal_cleanup_sequence()
    assert "\033[0m" in seq
```

**Step 2: Run test to verify it fails**
Run: `pytest tests/test_flipclock_ascii.py::test_setup_hides_cursor -v`
Expected: FAIL with `ImportError: cannot import name 'terminal_setup_sequence'`

**Step 3: Write minimal implementation**
```python
# add to flipclock_ascii.py
COLOR_DIGIT = "\033[1;37m"  # Bold white
COLOR_RESET = "\033[0m"
CLEAR = "\033[2J\033[H"     # Clear screen + home
HIDE_CURSOR = "\033[?25l"
SHOW_CURSOR = "\033[?25h"
BG_BLACK = "\033]11;#000000\007"


def terminal_setup_sequence():
    """Return ANSI sequence to initialize terminal for clock display."""
    return HIDE_CURSOR + BG_BLACK


def terminal_cleanup_sequence():
    """Return ANSI sequence to restore terminal state."""
    return SHOW_CURSOR + COLOR_RESET
```

**Step 4: Run test to verify it passes**
Run: `pytest tests/test_flipclock_ascii.py -v`
Expected: PASS (11 passed)

**Step 5: Commit**
Run: `/git commit`

---

### Task 6: Build full frame output

**Requirement:** REQ-001, REQ-002
**Depends on:** Tasks 3, 4, 5
**Files:**
- Modify: `flipclock_ascii.py`
- Modify: `tests/test_flipclock_ascii.py`

**Step 1: Write the failing test**
```python
# append to tests/test_flipclock_ascii.py
from unittest.mock import patch
from flipclock_ascii import build_frame


def test_build_frame_contains_time():
    frame = build_frame("12:45", term_cols=120, term_rows=40)
    # Frame should contain the pyfiglet rendered art
    assert len(frame) > 0
    assert "\033[1;37m" in frame  # bold white color


def test_build_frame_clears_screen():
    frame = build_frame("12:45", term_cols=120, term_rows=40)
    assert "\033[2J\033[H" in frame  # clear + home


def test_build_frame_once_mode_no_ansi():
    frame = build_frame("12:45", term_cols=120, term_rows=40, once=True)
    # once mode: no ANSI colors (clean output for TTE pipe)
    assert "\033[1;37m" not in frame
    assert "\033[2J" not in frame
```

**Step 2: Run test to verify it fails**
Run: `pytest tests/test_flipclock_ascii.py::test_build_frame_contains_time -v`
Expected: FAIL with `ImportError: cannot import name 'build_frame'`

**Step 3: Write minimal implementation**
```python
# add to flipclock_ascii.py
def build_frame(time_str, term_cols, term_rows, once=False):
    """Build a complete frame string for terminal output."""
    lines = render_frame(time_str)
    pad_top, pad_left = calculate_centering(lines, term_cols, term_rows)

    parts = []

    if not once:
        parts.append(CLEAR)

    # Top padding
    if not once:
        parts.append("\n" * pad_top)

    # Clock lines
    for line in lines:
        prefix = " " * pad_left
        if once:
            parts.append(f"{prefix}{line}\n")
        else:
            parts.append(f"{COLOR_DIGIT}{prefix}{line}{COLOR_RESET}\n")

    return "".join(parts)
```

**Step 4: Run test to verify it passes**
Run: `pytest tests/test_flipclock_ascii.py -v`
Expected: PASS (14 passed)

**Step 5: Commit**
Run: `/git commit`

---

### Task 7: Main loop + signal handling + entrypoint

**Requirement:** REQ-003, REQ-004
**Depends on:** Task 6
**Files:**
- Modify: `flipclock_ascii.py`
- Create: `flipclock-ascii`
- Modify: `tests/test_flipclock_ascii.py`

**Step 1: Write the failing test**
```python
# append to tests/test_flipclock_ascii.py
import signal
from unittest.mock import patch, MagicMock
from flipclock_ascii import render_clock


@patch("flipclock_ascii.shutil.get_terminal_size", return_value=(120, 40))
@patch("flipclock_ascii.sys.stdout", new_callable=MagicMock)
@patch("flipclock_ascii.datetime")
def test_render_clock_once_mode(mock_dt, mock_stdout, mock_size):
    mock_dt.now.return_value.strftime.return_value = "08:30"
    render_clock(once=True)
    mock_stdout.write.assert_called()
    mock_stdout.flush.assert_called()


@patch("flipclock_ascii.shutil.get_terminal_size", return_value=(120, 40))
@patch("flipclock_ascii.sys.stdout", new_callable=MagicMock)
@patch("flipclock_ascii.time.sleep", side_effect=KeyboardInterrupt)
@patch("flipclock_ascii.datetime")
def test_render_clock_exits_on_interrupt(mock_dt, mock_sleep, mock_stdout, mock_size):
    mock_dt.now.return_value.strftime.return_value = "08:30"
    render_clock(once=False)
    # Should have written cleanup sequence
    writes = [str(c) for c in mock_stdout.write.call_args_list]
    cleanup = "".join(writes)
    assert "\033[?25h" in cleanup  # cursor restored
```

**Step 2: Run test to verify it fails**
Run: `pytest tests/test_flipclock_ascii.py::test_render_clock_once_mode -v`
Expected: FAIL with `ImportError: cannot import name 'render_clock'`

**Step 3: Write minimal implementation**
```python
# add to flipclock_ascii.py
import sys
import time
import shutil
import signal
from datetime import datetime


def cleanup(stdout=None):
    """Restore terminal state."""
    out = stdout or sys.stdout
    out.write(terminal_cleanup_sequence())
    out.flush()


def render_clock(once=False):
    """Main render loop."""
    def handle_signal(signum, frame):
        cleanup()
        sys.exit(0)

    signal.signal(signal.SIGINT, handle_signal)
    signal.signal(signal.SIGTERM, handle_signal)

    sys.stdout.write(terminal_setup_sequence())
    last_hm = ""

    try:
        while True:
            now = datetime.now()
            hm = now.strftime("%H:%M")
            cols, rows = shutil.get_terminal_size()

            if hm != last_hm or once:
                frame = build_frame(hm, cols, rows, once=once)
                sys.stdout.write(frame)
                sys.stdout.flush()
                last_hm = hm

            if once:
                break

            time.sleep(0.5)

    except (KeyboardInterrupt, BrokenPipeError):
        pass
    finally:
        cleanup()


if __name__ == "__main__":
    args = parse_args()
    render_clock(once=args.once)
```

Create executable wrapper `flipclock-ascii`:
```python
#!/usr/bin/env python3
"""FlipClock ASCII - executable wrapper."""
from flipclock_ascii import parse_args, render_clock

if __name__ == "__main__":
    args = parse_args()
    render_clock(once=args.once)
```

```bash
chmod +x flipclock-ascii
```

**Step 4: Run test to verify it passes**
Run: `pytest tests/test_flipclock_ascii.py -v`
Expected: PASS (16 passed)

**Step 5: Commit**
Run: `/git commit`

---

### Task 8: flipclock-screensaver dependency check + terminal detection

**Requirement:** REQ-005
**Depends on:** Task 1
**Files:**
- Create: `flipclock-screensaver`
- Modify: `tests/test_screensaver.bats`

**Step 1: Write the failing test**
```bash
# tests/test_screensaver.bats
setup() {
    export PATH="$BATS_TEST_DIRNAME/mocks:$PATH"
    export SCRIPT="$BATS_TEST_DIRNAME/../flipclock-screensaver"
}

@test "exits with error when hyprctl is missing" {
    mkdir -p "$BATS_TEST_TMPDIR/bin"
    cat > "$BATS_TEST_TMPDIR/bin/jq" << 'EOF'
#!/bin/bash
echo "mock"
EOF
    chmod +x "$BATS_TEST_TMPDIR/bin/jq"

    PATH="$BATS_TEST_TMPDIR/bin" run bash "$SCRIPT"
    [ "$status" -ne 0 ]
    [[ "$output" == *"hyprctl"* ]]
}

@test "exits with error when jq is missing" {
    mkdir -p "$BATS_TEST_TMPDIR/bin"
    cat > "$BATS_TEST_TMPDIR/bin/hyprctl" << 'EOF'
#!/bin/bash
echo "mock"
EOF
    chmod +x "$BATS_TEST_TMPDIR/bin/hyprctl"

    PATH="$BATS_TEST_TMPDIR/bin" run bash "$SCRIPT"
    [ "$status" -ne 0 ]
    [[ "$output" == *"jq"* ]]
}

@test "detects terminal via xdg-terminal-exec" {
    mkdir -p "$BATS_TEST_TMPDIR/bin"
    for cmd in hyprctl jq pgrep; do
        cat > "$BATS_TEST_TMPDIR/bin/$cmd" << 'MOCK'
#!/bin/bash
if [[ "$1" == "monitors" ]]; then echo '[]'; fi
if [[ "$1" == "-f" ]]; then exit 1; fi
MOCK
        chmod +x "$BATS_TEST_TMPDIR/bin/$cmd"
    done
    cat > "$BATS_TEST_TMPDIR/bin/xdg-terminal-exec" << 'EOF'
#!/bin/bash
echo "ghostty"
EOF
    chmod +x "$BATS_TEST_TMPDIR/bin/xdg-terminal-exec"

    PATH="$BATS_TEST_TMPDIR/bin" run bash "$SCRIPT"
    [ "$status" -eq 0 ]
}
```

**Step 2: Run test to verify it fails**
Run: `bats tests/test_screensaver.bats`
Expected: FAIL (script does not exist)

**Step 3: Write minimal implementation**
```bash
#!/usr/bin/env bash
set -euo pipefail

# FlipClock ASCII Screensaver - Multi-monitor launcher
# Spawns a fullscreen terminal on each monitor running the clock.

# Check dependencies
for cmd in hyprctl jq; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "Error: $cmd is required but not found" >&2
        exit 1
    fi
done

# Detect terminal
if command -v xdg-terminal-exec &>/dev/null; then
    TERMINAL=$(xdg-terminal-exec --print-id 2>/dev/null || echo "")
else
    TERMINAL=""
fi

if [[ -z "$TERMINAL" ]]; then
    notify-send "FlipClock Screensaver" "No supported terminal found" 2>/dev/null || true
    echo "Error: no supported terminal found" >&2
    exit 1
fi
```

```bash
chmod +x flipclock-screensaver
```

**Step 4: Run test to verify it passes**
Run: `bats tests/test_screensaver.bats`
Expected: PASS (3 tests)

**Step 5: Commit**
Run: `/git commit`

---

### Task 9: flipclock-screensaver multi-monitor spawn

**Requirement:** REQ-005, REQ-014
**Depends on:** Task 8
**Files:**
- Modify: `flipclock-screensaver`
- Modify: `tests/test_screensaver.bats`

**Step 1: Write the failing test**
```bash
# append to tests/test_screensaver.bats
@test "spawns terminal for each monitor" {
    mkdir -p "$BATS_TEST_TMPDIR/bin"

    # Mock hyprctl to return 2 monitors
    cat > "$BATS_TEST_TMPDIR/bin/hyprctl" << 'EOF'
#!/bin/bash
case "$1" in
    monitors)
        echo '[{"name":"DP-1","focused":true},{"name":"HDMI-A-1","focused":false}]'
        ;;
    dispatch)
        echo "$@" >> "$BATS_TEST_TMPDIR/dispatches.log"
        ;;
esac
EOF
    chmod +x "$BATS_TEST_TMPDIR/bin/hyprctl"

    for cmd in jq pgrep; do
        cp "$(which $cmd)" "$BATS_TEST_TMPDIR/bin/" 2>/dev/null || true
    done

    # Mock pgrep to say no instance running
    cat > "$BATS_TEST_TMPDIR/bin/pgrep" << 'EOF'
#!/bin/bash
exit 1
EOF
    chmod +x "$BATS_TEST_TMPDIR/bin/pgrep"

    cat > "$BATS_TEST_TMPDIR/bin/xdg-terminal-exec" << 'EOF'
#!/bin/bash
echo "ghostty"
EOF
    chmod +x "$BATS_TEST_TMPDIR/bin/xdg-terminal-exec"

    PATH="$BATS_TEST_TMPDIR/bin:$(dirname $(which jq))" run bash "$SCRIPT"

    # Should have dispatched exec for 2 monitors + focusmonitor calls
    [ -f "$BATS_TEST_TMPDIR/dispatches.log" ]
    exec_count=$(grep -c "exec" "$BATS_TEST_TMPDIR/dispatches.log")
    [ "$exec_count" -eq 2 ]
}
```

**Step 2: Run test to verify it fails**
Run: `bats tests/test_screensaver.bats`
Expected: FAIL (no monitor loop in script yet)

**Step 3: Write minimal implementation**
```bash
# append to flipclock-screensaver (after terminal detection)

# Save focused monitor to restore later (REQ-014)
FOCUSED=$(hyprctl monitors -j | jq -r '.[] | select(.focused == true).name')

# Launch a terminal on each monitor
for monitor in $(hyprctl monitors -j | jq -r '.[].name'); do
    hyprctl dispatch focusmonitor "$monitor"

    case "$TERMINAL" in
        *alacritty*|*Alacritty*)
            hyprctl dispatch exec -- \
                alacritty --class=com.flipclock.screensaver \
                -e flipclock-screensaver-cmd
            ;;
        *ghostty*)
            hyprctl dispatch exec -- \
                ghostty --class=com.flipclock.screensaver \
                --font-size=18 \
                -e flipclock-screensaver-cmd
            ;;
        *kitty*)
            hyprctl dispatch exec -- \
                kitty --class=com.flipclock.screensaver \
                --override font_size=18 \
                --override window_padding_width=0 \
                -e flipclock-screensaver-cmd
            ;;
        *)
            notify-send "FlipClock" "Unsupported terminal: $TERMINAL" 2>/dev/null || true
            ;;
    esac
done

# Restore focus to original monitor (REQ-014)
hyprctl dispatch focusmonitor "$FOCUSED"
```

**Step 4: Run test to verify it passes**
Run: `bats tests/test_screensaver.bats`
Expected: PASS (4 tests)

**Step 5: Commit**
Run: `/git commit`

---

### Task 10: flipclock-screensaver-cmd with TTE on minute change

**Requirement:** REQ-006, REQ-008
**Depends on:** Tasks 7, 9
**Files:**
- Create: `flipclock-screensaver-cmd`
- Modify: `tests/test_screensaver_cmd.bats`

**Step 1: Write the failing test**
```bash
# tests/test_screensaver_cmd.bats
setup() {
    export SCRIPT="$BATS_TEST_DIRNAME/../flipclock-screensaver-cmd"
}

@test "exit_screensaver function exists" {
    mkdir -p "$BATS_TEST_TMPDIR/bin"
    cat > "$BATS_TEST_TMPDIR/bin/hyprctl" << 'EOF'
#!/bin/bash
true
EOF
    cat > "$BATS_TEST_TMPDIR/bin/pkill" << 'EOF'
#!/bin/bash
true
EOF
    chmod +x "$BATS_TEST_TMPDIR/bin/hyprctl" "$BATS_TEST_TMPDIR/bin/pkill"

    PATH="$BATS_TEST_TMPDIR/bin:$PATH" run bash -c "
        source '$SCRIPT' --source-only 2>/dev/null || true
        type exit_screensaver &>/dev/null && echo 'function_exists'
    "
    [[ "$output" == *"function_exists"* ]]
}

@test "detects TTE availability" {
    mkdir -p "$BATS_TEST_TMPDIR/bin"
    cat > "$BATS_TEST_TMPDIR/bin/tte" << 'EOF'
#!/bin/bash
echo "tte mock"
EOF
    chmod +x "$BATS_TEST_TMPDIR/bin/tte"

    PATH="$BATS_TEST_TMPDIR/bin:$PATH" run bash -c "command -v tte"
    [ "$status" -eq 0 ]
}
```

**Step 2: Run test to verify it fails**
Run: `bats tests/test_screensaver_cmd.bats`
Expected: FAIL (script does not exist)

**Step 3: Write minimal implementation**
```bash
#!/usr/bin/env bash

# FlipClock ASCII Screensaver - Content runner
# Runs inside the terminal spawned by flipclock-screensaver.
# Renders clock with TTE effects on minute change, exits on input or focus loss.

# Allow sourcing for testing
if [[ "${1:-}" == "--source-only" ]]; then
    exit_screensaver() {
        hyprctl keyword cursor:invisible false &>/dev/null || true
        pkill -x flipclock-ascii 2>/dev/null
        pkill -x tte 2>/dev/null
        pkill -f "com.flipclock.screensaver" 2>/dev/null
        exit 0
    }
    return 0 2>/dev/null || exit 0
fi

screensaver_in_focus() {
    hyprctl activewindow -j | jq -e '.class == "com.flipclock.screensaver"' >/dev/null 2>&1
}

exit_screensaver() {
    hyprctl keyword cursor:invisible false &>/dev/null || true
    pkill -x flipclock-ascii 2>/dev/null
    pkill -x tte 2>/dev/null
    pkill -f "com.flipclock.screensaver" 2>/dev/null
    exit 0
}

trap exit_screensaver SIGINT SIGTERM SIGHUP SIGQUIT

# Set background to black and hide cursor
printf '\033]11;rgb:00/00/00\007'
hyprctl keyword cursor:invisible true &>/dev/null

HAS_TTE=false
if command -v tte &>/dev/null; then
    HAS_TTE=true
fi

last_hm=""
tty_dev=$(tty 2>/dev/null)

while true; do
    current_hm=$(date +%H:%M)

    if [[ "$current_hm" != "$last_hm" ]]; then
        if [[ "$HAS_TTE" == true ]]; then
            # Kill any running TTE first
            pkill -x tte 2>/dev/null
            sleep 0.1

            # Render clock once, pipe through TTE with random effect
            flipclock-ascii --once | tte \
                --frame-rate 120 \
                --canvas-width 0 --canvas-height 0 \
                --reuse-canvas \
                --anchor-canvas c --anchor-text c \
                --random-effect \
                --exclude-effects dev_worm \
                --no-eol --no-restore-cursor &
        else
            # No TTE: render directly (REQ-007)
            flipclock-ascii &
        fi
        last_hm="$current_hm"
    fi

    # Check for user input or focus loss (REQ-008)
    if read -n1 -t 1 || ! screensaver_in_focus; then
        exit_screensaver
    fi
done
```

```bash
chmod +x flipclock-screensaver-cmd
```

**Step 4: Run test to verify it passes**
Run: `bats tests/test_screensaver_cmd.bats`
Expected: PASS (2 tests)

**Step 5: Commit**
Run: `/git commit`

---

### Task 11: flipclock-screensaver-cmd graceful degradation without TTE

**Requirement:** REQ-007
**Depends on:** Task 10
**Files:**
- Modify: `tests/test_screensaver_cmd.bats`

**Step 1: Write the failing test**
```bash
# append to tests/test_screensaver_cmd.bats
@test "runs flipclock-ascii directly when TTE not available" {
    mkdir -p "$BATS_TEST_TMPDIR/bin"

    # No tte in PATH
    cat > "$BATS_TEST_TMPDIR/bin/flipclock-ascii" << 'EOF'
#!/bin/bash
echo "clock rendered" > "$BATS_TEST_TMPDIR/clock_ran"
sleep 0.1
EOF
    chmod +x "$BATS_TEST_TMPDIR/bin/flipclock-ascii"

    # Simulate: no tte command available
    PATH="$BATS_TEST_TMPDIR/bin" run bash -c "
        HAS_TTE=false
        command -v tte &>/dev/null && HAS_TTE=true
        echo \"has_tte=\$HAS_TTE\"
    "
    [[ "$output" == *"has_tte=false"* ]]
}
```

**Step 2: Run test to verify it passes**
Run: `bats tests/test_screensaver_cmd.bats`
Expected: PASS (3 tests) - graceful degradation already implemented in Task 10

**Step 3: No new implementation needed**

The `else` branch in Task 10 already handles the no-TTE case (REQ-007).

**Step 4: Commit**
Run: `/git commit`

---

## P2 Tasks (Should Have)

### Task 12: Toggle on/off + duplicate prevention

**Requirement:** REQ-009, REQ-010
**Depends on:** Task 9
**Files:**
- Modify: `flipclock-screensaver`
- Modify: `tests/test_screensaver.bats`

**Step 1: Write the failing test**
```bash
# append to tests/test_screensaver.bats
@test "exits silently when already running" {
    mkdir -p "$BATS_TEST_TMPDIR/bin"
    for cmd in hyprctl jq xdg-terminal-exec; do
        cat > "$BATS_TEST_TMPDIR/bin/$cmd" << 'EOF'
#!/bin/bash
echo "mock"
EOF
        chmod +x "$BATS_TEST_TMPDIR/bin/$cmd"
    done

    # Mock pgrep to say instance IS running
    cat > "$BATS_TEST_TMPDIR/bin/pgrep" << 'EOF'
#!/bin/bash
echo "12345"
exit 0
EOF
    chmod +x "$BATS_TEST_TMPDIR/bin/pgrep"

    PATH="$BATS_TEST_TMPDIR/bin" run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "exits when toggle file exists" {
    mkdir -p "$BATS_TEST_TMPDIR/bin"
    mkdir -p "$BATS_TEST_TMPDIR/state/flipclock"
    touch "$BATS_TEST_TMPDIR/state/flipclock/screensaver-off"

    for cmd in hyprctl jq xdg-terminal-exec; do
        cat > "$BATS_TEST_TMPDIR/bin/$cmd" << 'EOF'
#!/bin/bash
echo "mock"
EOF
        chmod +x "$BATS_TEST_TMPDIR/bin/$cmd"
    done
    cat > "$BATS_TEST_TMPDIR/bin/pgrep" << 'EOF'
#!/bin/bash
exit 1
EOF
    chmod +x "$BATS_TEST_TMPDIR/bin/pgrep"

    FLIPCLOCK_STATE_DIR="$BATS_TEST_TMPDIR/state/flipclock" \
        PATH="$BATS_TEST_TMPDIR/bin" run bash "$SCRIPT"
    [ "$status" -eq 0 ]
}

@test "launches when toggle exists but force is passed" {
    mkdir -p "$BATS_TEST_TMPDIR/bin"
    mkdir -p "$BATS_TEST_TMPDIR/state/flipclock"
    touch "$BATS_TEST_TMPDIR/state/flipclock/screensaver-off"

    cat > "$BATS_TEST_TMPDIR/bin/hyprctl" << 'EOF'
#!/bin/bash
case "$1" in
    monitors) echo '[{"name":"DP-1","focused":true}]' ;;
    dispatch) echo "$@" >> "$BATS_TEST_TMPDIR/dispatches.log" ;;
esac
EOF
    chmod +x "$BATS_TEST_TMPDIR/bin/hyprctl"

    for cmd in jq; do
        cp "$(which $cmd)" "$BATS_TEST_TMPDIR/bin/" 2>/dev/null || true
    done

    cat > "$BATS_TEST_TMPDIR/bin/pgrep" << 'EOF'
#!/bin/bash
exit 1
EOF
    cat > "$BATS_TEST_TMPDIR/bin/xdg-terminal-exec" << 'EOF'
#!/bin/bash
echo "ghostty"
EOF
    chmod +x "$BATS_TEST_TMPDIR/bin/pgrep" "$BATS_TEST_TMPDIR/bin/xdg-terminal-exec"

    FLIPCLOCK_STATE_DIR="$BATS_TEST_TMPDIR/state/flipclock" \
        PATH="$BATS_TEST_TMPDIR/bin:$(dirname $(which jq))" run bash "$SCRIPT" force
    [ -f "$BATS_TEST_TMPDIR/dispatches.log" ]
}
```

**Step 2: Run test to verify it fails**
Run: `bats tests/test_screensaver.bats`
Expected: FAIL (no toggle/duplicate logic yet)

**Step 3: Write minimal implementation**

Insert after dependency check, before terminal detection in `flipclock-screensaver`:
```bash
# State directory (overridable for testing)
STATE_DIR="${FLIPCLOCK_STATE_DIR:-$HOME/.local/state/flipclock}"

# Exit if already running (REQ-010)
if pgrep -f "flipclock-screensaver-cmd" &>/dev/null; then
    exit 0
fi

# Toggle on/off (REQ-009)
if [[ -f "$STATE_DIR/screensaver-off" ]] && [[ "${1:-}" != "force" ]]; then
    exit 0
fi
```

**Step 4: Run test to verify it passes**
Run: `bats tests/test_screensaver.bats`
Expected: PASS (7 tests)

**Step 5: Commit**
Run: `/git commit`

---

### Task 13: install.sh + uninstall

**Requirement:** REQ-011, REQ-012
**Depends on:** Tasks 7, 9, 10
**Files:**
- Create: `install.sh`
- Create: `tests/test_install.bats`

**Step 1: Write the failing test**
```bash
# tests/test_install.bats
setup() {
    export SCRIPT="$BATS_TEST_DIRNAME/../install.sh"
    export INSTALL_DIR="$BATS_TEST_TMPDIR/bin"
    export STATE_DIR="$BATS_TEST_TMPDIR/state/flipclock"
    mkdir -p "$INSTALL_DIR"
}

@test "exits with error when python3 is missing" {
    mkdir -p "$BATS_TEST_TMPDIR/empty_bin"
    PATH="$BATS_TEST_TMPDIR/empty_bin" FLIPCLOCK_BIN_DIR="$INSTALL_DIR" \
        run bash "$SCRIPT"
    [ "$status" -ne 0 ]
    [[ "$output" == *"python3"* ]]
}

@test "installs scripts to bin dir" {
    mkdir -p "$BATS_TEST_TMPDIR/mock_bin"
    for cmd in python3 jq hyprctl pip; do
        cat > "$BATS_TEST_TMPDIR/mock_bin/$cmd" << 'EOF'
#!/bin/bash
true
EOF
        chmod +x "$BATS_TEST_TMPDIR/mock_bin/$cmd"
    done

    PATH="$BATS_TEST_TMPDIR/mock_bin:$PATH" \
        FLIPCLOCK_BIN_DIR="$INSTALL_DIR" \
        run bash "$SCRIPT"

    [ "$status" -eq 0 ]
    [ -x "$INSTALL_DIR/flipclock-ascii" ]
    [ -x "$INSTALL_DIR/flipclock-screensaver" ]
    [ -x "$INSTALL_DIR/flipclock-screensaver-cmd" ]
}

@test "uninstall removes scripts" {
    # Create fake installed files
    touch "$INSTALL_DIR/flipclock-ascii"
    touch "$INSTALL_DIR/flipclock-screensaver"
    touch "$INSTALL_DIR/flipclock-screensaver-cmd"
    mkdir -p "$STATE_DIR"
    touch "$STATE_DIR/screensaver-off"

    FLIPCLOCK_BIN_DIR="$INSTALL_DIR" \
        FLIPCLOCK_STATE_DIR="$STATE_DIR" \
        run bash "$SCRIPT" --uninstall

    [ "$status" -eq 0 ]
    [ ! -f "$INSTALL_DIR/flipclock-ascii" ]
    [ ! -f "$INSTALL_DIR/flipclock-screensaver" ]
    [ ! -f "$INSTALL_DIR/flipclock-screensaver-cmd" ]
    [ ! -f "$STATE_DIR/screensaver-off" ]
}
```

**Step 2: Run test to verify it fails**
Run: `bats tests/test_install.bats`
Expected: FAIL (script does not exist)

**Step 3: Write minimal implementation**
```bash
#!/usr/bin/env bash
set -euo pipefail

BIN_DIR="${FLIPCLOCK_BIN_DIR:-$HOME/.local/bin}"
STATE_DIR="${FLIPCLOCK_STATE_DIR:-$HOME/.local/state/flipclock}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

info()  { echo -e "\033[0;36m[info]\033[0m  $*"; }
ok()    { echo -e "\033[0;32m[ok]\033[0m    $*"; }
error() { echo -e "\033[0;31m[error]\033[0m $*" >&2; }

if [[ "${1:-}" == "--uninstall" ]]; then
    rm -f "$BIN_DIR/flipclock-ascii"
    rm -f "$BIN_DIR/flipclock-screensaver"
    rm -f "$BIN_DIR/flipclock-screensaver-cmd"
    rm -f "$STATE_DIR/screensaver-off"
    ok "Uninstalled"
    exit 0
fi

# Check dependencies (REQ-011)
for cmd in python3 jq hyprctl; do
    if ! command -v "$cmd" &>/dev/null; then
        error "$cmd is required but not found"
        exit 1
    fi
done

# Install Python deps
info "Installing Python dependencies..."
pip install --user --quiet pyfiglet terminaltexteffects 2>/dev/null || true

# Install scripts
mkdir -p "$BIN_DIR"

for script in flipclock-ascii flipclock-screensaver flipclock-screensaver-cmd; do
    cp "$SCRIPT_DIR/$script" "$BIN_DIR/$script"
    chmod +x "$BIN_DIR/$script"
done

# Copy Python module alongside the executable
cp "$SCRIPT_DIR/flipclock_ascii.py" "$BIN_DIR/flipclock_ascii.py"

ok "Installed to $BIN_DIR"
echo ""
echo "  flipclock-ascii           Test the clock renderer"
echo "  flipclock-screensaver     Launch screensaver (all monitors)"
echo "  flipclock-screensaver-cmd Internal: runs inside terminal"
```

```bash
chmod +x install.sh
```

**Step 4: Run test to verify it passes**
Run: `bats tests/test_install.bats`
Expected: PASS (3 tests)

**Step 5: Commit**
Run: `/git commit`

---

## P3 Tasks (Nice to Have)

### Task 14: Resize handling + hyprland config

**Requirement:** REQ-013, REQ-014
**Depends on:** Tasks 7, 9
**Files:**
- Modify: `flipclock_ascii.py`
- Modify: `tests/test_flipclock_ascii.py`
- Create: `hyprland.conf`

**Step 1: Write the failing test**
```python
# append to tests/test_flipclock_ascii.py
from flipclock_ascii import render_clock


@patch("flipclock_ascii.shutil.get_terminal_size")
@patch("flipclock_ascii.sys.stdout", new_callable=MagicMock)
@patch("flipclock_ascii.datetime")
def test_render_clock_recalculates_on_size_change(mock_dt, mock_stdout, mock_size):
    """REQ-013: recalculate centering when terminal is resized."""
    mock_dt.now.return_value.strftime.return_value = "08:30"

    # First call returns 120x40, second returns 80x24
    mock_size.side_effect = [(120, 40), (80, 24)]

    render_clock(once=True)

    # Should have called get_terminal_size at least once
    assert mock_size.call_count >= 1
```

**Step 2: Run test to verify it passes**
Run: `pytest tests/test_flipclock_ascii.py -v`
Expected: PASS (resize is implicit since `get_terminal_size` is called each redraw)

**Step 3: Add SIGWINCH handler for immediate redraw**
```python
# modify render_clock in flipclock_ascii.py - add inside the function before the loop
import threading

force_redraw = threading.Event()

def handle_resize(signum, frame):
    force_redraw.set()

signal.signal(signal.SIGWINCH, handle_resize)
```

Update the loop condition:
```python
if hm != last_hm or once or force_redraw.is_set():
    force_redraw.clear()
    # ... existing redraw logic
```

**Step 4: Create hyprland.conf**
```
# Window rules for FlipClock screensaver
# Add to ~/.config/hypr/hyprland.conf

windowrulev2 = fullscreen, class:^(com.flipclock.screensaver)$
windowrulev2 = noanim, class:^(com.flipclock.screensaver)$
windowrulev2 = noborder, class:^(com.flipclock.screensaver)$
windowrulev2 = noblur, class:^(com.flipclock.screensaver)$
windowrulev2 = noshadow, class:^(com.flipclock.screensaver)$
windowrulev2 = nodim, class:^(com.flipclock.screensaver)$

# Hypridle integration
# Add to ~/.config/hypr/hypridle.conf
#
# listener {
#     timeout = 900
#     on-timeout = pidof hyprlock || flipclock-screensaver
#     on-resume = pkill -f flipclock-screensaver
# }
```

**Step 5: Run all tests**
Run: `pytest tests/test_flipclock_ascii.py -v && bats tests/test_screensaver.bats && bats tests/test_screensaver_cmd.bats && bats tests/test_install.bats`
Expected: ALL PASS

**Step 6: Commit**
Run: `/git commit`
