#!/bin/bash

# Function to log both to the screen and syslog
log_message() {
  echo "USB config: $1"  # Echo to the screen
  logger "USB config: $1"  # Log to the system log
  echo "$(date +"%Y-%m-%d %H:%M:%S") $1" >> /tmp/femtofox-config.log # Log to file
}

# Check if the RTC (Real-Time Clock) has a valid time
if [[ $(hwclock -r) ]]; then
  log_message "Got time from RTC: $(hwclock -r)"  # Output the time obtained from the RTC
  time="$(hwclock -r)"  # Store the RTC time in the 'time' variable
  hwclock -s  # Set the system time from the RTC time
fi

# Check if we can get the time from a network source (e.g., google.com)
if [[ ! $(curl -s --head http://google.com | grep ^Date: | sed 's/Date: //g') ]]; then
  log_message "Could not get time from network"  # If no time is obtained, print an error message
else
  # Get the time from the network and store it in the 'time' variable
  time="$(curl -s --head http://google.com | grep ^Date: | sed 's/Date: //g')"
  log_message "Got time from network: ${time}"  # Output the time obtained from the network
  date -s "${time}"  # Set the system time from the network time
fi

# If no time is set yet, fall back to a default date
if [[ -z ${time} ]]; then
  log_message "Could not get time from any source. Setting to Jan 1 2024."  # Inform the user of the fallback date
  date -s "1 JAN 2024 00:00:00"  # Set the system time to January 1st, 2024
fi

# Check if the RTC device exists
if [[ -z /dev/rtc* ]]; then
  log_message "No RTC found"  # If no RTC device is found, print an error message
else
  log_message "RTC found, setting time from system clock"  # If an RTC is found, set its time from the system clock
  hwclock -w  # Write the system time to the RTC
fi

exit 0  # Exit the script successfully
