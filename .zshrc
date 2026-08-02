# Sources
source $HOME/.zsh_aliases
source $HOME/.zprofile

case "$(uname -s)" in
  Darwin) IS_MAC=1 ;;
  Linux)  IS_LINUX=1 ;;
esac

# Antigen: Homebrew's copy on Mac, vendored copy on Linux (apt doesn't ship
# antigen at a consistent path across distros)
if [ -n "$IS_MAC" ] && [ -s /opt/homebrew/share/antigen/antigen.zsh ]; then
  source /opt/homebrew/share/antigen/antigen.zsh
elif [ -s "$HOME/.antigen.zsh" ]; then
  source "$HOME/.antigen.zsh"
fi

# allows for terraform to be accessed globally
# export PATH=$HOME/terraform/:$PATH

# Nix. Deliberately after the .zprofile source above (which runs
# `brew shellenv`): on macOS 14+ that goes through path_helper, which rebuilds
# PATH from /etc/paths first and demotes every /nix entry behind /usr/bin and
# Homebrew. Re-establishing the Nix profile here puts it back in front.
#
# The upstream profile script exports __ETC_PROFILE_NIX_SOURCED and returns
# early when it's set — and the installers also write the same snippet into
# /etc/zshrc, which zsh reads immediately before ~/.zshrc. So the guard is
# always set by the time we get here, and this block did nothing at all until
# the guard was cleared first.
#
# Not needed on NixOS: there PATH/NIX_PROFILES come from /etc/set-environment
# via environment.profiles, not from this file (which the standalone installers
# create). Skipped inside nix-shell/nix develop so it can't stomp on that PATH.
if [ ! -e /etc/NIXOS ] && [ -z "${IN_NIX_SHELL:-}" ]; then
  for _nix_sh in \
    /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh \
    "$HOME/.nix-profile/etc/profile.d/nix.sh"
  do
    if [ -e "$_nix_sh" ]; then
      unset __ETC_PROFILE_NIX_SOURCED
      . "$_nix_sh"
      break
    fi
  done
  unset _nix_sh
fi

# Standalone home-manager writes its session variables here and expects the
# shell to source them. This repo owns .zshrc and doesn't use programs.zsh, so
# nothing else does — without this, home.sessionVariables/sessionPath are
# silently dropped.
if [ -e "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh" ]; then
  . "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh"
fi

# NVM (nvm's own installer puts this in ~/.nvm on both Mac and Linux)
export NVM_DIR="$HOME/.nvm"
if [ -s "$NVM_DIR/nvm.sh" ]; then
  . "$NVM_DIR/nvm.sh"
  [ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"
elif [ -n "$IS_MAC" ] && [ -s "/opt/homebrew/opt/nvm/nvm.sh" ]; then
  . "/opt/homebrew/opt/nvm/nvm.sh"
  [ -s "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm" ] && . "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm"
fi

# powerlevel10k. The upstream theme ships a prebuilt gitstatusd that's
# dynamically linked against /lib64/ld-linux-x86-64.so.2 — which NixOS doesn't
# have, so it fails to exec and p10k silently falls back to a much slower
# pure-zsh git backend. nixpkgs patches the theme to point at
# ${gitstatus}/bin/gitstatusd, so prefer that copy when the flake/home-manager
# repo has installed it, and let antigen handle it everywhere else.
_p10k_theme=""
for _candidate in \
  /run/current-system/sw/share/zsh-powerlevel10k/powerlevel10k.zsh-theme \
  "$HOME/.nix-profile/share/zsh-powerlevel10k/powerlevel10k.zsh-theme"
do
  if [ -e "$_candidate" ]; then
    _p10k_theme="$_candidate"
    break
  fi
done
unset _candidate

if command -v antigen >/dev/null 2>&1; then
## Antigen ##
# Load oh-my-zsh via antigen
antigen use oh-my-zsh

# antigen plugin bundles
antigen bundles <<EOBUNDLES
  # Common aliases for terminal
  common-aliases

  # jump between directories
  z

  # Guess what to install when running an unknown command.
  command-not-found

  # Syntax highlighter for zsh.
  zsh-users/zsh-syntax-highlighting

  # Ruby plugin
  ruby

  # Chruby plugin
  chruby

  # Gem plugin for ruby
  gem

  # add color to man pages
  colored-man-pages

  # autosuggestions for commands
  zsh-users/zsh-autosuggestions

  # completions for zsh
  zsh-users/zsh-completions

EOBUNDLES

[ -n "$_p10k_theme" ] || antigen theme romkatv/powerlevel10k

antigen apply
fi

if [ -n "$_p10k_theme" ]; then
  source "$_p10k_theme"
fi
unset _p10k_theme

#Custom Variables
DOTFILES="$HOME/Repos/dotfiles"

# export MANPATH="/usr/local/man:$MANPATH"

# Preferred editor for local and remote sessions
if [[ -n $SSH_CONNECTION ]]; then
  export EDITOR=nvim
else
  export EDITOR=vim
fi

export EDITOR=nvim

# Used by .config/lf/lfrc to hand off non-text files to the OS's opener
if [ -n "$IS_MAC" ]; then
  export OPENER=open
elif [ -n "$IS_LINUX" ]; then
  export OPENER=xdg-open
fi

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

if [ -n "$IS_MAC" ]; then
  export PATH="/opt/homebrew/opt/postgresql@12/bin:$PATH"
fi

command -v pyenv >/dev/null 2>&1 && eval "$(pyenv init -)"

test -e "${HOME}/.iterm2_shell_integration.zsh" && source "${HOME}/.iterm2_shell_integration.zsh"

export PATH="$HOME/.local/bin:$PATH"

# Attach to (or create) a single shared "main" tmux session instead of
# spawning a new session for every terminal window.
#
# This has to stay the LAST thing in the file. `exec` replaces the process, and
# that process forks the tmux *server* on the first terminal — so anything set
# after it never reaches the server's environment. Panes are fine (they re-run
# .zshrc with $TMUX set), but the server is what runs `run-shell` and
# `display-popup -E`, and tmux.conf.local calls `lazy-tmux` from ~/.local/bin
# in both. Running it above the PATH lines meant the server could never resolve
# it.
#
# `tmux ... && exit` rather than `exec tmux`: if the server can't start (stale
# socket, unwritable /tmp, resource limits) exec would already have replaced
# the shell, so the window just dies with no shell left to show the error.
#
# NO_AUTO_TMUX=1 opts out; so does an editor-integrated terminal, where
# auto-tmux breaks VS Code/Cursor shell integration.
if [[ -o interactive ]] && [[ -z "$TMUX" ]] && [[ -z "${NO_AUTO_TMUX:-}" ]] \
   && [[ "${TERM_PROGRAM:-}" != "vscode" ]] \
   && [[ ! "$TERM" =~ (screen|tmux|dumb) ]] \
   && command -v tmux >/dev/null 2>&1; then
  tmux new-session -A -s main && exit
fi
