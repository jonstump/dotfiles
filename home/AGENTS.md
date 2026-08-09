# AGENTS.md

Dotfiles repo managed by [chezmoi](https://www.chezmoi.io/). The source of truth
is this directory; chezmoi applies it to `$HOME` on macOS and Linux targets.

Design rationale (decisions, trade-offs, open questions) lives in
[`Architecture.md`](../Architecture.md) at the repo root — consult it when a
"why" is needed; update it when a decision changes. This file is the working
brief: what to know mid-session.

## Chezmoi file-naming

- `dot_FOO` → `~/.FOO`; `dot_config/foo/bar` → `~/.config/foo/bar`.
- `executable_dot_FOO` → `~/.FOO` **with the executable bit set** — needed for
  source-able shell files (chezmoi loses the mode otherwise, and a non-executable
  file breaks nothing for sourcing, but the bit matters for installed scripts).
- Files do **not** end in `.tmpl`; there are zero templates. All cross-platform
  handling is done with explicit shell `uname` guards (`IS_MAC`/`IS_LINUX` set in
  `executable_dot_zshrc`, used by `.zsh_aliases`), not chezmoi `onchange`/template
  conditionals.
- Everything is versioned with the default source directory as a git repo
  (public). Secrets/machine-specific values must **never** be added here.

## What is owned where (shell sourcing chain)

- `executable_dot_zshrc` is the orchestrator and the most heavily-commented file;
  read it before changing shell behavior. Sourcing order:
  1. `~/.zprofile` only if not a login shell (login shells already source it;
     unconditional sourcing double-runs `pyenv init` and `thefuck --alias` —
     why: Architecture.md decisions).
  2. `~/.zsh_aliases` (after `IS_MAC`/`IS_LINUX` are set, so aliases can guard
     per-OS).
  3. NVM, powerlevel10k, then antidote plugin loading (bundle lists below).
  4. `~/.zshrc.local` — untracked, machine-specific.
  7. **Last thing in the file**: auto-attach to tmux session `main`
     (`tmux new-session -A -s main && exit`). This must stay last: `exec`
     replaces the process, and that process forks the tmux *server*, so anything
     after it never reaches the server environment. `&& exit` instead of
     `exec tmux` so a failed server start leaves a shell to show the error.
     Before attaching, if `main` does not exist yet (fresh server), it runs
     `lazy-tmux bootstrap -session main` (ignoring failures) so a saved `main`
     is restored; restoring into an existing session is a lazy-tmux no-op and
     is skipped via `has-session`. `tmux.conf.local` also gates a bootstrap
     restore on server start with the same `has-session` check (only covers
     server starts where the spawning command does not itself create `main`).
     Opt-outs: `NO_AUTO_TMUX=1`, `TERM_PROGRAM=vscode`.

- `executable_dot_zsh_aliases`: OS-specific aliases guarded by `IS_MAC`/`IS_LINUX`
  (e.g. `integrated`/`nvidia`/`vpn` are Linux-only, brew/pyenv alias is Mac-only).
  Machine-specific aliases belong in untracked `~/.zsh_aliases.local`, sourced at
  the bottom. The bat/fd aliases are written as `if` blocks — don't
  "simplify" them (why: Architecture.md decisions).

## zsh plugins: antidote

- Plugin list: `dot_zsh_plugins.txt` (loads via `antidote load`), theme is
  deliberately **not** there — see `dot_zsh_plugins.p10k.txt`, a fallback loaded
  only when no natively packaged powerlevel10k is found (Homebrew first, then
  the Linux package managers' powerlevel10k or the fallback file).
- Edits to the bundles file regenerate the static cache on the next new shell;
  use `antidote update` to update plugins (OMZ's own updater is disabled via
  `zstyle ':omz:update' mode disabled`).
- `use-omz` (deferred compinit) must come first; syntax-highlighting and
  autosuggestions must stay last in that order (documented in the file).
- antidote itself: chezmoi git-repo external (`~/.antidote`); `.zshrc` prefers
  a packaged copy (Homebrew prefix) and self-heals by cloning pre-apply
  (why: Architecture.md decisions).

## tmux

- `dot_config/tmux/tmux.conf` is an unchanged upstream **Oh my tmux!** file —
  header says DO NOT MODIFY, and edits are impossible to maintain against
  upgrades. All customization lives in `tmux.conf.local` (sourced via
  `TMUX_CONF_LOCAL` bootstrap in the main file).
- `tmux.conf.local`: stock Oh-my-tmux override variables, plus two TPM plugins
  via `@plugin` (note: `set -g @plugin` with tpm-style plugins relies on
  Oh-my-tmux's plugin-update mechanism, `tmux_conf_update_plugins_on_launch=true`).
  Custom theme is the default palette with `tmux_conf_theme_*` variables;
  `tmux-powerkit` themed gruvbox/dark.
- The main file's relay section relies on env vars `TMUX_PROGRAM`/`TMUX_SOCKET`,
  and run-shell hooks can invoke tools from `~/.local/bin`. Local customization
  exists that references a `lazy-tmux` helper — behavior must be verified on a
  live session; comments in `.zshrc` explain why PATH must be set before the
  tmux exec (server env inherits it).
- `lazy-tmux` is a third-party helper installed manually (`~/.local/bin`, not
  via the package manifests). Its `bootstrap`/`restore` need the `main` session
  to NOT exist (restore into an existing session is a silent no-op), and older
  binaries (pre-mid-2026) falsely report restore failure due to a window-0
  focus bug — both are handled by gating the bootstrap on `has-session` and
  ignoring its exit status; the first terminal in `.zshrc` and the `run-shell`
  line in `tmux.conf.local` both follow this pattern.

## nvim (LazyVim starter)

- Standard LazyVim layout: `init.lua` → `require("config.lazy")`; `lua/config/`
  (lazy, options, keymaps, autocmds) and `lua/plugins/` (auto-imported specs).
- `lua/plugins/colorscheme.lua` is the only real customization so far: adds
  gruvbox.nvim and sets it as the colorscheme. `example.lua` is upstream
  boilerplate and is dead code guarded by `if true then return {} end` (with
  `stylua: ignore`) — it exists only as documentation. Don't treat its contents
  as user config (it references pyright/tsserver/telescope opts that are **not**
  actually enabled).
- `lazy-lock.json` pins plugin commits; `lazyvim.json`/`dot_neoconf.json`
  (`→ ~/.config/nvim/.neoconf.json`) manage LazyVim meta.
- Formatting: `stylua.toml` = spaces, 2-space indent, 120 col. Mason is set to
  auto-install stylua, shellcheck, shfmt, flake8 (that also lives in the example
  file, so verify before relying on it).

## kitty

- `kitty.conf` is the default with `# vim:...foldmethod=marker` regions, and a
  handful of active settings: font `mononoki Nerd Font Mono` at 18pt,
  `tab_bar_style powerline`, `macos_option_as_alt yes`,
  `macos_quit_when_last_window_closed yes`, and `include gruvbox.conf` on
  line ~1314 — that include is the switcher. `gruvbox.conf`/`nord.conf` are
  simple color-palette overrides; to switch theme, edit the include line, no
  other references exist.

## lf

- `dot_config/lf/lfrc`: minimal. `set preview/hidden/drawbox/icons`. The custom
  `cmd open` is the interesting bit — it resolves symlinks, opens text/* with
  `$EDITOR` (nvim) and everything else with `$OPENER` (set by `.zshrc` to `open`
  on macOS, `xdg-open` on Linux). The `setsid -f` branch is Linux-only (util-linux;
  macOS `open` detaches on its own — historically every non-text open silently
  failed on macOS here). Loop variable was renamed to avoid shadowing lf's `$f`.

## git

- `dot_gitconfig` → `~/.gitconfig`: **identity is deliberately not tracked** —
  it's a public repo. `[include] path = ~/.gitconfig.local` for `[user]`; without
  that file, commits fail with "Please tell me who you are". Delta is the pager
  and interactive diffFilter; `merge.conflictstyle = diff3`, not `zdiff3` (why:
  Architecture.md decisions); init default branch
  main; `pull.ff = only`. Note `gitconfig.local` and `zshrc.local` are both
  untracked-by-design local escape hatches — never add identical config here.

## Cross-cutting conventions

- **Heavily commented**: the shell files read like design docs (many comments
  explain *why* a previous bug happened and *why* the fix is the way it is).
  Preserve this style; the comments are load-bearing context for the next agent.
- All `uname`/PATH guards exist because the same repo must work on macOS and
  multiple Linux families (apt `bat`→`batcat`, `fd`→`fdfind`; Arch/Fedora/
  openSUSE keep the standard names). Any new install step must handle all of
  them.
- Linux packages live in per-package-manager manifests (`apt-packages.txt`,
  `pacman-packages.txt`, `dnf-packages.txt`, `zypper-packages.txt`), selected
  in `install.sh` by `$PM` (`apt`/`pacman`/`dnf`/`zypper`). Any new install
  step that needs a package must add it to each manifest with the correct
  name for that manager (names often differ — e.g. openSUSE uses `fd`,
  `ImageMagick`, `libopenssl-devel`, `sqlite3-devel`).
- Bazzite is a separate `$PM` (`bazzite`) detected via `ID=bazzite` in
  `/etc/os-release` before the dnf check; it installs via the shared Brewfile
  (Linuxbrew) instead of a manifest, and skips `chsh`.
- `$HOME/.local/bin` is on PATH in `.zshrc` and used by Debian symlink fixes and
  custom helpers (e.g. `lazy-tmux`).
- Style: 2-space indentation and 120-col line length in Lua (stylua); shell files
  use 2-space indent, `[[ ... ]]` tests, `command -v x >/dev/null 2>&1` guards,
  and `$(...)` over backticks. Emoji/unicode glyphs are used in tmux status
  config deliberately — don't strip them.
