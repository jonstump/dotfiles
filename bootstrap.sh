#!/usr/bin/env bash
# One-time entry point for a brand new machine, meant to be run BEFORE the
# dotfiles repo exists locally, e.g.:
#   curl -fsSL https://raw.githubusercontent.com/jonstump/dotfiles/main/bootstrap.sh | bash
#
# Clones the dotfiles as a bare repo and checks it out on top of $HOME using
# the same `config` alias trick .zsh_aliases defines for day-to-day use.
# After this finishes, open a new shell and run: $HOME/install.sh
set -euo pipefail

DOTFILES_REPO="https://github.com/jonstump/dotfiles.git"
DOTFILES_DIR="$HOME/Repos/dotfiles"
BACKUP_DIR="$HOME/.dotfiles-backup"

config() {
  /usr/bin/git --git-dir="$DOTFILES_DIR" --work-tree="$HOME" "$@"
}

mkdir -p "$HOME/Repos"

if [ ! -d "$DOTFILES_DIR" ]; then
  echo "Cloning $DOTFILES_REPO -> $DOTFILES_DIR"
  git clone --bare "$DOTFILES_REPO" "$DOTFILES_DIR"
fi

config config --local status.showUntrackedFiles no

# A fresh OS install usually ships its own .zshrc/.zprofile/etc that would
# collide with the checkout below. Move anything in the way aside instead of
# letting `git checkout` refuse to run.
conflicts="$(config checkout 2>&1 | grep -E '^\s' | awk '{print $1}' || true)"
if [ -n "$conflicts" ]; then
  echo "Backing up pre-existing files that would conflict, into $BACKUP_DIR"
  while IFS= read -r file; do
    [ -z "$file" ] && continue
    mkdir -p "$BACKUP_DIR/$(dirname "$file")"
    mv "$HOME/$file" "$BACKUP_DIR/$file"
  done <<< "$conflicts"
fi

config checkout

echo
echo "Dotfiles checked out to \$HOME. Open a new shell, then run:"
echo "  \$HOME/install.sh"
