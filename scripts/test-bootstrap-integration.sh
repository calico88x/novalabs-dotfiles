
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
NATIVE_BASELINE="$TEST_ROOT/native-baseline.log"

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
    grep -Fq "No changes were made." "$OUTPUT" ||
        fail "Non-mutating preview confirmation missing"
    [[ ! -s "$ERROR" ]] || fail "Unexpected preview diagnostics"
    if grep -q $'\033' "$OUTPUT"; then
        fail "Unexpected ANSI sequences in redirected preview"
    fi
}

require_enhanced() {
    require_preview
    local heading
    for heading in "BOOTSTRAP PREVIEW" "SYSTEM IDENTITY"         "BOOTSTRAP RUNTIME" "HOST ENROLLMENT" "BOOTSTRAP PLAN"         "NATIVE PACKAGE POLICIES" "NAMED-PROFILE PACKAGE BASELINE"         "PORTABLE TOOLS" "PREVIEW COMPLETE"
    do
        grep -Fxq "$heading" "$OUTPUT" || fail "Missing $heading"
    done
    grep -Eq '^  Profile[[:space:]]+Unresolved$' "$OUTPUT" ||
        fail "Host profile was not deferred"
    grep -Eq '^  Mode[[:space:]]+PREVIEW$' "$OUTPUT" || fail "Mode missing"
    grep -Fxq "  [OK] No changes were made." "$OUTPUT" || fail "Completion missing"
    if grep -Fxq "NovaLabs bootstrap preview" "$OUTPUT"; then
        fail "Unexpected native fallback"
    fi
}

require_baseline() {
    require_enhanced
    cmp -s "$BASELINE" "$OUTPUT" || fail "Enhanced preview differs from baseline"
}

