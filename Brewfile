tap "buo/cask-upgrade"
tap "charmbracelet/tap"

# Adopt casks whose app is already on disk but wasn't installed by Homebrew
# (e.g. dragged into /Applications by hand) instead of erroring out and
# aborting the whole bundle.
cask_args adopt: true
# GNU internationalization (i18n) and localization (l10n) library
brew "gettext"
# OpenType text shaping engine
brew "harfbuzz"
# Framework for layout and rendering of i18n text
brew "pango"
# Library to render SVG files using Cairo
brew "librsvg"
# Icons for the GNOME project
brew "adwaita-icon-theme"
# Cryptography and SSL/TLS Toolkit
brew "openssl@3"
# YAML Parser
brew "libyaml"
# Display directories as trees (with optional color/HTML output)
brew "tree"
# Automate deployment, configuration, and upgrading
brew "ansible"
# NOTE: `brew "antigen"` was removed (deprecated upstream, hard `disable!` on
# 2026-11-22, and one hard error aborts the entire bundle). The plugin stack
# now runs on antidote instead — see .zsh_plugins.txt. antidote is deliberately
# NOT a brew entry: it's pure zsh, and .zshrc/install.sh clone it so that one
# mechanism covers macOS and apt alike.
# Codec library for encoding and decoding AV1 video streams
brew "aom"
# Tool for generating GNU Standards-compliant Makefiles
brew "automake"
# B2 Cloud Storage Command-Line Tools
brew "b2-tools"
# Terminal bandwidth utilization tool
brew "bandwhich"
# Disk usage analyzer (was `brew "baobab"`, a GTK4 GNOME GUI app: it has arm64
# bottles so it installed, but there is no .app bundle, no Dock or Launchpad
# presence, and it renders through the GTK quartz backend.)
brew "ncdu"
# Bourne-Again SHell, a UNIX command interpreter
brew "bash"
# Clone of cat(1) with syntax highlighting and Git integration
brew "bat"
# Parser generator
brew "bison"
# GNU database manager
brew "gdbm"
# Interpreted, interactive, object-oriented programming language
# python@3.10 reaches upstream EOL ~Oct 2026; Homebrew tends to retire formulae
# for EOL Pythons shortly after, which would make this line start failing
# `brew bundle install`. That failure is already non-fatal (install_mac wraps
# it in a soft-fail guard), but bump to a supported version when it happens.
# (pyenv, not this formula, manages the Python versions you actually use.)
brew "python@3.10"
# Linux/OSX/FreeBSD resource monitor
brew "bpytop"
# Resource monitor. C++ version and continuation of bashtop and bpytop
brew "btop"
# Cross-platform make
brew "cmake"
# Console Matrix
brew "cmatrix"
# Container runtimes on MacOS (and Linux) with minimal setup
brew "colima"
# Libraries to talk to Microsoft SQL Server and Sybase databases
brew "freetds"
# Postgres C API library
brew "libpq"
# General-purpose scripting language
brew "php"
# Dependency Manager for PHP
brew "composer"
# GNU File, Shell, and Text utilities
brew "coreutils"
# Top-like interface for container metrics
brew "ctop"
# Open source programming language to build simple/reliable/efficient software
brew "go"
# Linux utility to get information on filesystems, like df but better
brew "dysk"
# Command-line EPUB reader
brew "epr"
# Like neofetch, but much faster because written mostly in C
brew "fastfetch"
# Simple, fast and user-friendly alternative to find
brew "fd"
# Command-line fuzzy finder written in Go
brew "fzf"
# GitHub command-line tool
brew "gh"
# Syntax-highlighting pager for git and diff output
brew "git-delta"
# Tcl/Tk UI for the git revision control system
brew "git-gui"
# Bootstrap GitHub SSH configuration
brew "github-keygen"
# Library for USB device access
brew "libusb"
# Package compiler and linker metadata toolkit
brew "pkgconf"
# Generate introspection data for GObject libraries
brew "gobject-introspection"
# Terminal based graphical activity monitor inspired by gtop and vtop
brew "gotop"
# Library access to GnuPG
brew "gpgme"
# Ping, but with a graph
brew "gping"
# Toolkit for creating graphical user interfaces
brew "gtk+3"
# Improved top (interactive process viewer)
brew "htop"
# Matrix client for Vim addicts
brew "iamb"
# ISO/IEC 23008-12:2017 HEIF file format decoder and encoder
brew "libheif"
# Tools and libraries to manipulate images in select formats
brew "imagemagick"
# Lightweight and flexible command-line JSON processor
brew "jq"
# Library for JSON, based on GLib
brew "json-glib"
# Fast, Dynamic Programming Language
brew "julia"
# Lazier way to manage everything docker
brew "lazydocker"
# Simple terminal UI for git commands
brew "lazygit"
# Terminal file manager
brew "lf"
# Portable Foreign Function Interface library
brew "libffi"
# Lynx-like WWW browser that supports tables, menus, etc.
brew "links"
# Next-gen compiler infrastructure
brew "llvm"
# Package manager for the Lua programming language
brew "luarocks"
# Mac App Store command-line interface
brew "mas"
# Small build system for use with gyp or CMake
brew "ninja"
# Fast and user friendly build system
brew "meson"
# Remote terminal application
brew "mosh"
# Lightweight PDF and XPS viewer
brew "mupdf"
# Ambitious Vim-fork focused on extensibility and agility
brew "neovim"
# Find/fix obsolete Nerd Font icons
brew "nerdfix"
# Single-player roguelike video game
brew "nethack"
# Port scanning utility for large networks
brew "nmap"
# Manage multiple Node.js versions
brew "nvm"
# Platform built on V8 to build network applications.
# Required by the `npm "..."` entries at the bottom of this file: brew bundle
# resolves npm via which("npm", ORIGINAL_PATHS), and nvm is a shell function
# that's invisible to it — so with nvm alone all twelve npm entries failed on a
# fresh machine. nvm still handles per-project versions once you `nvm use`.
brew "node"
# PDF rendering library (based on the xpdf-3.0 code base)
brew "poppler"
# Object-relational database system
brew "postgresql@17"
# A Zsh theme
# (.zshrc prefers this over the antidote-managed copy in .zsh_plugins.p10k.txt,
# so brew keeps the theme updated along with everything else.)
brew "powerlevel10k"
# Convert bitmaps to vector graphics
brew "potrace"
# Python version management
brew "pyenv"
# Perl-powered file rename script with many helpful built-ins
brew "rename"
# Search tool like grep and The Silver Searcher
brew "ripgrep"
# Safe, concurrent, practical language
brew "rust"
# Command-line interface for https://speedtest.net bandwidth tests
brew "speedtest-cli"
# Open source continuous file synchronization application
brew "syncthing"
# Feature-rich console based todo list manager
brew "task"
# Command-line tool to interact with Gitea servers
brew "tea"
# Tool to build, change, and version infrastructure
brew "terraform"
# Code-search similar to ack
brew "the_silver_searcher"
# Programmatically correct mistyped console commands
brew "thefuck"
# Simplified and community-driven man pages
brew "tlrc"
# Terminal multiplexer
brew "tmux"
# Upgrade all the things
brew "topgrade"
# Next generation frontend tooling. It's fast!
brew "vite"
# Extensible IRC client
brew "weechat"
# Internet file retriever
brew "wget"
# Tools for the WireGuard secure network tunnel
brew "wireguard-tools"
# Personal information dashboard for your terminal
brew "wtfutil"
# A powerful terminal-based AI assistant for developers, providing intelligent coding assistance directly in your terminal.
brew "charmbracelet/tap/crush", trusted: true
# Application launcher and productivity software
cask "alfred"
# Android SDK component
cask "android-platform-tools"
# E-books management software
cask "calibre"
# Anthropic's official Claude AI desktop app
cask "claude"
# Write, edit, and chat about your code with AI
cask "cursor"
# VPN client
cask "cyberghost-vpn"
# API documentation browser and code snippet manager
cask "dash"
# Voice and text chat software
cask "discord"
# Web browser
cask "firefox"
cask "font-mononoki-nerd-font"
# Desktop client for GitHub repositories
cask "github"
# Web browser
cask "google-chrome"
# Open-source video transcoder
cask "handbrake-app"
# Free and open-source media player
cask "iina"
# Vector graphics editor
cask "inkscape"
# Terminal emulator as alternative to Apple's Terminal app
cask "iterm2"
# Automatically ejects external drives
cask "jettison"
# Secure video conferencing app
cask "jitsi-meet"
# Menu bar manager
cask "jordanbaird-ice"
# GPU-based terminal emulator
cask "kitty"
# Free and open-source media player
cask "kodi"
# Cable-free audio router
cask "loopback"
# File system integration
# macFUSE ships a kernel extension that macOS requires you to approve manually
# in System Settings → Privacy & Security (then reboot) before it loads; on
# Apple Silicon some macOS versions additionally need Reduced Security mode
# from Recovery. `brew bundle` reports success either way, so FUSE tooling
# will silently not work until you approve it.
cask "macfuse"
# Desktop client for the Matrix protocol
cask "nheko"
# Knowledge base that works on top of a local folder of plain text Markdown files
cask "obsidian"
# Document editor
cask "onlyoffice"
# Collection of apps available by subscription
cask "setapp"
# Instant messaging application focusing on security
cask "signal"
# Customise mouse buttons, wheels and cursor speed
cask "steermouse"
# Customizable email client
cask "thunderbird"
# Open-source BitTorrent client
cask "transmission"
# Custom Discord App
cask "vesktop"
# Video communication and virtual meeting platform
cask "zoom"
cargo "cargo-update"
npm "@angular/cli"
npm "@feathersjs/cli"
npm "corepack"
npm "create-react-app"
npm "csv-parser"
npm "dpdm"
npm "fast-csv"
npm "neovim"
npm "npm-check-updates"
npm "slack-tui"
npm "typescript"
npm "yarn"
