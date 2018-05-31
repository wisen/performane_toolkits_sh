#!/bin/bash
# Collects post boot metrics of an Android device.

set -euo pipefail

readonly WAIT_FOR_DEVICE_TIME=2
readonly ONE_KB=1024
readonly ONE_GB=1048576
readonly FIVE_TWELVE_MB=524288
readonly NUMBER_RE="^[0-9]+([.][0-9]+)?$"
readonly PASS="PASS"
readonly FAIL="FAIL"
readonly REDUCE="REDUCE"
readonly OPTIMAL="OPTIMAL"
readonly SCREEN_TYPE_VGA="VGA"
readonly SCREEN_TYPE_WVGA="WVGA"
readonly SCREEN_TYPE_QHD="QHD"
readonly SCREEN_TYPE_HD="HD"

readonly MAX_PERSISTENT_MEMORY=$((90*ONE_KB))

readonly MIN_FREE_MEMORY_FOR_ONE_GB_VGA=$((600*ONE_KB))
readonly MIN_FREE_MEMORY_FOR_FIVE_TWELVE_MB_VGA=$((135*ONE_KB))
readonly MAX_LAUNCHER_MEMORY_VGA=$((30*ONE_KB))
readonly MAX_SYSTEM_UI_MEMORY_VGA=$((50*ONE_KB))
readonly MAX_SYSTEM_SERVER_MEMORY_VGA=$((65*ONE_KB))
readonly MAX_USED_KERNEL_MEMORY_VGA=$((70*ONE_KB))

readonly MIN_FREE_MEMORY_FOR_ONE_GB_WVGA=$((530*ONE_KB))
readonly MIN_FREE_MEMORY_FOR_FIVE_TWELVE_MB_WVGA=$((125*ONE_KB))
readonly MAX_LAUNCHER_MEMORY_WVGA=$((35*ONE_KB))
readonly MAX_SYSTEM_UI_MEMORY_WVGA=$((60*ONE_KB))
readonly MAX_SYSTEM_SERVER_MEMORY_WVGA=$((75*ONE_KB))
readonly MAX_USED_KERNEL_MEMORY_WVGA=$((80*ONE_KB))

readonly MIN_FREE_MEMORY_FOR_ONE_GB_QHD=$((510*ONE_KB))
readonly MAX_LAUNCHER_MEMORY_QHD=$((40*ONE_KB))
readonly MAX_SYSTEM_UI_MEMORY_QHD=$((65*ONE_KB))
readonly MAX_SYSTEM_SERVER_MEMORY_QHD=$((80*ONE_KB))
readonly MAX_USED_KERNEL_MEMORY_QHD=$((85*ONE_KB))

readonly MIN_FREE_MEMORY_FOR_ONE_GB_HD=$((430*ONE_KB))
readonly MAX_LAUNCHER_MEMORY_HD=$((50*ONE_KB))
readonly MAX_SYSTEM_UI_MEMORY_HD=$((75*ONE_KB))
readonly MAX_SYSTEM_SERVER_MEMORY_HD=$((90*ONE_KB))
readonly MAX_USED_KERNEL_MEMORY_HD=$((95*ONE_KB))

readonly MAX_MEMORY_CARVEOUT_MT6580M_ONE_GB=$((61*ONE_KB))
readonly MAX_MEMORY_CARVEOUT_MT6580M_FIVE_TWELVE_MB=$((45*ONE_KB))

readonly MAX_MEMORY_CARVEOUT_MT6737M_ONE_GB=$((107*ONE_KB))
readonly MAX_MEMORY_CARVEOUT_MT6737M_FIVE_TWELVE_MB=$((89*ONE_KB))

readonly MAX_MEMORY_CARVEOUT_MT6739_ENG_ONE_GB=$((129*ONE_KB))
readonly MAX_MEMORY_CARVEOUT_MT6739_ENG_FIVE_TWELVE_MB=$((95*ONE_KB))

readonly MAX_MEMORY_CARVEOUT_MSM8909_ONE_GB=$((120*ONE_KB))
readonly MAX_MEMORY_CARVEOUT_MSM8909_FIVE_TWELVE_MB=$((120*ONE_KB))

readonly MAX_MEMORY_CARVEOUT_MSM8917_ONE_GB=$((135*ONE_KB))
readonly MAX_MEMORY_CARVEOUT_MSM8917_FIVE_TWELVE_MB=$((120*ONE_KB))

device_serial=""
debug=${DEBUG:-0}
wait_time=300
metrics_results_dir="./summary_results"
metrics_file_suffix=""

