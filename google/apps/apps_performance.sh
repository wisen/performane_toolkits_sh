#!/bin/bash
#
# Runs the test_app.sh test n times for each config file in TEST_APP_CONFIG_DIR
# test_app.sh is run : # of times specified in config files
set -eu -o pipefail

# Global variables shared across the script
# number of iterations to run specified configurations for
iterations=1
number_of_runs=10
apks_dir="./apks"
device_serial=""
device_serial_array=
maximize_cpu_freq=1
maximize_gpu_freq=0

# Stores the list of configs that test_app.sh can run
CONFIGS=

# Constants
readonly ALL_DEVICES="All"
readonly TEST_APP="./test_app.sh"
readonly TEST_APP_CONFIG_DIR="test_app_config"
readonly SUMMARY_RESULTS_DIR="./summary_results"
readonly IGNORE_CONFIG="test_to_run.config"

# The number of seconds since the epoch, it is used for making csv filename
# unique.
SCRIPT_INVOCATION_TIME=$(date +%s)

usage() {
  cat <<EOF
Usage: "$(basename "${BASH_SOURCE[0]}")" [OPTION]...
-g, --maximize_gpu_freq     whether gpu frequency should be maximized,
                            supported values: 0, 1
                            defaults to 0, use 1 to enable it
-h, --help                  usage information (this)
-i, --iterations            number of iterations of configs to run
-n, --number_of_runs        number of times each config is run
    --apks_dir              the directory which contains apks for test
-u, --maximize_cpu_freq     whether cpu frequency should be maximized,
                            supported values: 0, 1
                            defaults to 1, use 0 to disable it
Example:
  "$(basename "${BASH_SOURCE[0]}")" -i 10
EOF
}

# Helper function to only log something if DEBUG is set to non-zero
dlog() {
  if [[ ${DEBUG:-0} -ne 0 ]]; then
    echo "$@"
  fi
}

parse_arguments() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)
        usage
        exit 0
        ;;
      -i|--iterations)
        iterations=$2
        shift
        ;;
      -n|--number_of_runs)
        number_of_runs=$2
        shift
        ;;
      --apks_dir)
        apks_dir=$2
        shift
        ;;
      -u|--maximize_cpu_freq)
        maximize_cpu_freq=$2
        shift
        ;;
      -g|--maximize_gpu_freq)
        maximize_gpu_freq=$2
        shift
        ;;
      *)
        echo "Unknown option $1"
        usage
        exit 1
        ;;
    esac
    shift
  done
}

get_device_serial() {
  device_serial_array=($(adb devices|awk "{if(found) print} /List of devices attached/{found=1}"|awk '{gsub("device", "");print}'|tr -d "\r\n"))
  device_count="${#device_serial_array[@]}"

  if [[ "$device_count" -lt 1 ]]; then
    echo "No device found" && exit 1
  elif [[ "$device_count" -eq 1 ]]; then
    device_serial="${device_serial_array[0]}"
    adb root>/dev/null
    return
  fi

  if [[ -n "$device_serial" ]]; then
    export ANDROID_SERIAL=$device_serial
    adb root>/dev/null
    return
  fi

  device_index=-1
  i=1
  indent="  "
  echo "Found the following devices:"
  for device_serial in "${!device_serial_array[@]}"; do
    device_serial="${device_serial_array[$device_serial]}"
    device_name=$(adb -s "$device_serial" shell getprop "ro.product.name"|tr -d '\r')
    echo "$indent[$i] $device_name ($device_serial)"
    i=$((i+1))
  done
  echo "$indent[$i] $ALL_DEVICES"
  echo ""
  echo -n "Select device to test: [1-$i] "
  read device_index

  if [[ $device_index -lt 1 || $device_index -gt $i ]]; then
    echo "Invalid device selection" && exit 1
  else
    if [[ $device_index -eq $i ]]; then
      device_serial="$ALL_DEVICES"
    else
      device_serial="${device_serial_array[$device_index - 1]}"
      if [[ -n $device_serial ]]; then
        export ANDROID_SERIAL=$device_serial
        adb root>/dev/null
      fi
    fi
  fi
  echo ""
}

unlock_device() {
  if [[ "$device_serial" = "$ALL_DEVICES" ]]; then
    return
  fi
  is_display_on=$(adb shell dumpsys power|grep "mHoldingDisplaySuspendBlocker"|cut -d '=' -f 2)
  if [[ "$is_display_on" = "false" ]]; then
    adb shell input keyevent 26
  fi
  adb shell wm dismiss-keyguard
  adb shell svc power stayon usb
}

# Gather all runnable configurations for test_app.sh
gather_configs() {
  CONFIGS=($(find $TEST_APP_CONFIG_DIR -name "*.config" | grep -v $IGNORE_CONFIG|sort))
}

# Installs the apk from the folder specified by --apks_dir param for the
# current test_app_config and runs test_app.sh on the installed app.
install_run_apk() {
  apk_file="${apks_dir}/${package}.apk"
  if [[ ! -e "$apk_file" ]]; then
    dlog "Apk file $apk_file not found."
    return
  fi
  echo "Installing ${package}.apk on device : $device_serial"
  installed=$(adb install -r -d -g "$apk_file" 2>&1)
  if [[ "$installed" != *"Success" ]]; then
    dlog "Failed to install ${package}.apk"
    return
  fi
  echo "Install $installed on device : $device_serial"

  $TEST_APP -c "$1" -s "$SUMMARY_RESULTS_DIR" -n "$number_of_runs"\
    -u "$maximize_cpu_freq" -g "$maximize_gpu_freq"\
    --device_serial "$2" --quiet_mode 2 --speed_profile 1 \
    --summary_file_suffix "$2-$SCRIPT_INVOCATION_TIME"
  adb uninstall "$3">/dev/null
}

#searches for all configs in the /configs folder and runs test for each
run_test_app() {
  local config i
  configs_per_device=0
  config_count=0
  device_count="${#device_serial_array[@]}"
  if [[ "$device_serial" = "$ALL_DEVICES" ]]; then
    config_count="${#CONFIGS[@]}"
    configs_per_device=$((config_count / device_count))
    echo "Configs per device : $configs_per_device"
  fi

  device_serial_index=0
  config_index=0
  for ((i=1; i<=iterations; i++)); do
    for config in "${CONFIGS[@]}"; do
      package="Invalid_Config"
      activity="Invalid Config"
      source $config
      dlog "Iteration $i, running $config"

      if [[ configs_per_device -gt 0 ]]; then
        if [[ $device_serial_index -ge $device_count ]]; then
          device_serial_index=0
        fi
        device_serial=${device_serial_array[$device_serial_index]}
        export ANDROID_SERIAL=$device_serial
        adb root>/dev/null
        unlock_device
        device_serial_index=$((device_serial_index+1))
        install_run_apk "$config" "$device_serial" "${package}" &
      else
        install_run_apk "$config" "$device_serial" "${package}"
      fi
      config_index=$((config_index+1))
      if [[ $((config_index % device_count)) -eq 0 ]]; then
        wait
      fi
    done
  done
  if [[ $((config_count % device_count)) -ne 0 ]]; then
    wait
  fi
  echo "Done!"
}

main() {
  parse_arguments "$@"
  get_device_serial
  unlock_device
  gather_configs
  run_test_app
}

main "$@"
