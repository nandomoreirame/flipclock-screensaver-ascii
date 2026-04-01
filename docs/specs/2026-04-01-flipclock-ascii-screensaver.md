# Spec: FlipClock ASCII Screensaver

## Problem Statement

There is no ASCII clock screensaver for Hyprland/Wayland terminals. Omarchy provides a static-text screensaver with TTE effects but no time display. Users who want a functional screensaver showing the time in a vintage flip clock style need an independent alternative.

## Goals

- Display `HH:MM` in ASCII art using a flip clock aesthetic, centered and readable from a distance
- Support multiple monitors simultaneously via Hyprland
- Apply TTE visual effects as transitions on minute changes
- Work without TTE installed (graceful degradation, no effects)
- Integrate with hypridle for automatic activation on idle

## Context

Omarchy implements a multi-monitor screensaver pattern with 2 shell scripts: a launcher that spawns fullscreen terminals per monitor and a content runner that executes the visual content. FlipClock follows the same architectural pattern but replaces static text with a Python renderer that generates the ASCII clock dynamically. Both screensavers coexist; the user chooses which to activate in hypridle.

## Requirements

### P1 (MVP)

1. **[REQ-001]** WHEN `flipclock-ascii` is executed THEN system SHALL render `HH:MM` in ASCII art using pyfiglet with font `ansi_shadow`, bold white on black background, centered horizontally and vertically in the terminal

2. **[REQ-002]** WHEN `flipclock-ascii` is executed with `--once` flag THEN system SHALL render a single frame to stdout and exit (for piping to TTE)

3. **[REQ-003]** WHEN `flipclock-ascii` is running and the minute changes THEN system SHALL redraw the clock display. Between minute changes, the display remains static.

4. **[REQ-004]** WHEN `flipclock-ascii` receives SIGINT or SIGTERM THEN system SHALL restore cursor visibility, reset terminal colors, and exit cleanly

5. **[REQ-005]** WHEN `flipclock-screensaver` is executed THEN system SHALL detect all connected monitors via `hyprctl monitors -j`, detect the default terminal via `xdg-terminal-exec --print-id`, and spawn one fullscreen terminal per monitor with window class `com.flipclock.screensaver`

6. **[REQ-006]** WHEN `flipclock-screensaver-cmd` is running and the minute changes and TTE is available THEN system SHALL pipe a new `flipclock-ascii --once` frame through TTE with a random effect as a visual transition

7. **[REQ-007]** WHEN `flipclock-screensaver-cmd` is running and TTE is NOT available THEN system SHALL run `flipclock-ascii` directly without effects (graceful degradation)

8. **[REQ-008]** WHEN the screensaver terminal loses focus or receives keyboard input THEN system SHALL exit the screensaver, restore cursor, and kill related processes

### P2 (Should Have)

9. **[REQ-009]** WHEN `flipclock-screensaver` is executed and the toggle file `~/.local/state/flipclock/screensaver-off` exists THEN system SHALL exit without launching, UNLESS the first argument is `force`

10. **[REQ-010]** WHEN `flipclock-screensaver` is executed and another instance is already running (detected via `pgrep -f flipclock-screensaver-cmd`) THEN system SHALL exit silently without spawning duplicates

11. **[REQ-011]** WHEN `install.sh` is executed THEN system SHALL verify dependencies (`python3`, `jq`, `hyprctl`), install Python packages (`pyfiglet`, `terminaltexteffects`), and copy the 3 scripts to `~/.local/bin/` with executable permissions

12. **[REQ-012]** WHEN `install.sh --uninstall` is executed THEN system SHALL remove the 3 scripts from `~/.local/bin/` and the toggle state file if it exists

### P3 (Nice to Have)

13. **[REQ-013]** WHEN the terminal is resized while `flipclock-ascii` is running THEN system SHALL recalculate centering and redraw on the next update cycle

14. **[REQ-014]** WHEN `flipclock-screensaver` finishes launching terminals THEN system SHALL restore focus to the monitor that was focused before launch

## Edge Cases

