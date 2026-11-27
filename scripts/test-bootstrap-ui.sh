
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

# -------------------------------------------------------------------
# Phase 3: Host identity and stage tracking
# -------------------------------------------------------------------

# 14. Architecture normalization.
[[ "$(nl_ui_architecture x86_64)" == AMD64 ]] ||
    fail "x86_64 normalization failed"

[[ "$(nl_ui_architecture aarch64)" == ARM64 ]] ||
    fail "aarch64 normalization failed"

[[ "$(nl_ui_architecture riscv64)" == riscv64 ]] ||
    fail "Unknown architecture was not preserved"

pass "Architecture normalization"

# 15. Repository revision fallback.
[[ "$(nl_ui_revision "$TEST_ROOT")" == unknown ]] ||
    fail "Missing repository revision fallback failed"

pass "Repository revision fallback"

# 16. Semantic plain-text indicators.
NL_UI_COLOR_MODE=plain

[[ "$(nl_ui_status success Example)" == "  [OK] Example" ]] ||
    fail "Incorrect success indicator"

[[ "$(nl_ui_status failure Example)" == "  [FAIL] Example" ]] ||
    fail "Incorrect failure indicator"

[[ "$(nl_ui_status warning Example)" == "  [WARN] Example" ]] ||
    fail "Incorrect warning indicator"

[[ "$(nl_ui_status running Example)" == "  [RUN] Example" ]] ||
    fail "Incorrect running indicator"

[[ "$(nl_ui_status skipped Example)" == "  [SKIP] Example" ]] ||
    fail "Incorrect skipped indicator"

[[ "$(nl_ui_status info Example)" == "  [INFO] Example" ]] ||
    fail "Incorrect information indicator"

if nl_ui_status invalid Example; then
    fail "Unknown semantic state accepted"
fi

pass "Semantic status indicators"

# 17. Reload authoritative palette after fallback testing.
nl_ui_load_palette "$ROOT" ||
    fail "Unable to reload theme catalog"

NL_UI_PALETTE_READY=true

for profile in \
    any proxmox docker pihole ubuntulab \
    lovelace worker1 zgx opnsense
do
    section="theme.hosts.$profile"

    for key in display_name family; do
        value="$(nl_ui_catalog_value \
            "$NL_UI_CATALOG" "$section" "$key")" ||
            fail "Missing $profile/$key"

        [[ -n "$value" ]] ||
            fail "Empty $profile/$key"
    done

    for key in shade_1 shade_2 shade_3 shade_4; do
        value="$(nl_ui_catalog_value \
            "$NL_UI_CATALOG" "$section" "$key")" ||
            fail "Missing $profile/$key"

        nl_ui_valid_hex "$value" ||
            fail "Invalid $profile/$key"
    done
done

pass "All nine host profile palettes"

# 18. Plain host palette presentation.
actual="$(nl_ui_host_palette \
    '#111111' '#222222' '#333333' '#444444')"

[[ "$actual" == *"#111111 #222222 #333333 #444444" ]] ||
    fail "Incorrect plain host palette"

pass "Plain host palette rendering"

# 19. Invalid host palette omission.
actual="$(nl_ui_host_palette \
    '#111111' invalid '#333333' '#444444')"

[[ -z "$actual" ]] ||
    fail "Invalid host palette was rendered"

pass "Invalid host palette omission"

# 20. Elapsed-time calculations.
[[ "$(nl_ui_elapsed 100 105)" == 5 ]] ||
    fail "Incorrect elapsed time"

[[ "$(nl_ui_elapsed 105 100)" == 0 ]] ||
    fail "Backward clock change not handled"

[[ "$(nl_ui_elapsed 0 105)" == 0 ]] ||
    fail "Unavailable timestamp not handled"

pass "Elapsed-time calculation"

# 21. Invalid stage totals.
for invalid in "" 0 01 -1 abc; do
    if nl_ui_tracker_init "$invalid"; then
        fail "Invalid stage total accepted: $invalid"
    fi
done

pass "Stage total validation"

# 22. Successful stage accounting.
nl_ui_tracker_init 3

