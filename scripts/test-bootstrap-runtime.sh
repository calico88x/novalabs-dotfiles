#!/usr/bin/env bash
# Isolated apply-prefix regression; native convergence is mocked in extended fixtures.
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
    local fixture_scope="${1:-runtime}"
    case "$fixture_scope" in runtime|extended|applications|full) ;; *) fail "Unknown fixture scope" ;; esac
    rm -rf -- "$FIXTURE" "$HOME_FIX" "$BIN" "$TMP"
    mkdir -p "$FIXTURE/scripts/lib" "$FIXTURE/.chezmoidata" \
        "$FIXTURE/.chezmoiscripts" "$HOME_FIX/.local/bin" "$BIN" "$TMP"
    cp "$ROOT/scripts/lib/bootstrap-ui.sh" "$FIXTURE/scripts/lib/"
    cp "$ROOT/.chezmoidata/theme.toml" "$FIXTURE/.chezmoidata/"
    # Preserve historical cutoffs and add a Stage 08 cutoff.
    # The application fixture redirects all managed paths before execution.
    awk -v scope="$fixture_scope" '
        /^bootstrap_ui_call nl_ui_stage_begin "NATIVE PREREQUISITES"$/ {
            if (scope == "runtime") { count++; stop=1 }
            else { print "ID=${FIXTURE_DISTRO:-ubuntu}"; starts++ }
        }
        /^bootstrap_ui_call nl_ui_stage_begin "APPLICATION CONVERGENCE"$/ {
            if (scope == "extended") { count++; stop=1 }
        }
        /^bootstrap_ui_call nl_ui_stage_begin "APPLICATION AUDIT AND PRUNING"$/ {
            if (scope == "applications") { count++; stop=1 }
        }
        !stop { print }
        END { if (count != (scope == "full" ? 0 : 1) || (scope != "runtime" && starts != 1)) exit 1 }
    ' "$ROOT/install.sh" > "$FIXTURE/install.sh" || fail 'Missing unique apply cutoff'
    if [[ "$fixture_scope" == applications || "$fixture_scope" == full ]]; then
        # Exact, counted substitutions; no real system paths in this fixture.
        for path in /usr/bin/chronyc /usr/local/bin/chronytop /usr/local/bin/.chronytop; do
            [[ $(grep -Fc "$path" "$FIXTURE/install.sh") == 1 ]] || fail "Unexpected path count: $path"
        done
        sed -i 's@/usr/bin/chronyc@$FIXTURE/managed/chronyc@g; s@/usr/local/bin/chronytop@$FIXTURE/managed/chronytop@g; s@/usr/local/bin/\.chronytop@$FIXTURE/managed/.chronytop@g' "$FIXTURE/install.sh"
        if grep -Eq '/usr/local/bin/|/usr/bin/chronyc' "$FIXTURE/install.sh"; then fail 'Unredirected managed path'; fi
        if [[ "$fixture_scope" == applications ]]; then
            printf '%s\n' "printf '%s\\n' 'REACHED_STAGE_08_BOUNDARY'" >> "$FIXTURE/install.sh"
        fi
    elif [[ "$fixture_scope" == extended ]]; then
        printf '%s\n' "printf '%s\\n' 'REACHED_STAGE_06_BOUNDARY'" >> "$FIXTURE/install.sh"
    else
        printf '%s\n' "printf '%s\\n' 'REACHED_STAGE_04_BOUNDARY'" >> "$FIXTURE/install.sh"
    fi
    if [[ "$fixture_scope" != full ]]; then
        cat >> "$FIXTURE/install.sh" <<'EOF'
printf '%s\n' 'boundary' >> "$TRACE"
exit 0
EOF
    fi
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
if [ "$#" -eq 5 ] && [ "$1" = x ] &&
   [ "$2" = aqua:twpayne/chezmoi@2.72.1 ] && [ "$3" = -- ] &&
   [ "$4" = chezmoi ] && [ "$5" = apply ]; then
    printf '%s\n' apply >> "$TRACE"
    printf '%s\n' NATIVE_APPLY_OUTPUT
    printf '%s\n' NATIVE_APPLY_DIAGNOSTIC >&2
    exit "${APPLY_STATUS:-0}"
fi
if [ "$#" = 1 ] && [ "$1" = install ]; then
    printf '%s\n' mise-install >> "$TRACE"
    exit "${MISE_INSTALL_STATUS:-0}"
