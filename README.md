# dotfiles

Personal dotfiles for macOS, Debian/Ubuntu-family Linux (PikaOS, etc.), Arch
Linux, Fedora, openSUSE, and Bazzite. Managed with
[chezmoi](https://www.chezmoi.io/): this repo
is chezmoi's *source* directory, applied on top of `$HOME` rather than
symlinked or checked out directly onto it.

The chezmoi source state lives under `home/` (see `.chezmoiroot`) so that
non-dotfile assets — `Brewfile`, package manifests, `install.sh`, this
README — can sit at the repo root without chezmoi trying to deploy them into
`$HOME` too. File names under `home/` use chezmoi's naming attributes
(`dot_zshrc` → `~/.zshrc`, `executable_dot_zsh_aliases` → `~/.zsh_aliases`,
etc.) — see [chezmoi's source state docs](https://www.chezmoi.io/reference/source-state-attributes/)
if a name under `home/` looks unfamiliar.

## Install on a new machine

**1. Bootstrap** — installs chezmoi itself, then has chezmoi clone this repo
as its source directory and apply it onto `$HOME`. Safe to run on a machine
that already has its own default `.zshrc`/`.zprofile`/etc.: anything that
would conflict with the apply is moved to `~/.dotfiles-backup` first instead
of being overwritten.

```sh
curl -fsSL https://raw.githubusercontent.com/jonstump/dotfiles/main/bootstrap.sh | bash
```

Only `curl` is required up front — the script installs git itself if it's
missing (chezmoi day-to-day usage below wants a real git, even though chezmoi
can clone without one). On macOS that means kicking off the Xcode Command
Line Tools install (git ships with them); accept the dialog, let it finish,
then re-run the same command. On Linux it installs git via
`apt-get`/`dnf`/`pacman`/`zypper`.
chezmoi itself is installed via its official install script into
`~/.local/bin`, on both platforms — no brew/apt package needed.

**2. Install tooling** — open a new shell, then run the OS-detecting
installer that was just applied:

```sh
$(chezmoi source-path)/../install.sh
```

- **macOS**: installs Homebrew if it's missing, then checks
  `brew bundle --file="$SCRIPT_DIR/Brewfile"` (i.e. the `Brewfile` next to
  `install.sh`) against what's already installed and installs only what's
  missing, with `HOMEBREW_NO_AUTO_UPDATE=1` and `--no-upgrade` — it never
  upgrades already-installed formulae/casks or triggers a `brew update` tap
  refresh. On an already-set-up machine it's a no-op; run `topgrade` by hand
  when you want upgrades.
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
  `neovim`/`nvm`/`pyenv`/`topgrade`/`lazygit`/`oh-my-tmux`/`antidote` via their
  own upstream installers since none of those are reliable apt packages
  (`topgrade` comes from PyPI via `pipx install topgrade`, using the `pipx`
  that apt already installed). Unavailable packages are reported and skipped
  rather than failing the install.
  - `zsh` itself is apt-installed when available, but on a derivative distro
    whose `sources.list` doesn't carry it (seen on PikaOS), it's built from
    the upstream release tarball instead — `build-essential` and
    `libncursesw5-dev` from `apt-packages.txt` are the only extra
    dependencies it needs, and the resulting `/usr/local/bin/zsh` is added to
    `/etc/shells` so `chsh` (below) still picks it up.
  - GUI apps live in `apt-packages-desktop.txt` and are only installed when a
    display environment is detected. Force it either way with
    `DOTFILES_DESKTOP=1` / `DOTFILES_DESKTOP=0`.
  - Your login shell is switched to zsh only if it's listed in `/etc/shells`;
    otherwise it says so and moves on.
- **Arch Linux (pacman)**: installs everything in `pacman-packages.txt`
  (official repo only — AUR packages are not installed by `install.sh`).
  `neovim`/`nvm`/`pyenv`/`topgrade`/`lazygit`/`oh-my-tmux`/`antidote` come from
  their upstream installers (same as apt), and `zsh` is pacman-installed (it
  isn't missing from Arch's repo). GUI apps live in
  `pacman-packages-desktop.txt` (same `want_desktop_packages` gate). Signal is
  an AUR package, so it isn't installed at all on Arch — install it yourself.
- **Fedora (dnf)**: installs everything in `dnf-packages.txt`, and
  `neovim`/`nvm`/`pyenv`/`topgrade`/`lazygit`/`oh-my-tmux`/`antidote` come from
  their upstream installers. `zsh` is dnf-installed. GUI apps live in
  `dnf-packages-desktop.txt`. Signal needs an external Copr repo that
  `install.sh` doesn't add — install it yourself.
- **openSUSE (zypper)**: installs everything in `zypper-packages.txt` (Leap
  and Tumbleweed share one path; package names verified against the OSS
  repos — `fd`, `the_silver_searcher`, `git-delta`, `ImageMagick`,
  `libopenssl-devel`, `libbz2-devel`, `sqlite3-devel`, `xmlsec1-devel`, etc.).
  `topgrade` is packaged, `neovim`/`nvm`/`pyenv`/`lazygit`/`oh-my-tmux`/
  `antidote` come from their upstream installers, and `zsh` is zypper-installed.
  GUI apps live in `zypper-packages-desktop.txt`. Signal isn't in the official
  repos — install via its network repo or Flatpak yourself.
- **Bazzite (atomic, uBlue/Fedora-derived)**: detected via `ID=bazzite` in
  `/etc/os-release` and treated as its own target, not plain Fedora. The root
  fs is read-only (rpm-ostree layering requires a reboot and is discouraged),
  so the toolset installs via Homebrew — the image provisions Linuxbrew at
  first boot, and the shared `Brewfile` is used as-is (cask/mas entries are
  ignored on Linux). Bazzite maintains its own brew updates via systemd
  timers. `chsh` is deliberately skipped (Bazzite's docs warn it can break
  session login); set zsh in the terminal emulator profile instead.

`install.sh` is safe to re-run; every step checks whether its target already
exists before doing anything.

### Machine-local overrides

Three files are sourced if present and are deliberately **not** tracked, so
each machine can differ without chezmoi ever seeing them — they aren't part
of the source state, so `chezmoi apply`/`chezmoi diff` never touch them:

| File | For |
|---|---|
| `~/.gitconfig.local` | git identity (`[user] name`/`email`) |
| `~/.zsh_aliases.local` | aliases with machine specifics — NAS addresses, uids, mount points |
| `~/.zshrc.local` | anything else shell-local |

`~/.gitconfig.local` is the one you need on a fresh box: without it,
`git commit` fails with *"Please tell me who you are"*.

## Day-to-day usage

This repo is chezmoi's source directory, cloned by `bootstrap.sh` to
chezmoi's default location (`~/.local/share/chezmoi`, unless
`$CHEZMOI_SOURCE_DIR` says otherwise). The `dotfiles` alias defined in
`.zsh_aliases` is just a shorter name for the `chezmoi` binary:

```sh
alias dotfiles='chezmoi'
```

Common commands, run from anywhere (chezmoi always knows where its source
directory is):

```sh
dotfiles diff                    # see what `apply` would change
dotfiles apply                   # apply the source state to $HOME
dotfiles edit ~/.zshrc           # edit the source file for a target, by target path
dotfiles cd                      # cd into the source directory (i.e. this repo) to edit/commit/push directly
dotfiles add ~/.config/foo/bar   # start tracking a new file — adds it under home/ with the right dot_/executable_ name
dotfiles re-add                  # pull local edits to a target back into the source state
```

Unlike the old bare-repo `config status`, chezmoi never scans `$HOME` for
untracked files at all — it only ever looks at the exact paths declared
under `home/` in this repo, so there's no untracked-file noise to filter and
no equivalent of `config add -A` to avoid.

Updates to installed tools are handled by [`topgrade`](https://github.com/topgrade-rs/topgrade)
rather than a dotfiles alias — run `topgrade` directly. It comes from the
Brewfile on macOS; on Linux `install.sh` installs it via the package manager
when available (Fedora/Arch package it, Debian/Ubuntu largely don't), falling
back to `pipx` on Debian/Ubuntu.

## What's here

Paths below are the **target** paths under `$HOME` — i.e. what you'd
`cat`/edit once applied. Their source lives under the matching chezmoi name
in `home/` (e.g. `~/.zshrc` is `home/executable_dot_zshrc`).

| Target path | Purpose |
|---|---|
| `.zshrc`, `.zprofile`, `.zsh_aliases` | Shell config. OS-detected (`IS_MAC`/`IS_LINUX`) where Mac and Linux paths diverge — Homebrew-only lines are guarded so they're inert on Linux, and use `$HOMEBREW_PREFIX` rather than assuming Apple Silicon. |
| `.gitconfig` | Wires up `git-delta` as the pager and includes `~/.gitconfig.local` for identity. |
| `.config/nvim/` | [LazyVim](https://www.lazyvim.org/) — the starter template plus a `gruvbox` colorscheme override in `lua/plugins/colorscheme.lua`. |
| `.config/tmux/tmux.conf` | Points at [oh-my-tmux](https://github.com/gpakosz/.tmux) via `source-file ~/.local/share/tmux/oh-my-tmux/.tmux.conf` (cloned there by `install.sh`). |
| `.config/tmux/tmux.conf.local` | Local oh-my-tmux overrides. |
| `.config/kitty/` | Kitty terminal config, gruvbox colorscheme. |
| `.config/lf/lfrc` | [lf](https://github.com/gokcehan/lf) file manager config. |
| `.zsh_plugins.txt` | zsh plugin bundles, loaded by [antidote](https://github.com/mattmc3/antidote). Edit and open a new shell — the static cache under `~/.cache/antidote/` rebuilds itself; run `antidote update` to update the plugins. |
| `.zsh_plugins.p10k.txt` | Fallback powerlevel10k, used only where no native package provides it (i.e. Debian/Ubuntu). |
The rest of the repo lives outside `home/` (see `.chezmoiroot`), so chezmoi
never deploys it into `$HOME` — these are read from the repo root, one level
above `chezmoi source-path` (which `.chezmoiroot` points at `home/`), not
from `home/` itself:

| Path | Purpose |
|---|---|
| `.chezmoiroot` | Points chezmoi's source state at `home/`, so everything below can share this repo without being deployed to `$HOME`. |
| `Brewfile` | macOS package manifest (`brew bundle --file=Brewfile`). |
| `Brewfile.mas` | Mac App Store entries, split out — run by hand after signing in to the App Store. |
| `apt-packages.txt` | Linux (apt) package manifest — a curated core set, not a full mirror of `Brewfile`; extend as needed per-distro. |
| `pacman-packages.txt` | Linux (Arch/pacman) package manifest — official repo only, no AUR packages. |
| `dnf-packages.txt` | Linux (Fedora/dnf) package manifest — curated core set, verify with `dnf search` per distro. |
| `zypper-packages.txt` | Linux (openSUSE/zypper) package manifest — Leap and Tumbleweed share one path; verify with `zypper search` per release. |
| `apt-packages-desktop.txt` | Linux (apt) GUI/desktop packages, installed only when a display environment is detected. |
| `pacman-packages-desktop.txt` | Linux (Arch) GUI/desktop packages, same display gate. |
| `dnf-packages-desktop.txt` | Linux (Fedora) GUI/desktop packages, same display gate. |
| `zypper-packages-desktop.txt` | Linux (openSUSE) GUI/desktop packages, same display gate. |
| `apt-flatpak-overrides.txt` | Maps an apt package to a Flatpak application ID; `install.sh` skips apt-installing a package if its mapped Flatpak is already present. Add a line to avoid double-installing an app you manage via Flatpak. |
| `bootstrap.sh` | One-time chezmoi install + init/apply for a brand new machine. |
| `install.sh` | OS-detecting package/tool installer, run after `bootstrap.sh`. |
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
