#!/usr/bin/env bash
# Installs tooling for whichever OS this is running on. Assumes the dotfiles
# have already been applied by chezmoi (run bootstrap.sh first if not).
#
# Mac: Homebrew + Brewfile.
# Debian/Ubuntu-family Linux (apt): native apt packages from apt-packages.txt,
#   plus upstream installers for the handful of tools apt doesn't reliably
#   package (pyenv, nvm — always upstream, since the dotfiles that load them
#   only look in fixed non-apt locations — and lazygit/topgrade, which check
#   apt first and only fall back to upstream if this distro/release doesn't
#   package them). oh-my-tmux and antidote are chezmoi git-repo externals now
#   (home/.chezmoiexternal.toml), applied by `chezmoi apply` before this runs;
#   install.sh only self-heals the tpm plugin checkout they previously owned.
set -euo pipefail

# Everything here is resolved relative to the script itself. This file lives
# outside chezmoi's source root (see .chezmoiroot), next to the Brewfile and
# package manifests, at the repo root — one level above `chezmoi source-path`,
# which .chezmoiroot points at the home/ subdirectory.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

detect_os() {
  if [ "$(uname -s)" = "Darwin" ]; then
    echo "mac"
    return
  fi

  # Atomic/immutable Fedora derivatives (Bazzite, and sibling uBlue images:
  # Bluefin, Aurora, etc.) plus plain Silverblue/Kinoite share one trait that
  # actually matters here: /run/ostree-booted exists and the root fs is
  # read-only, so `dnf install` would fail against it and system-level tools
  # must go through Homebrew (which the image provisions at first boot)
  # instead. On Bazzite `ID=bazzite`; on the siblings it's
  # `ID=fedora`+`VARIANT_ID=silverblue|kinoite` or another uBlue ID — so gate
  # on the standard rpm-ostree marker rather than a hardcoded ID string (it
  # also covers future images). Check before the generic package-manager
  # branches below.
  #
  # The path/marker are overridable via env for tests (a real CI box may not
  # be able to create /run/ostree-booted); they default to the real paths.
  if [ -f "${OS_RELEASE:-/etc/os-release}" ]; then
    # shellcheck disable=SC1091
    # shellcheck source=/etc/os-release
    . "${OS_RELEASE:-/etc/os-release}"
    if [ "${ID:-}" = "bazzite" ] || \
       { [ "${ID:-}" = "fedora" ] && { [ "${VARIANT_ID:-}" = "silverblue" ] || [ "${VARIANT_ID:-}" = "kinoite" ]; }; }; then
      echo "bazzite"
      return
    fi
  fi
  if [ -e "${OSTREE_MARKER:-/run/ostree-booted}" ]; then
    echo "bazzite"
    return
  fi

  if command -v apt-get >/dev/null 2>&1; then
    echo "apt"
  elif command -v pacman >/dev/null 2>&1; then
    echo "pacman"
  elif command -v dnf >/dev/null 2>&1; then
    echo "dnf"
  elif command -v zypper >/dev/null 2>&1; then
    echo "zypper"
  else
    echo "unknown"
  fi
}

# The global package manager in use on this run ("apt" | "pacman" | "dnf").
# Set by install_linux() before any per-tool install runs. The tool installs
# below (lazygit/topgrade/zsh/signal) consult it to decide whether to use the
# distro package or fall back to an upstream installer.
PM=""

# Refreshes the package index. Each manager needs a different invocation (apt
# must run before installing; pacman must sync with -u to avoid Arch's
# unsupported partial-upgrade state, a bare -Sy is documented as unsafe; dnf
# uses -y).
pm_update() {
  case "$PM" in
    apt)    apt_update ;;
    pacman) if ! sudo pacman -Syu --noconfirm; then
              # A mirror timeout/DNS blip fails mid-sync. Front load the
              # clear message instead of letting set -e leave the user with
              # an opaque exit code. Failed -Syu can leave a partial upgrade
              # state, and installing with a partial system is dangerous, so
              # this aborts rather than warn-and-continue.
              echo "ERROR: pacman -Syu failed; re-run install.sh once your mirrors" >&2
              echo "are reachable again (partial-upgrade states are unsafe to install onto)." >&2
              exit 1
            fi
            ;;
    dnf)    # exit 100 = "updates available" (expected, non-error); anything
            # else is a real failure worth surfacing early instead of letting
            # it explode later inside pm_install with no context.
            sudo dnf check-update >/dev/null 2>&1 || {
              local rc=$?
              [ "$rc" -eq 100 ] || echo "WARNING: dnf check-update failed (exit $rc); continuing." >&2
            }
            ;;
    zypper) if ! sudo zypper --non-interactive refresh; then
              echo "WARNING: zypper refresh failed; continuing with whatever" >&2
              echo "index it already had cached." >&2
            fi
            ;;
  esac
}

