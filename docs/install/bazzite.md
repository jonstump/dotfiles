# Bazzite (atomic, uBlue/Fedora-derived)

Detected via `ID=bazzite` in `/etc/os-release` and treated as its own
target, not plain Fedora. The root fs is read-only (rpm-ostree layering
requires a reboot and is discouraged), so the toolset installs via Homebrew
— the image provisions Linuxbrew at first boot, and the shared `Brewfile`
is used as-is (cask/mas entries are ignored on Linux). Bazzite maintains its
own brew updates via systemd timers. `chsh` is deliberately skipped
(Bazzite's docs warn it can break session login); set zsh in the terminal
emulator profile instead.
