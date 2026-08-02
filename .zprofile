if [[ "$(uname -s)" == "Darwin" ]]; then
  for brew_bin in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    if [ -x "$brew_bin" ]; then
      eval "$("$brew_bin" shellenv)"
      break
    fi
  done
fi

# pyenv installs itself to ~/.pyenv (install.sh runs pyenv.run), but nothing
# put that on PATH — so `command -v pyenv` was always false and both
# `pyenv init` calls were permanently dead. ~/.local/bin doesn't cover it.
export PYENV_ROOT="$HOME/.pyenv"
if [ -d "$PYENV_ROOT/bin" ]; then
  export PATH="$PYENV_ROOT/bin:$PATH"
fi

command -v pyenv >/dev/null 2>&1 && eval "$(pyenv init --path)"
command -v thefuck >/dev/null 2>&1 && eval "$(thefuck --alias)"