nl_ui_stage_begin FIRST >/dev/null
nl_ui_stage_pass "Completed" >/dev/null

nl_ui_stage_begin SECOND >/dev/null
nl_ui_stage_skip "Skipped" >/dev/null

nl_ui_stage_begin THIRD >/dev/null
nl_ui_stage_pass "Completed" >/dev/null

[[ "$NL_UI_STAGE_NUMBER" == 3 ]] ||
    fail "Incorrect stage number"

[[ "$NL_UI_STAGE_COMPLETED" == 2 ]] ||
    fail "Incorrect completed count"

[[ "$NL_UI_STAGE_SKIPPED" == 1 ]] ||
    fail "Incorrect skipped count"

[[ "$NL_UI_STAGE_FAILED" == 0 ]] ||
    fail "Unexpected failed count"

actual="$(nl_ui_summary 0)"

[[ "$actual" == *"BOOTSTRAP COMPLETE"* ]] ||
    fail "Successful summary missing"

pass "Successful stage accounting"

# 23. Invalid stage transitions.
if nl_ui_stage_begin OVERFLOW >/dev/null; then
    fail "Stage count exceeded planned total"
fi

nl_ui_tracker_init 2

if nl_ui_stage_pass Invalid >/dev/null; then
    fail "Completed a stage that was not started"
fi

if nl_ui_stage_skip Invalid >/dev/null; then
    fail "Skipped a stage that was not started"
fi

if nl_ui_stage_fail 42 Invalid >/dev/null; then
    fail "Failed a stage that was not started"
fi

nl_ui_stage_begin FIRST >/dev/null

if nl_ui_stage_begin SECOND >/dev/null; then
    fail "Overlapping active stages accepted"
fi

if nl_ui_stage_fail 0 Invalid >/dev/null; then
    fail "Zero failure status accepted"
fi

nl_ui_stage_pass Completed >/dev/null

if nl_ui_stage_pass Duplicate >/dev/null; then
    fail "Duplicate stage completion accepted"
fi

pass "Invalid stage transition rejection"

# 24. Failed stage accounting.
nl_ui_tracker_init 3

nl_ui_stage_begin FIRST >/dev/null
nl_ui_stage_pass Completed >/dev/null

nl_ui_stage_begin SECOND >/dev/null
nl_ui_stage_fail 42 Failed >/dev/null

[[ "$NL_UI_STAGE_COMPLETED" == 1 ]] ||
    fail "Incorrect completed count after failure"

[[ "$NL_UI_STAGE_FAILED" == 1 ]] ||
    fail "Incorrect failure count"

[[ "$NL_UI_STAGE_ACTIVE" == false ]] ||
    fail "Failed stage remained active"

if nl_ui_stage_begin THIRD >/dev/null; then
    fail "Execution continued after failed stage"
fi

actual="$(nl_ui_summary 42)"

[[ "$actual" == *"BOOTSTRAP FAILED"* ]] ||
    fail "Failure summary missing"

[[ "$actual" =~ Exit[[:space:]]status[[:space:]]+42 ]] ||
    fail "Original failure status missing"

pass "Failed stage accounting"

# 25. Incomplete execution summary.
nl_ui_tracker_init 2

nl_ui_stage_begin FIRST >/dev/null
nl_ui_stage_pass Completed >/dev/null

actual="$(nl_ui_summary 0)"

[[ "$actual" == *"BOOTSTRAP INCOMPLETE"* ]] ||
    fail "Incomplete execution reported as successful"

pass "Incomplete execution detection"

# 26. Standard host preview.
sh "$PREVIEW" --plain --profile lovelace \
    > "$TEST_ROOT/lovelace.log" 2>&1

grep -Eq 'Stages processed[[:space:]]+8/8' \
    "$TEST_ROOT/lovelace.log" ||
    fail "Lovelace stage count incorrect"

grep -Eq 'Completed[[:space:]]+7$' \
    "$TEST_ROOT/lovelace.log" ||
    fail "Lovelace completed count incorrect"

grep -Eq 'Skipped[[:space:]]+1$' \
    "$TEST_ROOT/lovelace.log" ||
    fail "Lovelace skipped count incorrect"