# Installs $@ as packages, best-effort: failures warn and continue rather than
# aborting the whole installer (set -e is on). Returns the success/failure of
# the batch so callers that need it can react.
pm_install() {
  case "$PM" in
    apt)
      if ! apt_retry install -y "$@"; then
        echo "WARNING: apt install failed for: $*" >&2
        return 1
      fi
      ;;
    pacman)
      if ! sudo pacman -S --noconfirm --needed "$@"; then
        echo "WARNING: pacman install failed for: $*" >&2
        return 1
      fi
      ;;
    dnf)
      if ! sudo dnf install -y "$@"; then
        echo "WARNING: dnf install failed for: $*" >&2
        return 1
      fi
      ;;
    zypper)
      if ! sudo zypper --non-interactive install --no-recommends "$@"; then
        echo "WARNING: zypper install failed for: $*" >&2
        return 1
      fi
      ;;
  esac
}

# True if the current package manager has an installable candidate for $1 on
# this machine. Package sets vary by distro and drift over time even on one
# distro (e.g. lazygit landed in Debian testing after this script first
# needed the upstream fallback below), and this repo's package path isn't
# limited to one distro's archive — so check at run time instead of hardcoding
# "not packaged" and letting that guess go stale or wrong. Also safe to call
# from the mac path, where no distro package manager exists at all.
# Renames $1 aside with a timestamp suffix instead of deleting it — mirrors
# upstream oh-my-tmux's own install.sh, which never destroys existing state,
# only backs it up before replacing it.
backup_aside() {
  local path="$1" backup
  [ -e "$path" ] || [ -L "$path" ] || return 0
  backup="$path.bak.$(date +%Y%m%d%H%M%S)"
  echo "Backing up $path -> $backup"
  mv "$path" "$backup"
}

# tpm and the plugins it manages (vim-tmux-navigator, tmux-powerkit — see
# tmux.conf.local) live under ~/.config/tmux/plugins: oh-my-tmux resolves
# TMUX_PLUGIN_MANAGER_PATH next to tmux.conf, and this repo's tmux.conf
# lives under ~/.config/tmux rather than directly in $HOME. oh-my-tmux's own
# bootstrap only *creates* tpm if that directory is entirely absent — it
# never repairs one that exists but is broken, so a corrupted checkout means
# plugins silently stop installing/updating with no error shown anywhere.
# (oh-my-tmux itself is now a chezmoi git-repo external — see
# home/.chezmoiexternal.toml — but tpm is a separate checkout under
# ~/.config/tmux/plugins, so its self-heal stays here.)
repair_tmux_plugins() {
  local plugins_dir="$HOME/.config/tmux/plugins"
  if [ -d "$plugins_dir/tpm" ] && [ ! -x "$plugins_dir/tpm/tpm" ]; then
    echo "tpm checkout at $plugins_dir/tpm looks broken; resetting plugins."
    backup_aside "$plugins_dir"
  fi
}

# True if the current package manager has an installable candidate for $1.
# Package sets vary by distro and drift over time even on one distro (e.g.
# lazygit landed in Debian testing after this script first needed the upstream
# fallback below), and this repo's package path isn't limited to one distro's
# archive — so check at run time instead of hardcoding "not packaged" and
# letting that guess go stale or wrong. Also safe to call from the mac path,
# where no distro package manager exists at all.
pm_has_candidate() {
  case "$PM" in
    apt)
      command -v apt-cache >/dev/null 2>&1 || return 1
      local candidate
      candidate="$(apt-cache policy "$1" 2>/dev/null | awk -F': ' '/Candidate:/{print $2; exit}')"
      [ -n "$candidate" ] && [ "$candidate" != "(none)" ]
      ;;
    pacman)
      pacman -Si "$1" >/dev/null 2>&1
      ;;
    dnf)
      dnf list --available "$1" >/dev/null 2>&1
      ;;
    zypper)
      # Search both installed and available (like the apt/pacman/dnf
      # branches); --installed-only would always miss the not-yet-installed
      # tools every caller of pm_has_candidate is checking for.
      zypper --non-interactive search --match-exact "$1" >/dev/null 2>&1
      ;;
    *)
      return 1
      ;;
  esac
}