require_native() {
    require_preview
    cmp -s "$NATIVE_BASELINE" "$OUTPUT" || fail "Native preview differs from baseline"
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
require_enhanced

cp "$OUTPUT" "$BASELINE"

# Independent native expectation preserving the pre-rendering format.
(
    . /etc/os-release
    cat <<EOF
NovaLabs bootstrap preview

Platform:          Linux
Distribution:      ${ID:-unknown}
Repository:        $FIXTURE

Bootstrap:
  Mise              2026.8.9
  ChezMoi           2.72.1

Native package policies:
  Named Debian-family profiles: full package baseline below
  any on Debian-family Linux:   build-essential, libatomic1
  any on other Linux:           externally managed

Named-profile package baseline:
  - build-essential
  - ca-certificates
  - curl
  - git
  - gzip
  - libatomic1
  - htop
  - openssh-server
  - procps
  - sudo
  - tar
  - tmux
  - vim

Portable tools:
  Managed by the pinned Mise configuration after ChezMoi enrollment.

No changes were made.

Apply with:
  ./install.sh --apply
EOF
) > "$NATIVE_BASELINE"

pass "Production preview baseline"

# 2. Missing presentation library.
reset_fixture

rm -- "$FIXTURE/scripts/lib/bootstrap-ui.sh"

run_installer
require_native

pass "Production preview without presentation library"

# 3. Invalid presentation library syntax.
reset_fixture

printf '%s\n' "if then" \
    > "$FIXTURE/scripts/lib/bootstrap-ui.sh"

run_installer
require_native

pass "Production preview with invalid library syntax"

# 4. Missing required presentation functions.
reset_fixture

cat > "$FIXTURE/scripts/lib/bootstrap-ui.sh" <<'EOF'
nl_ui_init() {
    return 0
}
EOF

run_installer
require_native

pass "Production preview with incomplete library"

# 5. Presentation initialization failure.
reset_fixture

cat >> "$FIXTURE/scripts/lib/bootstrap-ui.sh" <<'EOF'

nl_ui_init() {
    return 42
}
EOF

run_installer
require_native

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
: > "$repo_root/unexpected-init"
printf '%s\n' "UNEXPECTED_LIBRARY_EXECUTION" >&2
exit 42
EOF

run_installer --help
require_status 0

grep -Fq "Usage:" "$OUTPUT" ||
    fail "Help output missing"

[[ ! -s "$ERROR" ]] ||
    fail "Help unexpectedly initialized presentation"

[[ ! -e "$FIXTURE/unexpected-init" ]] || fail "Early guard loaded presentation"

pass "Help exits before presentation initialization"

# 9. Invalid arguments retain their original exit status.
run_installer --invalid-option
require_status 2

grep -Fq "Usage:" "$ERROR" ||
    fail "Invalid argument usage missing"

if grep -Fq "UNEXPECTED_LIBRARY_EXECUTION" "$ERROR"; then
    fail "Invalid arguments initialized presentation"
fi

[[ ! -e "$FIXTURE/unexpected-init" ]] || fail "Early guard loaded presentation"

pass "Invalid argument guard precedes presentation"

# 10. Prune without apply retains its original safety guard.
run_installer --prune
require_status 1

grep -Fq -- "--prune requires --apply" "$ERROR" ||
    fail "Prune safety guard missing"

if grep -Fq "UNEXPECTED_LIBRARY_EXECUTION" "$ERROR"; then
    fail "Prune guard initialized presentation"
fi

[[ ! -e "$FIXTURE/unexpected-init" ]] || fail "Early guard loaded presentation"

pass "Prune safety guard precedes presentation"

# 11. Explicit plain presentation.
reset_fixture

run_installer --plain
require_baseline

pass "Plain presentation argument"

# 12. Explicit animation opt-out.
run_installer --no-animation
require_baseline

pass "No-animation presentation argument"

# 13. Combined presentation arguments.
run_installer --plain --no-animation
require_baseline

run_installer --no-animation --plain
require_baseline

pass "Presentation argument order independence"

# 14. Repeated presentation arguments.
run_installer --plain --plain --no-animation --no-animation
require_baseline

pass "Repeated presentation arguments"

# 15. Updated installer help.
run_installer --help
require_status 0

for option in \
    --apply \
    --prune \
    --plain \
    --no-animation \
    --help
do
    grep -Fq -- "$option" "$OUTPUT" ||
        fail "Help does not document $option"
done

[[ ! -s "$ERROR" ]] ||
    fail "Unexpected help diagnostics"

pass "Presentation CLI help documentation"

# 16. Plain mode does not bypass the prune safety guard.
run_installer --plain --prune
require_status 1

grep -Fq -- "--prune requires --apply" "$ERROR" ||
    fail "Plain mode bypassed prune safety validation"

pass "Plain presentation preserves prune safety"

# 17. Animation opt-out does not bypass the prune safety guard.
run_installer --no-animation --prune
require_status 1

grep -Fq -- "--prune requires --apply" "$ERROR" ||
    fail "No-animation mode bypassed prune safety validation"

pass "No-animation presentation preserves prune safety"

# 18. Presentation arguments work without the optional library.
reset_fixture

rm -- "$FIXTURE/scripts/lib/bootstrap-ui.sh"

run_installer --plain
require_native

run_installer --no-animation
require_native

run_installer --plain --no-animation
require_native

pass "Presentation CLI without optional library"

# 19. Presentation arguments do not suppress argument validation.
reset_fixture

run_installer --plain --invalid-option
require_status 2

run_installer --no-animation --invalid-option
require_status 2

pass "Presentation arguments preserve invalid option rejection"

# 20. Verify actual argument propagation into the adapter.
#
# Instrument only the temporary fixture library. The production
# library and authoritative theme catalog remain unchanged.
reset_fixture

sed -i 's/^nl_ui_init() {/nl_ui_original_init() {/' "$FIXTURE/scripts/lib/bootstrap-ui.sh"
grep -q '^nl_ui_original_init() {' "$FIXTURE/scripts/lib/bootstrap-ui.sh" ||
    fail "Could not instrument initialization"
cat >> "$FIXTURE/scripts/lib/bootstrap-ui.sh" <<'EOF'

nl_ui_init() {
    printf 'plain=%s\nno_animation=%s\n' \
        "$NL_UI_PLAIN" \
        "$NL_UI_NO_ANIMATION" \
        > "$1/cli-state.log"
    nl_ui_original_init "$@"
}
EOF

require_cli_state() {
    local expected_plain="$1"
    local expected_no_animation="$2"

    printf 'plain=%s\nno_animation=%s\n' \
        "$expected_plain" \
        "$expected_no_animation" \
        > "$TEST_ROOT/expected-cli-state.log"

    cmp -s \
        "$TEST_ROOT/expected-cli-state.log" \
        "$FIXTURE/cli-state.log" ||
        fail "Presentation CLI state was not propagated correctly"
}

run_installer
require_baseline
require_cli_state false false

run_installer --plain
require_baseline
require_cli_state true true

run_installer --no-animation
require_baseline
require_cli_state false true

run_installer --plain --no-animation
require_baseline
require_cli_state true true

run_installer --no-animation --plain
require_baseline
require_cli_state true true

pass "Presentation CLI state propagation"

# 21. Rendering failure before any enhanced output.
reset_fixture
cat >> "$FIXTURE/scripts/lib/bootstrap-ui.sh" <<'EOF'
nl_ui_animate_logo() { return 42; }
EOF
run_installer
require_native
pass "Immediate rendering failure native recovery"

# 22. Rendering failure after partial enhanced output.
reset_fixture
cat >> "$FIXTURE/scripts/lib/bootstrap-ui.sh" <<'EOF'
nl_ui_runtime_identity() { return 42; }
EOF
run_installer
require_preview
grep -Fxq "SYSTEM IDENTITY" "$OUTPUT" || fail "Partial output missing"
sed -n '/^NovaLabs bootstrap preview$/,$p' "$OUTPUT" > "$TEST_ROOT/recovered.log"
cmp -s "$NATIVE_BASELINE" "$TEST_ROOT/recovered.log" || fail "Incomplete native recovery"
pass "Partial rendering failure native recovery"

# 23. Runtime versions and package inventory come from installer constants.
reset_fixture
sed -i 's/^MISE_VERSION=.*/MISE_VERSION="fixture-mise"/;s/^CHEZMOI_VERSION=.*/CHEZMOI_VERSION="fixture-chezmoi"/;s/^build-essential$/fixture-package/' "$FIXTURE/install.sh"
run_installer
require_enhanced
grep -Eq '^  Mise target[[:space:]]+fixture-mise$' "$OUTPUT" || fail "Mise pin not propagated"
grep -Eq '^  ChezMoi target[[:space:]]+fixture-chezmoi$' "$OUTPUT" || fail "ChezMoi pin not propagated"
grep -Fxq '  [INFO] fixture-package' "$OUTPUT" || fail "Package inventory not propagated"
pass "Authoritative runtime and package data"

# 24. Preview must not invoke infrastructure tools.
reset_fixture
mkdir -p "$TEST_ROOT/blocked-bin"
for tool in curl wget sudo apt-get mise chezmoi; do
    cat > "$TEST_ROOT/blocked-bin/$tool" <<'EOF'
#!/bin/sh
printf '%s\n' "$0" >> "$PREVIEW_SENTINEL"
exit 99
EOF
    chmod +x "$TEST_ROOT/blocked-bin/$tool"
done
# Include the installer's absolute Mise path in the isolated HOME.
mkdir -p "$TEST_ROOT/home/.local/bin"
cp "$TEST_ROOT/blocked-bin/mise" "$TEST_ROOT/home/.local/bin/mise"
HOME="$TEST_ROOT/home" PATH="$TEST_ROOT/blocked-bin:$PATH" \
    PREVIEW_SENTINEL="$TEST_ROOT/unexpected-command" run_installer
require_enhanced
[[ ! -e "$TEST_ROOT/unexpected-command" ]] || fail "Preview invoked infrastructure tools"
pass "Preview infrastructure command isolation"

printf '%s\n' \
    "============================================================"

printf 'PASS: All %s integration checkpoints validated\n' "$passed"
