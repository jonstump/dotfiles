# dotfiles

Personal dotfiles for macOS, Debian/Ubuntu-family Linux (PikaOS, etc.), and
NixOS. Managed as a bare git repo checked out on top of `$HOME`, rather than
symlinked from a cloned working copy.

## Install on a new machine

**1. Bootstrap** — clones this repo as a bare repo and checks it out onto
`$HOME`. Safe to run on a machine that already has its own default
`.zshrc`/`.zprofile`/etc.: anything that would conflict with the checkout is
moved to `~/.dotfiles-backup` first instead of being overwritten.

```sh
curl -fsSL https://raw.githubusercontent.com/jonstump/dotfiles/main/bootstrap.sh | bash
```

Only `curl` is required up front — the script installs git itself if it's
missing. On macOS that means kicking off the Xcode Command Line Tools install
(git ships with them); accept the dialog, let it finish, then re-run the same
command. On Linux it installs git via `apt-get`/`dnf`/`pacman`/`zypper`. On
NixOS, run it inside `nix-shell -p git`.

**2. Install tooling** — open a new shell, then run the OS-detecting
installer that was just checked out:

```sh
$HOME/install.sh
```

- **macOS**: installs Homebrew if it's missing, then `brew bundle --file=Brewfile`.
- **Debian/Ubuntu-family Linux (apt)**: adds the Signal apt repo (modern
  `signed-by` keyring, not the deprecated `apt-key`), installs everything in
  `apt-packages.txt` via `apt install`, and installs `nvm`/`pyenv`/`topgrade`/
  `oh-my-tmux` via their own upstream installers since none of those are
  reliable apt packages (`topgrade` comes from PyPI via `pipx install
  topgrade`, using the `pipx` apt already installed).
- **NixOS**: skips package installation entirely — packages for NixOS
  machines are declared in a separate flake/home-manager repo, not here.
  Only sets up the non-package pieces (`oh-my-tmux`).

`install.sh` is safe to re-run; every step checks whether its target already
exists before doing anything.

## Day-to-day usage

This repo is checked out directly on top of `$HOME` via a bare repo at
`~/Repos/dotfiles`, using the `config` alias defined in `.zsh_aliases`:

```sh
alias config='/usr/bin/git --git-dir=$DOTFILES/ --work-tree=$HOME'
```

Use `config` exactly like `git`, just pointed at your home directory instead
of a normal working copy:

```sh
config status
config add <file>
config commit -m "..."
config push
```

`status.showUntrackedFiles` is set to `no` for this repo, so `config status`
only shows changes to files it already tracks — it won't try to list every
unrelated file in `$HOME`. Avoid `config add -A`/`config add .` for that
reason; add files by name, or use `config add -u` to stage modifications/
deletions to already-tracked files only.

Updates to installed tools are handled by [`topgrade`](https://github.com/topgrade-rs/topgrade)
rather than a dotfiles alias — run `topgrade` directly.

## What's here

| Path | Purpose |
|---|---|
| `.zshrc`, `.zprofile`, `.zsh_aliases` | Shell config. OS-detected (`IS_MAC`/`IS_LINUX`) where Mac and Linux paths diverge — Homebrew-only lines are guarded so they're inert on Linux/NixOS. |
| `.config/nvim/` | [LazyVim](https://www.lazyvim.org/) — the starter template plus a `gruvbox` colorscheme override in `lua/plugins/colorscheme.lua`. |
| `.config/tmux/tmux.conf` | Points at [oh-my-tmux](https://github.com/gpakosz/.tmux) via `source-file ~/.local/share/tmux/oh-my-tmux/.tmux.conf` (cloned there by `install.sh`). |
| `.config/tmux/tmux.conf.local` | Local oh-my-tmux overrides. |
| `.config/kitty/` | Kitty terminal config, gruvbox colorscheme. |
| `.config/lf/lfrc` | [lf](https://github.com/gokcehan/lf) file manager config. |
| `Brewfile` | macOS package manifest (`brew bundle --file=Brewfile`). |
| `apt-packages.txt` | Linux (apt) package manifest — a curated core set, not a full mirror of `Brewfile`; extend as needed per-distro. |
| `bootstrap.sh` | One-time bare-repo checkout for a brand new machine. |
| `install.sh` | OS-detecting package/tool installer, run after `bootstrap.sh`. |
| `.antigen.zsh` | Vendored copy of [antigen](https://github.com/zsh-users/antigen), used as the Linux zsh-plugin-manager fallback (macOS uses Homebrew's copy instead). |
| `.dots_archive/` | Retired scripts/configs kept for reference only — not part of the active install path. |

## Shell auto-tmux behavior

Opening a new interactive terminal automatically attaches to a single shared
tmux session named `main` (creating it if it doesn't exist yet), instead of
spawning a new session per terminal window. See the `exec tmux new-session -A
-s main` line in `.zshrc`.