pass "Standard host preview"

# 27. Proxmox Chronytop preview.
sh "$PREVIEW" --plain --profile proxmox \
    > "$TEST_ROOT/proxmox.log" 2>&1

grep -Fq "Simulated Chronytop verification" \
    "$TEST_ROOT/proxmox.log" ||
    fail "Proxmox Chronytop stage missing"

grep -Eq 'Completed[[:space:]]+8$' \
    "$TEST_ROOT/proxmox.log" ||
    fail "Proxmox completed count incorrect"

pass "Proxmox Chronytop preview"

# 28. Simulated failure preview.
sh "$PREVIEW" --plain --profile zgx --simulate-failure \
    > "$TEST_ROOT/failure.log" 2>&1

grep -Fq "BOOTSTRAP FAILED" \
    "$TEST_ROOT/failure.log" ||
    fail "Simulated failure summary missing"

grep -Eq 'Stages processed[[:space:]]+5/8' \
    "$TEST_ROOT/failure.log" ||
    fail "Simulated failure stage count incorrect"

grep -Eq 'Exit status[[:space:]]+42$' \
    "$TEST_ROOT/failure.log" ||
    fail "Simulated failure status incorrect"

if grep -Fq '[06/08]' "$TEST_ROOT/failure.log"; then
    fail "Simulation continued after failure"
fi

pass "Simulated failure preview"

# 29. OPNsense stage-only policy.
sh "$PREVIEW" --plain --profile opnsense \
    > "$TEST_ROOT/opnsense.log" 2>&1

grep -Fq "OPNsense is excluded" \
    "$TEST_ROOT/opnsense.log" ||
    fail "OPNsense exclusion missing"

if grep -Fq '[01/08]' "$TEST_ROOT/opnsense.log"; then
    fail "OPNsense entered generic execution stages"
fi

pass "OPNsense stage-only preview"

# 30. Invalid preview profiles.
status=0

sh "$PREVIEW" --profile nonexistent \
    > "$TEST_ROOT/invalid-profile.log" 2>&1 ||
    status=$?

[[ "$status" == 2 ]] ||
    fail "Invalid profile returned incorrect exit status"

status=0

sh "$PREVIEW" --profile \
    > "$TEST_ROOT/missing-profile.log" 2>&1 ||
    status=$?

[[ "$status" == 2 ]] ||
    fail "Missing profile returned incorrect exit status"

pass "Preview profile argument validation"

# 31. ANSI-free output across all preview scenarios.
for logfile in \
    lovelace.log proxmox.log failure.log opnsense.log
do
    if grep -q $'\033' "$TEST_ROOT/$logfile"; then
        fail "ANSI escape found in $logfile"
    fi
done

pass "ANSI-free execution summaries"

# -------------------------------------------------------------------
# Phase 4: Presentation initialization safety
# -------------------------------------------------------------------

# 32. Deterministic fallback after previous initialization.
nl_ui_init "$ROOT"

[[ "$NL_UI_PALETTE_READY" == true ]] ||
    fail "Valid palette initialization failed"

NL_UI_SLOGAN="STALE PREVIOUS STATE"
NL_UI_BRAND_1="#123456"
NL_UI_HEADER="#123456"

nl_ui_init "$TEST_ROOT/nonexistent"

[[ "$NL_UI_PALETTE_READY" == false ]] ||
    fail "Missing palette reported as ready"

[[ "$NL_UI_COLOR_MODE" == plain ]] ||
    fail "Missing palette did not select plain mode"

[[ "$NL_UI_ANIMATE" == false ]] ||
    fail "Missing palette did not disable animation"

[[ "$NL_UI_SLOGAN" == "DECLARATIVE INFRASTRUCTURE" ]] ||
    fail "Default slogan was not restored"

[[ -z "$NL_UI_BRAND_1" && -z "$NL_UI_HEADER" ]] ||
    fail "Previous palette state was retained"

pass "Deterministic palette fallback"

# Create an isolated catalog fixture.
fixture="$TEST_ROOT/malformed-catalog"

mkdir -p "$fixture/.chezmoidata"