# The number of seconds since the epoch, it is used for making metrics filename
# unique.
SCRIPT_INVOCATION_TIME=$(date +%s)

usage() {
  cat <<EOF
Usage: "$(basename "${BASH_SOURCE[0]}")" [OPTION]...

-h, --help                  usage information (this)
-w, --wait_time             wait time in seconds before collecting metrics
-d, --metrics_results_dir   directory to store post boot metrics
-s, --metrics_file_suffix   used for making metrics filename unique
Example:
  "$(basename "${BASH_SOURCE[0]}")" -w 300
EOF
}

parse_arguments() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)
        usage
        exit 0
        ;;
      -w|--wait_time)
        wait_time=$2
        if ! [[ $wait_time =~ $NUMBER_RE ]] ; then
           echo "Invalid wait time. Exiting ..."
           exit 1
        fi
        shift
        ;;
      -d|--metrics_results_dir)
        metrics_results_dir=${2:-""}
        [[ -z "$metrics_results_dir" ]] \
          && echo "Results dir is not specified." && exit 1
        shift
        ;;
      -s|--metrics_file_suffix)
        metrics_file_suffix=$2
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
    return
  fi

  if [[ -n "$device_serial" ]]; then
    export ANDROID_SERIAL=$device_serial
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
  echo ""
  echo -n "Select device to test: [1-$device_count] "
  read device_index

  if [[ $device_index -lt 1 || $device_index -gt $device_count ]]; then
    echo "Invalid device selection" && exit 1
  else
    device_serial="${device_serial_array[$device_index - 1]}"
    if [[ -n $device_serial ]]; then
      export ANDROID_SERIAL=$device_serial
    fi
  fi
  echo ""
}

wait_for_device() {
  printf "Waiting for device to come online ..."
  sleep ${WAIT_FOR_DEVICE_TIME};
  adb wait-for-device
  local boot_completed=$(adb shell getprop sys.boot_completed | tr -d '\r')
  while [[ "$boot_completed" != "1" ]]; do
    printf "."
    sleep $WAIT_FOR_DEVICE_TIME
    boot_completed=$(adb shell getprop sys.boot_completed 2>/dev/null||echo 0)
    if [[ $os_version =~ "$NUMBER_RE" && "$os_version" -lt 8 ]]; then
      boot_completed=$(echo "$boot_completed"|tr -d '\r')
    fi
  done;
  sleep "$WAIT_FOR_DEVICE_TIME"
  echo ""
}

