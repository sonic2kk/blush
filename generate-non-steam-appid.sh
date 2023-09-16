#!/usr/bin/env bash


# Convert from decimal to hexadecimal
# Credit to @frostworx for the original incarnation of this function in SteamTinkerLaunch
function dec2hex {
    printf '%x\n' "$1" | cut -c 9-
}


# Takes a big-endian ("normal") hexadecimal number and converts it to little-endian (reverse byte order)
function bigToLittleEndian {
    echo -n "$1" | tac -rs .. | tr -d '\n'
}


# Generate random 32bit unsigned integer based on an optional seed string
# Some tools like Steam-ROM-Manager use the appname and Exe fields of the shortcut as a key
function generateShortcutVDFAppId {
    echo "-$( shuf -i 99999999-999999999 -n 1 --random-source=<(echo -n "$1") )"
}


# Takes an signed 32bit integer and converts it to a 4byte little-endian hex number, which should get written out to the VDF file
function generateHexAppId {
    bigToLittleEndian "$( dec2hex "$1" )"
}


# Takes a 4byte little-endian hex and appends the binary formatting needed to write this to the VDF file
# Credit to @frostworx who originally wrote this for SteamTinkerLaunch
function generateShortcutVDFHexAppId {
    echo "\x$(awk '{$1=$1}1' FPAT='.{2}' OFS="\\\x" <<< "$NOSTAIDVDFHEX")"
}


# Takes an signed 32bit integer and converts it to an unsigned 32bit integer 
function generateShortcutGridAppId {
    echo $(( $1 & 0xFFFFFFFF ))
}


# Takes an unsigned 32bit integer and converts it to a signed 32bit integer
function generateShortcutSignedAppId {
    echo $(( $1 - 0x100000000 ))
}
