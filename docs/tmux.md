# Shell auto-tmux behavior

Opening a new interactive terminal automatically attaches to a single shared
tmux session named `main` (creating it if it doesn't exist yet), instead of
spawning a new session per terminal window. See the `tmux new-session -A -s
main` block at the **end** of `.zshrc`.

On a fresh server (no `main` yet), the first terminal first runs
`lazy-tmux bootstrap -session main`, so a previously saved `main` (windows,
panes, scrollback via the daemon and `<prefix> C-s`) is restored instead of
starting blank. Restoring into an already-running session is a lazy-tmux
no-op, so this only happens when `main` is first created; a missing or old
`lazy-tmux`, or a restore failure, falls back to a plain empty session.
`tmux.conf.local` also bootstraps on server start when no `main` session
exists yet (covers servers started outside `.zshrc` that don't create `main`
themselves, e.g. a bare `tmux start-server`); a server spawned directly as
`main` skips it since the session already exists — use an `ExecStartPre`
bootstrap in a systemd unit for that case.

It has to stay last in the file: that shell becomes the tmux *server* on the
first terminal, so anything set after it never reaches the server's
environment — including the `~/.local/bin` entry that `tmux.conf.local` needs
to find `lazy-tmux`.

## Opting out

```sh
NO_AUTO_TMUX=1     # set in your environment
```

It's also skipped automatically in VS Code/Cursor integrated terminals, where
auto-tmux breaks shell integration. If tmux fails to start, you're left at a
normal shell rather than a closed window.
