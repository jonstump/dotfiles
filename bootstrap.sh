#!/usr/bin/env bash
# One-time entry point for a brand new machine, meant to be run BEFORE
# chezmoi or this repo exist locally, e.g.:
#   curl -fsSL https://raw.githubusercontent.com/jonstump/dotfiles/main/bootstrap.sh | bash
#
# Makes sure git exists (Xcode Command Line Tools on macOS, the distro package
# on Linux), installs chezmoi itself, then has chezmoi clone this repo as its
# source directory and apply it on top of $HOME.
# After this finishes, open a new shell and run: $(chezmoi source-path)/../install.sh

DOTFILES_REPO="jonstump/dotfiles"
# Timestamped so a re-run of this script (after an interrupted/partial run)
# never clobbers the backup from the previous run: the second run re-backs-up
# every target that is now a regular file (chezmoi's own output from run one),
# and without the suffix that `mv` would silently overwrite the user's one
# copy of the pre-dotfiles config (issue #174). install.sh's backup_aside()
# uses the same date +%Y%m%d%H%M%S scheme.
BACKUP_DIR="$HOME/.dotfiles-backup-$(date +%Y%m%d%H%M%S)"

# Runs an apt-get subcommand (e.g. `update` or `install -y git`) with the
# same fault tolerance install.sh uses: retry while the dpkg/apt lock is held
# (a near-certainty on a fresh PikaOS/Debian/Ubuntu install, where the OS's
# own background update timers or a GUI app-center compete for it right after
# first login), and treat a failed `update` as a warning rather than an error
# — a single third-party repo with stale/dirty metadata (known on PikaOS: its
# dep11 AppStream hash mismatch) makes apt-get update exit non-zero even when
# the actual indices came through fine. What must NOT happen is `set -e`
# killing this very first script over something apt itself calls non-fatal.
# Callers decide what a still-failing "update" means (they pass it through the
# normal `|| echo WARNING` path); a failing "install" returns its real rc.
apt_guarded() {
  local i
  for i in 1 2 3 4 5; do
    if sudo apt-get "$@"; then
      return 0
    fi
    local rc=$?
    # A busy lock is worth waiting out; any other error won't resolve by
    # re-running, so return immediately and let the caller react. fuser must
    # run as root: the lock holder on a fresh install is a root-owned
    # background updater, invisible to an unprivileged fuser. fuser accepts
    # multiple names and exits 0 if any is held — one call covers all four
    # apt/dpkg lock files.
    if ! sudo fuser /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock \
         /var/lib/apt/lists/lock /var/cache/apt/archives/lock >/dev/null 2>&1; then
      return "$rc"
    fi
    if [ $i -lt 5 ]; then
      echo "WARNING: apt-get $*: dpkg/apt lock busy (attempt $i/5); retrying in $((i * 3))s." >&2
      sleep "$((i * 3))"
    fi
  done
  return 1
}

