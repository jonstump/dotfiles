#!/bin/bash

#Install regardless of OSTYPE


if [[ "$OSTYPE" == "linux-gnu" ]];
then
  echo "Linux is your OS"
  # Do setup for Linux
  else [[ "$OSTYPE" == "darwin" ]];
  echo "MacOS is your OS"
  # do setup for Mac
fi

linux_setup() {
# install dot files:

#Homebrew
  curl and install brew via their script. &&
# Apt update and upgrade
  sudo apt update && upgrade &&
# Apt install
  sudo apt install &&
    # apps to install via apt
    kitty &&
    zsh &&
    zsh-antigen &&
    neofetch &&
    neovim &&
    imagemagick &&
    code &&
}

mac_setup() {
#Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" &&
  Brew install using brewfile
  <commands>
}
