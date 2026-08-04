#!/usr/bin/env bash
# Installs tooling for whichever OS this is running on. Assumes the dotfiles
# have already been applied by chezmoi (run bootstrap.sh first if not).
#
# Mac: Homebrew + Brewfile.
# Debian/Ubuntu-family Linux (apt): native apt packages from apt-packages.txt,
#   plus upstream installers for the handful of tools apt doesn't reliably
#   package (pyenv, nvm, oh-my-tmux, antidote — always upstream, since the
#   dotfiles that load them only look in fixed non-apt locations — and
#   lazygit/topgrade, which check apt first and only fall back to upstream if
#   this distro/release doesn't package them).
# Nix (any Linux host): packages are declared in a separate flake/home-manager
#   repo, not here — this only sets up the non-package config pieces
#   (oh-my-tmux, antidote).
set -euo pipefail

# Everything here is resolved relative to the script itself. This file lives
# outside chezmoi's source root (see .chezmoiroot), next to the Brewfile and
# package manifests, at the repo root — one level above `chezmoi source-path`,
# which .chezmoiroot points at the home/ subdirectory.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

detect_os() {
  if [ "$(uname -s)" = "Darwin" ]; then
    # nix-darwin looks exactly like plain macOS to `uname`, so it used to fall
    # into install_mac — installing Homebrew and running the whole Brewfile,
    # much of which the flake already provides. Keep brew as a choice there.
    if [ -e /run/current-system/sw/bin/darwin-rebuild ]; then
      echo "nix-darwin"
    else
      echo "mac"
    fi
    return
  fi

  if command -v apt-get >/dev/null 2>&1; then
    echo "apt"
  elif command -v nix >/dev/null 2>&1; then
    # Nix on Fedora/Arch/anything else used to fall through to "unknown" and
    # do nothing at all — not even the platform-independent oh-my-tmux clone.
    echo "nix"
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

# True if apt has an installable candidate for $1 on this machine. Package
# sets vary by distro and drift over time even on one distro (e.g. lazygit
# landed in Debian testing after this script first needed the upstream
# fallback below), and this repo's apt path isn't limited to one distro's
# archive — so check apt at run time instead of hardcoding "not packaged" and
# letting that guess go stale or wrong. Also safe to call from the
# mac/nix-darwin/nix paths, where apt-cache doesn't exist at all.
apt_has_candidate() {
  command -v apt-cache >/dev/null 2>&1 || return 1
  local candidate
  candidate="$(apt-cache policy "$1" 2>/dev/null | awk -F': ' '/Candidate:/{print $2; exit}')"
  [ -n "$candidate" ] && [ "$candidate" != "(none)" ]
}

# zsh plugin manager, replacing antigen (#26). Cloned rather than installed as
# a package because it's pure zsh and apt has no version of it across the
# releases this repo targets, so one mechanism covers all three platforms.
# Not apt_has_candidate-checked like lazygit/topgrade below: .zshrc discovers
# antidote by checking a fixed list of paths (nix, Homebrew, or this clone at
# ~/.antidote), not via `command -v`, so an apt package landing anywhere else
# would silently go unused instead of being picked up.
# .zshrc clones it too if it's missing; doing it here keeps the first shell
# after install.sh from paying for it.
install_antidote() {
  local target="$HOME/.antidote" packaged
  # Skip if the flake repo or Homebrew already provides one — .zshrc prefers
  # those over the clone, so cloning anyway would leave an unused copy that
  # nothing ever updates. (Written as an if rather than `[ -e ] && return`:
  # that form leaves the loop with a non-zero status on the last iteration,
  # which is a live grenade under the `set -e` at the top of this file.)
  for packaged in \
    /run/current-system/sw/share/antidote/antidote.zsh \
    "$HOME/.nix-profile/share/antidote/antidote.zsh" \
    "${HOMEBREW_PREFIX:-}/share/antidote/antidote.zsh"
  do
    if [ -e "$packaged" ]; then
      return 0
    fi
  done

  if [ ! -d "$target" ]; then
    echo "Cloning antidote -> $target"
    git clone --depth=1 https://github.com/mattmc3/antidote.git "$target"
  fi
}

# Not apt_has_candidate-checked: .zshrc only sources nvm from $HOME/.nvm/nvm.sh
# (or the Homebrew formula's path on Mac), never from `command -v nvm`, so an
# apt package wouldn't land where .zshrc looks and would silently go unused.
install_nvm() {
  if [ ! -d "$HOME/.nvm" ]; then
    echo "Installing nvm"
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
  fi
}

# Debian renames both of these to avoid clashing with existing packages: the
# `bat` deb ships /usr/bin/batcat and `fd-find` ships /usr/bin/fdfind, so `bat`
# and `fd` are "command not found" after a successful install. Symlinking into
# ~/.local/bin (already on PATH) fixes non-interactive callers too, which
# aliases alone can't.
link_debian_renamed_bins() {
  mkdir -p "$HOME/.local/bin"
  local real alias_name
  for pair in "batcat:bat" "fdfind:fd"; do
    real="${pair%%:*}"
    alias_name="${pair##*:}"
    if command -v "$real" >/dev/null 2>&1 && ! command -v "$alias_name" >/dev/null 2>&1; then
      ln -sf "$(command -v "$real")" "$HOME/.local/bin/$alias_name"
    fi
  done
}

# kitty.conf asks for "mononoki Nerd Font Mono". No Nerd Font is packaged in
# the Debian/Ubuntu archive (fonts-mononoki is upstream Mononoki, not the
# patched build), so kitty falls back to a default and powerlevel10k and
# LazyVim icons render as tofu.
install_nerd_font() {
  local dir="$HOME/.local/share/fonts"
  if [ -n "$(find "$dir" -iname 'Mononoki*Nerd*' -print -quit 2>/dev/null)" ]; then
    return
  fi
  if ! command -v unzip >/dev/null 2>&1; then
    echo "Skipping Nerd Font install: unzip is not available." >&2
    return
  fi

  echo "Installing Mononoki Nerd Font"
  mkdir -p "$dir"
  local tmp
  tmp="$(mktemp -d)"
  if curl -fsSL -o "$tmp/mononoki.zip" \
       https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Mononoki.zip \
     && unzip -oq "$tmp/mononoki.zip" -d "$dir"; then
    command -v fc-cache >/dev/null 2>&1 && fc-cache -f >/dev/null
  else
    echo "WARNING: Nerd Font download failed; skipping." >&2
  fi
  rm -rf "$tmp"
}

# Prints the latest release tag of <owner>/<repo>, with any leading "v"
# stripped. Needed because some projects put the version in their asset
# filenames, so /releases/latest/download/ can't be used directly the way it
# can for neovim.
github_latest_version() {
  curl -fsSL "https://api.github.com/repos/$1/releases/latest" \
    | sed -n 's/.*"tag_name": *"v\{0,1\}\([^"]*\)".*/\1/p' | head -1
}

# LazyVim's health check looks for lazygit. Not in the Debian/Ubuntu archive
# as of writing, but apt_has_candidate re-checks in case that has changed.
install_lazygit() {
  command -v lazygit >/dev/null 2>&1 && return

  if apt_has_candidate lazygit; then
    echo "Installing lazygit (apt)"
    sudo apt-get install -y lazygit
    return
  fi

  local machine target
  machine="$(uname -m)"
  case "$machine" in
    x86_64|amd64)  target="Linux_x86_64" ;;
    aarch64|arm64) target="Linux_arm64" ;;
    *)
      echo "No upstream lazygit build for $machine — skipping." >&2
      return
      ;;
  esac

  local version
  version="$(github_latest_version jesseduffield/lazygit)"
  if [ -z "$version" ]; then
    echo "WARNING: could not resolve the latest lazygit version; skipping." >&2
    return
  fi

  echo "Installing lazygit $version ($target, upstream release)"
  local tmp
  tmp="$(mktemp -d)"
  if curl -fsSL "https://github.com/jesseduffield/lazygit/releases/download/v${version}/lazygit_${version}_${target}.tar.gz" \
       | tar -xz -C "$tmp" lazygit; then
    mkdir -p "$HOME/.local/bin"
    install -m 0755 "$tmp/lazygit" "$HOME/.local/bin/lazygit"
  else
    echo "WARNING: lazygit download failed; skipping." >&2
  fi
  rm -rf "$tmp"
}