# A genuinely fresh machine may not have git at all: macOS ships /usr/bin/git
# as an xcrun stub that only works once the Command Line Tools are installed,
# and git isn't in the default Ubuntu Desktop / Debian netinst package set.
# Sort that out before touching anything else, so a missing git can't kill the
# script partway through. chezmoi's own git-backed clone works without a
# system git, but `chezmoi cd`/`git -C "$(chezmoi source-path)"` day-to-day
# usage (see README.md) needs a real one anyway.
#
# Atomic/immutable Fedora derivatives (Bazzite, Silverblue, Kinoite, uBlue
# siblings) gate on the /run/ostree-booted marker and /etc/os-release ID —
# the same detection install.sh's detect_os() does before the generic
# package-manager checks, kept in sync here (issue #162). These images ship
# without a `dnf` binary (the old cliwrap shim is gone), a root fs that is
# read-only anyway, and no pacman/zypper — so the generic branches below
# would otherwise fall through to "No known package manager found". git
# bootstrapping there needs rpm-ostree layering (reboot required) or a
# toolbox; give an actionable pointer instead of a dead end.
is_atomic_fedora() {
  local id variant
  if [ -f "${OS_RELEASE:-/etc/os-release}" ]; then
    # os-release values may be bare, single- or double-quoted (the spec
    # allows ID='fedora'); strip any single level of quote so the case
    # comparison below sees the bare value.
    id="$(sed -n 's/^ID=//p' "${OS_RELEASE:-/etc/os-release}" | head -1 | sed "s/^['\"]//; s/['\"]$//")"
    variant="$(sed -n 's/^VARIANT_ID=//p' "${OS_RELEASE:-/etc/os-release}" | head -1 | sed "s/^['\"]//; s/['\"]$//")"
    case "$id" in
      bazzite) return 0 ;;
      fedora)
        case "$variant" in
          silverblue|kinoite) return 0 ;;
        esac
        ;;
    esac
  fi
  [ -e "${OSTREE_MARKER:-/run/ostree-booted}" ]
}
ensure_git() {
  if [ "$(uname -s)" = "Darwin" ]; then
    if ! /usr/bin/xcode-select -p >/dev/null 2>&1; then
      echo "Installing Xcode Command Line Tools (git ships with them)."
      # `xcode-select --install` both succeeds (dialog shown) and fails with
      # no dialog at all when the CLT receipt is stale or partial (known
      # macOS state after an interrupted install or a version mismatch). A
      # repeat run in that state always lands here; telling the user to
      # "accept the dialog" again goes nowhere, so distinguish by testing
      # whether a dialog can even be triggered (exit 0) vs the immediate
      # failure (issue #178).
      local xcode_err
      xcode_err="$(mktemp)"
      if /usr/bin/xcode-select --install 2>"$xcode_err"; then
        echo "Accept the dialog, wait for it to finish, then re-run this script."
      elif grep -qi "already installed" "$xcode_err"; then
        # `-p` failed but the tools are actually present: `--install` exits
        # non-zero with "Command line tools are already installed", typically
        # because the active developer dir points at a removed Xcode.app.
        # Re-pointing is the fix; nuking the CLT receipt would be destructive
        # and pointless here (issue #178).
        echo "Xcode Command Line Tools appear already installed, but" >&2
        echo "xcode-select -p can't find them (stale developer dir)." >&2
        echo "Try: sudo xcode-select --reset   then re-run this script." >&2
        rm -f "$xcode_err"
        exit 1
      else
        echo "ERROR: xcode-select --install failed without showing a dialog." >&2
        echo "This usually means a stale or partial Command Line Tools receipt." >&2
        echo "Recovery: sudo rm -rf /Library/Developer/CommandLineTools" >&2
        echo "then re-run: xcode-select --install" >&2
        rm -f "$xcode_err"
        exit 1
      fi
      rm -f "$xcode_err"
      exit 1
    fi
  elif command -v git >/dev/null 2>&1; then
    :
  elif is_atomic_fedora; then
    # rpm-ostree images: layering is a reboot-gated operation and can't be
    # done inline, and the image usually ships git anyway (the common case of
    # still not finding it here is a stripped-down uBlue variant). Point at
    # the real options instead of the generic "no package manager" dead end.
    echo "git is not on PATH on this rpm-ostree (Bazzite/Silverblue/Kinoite)" >&2
    echo "system. Install it with: rpm-ostree install git  (then reboot), or" >&2
    echo "use a toolbox: toolbox enter -c 'sudo dnf install -y git'." >&2
    exit 1
  else
    echo "git not found — installing it first."
    if command -v apt-get >/dev/null 2>&1; then
      # A failed install returns non-zero but must not kill the script (set
      # -e); the "git is still unavailable" check below reports it cleanly.
      # The update is best-effort the same way install.sh's apt_update()
      # treats it: a single third-party repo with stale metadata makes
      # `apt-get update` exit non-zero even when the indices came through
      # fine, and set -e must not turn that into a hard stop (issue #173).
      apt_guarded update || \
        echo "WARNING: apt-get update reported errors (see above); continuing." >&2
      apt_guarded install -y git ca-certificates || \
        echo "WARNING: apt install of git failed; continuing so the check below can report it." >&2
    elif command -v dnf >/dev/null 2>&1; then
      sudo dnf install -y git
    elif command -v pacman >/dev/null 2>&1; then
      sudo pacman -Syu --noconfirm git
    elif command -v zypper >/dev/null 2>&1; then
      sudo zypper --non-interactive install git
    else
      echo "No known package manager found. Install git yourself" >&2
      echo "and re-run this script." >&2
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

main() {
  # Strict mode lives here, not at file top-level: bootstrap.sh is sourceable
  # (like install.sh, for the bats suite), and a top-level `set -euo pipefail`
  # would leak into the caller's shell and kill it on any helper returning
  # non-zero. Functions defined at source time still pick it up at call time.
  set -euo pipefail

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
  echo "  \$(chezmoi source-path)/../install.sh"
}

# Only run the bootstrap when executed directly. Sourcing the file (as the
# bats test-suite does, mirroring install.sh's guard — see Architecture.md
# decision 12) defines the helpers and globals but must not start
# installing anything.
#
# Note the fallback: when bash reads a script from a pipe — the documented
# `curl -fsSL …/bootstrap.sh | bash` path, which runs before any local clone
# exists — BASH_SOURCE is empty and $0 is "bash", so comparing only
# `BASH_SOURCE[0]` would silently *never* run main (verified regression:
# exit 0, no output, nothing installed). Falling back to $0 keeps the
# curl-pipe path working while still skipping main when the file is sourced
# (bats: BASH_SOURCE[0] is the real path, different from $0).
if [ "${BASH_SOURCE[0]:-$0}" = "$0" ]; then
  main
fi

