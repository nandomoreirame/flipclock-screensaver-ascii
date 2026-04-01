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
    rm -f "$BIN_DIR/flipclock_ascii.py"
    rm -f "$STATE_DIR/screensaver-off"

    # Remove Hyprland window rules
    HYPR_CONF="${HYPR_CONF:-$HOME/.config/hypr/hyprland.conf}"
    if [[ -f "$HYPR_CONF" ]] && grep -q "com.flipclock.screensaver" "$HYPR_CONF" 2>/dev/null; then
        sed -i '/# FlipClock screensaver/d;/com\.flipclock\.screensaver/d' "$HYPR_CONF"
        info "Window rules removed from $HYPR_CONF"
    fi

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
if ! pip install --user --quiet pyfiglet 2>/dev/null; then
    error "Failed to install pyfiglet (required dependency)"
    exit 1
fi
pip install --user --quiet terminaltexteffects 2>/dev/null || info "TTE not installed (optional, effects disabled)"

# Install scripts
mkdir -p "$BIN_DIR"

for script in flipclock-ascii flipclock-screensaver flipclock-screensaver-cmd; do
    cp "$SCRIPT_DIR/$script" "$BIN_DIR/$script"
    chmod +x "$BIN_DIR/$script"
done

# Copy Python module alongside the executable
cp "$SCRIPT_DIR/flipclock_ascii.py" "$BIN_DIR/flipclock_ascii.py"

# Install Hyprland window rules (idempotent, version-aware)
HYPR_CONF="${HYPR_CONF:-$HOME/.config/hypr/hyprland.conf}"
if [[ -f "$HYPR_CONF" ]]; then
    if ! grep -q "com.flipclock.screensaver" "$HYPR_CONF" 2>/dev/null; then
        # Detect Hyprland version to pick correct syntax
        # >= 0.45: new syntax (windowrule = ... match:class ...)
        # <  0.45: legacy syntax (windowrulev2 = ..., class:^(...)$)
        HYPR_VER=$(hyprctl version -j 2>/dev/null | jq -r '.version // "0.0.0"')
        HYPR_MAJOR=$(echo "$HYPR_VER" | cut -d. -f1)
        HYPR_MINOR=$(echo "$HYPR_VER" | cut -d. -f2)

        info "Hyprland $HYPR_VER detected, adding window rules..."

        if [[ "$HYPR_MAJOR" -gt 0 ]] || [[ "$HYPR_MINOR" -ge 45 ]]; then
            cat >> "$HYPR_CONF" << 'RULES'

# FlipClock screensaver
windowrule = fullscreen on, match:class com.flipclock.screensaver
windowrule = float on, match:class com.flipclock.screensaver
RULES
        else
            cat >> "$HYPR_CONF" << 'RULES'

# FlipClock screensaver
windowrulev2 = fullscreen, class:^(com.flipclock.screensaver)$
windowrulev2 = float, class:^(com.flipclock.screensaver)$
RULES
        fi
        ok "Window rules added to $HYPR_CONF"
    else
        info "Window rules already present in $HYPR_CONF"
    fi
else
    info "Hyprland config not found at $HYPR_CONF, skipping window rules"
fi

ok "Installed to $BIN_DIR"
echo ""
echo "  flipclock-ascii           Test the clock renderer"
echo "  flipclock-screensaver     Launch screensaver (all monitors)"
echo "  flipclock-screensaver-cmd Internal: runs inside terminal"