# Not pm_has_candidate-checked: .zshrc only sources nvm from $HOME/.nvm/nvm.sh
# (or the Homebrew formula's path on Mac), never from `command -v nvm`, so an
# apt package wouldn't land where .zshrc looks and would silently go unused.
install_nvm() {
  if [ ! -d "$HOME/.nvm" ]; then
    echo "Installing nvm"
    if ! curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash; then
      echo "WARNING: nvm install failed; continuing with the rest of the setup." >&2
    fi
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
  # Accept the API response on stdin (test seam / pipes) or fetch it.
  local body
  if [ ! -t 0 ]; then
    body="$(cat)"
  else
    body="$(curl -fsSL "https://api.github.com/repos/$1/releases/latest")"
  fi
  printf '%s\n' "$body" \
    | sed -n 's/.*"tag_name": *"v\{0,1\}\([^"]*\)".*/\1/p' | head -1
}

# LazyVim's health check looks for lazygit. Not in the Debian/Ubuntu archive
# as of writing, but pm_has_candidate re-checks in case that has changed.
install_lazygit() {
  command -v lazygit >/dev/null 2>&1 && return

  if pm_has_candidate lazygit; then
    echo "Installing lazygit (package)"
    pm_install lazygit || \
      echo "WARNING: lazygit (package) install failed; continuing with the rest of the setup." >&2
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

# lf ships in the Debian/Ubuntu and Arch archives, but is NOT in Fedora's
# official repos (only a third-party COPR), and package sets vary/drift even
# on apt (PikaOS tracks Debian testing/sid where lf can lag or vanish). Try
# the distro package first at run time (like lazygit/topgrade/zsh), and fall
# back to the upstream release tarball, which extracts to a single static
# binary named `lf`, whenever the package manager has no candidate.
install_lf() {
  command -v lf >/dev/null 2>&1 && return

  if [ -n "$PM" ] && pm_has_candidate lf; then
    echo "Installing lf (package)"
    pm_install lf || \
      echo "WARNING: lf (package) install failed; continuing with the rest of the setup." >&2
    return
  fi

  # No distro candidate (Fedora/dnf, or apt/pacman on a release missing it).
  local machine target
  machine="$(uname -m)"
  case "$machine" in
    x86_64|amd64)  target="amd64" ;;
    aarch64|arm64) target="arm64" ;;
    *)
      echo "No upstream lf build for $machine — skipping." >&2
      return
      ;;
  esac

  echo "Installing lf ($target, upstream release)"
  local tmp
  tmp="$(mktemp -d)"
  if curl -fsSL "https://github.com/gokcehan/lf/releases/latest/download/lf-linux-${target}.tar.gz" \
       | tar -xz -C "$tmp" lf; then
    mkdir -p "$HOME/.local/bin"
    install -m 0755 "$tmp/lf" "$HOME/.local/bin/lf"
  else
    echo "WARNING: lf download failed; skipping." >&2
  fi
  rm -rf "$tmp"
}

# Not pm_has_candidate-checked: .zprofile hardcodes PYENV_ROOT to
# $HOME/.pyenv and only puts $PYENV_ROOT/bin on PATH, so an apt-installed
# pyenv landing in a system location wouldn't be found there and pyenv init
# would silently stay dead.
install_pyenv() {
  if [ ! -d "$HOME/.pyenv" ]; then
    echo "Installing pyenv"
    if ! curl -fsSL https://pyenv.run | bash; then
      echo "WARNING: pyenv install failed; continuing with the rest of the setup." >&2
    fi
  fi
}

