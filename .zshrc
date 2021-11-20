# Sources
#source $HOME/.antigen.zsh
#source antigen with brew
source /opt/homebrew/share/antigen/antigen.zsh
source $HOME/.zsh_aliases
source $HOME/.zprofile

#Standard Linux install
source /usr/local/share/chruby/chruby.sh
source /usr/local/share/chruby/auto.sh

#Mac Hombrew
# source /opt/homebrew/opt/chruby/share/chruby/auto.sh
# source /opt/homebrew/opt/chruby/share/chruby/chruby.sh

# Exports
export PATH=/opt/homebrew/bin:$PATH

# allows for terraform to be accessed globally
# export PATH=$HOME/terraform/:$PATH
# export TERM=kitty-term

#NVM for standlard linux
#export NVM_DIR="$HOME/.nvm"
#[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
#[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# for item in $(ls -1 ${HOME}/.profile.d/*.plugin.zsh); do
  # [ -e "${item}" ] && source "${item}"
# done

#NVM for Mac with homebrew
export NVM_DIR="$HOME/.nvm"
  [ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && . "/opt/homebrew/opt/nvm/nvm.sh"  # This loads nvm
  [ -s "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm" ] && . "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm"  # This loads nvm bash_completion

# export for postgres
export PGDATA="/usr/local/var/postgres/12/"
export PGHOST="/tmp"
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
  export EDITOR='nvim'
else
  export EDITOR='vi'
fi

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# Neofetch to liven up the terminal on launch
# neofetch
export PATH="/opt/homebrew/opt/postgresql@12/bin:$PATH"
eval "$(pyenv init -)"
