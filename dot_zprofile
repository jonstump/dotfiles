if [[ "$(uname -s)" == "Darwin" ]]; then
  for brew_bin in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    if [ -x "$brew_bin" ]; then
      eval "$("$brew_bin" shellenv)"
      break
    fi
  done
fi

command -v pyenv >/dev/null 2>&1 && eval "$(pyenv init --path)"
command -v thefuck >/dev/null 2>&1 && eval "$(thefuck --alias)"
