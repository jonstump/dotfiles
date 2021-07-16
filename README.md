# Jon Stump's dotfiles
#### By: Jon Stump

* * *

## Description

These are my dotfiles for multiple apps. Currently working on an isntall script as well.

* * *

## App

* Kitty
* Ranger
* Neovim
* neofetch
* zathura
* zshrc

* * *

## To Add:

* [ ] git dotfiles
* [ ] VSCode/Codium
* [ ] spicetify
* [ ] Document ZSH setup installs
  * [ ] theme
  * [ ] plugins with antigen
  * [ ] nvm
  * [ ] chruby

## WIP

Current state of setup script:
It does recognize what OS you are running and is able to install repositories for signal and spotify, update apt repositories, auto install brew, and auto install apt applications.

Once it is done it fails on the brew file install because my dotfiles have not been downloaded. Therefore it doesn't know how to reference brew since it's not in the bashrc.
Need to investigate the better of the two options, having the script add those to the bashrc before it gets to the zsh setup or do zsh setup first and then do the brew file.

* * *

## Contact Information
_Jon Stump: [Email](jmstump@gmail.com)_
