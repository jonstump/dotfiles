# Fedora (dnf)

Installs everything in `dnf-packages.txt`, and
`neovim`/`nvm`/`pyenv` come from their upstream installers;
`lazygit`/`topgrade` are dnf-installed when available, falling back to an
upstream tarball (lazygit) or `pipx` (topgrade) otherwise. `zsh` is
dnf-installed. GUI apps live in `dnf-packages-desktop.txt`. Signal needs
an external Copr repo that `install.sh` doesn't add — install it yourself.
