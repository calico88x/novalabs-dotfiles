#!/usr/bin/env bash
# Validate NovaLabs K9s filesystem permissions on Linux.

set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

[[ "$(uname -s)" == "Linux" ]] ||
  fail "This test requires Linux"

command -v chezmoi >/dev/null 2>&1 ||
  fail "ChezMoi is required"

umask 022

TEST_ROOT="$(mktemp -d /tmp/novalabs-theme-permissions.XXXXXXXX)"
trap 'rm -rf -- "$TEST_ROOT"' EXIT

SOURCE="$TEST_ROOT/source"
DESTINATION="$TEST_ROOT/destination"
CONFIG="$TEST_ROOT/chezmoi.toml"
CACHE="$TEST_ROOT/cache"
PERSISTENT_STATE="$TEST_ROOT/state.boltdb"

mkdir -p "$SOURCE" "$DESTINATION" "$CACHE"

# Use the actual repository theme data and K9s source attributes.
# Exclude unrelated applications, bootstrap scripts and migrations.
cp -R -- "$ROOT/.chezmoidata" "$SOURCE/.chezmoidata"

mkdir -p "$SOURCE/private_dot_config"

cp -R -- \
  "$ROOT/private_dot_config/private_k9s" \
  "$SOURCE/private_dot_config/"

# Isolate ChezMoi configuration and persistent state from the host.
cat > "$CONFIG" <<'EOF'
[data]
    profile = "any"
    withDocker = false
EOF

run_chezmoi() {
  chezmoi \
    --config "$CONFIG" \
    --source "$SOURCE" \
    --destination "$DESTINATION" \
    --cache "$CACHE" \
    --persistent-state "$PERSISTENT_STATE" \
    "$@"
}

check_mode() {
  local path="$1"
  local expected="$2"
  local actual

  [[ -e "$path" ]] ||
    fail "Missing destination: $path"

  actual="$(stat -c '%a' -- "$path")"

  [[ "$actual" == "$expected" ]] ||
    fail "$path: expected $expected, found $actual"
}

K9S="$DESTINATION/.config/k9s"
SKINS="$K9S/skins"
SKIN="$SKINS/novalab.yaml"

check_permissions() {
  check_mode "$DESTINATION/.config" 700
  check_mode "$K9S" 700
  check_mode "$SKINS" 700
  check_mode "$SKIN" 644

  [[ -s "$SKIN" ]] ||
    fail "Generated K9s skin is empty"
}

check_convergence() {
  local diff

  diff="$(run_chezmoi diff)"

  [[ -z "$diff" ]] ||
    fail "Unexpected configuration drift: $diff"
}

printf 'NovaLabs K9s permission validation\n'
printf '%s\n' '============================================================'

# Scenario 1: Fresh installation.
run_chezmoi apply --force
check_permissions
check_convergence

printf 'PASS: Fresh installation permissions\n'

# Scenario 2: Reproduce an existing K9s configuration.
rm -rf -- "$K9S"

mkdir -p "$SKINS"

chmod 700 "$K9S"
chmod 744 "$SKINS"

printf 'k9s:\n  readOnly: true\n' > "$K9S/config.yaml"
printf 'aliases:\n  po: pods\n' > "$K9S/aliases.yaml"

chmod 600 "$K9S/config.yaml" "$K9S/aliases.yaml"

CONFIG_HASH="$(sha256sum "$K9S/config.yaml")"
ALIASES_HASH="$(sha256sum "$K9S/aliases.yaml")"

check_user_state() {
  check_mode "$K9S/config.yaml" 600
  check_mode "$K9S/aliases.yaml" 600

  [[ "$(sha256sum "$K9S/config.yaml")" == "$CONFIG_HASH" ]] ||
    fail "Existing K9s configuration was modified"

  [[ "$(sha256sum "$K9S/aliases.yaml")" == "$ALIASES_HASH" ]] ||
    fail "Existing K9s aliases were modified"
}

run_chezmoi apply --force
check_permissions
check_user_state
check_convergence

printf 'PASS: Existing installation permissions and state preservation\n'

# Scenario 3: Correct permission drift and verify idempotency.
SKIN_HASH="$(sha256sum "$SKIN")"

chmod 755 "$K9S" "$SKINS"

run_chezmoi apply --force
check_permissions
check_user_state

[[ "$(sha256sum "$SKIN")" == "$SKIN_HASH" ]] ||
  fail "Skin content changed during permission correction"

run_chezmoi apply --force
check_permissions
check_user_state
check_convergence

[[ "$(sha256sum "$SKIN")" == "$SKIN_HASH" ]] ||
  fail "Skin content changed during repeated reconciliation"

printf 'PASS: Permission drift correction and idempotency\n'
printf '%s\n' '============================================================'
printf 'PASS: 3 filesystem scenarios validated\n'
