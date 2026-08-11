# Arch Linux (pacman)

Installs everything in `pacman-packages.txt`
(official repo only — AUR packages are not installed by `install.sh`).
`neovim`/`nvm`/`pyenv` come from their upstream installers (same as apt);
`lazygit`/`topgrade` are pacman-installed when present in Arch's repos and
fall back to an upstream tarball (lazygit) or `pipx` (topgrade) otherwise;
`zsh` is pacman-installed (it isn't missing from Arch's repo). GUI apps
live in `pacman-packages-desktop.txt` (same `want_desktop_packages` gate).
Signal is checked at run time via `pm_has_candidate` — it moved into the
official `extra` repo, so `install_signal()` installs it on current Arch.
