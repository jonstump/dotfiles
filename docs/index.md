# dotfiles

Personal dotfiles for macOS, Debian/Ubuntu-family Linux (PikaOS, etc.), Arch
Linux, Fedora, openSUSE, and Bazzite. Managed with
[chezmoi](https://www.chezmoi.io/): this repo
is chezmoi's *source* directory, applied on top of `$HOME` rather than
symlinked or checked out directly onto it.

## Quickstart

**1. Bootstrap** — installs chezmoi itself, then has chezmoi clone this repo
as its source directory and apply it onto `$HOME`. Safe to run on a machine
that already has its own default `.zshrc`/`.zprofile`/etc.: anything that
would conflict with the apply is moved to `~/.dotfiles-backup` first instead
of being overwritten.

```sh
curl -fsSL https://raw.githubusercontent.com/jonstump/dotfiles/main/bootstrap.sh | bash
```

Only `curl` is required up front — the script installs git itself if it's
missing (day-to-day usage wants a real git, even though chezmoi
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

Per-distro install details: [macOS](install/macos.md) ·
[Debian/Ubuntu](install/debian-ubuntu.md) · [Arch](install/arch.md) ·
[Fedora](install/fedora.md) · [openSUSE](install/opensuse.md) ·
[Bazzite](install/bazzite.md)

## Documentation

- [Day-to-day usage](usage.md) — the `dotfiles` alias, common commands, updates
- [What's here](whats-here.md) — target paths under `$HOME` and their sources
- [Shell auto-tmux behavior](tmux.md) — the shared `main` session
- [Architecture](https://github.com/jonstump/dotfiles/blob/main/Architecture.md)
  — design rationale and decisions
