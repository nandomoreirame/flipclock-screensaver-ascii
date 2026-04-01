# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Terminal-based ASCII flip clock screensaver for Hyprland/Wayland. Multi-monitor support with TTE (Terminal Text Effects) transition animations on minute changes. Independent alternative to the Omarchy screensaver, coexisting via hypridle configuration.

## Architecture

Three executable scripts forming a pipeline:

1. **`flipclock-screensaver`** (Bash) - Multi-monitor launcher. Detects monitors via `hyprctl monitors -j`, detects terminal via `xdg-terminal-exec --print-id`, spawns one fullscreen terminal per monitor with window class `com.flipclock.screensaver`. Supports toggle on/off via state file and duplicate prevention via pgrep.
2. **`flipclock-screensaver-cmd`** (Bash) - Content runner inside each spawned terminal. On minute change: pipes `flipclock-ascii --once` through TTE with random effect. Without TTE: runs `flipclock-ascii` directly. Exits on keyboard input or focus loss.
3. **`flipclock-ascii`** (Python wrapper) / **`flipclock_ascii.py`** (module) - Clock renderer. Uses pyfiglet with `ansi_shadow` font to render `HH:MM` centered in terminal. Bold white on black. `--once` outputs clean text (no ANSI) for TTE piping. SIGWINCH triggers redraw on resize.

Key design: `flipclock-ascii` is a thin wrapper importing from `flipclock_ascii.py`. All logic lives in the module for testability.

## Commands

```bash
# Run all Python tests
pytest tests/test_flipclock_ascii.py -v

# Run a single Python test
pytest tests/test_flipclock_ascii.py::test_render_frame_returns_lines -v

# Run all bats (shell) tests
bats tests/test_screensaver.bats tests/test_screensaver_cmd.bats tests/test_install.bats

# Run a single bats test file
bats tests/test_screensaver.bats

# Run everything
pytest tests/ -v && bats tests/*.bats

# Test renderer manually
./flipclock-ascii --once    # single frame to stdout
./flipclock-ascii           # continuous mode (Ctrl+C to exit)

# Install to ~/.local/bin
bash install.sh

# Uninstall
bash install.sh --uninstall
```

## Dependencies

- **System:** `python3`, `jq`, `hyprctl` (Hyprland), `xdg-terminal-exec`
- **Python:** `pyfiglet` (required), `terminaltexteffects` (optional, for TTE effects)
- **Test:** `pytest`, `pytest-cov`, `bats` (bash-bats)
- **Terminals:** ghostty, alacritty, or kitty

## Testing Notes

- Bats tests mock external commands by creating restricted `PATH` dirs with only needed binaries. Mock scripts must `cat > /dev/null` on stdin to avoid SIGPIPE with `set -o pipefail`.
- Shell scripts use `FLIPCLOCK_STATE_DIR` and `FLIPCLOCK_BIN_DIR` env vars for test overrides.
- `flipclock-screensaver-cmd` supports `--source-only` flag to source functions for testing without executing the main loop.

## Hyprland Integration

Window class `com.flipclock.screensaver` used for Hyprland window rules (fullscreen, noanim, noborder). Reference config in `hyprland.conf`. Toggle screensaver off by creating `~/.local/state/flipclock/screensaver-off`; override with `flipclock-screensaver force`.
