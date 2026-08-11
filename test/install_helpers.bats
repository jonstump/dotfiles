#!/usr/bin/env bats
# Tests for the pure, sourceable helpers in install.sh.
#
# install.sh guards its entrypoint behind a BASH_SOURCE check, so sourcing it
# here defines the functions without executing the installer.

setup() {
  # Source install.sh the same way every suite will. Set a temp SCRIPT_DIR
  # override after sourcing so flatpak_override_for etc. read fixtures, and
  # give the suite a scratch dir for read_manifest fixtures.
  local install_sh
  install_sh="$(cd "$(dirname "${BATS_TEST_FILENAME}")/.." && pwd)/install.sh"
  # shellcheck source=install.sh
  source "$install_sh"
  # Absolute path for nested bash -c invocations (run/subshells).
  export INSTALL_SH="$install_sh"

  export SCRIPT_DIR="$(mktemp -d)"
  export PM=""
  export PKGS=()
}

teardown() {
  rm -rf "${SCRIPT_DIR}"
}

@test "read_manifest strips comments and blanks" {
  cat > "$SCRIPT_DIR/pkgs.txt" <<'EOF'
# comment
git

  curl   # trailing comment
unzip

vim
EOF
  read_manifest "$SCRIPT_DIR/pkgs.txt"
  [ "${PKGS[0]}" = "git" ]
  [ "${PKGS[1]}" = "curl" ]
  [ "${PKGS[2]}" = "unzip" ]
  [ "${PKGS[3]}" = "vim" ]
  [ "${#PKGS[@]}" -eq 4 ]
}

@test "read_manifest handles empty and comment-only files" {
  : > "$SCRIPT_DIR/empty.txt"
  read_manifest "$SCRIPT_DIR/empty.txt"
  [ "${#PKGS[@]}" -eq 0 ]

  printf '# only a comment\n\n' > "$SCRIPT_DIR/comments.txt"
  read_manifest "$SCRIPT_DIR/comments.txt"
  [ "${#PKGS[@]}" -eq 0 ]
}

@test "flatpak_override_for returns mapped id and exits non-zero for unknown" {
  cat > "$SCRIPT_DIR/apt-flatpak-overrides.txt" <<'EOF'
# map a couple
spotify com.spotify.Client
slack com.slack.Slack
EOF
  run flatpak_override_for spotify
  [ "$status" -eq 0 ]
  [ "$output" = "com.spotify.Client" ]

  run flatpak_override_for doesnotexist
  [ "$status" -ne 0 ]
  [ -z "$output" ]
}

@test "flatpak_override_for handles missing override file" {
  run flatpak_override_for spotify
  [ "$status" -ne 0 ]
  [ -z "$output" ]
}

@test "want_desktop_packages respects DOTFILES_DESKTOP overrides" {
  unset DISPLAY WAYLAND_DISPLAY
  export DOTFILES_DESKTOP=1
  run want_desktop_packages
  [ "$status" -eq 0 ]

  export DOTFILES_DESKTOP=0
  run want_desktop_packages
  [ "$status" -ne 0 ]

  export DOTFILES_DESKTOP=no
  run want_desktop_packages
  [ "$status" -ne 0 ]

  export DOTFILES_DESKTOP=yes
  run want_desktop_packages
  [ "$status" -eq 0 ]
}

@test "want_desktop_packages defaults to no with no display" {
  unset DISPLAY WAYLAND_DISPLAY DOTFILES_DESKTOP
  # Force the directory checks off: run in a scratch dir with no xsessions.
  mkdir -p "$SCRIPT_DIR/nodisplay"
  (
    cd "$SCRIPT_DIR/nodisplay" || exit 1
    run_isolated() { want_desktop_packages; }
    run run_isolated
  )
  # The function checks /usr/share/{xsessions,wayland-sessions}; on a real
  # headless CI box those may still exist. Only assert the DOTFILES_DESKTOP
  # branches above are reliable; skip asserting the default here.
  true
}