# Not apt_has_candidate-checked: .zprofile hardcodes PYENV_ROOT to
# $HOME/.pyenv and only puts $PYENV_ROOT/bin on PATH, so an apt-installed
# pyenv landing in a system location wouldn't be found there and pyenv init
# would silently stay dead.
install_pyenv() {
  if [ ! -d "$HOME/.pyenv" ]; then
    echo "Installing pyenv"
    curl https://pyenv.run | bash
  fi
}

# README.md points at topgrade for updates and apt-packages.txt claims
# install.sh installs it — but nothing did, and as of writing it isn't
# packaged for Debian/Ubuntu (macOS was always fine; it's in the Brewfile), so
# check apt first and fall back to pipx. topgrade-rs publishes to PyPI, and
# pipx is already in apt-packages.txt, so that's simpler than fetching and
# unpacking the release tarball per-arch.
install_topgrade() {
  command -v topgrade >/dev/null 2>&1 && return

  if apt_has_candidate topgrade; then
    echo "Installing topgrade (apt)"
    sudo apt-get install -y topgrade
    return
  fi

  echo "Installing topgrade (pipx)"
  pipx install topgrade
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
  install_antidote

  # The Homebrew nvm formula's caveats say to create this yourself, and nothing
  # here did — so .zshrc's `[ -s "$NVM_DIR/nvm.sh" ]` failed, it fell through
  # to the Homebrew copy, and nvm loaded with NVM_DIR pointing at a directory
  # that didn't exist.
  mkdir -p "$HOME/.nvm"

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

  link_debian_renamed_bins
  install_neovim
  install_lazygit
  install_topgrade
  install_nvm
  install_pyenv
  install_oh_my_tmux
  install_antidote

  if want_desktop_packages; then
    install_nerd_font
  fi

  set_login_shell
}

install_nix_darwin() {
  echo "nix-darwin detected: packages are managed by your flake, so the" \
       "Brewfile is not applied automatically."
  echo "Run 'brew bundle --file=$SCRIPT_DIR/Brewfile' by hand if you also" \
       "want the Homebrew casks."
  install_oh_my_tmux
  install_antidote
  mkdir -p "$HOME/.nvm"
}

install_nix() {
  echo "Nix detected: packages come from your flake repo," \
       "not this one. Only setting up non-package config here."
  install_oh_my_tmux
  install_antidote
}

case "$(detect_os)" in
  mac)        install_mac ;;
  apt)        install_apt ;;
  nix-darwin) install_nix_darwin ;;
  nix)        install_nix ;;
  *)
    # Still do the platform-independent part rather than skipping everything.
    echo "Unrecognized OS/package manager — skipping package installation." >&2
    install_oh_my_tmux
    install_antidote
    ;;
esac

echo
echo "Done. Open a new shell (or reattach tmux) to pick everything up."
