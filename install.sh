#!/usr/bin/env bash
# Installs tooling for whichever OS this is running on. Assumes the dotfiles
# are already checked out on top of $HOME (run bootstrap.sh first if not).
#
# Mac: Homebrew + Brewfile.
# Debian/Ubuntu-family Linux (apt): native apt packages from apt-packages.txt,
#   plus upstream installers for the handful of tools apt doesn't reliably
#   package (pyenv, nvm, topgrade, oh-my-tmux).
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

install_topgrade() {
  if ! command -v topgrade >/dev/null 2>&1; then
    echo "Installing topgrade"
    pipx install topgrade
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

# Debian/Ubuntu ship a neovim far too old for the LazyVim config in
# .config/nvim (Ubuntu 24.04 is 0.9.5, Debian 12 is 0.7.2; LazyVim's health
# check hard-errors below 0.11.2), so take the upstream release instead of the
# distro package.
nvim_meets_lazyvim_min() {
  command -v nvim >/dev/null 2>&1 || return 1
  local ver
  ver="$(nvim --version 2>/dev/null | sed -n '1s/^NVIM v//p')"
  [ -n "$ver" ] || return 1
  awk -v v="$ver" 'BEGIN {
    split(v, p, ".")
    if (p[1]+0 > 0) exit 0
    if (p[2]+0 > 11) exit 0
    if (p[2]+0 == 11 && p[3]+0 >= 2) exit 0
    exit 1
  }'
}

install_neovim() {
  if nvim_meets_lazyvim_min; then
    return
  fi

  local machine target
  machine="$(uname -m)"
  case "$machine" in
    x86_64|amd64)  target="nvim-linux-x86_64" ;;
    aarch64|arm64) target="nvim-linux-arm64" ;;
    *)
      echo "No upstream neovim build for $machine — install neovim >= 0.11.2 yourself." >&2
      return
      ;;
  esac

  echo "Installing neovim ($target, upstream release)"
  local tmp
  tmp="$(mktemp -d)"
  if curl -fsSL "https://github.com/neovim/neovim/releases/latest/download/${target}.tar.gz" \
       | tar -xz -C "$tmp"; then
    sudo rm -rf "/opt/$target"
    sudo mv "$tmp/$target" /opt/
    sudo ln -sf "/opt/$target/bin/nvim" /usr/local/bin/nvim
  else
    echo "WARNING: neovim download failed; skipping." >&2
  fi
  rm -rf "$tmp"
}

# Adds a third-party apt repo with a modern signed-by keyring (not the
# deprecated apt-key), if it isn't already configured.
#
# Keys go in /etc/apt/keyrings, not /usr/share/keyrings — the latter is
# reserved for keys shipped by distro packages (Debian's
# DebianRepository/UseThirdParty). The keyring is written to a temp file first
# so a failed download can't leave an empty one behind, and the idempotency
# guard checks both files: guarding on the .list alone meant a missing or empty
# keyring made this return early forever, and every later `apt-get update`
# fail with NO_PUBKEY.
add_apt_repo() {
  local name="$1" key_url="$2" repo_line="$3"
  local keyring="/etc/apt/keyrings/${name}.gpg"
  local list_file="/etc/apt/sources.list.d/${name}.list"

  if [ -s "$keyring" ] && [ -f "$list_file" ]; then
    return
  fi

  echo "Adding apt repo: $name"
  local tmp
  tmp="$(mktemp)"
  if curl -fsSL "$key_url" | gpg --dearmor > "$tmp" && [ -s "$tmp" ]; then
    sudo install -d -m 0755 /etc/apt/keyrings
    sudo install -m 0644 "$tmp" "$keyring"
    echo "$repo_line" | sudo tee "$list_file" >/dev/null
  else
    echo "WARNING: could not fetch the $name signing key; skipping that repo." >&2
  fi
  rm -f "$tmp"
}