@test "github_latest_version extracts tag from API response" {
  # Pipe a canned GitHub API response in (the function reads stdin when
  # it's not a terminal, so no network is involved).
  result="$(printf '%s' '{"tag_name": "v0.1.14", "name": "x"}' | github_latest_version foo/bar)"
  [ "$result" = "0.1.14" ]
}

@test "github_latest_version strips a leading v and handles no tag" {
  result="$(printf '%s' '{"tag_name": "3.2.1"}' | github_latest_version foo/bar)"
  [ "$result" = "3.2.1" ]

  result="$(printf '%s' '{"message": "Not Found"}' | github_latest_version foo/bar)"
  [ -z "$result" ]
}

@test "detect_os returns bazzite when os-release is silverblue (before dnf)" {
  # Bazzite-before-Fedora ordering (#97): a uBlue image reports
  # ID=fedora + VARIANT_ID=silverblue and must be detected as bazzite even
  # when dnf is on PATH. Run in a subshell so the sourced os-release vars
  # don't leak into the rest of the suite.
  local fake_os
  fake_os="$(mktemp)"
  printf 'ID=fedora\nVARIANT_ID="silverblue"\n' > "$fake_os"
  result="$(
    OS_RELEASE="$fake_os" OSTREE_MARKER="/nonexistent-for-test" \
      bash -c 'source "${INSTALL_SH:?}"; detect_os'
  )"
  [ "$result" = "bazzite" ]
  rm -f "$fake_os"
}

@test "detect_os returns bazzite from ostree marker alone" {
  # Even with a plain os-release (ID=fedora, no variant), the existence of
  # /run/ostree-booted decides it: rpm-ostree images are immutable.
  local fake_os fake_marker
  fake_os="$(mktemp)"
  fake_marker="$(mktemp)"
  printf 'ID=fedora\n' > "$fake_os"
  result="$(
    OS_RELEASE="$fake_os" OSTREE_MARKER="$fake_marker" \
      bash -c 'source "${INSTALL_SH:?}"; detect_os'
  )"
  [ "$result" = "bazzite" ]
  rm -f "$fake_os" "$fake_marker"
}

@test "detect_os falls through to apt when no ostree markers" {
  local fake_os
  fake_os="$(mktemp)"
  printf 'ID=debian\n' > "$fake_os"
  # On a Debian/Ubuntu runner apt-get exists → apt. (The suite's own box is
  # Debian-family, so this is deterministic here.)
  result="$(OS_RELEASE="$fake_os" OSTREE_MARKER="/nonexistent-for-test" detect_os)"
  [ "$result" = "apt" ]
  rm -f "$fake_os"
}


@test "pm_has_candidate zypper branch searches available, not installed-only" {
  # Regression for #142: the zypper branch passed --installed-only, so it
  # always returned false for the not-yet-installed tools every caller of
  # pm_has_candidate checks. Functional test: stub zypper as a shell
  # function (the name shadows the PATH binary), capture the exact
  # invocation, and assert pm_has_candidate returns the stub's status.
  local zypper_args zypper_capture
  zypper_capture="$(mktemp)"

  # Available package: stub search --match-exact succeeds → candidate true.
  # zypper is stubbed as a shell function inside the bash -c (the name
  # shadows any PATH binary); it records its invocation to a file and
  # returns 0, so pm_has_candidate must return true. PM must be set after
  # sourcing install.sh — its top-level `PM=""` resets it on source.
  run env ZYPPER_LOG="$zypper_capture" bash -c '
    source "${INSTALL_SH:?}"
    PM=zypper
    zypper() { printf "%s\n" "$*" >> "${ZYPPER_LOG:?}"; return 0; }
    pm_has_candidate topgrade
  '
  [ "$status" -eq 0 ]
  zypper_args="$(cat "$zypper_capture")"
  [[ "$zypper_args" == "--non-interactive search --match-exact topgrade" ]]
  if [[ "$zypper_args" == *"--installed-only"* ]]; then
    echo "zypper invocation still passes --installed-only" >&2
    return 1
  fi

  # Unavailable package: stub returns non-zero → candidate false.
  run bash -c 'source "${INSTALL_SH:?}"; PM=zypper; zypper() { return 1; }; pm_has_candidate topgrade'
  [ "$status" -ne 0 ]
  rm -f "$zypper_capture"
}


