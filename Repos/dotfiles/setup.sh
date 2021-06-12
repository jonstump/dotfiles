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
#Homebrew
  curl and install brew via their script. &&
    sudo apt install &&
    # apps to install via apt
    &&
    &&
    &&
    &&
    &&
    &&
    &&
  <commands>
}

mac_setup() {
#Homebrew
  curl and install brew via their script.
  <commands>
}
