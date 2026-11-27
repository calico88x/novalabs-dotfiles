
#!/usr/bin/env bash
# Validate the optional bootstrap presentation adapter.
# No real bootstrap operations are performed.

set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALLER="$ROOT/install.sh"
LIBRARY="$ROOT/scripts/lib/bootstrap-ui.sh"

TEST_ROOT="$(mktemp -d)"
trap 'rm -rf -- "$TEST_ROOT"' EXIT

ADAPTER="$TEST_ROOT/adapter.sh"
FIXTURE="$TEST_ROOT/repository"

passed=0

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

pass() {
    passed=$((passed + 1))
    printf 'PASS: %s\n' "$*"
}

printf '%s\n' \
    "NovaLabs bootstrap adapter validation" \
    "============================================================"

# Extract the actual adapter definitions without executing
# argument parsing or the production bootstrap workflow.
awk '
    /^bootstrap_ui_init\(\) \{/ {
        active = 1
        started++
    }

    active && /^while \[ "\$#" -gt 0 \]; do$/ {
        active = 0
        ended++
    }

    active {
        print
    }

    END {
        if (started != 1 || ended != 1)
            exit 1
    }
' "$INSTALLER" > "$ADAPTER" ||
    fail "Could not extract production adapter"

sh -n "$ADAPTER" ||
    fail "Extracted adapter contains invalid shell syntax"

grep -q '^bootstrap_ui_call() {' "$ADAPTER" ||
    fail "Presentation call adapter missing"

reset_fixture() {
    rm -rf -- "$FIXTURE"

    mkdir -p \
        "$FIXTURE/scripts/lib" \
        "$FIXTURE/.chezmoidata"

    cp "$LIBRARY" \
        "$FIXTURE/scripts/lib/bootstrap-ui.sh"

    cp "$ROOT/.chezmoidata/theme.toml" \
        "$FIXTURE/.chezmoidata/theme.toml"
}

# Execute each scenario in a fresh POSIX shell.
run_probe() {
    sh -eu -c '
        repo_root="$1"

        NL_UI_PLAIN=false
        NL_UI_NO_ANIMATION=false
        bootstrap_ui_available=false

        . "$2"

        bootstrap_ui_init

        eval "$3"
    ' adapter-probe "$FIXTURE" "$ADAPTER" "$1"
}

# 1. Valid library.
reset_fixture

run_probe '
    [ "$bootstrap_ui_available" = true ]
    [ "$NL_UI_PALETTE_READY" = true ]
' || fail "Valid presentation library unavailable"

pass "Valid presentation library initialization"

# 2. Missing library.
reset_fixture

rm -- "$FIXTURE/scripts/lib/bootstrap-ui.sh"

run_probe '
    [ "$bootstrap_ui_available" = false ]
' || fail "Missing library prevented safe fallback"

pass "Missing presentation library fallback"

# 3. Invalid shell syntax.
reset_fixture

printf "%s\n" "if then" \
    > "$FIXTURE/scripts/lib/bootstrap-ui.sh"

run_probe '
    [ "$bootstrap_ui_available" = false ]
' || fail "Malformed shell library was accepted"

pass "Invalid library syntax rejection"

# 4. Missing required presentation functions.
reset_fixture

cat > "$FIXTURE/scripts/lib/bootstrap-ui.sh" <<'EOF'
nl_ui_init() {
    return 0
}
EOF

run_probe '
    [ "$bootstrap_ui_available" = false ]
' || fail "Incomplete presentation library was accepted"

pass "Required function inventory validation"

# 5. Initialization returns failure.
reset_fixture

cat >> "$FIXTURE/scripts/lib/bootstrap-ui.sh" <<'EOF'

nl_ui_init() {
    return 42
}
EOF

run_probe '
    [ "$bootstrap_ui_available" = false ]
' || fail "Initialization failure escaped adapter"

pass "Initialization failure isolation"

# 6. Missing theme catalog.
reset_fixture

rm -- "$FIXTURE/.chezmoidata/theme.toml"

run_probe '
    [ "$bootstrap_ui_available" = true ]
    [ "$NL_UI_PALETTE_READY" = false ]
    [ "$NL_UI_COLOR_MODE" = plain ]
    [ "$NL_UI_ANIMATE" = false ]
' || fail "Missing palette did not select plain presentation"

pass "Missing palette plain-mode fallback"

# 7. Malformed theme catalog.
reset_fixture

printf "%s\n" '[theme.bootstrap]' \
    'slogan = "INVALID 123"' \
    > "$FIXTURE/.chezmoidata/theme.toml"

run_probe '
    [ "$bootstrap_ui_available" = true ]
    [ "$NL_UI_PALETTE_READY" = false ]
    [ "$NL_UI_COLOR_MODE" = plain ]
    [ "$NL_UI_ANIMATE" = false ]
' || fail "Malformed palette did not select plain presentation"

pass "Malformed palette plain-mode fallback"

# 8. Rendering function returns failure.
reset_fixture

run_probe '
    [ "$bootstrap_ui_available" = true ]

    nl_ui_heading() {
        return 42
    }

    bootstrap_ui_call nl_ui_heading "TEST"

    [ "$bootstrap_ui_available" = false ]
' || fail "Rendering failure escaped adapter"

pass "Rendering failure containment"

# 9. Calls after presentation is disabled.
reset_fixture

run_probe '
    nl_ui_heading() {
        return 42
    }

    bootstrap_ui_call nl_ui_heading "TEST"

    [ "$bootstrap_ui_available" = false ]

    invoked=false

    nl_ui_status() {
        invoked=true
    }

    bootstrap_ui_call nl_ui_status info "TEST"

    [ "$invoked" = false ]
' || fail "Disabled presentation executed another function"

pass "Disabled presentation call suppression"

# 10. Non-presentation command rejection.
reset_fixture

run_probe '
    invoked=false

    unrelated_command() {
        invoked=true
    }

    bootstrap_ui_call unrelated_command

    [ "$invoked" = false ]
    [ "$bootstrap_ui_available" = true ]
' || fail "Adapter executed a non-presentation command"

pass "Non-presentation command rejection"

# 11. Stateful presentation calls.
reset_fixture

run_probe '
    [ "$bootstrap_ui_available" = true ]

    bootstrap_ui_call nl_ui_tracker_init 2

    bootstrap_ui_call nl_ui_stage_begin "First stage"
    bootstrap_ui_call nl_ui_stage_pass "Completed"

    bootstrap_ui_call nl_ui_stage_begin "Second stage"
    bootstrap_ui_call nl_ui_stage_skip "Not required"

    [ "$bootstrap_ui_available" = true ]

    summary="$(nl_ui_summary 0)"

    printf "%s\n" "$summary" |
        grep -q "BOOTSTRAP COMPLETE"

    printf "%s\n" "$summary" |
        grep -Eq "Stages processed[[:space:]]+2/2"
' > "$TEST_ROOT/tracker-output.log" ||
    fail "Stage tracking state was not preserved"

pass "Presentation tracker state preservation"

printf '%s\n' \
    "============================================================"

printf 'PASS: All %s adapter checkpoints validated\n' "$passed"