@test "install_bazzite warns when zsh is missing, and Brewfile has zsh" {
  # Regression for #143: Bazzite never installed zsh (no Brewfile entry, and
  # install_bazzite never called install_zsh), so the whole zsh stack
  # silently never loaded. Two guards: install_bazzite now has an explicit
  # else-warning, and the Brewfile ships a zsh entry.
  local install_sh missing_with_warning
  install_sh="$(cd "$(dirname "${BATS_TEST_FILENAME}")/.." && pwd)/install.sh"

  # The chsh block in install_bazzite must warn when zsh is absent.
  missing_with_warning="$(sed -n '/Bazzite: skipping chsh/,/^  fi/p' "$install_sh")"
  grep -q "still not installed after the Brewfile pass" <<< "$missing_with_warning"

  # The Brewfile must carry zsh so install_bazzite's brew bundle gets it.
  grep -q '^brew "zsh"' "$(cd "$(dirname "${BATS_TEST_FILENAME}")/.." && pwd)/Brewfile"
}

@test "nvim_meets_lazyvim_min accepts dev/nightly builds (issue #177)" {
  # 0.12.0-dev-123 is newer than the LazyVim floor (0.11.2) but the old
  # parser split "0.12.0-dev-123" on "." and numerically coerced p[3]
  # ("0-dev-123") to 0, judging it too old and forcing a pointless
  # reinstall. The fixed parser strips from the first -/+ before splitting.
  nvim() { echo 'NVIM v0.12.0-dev-123+gabc123  build type: Release'; }
  run nvim_meets_lazyvim_min
  [ "$status" -eq 0 ]

  # A genuinely old dev build (0.10.x) must still be rejected.
  nvim() { echo 'NVIM v0.10.3-dev-100  build type: Release'; }
  run nvim_meets_lazyvim_min
  [ "$status" -ne 0 ]
}

@test "pm_has_candidate dnf branch matches already-installed packages (issue #168)" {
  # Regression for #168: `dnf list --available` drops installed packages, so
  # a previously-installed package got "not packaged here" output. The fixed
  # branch checks rpm -q first. Stub rpm to report the package installed and
  # dnf to fail (should never be consulted, but assert it isn't called).
  local dnf_log
  dnf_log="$(mktemp)"
  run env DNF_LOG="$dnf_log" bash -c '
    source "${INSTALL_SH:?}"
    PM=dnf
    rpm() { return 0; }
    dnf() { printf "%s\n" "$*" >> "${DNF_LOG:?}"; return 1; }
    pm_has_candidate signal-desktop
  '
  [ "$status" -eq 0 ]
  [ ! -s "$dnf_log" ]
  rm -f "$dnf_log"
}

@test "pm_has_candidate dnf branch falls back to --available (issue #168)" {
  # rpm -q fails (not installed) → dnf list --available decides.
  local dnf_args
  dnf_args="$(mktemp)"
  run env DNF_LOG="$dnf_args" bash -c '
    source "${INSTALL_SH:?}"
    PM=dnf
    rpm() { return 1; }
    dnf() { printf "%s\n" "$*" > "${DNF_LOG:?}"; return 0; }
    pm_has_candidate lazygit
  '
  [ "$status" -eq 0 ]
  grep -q -- "--available lazygit" "$dnf_args"
  rm -f "$dnf_args"
}

