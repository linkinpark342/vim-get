#!/bin/bash
# This is a script to fetch and install vim addons
#
# Here's how the script works:
#   1. search for the plugin using the vim/google search
#   2. scrape the results and get the first script link
#   3. get the most recent dl link from the script page
#   4. download the file
#   5. unpack according to file type

# See if user provided an argument
if [ $# -lt 1 ]
then
    echo "Usage: 'vim-plugin-install \$PLUGIN_NAME'"
    exit
fi

echo "Starting up."


# determine whether or not to use wget
wget_installed=$(type -P wget &>/dev/null)

# define dirs
VIM_PLUGIN_DIR="$HOME/.vim/plugin/"
VIM_COLORS_DIR="$HOME/.vim/colors/"
VIM_DIR="$HOME/.vim"

# a function to install the plugin
install_plugin() {
    echo -e "\nBeginning installation of addon."

    # arg should not have '.vim', it will be added later
    PLUGIN_NAME=$1
    TEMP_FILE=$(mktemp)

    # sorry to lie about the user agent, i really don't wana but google just rejects wget
    USER_AGENT="Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.7) Gecko/20040613 Firefox/0.8.0+"

    # create the url with the first argument as the query
    URL="http://www.google.com/cse?cx=partner-pub-3005259998294962:bvyni59kjr1&ie=ISO-8859-1&sa=Search&siteurl=www.vim.org/scripts/index.php&q=$PLUGIN_NAME"
    #URL="http://www.google.com/cse?sa=Search&siteurl=www.vim.org/scripts/index.php&q=$1"

    # fetch the HTML for the google search result
    echo "Looking for plugin: $PLUGIN_NAME"
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

    echo $FILE_NAME

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


# for each plugin name, install it
for var in "$@"
do
    install_plugin $var
done

echo -e "\nFinished, exiting."
