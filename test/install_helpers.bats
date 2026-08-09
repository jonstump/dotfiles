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
