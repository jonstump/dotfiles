#!/usr/bin/env bash
# Installs tooling for whichever OS this is running on. Assumes the dotfiles
# are already checked out on top of $HOME (run bootstrap.sh first if not).
#
# Mac: Homebrew + Brewfile.
# Debian/Ubuntu-family Linux (apt): native apt packages from apt-packages.txt,
#   plus upstream installers for the handful of tools apt doesn't reliably
#   package (pyenv, nvm, oh-my-tmux).
# NixOS: packages are declared in a separate flake/home-manager repo, not
#   here — this only sets up the non-package config pieces (oh-my-tmux).
set -euo pipefail

DOTFILES_DIR="$HOME/Repos/dotfiles"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

detect_os() {
  if [ -f /etc/NIXOS ] || { [ -f /etc/os-release ] && grep -qi '^ID=nixos' /etc/os-release; }; then
    echo "nixos"
  elif [ "$(uname -s)" = "Darwin" ]; then
    echo "mac"
  elif command -v apt >/dev/null 2>&1; then
    echo "apt"
  else
    echo "unknown"
  fi
}

install_oh_my_tmux() {
  local target="$HOME/.local/share/tmux/oh-my-tmux"
  if [ ! -d "$target" ]; then
    echo "Cloning oh-my-tmux -> $target"
    git clone https://github.com/gpakosz/.tmux.git "$target"
  fi
}

install_nvm() {
  if [ ! -d "$HOME/.nvm" ]; then
    echo "Installing nvm"
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
  fi
}

install_pyenv() {
  if [ ! -d "$HOME/.pyenv" ]; then
    echo "Installing pyenv"
    curl https://pyenv.run | bash
  fi
}

install_mac() {
  if ! command -v brew >/dev/null 2>&1; then
    echo "Installing Homebrew"
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi
  for brew_bin in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    [ -x "$brew_bin" ] && eval "$("$brew_bin" shellenv)" && break
  done

  # Config setup first: it's cheap and reliable, and must not be skipped just
  # because a package install failed. .zshrc execs into tmux on every
  # interactive shell, so a missing oh-my-tmux clone leaves a fresh Mac in an
  # unconfigured tmux with no obvious way out.
  install_oh_my_tmux

  # Package installation is the least reliable step here — a single broken or
  # disabled formula aborts the whole bundle. Don't let that take the rest of
  # the install down with it.
  if ! brew bundle --file="$SCRIPT_DIR/Brewfile"; then
    echo "WARNING: some Brewfile entries failed to install; continuing." >&2
  fi
}

# Adds a third-party apt repo with a modern signed-by keyring (not the
# deprecated apt-key), if it isn't already configured.
add_apt_repo() {
  local name="$1" key_url="$2" repo_line="$3"
  local keyring="/usr/share/keyrings/${name}.gpg"
  local list_file="/etc/apt/sources.list.d/${name}.list"

  if [ -f "$list_file" ]; then
    return
  fi

  echo "Adding apt repo: $name"
  curl -fsSL "$key_url" | gpg --dearmor | sudo tee "$keyring" >/dev/null
  echo "$repo_line" | sudo tee "$list_file" >/dev/null
}

install_apt() {
  add_apt_repo signal-desktop \
    "https://updates.signal.org/desktop/apt/keys.asc" \
    "deb [arch=amd64 signed-by=/usr/share/keyrings/signal-desktop.gpg] https://updates.signal.org/desktop/apt xenial main"

  sudo apt-get update

  # apt is all-or-nothing: one unresolvable name means nothing gets installed,
  # and `set -e` would then kill the rest of the installer. apt-packages.txt is
  # explicitly a best-effort list (names vary by distro/release), so try the
  # fast batch path first and fall back to per-package on failure.
  local pkgs=()
  while IFS= read -r pkg; do
    [ -n "$pkg" ] && pkgs+=("$pkg")
  done < <(sed -e 's/#.*//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e '/^$/d' "$SCRIPT_DIR/apt-packages.txt")

  if [ "${#pkgs[@]}" -gt 0 ]; then
    if ! sudo apt-get install -y "${pkgs[@]}"; then
      echo "Batch install failed; retrying package-by-package." >&2
      for pkg in "${pkgs[@]}"; do
        sudo apt-get install -y "$pkg" || echo "SKIP (unavailable): $pkg" >&2
      done
    fi
  fi

  install_nvm
  install_pyenv
  install_oh_my_tmux

  sudo chsh -s "$(command -v zsh)" "$USER"
}

install_nixos() {
  echo "NixOS detected: packages are managed by your flake/home-manager repo," \
       "not this one. Only setting up non-package config here."
  install_oh_my_tmux
}

case "$(detect_os)" in
  mac)    install_mac ;;
  apt)    install_apt ;;
  nixos)  install_nixos ;;
  *)      echo "Unrecognized OS/package manager — skipping package installation." >&2 ;;
esac

echo
echo "Done. Open a new shell (or reattach tmux) to pick everything up."
