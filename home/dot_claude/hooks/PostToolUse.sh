#!/usr/bin/env bash
# PostToolUse hook for Claude Code: keeps edits on the right side of the
# chezmoi wall.
#
# This repo is chezmoi's source directory, so every managed file has two
# paths and only one is real: editing ~/.zshrc instead of
# home/executable_dot_zshrc works immediately and is silently reverted by
# the next `chezmoi apply`. This hook makes that mistake visible at the
# moment it happens.
#
# Two directions are handled:
#   1. The edit landed on a chezmoi-managed target under $HOME (e.g.
#      ~/.zshrc). Emit additional context naming the correct source file
#      under home/ so the edit gets redone there.
#   2. The edit landed inside the source tree (home/...). Drop a per-session
#      marker recording that this session touched the source, so the Stop
#      hook can block ending the session while the tree is dirty.
#
# No-ops silently when jq is missing, or when the edited path is neither a
# managed target nor inside the source tree.

set -euo pipefail

hook_in="$(cat)"
[ -n "$hook_in" ] || exit 0

command -v jq >/dev/null 2>&1 || exit 0

tool_name="$(printf '%s' "$hook_in" | jq -r '.tool_name // empty')"
case "$tool_name" in
  Edit|Write|MultiEdit) ;;
  *) exit 0 ;;
esac

path="$(printf '%s' "$hook_in" | jq -r '.tool_input.file_path // empty')"
[ -n "$path" ] || exit 0

home="$HOME"
src_root="$(chezmoi source-path 2>/dev/null || true)"
[ -n "$src_root" ] || exit 0
src_parent="$(dirname "$src_root")"

# Source tree first: an edit under src_root (or its parent repo root — the
# scripts, Brewfile, manifests) is Direction 2 regardless of it also being
# under $HOME (~/.local/share/chezmoi lives under the home dir).
case "$path" in
  "$src_root"/*|"$src_parent"/*)
    session_id="$(printf '%s' "$hook_in" | jq -r '.session_id // empty')"
    if [ -n "$session_id" ]; then
      marker="/tmp/claude-chezmoi-dirty-${session_id}"
      : > "$marker"
    fi
    exit 0
    ;;
esac

# Direction 1: a managed TARGET under $HOME that was edited directly.
if [ -n "$src_root" ] && [ "${path#"$home"/}" != "$path" ]; then
  # It's under $HOME. Is it chezmoi-managed? If so, tell the agent where the
  # real source file is.
  managed_target="$(chezmoi source-path "$path" 2>/dev/null || true)"
  if [ -n "$managed_target" ] && [ -e "$managed_target" ]; then
    rel="${path#"$home"/}"
    source_rel="${managed_target#"$src_root"/}"
    printf '{"hookSpecificOutput":{"permissionDecision":"allow","permissionDecisionReason":"","additionalContext":"Chezmoi-managed file: you edited ~/%s directly, but the source of truth is home/%s in the dotfiles repo. Redo this edit in the source file (chezmoi cd, edit home/%s) or it will be reverted on the next chezmoi apply.","updatedInput":{}}}\n' \
      "$rel" "$source_rel" "$source_rel"
    exit 0
  fi
  exit 0
fi

exit 0
