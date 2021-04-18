#!/bin/bash

################################################################################
# Script Name   : mail-ip.sh
# Author        : Podesta
# Date          : October 2019
# Version       : 1.0
# Dependencies  : Miniupnpc for creating upnpc rules.
#                 Msmtp for sending email.
# Description   : Opens port on router using upnp, and mails the info. Works
#                 great with a cron job. Make sure you have msmtp configured.
################################################################################

# User variables
PORT=
TOMAIL=
FROMMAIL=
TIMER=21600
DESCRIPTION=""

# Makes sure system has fully started for boot cron job.
sleep 30

date=$( date -u +%F )
newEPOCH=$( date +%s )
oldEPOCH=$( grep "EPOCH" ~/Documents/ip-upnp/mail.txt | sed 's/[^0-9]//g' )

# Save upnpc to file, so it is run only once
upnpc -l > ~/Documents/ip-upnp/upnpc.txt

newExtIP=$( grep "ExternalIPAddress" ~/Documents/ip-upnp/upnpc.txt | sed 's/[^0-9\.]//g' )
newLanIP=$( grep "Local LAN ip address" ~/Documents/ip-upnp/upnpc.txt | sed 's/[^0-9\.]//g' )

oldExtIP=$( grep "External IP" ~/Documents/ip-upnp/mail.txt | sed 's/[^0-9\.]//g' )
oldLanIP=$( grep "LAN IP" ~/Documents/ip-upnp/mail.txt | sed 's/[^0-9\.]//g' )

# See if there is a rule on upnp with the desired port
upnpIP=$( grep ~/Documents/ip-upnp/upnpc.txt -E -e  \
    '^[[:space:]]*[[:digit:]]+[[:space:]]*TCP[[:space:]]'+"$PORT" \
    | sed -E 's/.*->(.+):.*/\1/g')

# If there is no rule on upnp or the IP is different, delete rule and add new one
if [[ ! "$newLanIP" == "$upnpIP" ]]
then
    upnpc -d $PORT
    upnpc -e "$DESCRIPTION" -r $PORT TCP
    echo "Creating upnp rule"
fi

# If same IP and less than 6 (21600) hours passed, do not send another email
if  [[ "$newEPOCH" -le $(("$oldEPOCH" + "$TIMER")) ]] && \
    [[ "$newExtIP" == "$oldExtIP" ]] && \
    [[ "$newLanIP" == "$oldLanIP" ]]
then
    echo "No need to send email"
    exit 1

# Otherwise update email and send it
else
    printf "To: '$TOMAIL'\nFrom: '$FROMMAIL'\nSubject: RPI - New IP\n\n" > ~/Documents/ip-upnp/mail.txt
    printf "Date: $date\nEPOCH: $newEPOCH\n" >> ~/Documents/ip-upnp/mail.txt
    printf "LAN IP: $newLanIP\nExternal IP: $newExtIP\n\n" >> ~/Documents/ip-upnp/mail.txt
    upnpc -l >> ~/Documents/ip-upnp/mail.txt
    cat ~/Documents/ip-upnp/mail.txt | msmtp -a default "$TOMAIL"
    echo "Email sent"
    exit 2
fi
