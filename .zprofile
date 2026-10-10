# Make Mise-managed tools available to login and non-interactive descendants.
if (( $+commands[mise] )); then
  eval "$(mise activate zsh --shims)"
fi
