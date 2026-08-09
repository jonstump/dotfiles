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

📖 Full documentation: [dotfiles site](https://jonstump.github.io/dotfiles/) —
per-distro install notes, day-to-day usage, what's-here, and tmux behavior.
Design rationale lives in [`Architecture.md`](Architecture.md).

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
missing (chezmoi day-to-day usage wants a real git, even though chezmoi
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


`install.sh` is safe to re-run; every step checks whether its target already
exists before doing anything.

Per-distro details (macOS, Debian/Ubuntu, Arch, Fedora, openSUSE, Bazzite):
see the [docs site](https://jonstump.github.io/dotfiles/).
