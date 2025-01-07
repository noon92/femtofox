#!/bin/bash

# Check if the filesystem has been resized previously
if [ ! -f /etc/.filesystem_resized ]; then
  # Perform filesystem resize
  resize2fs /dev/mmcblk1p5
  resize2fs /dev/mmcblk1p6
  echo "Resizing /dev/mmcblk1p7 can take up to 10 minutes, depending on microSD card size and speed."
  resize2fs /dev/mmcblk1p7
  
  # Create a marker file indicating filesystem resize has been done
  touch /etc/.filesystem_resized
  
  echo "Filesystem resized successfully."
fi

if [ ! -f /etc/.filesystem_swap ]; then
  fallocate -l 1G /swapfile
  chmod 600 /swapfile
  mkswap /swapfile > /dev/null
  swapon /swapfile > /dev/null
  echo '/swapfile none swap sw 0 0' | tee -a /etc/fstab > /dev/null
  
  touch /etc/.filesystem_swap
  
  echo "Swap successfully."
fi

