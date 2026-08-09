#!/usr/bin/env bash
# Stop hook for Claude Code: block ending a session that left the dotfiles
# source tree dirty.
#
# The mirror-image failure of the PostToolUse hook: editing the source
# correctly (home/executable_dot_zshrc) but ending the session without ever
# committing, leaving the tree dirty and the change unpublished. This hook
# makes that visible before the session disappears.
#
# Only fires when THIS session touched the source tree (the PostToolUse hook
# drops a marker for that), so a session that never touched this repo is
# never nagged even when the tree is dirty from something else.
#
# Blocks at most once: the first dirty stop returns continue with a reason.
# A second dirty stop (stop_hook_active is set) releases cleanly, so the
# session can never be trapped in a loop.
#
# No-ops silently when jq is missing or the repo isn't git.

set -euo pipefail

command -v jq >/dev/null 2>&1 || exit 0

hook_in="$(cat)"
session_id="$(printf '%s' "$hook_in" | jq -r '.session_id // empty')"
[ -n "$session_id" ] || exit 0

marker="/tmp/claude-chezmoi-dirty-${session_id}"
if [ ! -e "$marker" ]; then
  # This session never touched the source tree — even a dirty tree is not
  # this session's business.
  exit 0
fi

# Release path: Claude Code sets stop_hook_active=1 on the retry. The first
# dirty stop must return continue with the reason; once the user (or agent)
# acknowledges, the retry sees the flag and we exit 0 to allow the stop.
if [ "${stop_hook_active:-0}" = "1" ]; then
  rm -f "$marker"
  exit 0
fi

src_root="$(chezmoi source-path 2>/dev/null || true)"
[ -n "$src_root" ] || { rm -f "$marker"; exit 0; }
repo_root="$(dirname "$src_root")"

branch="$(git -C "$repo_root" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")"

# The extra context tells the agent to finish the commit now.
printf '{"hookSpecificOutput":{"permissionDecision":"continue","permissionDecisionReason":"The dotfiles source tree is dirty and this session edited it. Finish and commit before ending: cd %s && git status && git add -A && git commit (branch: %s).","additionalContext":"Dirty dotfiles tree pending commit — see reason."}}\n' \
  "$repo_root" "$branch"

exit 0
