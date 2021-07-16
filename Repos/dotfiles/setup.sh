#!/bin/bash

#Function for Linux setup
linux_setup() {
# Apt install

# Add Spotify Repository
  curl -sS https://download.spotify.com/debian/pubkey_0D811D58.gpg | sudo apt-key add -
  echo "deb http://repository.spotify.com stable non-free" | sudo tee /etc/apt/sources.list.d/spotify.list

# Add Signal Repositroy
  wget -O- https://updates.signal.org/desktop/apt/keys.asc | gpg --dearmor > signal-desktop-keyring.gpg
  cat signal-desktop-keyring.gpg | sudo tee -a /usr/share/keyrings/signal-desktop-keyring.gpg > /dev/null

  echo 'deb [arch=amd64 signed-by=/usr/share/keyrings/signal-desktop-keyring.gpg] https://updates.signal.org/desktop/apt xenial main' |\
  sudo tee -a /etc/apt/sources.list.d/signal-xenial.list

# Apt update and upgrade
  sudo apt update && upgrade

# apps to install via apt
  sudo apt install kitty zsh zsh-antigen neofetch neovim imagemagick code docker virtualbox spotify-client signal-desktop -y

  sudo apt clean

  #set shell to ZSH
  sudo chsh -s /bin/zsh

  #make directory for dotfiles and other repos

  mkdir Repos
  mkdir $HOME/Repos/dotfiles

  #clone git dotfiles repository
  git clone --bare https://github.com/jonstump/dotfiles.git $HOME/Repos/dotfiles

  #makes config alias for use of the script to setup dotfiles
  function config {
    /usr/bin/git --git-dir=$HOME/.config/ --work-tree=$HOME
  }

  #make a backup of already existing dotfiles
  mkdir -p .config-backup && \
    config checkout 2>&1 | egrep "\s+\." | awk {'print $1'} | \
    xargs -I{} mv {} .config-backup/{}

  #checkout content from bare git repository for dotfiles
  config checkout

  #set tracked files to no
  config config --local status.showUntrackedFiles no

  brew file install
}

#Function for MacOS setup
mac_setup() {
#Homebrew
  *create homebrew file*
}
#Install regardless of OSTYPE

/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# instructions to install basic brewfile regardless of linux or mac

if [[ "$OSTYPE" == "linux-gnu" ]];
then
  echo "Linux is your OS"
  linux_setup
  # Do setup for Linux
  else [[ "$OSTYPE" == "darwin" ]];
  echo "MacOS is your OS"
  # do setup for Mac
  mac_setup
fi