fi
if [ "$#" = 2 ] && [ "$1" = ls ] && [ "$2" = --prunable ]; then
    printf '%s\n' audit >> "$TRACE"
    printf '%s\n' NATIVE_AUDIT_OUTPUT
    exit "${AUDIT_STATUS:-0}"
fi
if [ "$#" = 1 ] && [ "$1" = prune ]; then
    printf '%s\n' prune >> "$TRACE"
    printf '%s\n' NATIVE_PRUNE_OUTPUT
    exit "${PRUNE_STATUS:-0}"
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
                printf '%s\n' "${FIXTURE_CHRONYTOP:-skip}"
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
    if [[ "$fixture_scope" != runtime ]]; then
        # Never invoke real sudo or apt-get: this shim only recognizes the
        # exact supported operations and records their arguments.
        cat > "$BIN/sudo" <<'EOF'
#!/bin/sh
set -eu
[ "$#" -ge 2 ] && [ "$1" = apt-get ] || exit 98
shift
case "$1" in
    update)
        [ "$#" -eq 1 ] || exit 98
        printf '%s\n' apt-update >> "$TRACE"
        printf '%s\n' NATIVE_APT_UPDATE
        exit "${UPDATE_STATUS:-0}"
        ;;
    install)
        shift
        case "$*" in
            '-y --no-install-recommends build-essential libatomic1'|'-y build-essential ca-certificates curl git gzip libatomic1 htop openssh-server procps sudo tar tmux vim') ;;
            *) exit 98 ;;
        esac
        printf 'apt-install:%s\n' "$*" >> "$TRACE"
        printf '%s\n' NATIVE_APT_INSTALL
        exit "${INSTALL_APT_STATUS:-0}"
        ;;
    *) exit 98 ;;
esac
EOF
        chmod +x "$BIN/sudo"
        printf '%s\n' '#!/bin/sh' 'exit 98' > "$BIN/cc"
        chmod +x "$BIN/cc"
    fi
    if [[ "$fixture_scope" == applications || "$fixture_scope" == full ]]; then
        mkdir -p "$FIXTURE/managed"
        printf '%s\n' '#!/bin/sh' 'exit 0' > "$FIXTURE/managed/chronyc"
        chmod +x "$FIXTURE/managed/chronyc"
        cat > "$FIXTURE/release" <<'EOF'
#!/bin/sh
[ "$#" = 1 ] && [ "$1" = -version ] || exit 98
printf '%s\n' chronytop-version >> "$TRACE"
printf '%s\n' FIXTURE_CHRONYTOP_VERSION
exit "${CHRONYTOP_VERSION_STATUS:-0}"
EOF
        mv "$BIN/curl" "$BIN/runtime-curl"
        cat > "$BIN/curl" <<'EOF'
#!/bin/sh
set -eu
url=https://github.com/geerlingguy/chronytop/releases/latest/download
if [ "$#" = 2 ] && [ "$2" = https://mise.run ]; then
    exec "$FIXTURE_BIN/runtime-curl" "$@"
fi
if [ "$#" = 2 ] && [ "$1" = -fsSL ] && [ "$2" = "$url/SHA256SUMS" ]; then
    printf '%s\n' checksums >> "$TRACE"
    [ "${CHECKSUM_STATUS:-0}" = 0 ] || exit "$CHECKSUM_STATUS"
    if [ "${INVALID_CHECKSUM:-0}" = 1 ]; then
        printf '%s\n' 'invalid  chronytop-linux-amd64'
    else
        sha=$(sha256sum "$FIXTURE/release"); sha=${sha%% *}
        printf '%s  chronytop-linux-amd64\n' "$sha"
    fi
elif [ "$#" = 4 ] && [ "$1" = -fsSL ] && [ "$2" = -o ] && [ "$4" = "$url/chronytop-linux-amd64" ]; then
    case "$3" in "$TMPDIR"/tmp.*) ;; *) exit 98 ;; esac
    printf '%s\n' download >> "$TRACE"
    [ "${DOWNLOAD_STATUS:-0}" = 0 ] || exit "$DOWNLOAD_STATUS"
    cp "$FIXTURE/release" "$3"
    if [ "${CORRUPT_DOWNLOAD:-0}" = 1 ]; then printf 'corrupt\n' >> "$3"; fi
else
    printf '%s\n' BLOCKED:curl >> "$TRACE"; exit 99
