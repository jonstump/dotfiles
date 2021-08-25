# installs ruby-install
wget -O ruby-install-0.8.2.tar.gz https://github.com/postmodern/ruby-install/archive/v0.8.2.tar.gz
tar -xzvf ruby-install-0.8.2.tar.gz
cd ruby-install-0.8.2/
sudo make install

#installs Chruby
wget -O chruby-0.3.9.tar.gz https://github.com/postmodern/chruby/archive/v0.3.9.tar.gz
tar -xzvf chruby-0.3.9.tar.gz
cd chruby-0.3.9/
sudo make install

#installs NVM
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.38.0/install.sh | bash

#make directory for dotfiles and other repos
mkdir Repos
mkdir $HOME/Repos/dotfiles

#clone git dotfiles repository
git clone --bare https://github.com/jonstump/dotfiles.git $HOME/Repos/dotfiles

# Note that this part might fail and has done so in the past. Need to investigate
#makes config alias for use of the script to setup dotfiles
alias config='/usr/bin/git --git-dir=$HOME/Repos/dotfiles --work-tree=$HOME'

config config --local status.showUntrackedFiles no

echo "alias config='/usr/bin/git --git-dir=$HOME/Repos/dotfiles --work-tree=$HOME'" >> $HOME/.bashrc

#checkout content from bare git repository for dotfiles
config checkout

#set tracked files to no
config config --local status.showUntrackedFiles no
