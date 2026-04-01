#!/usr/bin/env bats

setup() {
    export SCRIPT="$BATS_TEST_DIRNAME/../install.sh"
    export BASH_BIN="$(which bash)"
    export INSTALL_DIR="$BATS_TEST_TMPDIR/install_bin"
    export STATE_DIR="$BATS_TEST_TMPDIR/state/flipclock"
    mkdir -p "$INSTALL_DIR"
}

# Helper: link core utils needed by install.sh
link_coreutils() {
    local dir="$1"
    for util in bash env dirname mkdir cp chmod rm echo cat grep sed cut; do
        local path
        path="$(which "$util" 2>/dev/null || true)"
        if [[ -n "$path" ]]; then
            ln -sf "$path" "$dir/$util"
        fi
    done
}

@test "exits with error when python3 is missing" {
    mkdir -p "$BATS_TEST_TMPDIR/emptybin"
    link_coreutils "$BATS_TEST_TMPDIR/emptybin"

    PATH="$BATS_TEST_TMPDIR/emptybin" FLIPCLOCK_BIN_DIR="$INSTALL_DIR" \
        run "$BASH_BIN" "$SCRIPT"
    [ "$status" -ne 0 ]
    [[ "$output" == *"python3"* ]]
}

@test "installs scripts to bin dir" {
    mkdir -p "$BATS_TEST_TMPDIR/mock_bin"
    link_coreutils "$BATS_TEST_TMPDIR/mock_bin"
    for cmd in python3 pip; do
        cat > "$BATS_TEST_TMPDIR/mock_bin/$cmd" << 'EOF'
#!/bin/bash
true
EOF
        chmod +x "$BATS_TEST_TMPDIR/mock_bin/$cmd"
    done

    # Mock hyprctl with version support
    cat > "$BATS_TEST_TMPDIR/mock_bin/hyprctl" << 'EOF'
#!/bin/bash
case "$1" in
    version) echo '{"version":"0.54.0"}' ;;
    *) true ;;
esac
EOF
    chmod +x "$BATS_TEST_TMPDIR/mock_bin/hyprctl"

    # Mock jq
    JQ_BIN="$(which jq)"
    ln -sf "$JQ_BIN" "$BATS_TEST_TMPDIR/mock_bin/jq"

    # Create a temp hyprland.conf to avoid modifying the real one
    HYPR_TMP="$BATS_TEST_TMPDIR/hyprland.conf"
    echo "# test config" > "$HYPR_TMP"

    PATH="$BATS_TEST_TMPDIR/mock_bin" \
        FLIPCLOCK_BIN_DIR="$INSTALL_DIR" \
        HYPR_CONF="$HYPR_TMP" \
        run "$BASH_BIN" "$SCRIPT"

    [ "$status" -eq 0 ]
    [ -x "$INSTALL_DIR/flipclock-ascii" ]
    [ -x "$INSTALL_DIR/flipclock-screensaver" ]
    [ -x "$INSTALL_DIR/flipclock-screensaver-cmd" ]
}

@test "uninstall removes scripts" {
    touch "$INSTALL_DIR/flipclock-ascii"
    touch "$INSTALL_DIR/flipclock-screensaver"
    touch "$INSTALL_DIR/flipclock-screensaver-cmd"
    mkdir -p "$STATE_DIR"
    touch "$STATE_DIR/screensaver-off"

    FLIPCLOCK_BIN_DIR="$INSTALL_DIR" \
        FLIPCLOCK_STATE_DIR="$STATE_DIR" \
        run "$BASH_BIN" "$SCRIPT" --uninstall

    [ "$status" -eq 0 ]
    [ ! -f "$INSTALL_DIR/flipclock-ascii" ]
    [ ! -f "$INSTALL_DIR/flipclock-screensaver" ]
    [ ! -f "$INSTALL_DIR/flipclock-screensaver-cmd" ]
    [ ! -f "$STATE_DIR/screensaver-off" ]
}
