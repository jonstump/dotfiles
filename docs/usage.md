# Day-to-day usage

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

## Machine-local overrides

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
