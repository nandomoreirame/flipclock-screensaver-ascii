# Changelog

All notable changes to this project will be documented in this file.

This project adheres to [Keep a Changelog](https://keepachangelog.com/en/1.0.0/) and follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

## [0.1.0] - 2026-04-01

### Added

- Add ASCII clock renderer using pyfiglet with `ansi_shadow` font, centered in terminal with bold white on black.
- Add `--once` flag for single-frame output suitable for TTE piping.
- Add multi-monitor launcher that detects monitors via `hyprctl` and spawns fullscreen terminals.
- Add content runner with TTE random effects on minute change and graceful degradation without TTE.
- Add installer with dependency verification, version-aware Hyprland window rules, and uninstall support.
- Add toggle on/off via state file and duplicate instance prevention.
- Add SIGWINCH handler for terminal resize redraw.
- Add Hyprland window rules reference config.
- Add pytest (18 tests) and bats-core (13 tests) test suites covering all components.

### Fixed

- Fix `--once` mode leaking ANSI setup/cleanup sequences into TTE pipe.
- Harden `flipclock-screensaver-cmd` with `set -uo pipefail` and PID tracking for background processes.
- Deduplicate `exit_screensaver` function definition in content runner.
- Separate required (`pyfiglet`) from optional (`terminaltexteffects`) pip installs with proper error reporting.
- Add friendly `ImportError` handler for missing pyfiglet dependency.
- Cache `Figlet` instance to avoid per-frame re-instantiation.
- Use `while read` loop instead of `for in $(...)` for safer monitor iteration.
