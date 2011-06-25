#!/bin/bash
cd $HOME
mkdir Scripts
cd Scripts
git clone git://github.com/mellort/vim-get.git
echo "alias vim-get=\"bash $HOME/Scripts/vim-get/vim-get.sh\"" >> $HOME/.bashrc
. ~/.bashrc # reload your bashrc
vim-get setup
echo "source ~/.vim/bundle/.listing" >> ~/.vimrc
