# macOS

Installs Homebrew if it's missing, then checks
`brew bundle --file="$SCRIPT_DIR/Brewfile"` (i.e. the `Brewfile` next to
`install.sh`) against what's already installed and installs only what's
missing, with `HOMEBREW_NO_AUTO_UPDATE=1` and
`--no-upgrade`/`--no-lock` — it never upgrades already-installed
formulae/casks and never writes `Brewfile.lock.json` into the repo, and it
triggers no `brew update` tap refresh. On an already-set-up machine it's a
no-op; run `topgrade` by hand
when you want upgrades.

- Mac App Store apps are **not** included. `mas` can only install titles
  already associated with the signed-in Apple ID, so on a fresh machine
  every entry fails. Sign in to the App Store, then run
  `brew bundle --file=Brewfile.mas --no-lock` by hand.
- `cask "macfuse"` installs a kernel extension. On Apple Silicon that needs
  a trip through Recovery to enable Reduced Security with *"Allow user
  management of kernel extensions"*, plus two reboots — the one step here
  that isn't unattended.
