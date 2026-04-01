# FlipClock ASCII Screensaver

Terminal-based ASCII flip clock screensaver for Hyprland/Wayland. Renders `HH:MM` in large ASCII art with TTE (Terminal Text Effects) transitions on minute changes. Multi-monitor support.

```
 ██████╗  █████╗    ██████╗  ██████╗
██╔═████╗██╔══██╗██╗╚════██╗██╔═████╗
██║██╔██║╚█████╔╝╚═╝ █████╔╝██║██╔██║
████╔╝██║██╔══██╗██╗ ╚═══██╗████╔╝██║
╚██████╔╝╚█████╔╝╚═╝██████╔╝╚██████╔╝
 ╚═════╝  ╚════╝    ╚═════╝  ╚═════╝
```

## Dependencies

- Python 3.10+
- [pyfiglet](https://pypi.org/project/pyfiglet/) - ASCII art rendering
- [TTE](https://pypi.org/project/terminaltexteffects/) - visual transition effects (optional)
- [jq](https://jqlang.github.io/jq/) - JSON processing
- [Hyprland](https://hyprland.org/) compositor
- One of: [ghostty](https://ghostty.org/), [alacritty](https://alacritty.org/), or [kitty](https://sw.kovidgoez.net/kitty/)

## Install

```bash
bash install.sh
```

This installs three scripts to `~/.local/bin/`:

| Script | Purpose |
|--------|---------|
| `flipclock-ascii` | ASCII clock renderer |
| `flipclock-screensaver` | Multi-monitor launcher |
| `flipclock-screensaver-cmd` | Content runner (internal) |

## Usage

```bash
# Launch screensaver on all monitors
flipclock-screensaver

# Force launch (ignores toggle-off state)
flipclock-screensaver force

# Test the renderer directly
flipclock-ascii           # continuous mode (Ctrl+C to exit)
flipclock-ascii --once    # single frame to stdout
```

## Hypridle Integration

Add to `~/.config/hypr/hypridle.conf`:

```
listener {
    timeout = 900
    on-timeout = pidof hyprlock || flipclock-screensaver
    on-resume = pkill -f flipclock-screensaver
}
```

## Hyprland Window Rules

Add to `~/.config/hypr/hyprland.conf` (or copy from `hyprland.conf`):

```
windowrulev2 = fullscreen, class:^(com.flipclock.screensaver)$
windowrulev2 = noanim, class:^(com.flipclock.screensaver)$
windowrulev2 = noborder, class:^(com.flipclock.screensaver)$
windowrulev2 = noblur, class:^(com.flipclock.screensaver)$
windowrulev2 = noshadow, class:^(com.flipclock.screensaver)$
windowrulev2 = nodim, class:^(com.flipclock.screensaver)$
```

## Toggle On/Off

```bash
# Disable screensaver
mkdir -p ~/.local/state/flipclock
touch ~/.local/state/flipclock/screensaver-off

# Re-enable
rm ~/.local/state/flipclock/screensaver-off
```

## Development

```bash
# Install dev dependencies
pip install --user pytest pytest-cov pyfiglet
npm install -g bats  # or: pacman -S bash-bats

# Run tests
pytest tests/ -v            # Python tests
bats tests/*.bats           # Shell tests
```

## Uninstall

```bash
bash install.sh --uninstall
```

## How It Works

1. `flipclock-screensaver` detects all monitors and the default terminal
2. Spawns a fullscreen terminal on each monitor running `flipclock-screensaver-cmd`
3. The content runner renders the clock via `flipclock-ascii --once`
4. When TTE is available, the output is piped through TTE with a random visual effect
5. On minute change, a new frame is rendered with a fresh TTE transition
6. Without TTE, the clock renders directly with real-time updates
7. Any keyboard input or focus loss exits the screensaver

## License

MIT