# Reads a package manifest into the global PKGS array, stripping '#' comments,
# surrounding whitespace and blank lines.
read_manifest() {
  PKGS=()
  local line
  while IFS= read -r line; do
    [ -n "$line" ] && PKGS+=("$line")
  done < <(sed -e 's/#.*//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e '/^$/d' "$1")
}

# apt is all-or-nothing: one unresolvable name means nothing gets installed,
# and `set -e` would then kill the rest of the installer. The manifests are
# explicitly best-effort (names vary by distro/release), so try the fast batch
# path first and fall back to per-package on failure.
apt_install_manifest() {
  local file="$1"
  [ -f "$file" ] || return 0

  read_manifest "$file"
  [ "${#PKGS[@]}" -gt 0 ] || return 0

  if ! sudo apt-get install -y "${PKGS[@]}"; then
    echo "Batch install of $(basename "$file") failed; retrying package-by-package." >&2
    local pkg
    for pkg in "${PKGS[@]}"; do
      sudo apt-get install -y "$pkg" || echo "SKIP (unavailable): $pkg" >&2
    done
  fi
}

# Desktop apps are opt-in on headless boxes rather than mandatory. Set
# DOTFILES_DESKTOP=1/0 to force it either way.
want_desktop_packages() {
  case "${DOTFILES_DESKTOP:-}" in
    1|yes|true)  return 0 ;;
    0|no|false)  return 1 ;;
  esac

  if [ -n "${DISPLAY:-}" ] || [ -n "${WAYLAND_DISPLAY:-}" ]; then
    return 0
  fi
  [ -d /usr/share/xsessions ] || [ -d /usr/share/wayland-sessions ]
}

# The old `sudo chsh -s "$(command -v zsh)" "$USER"` was fragile in three ways:
# $USER isn't always set (fatal under `set -u`), it's `root` under
# `sudo ./install.sh`, and a Nix-store zsh isn't listed in /etc/shells (so chsh
# exits non-zero and, as the last command under `set -e`, aborted the whole
# installer) as well as being garbage-collectable, which can lock you out.
set_login_shell() {
  local target_user zsh_path current
  target_user="$(id -un)"
  zsh_path="$(command -v zsh || true)"

  # Prefer a system zsh over a Nix-store one — store paths are GC-able.
  case "$zsh_path" in
    /nix/store/*|"$HOME"/.nix-profile/*)
      if [ -x /usr/bin/zsh ]; then zsh_path=/usr/bin/zsh; else zsh_path=""; fi
      ;;
  esac

  if [ -z "$zsh_path" ]; then
    echo "Skipping chsh: no suitable zsh found." >&2
    return
  fi

  current="$(getent passwd "$target_user" | cut -d: -f7 || true)"
  if [ "$current" = "$zsh_path" ]; then
    return
  fi

  if ! grep -qxF "$zsh_path" /etc/shells 2>/dev/null; then
    echo "Skipping chsh: '$zsh_path' is not in /etc/shells." >&2
    echo "Set your login shell manually if you want zsh." >&2
    return
  fi

  sudo chsh -s "$zsh_path" "$target_user"
}

install_apt() {
  if ! command -v sudo >/dev/null 2>&1; then
    echo "sudo is required for the apt install path. Install it (or run as a" >&2
    echo "user in the sudo group) and re-run this script." >&2
    exit 1
  fi
  export DEBIAN_FRONTEND=noninteractive

  # add_apt_repo needs curl and gpg, and neither is guaranteed on a minimal
  # Debian image — bootstrap them before adding any repo.
  sudo apt-get update
  sudo apt-get install -y curl gnupg ca-certificates

  # Signal publishes an amd64 build only, so don't add a repo that can't
  # resolve on arm64 (a Pi, an Ampere box, an Asahi/UTM VM).
  if [ "$(dpkg --print-architecture)" = "amd64" ]; then
    add_apt_repo signal-desktop \
      "https://updates.signal.org/desktop/apt/keys.asc" \
      "deb [arch=amd64 signed-by=/etc/apt/keyrings/signal-desktop.gpg] https://updates.signal.org/desktop/apt xenial main"
  fi

  sudo apt-get update

  apt_install_manifest "$SCRIPT_DIR/apt-packages.txt"

  if want_desktop_packages; then
    apt_install_manifest "$SCRIPT_DIR/apt-packages-desktop.txt"
  else
    echo "No display environment detected — skipping apt-packages-desktop.txt."
    echo "(Set DOTFILES_DESKTOP=1 to install them anyway.)"
  fi

  install_neovim
  install_nvm
  install_pyenv
  install_topgrade
  install_oh_my_tmux

  set_login_shell
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