# Tests if the device has required memory metrics.
#
# Arguments:
#    Device RAM size
#    Free memory on device
#    Used kernel memory
#    System server Pss
#    System UI Pss
#    Launcher Pss
test_pss_metrics() {
  local total_ram_size="$1" free_memory="$2" kernel_memory="$3" \
    system_server_memory="$4" system_ui_memory="$5" launcher_memory="$6" \
    memory_carveout="$7"
  if ! [[ $total_ram_size =~ $NUMBER_RE ]] ; then
    echo "Fail, Because of invalid RAM size."
    return
  fi

  if ! [[ $free_memory =~ $NUMBER_RE ]] ; then
    echo "Fail, Because of invalid free memory size."
    return
  fi

  if ! [[ $kernel_memory =~ $NUMBER_RE ]] ; then
    echo "Fail, Because of invalid user kernel memory size."
    return
  fi

  if ! [[ $system_server_memory =~ $NUMBER_RE ]] ; then
    echo "Fail, Because of invalid system server memory size."
    return
  fi

  if ! [[ $system_ui_memory =~ $NUMBER_RE ]] ; then
    echo "Fail, Because of invalid system UI memory size."
    return
  fi

  if ! [[ $launcher_memory =~ $NUMBER_RE ]] ; then
    echo "Fail, Because of invalid launcher memory size."
    return
  fi

  if ! [[ $memory_carveout =~ $NUMBER_RE ]] ; then
    echo "Fail, Because of invalid memory carveout size."
    return
  fi

  screen_size=$(adb shell wm size|cut -d ':' -f 2|awk '{$1=$1;print}'|tr -d '\r')
  width=$(echo "$screen_size"|cut -d 'x' -f 1)
  height=$(echo "$screen_size"|cut -d 'x' -f 2)

  if [[ "$height" -le "$width" ]]; then
    short_side=$height
    long_side=$width
  else
    short_side=$width
    long_side=$height
  fi

  free_memory_test_result="N/A"
  launcher_memory_test_result="N/A"
  kernel_memory_test_result="N/A"
  system_server_memory_test_result="N/A"
  system_ui_memory_test_result="N/A"
  device_screen_type="N/A"

  if [[ "$short_side" -le 480 && "$long_side" -le 640 ]]; then # vga
    device_screen_type="$SCREEN_TYPE_VGA"
    if [[ "$total_ram_size" -eq "$ONE_GB" ]]; then
      [[ "$free_memory" -ge "$MIN_FREE_MEMORY_FOR_ONE_GB_VGA" ]] \
        && free_memory_test_result="$PASS" || free_memory_test_result="$FAIL"
    elif [[ "$total_ram_size" -eq "$FIVE_TWELVE_MB" ]]; then
      [[ "$free_memory" -ge "$MIN_FREE_MEMORY_FOR_FIVE_TWELVE_MB_VGA" ]] \
        && free_memory_test_result="$PASS" || free_memory_test_result="$FAIL"
    fi

    [[ "$launcher_memory" -le "$MAX_LAUNCHER_MEMORY_VGA" ]] \
      && launcher_memory_test_result="$PASS" \
      || launcher_memory_test_result="$FAIL"

    [[ "$kernel_memory" -le "$MAX_USED_KERNEL_MEMORY_VGA" ]] \
      && kernel_memory_test_result="$OPTIMAL" \
      || kernel_memory_test_result="$REDUCE"

    [[ "$system_server_memory" -le "$MAX_SYSTEM_SERVER_MEMORY_VGA" ]] \
      && system_server_memory_test_result="$OPTIMAL" \
      || system_server_memory_test_result="$REDUCE"

    [[ "$system_ui_memory" -le "$MAX_SYSTEM_UI_MEMORY_VGA" ]] \
      && system_ui_memory_test_result="$OPTIMAL" \
      || system_ui_memory_test_result="$REDUCE"

  elif [[ "$short_side" -le 480 && "$long_side" -le 854 ]]; then # wvga
    device_screen_type="$SCREEN_TYPE_WVGA"
    if [[ "$total_ram_size" -eq "$ONE_GB" ]]; then
      [[ "$free_memory" -ge "$MIN_FREE_MEMORY_FOR_ONE_GB_WVGA" ]] \
        && free_memory_test_result="$PASS" || free_memory_test_result="$FAIL"
    elif [[ "$total_ram_size" -eq "$FIVE_TWELVE_MB" ]]; then
      [[ "$free_memory" -ge "$MIN_FREE_MEMORY_FOR_FIVE_TWELVE_MB_WVGA" ]] \
        && free_memory_test_result="$PASS" || free_memory_test_result="$FAIL"
    fi

    [[ "$launcher_memory" -le "$MAX_LAUNCHER_MEMORY_WVGA" ]] \
      && launcher_memory_test_result="$OPTIMAL" \
      || launcher_memory_test_result="$REDUCE"

    [[ "$kernel_memory" -le "$MAX_USED_KERNEL_MEMORY_WVGA" ]] \
      && kernel_memory_test_result="$OPTIMAL" \
      || kernel_memory_test_result="$REDUCE"

    [[ "$system_server_memory" -le "$MAX_SYSTEM_SERVER_MEMORY_WVGA" ]] \
      && system_server_memory_test_result="$OPTIMAL" \
      || system_server_memory_test_result="$REDUCE"

    [[ "$system_ui_memory" -le "$MAX_SYSTEM_UI_MEMORY_WVGA" ]] \
      && system_ui_memory_test_result="$OPTIMAL" \
      || system_ui_memory_test_result="$REDUCE"

  elif [[ "$short_side" -le 540 && "$long_side" -le 960 ]]; then # qhd
    device_screen_type="$SCREEN_TYPE_QHD"
    if [[ "$total_ram_size" -eq "$ONE_GB" ]]; then
      [[ "$free_memory" -ge "$MIN_FREE_MEMORY_FOR_ONE_GB_QHD" ]] \
        && free_memory_test_result="$PASS" || free_memory_test_result="$FAIL"
    fi

    [[ "$launcher_memory" -le "$MAX_LAUNCHER_MEMORY_QHD" ]] \
      && launcher_memory_test_result="$PASS" \
      || launcher_memory_test_result="$FAIL"

    [[ "$kernel_memory" -le "$MAX_USED_KERNEL_MEMORY_QHD" ]] \
      && kernel_memory_test_result="$OPTIMAL" \
      || kernel_memory_test_result="$REDUCE"

    [[ "$system_server_memory" -le "$MAX_SYSTEM_SERVER_MEMORY_QHD" ]] \
      && system_server_memory_test_result="$OPTIMAL" \
      || system_server_memory_test_result="$REDUCE"

    [[ "$system_ui_memory" -le "$MAX_SYSTEM_UI_MEMORY_QHD" ]] \
      && system_ui_memory_test_result="$OPTIMAL" \
      || system_ui_memory_test_result="$REDUCE"

  else # "hd"
    device_screen_type="$SCREEN_TYPE_HD"
    if [[ "$total_ram_size" -eq "$ONE_GB" ]]; then
      [[ "$free_memory" -ge "$MIN_FREE_MEMORY_FOR_ONE_GB_HD" ]] \
        && free_memory_test_result="$PASS" || free_memory_test_result="$FAIL"
    fi

    [[ "$launcher_memory" -le "$MAX_LAUNCHER_MEMORY_HD" ]] \
      && launcher_memory_test_result="$PASS" \
      || launcher_memory_test_result="$FAIL"

    [[ "$kernel_memory" -le "$MAX_USED_KERNEL_MEMORY_HD" ]] \
      && kernel_memory_test_result="$OPTIMAL" \
      || kernel_memory_test_result="$REDUCE"

    [[ "$system_server_memory" -le "$MAX_SYSTEM_SERVER_MEMORY_HD" ]] \
      && system_server_memory_test_result="$OPTIMAL" \
      || system_server_memory_test_result="$REDUCE"

    [[ "$system_ui_memory" -le "$MAX_SYSTEM_UI_MEMORY_HD" ]] \
      && system_ui_memory_test_result="$OPTIMAL" \
      || system_ui_memory_test_result="$REDUCE"

  fi

  chipset_info=$(adb shell cat /proc/cpuinfo |grep -m 1 -i hardware|awk 'NF>1{print $NF}'|tr -d '\r'|| echo "")

  memory_carveout_test_result="N/A"
  case "$chipset_info" in
    "MT6580M")
      if [[ "$total_ram_size" -eq "$ONE_GB" ]]; then
        [[ "$memory_carveout" -le "$MAX_MEMORY_CARVEOUT_MT6580M_ONE_GB" ]] \
          && memory_carveout_test_result="$OPTIMAL" \
          || memory_carveout_test_result="$REDUCE"
      elif [[ "$total_ram_size" -eq "$FIVE_TWELVE_MB" ]]; then
        [[ "$memory_carveout" -le "$MAX_MEMORY_CARVEOUT_MT6580M_FIVE_TWELVE_MB" ]] \
          && memory_carveout_test_result="$OPTIMAL" \
          || memory_carveout_test_result="$REDUCE"
      fi
      ;;
    "MT6737M")
      if [[ "$total_ram_size" -eq "$ONE_GB" ]]; then
        [[ "$memory_carveout" -le "$MAX_MEMORY_CARVEOUT_MT6737M_ONE_GB" ]] \
          && memory_carveout_test_result="$OPTIMAL" \
          || memory_carveout_test_result="$REDUCE"
      elif [[ "$total_ram_size" -eq "$FIVE_TWELVE_MB" ]]; then
        [[ "$memory_carveout" -le "$MAX_MEMORY_CARVEOUT_MT6737M_FIVE_TWELVE_MB" ]] \
          && memory_carveout_test_result="$OPTIMAL" \
          || memory_carveout_test_result="$REDUCE"
      fi
      ;;
    "MT6739-ENG")
      if [[ "$total_ram_size" -eq "$ONE_GB" ]]; then
        [[ "$memory_carveout" -le "$MAX_MEMORY_CARVEOUT_MT6739_ENG_ONE_GB" ]] \
          && memory_carveout_test_result="$OPTIMAL" \
          || memory_carveout_test_result="$REDUCE"
      elif [[ "$total_ram_size" -eq "$FIVE_TWELVE_MB" ]]; then
        [[ "$memory_carveout" -le "$MAX_MEMORY_CARVEOUT_MT6739_ENG_FIVE_TWELVE_MB" ]] \
          && memory_carveout_test_result="$OPTIMAL" \
          || memory_carveout_test_result="$REDUCE"
      fi
      ;;
    "MSM8909")
      if [[ "$total_ram_size" -eq "$ONE_GB" ]]; then
        [[ "$memory_carveout" -le "$MAX_MEMORY_CARVEOUT_MSM8909_ONE_GB" ]] \
          && memory_carveout_test_result="$OPTIMAL" \
          || memory_carveout_test_result="$REDUCE"
      elif [[ "$total_ram_size" -eq "$FIVE_TWELVE_MB" ]]; then
        [[ "$memory_carveout" -le "$MAX_MEMORY_CARVEOUT_MSM8909_FIVE_TWELVE_MB" ]] \
          && memory_carveout_test_result="$OPTIMAL" \
          || memory_carveout_test_result="$REDUCE"
      fi
      ;;
    "MSM8917")
      if [[ "$total_ram_size" -eq "$ONE_GB" ]]; then
        [[ "$memory_carveout" -le "$MAX_MEMORY_CARVEOUT_MSM8917_ONE_GB" ]] \
          && memory_carveout_test_result="$OPTIMAL" \
          || memory_carveout_test_result="$REDUCE"
      elif [[ "$total_ram_size" -eq "$FIVE_TWELVE_MB" ]]; then
        [[ "$memory_carveout" -le "$MAX_MEMORY_CARVEOUT_MSM8917_FIVE_TWELVE_MB" ]] \
          && memory_carveout_test_result="$OPTIMAL" \
          || memory_carveout_test_result="$REDUCE"
      fi
      ;;
    *)
    ;;
  esac

  echo "Build approval metrics (Tested in GTS)"
  echo "Device screen type: $device_screen_type"
  echo "Free memory test: $free_memory_test_result"
  echo "Launcher memory test: $launcher_memory_test_result"
  echo
  echo "Metrics impacting free memory and persistent memory"
  echo "Kernel memory test: $kernel_memory_test_result"
  echo "System server memory test: $system_server_memory_test_result"
  echo "System UI memory test: $system_ui_memory_test_result"
  echo "Memory carveout test: $memory_carveout_test_result"
}

