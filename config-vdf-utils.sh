#!/usr/bin/env bash


# Generate string of [[:space:]] to represent indentation in VDF file, useful for searching
function generateVdfIndentString {
    spacetype="${2:-\t}"  # Type of space, expected values could be '\t' (for writing) or '[[:space:]]' (for searching)

    printf "%.0s${spacetype}" $(seq 1 "$1")
}


# Attempt to get the indentation level of the first occurance of a given VDF block
function guessVdfIndent {
    block_name="$( safequoteVdfBlockName "$1" )"  # Block to check the indentation level on
    vdf="$2"

    grep "${block_name}" "$vdf" | awk '{print gsub(/\t/,"")}'
}


# Surround a VDF block name with quotes if it doesn't have any
function safequoteVdfBlockName {
    quoted_blockname="$1"
    if ! [[ $quoted_blockname == \"* ]]; then
        quoted_blockname="\"$quoted_blockname\""
    fi

    echo "$quoted_blockname"
}


# Use sed to grab a section of a given VDF file based on its indentation level
function getVdfSection {
    start_pattern="$( safequoteVdfBlockName "$1" )"
    end_pattern="${2:-\}}"  # Default end pattern to end of block
    indent="$3"
    vdf="$4"

    if [ -z "$indent" ]; then
        indent="$(( $( guessVdfIndent "$start_pattern" "$vdf" ) ))"
    fi

    indent_str="$( generateVdfIndentString "$indent" "[[:space:]]" )"
    indented_start_pattern="${indent_str}${start_pattern}"
    indented_end_pattern="${indent_str}${end_pattern}"

    sed -n "/${indented_start_pattern}/,/^${indented_end_pattern}/ p" "$vdf"
}


# Unsure where this is used outside of config.vdf
function getLongSteamUserId {
    username="$( safequoteVdfBlockName "$1" )"
    config_vdf="$2"

    accounts_block="$( getVdfSection "Accounts" "" "" "$config_vdf" )"
    if [ -z "$accounts_block" ]; then
        echo "No accounts block in config.vdf file ('$config_vdf')."
        return
    fi
    
    username_block="$( getVdfSection "${username}" "" "" "$config_vdf" )"
    if [ -z "$username_block" ]; then
        echo "Username not found in  config.vdf file ('$config_vdf')."
        return
    fi
    
    # Extract just the ID from the block corresponding to the given username
    echo "$username_block" | grep '"SteamID"' | xargs | cut -d " " -f2 
}


# This is the Steam UserID used to name the userdata folder
function getShortSteamUserId {
    username="$( safequoteVdfBlockName "$1" )"
    config_vdf="$2"

    long_user_id="$( getLongSteamUserId "$username" "$config_vdf" )"
    echo $(( long_user_id & 0xFFFFFFFF ))
}
