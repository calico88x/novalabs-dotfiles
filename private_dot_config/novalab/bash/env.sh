# shellcheck shell=bash

export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-${HOME}/.config}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-${HOME}/.cache}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-${HOME}/.local/state}"

# Default to the managed NovaLabs TUI theme when available.
# Preserve an explicitly configured user theme.
if [[ -r "${XDG_CONFIG_HOME}/novalab/themes/tui-kit.toml" ]]; then
  export TUI_THEME="${TUI_THEME:-${XDG_CONFIG_HOME}/novalab/themes/tui-kit.toml}"
fi

# Default to the managed NovaLabs K9s skin when available.
# Preserve an explicitly configured user skin.
if [[ -r "${XDG_CONFIG_HOME}/k9s/skins/novalab.yaml" ]]; then
  export K9S_SKIN="${K9S_SKIN:-novalab}"
fi

_novalab_path_prepend() {
  local directory="$1"

  if [[ -d "${directory}" ]]; then
    case ":${PATH}:" in
      *":${directory}:"*) ;;
      *) PATH="${directory}:${PATH}" ;;
    esac
  fi
}

_novalab_path_prepend "${HOME}/bin"
_novalab_path_prepend "${HOME}/.local/bin"

export PATH

export EDITOR="${EDITOR:-vim}"
export VISUAL="${VISUAL:-${EDITOR}}"
export PAGER="${PAGER:-less}"
export LESS="${LESS:--R -F -X}"

# Use an available UTF-8 locale when the inherited locale is empty or plain C.
case "${LANG:-}" in
  ''|C|POSIX)
    if command -v locale >/dev/null 2>&1; then
      _novalab_utf8_locale="$(
        locale -a 2>/dev/null |
          awk 'tolower($0) == "c.utf-8" || tolower($0) == "c.utf8" { print; exit }'
      )"

      if [[ -n "${_novalab_utf8_locale}" ]]; then
        export LANG="${_novalab_utf8_locale}"
      fi
    fi
    ;;
esac

unset _novalab_utf8_locale
unset -f _novalab_path_prepend
