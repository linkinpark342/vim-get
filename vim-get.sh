#!/bin/bash
# This is a script to fetch and install vim addons

# See if user provided sufficient arguments (>3)
if [ $# -lt 2 ]
then
    echo "Usage: 'vim-get (install|remove|list|info|setup) (plugin|color) [names]'"
    exit
fi

echo "Starting up."

# determine whether or not to use wget
wget_installed=$(type -P wget &>/dev/null)




# define dirs
VIM_ROOT="$HOME/.vim"
BUNDLE_DIR="$VIM_ROOT/bundle"
BUNDLE_LISTING_FILE="$BUNDLE_DIR/.listing"
VIM_PLUGIN_DIR="$BUNDLE_DIR/plugins"
VIM_COLORS_DIR="$BUNDLE_DIR/colors"
VIM_PLUGIN_LISTING_DIR="$BUNDLE_DIR/.plugins-listing"
VIM_PLUGIN_LISTING_FILE="$VIM_PLUGIN_LISTING_DIR/.listing"
VIM_COLOR_LISTING_DIR="$BUNDLE_DIR/.colors-listing"

# make sure all necessary files and directories exist, otherwise create them
if [ ! -d "$BUNDLE_DIR" ]; then
	mkdir "$BUNDLE_DIR"
fi
if [ ! -d "$VIM_PLUGIN_DIR" ]; then
	mkdir "$VIM_PLUGIN_DIR"
fi
if [ ! -d "$VIM_COLORS_DIR" ]; then
	mkdir "$VIM_COLORS_DIR"
fi
if [ ! -d "$VIM_PLUGIN_LISTING_DIR" ]; then
	mkdir "$VIM_PLUGIN_LISTING_DIR" 
fi
if [ ! -d "$VIM_COLOR_LISTING_DIR" ]; then
	mkdir "$VIM_COLOR_LISTING_DIR" 
fi
if [ ! -f "$VIM_PLUGIN_LISTING_FILE" ]; then
	touch "$VIM_PLUGIN_LISTING_FILE" 
fi
if [ ! -f "$BUNDLE_LISTING_FILE" ]; then
	touch $BUNDLE_LISTING_FILE
	echo "set rtp^=$BUNDLE_DIR" > $BUNDLE_LISTING_FILE
	echo "source $VIM_PLUGIN_LISTING_FILE" >> $BUNDLE_LISTING_FILE
fi

download_addon() {
    ADDON_NAME=$1
    TEMP_FILE=$(mktemp)

    # sorry to lie about the user agent, i really don't wana but google just rejects wget
    USER_AGENT="Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.7) Gecko/20040613 Firefox/0.8.0+"

    # create the url with the first argument as the query
    URL="http://www.google.com/cse?cx=partner-pub-3005259998294962:bvyni59kjr1&ie=ISO-8859-1&sa=Search&siteurl=www.vim.org/scripts/index.php&q=$ADDON_NAME"

    # fetch the HTML for the google search result
    echo "Looking for plugin: $ADDON_NAME"
    if $wget_installed ; then
        wget --quiet -U "$USER_AGENT" -O $TEMP_FILE "$URL"
    else
        curl -S -U "$USER_AGENT" -o $TEMP_FILE "$URL"
    fi


    # use grep to find the first script url
    FIRST_RESULT=$(grep -o "http:\/\/www\.vim\.org\/scripts\/script\.php?script_id=[0-9]\+" $TEMP_FILE | head -1)

    # remove temp file
    rm $TEMP_FILE

    # if variable is unset, then no results found; exit
    if [ -z "$FIRST_RESULT" ]
    then
        echo "No results found."
        return
    fi

    echo "Found candidate."

    # go to script page of first result
    echo "Fetching plugin page."
    if $wget_installed ; then
        wget --quiet -U "$USER_AGENT" -O $TEMP_FILE "$FIRST_RESULT"
    else
        curl -S -U "$USER_AGENT" -o $TEMP_FILE "$FIRST_RESULT"
    fi

    # find the first download link (most recent version of plugin)
    echo "Grabbing download link."
    DOWNLOAD_URL="http://www.vim.org/scripts/$(grep -o "download_script\.php?src_id=[0-9]\+" $TEMP_FILE | head -1)"

    # grab file name from 'a href'
    FILE_NAME=$(grep -o "download_script\.php?src_id=[0-9]\+[^<]*" $TEMP_FILE | awk -F'>' '{print $2}' | head -1)
    # grab the script type from the html
    SCRIPT_TYPE=$(grep -A1 ">script type<" $TEMP_FILE | tail -1 | grep -o ">[^<>]\+<" | grep -o "[a-zA-Z ]*")

	# grab description, just first 2 sentences from webpage
	DESCRIPTION=$(grep -A1 ">description<" $TEMP_FILE | tail -1 |sed -e :a -e 's/<[^>]*>//g;/</N;//ba' | awk -F. 'BEGIN {OFS=""} {print $1,".", $2, "."}')

    # not the smartest way to do this
    SHORT_FILE_NAME=$(echo $FILE_NAME | sed 's/\(\.zip\|\.vba\|\.tar\|\.vba\.gz\|\.tar\.gz\)//g')


	# Create new file containing script info, modify
	# runtimepath if necessary
    if [[ $SCRIPT_TYPE == *color* ]]
    then
		echo $DESCRIPTION > $VIM_COLOR_LISTING_DIR/$SHORT_FILE_NAME
        grep -A5 "download_script\.php?src_id=[0-9]\+" $TEMP_FILE | head -6 | grep -o ">[^<>]\+<" | sed -e 's/[\<\>]//g' >> $VIM_COLOR_LISTING_DIR/$SHORT_FILE_NAME
    else
		echo $DESCRIPTION > $VIM_PLUGIN_LISTING_DIR/$SHORT_FILE_NAME
        grep -A5 "download_script\.php?src_id=[0-9]\+" $TEMP_FILE | head -6 | grep -o ">[^<>]\+<" | sed -e 's/[\<\>]//g' >> $VIM_PLUGIN_LISTING_DIR/$SHORT_FILE_NAME
		# need to modify the runtimepath to load new plugin dir
        echo "set rtp^=$VIM_PLUGIN_DIR/$SHORT_FILE_NAME" >> $VIM_PLUGIN_LISTING_FILE
    fi

    # rm temp file
    rm $TEMP_FILE

    # download
    echo "Downloading file: $FILE_NAME"
    if $wget_installed ; then
        wget --quiet -U "$USER_AGENT" -O $FILE_NAME "$DOWNLOAD_URL"
    else
        curl -S -U "$USER_AGENT" -o $FILE_NAME "$DOWNLOAD_URL"
    fi
}

# a function to install the addon
install_addon() {
    echo -e "\nBeginning installation of addon."

    # arg should not have '.vim', it will be added later
    ADDON_NAME=$1

    # download the addon
    FILE_NAME=""
    download_addon $ADDON_NAME
	## note that we get the global variable $SHORT_FILE_NAME here

    # file name is empty, so no file found; exit loop
    if [ -z "$FILE_NAME" ]; then
        return
    fi

	if [[ $SCRIPT_TYPE == *color* ]]
	then
		# currently only deal with color files which are just *.vim
		# not sure how to deal with color packages yet, wont be hard
		# just want to make sure we modify the listing files
		case $FILE_NAME in
			*.vim )
                echo "Copying color scheme to colors directory."
				cp $FILE_NAME $VIM_COLORS_DIR
				;;
			*.tar* )
				echo "not implemented yet"
				;;
			*.zip )
				echo "not implemented yet"
				;;
		esac
	else
		mkdir $VIM_PLUGIN_DIR/$SHORT_FILE_NAME
		case $FILE_NAME in
			*.vim )
                echo "Copying file to plugin directory."
                cp $FILE_NAME $VIM_PLUGIN_DIR/$SHORT_FILE_NAME
				;;
			*.tar* )
		 		echo "Unpacking and adding to plugin directory."
            	CURRENT_DIR=$(pwd)
            	cd $VIM_PLUGIN_DIR
				mkdir $SHORT_FILE_NAME
				cd $SHORT_FILE_NAME
            	tar xvf "$CURRENT_DIR/$FILE_NAME"
            	cd "$CURRENT_DIR"
            	;;
			*.zip )
            	echo "Unpacking and adding to plugin directory."
            	CURRENT_DIR=$(pwd)
	    		cd $VIM_PLUGIN_DIR/$SHORT_FILE_NAME
            	unzip "$CURRENT_DIR/$FILE_NAME"
            	cd "$CURRENT_DIR"
            	;;
			*.vba )
            	echo "Unpacking and adding to plugin directory."
            	vim -c "let g:vimball_home=\"$VIM_PLUGIN_DIR/$SHORT_FILE_NAME\"" -c "source %" -c "q" "$FILE_NAME"
            	# If there is a vba.gz, vim removes the gz, so change the file
            	# name accordingly so it can be deleted
            	FILE_NAME=$(echo "$FILE_NAME" | sed 's/vba\.gz$/vba/g')
				;;
		esac

	fi

    rm "$FILE_NAME"
}

