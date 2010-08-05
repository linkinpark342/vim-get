#!/bin/bash
# This is a script to fetch and install vim addons

# See if user provided sufficient arguments (>1)
if [ $# -lt 1 ]
then
    echo "Usage: 'vim-get (install|remove) [addon names]'"
    exit
fi

echo "Starting up."


# determine whether or not to use wget
wget_installed=$(type -P wget &>/dev/null)

# define dirs
VIM_PLUGIN_DIR="$HOME/.vim/plugin/"
VIM_COLORS_DIR="$HOME/.vim/colors/"
VIM_DIR="$HOME/.vim"

# Function for downloading an addon given the name
download_addon() {
    # arg should not have '.vim', it will be added later
    ADDON_NAME=$1

    # make a temp file for use storing
    TEMP_FILE=$(mktemp)

    # sorry to lie about the user agent, i really don't wana but google just rejects wget
    USER_AGENT="Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.7) Gecko/20040613 Firefox/0.8.0+"

    # create the url with the first argument as the query
    URL="http://www.google.com/cse?cx=partner-pub-3005259998294962:bvyni59kjr1&ie=ISO-8859-1&sa=Search&siteurl=www.vim.org/scripts/index.php&q=$ADDON_NAME"
    #URL="http://www.google.com/cse?sa=Search&siteurl=www.vim.org/scripts/index.php&q=$1"

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

    # file name is empty, so no file found; exit loop
    if [ -z "$FILE_NAME" ]; then
        return
    fi

    # do different actions based on file type
    case $FILE_NAME in
        *.vim )
            # check to see if the script type we got earlier 
            # was  a color file. if so, then copy to the 
            # color directory
            if [[ $SCRIPT_TYPE == *color* ]]
            then
                echo "Copying color scheme to colors directory."
                cp $FILE_NAME $VIM_COLORS_DIR
            else
                echo "Copying file to plugin directory."
                cp $FILE_NAME $VIM_PLUGIN_DIR
            fi
            ;;
        *.tar* )
            echo "Unpacking and adding to plugin directory."
            CURRENT_DIR=$(pwd)
            cd "$VIM_DIR"
            tar xvf "$CURRENT_DIR/$FILE_NAME"
            cd "$CURRENT_DIR"
            ;;
        *.tar.gz )
            echo "Unpacking and adding to plugin directory."
            CURRENT_DIR=$(pwd)
            cd "$VIM_DIR"
            tar xvzf "$CURRENT_DIR/$FILE_NAME"
            cd "$CURRENT_DIR"
            ;;
        *.vba* )
            echo "Unpacking and adding to plugin directory."
            vim -c "source %" -c "q" "$FILE_NAME"
            # If there is a vba.gz, vim removes the gz, so change the file
            # name accordingly so it can be deleted
            FILE_NAME=$(echo "$FILE_NAME" | sed 's/vba\.gz$/vba/g')
            ;;
        *.zip )
            echo "Unpacking and adding to plugin directory."
            CURRENT_DIR=$(pwd)
            cd "$VIM_DIR"
            unzip "$CURRENT_DIR/$FILE_NAME"
            cd "$CURRENT_DIR"
            ;;
    esac

    rm "$FILE_NAME"
}

# a function to remove an addon
remove_addon() {
    echo -e "\nBeginning removal of addon."

    # arg should not have '.vim' etc, it will be added later
    ADDON_NAME=$1

    # download the addon
    FILE_NAME=""
    download_addon $ADDON_NAME

    # file name is empty, so no file found; exit loop
    if [ -z "$FILE_NAME" ]; then
        return
    fi

    # do different actions based on file type
    case $FILE_NAME in
        *.vim )
            # check to see if the script type we got earlier 
            # was  a color file. if so, remove it from the
            # color directory
            if [[ $SCRIPT_TYPE == *color* ]]
            then
                echo "Deleting addon from colors directory."
                # combine dir and file name, removing double slashes
                FILE_PATH=$(echo "$VIM_COLORS_DIR/$FILE_NAME" | sed "s#//#/#g")
                rm $FILE_PATH
            else
                echo "Deleting addon from plugin directory."
                # combine dir and file name, removing double slashes
                FILE_PATH=$(echo "$VIM_PLUGIN_DIR/$FILE_NAME" | sed "s#//#/#g")
                rm $FILE_PATH
            fi
            ;;
        * )
            echo "Deleting that filetype is not supported yet."
            ;;
    esac

    rm "$FILE_NAME"
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

        # for each addon name, install it
        for var in "$@"
        do
            install_addon $var
        done
        ;;
    remove )
        # shift args over
        shift

        # for each addon name, install it
        for var in "$@"
        do
            remove_addon $var
        done
        ;;
    * )
        echo "Unrecognized command."
        ;;
esac

echo -e "\nFinished, exiting."
