
#!/usr/bin/env bash
# Validate NovaLabs bootstrap branding and presentation.
# No installation or system mutation is performed.

set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
LIB="$ROOT/scripts/lib/bootstrap-ui.sh"
PREVIEW="$ROOT/scripts/preview-bootstrap-ui.sh"

TEST_ROOT="$(mktemp -d /tmp/novalabs-bootstrap-ui.XXXXXXXX)"
trap 'rm -rf -- "$TEST_ROOT"' EXIT

passed=0

pass() {
    printf 'PASS: %s\n' "$1"
    passed=$((passed + 1))
}

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

printf 'NovaLabs bootstrap presentation validation\n'
printf '%s\n' '============================================================'

# 1. POSIX shell syntax.
sh -n "$LIB"
sh -n "$PREVIEW"
pass "POSIX shell syntax"

# Load the presentation library.
source "$LIB"

# 2. Authoritative palette.
nl_ui_load_palette "$ROOT" ||
    fail "Unable to load centralized theme catalog"

[[ "$NL_UI_SLOGAN" == "DECLARATIVE INFRASTRUCTURE" ]] ||
    fail "Unexpected brand slogan"

pass "Centralized brand palette and slogan"

# 3. RGB validation.
nl_ui_valid_hex "#FBDD49" ||
    fail "Valid RGB color rejected"

for invalid in "" "#FFF" "#GG0000" "FBDD49" "#1234567"; do
    if nl_ui_valid_hex "$invalid"; then
        fail "Invalid RGB color accepted: $invalid"
    fi
done

pass "RGB validation"

# 4. Truecolor escape sequence.
NL_UI_COLOR_MODE=truecolor

actual="$(nl_ui_color '#FF0000' 31)"

[[ "$actual" == $'\033[38;2;255;0;0m' ]] ||
    fail "Incorrect truecolor sequence"

pass "Truecolor rendering"

# 5. ANSI 256-color escape sequence.
NL_UI_COLOR_MODE=256

actual="$(nl_ui_color '#FF0000' 31)"

[[ "$actual" == $'\033[38;5;196m' ]] ||
    fail "Incorrect 256-color sequence"

pass "ANSI 256-color rendering"

# 6. Basic ANSI escape sequence.
NL_UI_COLOR_MODE=ansi

actual="$(nl_ui_color '#FF0000' 31)"

[[ "$actual" == $'\033[31m' ]] ||
    fail "Incorrect basic ANSI sequence"

pass "Basic ANSI rendering"

# 7. Plain rendering.
NL_UI_COLOR_MODE=plain

actual="$(nl_ui_text '#FF0000' 31 'Example')"

[[ "$actual" == "Example" ]] ||
    fail "Plain rendering introduced control sequences"

pass "Plain text rendering"

# 8. Bitmap dimensions.
bitmap="$(nl_ui_bitmap NOVALABS)"

[[ "$(printf '%s\n' "$bitmap" | wc -l)" -eq 5 ]] ||
    fail "Incorrect logo height"

printf '%s\n' "$bitmap" |
    awk '
        length($0) != 63 || $0 ~ /[^01]/ {
            invalid = 1
        }
        END {
            exit invalid
        }
    ' || fail "Incorrect logo bitmap dimensions"

pass "Five-row, 63-column logo bitmap"

# 9. Missing palette fallback.
nl_ui_init "$TEST_ROOT"

[[ "$NL_UI_PALETTE_READY" == false ]] ||
    fail "Missing palette reported as available"

[[ "$NL_UI_COLOR_MODE" == plain ]] ||
    fail "Missing palette did not enable plain output"

[[ "$NL_UI_ANIMATE" == false ]] ||
    fail "Missing palette did not disable animation"

pass "Missing palette fallback"

# 10. Redirected output must not contain ANSI escapes.
sh "$PREVIEW" > "$TEST_ROOT/redirected.log" 2>&1

if grep -q $'\033' "$TEST_ROOT/redirected.log"; then
    fail "ANSI escapes found in redirected output"
fi

grep -Fq "Branding preview complete" \
    "$TEST_ROOT/redirected.log" ||
    fail "Redirected preview did not complete"

pass "Non-interactive output"

# 11. Explicit plain mode.
sh "$PREVIEW" --plain > "$TEST_ROOT/plain.log" 2>&1

if grep -q $'\033' "$TEST_ROOT/plain.log"; then
    fail "ANSI escapes found in plain output"
fi

pass "Explicit plain mode"

# 12. Help output and exit status.
sh "$PREVIEW" --help > "$TEST_ROOT/help.log"

grep -Fq "Usage:" "$TEST_ROOT/help.log" ||
    fail "Missing usage information"

pass "Help interface"

# 13. Invalid arguments.
status=0

sh "$PREVIEW" --invalid-option \
    > "$TEST_ROOT/invalid.log" 2>&1 || status=$?

[[ "$status" -eq 2 ]] ||
    fail "Invalid argument returned incorrect exit status"

pass "Invalid argument handling"

printf '%s\n' '============================================================'
printf 'PASS: All %s presentation checkpoints validated\n' "$passed"
