#!/usr/bin/env bash

THRESHOLD=$((7 * 24 * 60 * 60))  # 1 week in seconds
LOGFILE="/var/log/time_change.log"
LAST_TIME_FILE="/tmp/last_time"

# Ensure the log file exists and is writable
if [ ! -f "$LOGFILE" ]; then
    touch "$LOGFILE" || { echo "ERROR: Cannot create log file $LOGFILE"; exit 1; }
fi
if [ ! -w "$LOGFILE" ]; then
    echo "ERROR: Log file $LOGFILE is not writable"
    exit 1
fi

# Ensure the last time file exists and is writable
if [ ! -f "$LAST_TIME_FILE" ]; then
    date +%s > "$LAST_TIME_FILE" || { echo "ERROR: Cannot create last time file $LAST_TIME_FILE"; exit 1; }
fi
if [ ! -w "$LAST_TIME_FILE" ]; then
    echo "ERROR: Last time file $LAST_TIME_FILE is not writable"
    exit 1
fi

while true; do
    # Check if meshtasticd service is running
    if ! systemctl is-active --quiet meshtasticd; then
        #echo "meshtasticd service is not running. Skipping..." | tee -a "$LOGFILE"
        sleep 30
        continue
    fi
    NEW_TIME=$(date +%s)

    # Ensure last_time file is readable before using it
    if [ ! -r "$LAST_TIME_FILE" ]; then
        echo "ERROR: Last time file $LAST_TIME_FILE is not readable" | tee -a "$LOGFILE"
        exit 1
    fi

    OLD_TIME=$(cat "$LAST_TIME_FILE")
    TIME_DIFF=$((NEW_TIME - OLD_TIME))

    if [ "${TIME_DIFF#-}" -ge "$THRESHOLD" ]; then
        echo "$(date) - Large time change detected ($TIME_DIFF seconds), restarting meshtasticd" | tee -a "$LOGFILE"
        systemctl restart meshtasticd
    fi

    # Ensure last_time file is writable before updating it
    if [ -w "$LAST_TIME_FILE" ]; then
        echo "$NEW_TIME" > "$LAST_TIME_FILE"
    else
        echo "ERROR: Failed to write to $LAST_TIME_FILE" | tee -a "$LOGFILE"
        exit 1
    fi

    sleep 30
done

