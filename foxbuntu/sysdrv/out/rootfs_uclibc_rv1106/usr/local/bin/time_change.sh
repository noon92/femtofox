#!/usr/bin/env bash

THRESHOLD=$((7 * 24 * 60 * 60))  # 1 week in seconds
LOGFILE="/var/log/time_change.log"
LAST_TIME_FILE="/tmp/last_time"

# Function to check time jump
check_time_jump() {
    NEW_TIME=$(date +%s)

    if [ -f "$LAST_TIME_FILE" ]; then
        OLD_TIME=$(cat "$LAST_TIME_FILE")
    else
        OLD_TIME=$NEW_TIME
    fi

    TIME_DIFF=$((NEW_TIME - OLD_TIME))

    if [ "${TIME_DIFF#-}" -ge "$THRESHOLD" ]; then
        echo "$(date) - Large time change detected ($TIME_DIFF seconds), restarting meshtasticd" | tee -a "$LOGFILE"
        systemctl restart meshtasticd
    fi

    echo "$NEW_TIME" > "$LAST_TIME_FILE"
}

# Monitor chronyd logs for time jumps (background)
(
    journalctl -fu chronyd --no-pager | while read -r line; do
        if echo "$line" | grep -q "Forward time jump detected"; then
            echo "$(date) - Detected time change via chronyd logs" | tee -a "$LOGFILE"
            check_time_jump
        fi
    done
) &

# Monitor /etc/adjtime for manual or RTC-based time changes (background)
(
    while true; do
        if find /etc/adjtime -mmin -1 | grep -q .; then
            echo "$(date) - Time change detected via /etc/adjtime modification" | tee -a "$LOGFILE"
            check_time_jump
        fi
        sleep 5
    done
) &

# Fallback: Compare timestamps every 5 seconds (if other methods fail)
(
    while true; do
        check_time_jump
        sleep 5
    done
) &

# Keep script running
wait