catalog="$ROOT/.chezmoidata/theme.toml"
fixture_catalog="$fixture/.chezmoidata/theme.toml"

# 33. Malformed brand color.
sed \
    's/^stop_1[[:space:]]*=.*/stop_1 = "#INVALID"/' \
    "$catalog" > "$fixture_catalog"

grep -Fxq 'stop_1 = "#INVALID"' "$fixture_catalog" ||
    fail "Malformed brand fixture was not generated"

nl_ui_init "$fixture"

[[ "$NL_UI_PALETTE_READY" == false ]] ||
    fail "Malformed brand palette accepted"

[[ "$NL_UI_COLOR_MODE" == plain ]] ||
    fail "Malformed brand palette retained color mode"

[[ "$NL_UI_ANIMATE" == false ]] ||
    fail "Malformed brand palette retained animation"

[[ -z "$NL_UI_BRAND_1" ]] ||
    fail "Malformed brand value was retained"

pass "Malformed brand color fallback"

# 34. Malformed slogan.
sed \
    's/^slogan[[:space:]]*=.*/slogan = "Invalid slogan 123"/' \
    "$catalog" > "$fixture_catalog"

grep -Fxq 'slogan = "Invalid slogan 123"' "$fixture_catalog" ||
    fail "Malformed slogan fixture was not generated"

nl_ui_init "$fixture"

[[ "$NL_UI_PALETTE_READY" == false ]] ||
    fail "Malformed slogan accepted"

[[ "$NL_UI_SLOGAN" == "DECLARATIVE INFRASTRUCTURE" ]] ||
    fail "Malformed slogan was retained"

actual="$(nl_ui_logo)"

[[ "$actual" != *"Invalid slogan 123"* ]] ||
    fail "Malformed slogan reached terminal output"

[[ "$actual" != *$'\033'* ]] ||
    fail "Fallback logo contains ANSI escapes"

pass "Malformed slogan fallback"

# 35. Late palette-loading failure.
# Remove the required muted color after earlier values can load.
awk '
    /^\[/ {
        active = ($0 == "[theme.tui]")
    }

    active && /^muted[[:space:]]*=/ {
        removed++
        next
    }

    { print }

    END {
        if (removed != 1)
            exit 1
    }
' "$catalog" > "$fixture_catalog" ||
    fail "Late failure fixture was not generated"

nl_ui_init "$fixture"

[[ "$NL_UI_PALETTE_READY" == false ]] ||
    fail "Incomplete palette accepted"

[[ "$NL_UI_COLOR_MODE" == plain ]] ||
    fail "Incomplete palette retained color mode"

[[ "$NL_UI_ANIMATE" == false ]] ||
    fail "Incomplete palette retained animation"

for variable in \
    NL_UI_BRAND_1 \
    NL_UI_BRAND_2 \
    NL_UI_BRAND_3 \
    NL_UI_BRAND_4 \
    NL_UI_BRAND_5 \
    NL_UI_BRAND_6 \
    NL_UI_HEADER \
    NL_UI_HIGHLIGHT \
    NL_UI_SUCCESS \
    NL_UI_ERROR \
    NL_UI_WARNING \
    NL_UI_FOREGROUND \
    NL_UI_MUTED
do
    [[ -z "${!variable}" ]] ||
        fail "Partial palette state retained: $variable"
done

pass "Late palette-loading failure isolation"

# 36. Recovery from malformed catalog data.
nl_ui_init "$ROOT"

[[ "$NL_UI_PALETTE_READY" == true ]] ||
    fail "Valid palette recovery failed"

nl_ui_valid_hex "$NL_UI_BRAND_1" ||
    fail "Recovered brand color is invalid"

nl_ui_valid_hex "$NL_UI_MUTED" ||
    fail "Recovered muted color is invalid"

[[ "$NL_UI_SLOGAN" == "DECLARATIVE INFRASTRUCTURE" ]] ||
    fail "Recovered slogan is invalid"

pass "Valid palette recovery after malformed data"

printf '%s\n' '============================================================'
printf 'PASS: All %s presentation checkpoints validated\n' "$passed"
