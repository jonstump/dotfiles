#!/usr/bin/env bash
# One-time entry point for a brand new machine, meant to be run BEFORE
# chezmoi or this repo exist locally, e.g.:
#   curl -fsSL https://raw.githubusercontent.com/jonstump/dotfiles/main/bootstrap.sh | bash
#
# Makes sure git exists (Xcode Command Line Tools on macOS, the distro package
# on Linux), installs chezmoi itself, then has chezmoi clone this repo as its
# source directory and apply it on top of $HOME.
# After this finishes, open a new shell and run: $(chezmoi source-path)/install.sh
set -euo pipefail

DOTFILES_REPO="jonstump/dotfiles"
BACKUP_DIR="$HOME/.dotfiles-backup"

# A genuinely fresh machine may not have git at all: macOS ships /usr/bin/git
# as an xcrun stub that only works once the Command Line Tools are installed,
# and git isn't in the default Ubuntu Desktop / Debian netinst package set.
# Sort that out before touching anything else, so a missing git can't kill the
# script partway through. chezmoi's own git-backed clone works without a
# system git, but `chezmoi cd`/`git -C "$(chezmoi source-path)"` day-to-day
# usage (see README.md) needs a real one anyway.
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
      echo "(e.g. nix-shell -p git), then re-run this script." >&2
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

# Installs the chezmoi binary itself via its official install script, which
# auto-detects OS/arch and drops a static binary into ~/.local/bin — no brew/
# apt package needed, and it works the same on macOS and Linux (inside a
# shell that already has curl, which both have by this point).
# ~/.local/bin is already on PATH for interactive shells via .zshrc; add it
# here too so this script can call chezmoi immediately after installing it.
ensure_chezmoi() {
  export PATH="$HOME/.local/bin:$PATH"
  if command -v chezmoi >/dev/null 2>&1; then
    return
  fi
  echo "Installing chezmoi -> $HOME/.local/bin"
  sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin"
}

ensure_git
ensure_chezmoi

# chezmoi's default source directory, per its own docs — checked directly
# (rather than via `chezmoi source-path`, which errors before any init has
# happened) so re-running this script after a partial run doesn't try to
# clone on top of an already-initialized source dir.
CHEZMOI_SOURCE_DIR="${CHEZMOI_SOURCE_DIR:-$HOME/.local/share/chezmoi}"

# `chezmoi init` alone just clones the source repo; it doesn't touch $HOME
# yet, so the OS-default files it's about to replace can be moved aside
# first below, mirroring the backup-before-checkout safety the old bare-repo
# bootstrap had.
if [ ! -d "$CHEZMOI_SOURCE_DIR" ]; then
  chezmoi init "$DOTFILES_REPO"
fi

# `chezmoi apply` overwrites its managed targets unconditionally — unlike a
# bare-repo `git checkout`, it won't refuse because a plain (non-chezmoi)
# file is already there. A fresh OS install usually ships its own
# .zshrc/.zprofile/etc that would otherwise be silently clobbered, so back up
# anything chezmoi is about to manage that already exists first.
#
# `chezmoi managed` also lists the directories it manages (e.g. .config,
# .config/nvim) alongside files — skip those rather than backing them up:
# chezmoi is happy to create files inside a directory that already exists for
# unrelated reasons (other apps' configs live under ~/.config too), and
# mv-ing the whole directory aside would take those with it. Only regular
# files/symlinks are real conflicts, same as what `git checkout` used to
# refuse on.
while IFS= read -r target; do
  { [ -f "$target" ] || [ -L "$target" ]; } || continue
  rel="${target#"$HOME"/}"
  echo "Backing up pre-existing $rel -> $BACKUP_DIR/$rel"
  mkdir -p "$BACKUP_DIR/$(dirname "$rel")"
  mv "$target" "$BACKUP_DIR/$rel"
done < <(chezmoi managed --path-style=absolute)

chezmoi apply

echo
echo "Dotfiles applied to \$HOME. Open a new shell, then run:"
echo "  \$(chezmoi source-path)/install.sh"
