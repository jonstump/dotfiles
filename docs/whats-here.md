# What's here

Paths below are the **target** paths under `$HOME` — i.e. what you'd
`cat`/edit once applied. Their source lives under the matching chezmoi name
in `home/` (e.g. `~/.zshrc` is `home/executable_dot_zshrc`).

| Target path | Purpose |
|---|---|
| `.zshrc`, `.zprofile`, `.zsh_aliases` | Shell config. OS-detected (`IS_MAC`/`IS_LINUX`) where Mac and Linux paths diverge — Homebrew-only lines are guarded so they're inert on Linux, and use `$HOMEBREW_PREFIX` rather than assuming Apple Silicon. |
| `.gitconfig` | Wires up `git-delta` as the pager and includes `~/.gitconfig.local` for identity. |
| `.config/nvim/` | [LazyVim](https://www.lazyvim.org/) — the starter template plus a `gruvbox` colorscheme override in `lua/plugins/colorscheme.lua`. |
| `.config/tmux/tmux.conf` | Vendored [oh-my-tmux](https://github.com/gpakosz/.tmux) config (the upstream repo is also cloned to `~/.local/share/tmux/oh-my-tmux` as a chezmoi git-repo external). |
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

## Chezmoi file-naming

`dot_FOO` → `~/.FOO`; `dot_config/foo/bar` → `~/.config/foo/bar`;
`executable_dot_FOO` → `~/.FOO` with the executable bit set. Files do not
end in `.tmpl` — there are zero templates; cross-platform handling is done
with explicit shell `uname` guards.