- **Terminal too small** - If terminal columns are smaller than ASCII art width, pyfiglet wraps automatically. Result may be illegible but will not crash.
- **pyfiglet not installed** - `flipclock-ascii` displays error message to stderr and exits with code 1.
- **No supported terminal** - If `xdg-terminal-exec --print-id` does not return a recognized terminal (ghostty/alacritty/kitty), displays `notify-send` error and exits.
- **Hyprland not available** - `hyprctl` fails silently. The launcher checks dependencies at start and exits with error if `hyprctl` or `jq` are not present.
- **TTE hangs or takes too long** - The content runner monitors the TTE process. If the user presses a key or focus is lost during animation, kills TTE and exits.
- **Screensaver already running** - REQ-010 prevents duplicates via `pgrep`.

## Architecture Decisions

1. **3 separate scripts** - Chosen over monolithic script. Allows testing the Python renderer in isolation (`flipclock-ascii --once`), reusing the launcher for other content, and maintaining clear responsibilities. Alternative discarded: single Go/Python script that does everything (less flexible, more complex).

2. **Python + pyfiglet for rendering** - Chosen over native figlet CLI for portability and programmatic control (centering, ANSI colors). Alternative discarded: pure bash with heredoc art (inflexible, hard to maintain).

3. **`xdg-terminal-exec --print-id` for detection** - Chosen over manual detection in fixed sequence. Respects user preference. Omarchy standard.

4. **TTE only on minute change** - Chosen over continuous TTE (loop every frame). Keeps time accurate between transitions. Visual effect marks the passage of time without compromising readability.

5. **Window class `com.flipclock.screensaver`** - Allows specific Hyprland window rules (fullscreen, noborder, noanim) without affecting other terminals.

## Constraints

- Requires Hyprland compositor (Wayland). Does not support X11 or other compositors.
- Requires one of: ghostty, alacritty, or kitty.
- Python 3 required. pyfiglet required. TTE optional.
- `jq` and `hyprctl` required for the launcher.
- `xdg-terminal-exec` must be available on the system.

## Out of Scope

| Item | Reason |
|------|--------|
| X11/Sway/other compositor support | Project focused on Hyprland |
| Font/color configuration via flags | Keep simplicity; `ansi_shadow` font and white/black are fixed |
| Date/day of week in display | Scope is flip clock (`HH:MM`) |
| Direct Omarchy integration | Coexists as independent alternative |
| Quit Walker before launch | Not FlipClock's responsibility |
| Time notifications | Screensaver is passive, display only |
| Wayland support without Hyprland | Depends on `hyprctl` for monitor detection |

## Test Strategy

- **Unit (Python/pytest):** Arg parsing (`--once`), rendering with pyfiglet (mock terminal size), vertical/horizontal centering, terminal cleanup (cursor restore, color reset)
- **Unit (Shell/bats-core):** Terminal detection, dependency validation, toggle on/off logic, duplicate instance detection
- **Manual:** Visual rendering in real terminal, multi-monitor with Hyprland, TTE transition on minute change, exit by key/focus

## Requirement Traceability

| ID | Description | Priority | Status |
|----|-------------|----------|--------|
| REQ-001 | Render HH:MM ASCII art centered with ansi_shadow | P1 | Pending |
| REQ-002 | --once flag for single frame (TTE pipe) | P1 | Pending |
| REQ-003 | Redraw only on minute change | P1 | Pending |
| REQ-004 | Clean exit with terminal restore | P1 | Pending |
| REQ-005 | Multi-monitor launcher via hyprctl | P1 | Pending |
| REQ-006 | TTE random effect as minute transition | P1 | Pending |
| REQ-007 | Graceful degradation without TTE | P1 | Pending |
| REQ-008 | Exit on focus loss or input | P1 | Pending |
| REQ-009 | Toggle on/off via state file | P2 | Pending |
| REQ-010 | Duplicate instance prevention | P2 | Pending |
| REQ-011 | Installer with dependency verification | P2 | Pending |
| REQ-012 | Uninstaller | P2 | Pending |
| REQ-013 | Recalculate centering on resize | P3 | Pending |
| REQ-014 | Restore focus to original monitor | P3 | Pending |
