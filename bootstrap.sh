#!/usr/bin/env bash
# One-time entry point for a brand new machine, meant to be run BEFORE the
# dotfiles repo exists locally, e.g.:
#   curl -fsSL https://raw.githubusercontent.com/jonstump/dotfiles/main/bootstrap.sh | bash
#
# Makes sure git exists (Xcode Command Line Tools on macOS, the distro package
# on Linux), then clones the dotfiles as a bare repo and checks it out on top
# of $HOME using the same `config` alias trick .zsh_aliases defines for
# day-to-day use.
# After this finishes, open a new shell and run: $HOME/install.sh
set -euo pipefail

DOTFILES_REPO="https://github.com/jonstump/dotfiles.git"
DOTFILES_DIR="$HOME/Repos/dotfiles"
BACKUP_DIR="$HOME/.dotfiles-backup"

# A genuinely fresh machine may not have git at all: macOS ships /usr/bin/git
# as an xcrun stub that only works once the Command Line Tools are installed,
# and git isn't in the default Ubuntu Desktop / Debian netinst package set.
# Sort that out before touching anything else, so a missing git can't kill the
# script partway through.
ensure_git() {
  if [ "$(uname -s)" = "Darwin" ]; then
    if ! /usr/bin/xcode-select -p >/dev/null 2>&1; then
      echo "Installing Xcode Command Line Tools (git ships with them)."
      echo "Accept the dialog, wait for it to finish, then re-run this script."
      /usr/bin/xcode-select --install || true
      exit 1
    fi
  elif ! command -v git >/dev/null 2>&1; then
    echo "git not found — installing it first."
    if command -v apt-get >/dev/null 2>&1; then
      sudo apt-get update && sudo apt-get install -y git ca-certificates
    elif command -v dnf >/dev/null 2>&1; then
      sudo dnf install -y git
    elif command -v pacman >/dev/null 2>&1; then
      sudo pacman -Sy --noconfirm git
    elif command -v zypper >/dev/null 2>&1; then
      sudo zypper --non-interactive install git
    else
      echo "No known package manager found. Install git yourself" >&2
      echo "(on NixOS: nix-shell -p git), then re-run this script." >&2
      exit 1
    fi
  fi

  # Covers the leftovers: CLT present but git still broken, or a package
  # manager that reported success without actually producing a usable git.
  if ! command -v git >/dev/null 2>&1 || ! git --version >/dev/null 2>&1; then
    echo "git is still unavailable after the install attempt." >&2
    echo "Install a working git, then re-run this script." >&2
    exit 1
  fi
}

ensure_git

# Resolve git once, rather than hardcoding /usr/bin/git the way the `config`
# alias in .zsh_aliases does — on NixOS (and anywhere else git lives outside
# /usr/bin) that path doesn't exist.
GIT_BIN="$(command -v git)"

config() {
  "$GIT_BIN" --git-dir="$DOTFILES_DIR" --work-tree="$HOME" "$@"
}

mkdir -p "$HOME/Repos"

if [ ! -d "$DOTFILES_DIR" ]; then
  echo "Cloning $DOTFILES_REPO -> $DOTFILES_DIR"
  "$GIT_BIN" clone --bare "$DOTFILES_REPO" "$DOTFILES_DIR"
fi

config config --local status.showUntrackedFiles no

# `git clone --bare` deliberately omits remote.origin.fetch, which leaves the
# repo with no remote-tracking branches: `config fetch` only writes FETCH_HEAD
# and `config pull` can't fast-forward normally. Add the refspec back so the
# day-to-day `config fetch`/`pull`/`push` documented in README.md behaves like
# an ordinary clone.
if [ -z "$(config config --get-all remote.origin.fetch || true)" ]; then
  config config remote.origin.fetch '+refs/heads/*:refs/remotes/origin/*'
  config fetch origin
  config branch --set-upstream-to=origin/main main 2>/dev/null || true
fi

# A fresh OS install usually ships its own .zshrc/.zprofile/etc that would
# collide with the checkout below. Move anything in the way aside instead of
# letting `git checkout` refuse to run.
#
# Git lists the offending paths one per line, tab-indented. Strip only that
# leading tab: splitting on whitespace (the old `awk '{print $1}'`) truncated
# any path containing a space, so the backup `mv` failed, the retry checkout
# aborted, and `set -e` killed the script with no message at all — bootstrap
# appeared to finish with nothing checked out. LC_ALL=C keeps the surrounding
# English strings stable if a translated git is ever in play.
conflicts="$(LC_ALL=C config checkout 2>&1 | sed -n 's/^\t//p' || true)"
if [ -n "$conflicts" ]; then
  echo "Backing up pre-existing files that would conflict, into $BACKUP_DIR"
  while IFS= read -r file; do
    [ -z "$file" ] && continue
    mkdir -p "$BACKUP_DIR/$(dirname "$file")"
    mv "$HOME/$file" "$BACKUP_DIR/$file"
  done <<< "$conflicts"
fi

config checkout || {
  echo "checkout is still blocked — see the git output above." >&2
  echo "Move the listed files aside by hand, then re-run this script." >&2
  exit 1
}

echo
echo "Dotfiles checked out to \$HOME. Open a new shell, then run:"
echo "  \$HOME/install.sh"
