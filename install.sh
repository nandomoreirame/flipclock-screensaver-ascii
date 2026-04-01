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