# README.md points at topgrade for updates and the manifests claim install.sh
# installs it — but it isn't packaged everywhere (as of writing, not reliably
# for Debian/Ubuntu; macOS was always fine, it's in the Brewfile), so check the
# package manager first and fall back to pipx. topgrade-rs publishes to PyPI,
# and pipx is bootstrapped on each PM path (in the manifests / bootstrap
# step), so that's simpler than fetching and unpacking the release tarball
# per-arch.
install_topgrade() {
  command -v topgrade >/dev/null 2>&1 && return

  if pm_has_candidate topgrade; then
    echo "Installing topgrade (package)"
    pm_install topgrade || \
      echo "WARNING: topgrade (package) install failed; continuing with the rest of the setup." >&2
    return
  fi

  echo "Installing topgrade (pipx)"
  if command -v pipx >/dev/null 2>&1; then
    pipx install topgrade
  else
    echo "WARNING: pipx not available; skipping topgrade." >&2
  fi
}

# zsh is normally in every Debian/Ubuntu archive, but a derivative distro's
# sources.list can omit the component that carries it (or only ship its own
# overlay repo) — pm_has_candidate re-checks so this only builds from source
# when the package manager genuinely has no candidate, not just a stale index.
# The upstream release tarball (unlike a raw git checkout) ships a
# pre-generated ./configure, so this only needs a C compiler and ncurses
# headers — build-essential and libncursesw5-dev from apt-packages.txt.
install_zsh() {
  command -v zsh >/dev/null 2>&1 && return

  if pm_has_candidate zsh; then
    echo "Installing zsh (package)"
    pm_install zsh || \
      echo "WARNING: zsh (package) install failed; continuing with the rest of the setup." >&2
    return
  fi

  echo "zsh not found via the package manager — building from source (upstream release tarball)."
  local tmp
  tmp="$(mktemp -d)"
  if curl -fsSL -o "$tmp/zsh-src.tar" "https://sourceforge.net/projects/zsh/files/latest/download" \
       && tar -xf "$tmp/zsh-src.tar" -C "$tmp" --strip-components=1; then
    if (
         cd "$tmp" &&
         ./configure --prefix=/usr/local &&
         make -j"$(nproc)" &&
         sudo make install
       ); then
      if ! grep -qxF /usr/local/bin/zsh /etc/shells 2>/dev/null; then
        echo /usr/local/bin/zsh | sudo tee -a /etc/shells >/dev/null
      fi
    else
      echo "WARNING: zsh build failed; skipping." >&2
    fi
  else
    echo "WARNING: zsh source download failed; skipping." >&2
  fi
  rm -rf "$tmp"
}

install_mac() {
  if ! command -v brew >/dev/null 2>&1; then
    echo "Installing Homebrew"
    # Fetch the installer script as `script` first: `set -e` cannot catch a
    # failing curl inside a command substitution (its status is discarded),
    # so a dead network would have run `/bin/bash -c ""` and "succeeded"
    # (issue #99).
    local brew_install
    if ! brew_install="$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; then
      echo "ERROR: failed to download the Homebrew installer." >&2
      echo "Check your network and re-run this script." >&2
      exit 1
    fi
    NONINTERACTIVE=1 /bin/bash -c "$brew_install"
  fi
  for brew_bin in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    [ -x "$brew_bin" ] && eval "$("$brew_bin" shellenv)" && break
  done

  # Config setup first: it's cheap and reliable, and must not be skipped just
  # because a package install failed. oh-my-tmux and antidote themselves are
  # chezmoi git-repo externals (home/.chezmoiexternal.toml) applied before
  # this script runs, but the tpm plugin checkout still needs its self-heal.
  repair_tmux_plugins

  # The Homebrew nvm formula's caveats say to create this yourself, and nothing
  # here did — so .zshrc's `[ -s "$NVM_DIR/nvm.sh" ]` failed, it fell through
  # to the Homebrew copy, and nvm loaded with NVM_DIR pointing at a directory
  # that didn't exist.
  mkdir -p "$HOME/.nvm"

  # brew bundle install defaults to upgrading every already-installed
  # dependency too, and `brew` auto-runs `brew update` (a full core/cask tap
  # fetch) before that — on a machine that's already set up, that's minutes
  # of upgrade churn for packages that don't need to change, with progress
  # output that doesn't render cleanly in every terminal. Skip both: only
  # install what's actually missing, and leave upgrades to `topgrade` (see
  # README) run by hand.
  export HOMEBREW_NO_AUTO_UPDATE=1

  local brewfile="$SCRIPT_DIR/Brewfile"
  if brew bundle check --no-upgrade --file="$brewfile" >/dev/null 2>&1; then
    echo "Brewfile dependencies already installed; nothing to do."
  else
    echo "Missing Brewfile dependencies:"
    brew bundle check --no-upgrade --verbose --file="$brewfile" || true

    # Package installation is the least reliable step here — a single broken
    # or disabled formula aborts the whole bundle. Don't let that take the
    # rest of the install down with it. --no-lock: brew otherwise writes
    # Brewfile.lock.json next to the Brewfile (i.e. into this repo), leaving
    # untracked noise in the checkout (issue #107).
    if ! brew bundle install --no-upgrade --no-lock --file="$brewfile"; then
      echo "WARNING: some Brewfile entries failed to install; continuing." >&2
    fi
  fi
}

