
#!/usr/bin/env bash
# Validate the production bootstrap presentation integration.
#
# All installer executions use isolated repository fixtures.
# No enrollment, installation or system reconciliation is performed.

set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

TEST_ROOT="$(mktemp -d)"
trap 'rm -rf -- "$TEST_ROOT"' EXIT

FIXTURE="$TEST_ROOT/repository"
OUTPUT="$TEST_ROOT/output.log"
ERROR="$TEST_ROOT/error.log"
BASELINE="$TEST_ROOT/baseline.log"

passed=0

fail() {
    printf 'FAIL: %s\n' "$*" >&2

    if [[ -f "$OUTPUT" ]]; then
        printf '\n--- Standard output ---\n' >&2
        cat "$OUTPUT" >&2
    fi

    if [[ -f "$ERROR" ]]; then
        printf '\n--- Standard error ---\n' >&2
        cat "$ERROR" >&2
    fi

    exit 1
}

pass() {
    passed=$((passed + 1))
    printf 'PASS: %s\n' "$*"
}

reset_fixture() {
    rm -rf -- "$FIXTURE"

    mkdir -p \
        "$FIXTURE/scripts/lib" \
        "$FIXTURE/.chezmoidata"

    cp "$ROOT/install.sh" \
        "$FIXTURE/install.sh"

    cp "$ROOT/scripts/lib/bootstrap-ui.sh" \
        "$FIXTURE/scripts/lib/bootstrap-ui.sh"

    cp "$ROOT/.chezmoidata/theme.toml" \
        "$FIXTURE/.chezmoidata/theme.toml"
}

run_installer() {
    actual_status=0

    sh "$FIXTURE/install.sh" "$@" \
        > "$OUTPUT" \
        2> "$ERROR" ||
        actual_status=$?
}

require_status() {
    local expected="$1"

    [[ "$actual_status" -eq "$expected" ]] ||
        fail "Expected exit status $expected, got $actual_status"
}

require_preview() {
    require_status 0

    grep -Fq "NovaLabs bootstrap preview" "$OUTPUT" ||
        fail "Original preview heading missing"

    grep -Fq "Native package policies:" "$OUTPUT" ||
        fail "Native package policy information missing"

    grep -Fq "No changes were made." "$OUTPUT" ||
        fail "Non-mutating preview confirmation missing"

    [[ ! -s "$ERROR" ]] ||
        fail "Unexpected preview diagnostics"

    if grep -q $'\033' "$OUTPUT"; then
        fail "Unexpected ANSI sequences in redirected preview"
    fi
}

require_baseline() {
    require_preview

    cmp -s "$BASELINE" "$OUTPUT" ||
        fail "Preview output differs from the baseline"
}

printf '%s\n' \
    "NovaLabs bootstrap integration validation" \
    "============================================================"

if [[ "$(id -u)" -eq 0 ]]; then
    fail "Integration tests must run as a normal user"
fi

if [[ "$(uname -s)" != Linux ]]; then
    fail "Current integration fixtures require Linux"
fi

# 1. Valid production preview.
reset_fixture
run_installer
require_preview

cp "$OUTPUT" "$BASELINE"

pass "Production preview baseline"

# 2. Missing presentation library.
reset_fixture

rm -- "$FIXTURE/scripts/lib/bootstrap-ui.sh"

run_installer
require_baseline

pass "Production preview without presentation library"

# 3. Invalid presentation library syntax.
reset_fixture

printf '%s\n' "if then" \
    > "$FIXTURE/scripts/lib/bootstrap-ui.sh"

run_installer
require_baseline

pass "Production preview with invalid library syntax"

# 4. Missing required presentation functions.
reset_fixture

cat > "$FIXTURE/scripts/lib/bootstrap-ui.sh" <<'EOF'
nl_ui_init() {
    return 0
}
EOF

run_installer
require_baseline

pass "Production preview with incomplete library"

# 5. Presentation initialization failure.
reset_fixture

cat >> "$FIXTURE/scripts/lib/bootstrap-ui.sh" <<'EOF'

nl_ui_init() {
    return 42
}
EOF

run_installer
require_baseline

pass "Production preview after initialization failure"

# 6. Missing theme catalog.
reset_fixture

rm -- "$FIXTURE/.chezmoidata/theme.toml"

run_installer
require_baseline

pass "Production preview without theme catalog"

# 7. Malformed theme catalog.
reset_fixture

printf '%s\n' \
    '[theme.bootstrap]' \
    'slogan = "INVALID 123"' \
    > "$FIXTURE/.chezmoidata/theme.toml"

run_installer
require_baseline

pass "Production preview with malformed theme catalog"

# 8. Help remains available before presentation initialization.
reset_fixture

cat > "$FIXTURE/scripts/lib/bootstrap-ui.sh" <<'EOF'
printf '%s\n' "UNEXPECTED_LIBRARY_EXECUTION" >&2
exit 42
EOF

run_installer --help
require_status 0

grep -Fq "Usage:" "$OUTPUT" ||
    fail "Help output missing"

[[ ! -s "$ERROR" ]] ||
    fail "Help unexpectedly initialized presentation"

pass "Help exits before presentation initialization"

# 9. Invalid arguments retain their original exit status.
run_installer --invalid-option
require_status 2

grep -Fq "Usage:" "$ERROR" ||
    fail "Invalid argument usage missing"

if grep -Fq "UNEXPECTED_LIBRARY_EXECUTION" "$ERROR"; then
    fail "Invalid arguments initialized presentation"
fi

pass "Invalid argument guard precedes presentation"

# 10. Prune without apply retains its original safety guard.
run_installer --prune
require_status 1

grep -Fq -- "--prune requires --apply" "$ERROR" ||
    fail "Prune safety guard missing"

if grep -Fq "UNEXPECTED_LIBRARY_EXECUTION" "$ERROR"; then
    fail "Prune guard initialized presentation"
fi

pass "Prune safety guard precedes presentation"

printf '%s\n' \
    "============================================================"

printf 'PASS: All %s integration checkpoints validated\n' "$passed"
