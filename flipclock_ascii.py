#!/usr/bin/env python3
"""FlipClock ASCII - Terminal clock renderer using pyfiglet."""

import argparse
import shutil
import signal
import sys
import threading
import time
from datetime import datetime

import pyfiglet

FONT = "ansi_shadow"
COLOR_DIGIT = "\033[1;37m"  # Bold white
COLOR_RESET = "\033[0m"
CLEAR = "\033[2J\033[H"  # Clear screen + home
HIDE_CURSOR = "\033[?25l"
SHOW_CURSOR = "\033[?25h"
BG_BLACK = "\033]11;#000000\007"


def parse_args(argv=None):
    """Parse command-line arguments."""
    parser = argparse.ArgumentParser(description="ASCII flip clock renderer")
    parser.add_argument(
        "--once", action="store_true", help="Render single frame and exit"
    )
    return parser.parse_args(argv)


def render_frame(time_str):
    """Render a time string as ASCII art lines using pyfiglet."""
    fig = pyfiglet.Figlet(font=FONT)
    art = fig.renderText(time_str)
    return art.rstrip("\n").split("\n")


def calculate_centering(art_lines, term_cols, term_rows):
    """Calculate top and left padding to center art in terminal."""
    art_height = len(art_lines)
    art_width = max(len(line) for line in art_lines) if art_lines else 0
    pad_top = max(0, (term_rows - art_height) // 2)
    pad_left = max(0, (term_cols - art_width) // 2)
    return pad_top, pad_left


def terminal_setup_sequence():
    """Return ANSI sequence to initialize terminal for clock display."""
    return HIDE_CURSOR + BG_BLACK


def terminal_cleanup_sequence():
    """Return ANSI sequence to restore terminal state."""
    return SHOW_CURSOR + COLOR_RESET


def build_frame(time_str, term_cols, term_rows, once=False):
    """Build a complete frame string for terminal output."""
    lines = render_frame(time_str)
    pad_top, pad_left = calculate_centering(lines, term_cols, term_rows)

    parts = []

    if not once:
        parts.append(CLEAR)
        parts.append("\n" * pad_top)

    for line in lines:
        if once:
            parts.append(f"{line}\n")
        else:
            prefix = " " * pad_left
            parts.append(f"{COLOR_DIGIT}{prefix}{line}{COLOR_RESET}\n")

    return "".join(parts)


def cleanup():
    """Restore terminal state."""
    sys.stdout.write(terminal_cleanup_sequence())
    sys.stdout.flush()


def render_clock(once=False):
    """Main render loop."""

    def handle_signal(signum, frame):
        cleanup()
        sys.exit(0)

    signal.signal(signal.SIGINT, handle_signal)
    signal.signal(signal.SIGTERM, handle_signal)

    # SIGWINCH handler for terminal resize (REQ-013)
    force_redraw = threading.Event()

    def handle_resize(signum, frame):
        force_redraw.set()

    if hasattr(signal, "SIGWINCH"):
        signal.signal(signal.SIGWINCH, handle_resize)

    if not once:
        sys.stdout.write(terminal_setup_sequence())

    last_hm = ""

    try:
        while True:
            now = datetime.now()
            hm = now.strftime("%H:%M")
            cols, rows = shutil.get_terminal_size()

            if hm != last_hm or once or force_redraw.is_set():
                force_redraw.clear()
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
        if not once:
            cleanup()


if __name__ == "__main__":
    args = parse_args()
    render_clock(once=args.once)
