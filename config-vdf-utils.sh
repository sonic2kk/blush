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

    grep -i "${block_name}" "$vdf" | awk '{print gsub(/\t/,"")}'
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

    sed -n "/${indented_start_pattern}/I,/^${indented_end_pattern}/I p" "$vdf"
}


# Check if a VDF block (block_name) already exists inside a parent block (search_block)
# Ex: search_block "CompatToolMapping" for a specific block_name "22320"
function checkVdfSectionAlreadyExists {
    search_block="$( safequoteVdfBlockName "${1:-\"}" )"  # Default to the first quotation, should be the start VDF file
    block_name="$( safequoteVdfBlockName "$2" )"  # Block name to  search for
    vdf="$3"

    if [ -z "$block_name" ]; then
        echo "Block name must be provided!"
        return
    fi

    search_block_vdf_section="$( getVdfSection "$search_block" "" "" "$vdf" )"
    if [ -z "$search_block_vdf_section" ]; then
        return 0
    fi

    printf "%s" "$search_block_vdf_section" > "/tmp/tmp.vdf"
    getVdfSection "$block_name" "" "" "/tmp/tmp.vdf" | grep -iq "$block_name"
}


# Create entry in given VDF block with matching indentation (Case-INsensitive)
# Appends to bottom of target block by default, but can optionally append to the top instead
#
# This doesn't support adding nested entries, at least not very easily
function createVdfEntry {
    vdf="$1"  # Absolute path to VDF to insert into
    parent_block_name="$( safequoteVdfBlockName "$2" )"  # Block to start from, e.g. "CompatToolMapping"
    new_block_name="$( safequoteVdfBlockName "$3" )"  # Name of new block, e.g. "<AppID>"
    position="${4:-bottom}"  # Position to insert into, can be either top/bottom -- Bottom by default

    # Ensure no duplicates are written out
    if checkVdfSectionAlreadyExists "$parent_block_name" "$new_block_name" "$vdf"; then
        echo "Block already exists, skipping..."
        return
    fi

    # Create array from args, skip first four to get array of key/value pairs for VDF block
    new_block_values=("${@:5}")
    new_block_values_delimiter="!"

    # Calculate indents for new block (one more than parent_block_name indent)
    base_tab_amt="$(( $( guessVdfIndent "${parent_block_name}" "$vdf" ) + 1 ))"
    block_tab_amt="$(( base_tab_amt + 1 ))"

    # Tab amounts represented as string
    base_tab_str="$( generateVdfIndentString "$base_tab_amt" )"
    block_tab_str="$( generateVdfIndentString "$block_tab_amt" )"

    # Calculations for line numbers
    parent_block_length="$( getVdfSection "$parent_block_name" "" "" "$vdf" | wc -l )"
    block_start_line="$( grep -in "${parent_block_name}" "$vdf" | cut -d ':' -f1 | xargs )"

    top_of_block="$(( block_start_line + 1 ))"
    bottom_of_block="$(( block_start_line + parent_block_length - 2 ))"

    # Decide which line to insert new block into
    insert_line="${bottom_of_block}"
    if [[ "${position,,}" == "top" ]]; then
        insert_line="${top_of_block}"
    fi

    # Build new VDF entry string
    # Maybe this could be a separate function at some point, that generates a VDF string from the input array?
    new_block_str="${base_tab_str}${new_block_name}\n"  # Add tab + block name
    new_block_str+="${base_tab_str}{\n"  # Add tab + opening brace
    for i in "${new_block_values[@]}"; do
        # Cut string in array at delimiter and store them as key/val
        new_block_data_key="$( echo "$i" | cut -d "${new_block_values_delimiter}" -f1 )"
        new_block_data_val="$( echo "$i" | cut -d "${new_block_values_delimiter}" -f2 )"

        new_block_data_key="$( safequoteVdfBlockName "$new_block_data_key" )"
        new_block_data_val="$( safequoteVdfBlockName "$new_block_data_val" )"

        new_block_str+="${block_tab_str}${new_block_data_key}"  # Add tab +  key
        new_block_str+="\t\t${new_block_data_val}\n"  # Add tab + val + newline
    done
    new_block_str+="${base_tab_str}}"  # Add tab + closing brace

    # Write out new string to calculated line in VDF file
    sed -i "${insert_line}a\\${new_block_str}" "$vdf"
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
    echo "$username_block" | grep -i '"SteamID"' | xargs | cut -d " " -f2
}


# This is the Steam UserID used to name the userdata folder
function getShortSteamUserId {
    username="$( safequoteVdfBlockName "$1" )"
    config_vdf="$2"

    long_user_id="$( getLongSteamUserId "$username" "$config_vdf" )"
    echo $(( long_user_id & 0xFFFFFFFF ))
}
