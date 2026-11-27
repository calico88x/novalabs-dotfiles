#!/usr/bin/env bash
# Phase 4.06 apply-prefix regression. Never executes native convergence.
set -euo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf -- "$TEST_ROOT"' EXIT
FIXTURE="$TEST_ROOT/repository"
HOME_FIX="$TEST_ROOT/home"
BIN="$TEST_ROOT/bin"
TMP="$TEST_ROOT/tmp"
OUT="$TEST_ROOT/stdout"
ERR="$TEST_ROOT/stderr"
TRACE="$TEST_ROOT/trace"
passed=0

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    for file in "$OUT" "$ERR" "$TRACE"; do
        if [[ -f "$file" ]]; then
            printf '\n--- %s ---\n' "$file" >&2
            cat "$file" >&2
        fi
    done
    exit 1
}
pass() { passed=$((passed + 1)); printf 'PASS: %s\n' "$*"; }

[[ "$(id -u)" != 0 && "$(uname -s)" == Linux ]] ||
    fail 'Run as a normal user on Linux'

reset_fixture() {
    rm -rf -- "$FIXTURE" "$HOME_FIX" "$BIN" "$TMP"
    mkdir -p "$FIXTURE/scripts/lib" "$FIXTURE/.chezmoidata" \
        "$FIXTURE/.chezmoiscripts" "$HOME_FIX/.local/bin" "$BIN" "$TMP"
    cp "$ROOT/scripts/lib/bootstrap-ui.sh" "$FIXTURE/scripts/lib/"
    cp "$ROOT/.chezmoidata/theme.toml" "$FIXTURE/.chezmoidata/"
    # Copy the actual apply prefix, stopping BEFORE native package convergence.
    # Fail closed if the boundary is absent or ambiguous.
    awk '
        /^# Generic Linux hosts install only required toolchain prerequisites\.$/ {
            count++; stop=1
        }
        !stop { print }
        END { if (count != 1) exit 1 }
    ' "$ROOT/install.sh" > "$FIXTURE/install.sh" || fail 'Missing unique apply cutoff'
    cat >> "$FIXTURE/install.sh" <<'EOF'
printf '%s\n' 'REACHED_STAGE_04_BOUNDARY'
printf '%s\n' 'boundary' >> "$TRACE"
exit 0
EOF
    sh -n "$FIXTURE/install.sh" || fail 'Invalid apply-prefix fixture'
    printf '%s\n' 'fixture validator template' > \
        "$FIXTURE/.chezmoiscripts/run_before_10-validate-host.sh.tmpl"

    # All bootstrap runtime and ChezMoi calls use this fake Mise binary.
    # Write the complete fake directly; no actual Mise installation occurs.
    cat > "$BIN/mise-fixture" <<'EOF'
#!/bin/sh
set -eu
if [ "$#" -eq 1 ] && [ "$1" = --version ]; then
    printf '%s\n' version >> "$TRACE"
    printf '%s\n' "mise ${FIXTURE_VERSION:-2026.8.9}"
    exit 0
fi
[ "$#" -eq 7 ] || exit 98
[ "$1" = x ] && [ "$2" = aqua:twpayne/chezmoi@2.72.1 ] &&
    [ "$3" = -- ] && [ "$4" = chezmoi ] &&
    [ "$5" = -S ] && [ "$6" = "$FIXTURE" ] || exit 98
case "$7" in
    init)
        printf '%s\n' enroll >> "$TRACE"
        printf '%s\n' 'NATIVE_ENROLLMENT_OUTPUT'
        printf '%s\n' 'NATIVE_ENROLLMENT_DIAGNOSTIC' >&2
        exit "${ENROLL_STATUS:-0}"
        ;;
    execute-template)
        input=$(cat)
        case "$input" in
            'fixture validator template')
                printf '%s\n' render-validator >> "$TRACE"
                [ "${RENDER_STATUS:-0}" -eq 0 ] || exit "$RENDER_STATUS"
                printf '%s\n' '#!/bin/sh' 'printf "%s\n" validate >> "$TRACE"' 'exit "${VALIDATOR_STATUS:-0}"'
                ;;
            '{{ .profile }}')
                printf '%s\n' profile >> "$TRACE"
                [ "${PROFILE_STATUS:-0}" -eq 0 ] || exit "$PROFILE_STATUS"
                printf '%s\n' "${FIXTURE_PROFILE:-any}"
                ;;
            '{{ .withDocker }}')
                printf '%s\n' with-docker >> "$TRACE"
                printf '%s\n' false
                ;;
            '{{ with (index (index .hosts .profile) "chronytop") }}{{ . }}{{ else }}skip{{ end }}')
                printf '%s\n' chronytop-policy >> "$TRACE"
                printf '%s\n' skip
                ;;
            *) exit 98 ;;
        esac
        ;;
    *) exit 98 ;;
