#!/bin/bash
# Checks if an Android Go device passes F2FS tests.

set -euo pipefail

readonly TEMP_DIR="/data/local/tmp/"
readonly PASS="PASS"
readonly FAIL="FAIL"

device_serial=""
debug=${DEBUG:-0}
check_f2fs_path="./check_f2fs"
f2fs_results_dir="./summary_results"
f2fs_file_suffix=""

# The number of seconds since the epoch, it is used for making f2fs results
# filename unique.
SCRIPT_INVOCATION_TIME=$(date +%s)

usage() {
  cat <<EOF
Usage: "$(basename "${BASH_SOURCE[0]}")" [OPTION]...

-h, --help                  usage information (this)
-p, --check_f2fs_path       path of check_f2fs binary
-d, --f2fs_results_dir      directory to store f2fs results
-s, --f2fs_file_suffix      used for making f2fs result filename unique

Example:
  $(basename "${BASH_SOURCE[0]}") -p $check_f2fs_path
EOF
}

parse_arguments() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)
        usage
        exit 0
        ;;
      -p|--check_f2fs_path)
        check_f2fs_path=${2:-""}
        shift
        ;;
      -d|--f2fs_results_dir)
        f2fs_results_dir=${2:-""}
        [[ -z "$f2fs_results_dir" ]] \
          && echo "Results dir is not specified." && exit 1
        shift
        ;;
      -s|--f2fs_file_suffix)
        f2fs_file_suffix=$2
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

test_f2fs() {
  local check_f2fs_text="$1"

  f2fs_support_info=$(echo "$check_f2fs_text" |awk '/# Test 1:/{found=0} {if(found) print} /# Test 0:/{found=1}')

  has_f2fs_support=$(echo "$f2fs_support_info"|grep -m 1 "f2fs"||echo "")

  [[ -n "$has_f2fs_support" ]] \
    && f2fs_support_test_result="$PASS" || f2fs_support_test_result="$FAIL"

  f2fs_support_on_userdata_info=$(echo "$check_f2fs_text" |awk '/# Test 2:/{found=0} {if(found) print} /# Test 1:/{found=1}')

  has_data_type_f2fs_on=$(echo "$f2fs_support_on_userdata_info"|grep -m 1  "on /data type f2fs"||echo "")
  has_feat_encryption=$(echo "$f2fs_support_on_userdata_info"|grep -m 1  "encryption"||echo "")
  has_feat_quota=$(echo "$f2fs_support_on_userdata_info"|grep -m 1  "quota_ino"||echo "")
  has_feat_atomic_write=$(echo "$f2fs_support_on_userdata_info"|grep -m 1  "atomic_write"||echo "")
  has_uptodate_atomic_write=$(echo "$f2fs_support_on_userdata_info"|grep -A 2 -m 1 "Balancing F2FS Async:"|tail -1|grep "atomic IO:"||echo "")
  has_ipu_policy=$(echo "$f2fs_support_on_userdata_info"|grep -m 1 "/ipu_policy"||echo "")
  has_discard_granularity=$(echo "$f2fs_support_on_userdata_info"|grep -m 1 "/discard_granularity"||echo "")

  [[ -n "$has_data_type_f2fs_on" \
    && -n "$has_feat_encryption" \
    && -n "$has_feat_quota" \
    && -n "$has_feat_atomic_write" \
    && -n "$has_uptodate_atomic_write" \
    && -n "$has_ipu_policy" \
    && -n "$has_discard_granularity" ]] \
    && f2fs_status_on_userdata_test_result="$PASS" || f2fs_status_on_userdata_test_result="$FAIL"

  [[ -n "$has_ipu_policy" ]] \
    && ipu_policy=$(echo "$f2fs_support_on_userdata_info"|grep -A 1 -m 1  "ipu_policy"|tail -1||echo 0) || ipu_policy="$FAIL"
  [[ -n "$has_discard_granularity" ]] \
    && discard_granularity=$(echo "$f2fs_support_on_userdata_info"|grep -A 1 -m 1  "discard_granularity"|tail -1||echo 0) || discard_granularity="$FAIL"

  atomic_write_on_userdata_info=$(echo "$check_f2fs_text" |awk '/# Test 3:/{found=0} {if(found) print} /# Test 2:/{found=1}')

  has_atomic_write_on_user_data=$(echo "$atomic_write_on_userdata_info"|grep -m 1 "inmem:    2, atomic IO:    1 "||echo "")
  [[ -n "$has_atomic_write_on_user_data" ]] \
    && atomic_write_on_user_data_test_result="$PASS" || atomic_write_on_user_data_test_result="$FAIL"

  atomic_write_on_sdcard_info=$(echo "$check_f2fs_text" |awk '/# Test 4:/{found=0} {if(found) print} /# Test 3:/{found=1}')

  has_atomic_write_on_sdcard=$(echo "$atomic_write_on_sdcard_info"|grep -m 1 "inmem:    2, atomic IO:    1 "||echo "")

  [[ -n "$has_atomic_write_on_sdcard" ]] \
    && atomic_write_on_sdcard_test_result="$PASS" || atomic_write_on_sdcard_test_result="$FAIL"

  bad_write_call_test=$(echo "$check_f2fs_text" |awk '/# Test 4:/{found=1} {if(found) print}')
  bad_write_call_result=$(echo "$bad_write_call_test"|grep -m 1 "FAIL: missing patch"||echo "$PASS")

  if [[ "$debug" -eq 1 ]]; then
    echo ""
    echo "------------------------------------DEBUG INFO START------------------------------------"
    echo "has_f2fs_support: $has_f2fs_support"
    echo "has_data_type_f2fs_on: $has_data_type_f2fs_on"
    echo "has_feat_encryption: $has_feat_encryption"
    echo "has_feat_quota: $has_feat_quota"
    echo "has_feat_atomic_write: $has_feat_atomic_write"
    echo "has_uptodate_atomic_write: $has_uptodate_atomic_write"
    echo "has_atomic_write_on_user_data: $has_atomic_write_on_user_data"
    echo "has_atomic_write_on_sdcard: $has_atomic_write_on_sdcard"
    echo "bad_write_call_test: $bad_write_call_test"
    echo "-------------------------------------DEBUG INFO END-------------------------------------"
    echo ""
  fi

  android_build_fingerprint=$(adb shell getprop "ro.build.fingerprint"|tr "/" "_"|tr -d '\r')
  echo "Device serial: $device_serial"
  echo "Build fingerprint: $android_build_fingerprint"
  echo "F2FS support: $f2fs_support_test_result"
  echo "F2FS status on /userdata: $f2fs_status_on_userdata_test_result"
  echo "Ipu policy: $ipu_policy"
  echo "Discard granularity: $discard_granularity"
  echo "Atomic write on /userdata: $atomic_write_on_user_data_test_result"
  echo "Atomic write on /sdcard: $atomic_write_on_sdcard_test_result"
  echo "Bad Write(2) Call: $bad_write_call_result"
}

