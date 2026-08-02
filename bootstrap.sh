#!/usr/bin/env bash
# One-time entry point for a brand new machine, meant to be run BEFORE the
# dotfiles repo exists locally, e.g.:
#   curl -fsSL https://raw.githubusercontent.com/jonstump/dotfiles/main/bootstrap.sh | bash
#
# Installs chezmoi (if it isn't already there), clones this repo into chezmoi's
# source directory, backs up any pre-existing files chezmoi is about to manage,
# then applies. The apply also runs the package/tooling scripts in
# .chezmoiscripts/, so it may prompt for sudo on Linux.
#
# Everything here is idempotent; re-running it is a no-op plus a fresh apply.
set -euo pipefail

GITHUB_USER="jonstump"
BIN_DIR="$HOME/.local/bin"
BACKUP_DIR="$HOME/.dotfiles-backup"

install_chezmoi() {
  if command -v chezmoi >/dev/null 2>&1; then
    command -v chezmoi
    return
  fi

  if [ "$(uname -s)" = "Darwin" ] && command -v brew >/dev/null 2>&1; then
    brew install chezmoi >&2
    command -v chezmoi
    return
  fi

  echo "Installing chezmoi -> $BIN_DIR" >&2
  mkdir -p "$BIN_DIR"
  sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$BIN_DIR" >&2
  echo "$BIN_DIR/chezmoi"
}

chezmoi_bin="$(install_chezmoi)"

# `init` without --apply only clones the repo into the source directory and
# writes chezmoi's config; nothing in $HOME is touched yet.
"$chezmoi_bin" init "$GITHUB_USER"

# A fresh OS install usually ships its own .zshrc/.zprofile/etc. chezmoi would
# happily overwrite them, so move anything it's about to manage aside first.
while IFS= read -r target; do
  [ -z "$target" ] && continue
  [ -e "$target" ] || continue
  rel="${target#"$HOME"/}"
  echo "Backing up existing $rel -> $BACKUP_DIR/$rel"
  mkdir -p "$BACKUP_DIR/$(dirname "$rel")"
  mv "$target" "$BACKUP_DIR/$rel"
done < <("$chezmoi_bin" managed --include=files,symlinks --path-style=absolute)

"$chezmoi_bin" apply

echo
echo "Done. Open a new shell (or reattach tmux) to pick everything up."