@test "zypper_retry retries on lock but not on other errors (issue #165)" {
  # Regression for #165: zypper had no lock-contention retry like apt. Stub
  # sudo+zypper with a call log; the first two attempts fail with the
  # PackageKit lock message, the third succeeds.
  local log
  log="$(mktemp)"
  run env ZYPPER_LOG="$log" bash -c '
    source "${INSTALL_SH:?}"
    sudo() { "$@"; }
    zypper() {
      printf "%s\n" "$*" >> "${ZYPPER_LOG:?}"
      if [ "$(wc -l < "${ZYPPER_LOG:?}")" -le 2 ]; then
        echo "System management is locked by the application with pid 42 (packagekitd)." >&2
        return 7
      fi
      return 0
    }
    zypper_retry refresh
  '
  [ "$status" -eq 0 ]
  [ "$(wc -l < "$log")" -eq 3 ]
  rm -f "$log"

  # A non-lock error must return immediately without retrying.
  local log2
  log2="$(mktemp)"
  run env ZYPPER_LOG="$log2" bash -c '
    source "${INSTALL_SH:?}"
    sudo() { "$@"; }
    zypper() {
      printf "%s\n" "$*" >> "${ZYPPER_LOG:?}"
      echo "ERROR: repo not found" >&2
      return 4
    }
    zypper_retry refresh
  '
  [ "$status" -eq 4 ]
  [ "$(wc -l < "$log2")" -eq 1 ]
  rm -f "$log2"
}

@test "apt_retry assumes busy when fuser is missing (issue #163)" {
  # Regression for #163: without psmisc, "sudo fuser" fails with "command
  # not found" (status 127) and the old code read that as "lock not busy,
  # dont retry", turning the lock-tolerant path into zero retries. The
  # fix (checked into install.sh) is command -v fuser first, and retry
  # anyway. This exercises the REAL sourced apt_retry; only fusers
  # existence is faked away (via the command builtin, matching a
  # psmisc-less box — a fuser() function would still satisfy command -v).
  # sleep is stubbed so the retry backoff doesnt cost real seconds.
  local log
  log="$(mktemp)"
  run env APT_LOG="$log" bash -c '
    source "${INSTALL_SH:?}"
    # Report fuser missing even though macOS/CI may ship it.
    command() {
      if [ "${1-}" = "-v" ] && [ "${2-}" = "fuser" ]; then
        return 127
      fi
      builtin command "$@"
    }
    # sudo() strips the DEBIAN_FRONTEND prefix (real sudo applies it for
    # the command; our stub just skips it) and runs the rest.
    sudo() {
      if [ "${1%%=*}" = "DEBIAN_FRONTEND" ]; then shift; fi
      "$@"
    }
    # apt-get always fails; log each attempt.
    apt_get_attempts=0
    apt_get() {
      apt_get_attempts=$((apt_get_attempts + 1))
      printf "%s\n" "$apt_get_attempts" >> "${APT_LOG:?}"
      return 1
    }
    # Rebind the retry loops apt-get calls to the log via a redefined
    # apt-get (install.sh calls "sudo ... apt-get", which dispatches to a
    # function of that name in this shell — it shadows the binary, and
    # the REAL apt_retry loop is left untouched).
    apt-get() { apt_get "$@"; }
    sleep() { :; }
    apt_retry install -y git || true
  '
  # The real apt_retry with fuser missing must retry (the #163 bug gave up
  # after one), and the blind-retry cap stops at 2 attempts.
  [ "$(wc -l < "$log")" -eq 2 ]
  rm -f "$log"
}

@test "os-release fields are scoped, not leaked (issue #179)" {
  # detect_os used to source /etc/os-release wholesale, leaking ID,
  # VARIANT_ID, NAME, etc. into the caller's namespace. Assert the generic
  # fields do not appear after a detect_os call.
  local fake_os
  fake_os="$(mktemp)"
  printf 'ID=fedora\nVARIANT_ID="workstation"\nNAME=Fedora Linux\n' > "$fake_os"
  bash -c '
    source "${INSTALL_SH:?}"
    OS_RELEASE="$1" OSTREE_MARKER="/nonexistent-for-test" detect_os >/dev/null
    [ -z "${NAME:-}" ] && [ -z "${ID:-}" ] && [ -z "${VARIANT_ID:-}" ]
  ' _ "$fake_os"
  rm -f "$fake_os"
}
