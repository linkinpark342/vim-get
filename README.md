Summary
---------------
A small script to handle installing and deleting vim addons.

Example uses
---------------
    $ vim-get install color molokai
    $ vim-get remove color zenburn
    $ vim-get install plugin NERD_commenter

Install
----------
    $ cd $HOME
    $ mkdir Scripts
    $ cd Scripts
    $ git clone git://github.com/mellort/vim-get.git
    $ echo "alias vim-get=\"bash $HOME/Scripts/vim-get/vim-get.sh\"" >> $HOME/.bashrc
	$ . ~/.bashrc # reload your bashrc
    $ vim-get setup
    $ echo "source ~/.vim/bundle/.listing" >> ~/.vimrc


Advanced Configuration
-----------------------
Near the top of the file, there are some directory definitions; these
can be changed to suit your configuration.

More technical info
----------------------
The program will create this structure in your .vim folder:

    .vim/
    	bundle/
    		.listing
    		plugins/
    		colors/
    		.plugins-listing/
    			.listing
    		.colors-listing/
	
The bundle directory essentially contains everything. The .listing file inside contains
modifications to vim's runtimepath so that you can store plugins inside their own directories 
in the plugins/ folder. The .plugins-listing and .colors-listing files contain information about 
the version of the color/plugin you downloaded, as well as author and description information. There 
is an extra .listing file in the .plugins-listing directory which contains runtimepath modifications for each plugin in the plugin/ directory. The .listing file inside bundle sources the one in the plugin listing folder.



