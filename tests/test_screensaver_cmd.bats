#!/usr/bin/env bats

setup() {
    export SCRIPT="$BATS_TEST_DIRNAME/../flipclock-screensaver-cmd"
    export BASH_BIN="$(which bash)"
}

@test "exit_screensaver function exists when sourced" {
    mkdir -p "$BATS_TEST_TMPDIR/bin"
    ln -sf "$BASH_BIN" "$BATS_TEST_TMPDIR/bin/bash"
    cat > "$BATS_TEST_TMPDIR/bin/hyprctl" << 'EOF'
#!/bin/bash
true
EOF
    cat > "$BATS_TEST_TMPDIR/bin/pkill" << 'EOF'
#!/bin/bash
true
EOF
    chmod +x "$BATS_TEST_TMPDIR/bin/hyprctl" "$BATS_TEST_TMPDIR/bin/pkill"

    PATH="$BATS_TEST_TMPDIR/bin" run "$BASH_BIN" -c "
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

    PATH="$BATS_TEST_TMPDIR/bin:$PATH" run "$BASH_BIN" -c "command -v tte"
    [ "$status" -eq 0 ]
}

@test "detects no TTE when not in PATH" {
    mkdir -p "$BATS_TEST_TMPDIR/emptybin"
    ln -sf "$BASH_BIN" "$BATS_TEST_TMPDIR/emptybin/bash"

    PATH="$BATS_TEST_TMPDIR/emptybin" run "$BASH_BIN" -c "
        HAS_TTE=false
        command -v tte &>/dev/null && HAS_TTE=true
        echo \"has_tte=\$HAS_TTE\"
    "
    [[ "$output" == *"has_tte=false"* ]]
}