esac
EOF
    chmod +x "$BIN/mise-fixture"
    cp "$BIN/mise-fixture" "$HOME_FIX/.local/bin/mise"

    # Fetcher emits only a local fixture installer; no network requests.
    cat > "$BIN/curl" <<'EOF'
#!/bin/sh
set -eu
[ "$#" -eq 2 ] && [ "$1" = -fsSL ] && [ "$2" = https://mise.run ] || exit 98
printf '%s\n' fetch >> "$TRACE"
cat <<'INSTALL'
set -eu
printf '%s\n' install-runtime >> "$TRACE"
[ "$MISE_VERSION" = v2026.8.9 ] || exit 98
[ "$MISE_INSTALL_PATH" = "$HOME/.local/bin/mise" ] || exit 98
[ "${INSTALL_STATUS:-0}" -eq 0 ] || exit "$INSTALL_STATUS"
cp "$FIXTURE_BIN/mise-fixture" "$MISE_INSTALL_PATH"
INSTALL
EOF
    chmod +x "$BIN/curl"
    cat > "$BIN/docker" <<'EOF'
#!/bin/sh
[ "$#" -eq 1 ] && [ "$1" = info ] || exit 98
printf '%s\n' docker-info >> "$TRACE"
exit "${DOCKER_STATUS:-0}"
EOF
    chmod +x "$BIN/docker"
    # Defense in depth: block privileged/package/network commands even if
    # the cutoff is accidentally changed. No real tools are invoked.
    for tool in sudo apt-get wget chezmoi mise; do
        cat > "$BIN/$tool" <<'EOF'
#!/bin/sh
printf '%s\n' "BLOCKED:$0" >> "$TRACE"
exit 99
EOF
        chmod +x "$BIN/$tool"
    done
    : > "$TRACE"
}

run_apply() {
    actual=0
    env -i PATH="$BIN:/usr/bin:/bin" HOME="$HOME_FIX" TMPDIR="$TMP" \
        LC_ALL=C TERM=dumb TRACE="$TRACE" FIXTURE="$FIXTURE" FIXTURE_BIN="$BIN" \
        "$@" sh "$FIXTURE/install.sh" --apply --plain > "$OUT" 2> "$ERR" || actual=$?
    if grep -q '^BLOCKED:' "$TRACE"; then fail 'Unexpected infrastructure invocation'; fi
    [[ -z "$(find "$TMP" -mindepth 1 -print -quit)" ]] || fail 'Validator temporary file leaked'
}
status() { [[ "$actual" -eq "$1" ]] || fail "Expected status $1, got $actual"; }
contains() { grep -Fq -- "$1" "$OUT" || fail "Missing output: $1"; }
absent() { if grep -Fq -- "$1" "$OUT"; then fail "Unexpected output: $1"; fi; }
trace_is() {
    printf '%s\n' "$@" > "$TEST_ROOT/expected-trace"
    cmp -s "$TRACE" "$TEST_ROOT/expected-trace" || fail 'Unexpected execution order'
}
complete_prefix() {
    status 0
    contains 'REACHED_STAGE_04_BOUNDARY'
    contains 'NATIVE_ENROLLMENT_OUTPUT'
    grep -Fxq 'NATIVE_ENROLLMENT_DIAGNOSTIC' "$ERR" || fail 'Native stderr lost'
    absent 'BOOTSTRAP COMPLETE'
    absent '[04/08]'
}
tracked_prefix() {
    complete_prefix
    contains '[01/08] BOOTSTRAP RUNTIME'
    contains '[02/08] CHEZMOI ENROLLMENT'
    contains '[03/08] HOST POLICY VALIDATION'
    contains '[OK] Pinned Mise runtime verified.'
    contains '[OK] ChezMoi enrollment completed.'
    contains '[OK] Host policy validated.'
    grep -Eq '^  Mode[[:space:]]+APPLY$' "$OUT" || fail 'Apply identity missing'
    if grep -q $'\033' "$OUT"; then fail 'ANSI in plain output'; fi
}

