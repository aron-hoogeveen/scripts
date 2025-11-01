#!/bin/sh

####################################################################################################
# Battery Warning
# By: Aron Hoogeveen
#
# This script is supposed to run every 5 minutes or so via a cronjob. The script shows warnings when
# low battery levels have been reached and shuts down the system when a critically low battery level
# has been reached.
#
# This script should be in a global folder with read/execution for all users, but write only for root user. For example in /usr/local/bin
#
# TODO currently only works if you add this to the crontabs of all users who will use graphical sessions. Would be best if it runs on root or special user and then shows the notifications for all users that currently have a graphical session active. Then the laptop will shutoff also when noone is yet logged in.
####################################################################################################

# check if commands exist
if ! command -v notify-send &> /dev/null; then
    >&2 echo 'ERROR: notify-send is not an available command on your system.'
    return
fi

# threshold level settings (percentage)
th1=5
th2=10
th3=20

# battery path
batpath='/sys/class/power_supply/BAT1'
charge_now="$batpath/charge_now"
charge_full="$batpath/charge_full"

# tmp file
tmp_file_path=/dev/shm/battery-manager-notified

# notify-send settings
not_urg='critical'
not_title='Battery Warning'
not_descr=(
    'Your battery level is critically low. To protect your battery the system will shutdown in 1 minute. Save your work!'
    "Your battery level is below $th2%. Connect a charger!"
    "Your battery level is below $th3%. Connect a charger!"
)

# Calculate battery level (percentage)
batlevel=$(echo "$(cat $charge_now) * 100 / $(cat $charge_full)" | bc)

reset_tmp_file()
{
    echo '999' > $tmp_file_path
}

# Notify the user if not already notified for the specific warning level
# params:
#   $1 - int indicating the warning level. 1-3
#   
do_notify()
{
    if [ ! -f $tmp_file_path ]; then
        reset_tmp_file
    fi

    # if new notify level is lower (more critical) than currently saved, notify
    if [ $1 -lt $(cat $tmp_file_path) ]; then
        echo $1 > $tmp_file_path  # save new warning level

        # special notification when shutting down
        if [ $1 -eq 1 ]; then
            not_ret=$(notify-send --app-name="$not_title" --urgency="$not_urg" \
                "$not_title" \
                "${not_descr[$1-1]}" \
                --action=cancel_shutdown="Cancel shutdown")

            case $not_ret in
                "cancel_shutdown")
                    shutdown -c
                    break
                    ;;
                *)
                    echo "something was selected that is not handled."
                    break
                    ;;
            esac
        else
            notify-send --app-name="$not_title" --urgency="$not_urg" \
                "$not_title" \
                "${not_descr[$1-1]}"
        fi
    fi
}

# Check most critical exceeded threshold
if [ $batlevel -le $th1 ]; then
    shutdown  # initiate shutdown (after a minute) before the blocking do_notify
    do_notify 1
elif [ $batlevel -le $th2 ]; then
    do_notify 2
elif [ $batlevel -le $th3 ]; then
    do_notify 3
else
    reset_tmp_file  # otherwise the next time the warnings will not be triggered
fi

