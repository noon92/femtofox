#!/bin/bash

LOG_FILE="/var/log/meshtastic_wifi.log"
WIFI_STATE_FILE="/etc/wifi_state.txt"
PROTO_FILE="/root/.portduino/default/prefs/config.proto"

log() {
    echo "$(date) - $1" | tee -a "$LOG_FILE"
}

get_mobile_wifi_state() {
    local proto_output
    proto_output=$(cat "$PROTO_FILE" | protoc --decode_raw | awk '/4 {/, /}/ {if ($1 == "1:") print $2}')
    [[ "$proto_output" == "1" ]] && echo "up" || echo "down"
}

set_mobile_wifi_state() {
    local state="$1"
    local meshtastic_output

    if [[ "$state" == "up" ]]; then
        meshtastic_output=$(meshtastic --host 127.0.0.1 --set network.wifi_enabled true 2>&1 || true)
    else
        meshtastic_output=$(meshtastic --host 127.0.0.1 --set network.wifi_enabled false 2>&1 || true)
    fi

    log "Set Meshtastic Wi-Fi state to $state. Output: $meshtastic_output"
}

set_wlan_state() {
    local state="$1"
    if [[ "$state" == "up" ]]; then
        ip link set wlan0 up && log "Set wlan0 UP."
    else
        ip link set wlan0 down && log "Set wlan0 DOWN."
    fi
}

validate_wifi_state_file() {
    local state
    state=$(cat "$WIFI_STATE_FILE" 2>/dev/null)
    if [[ "$state" != "up" && "$state" != "down" ]]; then
        echo "up" > "$WIFI_STATE_FILE"
        log "Invalid wifi_state.txt content. Defaulting to up."
    fi
}

sync_states() {
    local text_state mobile_state
    text_state=$(cat "$WIFI_STATE_FILE")
    mobile_state=$(get_mobile_wifi_state)

    if [[ "$text_state" != "$mobile_state" ]]; then
        set_mobile_wifi_state "$text_state"
        log "Synced mobile Wi-Fi state to $text_state."
    fi

    current_wlan_state=$(cat /sys/class/net/wlan0/operstate)
    if [[ "$text_state" != "$current_wlan_state" ]]; then
        set_wlan_state "$text_state"
        log "Synced wlan0 state to $text_state."
    fi
}

monitor_changes() {
    local previous_mobile_state previous_wlan_state
    previous_mobile_state=$(get_mobile_wifi_state)
    previous_wlan_state=$(cat /sys/class/net/wlan0/operstate)

    while true; do
        PID=$(ps -C meshtasticd -o pid= | tr -d ' ')
        #if [[ -n "$PID" ]] && sudo lsof /dev/spidev0.0 | grep -q "$PID" && [[ -d /sys/class/net/wlan0 ]]; then
        if [[ -n "$PID" ]] && sudo lsof /dev/spidev0.0 | grep -q "$PID" && [[ -d /sys/class/net/wlan0 ]] && systemctl is-active --quiet meshtasticd; then
          local current_mobile_state current_wlan_state
          current_mobile_state=$(get_mobile_wifi_state)
          current_wlan_state=$(cat /sys/class/net/wlan0/operstate)

          if [[ "$current_mobile_state" != "$previous_mobile_state" ]]; then
              log "Detected mobile Wi-Fi state change: $previous_mobile_state -> $current_mobile_state"
              echo "$current_mobile_state" > "$WIFI_STATE_FILE"
              set_wlan_state "$current_mobile_state"
              previous_mobile_state="$current_mobile_state"
          fi

          if [[ "$current_wlan_state" != "$previous_wlan_state" ]]; then
              log "Detected wlan0 state change: $previous_wlan_state -> $current_wlan_state"
              echo "$current_wlan_state" > "$WIFI_STATE_FILE"
              set_mobile_wifi_state "$current_wlan_state"
              previous_wlan_state="$current_wlan_state"
          fi
        fi
        sleep 5
    done
}

# Main Execution
validate_wifi_state_file
sync_states
monitor_changes
