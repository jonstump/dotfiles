# Debian / Ubuntu (apt)

Adds the Signal apt repo on amd64 (modern `signed-by` keyring in
`/etc/apt/keyrings`, not the deprecated `apt-key`), installs everything in
`apt-packages.txt`, and installs `neovim`/`nvm`/`pyenv` via their own
upstream installers since none of those are reliable apt packages;
`lazygit`/`topgrade` are apt-installed when a candidate exists and otherwise
fall back to an upstream tarball (lazygit) or `pipx` (topgrade — using the
`pipx` that apt already installed). Unavailable packages are reported and
skipped rather than failing the install.

- `zsh` itself is apt-installed when available, but on a derivative distro
  whose `sources.list` doesn't carry it (seen on PikaOS), it's built from
  the upstream release tarball instead — `build-essential` and
  `libncurses-dev` from `apt-packages.txt` are the only extra
  dependencies it needs, and the resulting `/usr/local/bin/zsh` is added to
  `/etc/shells` so `chsh` (below) still picks it up.
- GUI apps live in `apt-packages-desktop.txt` and are only installed when a
  display environment is detected. Force it either way with
  `DOTFILES_DESKTOP=1` / `DOTFILES_DESKTOP=0`.
- Your login shell is switched to zsh only if it's listed in `/etc/shells`;
  otherwise it says so and moves on.