fi
EOF
        mv "$BIN/sudo" "$BIN/apt-sudo"
        cat > "$BIN/sudo" <<'EOF'
#!/bin/sh
set -eu
case "$1" in
    apt-get) exec "$FIXTURE_BIN/apt-sudo" "$@" ;;
    install)
        [ "$#" = 9 ] && [ "$2 $3 $4 $5 $6 $7" = '-o root -g root -m 0755' ] || exit 98
        case "$8" in "$TMPDIR"/tmp.*) ;; *) exit 98 ;; esac
        case "$9" in "$FIXTURE"/managed/.chronytop.*) ;; *) exit 98 ;; esac
        printf '%s\n' stage-binary >> "$TRACE"
        # Create the fixture stage even on failure to test explicit cleanup.
        cp "$8" "$9"; chmod 755 "$9"
        exit "${STAGE_STATUS:-0}"
        ;;
    mv)
        [ "$#" = 5 ] && [ "$2 $3" = '-f --' ] && [ "$5" = "$FIXTURE/managed/chronytop" ] || exit 98
        case "$4" in "$FIXTURE"/managed/.chronytop.*) ;; *) exit 98 ;; esac
        printf '%s\n' replace-binary >> "$TRACE"
        [ "${REPLACE_STATUS:-0}" = 0 ] || exit "$REPLACE_STATUS"
        mv -- "$4" "$5"
        ;;
    rm)
        [ "$#" = 4 ] && [ "$2 $3" = '-f --' ] || exit 98
        case "$4" in "$FIXTURE"/managed/.chronytop.*) ;; *) exit 98 ;; esac
        printf '%s\n' cleanup-stage >> "$TRACE"
        rm -f -- "$4"
        ;;
    *) printf '%s\n' BLOCKED:sudo >> "$TRACE"; exit 99 ;;
esac
EOF
        cat > "$BIN/stat" <<'EOF'
#!/bin/sh
set -eu
[ "$#" = 3 ] && [ "$1" = -c ] && [ "$2" = '%U:%G %a' ] && [ "$3" = "$FIXTURE/managed/chronytop" ] || exit 98
printf '%s\n' verify-metadata >> "$TRACE"
# Ownership is simulated; permissions are measured on the actual fixture.
mode=$(/usr/bin/stat -c %a "$3")
printf '%s %s\n' "${FIXTURE_OWNER:-root:root}" "$mode"
EOF
        chmod +x "$BIN/curl" "$BIN/sudo" "$BIN/stat"
    fi
    : > "$TRACE"
}

