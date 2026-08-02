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

- **macOS**: installs Homebrew if it's missing, then `brew bundle --file="$SCRIPT_DIR/Brewfile"`
  (i.e. the `Brewfile` next to `install.sh`).
  - Mac App Store apps are **not** included. `mas` can only install titles
    already associated with the signed-in Apple ID, so on a fresh machine
    every entry fails. Sign in to the App Store, then run
    `brew bundle --file=Brewfile.mas` by hand.
  - `cask "macfuse"` installs a kernel extension. On Apple Silicon that needs
    a trip through Recovery to enable Reduced Security with *"Allow user
    management of kernel extensions"*, plus two reboots — the one step here
    that isn't unattended.
- **Debian/Ubuntu-family Linux (apt)**: adds the Signal apt repo on amd64
  (modern `signed-by` keyring in `/etc/apt/keyrings`, not the deprecated
  `apt-key`), installs everything in `apt-packages.txt`, and installs
  `neovim`/`nvm`/`pyenv`/`topgrade`/`lazygit`/`oh-my-tmux` via their own
  upstream installers since none of those are reliable apt packages
  (`topgrade` comes from PyPI via `pipx install topgrade`, using the `pipx`
  that apt already installed). Unavailable packages are reported and skipped
  rather than failing the install.
  - GUI apps live in `apt-packages-desktop.txt` and are only installed when a
    display environment is detected. Force it either way with
    `DOTFILES_DESKTOP=1` / `DOTFILES_DESKTOP=0`.
  - Your login shell is switched to zsh only if a zsh outside the Nix store is
    listed in `/etc/shells`; otherwise it says so and moves on.
- **NixOS / nix-darwin / Nix on any other host**: skips package installation
  entirely — packages for those machines are declared in a separate
  flake/home-manager repo, not here. Only sets up the non-package pieces
  (`oh-my-tmux`). On nix-darwin the Brewfile is *not* applied automatically;
  run `brew bundle --file=Brewfile` by hand if you also want the casks.

`install.sh` is safe to re-run; every step checks whether its target already
exists before doing anything.

### Machine-local overrides

Three files are sourced if present and are deliberately **not** tracked, so
each machine can differ without dirtying `config status`:

| File | For |
|---|---|
| `~/.gitconfig.local` | git identity (`[user] name`/`email`) |
| `~/.zsh_aliases.local` | aliases with machine specifics — NAS addresses, uids, mount points |
| `~/.zshrc.local` | anything else shell-local |

`~/.gitconfig.local` is the one you need on a fresh box: without it,
`config commit` fails with *"Please tell me who you are"*.

### Sharing a machine with Nix

The rule is **one writer per path**:

| Concern | Owner |
|---|---|
| `~/.zshrc`, `~/.zprofile`, `~/.zsh_aliases`, `~/.config/{nvim,tmux,kitty,lf}` | **This repo**, on all three platforms |
| Package sets (`Brewfile`, `apt-packages.txt`, `home.packages`) | Per-platform: this repo for mac/apt, the flake repo for nix |
| System config (login shell, fonts, services) | Platform-native (`users.users.<you>.shell` in the flake, `chsh` on apt) |

So in the flake repo, deliberately **don't** set `programs.zsh.enable = true`
— install zsh and its plugins as packages and let this repo's `.zshrc` stay
authoritative. Both systems writing `~/.zshrc` collides in both directions:
`home-manager switch` refuses to activate over a tracked file (or with
`-b backup` quietly renames it, so `config status` reports it deleted), while
`config checkout` will happily replace HM's read-only store symlink with a
regular file that the next switch then reverts.

When home-manager needs to inject something into the shell, have it write a
separate file instead. `.zshrc` sources this near the end if it exists:

```sh
~/.config/zsh/nix-env.zsh
```

That keeps the seam explicit rather than having two systems fight over one
file.

## Day-to-day usage

This repo is checked out directly on top of `$HOME` via a bare repo at
`~/Repos/dotfiles`, using the `config` alias defined in `.zsh_aliases`:

```sh
alias config='command git --git-dir=$DOTFILES/ --work-tree=$HOME'
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
rather than a dotfiles alias — run `topgrade` directly. It comes from the
Brewfile on macOS; on Linux `install.sh` installs it with `pipx`, since it
isn't packaged for Debian/Ubuntu.

## What's here

| Path | Purpose |
|---|---|
| `.zshrc`, `.zprofile`, `.zsh_aliases` | Shell config. OS-detected (`IS_MAC`/`IS_LINUX`) where Mac and Linux paths diverge — Homebrew-only lines are guarded so they're inert on Linux/NixOS, and use `$HOMEBREW_PREFIX` rather than assuming Apple Silicon. |
| `.gitconfig` | Wires up `git-delta` as the pager and includes `~/.gitconfig.local` for identity. |
| `.config/nvim/` | [LazyVim](https://www.lazyvim.org/) — the starter template plus a `gruvbox` colorscheme override in `lua/plugins/colorscheme.lua`. |
| `.config/tmux/tmux.conf` | Points at [oh-my-tmux](https://github.com/gpakosz/.tmux) via `source-file ~/.local/share/tmux/oh-my-tmux/.tmux.conf` (cloned there by `install.sh`). |
| `.config/tmux/tmux.conf.local` | Local oh-my-tmux overrides. |
| `.config/kitty/` | Kitty terminal config, gruvbox colorscheme. |
| `.config/lf/lfrc` | [lf](https://github.com/gokcehan/lf) file manager config. |
| `Brewfile` | macOS package manifest (`brew bundle --file=Brewfile`). |
| `Brewfile.mas` | Mac App Store entries, split out — run by hand after signing in to the App Store. |
| `apt-packages.txt` | Linux (apt) package manifest — a curated core set, not a full mirror of `Brewfile`; extend as needed per-distro. |
| `apt-packages-desktop.txt` | Linux (apt) GUI/desktop packages, installed only when a display environment is detected. |
| `bootstrap.sh` | One-time bare-repo checkout for a brand new machine. |
| `install.sh` | OS-detecting package/tool installer, run after `bootstrap.sh`. |
| `.antigen.zsh` | Vendored copy of [antigen](https://github.com/zsh-users/antigen), used as the Linux zsh-plugin-manager fallback (macOS uses Homebrew's copy instead). |
| `.dots_archive/` | Retired scripts/configs kept for reference only — not part of the active install path. |

## Shell auto-tmux behavior

Opening a new interactive terminal automatically attaches to a single shared
tmux session named `main` (creating it if it doesn't exist yet), instead of
spawning a new session per terminal window. See the `tmux new-session -A -s
main` block at the **end** of `.zshrc`.

It has to stay last in the file: that shell becomes the tmux *server* on the
first terminal, so anything set after it never reaches the server's
environment — including the `~/.local/bin` entry that `tmux.conf.local` needs
to find `lazy-tmux`.

Opt out with either of:

```sh
NO_AUTO_TMUX=1     # set in your environment
```

It's also skipped automatically in VS Code/Cursor integrated terminals, where
auto-tmux breaks shell integration. If tmux fails to start, you're left at a
normal shell rather than a closed window.
