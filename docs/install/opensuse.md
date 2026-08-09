# openSUSE (zypper)

Installs everything in `zypper-packages.txt` (Leap
and Tumbleweed share one path; package names verified against the OSS
repos — `fd`, `the_silver_searcher`, `git-delta`, `ImageMagick`,
`libopenssl-devel`, `libbz2-devel`, `sqlite3-devel`, `xmlsec1-devel`, etc.).
`topgrade` is packaged, `neovim`/`nvm`/`pyenv`/`lazygit` come from their
upstream installers (lazygit checks for a zypper candidate first), and `zsh`
is zypper-installed. GUI apps live in `zypper-packages-desktop.txt`. Signal
isn't in the official repos — install via its network repo or Flatpak
yourself.