# a function to remove an addon
remove_addon() {
    echo -e "\nBeginning removal of addon."

	ADDON_TYPE=$1 # color | plugin
    ADDON_NAME=$2 # name

	if [[ "$ADDON_TYPE" == "color" ]]
	then
		rm $VIM_COLORS_DIR/$ADDON_NAME.vim
	else
		rm -rf $VIM_PLUGIN_DIR/$ADDON_NAME
		sed -i '/$ADDON_NAME\$/d' $VIM_PLUGIN_LISTING_FILE
	fi

	echo -e "\nRemoval comleted."
}

list_addons() {
	ADDON_TYPE=$1

	if [[ "$ADDON_TYPE" == "plugin" ]]
	then
		echo "Plugin listing:"
		echo "================="
		ls -1 $VIM_PLUGIN_LISTING_DIR
		echo "================="
	else 
		echo "Color listing:"
		echo "================="
		ls -1 $VIM_COLOR_LISTING_DIR
		echo "================="
	fi
}

addon_info() {
	ADDON_TYPE=$1
	ADDON_NAME=$2

	if [[ "$ADDON_TYPE" == "plugin" ]]
	then
		cat $VIM_PLUGIN_LISTING_DIR/$ADDON_NAME
	else 
		cat $VIM_COLOR_LISTING_DIR/$ADDON_NAME
	fi
}

# This is the main logic. The first argument is the command, which can either
# be 'install' or 'remove'. The arguments are stored by bash in the variable
# $@. We use the command 'shift' to shift all of the arguments back an index,
# thus 'discarding' the first argument. The rest of the args are presumably
# addon names, which will be looped through.
case $1 in
    install )
        # shift args over
        shift
		shift

        # for each addon name, install it
        for var in "$@"
        do
            install_addon $var
        done
        ;;
    remove )
        # shift args over
        shift
		ADDON_TYPE=$1
	    shift

        # for each addon name, install it
        for var in "$@"
        do
            remove_addon $ADDON_TYPE $var
        done
        ;;
	list )
		shift
		list_addons $1
		;;
	info )
		shift
		addon_info $1 $2
		;;
	setup )
		echo "Setup comlete"
		;;
    * )
        echo "Unrecognized command."
        ;;
esac

echo -e "\nFinished, exiting."