printf '%s\n' 'NovaLabs apply-prefix regression validation' '============================================================'

reset_fixture
run_apply
tracked_prefix
trace_is version version enroll render-validator validate profile with-docker chronytop-policy boundary
pass 'Existing pinned runtime and tracked apply prefix'

reset_fixture
rm "$HOME_FIX/.local/bin/mise"
run_apply
tracked_prefix
trace_is fetch install-runtime version enroll render-validator validate profile with-docker chronytop-policy boundary
pass 'Fresh pinned runtime installation fixture'

reset_fixture
rm "$FIXTURE/scripts/lib/bootstrap-ui.sh"
run_apply
complete_prefix
absent '[01/08]'
trace_is version version enroll render-validator validate profile with-docker chronytop-policy boundary
pass 'Apply prefix without optional presentation'

reset_fixture
cat >> "$FIXTURE/scripts/lib/bootstrap-ui.sh" <<'EOF'
nl_ui_animate_logo() { return 42; }
EOF
run_apply
complete_prefix
absent '[01/08]'
trace_is version version enroll render-validator validate profile with-docker chronytop-policy boundary
pass 'Startup rendering failure preserves execution'

reset_fixture
cat >> "$FIXTURE/scripts/lib/bootstrap-ui.sh" <<'EOF'
nl_ui_stage_pass() { return 42; }
EOF
run_apply
complete_prefix
contains '[01/08] BOOTSTRAP RUNTIME'
absent '[02/08]'
trace_is version version enroll render-validator validate profile with-docker chronytop-policy boundary
pass 'Stage reporting failure preserves execution'

reset_fixture
rm "$HOME_FIX/.local/bin/mise"
run_apply INSTALL_STATUS=41
status 41
absent '[OK] Pinned Mise runtime verified.'
absent '[02/08]'
trace_is fetch install-runtime
pass 'Runtime installer failure preserves exit status'

reset_fixture
run_apply FIXTURE_VERSION=wrong-version
status 1
absent '[OK] Pinned Mise runtime verified.'
absent '[02/08]'
trace_is version fetch install-runtime version
pass 'Runtime version mismatch stops enrollment'

reset_fixture
run_apply ENROLL_STATUS=42
status 42
contains '[02/08] CHEZMOI ENROLLMENT'
absent '[OK] ChezMoi enrollment completed.'
absent '[03/08]'
trace_is version version enroll
pass 'Enrollment failure preserves exit status'

reset_fixture
run_apply RENDER_STATUS=43
status 43
contains '[03/08] HOST POLICY VALIDATION'
absent '[OK] Host policy validated.'
trace_is version version enroll render-validator
pass 'Validator rendering failure preserves exit status'

reset_fixture
run_apply VALIDATOR_STATUS=44
status 44
absent '[OK] Host policy validated.'
trace_is version version enroll render-validator validate
pass 'Host validator failure preserves exit status'

reset_fixture
run_apply PROFILE_STATUS=45
status 45
absent '[OK] Host policy validated.'
trace_is version version enroll render-validator validate profile
pass 'Host profile resolution failure preserves exit status'

reset_fixture
run_apply FIXTURE_PROFILE=docker DOCKER_STATUS=46
status 1
absent '[OK] Host policy validated.'
trace_is version version enroll render-validator validate profile with-docker chronytop-policy docker-info
pass 'Docker prerequisite failure retains existing guard'