run_apply() {
    local -a apply_args=(--apply --plain)
    if [[ "${1:-}" == --prune ]]; then
        apply_args+=(--prune)
        shift
    fi
    actual=0
    env -i PATH="$BIN:/usr/bin:/bin" HOME="$HOME_FIX" TMPDIR="$TMP" \
        LC_ALL=C TERM=dumb TRACE="$TRACE" FIXTURE="$FIXTURE" FIXTURE_BIN="$BIN" \
        "$@" sh "$FIXTURE/install.sh" "${apply_args[@]}" > "$OUT" 2> "$ERR" || actual=$?
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

extended_success() {
    status 0
    contains 'REACHED_STAGE_06_BOUNDARY'
    contains '[04/08] NATIVE PREREQUISITES'
    contains '[05/08] CONFIGURATION RECONCILIATION'
    contains '[OK] Managed configuration reconciled.'
    contains 'NATIVE_APPLY_OUTPUT'
    grep -Fxq 'NATIVE_APPLY_DIAGNOSTIC' "$ERR" || fail 'Native apply stderr lost'
    absent '[06/08]'
    absent 'BOOTSTRAP COMPLETE'
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

# Extended fixtures execute through Stage 05 only. The existing 20 cases
# retain their original cutoff and traces.
reset_fixture extended
run_apply
extended_success
contains '[OK] Toolchain prerequisites converged.'
trace_is version version enroll render-validator validate profile with-docker chronytop-policy apt-update 'apt-install:-y --no-install-recommends build-essential libatomic1' apply boundary
pass 'Generic Debian-family minimal prerequisites and configuration'

reset_fixture extended
run_apply FIXTURE_PROFILE=lovelace
extended_success
contains '[OK] Native package baseline converged.'
trace_is version version enroll render-validator validate profile with-docker chronytop-policy apt-update 'apt-install:-y build-essential ca-certificates curl git gzip libatomic1 htop openssh-server procps sudo tar tmux vim' apply boundary
pass 'Named Debian-family full native baseline'

reset_fixture extended
run_apply FIXTURE_DISTRO=fedora
extended_success
contains '[OK] C compiler verified; native prerequisites externally managed.'
contains 'Ensure libatomic.so.1 is available'
trace_is version version enroll render-validator validate profile with-docker chronytop-policy apply boundary
pass 'Generic externally managed prerequisites'

reset_fixture extended
run_apply FIXTURE_PROFILE=lovelace FIXTURE_DISTRO=fedora
status 1
contains '[04/08] NATIVE PREREQUISITES'
absent '[05/08]'
trace_is version version enroll render-validator validate profile with-docker chronytop-policy
pass 'Named unsupported distribution guard'

reset_fixture extended
run_apply UPDATE_STATUS=51
status 51
absent '[OK] Toolchain prerequisites converged.'
absent '[05/08]'
trace_is version version enroll render-validator validate profile with-docker chronytop-policy apt-update
pass 'APT update failure preserves exit status'

reset_fixture extended
run_apply INSTALL_APT_STATUS=52
status 52
absent '[OK] Toolchain prerequisites converged.'
absent '[05/08]'
trace_is version version enroll render-validator validate profile with-docker chronytop-policy apt-update 'apt-install:-y --no-install-recommends build-essential libatomic1'
pass 'APT install failure preserves exit status'

reset_fixture extended
run_apply APPLY_STATUS=53
status 53
contains '[05/08] CONFIGURATION RECONCILIATION'
absent '[OK] Managed configuration reconciled.'
absent 'REACHED_STAGE_06_BOUNDARY'
trace_is version version enroll render-validator validate profile with-docker chronytop-policy apt-update 'apt-install:-y --no-install-recommends build-essential libatomic1' apply
pass 'ChezMoi apply failure preserves exit status'

reset_fixture extended
rm "$FIXTURE/scripts/lib/bootstrap-ui.sh"
run_apply
status 0
contains 'REACHED_STAGE_06_BOUNDARY'
contains 'NATIVE_APPLY_OUTPUT'
absent '[04/08]'
trace_is version version enroll render-validator validate profile with-docker chronytop-policy apt-update 'apt-install:-y --no-install-recommends build-essential libatomic1' apply boundary
pass 'Native and configuration execution without presentation'

reset_fixture extended
# Rename the actual function, then inject a failure only at Stage 04.
sed -i 's/^nl_ui_stage_begin() {/nl_ui_saved_stage_begin() {/' "$FIXTURE/scripts/lib/bootstrap-ui.sh"
grep -q '^nl_ui_saved_stage_begin() {' "$FIXTURE/scripts/lib/bootstrap-ui.sh" || fail 'Missing stage function'
cat >> "$FIXTURE/scripts/lib/bootstrap-ui.sh" <<'EOF'
nl_ui_stage_begin() {
    [ "$1" != 'NATIVE PREREQUISITES' ] || return 54
    nl_ui_saved_stage_begin "$@"
}
EOF
run_apply
status 0
contains 'REACHED_STAGE_06_BOUNDARY'
contains 'NATIVE_APPLY_OUTPUT'
absent '[05/08]'
trace_is version version enroll render-validator validate profile with-docker chronytop-policy apt-update 'apt-install:-y --no-install-recommends build-essential libatomic1' apply boundary
pass 'Stage 04 presentation failure preserves native execution'

# Application fixtures execute the real control flow through Stage 07.
app_prefix() {
    status 0
    contains 'REACHED_STAGE_08_BOUNDARY'
    contains '[06/08] APPLICATION CONVERGENCE'
    contains '[OK] Declared application versions converged.'
    contains '[07/08] CHRONYTOP POLICY'
    absent '[08/08]'
    absent 'BOOTSTRAP COMPLETE'
}
managed_run() { run_apply FIXTURE_PROFILE=proxmox FIXTURE_CHRONYTOP=managed "$@"; }
managed_trace() {
    trace_is version version enroll render-validator validate profile with-docker chronytop-policy apt-update 'apt-install:-y build-essential ca-certificates curl git gzip libatomic1 htop openssh-server procps sudo tar tmux vim' apply mise-install "$@"
}
no_stage_file() {
    [[ -z "$(find "$FIXTURE/managed" -name '.chronytop.*' -print -quit)" ]] || fail 'Staged binary leaked'
}
chronytop_failed() {
    status "$1"
    absent '[OK] Chronytop installed and verified.'
    absent '[OK] Chronytop already current and verified.'
    absent 'REACHED_STAGE_08_BOUNDARY'
    no_stage_file
}
reset_fixture applications
run_apply
app_prefix
contains '[SKIP] Chronytop is not managed for this profile.'
trace_is version version enroll render-validator validate profile with-docker chronytop-policy apt-update 'apt-install:-y --no-install-recommends build-essential libatomic1' apply mise-install boundary
pass 'Application convergence and skipped Chronytop'

reset_fixture applications
run_apply MISE_INSTALL_STATUS=61
status 61
absent '[OK] Declared application versions converged.'
absent '[07/08]'
absent 'REACHED_STAGE_08_BOUNDARY'
trace_is version version enroll render-validator validate profile with-docker chronytop-policy apt-update 'apt-install:-y --no-install-recommends build-essential libatomic1' apply mise-install
pass 'Mise convergence failure preserves exit status'

reset_fixture applications
cp "$FIXTURE/release" "$FIXTURE/managed/chronytop"
chmod 755 "$FIXTURE/managed/chronytop"
managed_run
app_prefix
contains '[OK] Chronytop already current and verified.'
managed_trace checksums verify-metadata chronytop-version boundary
pass 'Current Chronytop checksum and metadata verification'

reset_fixture applications
managed_run
app_prefix
contains '[OK] Chronytop installed and verified.'
cmp -s "$FIXTURE/release" "$FIXTURE/managed/chronytop" || fail 'Installed fixture mismatch'
no_stage_file
managed_trace checksums download stage-binary replace-binary chronytop-version boundary
pass 'Chronytop download checksum and atomic replacement'

reset_fixture applications
cp "$FIXTURE/release" "$FIXTURE/managed/chronytop"
chmod 700 "$FIXTURE/managed/chronytop"
managed_run
app_prefix
contains '[OK] Chronytop installed and verified.'
[[ $(stat -c %a "$FIXTURE/managed/chronytop") == 755 ]] || fail 'Incorrect fixture mode'
managed_trace checksums verify-metadata download stage-binary replace-binary chronytop-version boundary
pass 'Chronytop incorrect mode triggers replacement'

reset_fixture applications
managed_run CHECKSUM_STATUS=62
chronytop_failed 1
managed_trace checksums
pass 'Chronytop checksum retrieval failure'

reset_fixture applications
managed_run INVALID_CHECKSUM=1
chronytop_failed 1
managed_trace checksums
pass 'Chronytop malformed release checksum rejection'

reset_fixture applications
managed_run DOWNLOAD_STATUS=63
chronytop_failed 1
managed_trace checksums download
pass 'Chronytop download failure cleanup'

reset_fixture applications
managed_run CORRUPT_DOWNLOAD=1
chronytop_failed 1
managed_trace checksums download
pass 'Chronytop corrupt download rejected by real checksum'

reset_fixture applications
managed_run STAGE_STATUS=64
chronytop_failed 1
managed_trace checksums download stage-binary cleanup-stage
pass 'Chronytop staging failure cleanup'

reset_fixture applications
managed_run REPLACE_STATUS=65
chronytop_failed 1
managed_trace checksums download stage-binary replace-binary cleanup-stage
pass 'Chronytop replacement failure cleanup'

reset_fixture applications
managed_run CHRONYTOP_VERSION_STATUS=66
chronytop_failed 66
managed_trace checksums download stage-binary replace-binary chronytop-version
pass 'Chronytop final version failure preserves exit status'

reset_fixture applications
run_apply FIXTURE_CHRONYTOP=managed
chronytop_failed 1
trace_is version version enroll render-validator validate profile with-docker chronytop-policy apt-update 'apt-install:-y --no-install-recommends build-essential libatomic1' apply mise-install
pass 'Chronytop managed policy rejects non-Proxmox profile'

reset_fixture applications
rm "$FIXTURE/managed/chronyc"
managed_run
chronytop_failed 1
managed_trace
pass 'Chronytop requires existing Chrony executable'

reset_fixture applications
run_apply FIXTURE_CHRONYTOP=invalid
chronytop_failed 1
trace_is version version enroll render-validator validate profile with-docker chronytop-policy apt-update 'apt-install:-y --no-install-recommends build-essential libatomic1' apply mise-install
pass 'Unsupported Chronytop policy retains guard'

reset_fixture applications
rm "$FIXTURE/scripts/lib/bootstrap-ui.sh"
managed_run
status 0
contains 'REACHED_STAGE_08_BOUNDARY'
absent '[07/08]'
managed_trace checksums download stage-binary replace-binary chronytop-version boundary
pass 'Managed Chronytop without presentation'

reset_fixture applications
sed -i 's/^nl_ui_stage_begin() {/nl_ui_saved_stage_begin() {/' "$FIXTURE/scripts/lib/bootstrap-ui.sh"
cat >> "$FIXTURE/scripts/lib/bootstrap-ui.sh" <<'EOF'
nl_ui_stage_begin() {
    [ "$1" != 'CHRONYTOP POLICY' ] || return 67
    nl_ui_saved_stage_begin "$@"
}
EOF
managed_run
status 0
contains 'REACHED_STAGE_08_BOUNDARY'
absent '[07/08]'
managed_trace checksums download stage-binary replace-binary chronytop-version boundary
pass 'Chronytop presentation failure preserves execution'

# Full-length fixtures reach the natural production exit.
full_trace() {
    trace_is version version enroll render-validator validate profile with-docker chronytop-policy apt-update 'apt-install:-y --no-install-recommends build-essential libatomic1' apply mise-install "$@"
}
full_success() {
    status 0
    contains 'NovaLabs bootstrap completed successfully.'
    contains 'NATIVE_AUDIT_OUTPUT'
    absent 'REACHED_STAGE_'
    absent 'BOOTSTRAP COMPLETE'
    no_stage_file
}
reset_fixture full
run_apply
full_success
contains '[08/08] APPLICATION AUDIT AND PRUNING'
contains '[OK] Application audit completed.'
contains '[INFO] Pruning not requested.'
absent '[SKIP] Application audit'
absent 'NATIVE_PRUNE_OUTPUT'
full_trace audit
pass 'Full apply audits without implicit pruning'

reset_fixture full
run_apply --prune
full_success
contains '[OK] Application audit and pruning completed.'
contains 'NATIVE_PRUNE_OUTPUT'
absent 'Pruning not requested.'
full_trace audit prune
pass 'Explicit pruning follows successful audit'

reset_fixture full
run_apply --prune AUDIT_STATUS=71
status 71
absent 'Application audit completed.'
absent 'Application audit and pruning completed.'
absent 'NovaLabs bootstrap completed successfully.'
full_trace audit
pass 'Audit failure prevents pruning and preserves status'

reset_fixture full
run_apply --prune PRUNE_STATUS=72
status 72
absent 'Application audit and pruning completed.'
absent 'NovaLabs bootstrap completed successfully.'
full_trace audit prune
pass 'Prune failure preserves exit status'

reset_fixture full
rm "$FIXTURE/scripts/lib/bootstrap-ui.sh"
run_apply --prune
full_success
absent '[08/08]'
full_trace audit prune
pass 'Full apply with pruning without presentation'

reset_fixture full
sed -i 's/^nl_ui_stage_begin() {/nl_ui_saved_stage_begin() {/' "$FIXTURE/scripts/lib/bootstrap-ui.sh"
cat >> "$FIXTURE/scripts/lib/bootstrap-ui.sh" <<'EOF'
nl_ui_stage_begin() {
    [ "$1" != 'APPLICATION AUDIT AND PRUNING' ] || return 73
    nl_ui_saved_stage_begin "$@"
}
EOF
run_apply --prune
full_success
absent '[08/08]'
full_trace audit prune
pass 'Stage 08 rendering failure preserves audit and pruning'

reset_fixture full
managed_run
full_success
contains '[OK] Chronytop installed and verified.'
contains '[OK] Application audit completed.'
managed_trace checksums download stage-binary replace-binary chronytop-version audit
pass 'Full managed Chronytop apply reaches audit'

reset_fixture full
run_apply --prune MISE_INSTALL_STATUS=61
status 61
absent '[08/08]'
absent 'NovaLabs bootstrap completed successfully.'
full_trace
pass 'Earlier failure prevents audit and pruning'

printf '%s\n' '============================================================'
printf 'PASS: All %s apply integration checkpoints validated\n' "$passed"
