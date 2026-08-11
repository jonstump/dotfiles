#!/usr/bin/env bats
# Tests for the pure, sourceable helpers in bootstrap.sh.
#
# bootstrap.sh guards its entrypoint behind a BASH_SOURCE check (mirroring
# install.sh — see Architecture.md decision 12), so sourcing it here defines
# the functions without executing the bootstrap.

setup() {
  local bootstrap_sh
  bootstrap_sh="$(cd "$(dirname "${BATS_TEST_FILENAME}")/.." && pwd)/bootstrap.sh"
  # shellcheck source=bootstrap.sh
  source "$bootstrap_sh"
  export BOOTSTRAP_SH="$bootstrap_sh"
}

@test "is_atomic_fedora detects bazzite by ID" {
  local fake_os
  fake_os="$(mktemp)"
  printf 'ID=bazzite\nVARIANT_ID="stable"\n' > "$fake_os"
  run env OS_RELEASE="$fake_os" OSTREE_MARKER="/nonexistent-for-test" bash -c '
    source "${BOOTSTRAP_SH:?}"
    is_atomic_fedora
  '
  [ "$status" -eq 0 ]
  rm -f "$fake_os"
}

@test "is_atomic_fedora detects fedora silverblue/kinoite variants" {
  local fake_os
  fake_os="$(mktemp)"
  printf 'ID=fedora\nVARIANT_ID="silverblue"\n' > "$fake_os"
  run env OS_RELEASE="$fake_os" OSTREE_MARKER="/nonexistent-for-test" bash -c '
    source "${BOOTSTRAP_SH:?}"
    is_atomic_fedora
  '
  [ "$status" -eq 0 ]

  printf 'ID=fedora\nVARIANT_ID="kinoite"\n' > "$fake_os"
  run env OS_RELEASE="$fake_os" OSTREE_MARKER="/nonexistent-for-test" bash -c '
    source "${BOOTSTRAP_SH:?}"
    is_atomic_fedora
  '
  [ "$status" -eq 0 ]
  rm -f "$fake_os"
}

@test "is_atomic_fedora is false for plain fedora/debian and true for ostree marker" {
  local fake_os
  fake_os="$(mktemp)"
  printf 'ID=fedora\nVARIANT_ID="workstation"\n' > "$fake_os"
  run env OS_RELEASE="$fake_os" OSTREE_MARKER="/nonexistent-for-test" bash -c '
    source "${BOOTSTRAP_SH:?}"
    is_atomic_fedora
  '
  [ "$status" -ne 0 ]

  # Even a plain os-release is atomic when the ostree marker exists.
  run env OS_RELEASE="$fake_os" OSTREE_MARKER="/etc/hosts" bash -c '
    source "${BOOTSTRAP_SH:?}"
    is_atomic_fedora
  '
  [ "$status" -eq 0 ]

  printf 'ID=debian\n' > "$fake_os"
  run env OS_RELEASE="$fake_os" OSTREE_MARKER="/nonexistent-for-test" bash -c '
    source "${BOOTSTRAP_SH:?}"
    is_atomic_fedora
  '
  [ "$status" -ne 0 ]
  rm -f "$fake_os"
}

@test "BACKUP_DIR is timestamped so re-runs cannot clobber the previous backup" {
  # Regression for #174: a fixed name meant a second bootstrap run would
  # silently overwrite the one surviving copy of the user's pre-dotfiles
  # config. The scheme matches install.sh's backup_aside().
  [ -n "$BACKUP_DIR" ]
  # The HOME prefix is compared literally (no regex metachar issue), the
  # suffix is the timestamp pattern.
  [ "$BACKUP_DIR" != "${BACKUP_DIR#"$HOME"/}" ]
  [[ "$BACKUP_DIR" =~ \.dotfiles-backup-[0-9]{14}$ ]]

  # The anti-clobber property is two runs into the SAME $HOME producing two
  # surviving backups (a different HOME would make the paths differ even
  # with the old fixed name — the bug the previous test failed to catch).
  local home
  home="$(mktemp -d)"
  local d1 d2
  d1="$(HOME="$home" bash -c 'source "$1"; printf "%s" "$BACKUP_DIR"' _ "${BOOTSTRAP_SH:?}")"
  sleep 1   # timestamp resolution: two runs must land in different seconds
  d2="$(HOME="$home" bash -c 'source "$1"; printf "%s" "$BACKUP_DIR"' _ "${BOOTSTRAP_SH:?}")"
  [ "$d1" != "$d2" ]
  rm -rf "$home"
}
