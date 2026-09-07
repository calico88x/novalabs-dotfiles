# shellcheck shell=bash

HISTCONTROL="ignoreboth:erasedups"
HISTSIZE=10000
HISTFILESIZE=20000
HISTTIMEFORMAT="%Y-%m-%d %H:%M:%S  "

export HISTCONTROL
export HISTSIZE
export HISTFILESIZE
export HISTTIMEFORMAT

shopt -s checkwinsize
shopt -s cmdhist
shopt -s histappend

# Write new commands to the history file after every prompt.
_novalab_history_sync='history -a'

if [[ -n "${PROMPT_COMMAND:-}" ]]; then
  case ";${PROMPT_COMMAND};" in
    *";${_novalab_history_sync};"*) ;;
    *) PROMPT_COMMAND="${_novalab_history_sync};${PROMPT_COMMAND}" ;;
  esac
else
  PROMPT_COMMAND="${_novalab_history_sync}"
fi

export PROMPT_COMMAND

unset _novalab_history_sync
