#!/usr/bin/env bash
# Validate NovaLabs theme environment activation.
# Requires Bash 4.2+ and standard Linux utilities.
# Uses temporary HOME directories and clean shell environments.

set -euo pipefail

if [[ "${1:-}" != "--scenario" ]]; then
  ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
  TEST_ROOT="$(mktemp -d /tmp/novalabs-theme-env.XXXXXXXX)"

  trap 'rm -rf -- "$TEST_ROOT"' EXIT

  ENV_SOURCE="$ROOT/private_dot_config/novalab/bash/env.sh"

  bash -n "$ENV_SOURCE"

  printf 'NovaLabs theme environment validation\n'
  printf '%s\n' '============================================================'

  for scenario in \
    neither tui-only k9s-only both \
    overrides empty custom-xdg repeated
  do
    env -i \
      PATH="/usr/bin:/bin" \
      LANG="C.UTF-8" \
      TEST_ROOT="$TEST_ROOT" \
      ENV_SOURCE="$ENV_SOURCE" \
      /bin/bash --noprofile --norc \
      "${BASH_SOURCE[0]}" --scenario "$scenario"
  done

  printf '%s\n' '============================================================'
  printf 'PASS: All 8 shell activation scenarios validated\n'
  exit 0
fi

shift

scenario="$1"

export HOME="$TEST_ROOT/$scenario/home"
mkdir -p "$HOME/bin" "$HOME/.local/bin"

config="$HOME/.config"
expected_tui=""
expected_k9s=""

if [[ "$scenario" == "custom-xdg" ]]; then
  export XDG_CONFIG_HOME="$TEST_ROOT/$scenario/custom-config"
  config="$XDG_CONFIG_HOME"
fi

case "$scenario" in
  neither)
    ;;
  tui-only)
    mkdir -p "$config/novalab/themes"
    touch "$config/novalab/themes/tui-kit.toml"
    expected_tui="$config/novalab/themes/tui-kit.toml"
    ;;
  k9s-only)
    mkdir -p "$config/k9s/skins"
    touch "$config/k9s/skins/novalab.yaml"
    expected_k9s="novalab"
    ;;
  both|overrides|empty|custom-xdg|repeated)
    mkdir -p "$config/novalab/themes" "$config/k9s/skins"
    touch "$config/novalab/themes/tui-kit.toml"
    touch "$config/k9s/skins/novalab.yaml"

    expected_tui="$config/novalab/themes/tui-kit.toml"
    expected_k9s="novalab"
    ;;
  *)
    echo "FAIL: Unknown scenario: $scenario"
    exit 1
    ;;
esac

if [[ "$scenario" == "overrides" ]]; then
  export TUI_THEME="user-custom-theme"
  export K9S_SKIN="user-custom-skin"
  expected_tui="$TUI_THEME"
  expected_k9s="$K9S_SKIN"
elif [[ "$scenario" == "empty" ]]; then
  export TUI_THEME=""
  export K9S_SKIN=""
fi

source "$ENV_SOURCE"

if [[ "$scenario" == "repeated" ]]; then
  first_path="$PATH"
  source "$ENV_SOURCE"

  [[ "$PATH" == "$first_path" ]] || {
    echo "FAIL: PATH changed after repeated sourcing"
    exit 1
  }
fi

[[ "${TUI_THEME:-}" == "$expected_tui" ]] || {
  echo "FAIL: $scenario: TUI_THEME mismatch"
  exit 1
}

[[ "${K9S_SKIN:-}" == "$expected_k9s" ]] || {
  echo "FAIL: $scenario: K9S_SKIN mismatch"
  exit 1
}

if [[ -z "$expected_tui" && -v TUI_THEME ]]; then
  echo "FAIL: $scenario: TUI_THEME should be unset"
  exit 1
fi

if [[ -z "$expected_k9s" && -v K9S_SKIN ]]; then
  echo "FAIL: $scenario: K9S_SKIN should be unset"
  exit 1
fi

printf 'PASS  %-15s TUI_THEME=%s K9S_SKIN=%s\n' \
  "$scenario" \
  "${TUI_THEME:-<unset>}" \
  "${K9S_SKIN:-<unset>}"