get_post_boot_metrics() {
  local meminfo_text="$1"

  cached_process_array=($(echo "$meminfo_text" |awk '/Total PSS by category:/{found=0} {if(found) print} /: Cached/{found=1}'|tr -d '\r'|tr -d ' '))
  mem_available=($(adb shell cat /proc/meminfo| grep 'MemAvailable:'))

  if [[ "${#mem_available[@]}" -le 1 ]]; then
    echo "Error parsing meminfo. Exiting ..."
    exit 1
  fi

  cache_proc_dirty=${mem_available[1]}

  if [[ $debug -eq 1 ]]; then
    declare -p cached_process_array
  fi

  for i in "${!cached_process_array[@]}"; do
    pid=$(echo "${cached_process_array[$i]}"|cut -d '(' -f 2|tr -d 'pid)')
    process_cache_info=$(adb shell dumpsys meminfo "$pid"|grep 'TOTAL'||echo "")
    if [[ -z "$process_cache_info" ]]; then
      continue
    fi
    cache=($process_cache_info)

    if [[ "${#cache[@]}" -le 3 ]]; then
      echo "Error parsing dumpsys meminfo $pid. Exiting ..."
      exit 1
    fi

    cache_proc_dirty=$((cache_proc_dirty+${cache[2]}+${cache[3]}))
  done

  android_build_fingerprint=$(adb shell getprop "ro.build.fingerprint"|tr "/" "_"|tr -d '\r')
  echo "Device serial: $device_serial"
  echo "Build fingerprint: $android_build_fingerprint"
  echo "MemAvailable: ${mem_available[1]} KB"
  echo "MemAvailable + Dirty Cache: $cache_proc_dirty KB"

  launcher_memory=$(echo "$meminfo_text"|grep -m 1 "launcher"|cut -d ':' -f 1|awk '{$1=$1;print}'|cut -d ' ' -f 1|tr -d ',K' || echo 0)
  echo "Launcher Memory: $launcher_memory KB"

  kernel_memory=$(echo "$meminfo_text"|grep "Used RAM:"|cut -d '+' -f 2|awk '{$1=$1;print}'|cut -d ' ' -f 1|tr -d ',K' || echo 0)
  echo "Kernel Memory: $kernel_memory KB"

  system_server_memory=$(echo "$meminfo_text"|grep -m 1 "system ("|cut -d ':' -f 1|awk '{$1=$1;print}'|cut -d ' ' -f 1|tr -d ',K' || echo 0)
  echo "System server memory: $system_server_memory KB"

  system_ui_memory=$(echo "$meminfo_text"|grep -m 1 "com.android.systemui"|cut -d ':' -f 1|awk '{$1=$1;print}'|cut -d ' ' -f 1|tr -d ',K' || echo 0)
  echo "System UI Memory: $system_ui_memory KB"

  total_ram=$(echo "$meminfo_text"|grep -m 1 "Total RAM:"|cut -d '(' -f 1|cut -d ':' -f 2|awk '{$1=$1;print}'|tr -d ',kBK' || echo 0)
  if [[ "$total_ram" -gt "$FIVE_TWELVE_MB" && "$total_ram" -le "$ONE_GB" ]]; then
    memory_carveout=$((ONE_GB-total_ram))
    pss_metrics_test_results=$(test_pss_metrics \
      "$ONE_GB" \
      "$cache_proc_dirty" \
      "$kernel_memory" \
      "$system_server_memory" \
      "$system_ui_memory" \
      "$launcher_memory" \
      "$memory_carveout")
  elif [[ "$total_ram" -lt "$FIVE_TWELVE_MB" && "$total_ram" -gt 0 ]]; then
    memory_carveout=$((FIVE_TWELVE_MB-total_ram))
    pss_metrics_test_results=$(test_pss_metrics \
      "$FIVE_TWELVE_MB" \
      "$cache_proc_dirty" \
      "$kernel_memory" \
      "$system_server_memory" \
      "$system_ui_memory" \
      "$launcher_memory" \
      "$memory_carveout")
  else
    pss_metrics_test_results="Pss metrics test: N/A"
    memory_carveout=0
  fi

  if [[ "$memory_carveout" -gt 0 ]]; then
    echo "Memory Carveout: $memory_carveout KB"
  fi

  persistent_memory=$(echo "$meminfo_text"|grep -m 1 ": Persistent"|cut -d ':' -f 1|awk '{$1=$1;print}'|cut -d ' ' -f 1|tr -d ',K' || echo 0)
  echo "Total persistent Memory: $persistent_memory KB"
  [[ "$persistent_memory" -le "$MAX_PERSISTENT_MEMORY" ]] && persistent_memory_test_result="$PASS" || persistent_memory_test_result="$FAIL"

  persistent_processes_array=($(echo "$meminfo_text"|awk '/: Foreground/{found=0} {if(found) print} /: Persistent/{found=1}'|tr -d ' '))
  for j in "${!persistent_processes_array[@]}"; do
    if [[ "$j" -eq 0 ]]; then
      echo ""
      echo "--------------------"
      echo "Persistent processes"
      echo "--------------------"
    fi
    echo "    $(echo "${persistent_processes_array[$j]}"|cut -d '(' -f 1)"
  done

  echo ""
  echo "----------------------------------------------------------------------"
  echo "$pss_metrics_test_results"
  echo "Persistent memory test : $persistent_memory_test_result"
  echo "----------------------------------------------------------------------"
}

