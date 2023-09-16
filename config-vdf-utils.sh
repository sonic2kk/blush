#!/usr/bin/env bash

function getVdfSection {
    start_pattern="$1"
    end_pattern="$2"
    vdf="$3"
    sed -n "/${start_pattern}/,/${end_pattern}/ p" "$vdf"
}

# Unsure where this is used outside of config.vdf
function getLongSteamUserId {
    accounts_indent="$( printf '%.0s[[:space:]]' $(seq 1 4) )"  # Accounts block starts at indent level 4
    username_indent="$( printf '%.0s[[:space:]]' $(seq 1 5) )"
    
    username="$1"
    config_vdf="$2"

    accounts_block="$( getVdfSection "${accounts_indent}\"Accounts\"" "^${accounts_indent}}" "$config_vdf" )"
    if [ -z "$accounts_block" ]; then
        echo "No accounts block in config.vdf file ('$config_vdf')."
        return
    fi
    
    username_block="$( getVdfSection "${username_indent}\"${username}\"" "${username_indent}}" "$config_vdf" )"
    if [ -z "$username_block" ]; then
        echo "Username not found in  config.vdf file ('$config_vdf')."
        return
    fi
    
    # Extract just the ID from the block corresponding to the given username
    echo "$username_block" | grep '"SteamID"' | xargs | cut -d " " -f2 
}

# This is used in userdata folder
function getShortSteamUserId {
    username="$1"
    config_vdf="$2"

    long_user_id="$( getLongSteamUserId "$username" "$config_vdf" )"
    echo $(( long_user_id & 0xFFFFFFFF ))
}