#=====================
# Main entry point
#=====================
parse_arguments "$@"
get_device_serial
# if we do not have check_f2fs file path, exit early with an error
[[ -z "$check_f2fs_path" ]] \
  && echo "check_f2fs path is not specified." && exit 1
[[ ! -f $check_f2fs_path ]] \
  && echo "$check_f2fs_path does not exist." && exit 1

# use f2fs results file suffix from parameter if available
f2fs_file_suffix="${f2fs_file_suffix:-$SCRIPT_INVOCATION_TIME}"

push_results=$(adb push "$check_f2fs_path" "$TEMP_DIR")

if [[ "$push_results" != *"1 file pushed"* ]]; then
  echo "Failed to push $check_f2fs_path to $TEMP_DIR. Exiting ..."
  exit 1
fi

# Need to run as root to access f2fs data
adb root>/dev/null

check_f2fs_text=$(adb shell "$TEMP_DIR"check_f2fs)

f2fs_test_results=$(test_f2fs "$check_f2fs_text")
echo
echo "----------------------------------------"
echo "                RESULTS                 "
echo "----------------------------------------"
echo "$f2fs_test_results"

adb shell rm "$TEMP_DIR/check_f2fs"

if ! mkdir -p "$f2fs_results_dir"; then
  echo >&2 "Unable to create f2fs result directory: $f2fs_results_dir"
  exit 1
fi

f2fs_results_path="$f2fs_results_dir/f2fs_test_results-$f2fs_file_suffix.txt"

echo ""
echo "Writing results to $f2fs_results_path"
echo ""
echo "$f2fs_test_results" > "$f2fs_results_path"