# 13. Authoritative profile, independent of current hostname.
reset_fixture
run_apply FIXTURE_PROFILE=lovelace
tracked_prefix
contains 'HOST PROFILE'
grep -Eq '^  Profile[[:space:]]+lovelace$' "$OUT" || fail 'Incorrect profile'
grep -Eq '^  Identity[[:space:]]+Lovelace$' "$OUT" || fail 'Incorrect identity'
contains '#af63e1'
trace_is version version enroll render-validator validate profile with-docker chronytop-policy boundary
pass 'Authoritative profile selection'

# 14. All catalog identities, including stage-only OPNsense metadata.
# OPNsense here is a mocked profile on Linux, not a real supported apply.
for entry in 'any|Generic Linux|Dracula Classic|#FF79C6' 'proxmox|Proxmox|Ember orange|#ff9b3e' 'docker|Docker LXC|Cyan blue|#5ab7ff' 'pihole|Pi-hole|Electric lime|#f8547a' 'ubuntulab|UbuntuLab|Golden amber|#ff823a' 'opnsense|OPNsense|Crimson red|#f66c88' 'zgx|ZGX|GPU emerald|#5ff70d' 'lovelace|Lovelace|Violet purple|#af63e1' 'worker1|Worker node|Kubernetes cobalt|#ffe645'; do
    IFS='|' read -r p name family accent <<< "$entry"
    reset_fixture
    run_apply FIXTURE_PROFILE="$p"
    tracked_prefix
    grep -Eq "^  Profile[[:space:]]+$p$" "$OUT" || fail "Profile missing: $p"
    grep -Fq "$name" "$OUT" || fail "Identity missing: $p"
    grep -Fq "$family" "$OUT" || fail "Family missing: $p"
    grep -Fq "$accent" "$OUT" || fail "Accent missing: $p"
done
pass 'All nine catalog identities in mocked apply prefix'

# 15. Generic enrollment is not inferred from the hostname.
reset_fixture
run_apply
tracked_prefix
grep -Eq '^  Profile[[:space:]]+any$' "$OUT" || fail 'Generic profile missing'
contains 'Generic Linux'
pass 'Generic enrollment remains authoritative'

# 16. Missing catalog does not stop execution.
reset_fixture
rm "$FIXTURE/.chezmoidata/theme.toml"
run_apply
tracked_prefix
absent 'HOST PROFILE'
pass 'Missing presentation catalog preserves execution'

# 17. Missing display metadata does not stop execution.
reset_fixture
sed -i '/^\[theme.hosts.lovelace\]$/,/^\[/ { /^display_name =/d; }' "$FIXTURE/.chezmoidata/theme.toml"
run_apply FIXTURE_PROFILE=lovelace
tracked_prefix
absent 'HOST PROFILE'
pass 'Missing host metadata preserves execution'

# 18. Invalid palette omits accent and palette, retains identity.
reset_fixture
sed -i '/^\[theme.hosts.lovelace\]$/,/^\[/ s/^shade_2 =.*/shade_2 = "invalid"/' "$FIXTURE/.chezmoidata/theme.toml"
run_apply FIXTURE_PROFILE=lovelace
tracked_prefix
contains 'HOST PROFILE'
contains 'Lovelace'
absent 'Host accent'
absent 'Host palette'
pass 'Malformed host palette omitted'

# 19. Explicit host renderer failure cannot stop execution.
reset_fixture
cat >> "$FIXTURE/scripts/lib/bootstrap-ui.sh" <<'EOF'
nl_ui_host_identity() { return 47; }
EOF
run_apply FIXTURE_PROFILE=lovelace
tracked_prefix
absent 'HOST PROFILE'
trace_is version version enroll render-validator validate profile with-docker chronytop-policy boundary
pass 'Host identity rendering failure preserves execution'

# 20. Host identity must never be rendered before validation succeeds.
reset_fixture
run_apply FIXTURE_PROFILE=docker DOCKER_STATUS=46
status 1
absent 'HOST PROFILE'
absent '[OK] Host policy validated.'
trace_is version version enroll render-validator validate profile with-docker chronytop-policy docker-info
pass 'Host validation precedes identity rendering'

printf '%s\n' '============================================================'
printf 'PASS: All %s apply-prefix checkpoints validated\n' "$passed"
