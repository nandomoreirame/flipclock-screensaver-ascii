#!/usr/bin/env bats

setup() {
    export SCRIPT="$BATS_TEST_DIRNAME/../flipclock-screensaver"
    export BASH_BIN="$(which bash)"
}

# Helper: create a minimal mock bin dir with bash and env
create_mock_bin() {
    mkdir -p "$BATS_TEST_TMPDIR/bin"
    ln -sf "$BASH_BIN" "$BATS_TEST_TMPDIR/bin/bash"
    ln -sf "$(which env)" "$BATS_TEST_TMPDIR/bin/env"
}

@test "exits with error when hyprctl is missing" {
    create_mock_bin
    cat > "$BATS_TEST_TMPDIR/bin/jq" << 'EOF'
#!/bin/bash
echo "mock"
EOF
    chmod +x "$BATS_TEST_TMPDIR/bin/jq"

    PATH="$BATS_TEST_TMPDIR/bin" run "$BASH_BIN" "$SCRIPT"
    [ "$status" -ne 0 ]
    [[ "$output" == *"hyprctl"* ]]
}

@test "exits with error when jq is missing" {
    create_mock_bin
    cat > "$BATS_TEST_TMPDIR/bin/hyprctl" << 'EOF'
#!/bin/bash
echo "mock"
EOF
    chmod +x "$BATS_TEST_TMPDIR/bin/hyprctl"

    PATH="$BATS_TEST_TMPDIR/bin" run "$BASH_BIN" "$SCRIPT"
    [ "$status" -ne 0 ]
    [[ "$output" == *"jq"* ]]
}

@test "detects terminal via xdg-terminal-exec" {
    create_mock_bin

    cat > "$BATS_TEST_TMPDIR/bin/hyprctl" << 'MOCK'
#!/bin/bash
case "$1" in
    monitors) echo '[]' ;;
    dispatch) true ;;
esac
MOCK
    chmod +x "$BATS_TEST_TMPDIR/bin/hyprctl"

    cat > "$BATS_TEST_TMPDIR/bin/jq" << 'MOCK'
#!/bin/bash
cat > /dev/null
echo ""
MOCK
    chmod +x "$BATS_TEST_TMPDIR/bin/jq"

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

    PATH="$BATS_TEST_TMPDIR/bin" run "$BASH_BIN" "$SCRIPT"
    [ "$status" -eq 0 ]
}

@test "spawns terminal for each monitor" {
    create_mock_bin
    JQ_BIN="$(which jq)"

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

    ln -sf "$JQ_BIN" "$BATS_TEST_TMPDIR/bin/jq"

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

    PATH="$BATS_TEST_TMPDIR/bin" run "$BASH_BIN" "$SCRIPT"
    [ "$status" -eq 0 ]
    [ -f "$BATS_TEST_TMPDIR/dispatches.log" ]
    exec_count=$(grep -c "exec" "$BATS_TEST_TMPDIR/dispatches.log")
    [ "$exec_count" -eq 2 ]
}

@test "exits silently when already running" {
    create_mock_bin
    for cmd in hyprctl jq xdg-terminal-exec; do
        cat > "$BATS_TEST_TMPDIR/bin/$cmd" << 'EOF'
#!/bin/bash
echo "mock"
EOF
        chmod +x "$BATS_TEST_TMPDIR/bin/$cmd"
    done

    cat > "$BATS_TEST_TMPDIR/bin/pgrep" << 'EOF'
#!/bin/bash
echo "12345"
exit 0
EOF
    chmod +x "$BATS_TEST_TMPDIR/bin/pgrep"

    PATH="$BATS_TEST_TMPDIR/bin" run "$BASH_BIN" "$SCRIPT"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "exits when toggle file exists" {
    create_mock_bin
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
        PATH="$BATS_TEST_TMPDIR/bin" run "$BASH_BIN" "$SCRIPT"
    [ "$status" -eq 0 ]
}

@test "launches when toggle exists but force is passed" {
    create_mock_bin
    mkdir -p "$BATS_TEST_TMPDIR/state/flipclock"
    touch "$BATS_TEST_TMPDIR/state/flipclock/screensaver-off"
    JQ_BIN="$(which jq)"

    cat > "$BATS_TEST_TMPDIR/bin/hyprctl" << 'EOF'
#!/bin/bash
case "$1" in
    monitors) echo '[{"name":"DP-1","focused":true}]' ;;
    dispatch) echo "$@" >> "$BATS_TEST_TMPDIR/dispatches_force.log" ;;
esac
EOF
    chmod +x "$BATS_TEST_TMPDIR/bin/hyprctl"
    ln -sf "$JQ_BIN" "$BATS_TEST_TMPDIR/bin/jq"

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
        PATH="$BATS_TEST_TMPDIR/bin" run "$BASH_BIN" "$SCRIPT" force
    [ -f "$BATS_TEST_TMPDIR/dispatches_force.log" ]
}
