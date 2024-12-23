      fi
    else
      echo "$duration second button press detected. Rebooting."
      echo 1 > /sys/class/gpio/gpio34/value;
      sudo reboot
    fi
  fi
done