# Bazzite (uBlue / Fedora Silverblue-derived atomic distro). The root fs is
# read-only (rpm-ostree image layering requires a reboot and is discouraged
# for frequently-changed tools), so the repo's CLI toolset goes through
# Homebrew instead: the Bazzite image provisions Linuxbrew at first boot
# (/home/linuxbrew/.linuxbrew) and auto-updates it with its own systemd
# timers, so the shared Brewfile covers everything with no layering. This is
# also why there's no dnf manifest for Bazzite.
install_bazzite() {
  # Bazzite's first-boot brew provisioning (brew-setup.service) is known to
  # occasionally not complete; fall back to the standard install if brew
  # isn't usable yet.
  if ! command -v brew >/dev/null 2>&1; then
    if [ -x /home/linuxbrew/.linuxbrew/bin/brew ]; then
      eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    fi
  fi
  if ! command -v brew >/dev/null 2>&1; then
    echo "Homebrew not found; installing it (Bazzite's first-boot provisioning"
    echo "may not have completed)."
    # Fetch the installer script as `script` first: checking the download
    # lets a failed curl (proxy/DNS/github outage) abort with a clear error
    # instead of `/bin/bash -c ""` silently "succeeding" (issue #99).
    local brew_install
    if ! brew_install="$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; then
      echo "ERROR: failed to download the Homebrew installer." >&2
      echo "Check your network and re-run this script." >&2
      exit 1
    fi
    NONINTERACTIVE=1 /bin/bash -c "$brew_install"

    # install_bazzite differs from install_mac here: brew wasn't on PATH at
    # the top of this function, so a fresh install means the shellenv eval
    # below never ran yet. Without this, every later `brew bundle`
    # invocation fails with "command not found" (issue #94).
    if [ -x /home/linuxbrew/.linuxbrew/bin/brew ]; then
      eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    else
      echo "ERROR: Homebrew installed but /home/linuxbrew/.linuxbrew/bin/brew" >&2
      echo "is missing; cannot continue with the Brewfile." >&2
      exit 1
    fi
  fi

  # Config first (same reasoning as install_mac — a fresh shell must not come
  # up in an unconfigured tmux). oh-my-tmux/antidote are externals; keep only
  # the tpm self-heal here.
  repair_tmux_plugins
  mkdir -p "$HOME/.nvm"

  # The shared Brewfile: cask/mas entries are macOS-only and brew bundle
  # ignores them on Linux. Formula lines (bat, fd, fzf, delta, ripgrep,
  # lazygit, topgrade, neovim, zsh, lf, node, python, etc.) install the whole
  # toolset. Bazzite manages its own brew updates via systemd timers, so
  # HOMEBREW_NO_AUTO_UPDATE keeps this run from fighting them.
  export HOMEBREW_NO_AUTO_UPDATE=1
  local brewfile="$SCRIPT_DIR/Brewfile"
  if brew bundle check --no-upgrade --file="$brewfile" >/dev/null 2>&1; then
    echo "Brewfile dependencies already installed; nothing to do."
  else
    echo "Missing Brewfile dependencies:"
    brew bundle check --no-upgrade --verbose --file="$brewfile" || true
    if ! brew bundle install --no-upgrade --no-lock --file="$brewfile"; then
      echo "WARNING: some Brewfile entries failed to install; continuing." >&2
    fi
  fi

  # nvm and pyenv come from the Brewfile on Bazzite. The Homebrew nvm formula
  # needs NVM_DIR to exist (same caveat as install_mac), and .zprofile expects
  # PYENV_ROOT.
  mkdir -p "$HOME/.nvm" "$HOME/.pyenv"

  if want_desktop_packages; then
    install_nerd_font
  fi

  # Deliberately NO set_login_shell: Bazzite's docs recommend against a
  # system-wide chsh (known to break KDE session login and Flatpak apps that
  # spawn a login shell). Set zsh in the terminal emulator profile instead.
  if command -v zsh >/dev/null 2>&1; then
    echo "Bazzite: skipping chsh — set your shell to zsh in the terminal"
    echo "emulator's profile instead (Bazzite recommends against system chsh)."
  else
    echo "WARNING: zsh is still not installed after the Brewfile pass." >&2
    echo "The zsh-based dotfiles stack (.zshrc, antidote, p10k, tmux auto-attach)" >&2
    echo "will not load. The Brewfile has a zsh entry; a failed/aborted brew" >&2
    echo "bundle is the likely cause — re-run install.sh or 'brew install zsh'." >&2
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
    # mv preserves the source SELinux context (extracted under mktemp's
    # tmp_t), which on Fedora's enforcing policy stops nvim from running
    # despite being executable. restorecon relabels to the /opt policy.
    command -v restorecon >/dev/null 2>&1 && sudo restorecon -R "/opt/$target" /usr/local/bin/nvim
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
    rm -f "$tmp"
    return 1
  fi
  rm -f "$tmp"
}

