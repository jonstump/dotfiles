# Architecture

Design record for this dotfiles repo. **Update this file whenever a decision
changes** — it is the home for *why* the code looks the way it does; the code
itself and `home/AGENTS.md` (the working brief) are deliberately separate.

Read `home/AGENTS.md` for how to work in this repo. Read this for why past
decisions were made and which trade-offs are load-bearing.

Last updated: 2026-08-09

## Components

| Component | Location | Role |
|---|---|---|
| chezmoi source tree | `home/` (`.chezmoiroot`) | Source of truth for everything applied to `$HOME`; no templates, zero `.tmpl` files |
| Shell config | `home/executable_dot_zshrc` (+ `.zprofile`, `.zsh_aliases`) | Orchestrator; sourcing chain ends with the auto-tmux attach |
| tmux | `home/dot_config/tmux/` | Vendored upstream oh-my-tmux conf + `tmux.conf.local` overrides |
| zsh plugins | `home/dot_zsh_plugins*.txt` | antidote-load bundle lists (theme deliberately separate) |
| Installer | `install.sh` (+ `bootstrap.sh`) | OS-detecting package/tool installer; entrypoint guarded behind a `BASH_SOURCE` check so helpers are sourceable |
| CLI/tool clones | `home/.chezmoiexternal.toml` | oh-my-tmux and antidote managed as chezmoi git-repo externals |
| Package manifests | `*-packages.txt`, `Brewfile` | Per-package-manager install lists (`apt`/`pacman`/`dnf`/`zypper` + macOS Brewfile + Bazzite's Brewfile) |
| Agent session guards | `home/dot_claude/` | Claude Code hooks preventing edits to applied targets and dirty-tree session ends |
| Secret scanning | `.githooks/`, `.gitleaks.toml`, CI | gitleaks on staged diff (pre-commit hook) + full history (CI) |
| Quality gates | `Makefile`, `test/`, `.github/workflows/check.yml` | `make lint` / `make test` / `make check`, run identically in CI |

## Decisions

| # | Decision | Rationale |
|---|---|---|
| 1 | **Zero templates** — no `.tmpl` files; all cross-platform handling via explicit shell `uname` guards (`IS_MAC`/`IS_LINUX`) | chezmoi templates add a layer of indirection that's hard to grep/audit in a public repo; explicit shell guards are visible at the point of use and keep every file a valid plain sh/zsh file |
| 2 | **`merge.conflictstyle = diff3`, not `zdiff3`** (#58) | apt-installed git on Debian 11 / Ubuntu 20.04 / 22.04 is < 2.35, which can't parse `zdiff3` and dies on the first conflicted merge; `diff3` shows all three sides (ours/base/theirs) on every supported version |
| 3 | **Auto-tmux block must be the last thing in `.zshrc`** | `tmux ... && exit` replaces the process, and that process forks the tmux *server* on the first terminal — anything after it never reaches the server's environment. `&& exit` (not `exec tmux`) so a failed server start leaves a shell to show the error |
| 4 | **`bat`/`fd` aliases written as `if` blocks** | zsh cannot parse `a && ! b && alias …` ("parse error near `\n`"); the `if` form is the only parseable way to conditionally alias |
| 5 | **Bazzite is its own `$PM` (`bazzite`), not plain Fedora** | Atomic/immutable root fs (`/run/ostree-booted`, read-only) means `dnf install` would fail; detection gates on `ID=bazzite`/`VARIANT_ID=silverblue\|kinoite` or the ostree marker *before* the dnf branch, and the toolset installs via the image's Linuxbrew + shared Brewfile instead of a manifest, skipping `chsh` (Bazzite warns it can break session login) |
| 6 | **antidote self-healing clone** | `.zshrc` clones to `~/.antidote` if the external hasn't run yet (pre-`install.sh` shells on a fresh bootstrap); chezmoi applies it as a git-repo external at apply time. Keeps the very next terminal after `bootstrap.sh` from coming up bare |
| 7 | **oh-my-tmux/antidote as chezmoi git-repo externals** (#117) | Replaces ~100 lines of hand-rolled git-clone logic in `install.sh` (existence checks, broken-clone recovery) with chezmoi-native management; `refreshPeriod` bounds re-pulls; contents are delegated to git by design |
| 8 | **lazy-tmux restore gated on `has-session`** | lazy-tmux refuses to restore into an existing session (silent no-op) and older binaries falsely report failure due to a window-0 focus bug; gating + ignoring exit status means restore only happens at creation and can never wedge a session |
| 9 | **`~/.local/bin` on PATH before tmux exec** | The tmux server inherits the first terminal's environment; PATH must include `~/.local/bin` before `.zshrc` execs into tmux or `run-shell`/`display-popup -E` can't resolve `lazy-tmux` |
| 10 | **gitleaks pre-commit + CI** (#115) | Public repo with untracked-by-design local identity; the hook scans the staged diff, CI scans full history so a `--no-verify` commit is still caught before merge; hook degrades to skip-with-warning when gitleaks isn't installed |
| 11 | **nvim `example.lua` kept as dead code** | Upstream LazyVim boilerplate guarded by `if true then return {} end` + `stylua: ignore`; exists only as documentation and references config that is **not** enabled — don't treat its contents as user config |
| 12 | **install.sh entrypoint behind a `BASH_SOURCE` guard** (#118) | Lets bats source the helper functions (`detect_os`, `pm_has_candidate`, `read_manifest`, …) without executing the installer — the hook that makes `make test` possible |
| 13 | **no `cd` / PATH imports in shell startup, PATH dedup via `typeset -U path`** (#146) | Every tmux pane re-sources `.zshrc`; unconditional re-prepends with no dedup made PATH grow linearly. `typeset -U path` drops duplicates automatically, first occurrence wins |

## Open questions

- **`topgrade` update path**: the README says updates are handled by `topgrade`
  run by hand; there is no timer/managed schedule. #125 proposes a shared
  update path for both an interactive command and a timer — worth deciding
  whether topgrade stays manual.
- **Per-distro install docs**: the README's per-distro bullets are accurate but
  each new distro makes it longer. #136 proposes moving them to a docs site
  (this is tracked separately from this file).
- **`fakeroot`/`cmake` in `pacman-packages.txt`**: kept in the manifest but not
  exercised by any install.sh source build (see #148); they're listed as
  "general tools" pending a real requirement.
