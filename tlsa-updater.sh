#!/bin/sh
#
#title           :tlsa-updater.sh
#description     :this script is used to (correctly) update TLSA records for a zone after renewal
#		             it will check $ZONEFILE to create a new zone, and then create $UPDATEFILE
#           		 with --update, it will check $UPDATEDIR and if a file is older than $WAITPERIOD (days)
#                it will finish the update.
#author           :Bjorn Peeters (Thutex) - https://peeters.io
#date           :2017-07-08
#version           :0.2    
#usage           :tlsa-updater.sh --new | --update
#expects           :"zonefile" needs to be named domain.ext, tlsa records (if already present)
#		             need to be between ;tlsa and ;aslt
#notes           :May still contain bugs and lacks error checking
#==============================================================================


BINDDIR="/etc/bind"                   # directory to BIND
CERTDIR="/etc/letsencrypt/live"       # directory to where the latest certificates lie, without the domainname
MAILCERT=""                           # leave empty if you use the same certificate for both domain and mailserver, otherwise full path to fullchain.pem
CCDIR="/etc/letsencrypt/dane"         # directory where postfix looks for its current certificate, again without the domainname   
ZONEDIR="$BINDDIR/zones"              # where do you save your zonefiles?
UPDATEDIR="$BINDDIR/updating"         # create this directory! it will save the temporary file for the new TLSA records until its old enough (checked by the --update param)
WAITPERIOD="259200"                   # time in seconds before updating zonefile with only the new records, default is 3 days
#RENEWED_DOMAINS="example.org" # only for testing or manual use, (this script is meant to be run as renew-hook with LE) - will change with future revisions

usage()
{
    echo "$0 : prepare and update TLSA records after letsencrypt updates a certificate"
    echo ""
    echo "$0"
    echo "\t-h --help (this - which is fairly useless for now)"
    echo "\t--new (start a new update - run $0 --new with LE's renew-hook to start updates)"
    echo "\t--update (meant for crontab to finish the update, just run it once a day as $0 --update in cron)"
    echo ""
}

updated_mailtlsa()
{
# adds 3 1 1 TLSA records for DOMAIN and MAIL.DOMAIN on ports 25,465,587,993,995
echo "
_25._tcp.$1. IN TLSA 3 1 1 $2
_25._tcp.mail.$1. IN TLSA 3 1 1 $2
_465._tcp.$1. IN TLSA 3 1 1 $2
_465._tcp.mail.$1. IN TLSA 3 1 1 $2
_587._tcp.$1. IN TLSA 3 1 1 $2
_587._tcp.mail.$1. IN TLSA 3 1 1 $2
_993._tcp.$1. IN TLSA 3 1 1 $2
_993._tcp.mail.$1. IN TLSA 3 1 1 $2
_995._tcp.$1. IN TLSA 3 1 1 $2
_995._tcp.mail.$1. IN TLSA 3 1 1 $2
"
}

updated_webtlsa()
{
# adds 3 1 1 TLSA records for DOMAIN on ports 22 and 443
echo "
_22._tcp.$1. IN TLSA 3 1 1 $2
_443._tcp.$1. IN TLSA 3 1 1 $2
_443._tcp.www.$1. IN TLSA 3 1 1 $2
"
}

while [ "$1" != "" ]; do
    PARAM=`echo $1 | awk -F= '{print $1}'`
    VALUE=`echo $1 | awk -F= '{print $2}'`
    case $PARAM in
        -h | --help)
            usage
            exit
          ;;
        --new)
            for DOMAIN in $RENEWED_DOMAINS; do
                WHEN=$(date +%Y%m%d)
                ZONEFILE="$ZONEDIR/$DOMAIN"
                UPDATEFILE="$UPDATEDIR/$DOMAIN"
                NEWTLSA=$(openssl x509 -in $CERTDIR/$DOMAIN/fullchain.pem -noout -pubkey | openssl pkey -pubin -outform DER | openssl dgst -sha256 -binary | hexdump -ve '/1 "%02x"')
                if [ -z "$MAILCERT" ]; then
                MAILTLSA="$NEWTLSA"
                else
                MAILTLSA=$(openssl x509 -in $MAILCERT -noout -pubkey | openssl pkey -pubin -outform DER | openssl dgst -sha256 -binary | hexdump -ve '/1 "%02x"')
                fi
                OLDTLSA=$(cat "$ZONEFILE" | awk '/^;tlsa$/,/^;aslt$/{if (!/^;tlsa$/&&!/^;aslt$/)print}')
                CLEANZONE=$(sed '/\;tlsa/,/\;aslt/d' "$ZONEFILE")
                echo "$CLEANZONE" > $ZONEFILE
                echo ';tlsa' >> $ZONEFILE
                echo ";last update: $WHEN" >> $ZONEFILE
                echo "$OLDTLSA" >> $ZONEFILE
                updated_webtlsa $DOMAIN $NEWTLSA >> $ZONEFILE
                updated_mailtlsa $DOMAIN $MAILTLSA >> $ZONEFILE
                echo ';aslt' >> $ZONEFILE
                sed -i 's/20[0-1][0-9]\{7\}/'`date +%Y%m%d%I`'/Ig' $ZONEFILE
                updated_webtlsa $DOMAIN $NEWTLSA > $UPDATEFILE
                updated_mailtlsa $DOMAIN $MAILTLSA >> $UPDATEFILE
            done
            systemctl reload bind9
                exit
            ;;
        --update)
                for FILE in $UPDATEDIR/*; do
                WHEN=$(date +%Y%m%d)
                DOMAIN=$(basename "$FILE")
                ZONEFILE="$ZONEDIR/$DOMAIN"
                AGETEST=$(($(date +%s) - $(date +%s -r $FILE)))
                if [ "$AGETEST" -le "$WAITPERIOD" ]
                then
                    echo "update for $DOMAIN ($FILE) may not be propagated yet - stopping zone update"
                exit
                else
                OLDTLSA=$(cat "$ZONEFILE" | awk '/^;tlsa$/,/^;aslt$/{if (!/^;tlsa$/&&!/^;aslt$/)print}')
                CLEANZONE=$(sed '/\;tlsa/,/\;aslt/d' "$ZONEFILE")
                echo "$CLEANZONE" > $ZONEFILE
                echo ';tlsa' >> $ZONEFILE
                echo ";last update: $WHEN" >> $ZONEFILE
                cat $FILE >> $ZONEFILE
                echo ';aslt' >> $ZONEFILE
                sed -i 's/20[0-1][0-9]\{7\}/'`date +%Y%m%d%I`'/Ig' $ZONEFILE
                rm $FILE
                systemctl reload bind9
                rm -rf $CCDIR/$DOMAIN
                cp -R $CERTDIR/$DOMAIN $CCDIR
                systemctl reload postfix
                fi
                done
                exit

            ;;
  *)
            echo "ERROR: unknown parameter \"$PARAM\""
            usage
            exit 1
            ;;
    esac
    shift
done

