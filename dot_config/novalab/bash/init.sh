# shellcheck shell=bash

# This file must be sourced by an interactive Bash shell.
if [[ $- != *i* ]]; then
  return 0
fi

_novalab_bash_dir="$(
  cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 &&
    pwd -P
)" || return 1

# Environment first: establishes XDG paths and ~/.local/bin.
if [[ -r "${_novalab_bash_dir}/env.sh" ]]; then
  # shellcheck disable=SC1090
  source "${_novalab_bash_dir}/env.sh"
fi

# Shell behavior and helpers do not depend on Mise.
for _novalab_file in \
  options.sh \
  functions.sh
do
  if [[ -r "${_novalab_bash_dir}/${_novalab_file}" ]]; then
    # shellcheck disable=SC1090
    source "${_novalab_bash_dir}/${_novalab_file}"
  fi
done

# Activate the Mise-managed toolchain before resolving command aliases.
if command -v mise >/dev/null 2>&1; then
  eval "$(mise activate bash)"
elif [[ -x "${HOME}/.local/bin/mise" ]]; then
  eval "$("${HOME}/.local/bin/mise" activate bash)"
fi

if [[ -r "${_novalab_bash_dir}/aliases.sh" ]]; then
  # shellcheck disable=SC1090
  source "${_novalab_bash_dir}/aliases.sh"
fi

# Expose the canonical NovaLabs host profile to the interactive environment.
_novalab_host_file="${XDG_CONFIG_HOME}/novalab/host"

if [[ -r "${_novalab_host_file}" ]]; then
  IFS= read -r NOVALAB_HOST_PROFILE < "${_novalab_host_file}"
fi

if [[ -z "${NOVALAB_HOST_PROFILE:-}" ]]; then
  NOVALAB_HOST_PROFILE="$(
    (hostname -s 2>/dev/null || hostname) |
      tr '[:upper:]' '[:lower:]'
  )"
fi

export NOVALAB_HOST_PROFILE

# Starship is provided by Mise on managed hosts.
if command -v starship >/dev/null 2>&1; then
  eval "$(starship init bash)"
fi

unset _novalab_bash_dir
unset _novalab_file
unset _novalab_host_file
