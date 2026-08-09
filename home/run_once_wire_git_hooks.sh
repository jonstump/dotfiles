#!/usr/bin/env bash
# Wire the tracked pre-commit hook into this clone of the dotfiles repo.
#
# `git clone` does not carry hook configuration (core.hooksPath is a local
# config setting, not something GitHub clones apply), so a fresh clone has
# no secret-scanning protection until something runs this. chezmoi run_once
# scripts execute after apply, so this is that something.
#
# Runs once per machine (chezmoi tracks run_once by script hash); re-running
# with the hash bumped re-applies harmlessly.
set -euo pipefail

repo_root="$(chezmoi source-path)/.."
if [ ! -d "$repo_root/.git" ]; then
  echo "dotfiles repo not found at $repo_root; skipping hooks wiring." >&2
  exit 0
fi

git -C "$repo_root" config core.hooksPath .githooks
echo "git hooks wired: core.hooksPath = .githooks (in $repo_root)"