# True if $1 (a Flatpak application ID) is installed.
flatpak_installed() {
  command -v flatpak >/dev/null 2>&1 || return 1
  flatpak list --app --columns=application 2>/dev/null | grep -qix "$1"
}

# Looks up $1 (an apt package name) in apt-flatpak-overrides.txt and prints
# the Flatpak application ID it's mapped to. Empty output and non-zero exit
# if that package has no override entry.
flatpak_override_for() {
  local file="$SCRIPT_DIR/apt-flatpak-overrides.txt"
  [ -f "$file" ] || return 1
  awk -v pkg="$1" '
    { sub(/#.*/, ""); gsub(/^[[:space:]]+|[[:space:]]+$/, "") }
    NF == 2 && $1 == pkg { print $2; found = 1; exit }
    END { exit !found }
  ' "$file"
}

# Signal needs its own apt repo before it can be installed at all (Debian
# family), so it can't go through install_manifest's generic Flatpak-override
# check like an ordinary package — it has to decide whether it's needed before
# deciding whether to add that repo. amd64-only upstream: Signal only ships an
# amd64 apt build, so on arm64 boxen (Pi/Ampere/Asahi/UTM) don't even try.
# On pacman/dnf/zypper Signal is not in the official repos (AUR / Copr /
# third-party repo respectively), so it's skipped with a warning rather than
# installed.
install_signal() {
  # Flatpak-override check is apt-only, matching install_manifest.
  if [ "$PM" = "apt" ]; then
    [ "$(dpkg --print-architecture)" = "amd64" ] || return 0
    dpkg -s signal-desktop >/dev/null 2>&1 && return 0

    local flatpak_id
    if flatpak_id="$(flatpak_override_for signal-desktop)" && flatpak_installed "$flatpak_id"; then
      echo "Skipping signal-desktop — already installed via Flatpak ($flatpak_id)."
      return 0
    fi

    if add_apt_repo signal-desktop \
      "https://updates.signal.org/desktop/apt/keys.asc" \
      "deb [arch=amd64 signed-by=/etc/apt/keyrings/signal-desktop.gpg] https://updates.signal.org/desktop/apt xenial main"; then
      apt_update
      apt_retry install -y signal-desktop || \
        echo "WARNING: signal-desktop install failed; continuing with the rest of the setup." >&2
    else
      echo "WARNING: skipping signal-desktop (no apt repo added)." >&2
    fi
    return
  fi

  # pacman/dnf/zypper: package-manager install, with the package name in the
  # distro-specific desktop manifest (pacman-packages-desktop.txt /
  # dnf-packages-desktop.txt), so just delegate.
  if pm_has_candidate signal-desktop; then
    pm_install signal-desktop || \
      echo "WARNING: signal-desktop install failed; continuing with the rest of the setup." >&2
  else
    echo "signal-desktop not packaged on this distro; skipping." >&2
  fi
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

# Retries an apt-get subcommand a few times. On a fresh Debian-family install
# (PikaOS especially) the OS's own background update timers or a GUI
# app-center can hold /var/lib/dpkg/lock-frontend right when this runs; a
# short backoff clears most such cases instead of failing (or silently
# continuing past a real failure) on the first attempt. Only for the "install"
# family do we treat a finally-failed attempt as an error — "update" is
# inherently best-effort (see apt_update below).
apt_retry() {
  local i
  for i in 1 2 3 4; do
    if sudo apt-get "$@"; then
      return 0
    fi
    local rc=$?
    # A busy lock is worth waiting out; a package/network error won't resolve
    # by re-running, so don't spin on it. fuser must run as root: on a fresh
    # install the lock holder is a root-owned background updater (PikaOS's
    # update timer, PackageKit/GUI app-center), and an unprivileged fuser
    # can't see another user's open file descriptors — it would report
    # "nothing holds the lock" and skip the retry entirely. fuser accepts
    # multiple names and exits 0 if any is held — one call covers all four
    # apt/dpkg lock files.
    if ! sudo fuser /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock \
         /var/lib/apt/lists/lock /var/cache/apt/archives/lock >/dev/null 2>&1; then
      return "$rc"
    fi
    if [ $i -lt 4 ]; then
      echo "WARNING: apt-get $*: dpkg/apt lock busy (attempt $i/4); retrying in $((i * 3))s." >&2
      sleep "$((i * 3))"
    fi
  done
  return 1
}

# A single third-party repo with stale/desyncing mirrors (seen in practice:
# PikaOS's own PPA returning a Release file whose recorded hash for its dep11
# AppStream Components file doesn't match what's currently being served) makes
# `apt-get update` exit non-zero even though the actual package indices came
# through fine and apt itself calls the failure non-fatal ("ignored, or old
# ones used instead"). Don't let `set -e` turn that into a hard stop for the
# whole installer.
apt_update() {
  if ! apt_retry update; then
    echo "WARNING: apt-get update reported errors (see above); continuing with" >&2
    echo "whatever indices it did fetch or already had cached." >&2
  fi
}

# Package manifests are all-or-nothing: one unresolvable name means nothing
# gets installed, and `set -e` would then kill the rest of the installer. The
# manifests are explicitly best-effort (names vary by distro/release), so try
# the fast batch path first and fall back to per-package on failure. The
# Flatpak-override check is apt-only (Fedora/Arch users manage Flatpaks
# themselves and those manifests don't map to a shared file).
install_manifest() {
  local file="$1"
  [ -f "$file" ] || return 0

  read_manifest "$file"
  [ "${#PKGS[@]}" -gt 0 ] || return 0

  local pkg flatpak_id filtered=()
  if [ "$PM" = "apt" ]; then
    for pkg in "${PKGS[@]}"; do
      if flatpak_id="$(flatpak_override_for "$pkg")" && flatpak_installed "$flatpak_id"; then
        echo "Skipping $pkg — already installed via Flatpak ($flatpak_id)."
        continue
      fi
      filtered+=("$pkg")
    done
    PKGS=("${filtered[@]}")
    [ "${#PKGS[@]}" -gt 0 ] || return 0
  fi

  if ! pm_install "${PKGS[@]}"; then
    echo "Batch install of $(basename "$file") failed; retrying package-by-package." >&2
    for pkg in "${PKGS[@]}"; do
      pm_install "$pkg" || echo "SKIP (unavailable): $pkg" >&2
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
# `sudo ./install.sh`, and a zsh that isn't listed in /etc/shells makes chsh
# exit non-zero and, as the last command under `set -e`, abort the whole
# installer — as well as being removable, which can lock you out.
set_login_shell() {
  local target_user zsh_path current
  target_user="$(id -un)"
  zsh_path="$(command -v zsh || true)"

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

install_linux() {
  if ! command -v sudo >/dev/null 2>&1; then
    echo "sudo is required for the package install path. Install it (or run as" >&2
    echo "a user in the sudo group) and re-run this script." >&2
    exit 1
  fi
  export DEBIAN_FRONTEND=noninteractive

  # The manifests live next to install.sh, one per package manager, named
  # <pm>-packages.txt and <pm>-packages-desktop.txt.
  local packages_file="$SCRIPT_DIR/${PM}-packages.txt"
  local desktop_file="$SCRIPT_DIR/${PM}-packages-desktop.txt"

  # add_apt_repo needs curl and gpg, and neither is guaranteed on a minimal
  # Debian image — bootstrap them before adding any repo. Similarly, several
  # installs below need curl/tar/unzip; make sure curl and the basics exist
  # on every Linux PM path.
  pm_update
  if [ "$PM" = "apt" ]; then
    apt_retry install -y curl gnupg ca-certificates tar unzip || \
      echo "WARNING: curl/gnupg/ca-certificates install failed; add_apt_repo calls" \
        "below may fail as a result. Continuing with the rest of the setup." >&2
  else
    # curl/tar are bootstrap-needed for the upstream installers below too.
    # pacman/dnf pull these in as deps of other things typically, but be
    # explicit. (unzip for Nerd Font, tar for tarball extraction.)
    pm_install curl tar unzip || \
      echo "WARNING: curl/tar/unzip install failed; some installs may fail." >&2
    if [ "$PM" = "dnf" ]; then
      # Fedora core ships python3 but not pip; pipx is the topgrade fallback.
      pm_install python3 python3-pip pipx || true
    elif [ "$PM" = "pacman" ]; then
      # Arch ships python, but pipx is a separate package (topgrade fallback).
      pm_install python-pipx || true
    elif [ "$PM" = "zypper" ]; then
      # openSUSE's pipx package is python3-pipx (a meta resolving to the
      # default-Python versioned package, e.g. python313-pipx on Tumbleweed).
      pm_install python3 python3-pip python3-pipx || true
    fi
  fi

  install_manifest "$packages_file"

  # pkgfile (Arch) powers the oh-my-zsh command-not-found hook, but pacman
  # doesn't populate its file-list database at install time — build it now
  # and (optionally) make the systemd timer keep it current, so the hook
  # works from the very first shell instead of failing until someone runs
  # `pkgfile --update` by hand.
  if [ "$PM" = "pacman" ] && command -v pkgfile >/dev/null 2>&1; then
    sudo pkgfile --update || \
      echo "WARNING: pkgfile --update failed; the zsh command-not-found hook will" >&2
      echo "stay broken until it succeeds (e.g. after a network retry)." >&2
    # shellcheck disable=SC2015  # best-effort timer enable; || true is the
    # intended no-error outcome even when the enable fails.
    command -v systemctl >/dev/null 2>&1 && sudo systemctl enable --now pkgfile-update.timer 2>/dev/null || true
  fi

  if want_desktop_packages; then
    install_manifest "$desktop_file"
    install_signal
  else
    echo "No display environment detected — skipping ${PM}-packages-desktop.txt."
    echo "(Set DOTFILES_DESKTOP=1 to install them anyway.)"
  fi

  if [ "$PM" = "apt" ]; then
    link_debian_renamed_bins
  fi
  install_neovim
  install_lazygit
  install_topgrade
  install_zsh
  install_nvm
  install_pyenv
  repair_tmux_plugins
  install_lf

  if want_desktop_packages; then
    install_nerd_font
  fi

  set_login_shell
}

main() {
  PM="$(detect_os)"
  case "$PM" in
    mac)        install_mac ;;
    bazzite)    install_bazzite ;;
    apt|pacman|dnf|zypper) install_linux ;;
    *)
      # Still do the platform-independent part rather than skipping everything.
      # (oh-my-tmux/antidote are chezmoi externals, run at apply — not here.)
      echo "Unrecognized OS/package manager — skipping package installation." >&2
      repair_tmux_plugins
      ;;
  esac

  echo
  echo "Done. Open a new shell (or reattach tmux) to pick everything up."
}

# Only run the installer when executed directly. Sourcing the file (as the
# bats test-suite does, and as any future lib consumer might) defines the
# functions and globals but must not start installing packages.
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  main "$@"
fi
