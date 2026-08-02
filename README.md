# dotfiles

Personal dotfiles for macOS, Debian/Ubuntu-family Linux (PikaOS, etc.), and
NixOS. Managed with [chezmoi](https://www.chezmoi.io/).

This repo **is** the chezmoi source directory: filenames use chezmoi's
[source-state naming](https://www.chezmoi.io/reference/source-state-attributes/)
(`dot_zshrc` → `~/.zshrc`, `dot_config/lf/lfrc` → `~/.config/lf/lfrc`), and
package installation is handled by scripts in `.chezmoiscripts/` that chezmoi
runs as part of `chezmoi apply`.

## Install on a new machine

```sh
curl -fsSL https://raw.githubusercontent.com/jonstump/dotfiles/main/bootstrap.sh | bash
```

`bootstrap.sh` installs chezmoi if it's missing (Homebrew on macOS,
`get.chezmoi.io` otherwise), runs `chezmoi init jonstump` to clone this repo
into `~/.local/share/chezmoi`, moves any pre-existing file chezmoi is about to
manage into `~/.dotfiles-backup`, and then runs `chezmoi apply`.

If you already have chezmoi and don't need the backup step, the one-liner
equivalent is:

```sh
chezmoi init --apply jonstump
```

Either way, that first `chezmoi apply` also runs the install scripts, so
expect a sudo prompt on Linux and a long Homebrew run on macOS.

### What the install scripts do

- **macOS**: installs Homebrew if it's missing, then `brew bundle` against
  `Brewfile`.
- **Debian/Ubuntu-family Linux (apt)**: adds the Signal apt repo (modern
  `signed-by` keyring, not the deprecated `apt-key`), installs everything in
  `apt-packages.txt`, installs `nvm`/`pyenv` via their own upstream installers
  since neither is a reliable apt package, and sets zsh as the login shell.
- **NixOS**: the package scripts render empty and are skipped — packages for
  NixOS machines are declared in a separate flake/home-manager repo, not here.

`oh-my-tmux` is not installed by a script; it's declared in
`.chezmoiexternal.toml` and cloned to `~/.local/share/tmux/oh-my-tmux` by
chezmoi itself on every OS.

## Day-to-day usage

Edit the source copy, not the file in `$HOME` — `chezmoi apply` overwrites
`$HOME` from the source state, so direct edits to e.g. `~/.zshrc` get blown
away on the next apply.

```sh
chezmoi edit ~/.zshrc      # edit the source file behind a target
chezmoi diff               # what would apply change?
chezmoi apply              # write the source state out to $HOME
chezmoi status             # short per-file summary
chezmoi cd                 # subshell in the source dir, for git work
chezmoi update             # git pull + apply, e.g. on another machine
```

`.zsh_aliases` defines short forms: `cz`, `czd`, `cza`, `cze`, `czs`, `czcd`.

To start tracking a file that isn't managed yet:

```sh
chezmoi add ~/.config/foo/bar    # copies it into the source dir, named foo/bar
chezmoi cd && git add . && git commit && git push
```

Committing and pushing is still plain git, just run from inside the source
directory (`chezmoi cd`, or `$DOTFILES`, which `.zshrc` exports).

Updates to installed tools are handled by [`topgrade`](https://github.com/topgrade-rs/topgrade)
rather than a dotfiles command — run `topgrade` directly.

## What's here

| Path | Purpose |
|---|---|
| `dot_zshrc`, `dot_zprofile`, `dot_zsh_aliases` | Shell config. OS-detected (`IS_MAC`/`IS_LINUX`) at runtime where Mac and Linux paths diverge — Homebrew-only lines are guarded so they're inert on Linux/NixOS. |
| `dot_config/nvim/` | [LazyVim](https://www.lazyvim.org/) — the starter template plus a `gruvbox` colorscheme override in `lua/plugins/colorscheme.lua`. |
| `dot_config/tmux/tmux.conf` | Points at [oh-my-tmux](https://github.com/gpakosz/.tmux) via `source-file ~/.local/share/tmux/oh-my-tmux/.tmux.conf`. |
| `dot_config/tmux/tmux.conf.local` | Local oh-my-tmux overrides. |
| `dot_config/kitty/` | Kitty terminal config, gruvbox colorscheme. |
| `dot_config/lf/lfrc` | [lf](https://github.com/gokcehan/lf) file manager config. |
| `.chezmoiscripts/` | Scripts chezmoi runs during `apply`. `run_onchange_*` re-runs when its content changes (the package manifests are digested into it); `run_once_*` runs once per machine. |
| `.chezmoiexternal.toml` | Third-party trees cloned into `$HOME` by chezmoi (oh-my-tmux). |
| `.chezmoiignore` | Repo-only files (`README.md`, `Brewfile`, `apt-packages.txt`, `bootstrap.sh`) that must not be written into `$HOME`. |
| `.chezmoiversion` | Minimum chezmoi version this source state needs. |
| `Brewfile` | macOS package manifest. |
| `apt-packages.txt` | Linux (apt) package manifest — a curated core set, not a full mirror of `Brewfile`; extend as needed per-distro. |
| `bootstrap.sh` | One-time installer for a brand new machine. |
| `dot_antigen.zsh` | Vendored copy of [antigen](https://github.com/zsh-users/antigen), used as the Linux zsh-plugin-manager fallback (macOS uses Homebrew's copy instead). |
| `.dots_archive/` | Retired scripts/configs kept for reference only. Ignored by chezmoi automatically — source-dir entries starting with `.` are never applied. |

## Shell auto-tmux behavior

Opening a new interactive terminal automatically attaches to a single shared
tmux session named `main` (creating it if it doesn't exist yet), instead of
spawning a new session per terminal window. See the `exec tmux new-session -A
-s main` line in `dot_zshrc`.

## Migrating an existing machine

Machines set up with the previous bare-repo-on-`$HOME` scheme have a bare repo
at `~/Repos/dotfiles` and a `config` alias. To switch one over:

```sh
# 1. Make sure nothing is uncommitted under the old scheme.
/usr/bin/git --git-dir="$HOME/Repos/dotfiles" --work-tree="$HOME" status

# 2. Point chezmoi at this repo and see what it would change.
chezmoi init jonstump
chezmoi diff

# 3. Apply, then retire the old bare repo.
chezmoi apply
mv "$HOME/Repos/dotfiles" "$HOME/Repos/dotfiles.bare.bak"
```

The old `config` alias is gone from `.zsh_aliases`, so it stops working once
the new `.zsh_aliases` is applied — that's intentional.