#=====================
# Main entry point
#=====================
parse_arguments "$@"
# use metrics file suffix from parameter if available
metrics_file_suffix="${metrics_file_suffix:-$SCRIPT_INVOCATION_TIME}"
get_device_serial
os_version=$(adb shell getprop ro.build.version.release|cut -d '.' -f 1)
# Reboot device and wait for it to come online.
echo ""
echo "Rebooting device"
adb reboot
wait_for_device
adb shell wm dismiss-keyguard
adb shell svc power stayon true
echo "Sleeping for $wait_time seconds before taking measurement"
sleep "$wait_time"

if [[ $os_version =~ "$NUMBER_RE" && "$os_version" -ge 8 ]]; then
  meminfo_text=$(adb shell dumpsys -t 30 meminfo)
else
  meminfo_text=$(adb shell dumpsys meminfo)
fi

if [[ $debug -eq 1 ]]; then
  echo ""
  echo "------------------------------- DEBUG INFO START ------------------------------- "
  echo "$meminfo_text"
  echo "------------------------------- DEBUG INFO END ------------------------------- "
fi

echo ""
post_boot_metrics=$(get_post_boot_metrics "$meminfo_text")
echo "----------------------------------------"
echo "                RESULTS                 "
echo "----------------------------------------"
echo "$post_boot_metrics"

if ! mkdir -p "$metrics_results_dir"; then
  echo >&2 "Unable to create metrics result directory: $metrics_results_dir"
  exit 1
fi

metrics_results_path="$metrics_results_dir/post_boot_metrics-$metrics_file_suffix.txt"

echo ""
echo "Writing results to $metrics_results_path"
echo ""
echo "$post_boot_metrics" > "$metrics_results_path"
