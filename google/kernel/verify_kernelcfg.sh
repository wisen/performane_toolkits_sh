#!/bin/bash

# IMPORTANT: This script can only be used on devices with the MTK chipset
#
# Script which verifies the Kernel configuration based on value set in
# required_values.txt
#
# Any configuration prefixed with ! in required_values.txt is checking to
# ensure the configuration is not enabled
#

set -eu

kernel_configuration='device_kernel_cfg.txt'
adb shell cat /proc/config.gz | gunzip > $kernel_configuration

required_kernel_cfg='required_values.txt'

while read config; do
  if [[ ${config:0:1} != '!' ]];
  then
    if !(grep -iq "$config" "$kernel_configuration");
    then
      echo "Configuration missing: $config"
    fi
  else
    if (grep -iq "${config:1:${#config}}" "$kernel_configuration");
    then
      echo "Unset or set to n: ${config:1:${#config}-3}"
    fi
  fi
done < $required_kernel_cfg
