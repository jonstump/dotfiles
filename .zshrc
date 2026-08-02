# Sources
#source $HOME/.antigen.zsh
#source antigen with brew
source /opt/homebrew/share/antigen/antigen.zsh
source $HOME/.zsh_aliases
source $HOME/.zprofile

# Exports
export PATH=/opt/homebrew/bin:$PATH
# export KUBECONFIG=/Users/jonathanstump/kubeconfig

# allows for terraform to be accessed globally
# export PATH=$HOME/terraform/:$PATH
# export TERM=kitty-term

# for item in $(ls -1 ${HOME}/.profile.d/*.plugin.zsh); do
  # [ -e "${item}" ] && source "${item}"
# done
#Nix for Mac
if [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then
  . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
fi

#NVM for Mac with homebrew
export NVM_DIR="$HOME/.nvm"
  [ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && . "/opt/homebrew/opt/nvm/nvm.sh"  # This loads nvm
  [ -s "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm" ] && . "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm"  # This loads nvm bash_completion

# export for postgres
# export PGDATA="/usr/local/var/postgres/12/"
# export PGHOST="/tmp"
eval "$(rbenv init - zsh)"

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

antigen theme romkatv/powerlevel10k

antigen apply

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

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

#check to see if in a tmux session, if not run one
if command -v tmux &> /dev/null && [ -n "$PS1" ] && [[ ! "$TERM" =~ screen ]] && [[ ! "$TERM" =~ tmux ]] && [ -z "$TMUX" ]; then
  exec tmux
fi

# Neofetch to liven up the terminal on launch
export PATH="/opt/homebrew/opt/postgresql@12/bin:$PATH"
eval "$(pyenv init -)"

test -e "${HOME}/.iterm2_shell_integration.zsh" && source "${HOME}/.iterm2_shell_integration.zsh"

export PATH="$HOME/.local/bin:$PATH"
