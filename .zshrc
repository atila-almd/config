# Only interactive shells need completions, directory hooks, or a prompt.
[[ -o interactive ]] || return

alias ls='ls --color=auto'
alias ll='ls -la'
alias la='ls -a'
alias grep='grep --color=auto'

autoload -Uz compinit
compinit

# Mise updates tool versions and environment variables as directories change.
if (( $+commands[mise] )); then
  eval "$(mise activate zsh)"
fi

# Zoxide is loaded after compinit so its Zsh completions are registered.
if (( $+commands[zoxide] )); then
  eval "$(zoxide init zsh)"
fi

# Starship initializes last and owns the final interactive prompt.
if (( $+commands[starship] )); then
  eval "$(starship init zsh)"
else
  PS1='[%n@%m %1~]\$ '
fi
