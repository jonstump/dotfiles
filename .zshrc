# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
# if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
#   source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
# fi

# zshrc setup
#
# This setup primarily uses antigen and brew
#
# Sources
source $HOME/.antigen.zsh
source ~/.zsh_aliases
source /home/linuxbrew/.linuxbrew/opt/chruby/share/chruby/chruby.sh
source /home/linuxbrew/.linuxbrew/opt/chruby/share/chruby/auto.sh
source $HOME/.zprofile

# Exports
export NVM_DIR="$HOME/.nvm"
  [ -s "/home/linuxbrew/.linuxbrew/opt/nvm/nvm.sh" ] && . "/home/linuxbrew/.linuxbrew/opt/nvm/nvm.sh"  # This loads nvm
  [ -s "/home/linuxbrew/.linuxbrew/opt/nvm/etc/bash_completion.d/nvm" ] && . "/home/linuxbrew/.linuxbrew/opt/nvm/etc/bash_completion.d/nvm"  # This loads nvm bash_completion

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
neofetch
