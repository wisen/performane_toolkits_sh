#!/bin/bash
set -euo pipefail

# Default configurable values
# User can write a config file that overrides these values.
# The config file will be `source`-ed
# To test:
# ./test_app.sh                 # prints the menu options to run tests
# ./test_app.sh -c 1            # should run first config
# ./test_app.sh --config chrome # should run chrome config
# ./test_app.sh --config config # should run first config since this matches all files
# ./test_app.sh -p com.android.chrome -a \
#     org.chromium.chrome.browser.ChromeTabbedActivity -n 1
package=""
activity=""
number_of_runs=10
delay="5s"
simpleperf_events="cpu-cycles,cache-misses,page-faults"
simpleperf_duration=3
package_to_profile=""
is_custom_package_to_profile=0
csv_dir="./test_results"
systrace_dir="./systrace_results"
drop_caches=3
device_serial=""
quiet_mode=0
speed_profile=1
summary_file_suffix=""
maximize_cpu_freq=1
maximize_gpu_freq=0
trace2html_path=""
trace_buffer_size=48000

readonly NUMBER_RE="^[0-9]+([.][0-9]+)?$"

# default directory path for storing average of run results
summary_results_dir="./summary_results"
CONFIG_DIR="test_app_config"
CONFIG_FILE_PATTERN="*.config"
# the configuration this script should run with
config_file=""

# an array of config files we found to display in the menu
CONFIG_FILES=
# number of configuration files found
NUM_CONFIG=0

# the kinds of test this script can run
APP_START_TEST="app-start"
MEMINFO_TEST="meminfo"
DEVICE_MEMORY_TEST="device-memory"
DEVICE_CONFIGS_TEST="device-configs"
MEMCG_TEST="memcg"
GFXINFO_TEST="gfxinfo"
SIMPLEPERF_TEST="simpleperf"
APP_ASSOCIATIONS="app-associations"
SYSTRACE="systrace"

# Specify the tests this script will run in this config file
TESTS_TO_RUN_CONFIG_FILE="test_to_run.config"
TESTS_TO_RUN_CONFIG_PATH="$CONFIG_DIR/$TESTS_TO_RUN_CONFIG_FILE"
# By default, this script runs all tests
# The individual package file can overwrite this script-wide configuration
# by setting the tests_to_run configuration parameter
tests_to_run="$APP_START_TEST,$MEMINFO_TEST,$DEVICE_MEMORY_TEST,"`
`"$DEVICE_CONFIGS_TEST,$MEMCG_TEST,$GFXINFO_TEST,$SIMPLEPERF_TEST,"`
`"$APP_ASSOCIATIONS","$SYSTRACE"

# write user specified config into a file
# this is set if the user selects the menu option to input config
SHOULD_WRITE_CUSTOM_CONFIG=false

# The number of seconds since the epoch, it is used for making csv filename
# unique.
SCRIPT_INVOCATION_TIME=$(date +%s)

# summary headers for summary csv files
readonly APP_START_TEST_SUMMARY_CSV_HEADER="Serial number,Build fingerprint,"`
`"Ram size,Package name,Version code,Time to start app,Time to start app SD"
readonly MEMINFO_TEST_SUMMARY_CSV_HEADER="Serial number,Build fingerprint,"`
`"Ram size,Package name,Version code,Java heap usage,Java heap SD,"`
`"Native heap usage,Native heap SD,Code heap usage,"`
`"Code heap SD,Graphics heap usage,Graphics heap SD,"`
`"Private dirty,Private dirty SD,Pss,Pss SD"
readonly MEMCG_TEST_SUMMARY_CSV_HEADER="Serial number,Build fingerprint,"`
`"Ram size,Package name,Version code,Cache,Rss,Rss huge,"`
`"Mapped file,Writeback,Swap,Pgpgin,"`
`"Pgpgout,Pgfault,Pgmajfault,Inactive anon,"`
`"ActiveAnon,Inactive file,Active file,Unevictable"
readonly GFXINFO_TEST_SUMMARY_CSV_HEADER="Serial number,Build fingerprint,"`
`"Ram size,Package name,Version code,Frames rendered,Janky frames,"`
`"50th percentile ms,90th percentile ms,95th percentile ms,99th percentile ms,"`
`"Number Missed VSync,Number High input latency,Number Slow UI thread,"`
`"Number Slow bitmap uploads,Number Slow issue draw commands,"`
`"Memory usage,TextureCache,Layers total,"`
`"RenderBufferCache,GradientCache,PathCache,"`
`"TessellationCache,TextDropShadowCache,PatchCache,"`
`"FontRenderer total"
readonly SIMPLEPERF_TEST_SUMMARY_CSV_HEADER="Serial number,Build fingerprint,"`
`"Ram size,Package name,Version code,Cpu cycles,Cache misses,"`
`"Page faults"
readonly DEVICE_MEMORY_TEST_SUMMARY_CSV_HEADER="Serial number,"`
`"Build fingerprint,Ram size,Package name,Version code,Total memory on device,"`
`"Used mem,Used mem SD,Free mem,Free mem SD,Total swap on device,Used swap,"`
`"Used swap SD,Free swap,Free swap SD"
readonly DEVICE_CONFIGS_TEST_SUMMARY_CSV_HEADER="Serial number,"`
`"Build fingerprint,Ram size,Crypto State,Has engineermode,Has F2FS"

# headers for csv written for each test
readonly APP_START_TEST_CSV_HEADER="Time to start app"
readonly MEMINFO_TEST_CSV_HEADER="Java heap usage,"`
`"Native heap usage,Code heap usage,Graphics heap usage,"`
`"Private dirty,Pss"
readonly DEVICE_MEMORY_TEST_CSV_HEADER="Used mem,Free mem,Used swap,Free swap"
readonly MEMCG_TEST_CSV_HEADER="Cache,Rss,Rss huge,"`
`"Mapped file,Writeback,Swap,Pgpin,Pgpout,"`
`"Pgfault,Pgmajfault,Inactive anon,ActiveAnon,"`
`"Inactive file,Active file,Unevictable"
readonly GFXINFO_TEST_CSV_HEADER="Frames rendered,Janky frames,"`
`"50th percentile,50th percentile,50th percentile,50th percentile,"`
`"Number Missed VSync,Number High input latency,Number Slow UI thread,"`
`"Number Slow bitmap uploads,Number Slow issue draw commands,"`
`"Memory usage,TextureCache,Layers total,"`
`"RenderBufferCache,GradientCache,PathCache,"`
`"TessellationCache,TextDropShadowCache,PatchCache,"`
`"FontRenderer total"
readonly SIMPLEPERF_TEST_CSV_HEADER="Cpu cycles,Cache misses,"`
`"Page faults"

# Find configuration files in current working directory.
# Configuration files end in '.config'.
find_configs() {
  # find all configs, excluding TESTS_TO_RUN_CONFIG_FILE so we don't
  # print it in the menu
  CONFIG_FILES=($(find "$CONFIG_DIR" -name "$CONFIG_FILE_PATTERN" | grep -v "$TESTS_TO_RUN_CONFIG_FILE"|sort))
  NUM_CONFIG=${#CONFIG_FILES[@]}
}

print_custom_config_usage() {
  echo "  Usage:"
  echo "  <package name> <activity name> <number of runs> <delay> <package to profile>"
  echo "  Example:"
  echo "  com.google.android.gm.lite com.google.android.gm.ConversationListActivityGmail 4 4s com.android.systemui"
  echo "------------------------------------------------------------------------------------------------------------"
}

# Print out a menu showing all available configuration.
print_menu() {
  # if no config files were found we skip printing the menu
  [[ $NUM_CONFIG -eq 0 ]] && return

  i=1
  indent="  "
  echo "Found the following config files:"
  for file in "${CONFIG_FILES[@]}"
  do
    echo "$indent[$i] $(basename "$file")"
    i=$((i+1))
  done

  # the last option is for user to enter config values on a single line
  echo "$indent[$i] Enter your own configuration values in the form of following:"
  print_custom_config_usage
}

# User's selected menu option
selection=
get_selection() {
  # if no config files are found, there's nothing to select, so skip this
  [[ $NUM_CONFIG -eq 0 ]] && return
  echo ""
  echo -n "Select configuration to run: [1-$((NUM_CONFIG + 1))] "
  read selection
}

# Write user specified config to file so next time it will be easier to run.
# Should only be called after user selects to enter custom config.
write_custom_config_to_file() {
  mkdir -p "$CONFIG_DIR"
  filename="$CONFIG_DIR/$package.config"
  cat <<-END > $filename
package=$package
activity=$activity
number_of_runs=$number_of_runs
delay=$delay
simpleperf_events=$simpleperf_events
simpleperf_duration=$simpleperf_duration
package_to_profile=${package_to_profile:-$package}
drop_caches=$drop_caches
END
  echo "Your custom configuration has been written to $filename"
}

# Gather configuration values from user
gather_configuration_from_user() {
  local _number_of_runs _delay _package_to_profile
  if [[ $NUM_CONFIG -eq 0 ]]; then
    print_custom_config_usage
  fi
  echo "Enter config:"
  # read in values by user, but do not override the default values
  read package activity _number_of_runs _delay _package_to_profile

  # ensure that required parameters are provided
  [[ "$package" == "" ]] && echo "Package not specified" 1>&2 && exit 1
  [[ "$activity" == "" ]] && echo "Activity not specified" 1>&2 && exit 1

  # ensure that we have a valid value to override
  [[ "$_number_of_runs" != "" ]] && number_of_runs="$_number_of_runs"
  [[ "$_delay" != "" ]] && delay="$_delay"
  if [[ -n "$_package_to_profile" ]]; then
    is_custom_package_to_profile=1
  else
    is_custom_package_to_profile=0
  fi
  package_to_profile=${_package_to_profile:-$package}
}

# Set config based on values in config file
source_config() {
  # selection is 1-based, but array access is 0-based
  index=$((${selection:-1} - 1))
  config_file=${CONFIG_FILES[$index]}
  if [[ $quiet_mode -lt 2 ]]; then
    echo "Using configuration from $config_file"
  fi
  # sanity check, the config file should exit
  [[ -f $config_file ]] || (echo "Configuration $config_file cannot be found" 1&>2 && exit 1)
  source $config_file

  # if this config file is not found, create it and write with default values
  if [[ ! -f "$TESTS_TO_RUN_CONFIG_PATH" ]]; then
    cat <<-EOF > $TESTS_TO_RUN_CONFIG_PATH
# Specify tests that test_app will run.
# Valid values are app, device, gfxinfo, memcg, simpleperf.
# Example:
#   tests_to_run=app,device,gfxinfo
tests_to_run=$tests_to_run
EOF
  fi
  source "$TESTS_TO_RUN_CONFIG_PATH"
}

# Set config values needed for this script
set_config() {
  # if the selection is not a configuration file, let the user input values
  if [[ "$selection" == "" || "$selection" -gt "$NUM_CONFIG" ]]; then
    gather_configuration_from_user
    SHOULD_WRITE_CUSTOM_CONFIG=true
    source "$TESTS_TO_RUN_CONFIG_PATH"
  else
    source_config
  fi
}

# Checks if test should be run given the current configuration.
# Right now this is just a simple grep check, will not work
# correctly if test names have substring matches.
# Arguments
#   test name
should_run_test() {
  echo "$tests_to_run" | grep -q "$1"
}

validate_selection() {
  local config_line
  # if selection is not a number, find the index of the config file,
  # otherwise use the config index entered by user
  if [[ ! "$selection" =~ ^[0-9]+$ ]]; then
    if config_line=$(echo "${CONFIG_FILES[@]}" | tr ' ' '\n' | grep -n "$selection"); then
      selection=$(echo "$config_line" | cut -d ':' -f 1 | head -n 1)
    else
      echo "Configuration $selection not found" >&2
      exit 1
    fi
  fi
}

usage() {
  cat <<EOF
Usage: "$(basename "${BASH_SOURCE[0]}")" [OPTION]...
-a, --activity                  activity of the app to test
-b, --trace_buffer_size         trace buffer size in KB
                                only used if tracing is enabled in test_app_config
-c, --config                    config file to read
    --csv_dir                   write stats in csv format to files in this
                                directory, one file for each test
                                defaults to "./test_results"
-d, --delay                     delay after app start to take measurement
-f, --trace2html_path           path to trace2html tool
                                e.g. /tmp/trace2html/catapult/tracing/bin/trace2html
                                See: https://github.com/catapult-project/catapult
                                only used if tracing is enabled in test_app_config
-g, --maximize_gpu_freq         whether gpu frequency should be maximized,
                                supported values: 0, 1
                                defaults to 0, use 1 to enable it
-h, --help                      usage information (this)
-n, --number_of_runs            number of runs
-o, --trace_points              comma separated trace points
                                e.g. sched,freq,idle,am,wm,res,gfx,view,sync,irq,hal,workq,dalvik,pagecache,binder_driver
                                On pre-O devices device we should exclude following:
                                pagecache,binder_driver

-p, --package                   package of the app to test
-r, --package_to_profile        package to profile
-t, --tests_to_run              tests to run
-s, --summary_results_dir       directory to store summary app results
-u, --maximize_cpu_freq         whether cpu frequency should be maximized,
                                supported values: 0, 1
                                defaults to 1, use 0 to disable it
    --simpleperf_events         simpleperf events which need to measured
    --simpleperf_duration       simpleperf run duration in second
    --drop_caches               frees caches, supported values: 1, 2, 3
                                1 to free pagecache
                                2 to free dentries and inodes
                                3 to free pagecache, dentries and inodes
    --device_serial             the serial number of the device
    --quiet_mode                quiet mode can be used to control amount of
                                console output, supported values: 0, 1, 2
                                0 to show all output
                                1 to hide only iteration output
                                2 to hide both iteration and summary output
    --speed_profile             whether app should be speed-profile compiled
                                or not. Defaults to 1, supported values 0, 1
                                0 Do not speed-profile compile app
                                1 speed-profile compile app
    --summary_file_suffix       used for making summary csv filename unique
EOF
}

parse_arguments() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -a|--activity)
        activity=$2
        shift
        ;;
      -b|--trace_buffer_size)
        trace_buffer_size=$2
        shift
        ;;
      -c|--config)
        # specify either the index of config file (as it appears in the menu)
        # or the config file name (partial match)
        selection=$2
        shift
        ;;
      -d|--delay)
        delay=$2
        shift
        ;;
      -f|--trace2html_path)
        trace2html_path=$2
        shift
       ;;
      -g|--maximize_gpu_freq)
        maximize_gpu_freq=$2
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      -n|--number_of_runs)
        number_of_runs=$2
        shift
        ;;
      -o|--trace_points)
        trace_points=$2
        shift
        ;;
      -p|--package)
        package=$2
        shift
        ;;
      -r|--package_to_profile)
        package_to_profile=$2
        shift
        ;;
      -t|--tests_to_run)
        tests_to_run=$2
        shift
        ;;
      -s|--summary_results_dir)
        summary_results_dir=$2
         shift
         ;;
      -u|--maximize_cpu_freq)
        maximize_cpu_freq=$2
        shift
        ;;
      --csv_dir)
        csv_dir=$2
        shift
        ;;
      --simpleperf_events)
        simpleperf_events=$2
        shift
        ;;
      --simpleperf_duration)
        simpleperf_duration=$2
        shift
        ;;
      --drop_caches)
        drop_caches=$2
        shift
        ;;
      --device_serial)
        device_serial=$2
        shift
        ;;
      --quiet_mode)
        quiet_mode=$2
        shift
        ;;
      --speed_profile)
        speed_profile=$2
        shift
        ;;
      --summary_file_suffix)
        summary_file_suffix=$2
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

# Get the path to csv file for a test
# Arguments:
#   name of test
#   package name
path_to_csv() {
  if [[ -z "$csv_dir" ]]; then
    echo >&2 "want to write csv but csv_dir is not set, try --csv_dir=path"
    exit 1
  fi
  if ! mkdir -p "$csv_dir"; then
    echo >&2 "unable to create csv_dir: $csv_dir"
    exit 1
  fi
  echo "$csv_dir/$1-$2-$app_version_code-$device_serial-$android_build_fingerprint-$mem_total-$SCRIPT_INVOCATION_TIME.csv"
}

# Ensures that a csv file for a test exists.
# If the file does not exist, create the file and write csv headers,
# if headers are specified.
# Arguments:
#   path to csv
#   headers for the csv, optional
ensure_csv() {
  [[ -e "$1" ]] && return
  touch "$1"
  [[ -z "$2" ]] || echo "$2" > "$1"
}

# Join all arguments by a string
# Arguments:
#   separator
#   arguments to join together using separator
join_by() {
  local IFS="$1"
  shift
  echo "$*"
}

# Writes a line of test results to csv file
# Arguments:
#   name of test
#   header
#   package name
#   values to write to, will be joined by comma
write_to_csv() {
  local name="$1" header="$2" _package="$3" csv_file
  shift 3

  if [[ -n "$csv_dir" ]]; then
    csv_file=$(path_to_csv "$name" "$_package")
    ensure_csv "$csv_file" "$header"
    join_by "," "$@" >> "$csv_file"
  fi
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

unlock_device() {
  is_display_on=$(adb shell dumpsys power|grep "mHoldingDisplaySuspendBlocker"|cut -d '=' -f 2)
  if [[ "$is_display_on" = "false" ]]; then
    adb shell input keyevent 26
  fi
  adb shell wm dismiss-keyguard
  adb shell svc power stayon usb
}

# In order for profiles to be generate we should have the app open for at
# least 40s. We are waiting for 60s here. Adding SIGUSR1 command before
# speed-profile compilation ensures that the profiles are written.
speed_profile_app() {
  os_version=$(adb shell getprop ro.build.version.release|cut -d '.' -f 1)
  if [[ $os_version =~ "$NUMBER_RE" && "$os_version" -lt 7 ]]; then
    return
  fi

  echo "Preparing to compile ${package}.apk : $device_serial"
  adb shell am start -S -W "$package/$activity">/dev/null

  echo "Waiting to start speed profile .... : $device_serial"
  sleep 60s
  pids_to_profile_text=$(adb shell dumpsys activity processes "$package"|grep "PID #"|cut -d '{' -f 2|cut -d '/' -f 1|cut -d ' ' -f 2|cut -d ':' -f1)

  pids_to_profile_array=($(echo "$pids_to_profile_text"))

  if [[ "${#pids_to_profile_array[@]}" -lt 1 ]]; then
    "Unable to find pid of $package. Exiting ..."
    exit 1
  fi

  pid="${pids_to_profile_array[0]}"

  if [[ -z "$pid" ]]; then
    echo "Unable to find pid of $package. Exiting ..."
    exit 1
  fi

  adb shell kill -s SIGUSR1 "$pid"
  stop_status=$(adb shell am force-stop "$package")
  adb shell "echo 3 > /proc/sys/vm/drop_caches"

  echo "Speed profile compiling ${package} : $device_serial"
  compiled=$(adb shell cmd package compile -m speed-profile -f "${package}")
  echo "Compilation ${compiled} : $device_serial"

  # first run post speed profile results in values that are outliers
  # ignoring the first run of the app
  adb shell am start -S -W "$package/$activity">/dev/null
  sleep 15s
}

maximize_gpu_frequency() {
  if [[ $maximize_gpu_freq -eq 1 ]]; then
    has_vcore_debug=$(adb shell cat /sys/power/vcorefs/vcore_debug 2>/dev/null||echo "")
    if [[ -n "$has_vcore_debug" ]]; then
      adb shell "echo KIR_SYSFS 0 > /sys/power/vcorefs/vcore_debug"
    else
      [[ $debug -eq 1 ]] && echo "/sys/power/vcorefs/vcore_debug does not exist"
    fi

    has_gpufreq_opp_freq=$(adb shell cat /proc/gpufreq/gpufreq_opp_freq 2>/dev/null||echo "")
    if [[ -n "$has_gpufreq_opp_freq" ]]; then
      adb shell "echo 549250 > /proc/gpufreq/gpufreq_opp_freq"
    else
      [[ $debug -eq 1 ]] && echo "/proc/gpufreq/gpufreq_opp_freq does not exist"
    fi
  fi
}

maximize_cpu_frequency() {
  if [[ $maximize_cpu_freq -eq 1 ]]; then
    has_hps=$(adb shell cat /proc/hps/enabled 2>/dev/null||echo "")
    if [[ -n "$has_hps" ]]; then
      # Turn off CPU hotplug strategy
      adb shell "echo 0 > /proc/hps/enabled"
    else
      [[ $debug -eq 1 ]] && echo "/proc/hps/enabled does not exist"
    fi
    max_freq=$(adb shell cat sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq)
    if ! [[ $max_freq =~ $NUMBER_RE ]] ; then
      echo "Invalid max cpu frequency : $max_freq"
      return
    fi
    # Pin CPU frequencies to a specific value (which is the maximum for these
    # devices).
    adb shell "echo 1 > /sys/devices/system/cpu/cpu1/online"
    adb shell "echo 1 > /sys/devices/system/cpu/cpu2/online"
    adb shell "echo 1 > /sys/devices/system/cpu/cpu3/online"

    adb shell "echo $max_freq > /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq">/dev/null
    adb shell "echo $max_freq > /sys/devices/system/cpu/cpu1/cpufreq/scaling_min_freq">/dev/null
    adb shell "echo $max_freq > /sys/devices/system/cpu/cpu2/cpufreq/scaling_min_freq">/dev/null
    adb shell "echo $max_freq > /sys/devices/system/cpu/cpu3/cpufreq/scaling_min_freq">/dev/null

    adb shell "echo $max_freq > /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq">/dev/null
    adb shell "echo $max_freq > /sys/devices/system/cpu/cpu1/cpufreq/scaling_max_freq">/dev/null
    adb shell "echo $max_freq > /sys/devices/system/cpu/cpu2/cpufreq/scaling_max_freq">/dev/null
    adb shell "echo $max_freq > /sys/devices/system/cpu/cpu3/cpufreq/scaling_max_freq">/dev/null
  fi
}

#=====================
# Main entry point
#=====================
if [[ $# -eq 0 ]]; then
  # no arguments specified, show the menu
  find_configs
  print_menu
  get_selection
  set_config
else
  # otherwise we parse the command line arguments
  parse_arguments "$@"

  # TODO the way this is set up, config file will override command line args
  # if config is set, use it
  if [[ -n "$selection" ]]; then
    find_configs
    validate_selection
    set_config
  fi

  # validate the keyword arguments
  # if we do not have have package and activity, exit early with an error
  [[ "$package" == "" ]] && echo "Package not specified" 1>&2 && exit 1
  [[ "$activity" == "" ]] && echo "Activity not specified" 1>&2 && exit 1
fi

# Need to run as root to access memcg data
adb root>/dev/null
debug=${DEBUG:-0}

get_device_serial
unlock_device
maximize_cpu_frequency
maximize_gpu_frequency

gboard_test_shared_preference_path="/data/data/wireless.android.androidgo.apps.testing.gboardtest/shared_prefs/GBoardTestMainActivity.xml"

# use summary file suffix from parameter if available
summary_file_suffix="${summary_file_suffix:-$SCRIPT_INVOCATION_TIME}"

if [[ -n "$package_to_profile" ]]; then
  is_custom_package_to_profile=1
else
  is_custom_package_to_profile=0
fi
# specify the package to profile, this should be set after
# configuration files have been sourced
package_to_profile="${package_to_profile:-$package}"

# extract android build fingerprint.
android_build_fingerprint=$(adb shell getprop "ro.build.fingerprint"|tr "/" "_"|tr -d '\r')

# extract RAM size
mem_total=$(adb shell cat /proc/meminfo|grep "MemTotal"|cut -d ':' -f 2|tr -d ' '|tr -d '\r')

# extract app version.
app_version_array=($(adb shell dumpsys package "$package"| grep "versionCode"|tr -d '\r'))
app_version_code=$(echo "${app_version_array[0]}"|cut -d '=' -f 2)

readonly ONE_KB=1024

memory_stat_path_template="/dev/memcg/apps/uid_%uid%/pid_%pid%/memory.stat"

# keyboard
total_keyboard_start_time=0

# app-start
total_app_start_time=0

# device
total_memory_on_device=0
total_used_memory_on_device=0
total_free_memory_on_device=0
total_swap_on_device=0
total_used_swap_on_device=0
total_free_swap_on_device=0

# meminfo
total_app_pss=()
total_app_private_dirty=()
total_app_java_heap=()
total_app_native_heap=()
total_app_code_heap=()
total_app_graphics_heap=()

# memcg
total_cache_for_app=()
total_rss_for_app=()
total_rss_huge_for_app=()
total_mapped_file_for_app=()
total_writeback_for_app=()
total_swap_for_app=()
total_pg_pg_in_for_app=()
total_pg_pg_out_for_app=()
total_pg_fault_for_app=()
total_pg_maj_fault_for_app=()
total_inactive_anon_for_app=()
total_active_anon_for_app=()
total_inactive_file_for_app=()
total_active_file_for_app=()
total_unevictable_for_app=()

# gfxinfo aggregate stats
total_gfx_total_frames_rendered=()
total_gfx_janky_frames=()
total_gfx_50th_percentile=()
total_gfx_90th_percentile=()
total_gfx_95th_percentile=()
total_gfx_99th_percentile=()
total_gfx_num_missed_vsync=()
total_gfx_num_high_input_latency=()
total_gfx_num_slow_ui_thread=()
total_gfx_num_slow_bitmap_uploads=()
total_gfx_num_slow_issue_draw_commands=()
total_gfx_memory_usage=()
total_gfx_texture_cache=()
total_gfx_layers_total=()
total_gfx_render_buffer_cache=()
total_gfx_gradient_cache=()
total_gfx_path_cache=()
total_gfx_tessellation_cache=()
total_gfx_text_drop_shadow_cache=()
total_gfx_patch_cache=()
total_gfx_font_renderer_total=()

# simpleperf
total_cpu_cycles=()
total_cache_misses=()
total_page_faults=()

process_to_profile_array=()

if ! mkdir -p "$summary_results_dir"; then
  echo >&2 "Unable to create summary result directory: $summary_results_dir"
  exit 1
fi

if ! mkdir -p "$csv_dir"; then
  echo >&2 "Unable to create iteration test result directory : $csv_dir"
  exit 1
fi

#initialize variables for systrace test if required to run the test
if should_run_test "$SYSTRACE"; then
  os_version=$(adb shell getprop ro.build.version.release|cut -d '.' -f 1)
  if ! mkdir -p "$systrace_dir"; then
    echo >&2 "unable to create systrace_dir: $systrace_dir"
    exit 1
  fi
  if [[ $os_version =~ "$NUMBER_RE" && "$os_version" -ge 8 ]]; then
    trace_points="sched freq idle am wm res gfx view sync irq hal workq dalvik pagecache binder_driver"
  else
    trace_points="sched freq idle am wm res gfx view sync irq hal workq dalvik"
  fi
fi

# Collects the device configs.
collect_device_configs() {
  if should_run_test "$DEVICE_CONFIGS_TEST"; then
    summary_device_configs_result="$summary_results_dir/$DEVICE_CONFIGS_TEST-$summary_file_suffix.csv"
    [[ -e "$summary_device_configs_result" ]] && return

    crypto_state=$(adb shell getprop ro.crypto.state)
    engineermode_pm_text=$(adb shell pm list packages com.mediatek.engineermode|tr -d ' ')
    build_type=$(adb shell getprop ro.build.type)

    [[ -z "$engineermode_pm_text" ]] && has_engineermode="No" || has_engineermode="Yes"

    if [[ "$build_type" == "userdebug" ]]; then
      f2fs_status=$(adb shell cat /sys/kernel/debug/f2fs/status 2>/dev/null||echo "")
    else
      f2fs_status=$(adb shell cat proc/filesystems|grep f2fs|tr -d '\t'||echo "")
    fi

    [[ -n "$f2fs_status" ]] && has_f2fs="Yes" || has_f2fs="No"

    if [[ $debug -eq 1 ]]; then
        echo "---------------- DEVICE CONFIGS DEBUG INFO START ------------------"
        echo "Crypto state: $crypto_state"
        echo "Has engineermode: $has_engineermode: $engineermode_pm_text"
        echo "Has f2fs: $f2fs_status"
        echo "---------------- DEVICE CONFIGS DEBUG INFO END --------------------"
    fi

    if [[ $quiet_mode -lt 1 ]]; then
      echo "DEVICE CONFIGS"
      echo "------------------"
      echo "Crypto state: $crypto_state"
      echo "Has engineermode: $has_engineermode"
      echo "Has f2fs: $has_f2fs"
      echo ""
    fi

    ensure_csv "$summary_device_configs_result" \
      "$DEVICE_CONFIGS_TEST_SUMMARY_CSV_HEADER"
    join_by "," \
      "$device_serial" \
      "$android_build_fingerprint" \
      "$mem_total" \
      "$crypto_state" \
      "$has_engineermode" \
      "$has_f2fs" >> "$summary_device_configs_result"
    adb shell getprop > "$summary_results_dir/device-properties-$summary_file_suffix.csv"
  fi
}

# Collects the device memory metric after an app starts.
collect_device_memory_metrics() {
  if should_run_test "$DEVICE_MEMORY_TEST"; then
    if ! free_output=$(adb shell free 2> /dev/null); then
      [[ $debug -eq 1 ]] && echo "free not found"
      # just in case something is on stdout when it exists with non-zero
      free_output=""
    fi

    # on some devices, free is not found, but adb return status is 0
    if [[ $free_output =~ not\ found ]]; then
      free_output=""
    fi

    if [[ $debug -eq 1 ]]; then
      if [[ -n "$free_output" ]]; then
        echo "---------------- DEVICE DEBUG INFO START ------------------"
        echo "$free_output"
        echo "---------------- DEVICE DEBUG INFO END --------------------"
      fi
    fi

    if [[ -n "$free_output" ]]; then
      free_output_mem=$(echo "$free_output" | grep 'Mem:'|tr -d '\r') # get the memory usage line
      free_array=($free_output_mem) # convert free output to an array

      total_memory_on_device=$((${free_array[1]} / ONE_KB))
      used_memory_on_device=$((${free_array[2]} / ONE_KB))
      free_memory_on_device=$((${free_array[3]} / ONE_KB))
      free_output_swap_on_device=$(echo "$free_output" | grep 'Swap:'|tr -d '\r') # get the swap usage line
      free_array_swap_on_device=($free_output_swap_on_device) # convert free output into array
      total_swap_on_device=$((${free_array_swap_on_device[1]} / ONE_KB))
      used_swap_on_device=$((${free_array_swap_on_device[2]} / ONE_KB))
      free_swap_on_device=$((${free_array_swap_on_device[3]} / ONE_KB))

      if [[ $quiet_mode -lt 1 ]]; then
        echo "DEVICE MEMORY"
        echo "------------"
        echo "Used mem: $used_memory_on_device KB"
        echo "Free mem: $free_memory_on_device KB"
        echo "Used swap: $used_swap_on_device KB"
        echo "Free swap: $free_swap_on_device KB"
        echo ""
      fi

      if [[ $is_gboard_test -eq 1 ]]; then
        package_for_csv=$package_to_profile
      else
        package_for_csv=$package
      fi

      write_to_csv \
        "$DEVICE_MEMORY_TEST" \
        "$DEVICE_MEMORY_TEST_CSV_HEADER" \
        "$package_for_csv" \
        "$used_memory_on_device" "$free_memory_on_device" \
        "$used_swap_on_device" "$free_swap_on_device"

      total_used_memory_on_device=$((total_used_memory_on_device + used_memory_on_device))
      total_free_memory_on_device=$((total_free_memory_on_device + free_memory_on_device))
      total_used_swap_on_device=$((total_used_swap_on_device + used_swap_on_device))
      total_free_swap_on_device=$((total_free_swap_on_device + free_swap_on_device))
    fi
  fi
}

# Collects the startup metric for an app.
#
# Arguments:
#   app startup info
#   package name for which metrics needs to be collected
collect_app_startup_metrics() {
  if should_run_test "$APP_START_TEST"; then
    # activity failed to start, re-echo the activity failed to start message
    echo "$1" | grep -q "Error:" && echo "$1" 1>&2 && exit 1

    if $SHOULD_WRITE_CUSTOM_CONFIG; then
      write_custom_config_to_file
      # make sure we that we only write it once, on the first run
      SHOULD_WRITE_CUSTOM_CONFIG=false
    fi
    if [[ $debug -eq 1 ]]; then
      echo "----------------- APP START DEBUG START --------------------"
      echo "$1"
      echo "------------------ APP START DEBUG END ---------------------"
    fi
    app_start_status=$(echo "$1"|grep 'Status:'|cut -d ':' -f 2|sed -e 's/^[ \t]*//')
    if [[ "$app_start_status" = *"ok"* ]]; then
      app_start_time=$(echo "$1"|grep 'TotalTime:'|cut -d ':' -f 2|tr -d '\r')
    else
      app_start_time=0
    fi

    if [[ $quiet_mode -lt 1 ]]; then
      echo ""
      echo "APP STARTUP INFO for $2"
      echo "-----------------------------------------------------------------"
      echo "Time to start app: $app_start_time ms"
      echo ""
    fi
    write_to_csv \
      "$APP_START_TEST" \
      "$APP_START_TEST_CSV_HEADER" \
      "$package" \
      "$app_start_time"
    total_app_start_time=$((total_app_start_time + app_start_time))
  fi
}

# Collects the meminfo metric for a process run by an app.
#
# Arguments:
#   process name for which metrics needs to be collected
#   index of the process from the list of processes for an app
collect_app_memory_metrics() {
  if should_run_test "$MEMINFO_TEST"; then
    meminfo_text=$(adb shell dumpsys meminfo "$1")

    if [[ $debug -eq 1 ]]; then
      echo "----------------- APP MEMORY INFO DEBUG START --------------------"
      echo "$meminfo_text"
      echo "------------------ APP MEMORY INFO DEBUG END ---------------------"
    fi
    # some devices might not have the App Summary section
    app_pss_info=$(echo "$meminfo_text"|grep 'TOTAL'|grep -v ':'|tr -d '\r'|| echo "")
    app_pss_info_array=($app_pss_info)
    if [[ "${#app_pss_info_array[@]}" -ge 3 ]]; then
      app_pss=${app_pss_info_array[1]}
      app_private_dirty=${app_pss_info_array[2]}
    else
      app_pss=0
      app_private_dirty=0
    fi
    java_heap=$(echo "$meminfo_text"| grep 'Java Heap:' | cut -d ':' -f 2|tr -d '\r' || echo 0)
    native_heap=$(echo "$meminfo_text"| grep 'Native Heap:' | cut -d ':' -f 2|tr -d '\r' || echo 0)
    code_heap=$(echo "$meminfo_text"| grep 'Code:' | cut -d ':' -f 2|tr -d '\r' || echo 0)
    graphics_heap=$(echo "$meminfo_text" | grep 'Graphics:' | cut -d ':' -f 2|tr -d '\r' || echo 0)

    if [[ $quiet_mode -lt 1 ]]; then
      echo "MEMINFO for $1"
      echo "-----------------------------------------------------------------"
      echo "Total java heap usage: $java_heap KB"
      echo "Total native heap usage: $native_heap KB"
      echo "Total code heap usage: $code_heap KB"
      echo "Total graphics heap usage: $graphics_heap KB"
      echo "Total private dirty: $app_private_dirty KB"
      echo "Total Pss:  $app_pss KB"
      echo ""
    fi

    write_to_csv \
      "$MEMINFO_TEST" \
      "$MEMINFO_TEST_CSV_HEADER" \
      "$1" \
      "$java_heap" "$native_heap" "$code_heap" "$graphics_heap" "$app_private_dirty" "$app_pss"

    total_app_private_dirty[$2]=$((${total_app_private_dirty[$2]:-0} + app_private_dirty))
    total_app_pss[$2]=$((${total_app_pss[$2]:-0} + app_pss))
    total_app_java_heap[$2]=$((${total_app_java_heap[$2]:-0} + java_heap))
    total_app_native_heap[$2]=$((${total_app_native_heap[$2]:-0} + native_heap))
    total_app_code_heap[$2]=$((${total_app_code_heap[$2]:-0} + code_heap))
    total_app_graphics_heap[$2]=$((${total_app_graphics_heap[$2]:-0} + graphics_heap))
  fi
}

# Collects the simpleperf metric for a process run by an app.
#
# Arguments:
#   pid of the process for which metrics needs to be collected
#   index of the process from the list of processes for an app
#   process name for which metrics needs to be collected
collect_simpleperf_metrics() {
  if should_run_test "$SIMPLEPERF_TEST"; then
    if [[ -n "$1" ]]; then
      simpleperf[$2]=$(adb shell simpleperf stat -e "$simpleperf_events" -p "$1" --duration "$simpleperf_duration" --csv 2>/dev/null|| echo ""|tr -d '\r')
      # on some devices simpleperf is not found
      if [[ "${simpleperf[$2]}" =~ not\ found ]]; then
        simpleperf[$2]=""
      fi
      # on some devices certain simpleperf events are not supported
      if [[ "${simpleperf[$2]}"  = *"is not supported on the device"* ]]; then
        simpleperf[$2]=""
      fi
    else
      simpleperf[$2]=""
    fi

    if [[ $debug -eq 1 ]]; then
      echo "---------------------------- SIMPLEPERF DEBUG INFO START ----------------------------"
      echo "${simpleperf[$2]}"
      echo "---------------------------- SIMPLEPERF DEBUG INFO END ----------------------------"
    fi

    if [[ -n "${simpleperf[$2]}"  ]]; then
      cpu_cycles=$(echo "${simpleperf[$2]}"  | grep "cpu-cycles" | cut -d ',' -f 1|| echo 0)
      cache_misses=$(echo "${simpleperf[$2]}"  | grep "cache-misses" | cut -d ',' -f 1|| echo 0)
      page_faults=$(echo "${simpleperf[$2]}"  | grep "page-faults" | cut -d ',' -f 1|| echo 0)

      if [[ $quiet_mode -lt 1 ]]; then
        echo "SIMPLEPERF INFO for $3"
        echo "-----------------------------------------------------------------"
        echo "Total cpu cycles: $cpu_cycles"
        echo "Total cache misses: $cache_misses"
        echo "Total page faults: $page_faults"
      fi

      write_to_csv \
        "$SIMPLEPERF_TEST" \
        "$SIMPLEPERF_TEST_CSV_HEADER" \
        "$3" \
        "$cpu_cycles" "$cache_misses" "$page_faults"

      total_cpu_cycles[$2]=$((${total_cpu_cycles[$2]:-0} + cpu_cycles))
      total_cache_misses[$2]=$((${total_cache_misses[$2]:-0} + cache_misses))
      total_page_faults[$2]=$((${total_page_faults[$2]:-0} + page_faults))

      if [[ $quiet_mode -lt 1 ]]; then
        echo ""
      fi
    fi
  fi
}

# Get the gfxinfo metric for a process run by an app.
#
# Arguments:
#   process for which metrics needs to be collected
#   index of the process from the list of processes
collect_gfx_metrics() {
  if should_run_test "$GFXINFO_TEST"; then
    gfxinfo=$(adb shell dumpsys gfxinfo "$1"|tr -d '\r')

    if [[ $debug -eq 1 ]]; then
      echo "---------------------------- GFX DEBUG INFO START ----------------------------"
      echo "$gfxinfo"
      echo "---------------------------- GFX DEBUG INFO END ----------------------------"
    fi
    # get_stat <name of stat to grep>
    get_stat() {
      local stat length
      # get the line of gfxinfo output we want, and select the part before the "/"
      stat=($(echo "$gfxinfo" | grep "$1" | cut -d "/" -f 1))
      length="${#stat[@]}"
      if [[ "$length" -ge 2 ]]; then
        echo "${stat[$length-1]}"
      else
        echo 0
      fi
    }

    if gfxinfo_memory_usage[$2]=$(echo "$gfxinfo" | grep -A 1 "Total memory usage:"); then
      gfx_total_frames_rendered=$(echo "$gfxinfo" | grep -m 1 "Total frames rendered" | cut -d ':' -f 2)
      gfx_janky_frames=$(echo "$gfxinfo" | grep -m 1 "Janky frames" | cut -d ':' -f 2 | cut -d ' ' -f 2)
      gfx_50th_percentile=$(echo "$gfxinfo" | grep -m 1 "50th percentile" | cut -d ':' -f 2 | tr '[:alpha:]' ' ' || echo "")
      gfx_90th_percentile=$(echo "$gfxinfo" | grep -m 1 "90th percentile" | cut -d ':' -f 2 | tr '[:alpha:]' ' ' || echo "")
      gfx_95th_percentile=$(echo "$gfxinfo" | grep -m 1 "95th percentile" | cut -d ':' -f 2 | tr '[:alpha:]' ' ' || echo "")
      gfx_99th_percentile=$(echo "$gfxinfo" | grep -m 1 "99th percentile" | cut -d ':' -f 2 | tr '[:alpha:]' ' ' || echo "")
      gfx_num_missed_vsync=$(echo "$gfxinfo" | grep -m 1 "Number Missed Vsync" | cut -d ':' -f 2)
      gfx_num_high_input_latency=$(echo "$gfxinfo" | grep -m 1 "Number High input latency" | cut -d ':' -f 2)
      gfx_num_slow_ui_thread=$(echo "$gfxinfo" | grep -m 1 "Number Slow UI thread" | cut -d ':' -f 2)
      gfx_num_slow_bitmap_uploads=$(echo "$gfxinfo" | grep -m 1 "Number Slow bitmap uploads" | cut -d ':' -f 2)
      gfx_num_slow_issue_draw_commands=$(echo "$gfxinfo" | grep -m 1 "Number Slow issue draw commands" | cut -d ':' -f 2)
      bytes_output=$(echo "${gfxinfo_memory_usage[$2]}" | tail -n 1)
      # if there is Total memory usage, we will have the rest of these fields too
      tmp_array=($bytes_output)
      gfx_mem_usage=$((${tmp_array[0]} / ONE_KB))
      gfx_texture_cache=$(($(get_stat "TextureCache") / ONE_KB))
      tmp_array=($(echo "$gfxinfo" | grep -i "Layers total"))
      gfx_layers_total=$(printf '%.*f' 0 "${tmp_array[2]}")
      gfx_render_buffer_cache=$(($(get_stat "RenderBufferCache") / ONE_KB))
      gfx_gradient_cache=$(($(get_stat "GradientCache") / ONE_KB))
      gfx_path_cache=$(($(get_stat "PathCache") / ONE_KB))
      gfx_tessellation_cache=$(($(get_stat "TessellationCache") / ONE_KB))
      gfx_text_drop_shadow_cache=$(($(get_stat "TextDropShadowCache") / ONE_KB))
      gfx_patch_cache=$(($(get_stat "PatchCache") / ONE_KB))
      gfx_font_renderer_total=$(($(get_stat "FontRenderer total") / ONE_KB))

      if [[ $quiet_mode -lt 1 ]]; then
        echo "GFX INFO for $1"
        echo "-----------------------------------------------------------------"
        echo "Total frames rendered: $gfx_total_frames_rendered"
        echo "Janky frames: $gfx_janky_frames"
        echo "50th percentile: $gfx_50th_percentile ms"
        echo "50th percentile: $gfx_90th_percentile ms"
        echo "50th percentile: $gfx_95th_percentile ms"
        echo "50th percentile: $gfx_99th_percentile ms"
        echo "Number Missed VSync: $gfx_num_missed_vsync"
        echo "Number High input latency: $gfx_num_high_input_latency"
        echo "Number Slow UI thread: $gfx_num_slow_ui_thread"
        echo "Number Slow bitmap uploads: $gfx_num_slow_bitmap_uploads"
        echo "Number Slow issue draw commands: $gfx_num_slow_issue_draw_commands"
        echo "Total memory usage: $gfx_mem_usage KB"
        echo "Total TextureCache: $gfx_texture_cache KB"
        echo "Total Layers total: $gfx_layers_total"
        echo "Total RenderBufferCache: $gfx_render_buffer_cache KB"
        echo "Total GradientCache: $gfx_gradient_cache KB"
        echo "Total PathCache: $gfx_path_cache KB"
        echo "Total TessellationCache: $gfx_tessellation_cache KB"
        echo "Total TextDropShadowCache: $gfx_text_drop_shadow_cache KB"
        echo "Total PatchCache: $gfx_patch_cache KB"
        echo "Total FontRenderer total: $gfx_font_renderer_total KB"
        echo ""
      fi

      write_to_csv \
        "$GFXINFO_TEST" \
        "$GFXINFO_TEST_CSV_HEADER" \
        "$1" \
        "$gfx_total_frames_rendered" "$gfx_janky_frames" "$gfx_50th_percentile" \
        "$gfx_90th_percentile" "$gfx_95th_percentile" "$gfx_99th_percentile" \
        "$gfx_num_missed_vsync" "$gfx_num_high_input_latency" \
        "$gfx_num_slow_ui_thread" "$gfx_num_slow_bitmap_uploads" \
        "$gfx_num_slow_issue_draw_commands" "$gfx_mem_usage" \
        "$gfx_texture_cache" "$gfx_layers_total" "$gfx_render_buffer_cache" \
        "$gfx_gradient_cache" "$gfx_path_cache" "$gfx_tessellation_cache" \
        "$gfx_text_drop_shadow_cache" "$gfx_patch_cache" "$gfx_font_renderer_total"

      total_gfx_total_frames_rendered[$2]=$((${total_gfx_total_frames_rendered[$2]:-0} + gfx_total_frames_rendered))
      total_gfx_janky_frames[$2]=$((${total_gfx_janky_frames[$2]:-0} + gfx_janky_frames))
      total_gfx_50th_percentile[$2]=$((${total_gfx_50th_percentile[$2]:-0} + gfx_50th_percentile))
      total_gfx_90th_percentile[$2]=$((${total_gfx_90th_percentile[$2]:-0} + gfx_90th_percentile))
      total_gfx_95th_percentile[$2]=$((${total_gfx_95th_percentile[$2]:-0} + gfx_95th_percentile))
      total_gfx_99th_percentile[$2]=$((${total_gfx_99th_percentile[$2]:-0} + gfx_99th_percentile))
      total_gfx_num_missed_vsync[$2]=$((${total_gfx_num_missed_vsync[$2]:-0} + gfx_num_missed_vsync))
      total_gfx_num_high_input_latency[$2]=$((${total_gfx_num_high_input_latency[$2]:-0} + gfx_num_high_input_latency))
      total_gfx_num_slow_ui_thread[$2]=$((${total_gfx_num_slow_ui_thread[$2]:-0} + gfx_num_slow_ui_thread))
      total_gfx_num_slow_bitmap_uploads[$2]=$((${total_gfx_num_slow_bitmap_uploads[$2]:-0} + gfx_num_slow_bitmap_uploads))
      total_gfx_num_slow_issue_draw_commands[$2]=$((${total_gfx_num_slow_issue_draw_commands[$2]:-0} + gfx_num_slow_issue_draw_commands))
      total_gfx_memory_usage[$2]=$((${total_gfx_memory_usage[$2]:-0} + gfx_mem_usage))
      total_gfx_texture_cache[$2]=$((${total_gfx_texture_cache[$2]:-0} + gfx_texture_cache))
      total_gfx_layers_total[$2]=$((${total_gfx_layers_total[$2]:-0} + gfx_layers_total))
      total_gfx_render_buffer_cache[$2]=$((${total_gfx_render_buffer_cache[$2]:-0} + gfx_render_buffer_cache))
      total_gfx_gradient_cache[$2]=$((${total_gfx_gradient_cache[$2]:-0} + gfx_gradient_cache))
      total_gfx_path_cache[$2]=$((${total_gfx_path_cache[$2]:-0} + gfx_path_cache))
      total_gfx_tessellation_cache[$2]=$((${total_gfx_tessellation_cache[$2]:-0} + gfx_tessellation_cache))
      total_gfx_text_drop_shadow_cache[$2]=$((${total_gfx_text_drop_shadow_cache[$2]:-0} + gfx_text_drop_shadow_cache))
      total_gfx_patch_cache[$2]=$((${total_gfx_patch_cache[$2]:-0} + gfx_patch_cache))
      total_gfx_font_renderer_total[$2]=$((${total_gfx_font_renderer_total[$2]:-0} + gfx_font_renderer_total))
    fi
  fi
}

# Collects the memcg info metric for a process run by an app.
#
# Arguments:
#   pid of the process for which metrics needs to be collected
#   index of the process from the list of processes for an app
#   process name for which metrics needs to be collected
collect_memcg_metrics() {
  # memcg info
  if should_run_test "$MEMCG_TEST"; then
    if [[ -n "$pid" ]]; then
      uid=$(adb shell ps -A -o uid,pid|grep "$pid"|tail -1|cut -d ' ' -f 1 || echo "")
      if [[ -n "$uid" ]]; then
        memory_stat_path=$(echo "$memory_stat_path_template"|sed -e "s/%pid%/$pid/g"|sed -e "s/%uid%/$uid/g")
        memory_stat[$2]=$(adb shell cat "$memory_stat_path" 2> /dev/null || echo "")
        if [[ "${memory_stat[$2]}" =~ No\ such\ file\ or\ directory ]]; then
          memory_stat_path=""
          memory_stat[$2]=""
        fi
      else
        memory_stat_path=""
        memory_stat[$2]=""
      fi
    else
      memory_stat_path=""
      memory_stat[$2]=""
    fi

    if [[ $debug -eq 1 ]]; then
      echo ""
      echo "--------------------------- MEMCG DEBUG INFO START -------------------------"
      [[ -n "$memory_stat_path" ]] && echo "Memory stat path: $memory_stat_path"
      echo ""
      echo "${memory_stat[$2]}"
      echo "---------------------------- MEMCG DEBUG INFO END --------------------------"
      echo ""
    fi

    if [[ -n "${memory_stat[$2]}" ]]; then
      cache=$(($(echo "${memory_stat[$2]}"|grep "total_cache"|cut -d ' ' -f 2 || echo 0) / ONE_KB))
      rss=$(($(echo "${memory_stat[$2]}"|grep "total_rss"|grep -v "huge"|cut -d ' ' -f 2 || echo 0) / ONE_KB))
      rss_huge=$(($(echo "${memory_stat[$2]}"|grep "total_rss_huge"|cut -d ' ' -f 2 || echo 0) / ONE_KB))
      mapped_file=$(($(echo "${memory_stat[$2]}"|grep "total_mapped_file"|cut -d ' ' -f 2 || echo 0) / ONE_KB))
      writeback=$(($(echo "${memory_stat[$2]}"|grep "total_writeback"|cut -d ' ' -f 2 || echo 0) / ONE_KB))
      swap=$(($(echo "${memory_stat[$2]}"|grep "total_swap"|cut -d ' ' -f 2 || echo 0) / ONE_KB))
      pgpgin=$(echo "${memory_stat[$2]}"|grep "total_pgpgin"|cut -d ' ' -f 2 || echo 0)
      pgpgout=$(echo "${memory_stat[$2]}"|grep "total_pgpgout"|cut -d ' ' -f 2 || echo 0)
      pg_fault=$(echo "${memory_stat[$2]}"|grep "total_pgfault"|cut -d ' ' -f 2 || echo 0)
      pg_maj_fault=$(echo "${memory_stat[$2]}"|grep "total_pgmajfault"|cut -d ' ' -f 2 || echo 0)
      inactive_anon=$(($(echo "${memory_stat[$2]}"|grep "total_inactive_anon"|cut -d ' ' -f 2 || echo 0) / ONE_KB))
      active_anon=$(($(echo "${memory_stat[$2]}"|grep "total_active_anon"|cut -d ' ' -f 2 || echo 0) / ONE_KB))
      inactive_file=$(($(echo "${memory_stat[$2]}"|grep "total_inactive_file"|cut -d ' ' -f 2 || echo 0) / ONE_KB))
      active_file=$(($(echo "${memory_stat[$2]}"|grep "total_active_file"|cut -d ' ' -f 2 || echo 0) / ONE_KB))
      unevictable=$(($(echo "${memory_stat[$2]}"|grep "total_unevictable"|cut -d ' ' -f 2 || echo 0) / ONE_KB))

      if [[ $quiet_mode -lt 1 ]]; then
        echo "MEMCG INFO for $3"
        echo "-----------------------------------------------------------------"
        echo "total_cache: $cache KB"
        echo "total_rss: $rss KB"
        echo "total_rss_huge: $rss_huge KB"
        echo "total_mapped_file: $mapped_file KB"
        echo "total_writeback: $writeback KB"
        echo "total_swap: $swap KB"
        echo "total_pgpgin: $pgpgin"
        echo "total_pgpgout: $pgpgout"
        echo "total_pgfault: $pg_fault"
        echo "total_pgmajfault: $pg_maj_fault"
        echo "total_inactive_anon: $inactive_anon KB"
        echo "total_active_anon: $active_anon KB"
        echo "total_inactive_file: $inactive_file KB"
        echo "total_active_file: $active_file KB"
        echo "total_unevictable: $unevictable KB"
        echo ""
      fi

      write_to_csv \
        "$MEMCG_TEST" \
        "$MEMCG_TEST_CSV_HEADER" \
        "$3" \
        "$cache" "$rss" "$rss_huge" "$mapped_file" "$writeback" "$swap" \
        "$pgpgin" "$pgpgout" "$pg_fault" "$pg_maj_fault" "$inactive_anon" \
        "$active_anon" "$inactive_file" "$active_file" "$unevictable"

      total_cache_for_app[$2]=$((${total_cache_for_app[$2]:-0} + cache))
      total_rss_for_app[$2]=$((${total_rss_for_app[$2]:-0} + rss))
      total_rss_huge_for_app[$2]=$((${total_rss_huge_for_app[$2]:-0} + rss_huge))
      total_mapped_file_for_app[$2]=$((${total_mapped_file_for_app[$2]:-0} + mapped_file))
      total_writeback_for_app[$2]=$((${total_writeback_for_app[$2]:-0} + writeback))
      total_swap_for_app[$2]=$((${total_swap_for_app[$2]:-0} + swap))
      total_pg_pg_in_for_app[$2]=$((${total_pg_pg_in_for_app[$2]:-0} + pgpgin))
      total_pg_pg_out_for_app[$2]=$((${total_pg_pg_out_for_app[$2]:-0} + pgpgout))
      total_pg_fault_for_app[$2]=$((${total_pg_fault_for_app[$2]:-0} + pg_fault))
      total_pg_maj_fault_for_app[$2]=$((${total_pg_maj_fault_for_app[$2]:-0} + pg_maj_fault))
      total_inactive_anon_for_app[$2]=$((${total_inactive_anon_for_app[$2]:-0} + inactive_anon))
      total_active_anon_for_app[$2]=$((${total_active_anon_for_app[$2]:-0} + active_anon))
      total_inactive_file_for_app[$2]=$((${total_inactive_file_for_app[$2]:-0} + inactive_file))
      total_active_file_for_app[$2]=$((${total_active_file_for_app[$2]:-0} + active_file))
      total_unevictable_for_app[$2]=$((${total_unevictable_for_app[$2]:-0} + unevictable))
    fi
  fi
}

# Collects keyboard metrics.
collect_keyboard_metrics() {
  if [[ $is_gboard_test -eq 1 ]]; then
    keyboard_start_time=$(adb shell cat "$gboard_test_shared_preference_path"|grep 'time_to_display_keyboard'|grep -o 'value=[^,/]*'|cut -d '=' -f 2|tr -d '\"')
    echo "Total time to display Keyboard: $keyboard_start_time ms"
    echo ""
    total_keyboard_start_time=$((total_keyboard_start_time + keyboard_start_time))
  fi
}

if [[ $debug -eq 1 ]]; then
  echo ""
  echo "Number of runs: $number_of_runs"
  echo "Delay: $delay"
  echo "Tests to run: $tests_to_run"
  echo "Profiling package: $package_to_profile"
fi

if [[ $speed_profile -eq 1 ]]; then
  speed_profile_app
fi

if [[ $quiet_mode -lt 2 ]]; then
  echo ""
  echo "-------------------------------- STARTING TEST ON $device_serial --------------------------------"
fi
collect_device_configs
is_gboard_test=0

if [[ "$package" = "wireless.android.androidgo.apps.testing.gboardtest" ]]; then
  is_gboard_test=1
fi

for (( c=1; c<=number_of_runs; c++ )); do
  if [[ $quiet_mode -lt 1 ]]; then
    echo ""
  fi
  echo "Run $c on device: $device_serial"

  if [[ $drop_caches -gt 0 && $drop_caches -lt 4 ]]; then
    drop_caches_status=$(adb shell "echo $drop_caches > /proc/sys/vm/drop_caches")
    if [[ $debug -eq 1 ]]; then
      echo ""
      if [[ -z "$drop_caches_status" ]]; then
        echo "Cleared cache successfully"
      else
        echo "Failed to clear cache"
      fi
    fi
  fi

  if [[ $is_gboard_test -eq 1 ]]; then
    stop_inputmethod_text=$(adb shell am force-stop "$package_to_profile")
    echo "$stop_inputmethod_text" | grep -q "Error:" && echo "$stop_inputmethod_text" 1>&2 && exit 1
    sleep "$delay"
  fi

  app_associations_result="$csv_dir/$APP_ASSOCIATIONS-$package-$app_version_code-$device_serial-$android_build_fingerprint-$mem_total-$summary_file_suffix.txt"
  if should_run_test "$APP_ASSOCIATIONS"; then
    if [[ ! -e "$app_associations_result" ]]; then
      track_associations=$(adb shell cmd activity track-associations)
      if [[ $debug -eq 1 ]]; then
        echo "$track_associations"
      fi
    fi
  fi

  if should_run_test "$SYSTRACE"; then
    if [[ -z "$package_to_profile" ]]; then
      adb shell "atrace --async_start -b $trace_buffer_size $trace_points"
    else
      adb shell "atrace --async_start -b $trace_buffer_size $trace_points -a $package_to_profile"
    fi
  fi
  app_start_info_text=$(adb shell am start -S -W "$package/$activity")

  if should_run_test "$APP_ASSOCIATIONS"; then
    if [[ ! -e "$app_associations_result" ]]; then
      associations=$(adb shell dumpsys activity associations)
      untrack_associations=$(adb shell cmd activity untrack-associations)
      if [[ $debug -eq 1 ]]; then
        echo "--------------------------- ASSOCIATION DEBUG INFO START -------------------------"
        echo "$associations"
        echo ""
        echo "$untrack_associations"
        echo "--------------------------- ASSOCIATION DEBUG INFO END -------------------------"
      fi
      echo "$associations" > "$app_associations_result"
    fi
  fi

  sleep "$delay"
  # this is so that we save either the trace or the html package
  if should_run_test "$SYSTRACE"; then
    adb shell "echo 0 > /d/tracing/tracing_on"
    trace_file_name="$package-$app_version_code-$device_serial-$android_build_fingerprint-$mem_total-$summary_file_suffix-Run_$c"
    adb shell cat /d/tracing/trace > "$systrace_dir/$trace_file_name.trace"
    echo "Generated: $systrace_dir/$trace_file_name.trace"
    if [[ -e "$trace2html_path" ]]; then
      "$trace2html_path" "$systrace_dir/$trace_file_name.trace">/dev/null
      echo "Generated: $systrace_dir/$trace_file_name.html"
    fi
  fi

  if [[ $is_custom_package_to_profile -eq 1 ]]; then
    process_to_profile_array[0]="$package_to_profile"
    pids_to_profile_text=$(adb shell dumpsys activity processes "$package_to_profile"|grep "PID #"|cut -d '{' -f 2|cut -d '/' -f 1|cut -d ' ' -f 2|cut -d ':' -f1)
  else
    processes_to_profile_text=$(adb shell dumpsys activity processes "$package"|grep "PID #"|cut -d '{' -f 2|cut -d '/' -f 1|cut -d ' ' -f 2|cut -d ':' -f2,3)
    pids_to_profile_text=$(adb shell dumpsys activity processes "$package"|grep "PID #"|cut -d '{' -f 2|cut -d '/' -f 1|cut -d ' ' -f 2|cut -d ':' -f1)

    if [[ $debug -eq 1 ]]; then
      echo "----------- PROCESSES ----------"
      echo "$processes_to_profile_text"
      echo "----------- PIDS ----------"
      echo "$pids_to_profile_text"
      echo "--------------------------------"
    fi

    process_to_profile_array=($(echo "$processes_to_profile_text"))
  fi

  pids_to_profile_array=($(echo "$pids_to_profile_text"))

  if [[ "${#pids_to_profile_array[@]}" -lt 1 ]]; then
    "Unable to find pid of the processes. Exiting ..."
    exit 1
  fi

  collect_app_startup_metrics "$app_start_info_text" "$package_to_profile"
  collect_device_memory_metrics
  collect_keyboard_metrics

  for i in "${!process_to_profile_array[@]}"; do
    package_to_profile="${process_to_profile_array[$i]}"

    pid="${pids_to_profile_array[$i]}"
    if [[ -z "$pid" ]]; then
      echo "Unable to find pid of $package_to_profile. Skipping ..."
      continue
    fi
    collect_app_memory_metrics "$package_to_profile" "$i"
    collect_gfx_metrics "$package_to_profile" "$i"
    collect_memcg_metrics "$pid" "$i" "$package_to_profile"
    collect_simpleperf_metrics "$pid" "$i" "$package_to_profile"
  done

  if [[ "${#process_to_profile_array[@]}" -gt 1 ]]; then
    package_to_profile="$package"
  fi
done

# Calculates standard deviation for a given list of values and its average
# Arguments:
#   an array of values
#   average value
calculate_standard_deviation() {
  local value_array=("$@")
  unset 'value_array[${#value_array[@]} -1]'

  value_count=${#value_array[@]}
  if [[ "$value_count" -lt 1 ]]; then
    echo 0
    return
  fi

  shift_value=$((value_count - 1))
  shift $shift_value

  local average="$2" sum=0

  re="^[0-9]+([.][0-9]+)?$"
  if ! [[ $average =~ $re ]] ; then
    echo 0
    return
  fi

  for val_index in "${!value_array[@]}"; do
    value="${value_array[$val_index]}"
    if ! [[ $value =~ $re ]] ; then
      continue
    fi
    delta=$(echo "${value} - ${average}"|bc)
    deviation=$(echo "${delta} ^ 2"|bc)
    sum=$(echo "${sum} + ${deviation}"|bc)
  done

  variance=$(printf '%.*f' 0 "$(echo "scale=6; ${sum} / ${value_count}"|bc)")
  sd=$(printf '%.*f' 0 "$(echo "scale=6; sqrt(${variance})"|bc)")
  echo "$sd"
}

if [[ $quiet_mode -lt 2 ]]; then
  echo "================================================================================================"
  echo ""
  echo "=============================== TEST RESULTS ON $device_serial ==============================="
fi
if [[ $is_gboard_test -eq 1 && $quiet_mode -lt 2 ]]; then
  echo "KEYBOARD SUMMARY"
  echo "----------------"
  echo "Average time to display Keyboard: $((total_keyboard_start_time / number_of_runs)) ms"
  echo ""
fi

if should_run_test "$APP_START_TEST"; then
  average_time_to_start=$((total_app_start_time / number_of_runs))

  if [[ $quiet_mode -lt 2 ]]; then
    echo "APP STARTUP SUMMARY"
    echo "-------------------"
    echo "Average time to start: $average_time_to_start ms"
    echo ""
  fi

  app_startup_time_array=($(awk '{if (NR!=1) {print $1}}' FS="," "$(path_to_csv "$APP_START_TEST" "$package")"))
  app_startup_time_sd=$(calculate_standard_deviation "${app_startup_time_array[@]}" "$average_time_to_start")

  app_summary_result="$summary_results_dir/$APP_START_TEST-$summary_file_suffix.csv"
  ensure_csv "$app_summary_result" "$APP_START_TEST_SUMMARY_CSV_HEADER"
  join_by "," \
    "$device_serial" \
    "$android_build_fingerprint" \
    "$mem_total" \
    "$package" \
    "$app_version_code" \
    "$average_time_to_start" \
    "$app_startup_time_sd" >> "$app_summary_result"
fi


if should_run_test "$MEMINFO_TEST"; then
  for i in "${!process_to_profile_array[@]}"; do
    package_to_profile="${process_to_profile_array[$i]}"

    average_java_heap_usage=$((${total_app_java_heap[$i]} / number_of_runs))
    average_native_heap_usage=$((${total_app_native_heap[$i]} / number_of_runs))
    average_code_heap_usage=$((${total_app_code_heap[$i]} / number_of_runs))
    average_graphics_heap_usage=$((${total_app_graphics_heap[$i]} / number_of_runs))
    average_private_dirty=$((${total_app_private_dirty[$i]} / number_of_runs))
    average_pss=$((${total_app_pss[$i]} / number_of_runs))

    if [[ $quiet_mode -lt 2 ]]; then
      echo "MEMINFO SUMMARY for $package_to_profile"
      echo "-----------------------------------------------------------------"
      echo "Average java heap usage: $average_java_heap_usage KB"
      echo "Average native heap usage: $average_native_heap_usage KB"
      echo "Average code heap usage: $average_code_heap_usage KB"
      echo "Average graphics heap usage: $average_graphics_heap_usage KB"
      echo "Average private dirty: $average_private_dirty KB"
      echo "Average Pss: $average_pss KB"
      echo ""
    fi

    csv_path=$(path_to_csv "$MEMINFO_TEST" "$package_to_profile")

    java_heap_usage_array=($(awk '{if (NR!=1) {print $1}}' FS="," "$csv_path"))
    java_heap_usage_sd=$(calculate_standard_deviation "${java_heap_usage_array[@]}" "$average_java_heap_usage")

    native_heap_usage_array=($(awk '{if (NR!=1) {print $2}}' FS="," "$csv_path"))
    native_heap_usage_sd=$(calculate_standard_deviation "${native_heap_usage_array[@]}" "$average_native_heap_usage")

    code_heap_usage_array=($(awk '{if (NR!=1) {print $3}}' FS="," "$csv_path"))
    code_heap_usage_sd=$(calculate_standard_deviation "${code_heap_usage_array[@]}" "$average_code_heap_usage")

    graphics_heap_usage_array=($(awk '{if (NR!=1) {print $4}}' FS="," "$csv_path"))
    graphics_heap_usage_sd=$(calculate_standard_deviation "${graphics_heap_usage_array[@]}" "$average_graphics_heap_usage")

    private_dirty_array=($(awk '{if (NR!=1) {print $5}}' FS="," "$csv_path"))
    private_dirty_sd=$(calculate_standard_deviation "${private_dirty_array[@]}" "$average_private_dirty")

    pss_array=($(awk '{if (NR!=1) {print $6}}' FS="," "$csv_path"))
    pss_sd=$(calculate_standard_deviation "${pss_array[@]}" "$average_pss")

    meminfo_summary_result="$summary_results_dir/$MEMINFO_TEST-$summary_file_suffix.csv"
    ensure_csv "$meminfo_summary_result" "$MEMINFO_TEST_SUMMARY_CSV_HEADER"
    join_by "," \
      "$device_serial" \
      "$android_build_fingerprint" \
      "$mem_total" \
      "$package_to_profile" \
      "$app_version_code" \
      "$average_java_heap_usage" \
      "$java_heap_usage_sd" \
      "$average_native_heap_usage" \
      "$native_heap_usage_sd" \
      "$average_code_heap_usage" \
      "$code_heap_usage_sd" \
      "$average_graphics_heap_usage" \
      "$graphics_heap_usage_sd" \
      "$average_private_dirty" \
      "$private_dirty_sd" \
      "$average_pss" \
      "$pss_sd">> "$meminfo_summary_result"
  done
  if [[ "${#process_to_profile_array[@]}" -gt 1 ]]; then
    package_to_profile="$package"
  fi
fi

if should_run_test "$DEVICE_MEMORY_TEST"; then
  if [[ -n "$free_output" ]]; then
    average_used_memory_on_device=$((total_used_memory_on_device / number_of_runs))
    average_free_memory_on_device=$((total_free_memory_on_device / number_of_runs))
    average_used_swap_on_device=$((total_used_swap_on_device / number_of_runs))
    average_free_swap_on_device=$((total_free_swap_on_device / number_of_runs))

    if [[ $quiet_mode -lt 2 ]]; then
      echo "DEVICE SUMMARY"
      echo "--------------"
      echo "Memory (total/average used/average free): $total_memory_on_device KB/ $average_used_memory_on_device KB/ $average_free_memory_on_device KB"
      echo "Swap (total/average used/average free):  $total_swap_on_device KB/ $average_used_swap_on_device KB/ $average_free_swap_on_device KB"
      echo ""
    fi

    csv_path=$(path_to_csv "$DEVICE_MEMORY_TEST" "$package_to_profile")

    used_memory_on_device_array=($(awk '{if (NR!=1) {print $1}}' FS="," "$csv_path"))
    used_memory_on_device_sd=$(calculate_standard_deviation "${used_memory_on_device_array[@]}" "$average_used_memory_on_device")

    free_memory_on_device_array=($(awk '{if (NR!=1) {print $2}}' FS="," "$csv_path"))
    free_memory_on_device_sd=$(calculate_standard_deviation "${free_memory_on_device_array[@]}" "$average_free_memory_on_device")

    used_swap_on_device_array=($(awk '{if (NR!=1) {print $3}}' FS="," "$csv_path"))
    used_swap_on_device_sd=$(calculate_standard_deviation "${used_swap_on_device_array[@]}" "$average_used_swap_on_device")

    free_swap_on_device_array=($(awk '{if (NR!=1) {print $4}}' FS="," "$csv_path"))
    free_swap_on_device_sd=$(calculate_standard_deviation "${free_swap_on_device_array[@]}" "$average_free_swap_on_device")

    device_summary_result="$summary_results_dir/$DEVICE_MEMORY_TEST-$summary_file_suffix.csv"
    ensure_csv "$device_summary_result" "$DEVICE_MEMORY_TEST_SUMMARY_CSV_HEADER"
    join_by "," \
      "$device_serial" \
      "$android_build_fingerprint" \
      "$mem_total" \
      "$package" \
      "$app_version_code" \
      "$total_memory_on_device" \
      "$average_used_memory_on_device" \
      "$used_memory_on_device_sd" \
      "$average_free_memory_on_device" \
      "$free_memory_on_device_sd" \
      "$total_swap_on_device" \
      "$average_used_swap_on_device" \
      "$used_swap_on_device_sd" \
      "$average_free_swap_on_device" \
      "$free_swap_on_device_sd" >> "$device_summary_result"
  fi
fi

if should_run_test "$MEMCG_TEST"; then
  for i in "${!process_to_profile_array[@]}"; do
    if [[ -n "${memory_stat[$i]}" ]]; then
      package_to_profile="${process_to_profile_array[$i]}"

      average_cache=$((${total_cache_for_app[$i]} / number_of_runs))
      average_rss=$((${total_rss_for_app[$i]} / number_of_runs))
      average_rss_huge=$((${total_rss_huge_for_app[$i]} / number_of_runs))
      average_mapped_file=$((${total_mapped_file_for_app[$i]} / number_of_runs))
      average_total_writeback=$((${total_writeback_for_app[$i]} / number_of_runs))
      average_swap=$((${total_swap_for_app[$i]} / number_of_runs))
      average_pgpgin=$((${total_pg_pg_in_for_app[$i]} / number_of_runs))
      average_pgpgout=$((${total_pg_pg_out_for_app[$i]} / number_of_runs))
      average_pgfault=$((${total_pg_fault_for_app[$i]} / number_of_runs))
      average_pgmajfault=$((${total_pg_maj_fault_for_app[$i]} / number_of_runs))
      average_inactive_anon=$((${total_inactive_anon_for_app[$i]} / number_of_runs))
      average_active_anon=$((${total_active_anon_for_app[$i]} / number_of_runs))
      average_inactive_file=$((${total_inactive_file_for_app[$i]} / number_of_runs))
      average_active_file=$((${total_active_file_for_app[$i]} / number_of_runs))
      average_unevictable=$((${total_unevictable_for_app[$i]} / number_of_runs))


      if [[ $quiet_mode -lt 2 ]]; then
        echo "MEMCG SUMMARY for $package_to_profile"
        echo "-----------------------------------------------------------------"
        echo "Average cache: $average_cache KB"
        echo "Average rss: $average_rss KB"
        echo "Average rss huge: $average_rss_huge KB"
        echo "Average mapped file: $average_mapped_file KB"
        echo "Average total_writeback: $average_total_writeback KB"
        echo "Average swap: $average_swap KB"
        echo "Average pgpgin: $average_pgpgin"
        echo "Average pgpout: $average_pgpgout"
        echo "Average pgfault: $average_pgfault"
        echo "Average pgmajfault: $average_pgmajfault"
        echo "Average inactive anon: $average_inactive_anon KB"
        echo "Average active anon: $average_active_anon KB"
        echo "Average inactive file: $average_inactive_file KB"
        echo "Average active file: $average_active_file KB"
        echo "Average unevictable: $average_unevictable KB"
        echo ""
      fi

      summary_memcg_result="$summary_results_dir/$MEMCG_TEST-$summary_file_suffix.csv"
      ensure_csv "$summary_memcg_result" "$MEMCG_TEST_SUMMARY_CSV_HEADER"
      join_by "," \
        "$device_serial" \
        "$android_build_fingerprint" \
        "$mem_total" \
        "$package_to_profile" \
        "$app_version_code" \
        "$average_cache" \
        "$average_rss" \
        "$average_rss_huge" \
        "$average_mapped_file" \
        "$average_total_writeback" \
        "$average_swap" \
        "$average_pgpgin" \
        "$average_pgpgout" \
        "$average_pgfault" \
        "$average_pgmajfault" \
        "$average_inactive_anon" \
        "$average_active_anon" \
        "$average_inactive_file" \
        "$average_active_file" \
        "$average_unevictable" >> "$summary_memcg_result"
    fi
  done
  if [[ "${#process_to_profile_array[@]}" -gt 1 ]]; then
    package_to_profile="$package"
  fi
fi

if should_run_test "$GFXINFO_TEST"; then
  for i in "${!process_to_profile_array[@]}"; do
    if [[ -n "${gfxinfo_memory_usage[$i]}" ]]; then
      package_to_profile="${process_to_profile_array[$i]}"

      average_total_frames_rendered=$((${total_gfx_total_frames_rendered[$i]} / number_of_runs))
      average_janky_frames=$((${total_gfx_janky_frames[$i]} / number_of_runs))
      average_50th_percentile=$((${total_gfx_50th_percentile[$i]} / number_of_runs))
      average_90th_percentile=$((${total_gfx_90th_percentile[$i]} / number_of_runs))
      average_95th_percentile=$((${total_gfx_95th_percentile[$i]} / number_of_runs))
      average_99th_percentile=$((${total_gfx_99th_percentile[$i]} / number_of_runs))
      average_number_missed_vsync=$((${total_gfx_num_missed_vsync[$i]} / number_of_runs))
      average_number_high_input_latency=$((${total_gfx_num_high_input_latency[$i]} / number_of_runs))
      average_number_slow_UI_thread=$((${total_gfx_num_slow_ui_thread[$i]} / number_of_runs))
      average_number_slow_bitmap_uploads=$((${total_gfx_num_slow_bitmap_uploads[$i]} / number_of_runs))
      average_number_slow_issue_draw_commands=$((${total_gfx_num_slow_issue_draw_commands[$i]} / number_of_runs))
      average_gfx_memory_usage=$((${total_gfx_memory_usage[$i]} / number_of_runs))
      average_texture_cache=$((${total_gfx_texture_cache[$i]} / number_of_runs))
      average_layers_total=$((${total_gfx_layers_total[$i]} / number_of_runs))
      average_render_buffer_cache=$((${total_gfx_render_buffer_cache[$i]} / number_of_runs))
      average_gradient_cache=$((${total_gfx_gradient_cache[$i]} / number_of_runs))
      average_path_cache=$((${total_gfx_path_cache[$i]} / number_of_runs))
      average_tessellation_cache=$((${total_gfx_tessellation_cache[$i]} / number_of_runs))
      average_text_drop_shadow_cache=$((${total_gfx_text_drop_shadow_cache[$i]} / number_of_runs))
      average_patch_cache=$((${total_gfx_patch_cache[$i]} / number_of_runs))
      average_font_renderer_total=$((${total_gfx_font_renderer_total[$i]} / number_of_runs))


      if [[ $quiet_mode -lt 2 ]]; then
        echo "GFXINFO SUMMARY for $package_to_profile"
        echo "-----------------------------------------------------------------"
        echo "Average Total frames rendered: $average_total_frames_rendered"
        echo "Average Janky frames: $average_janky_frames"
        echo "Average 50th percentile: $average_50th_percentile ms"
        echo "Average 90th percentile: $average_90th_percentile ms"
        echo "Average 95th percentile: $average_95th_percentile ms"
        echo "Average 99th percentile: $average_99th_percentile ms"
        echo "Average Number Missed VSync: $average_number_missed_vsync"
        echo "Average Number High input latency: $average_number_high_input_latency"
        echo "Average Number Slow UI thread: $average_number_slow_UI_thread"
        echo "Average Number Slow bitmap uploads: $average_number_slow_bitmap_uploads"
        echo "Average Number Slow issue draw commands: $average_number_slow_issue_draw_commands"
        echo "Average memory usage: $average_gfx_memory_usage KB"
        echo "Average TextureCache: $average_texture_cache KB"
        echo "Average Layers total: $average_layers_total"
        echo "Average RenderBufferCache: $average_render_buffer_cache KB"
        echo "Average GradientCache: $average_gradient_cache KB"
        echo "Average PathCache: $average_path_cache KB"
        echo "Average TessellationCache: $average_tessellation_cache KB"
        echo "Average TextDropShadowCache: $average_text_drop_shadow_cache KB"
        echo "Average PatchCache: $average_patch_cache KB"
        echo "Average FontRenderer total: $average_font_renderer_total KB"
        echo ""
      fi
      summary_gfxinfo_result="$summary_results_dir/$GFXINFO_TEST-$summary_file_suffix.csv"
      ensure_csv "$summary_gfxinfo_result" "$GFXINFO_TEST_SUMMARY_CSV_HEADER"
      join_by "," \
        "$device_serial" \
        "$android_build_fingerprint" \
        "$mem_total" \
        "$package_to_profile" \
        "$app_version_code" \
        "$average_total_frames_rendered" \
        "$average_janky_frames" \
        "$average_50th_percentile" \
        "$average_90th_percentile" \
        "$average_95th_percentile" \
        "$average_99th_percentile" \
        "$average_number_missed_vsync" \
        "$average_number_high_input_latency" \
        "$average_number_slow_UI_thread" \
        "$average_number_slow_bitmap_uploads" \
        "$average_number_slow_issue_draw_commands" \
        "$average_gfx_memory_usage" \
        "$average_texture_cache" \
        "$average_layers_total" \
        "$average_render_buffer_cache" \
        "$average_gradient_cache" \
        "$average_path_cache" \
        "$average_tessellation_cache" \
        "$average_text_drop_shadow_cache" \
        "$average_patch_cache" \
        "$average_font_renderer_total" >> "$summary_gfxinfo_result"
    fi
  done
  if [[ "${#process_to_profile_array[@]}" -gt 1 ]]; then
    package_to_profile="$package"
  fi
fi

if should_run_test "$SIMPLEPERF_TEST"; then
  for i in "${!process_to_profile_array[@]}"; do
    if [[ -n "${simpleperf[$i]}" ]]; then
      package_to_profile="${process_to_profile_array[$i]}"

      average_cpu_cycles=$((${total_cpu_cycles[$i]} / number_of_runs))
      average_cache_misses=$((${total_cache_misses[$i]} / number_of_runs))
      average_page_faults=$((${total_page_faults[$i]} / number_of_runs))

      if [[ $quiet_mode -lt 2 ]]; then
        echo "SIMPLEPERF SUMMARY for $package_to_profile"
        echo "-----------------------------------------------------------------"
        echo "Average cpu cycles: $average_cpu_cycles"
        echo "Average cache misses: $average_cache_misses"
        echo "Average page faults: $average_page_faults"
      fi
      summary_simpleperf_result="$summary_results_dir/$SIMPLEPERF_TEST-$summary_file_suffix.csv"
      ensure_csv "$summary_simpleperf_result" \
        "$SIMPLEPERF_TEST_SUMMARY_CSV_HEADER"
      join_by "," \
        "$device_serial" \
        "$android_build_fingerprint" \
        "$mem_total" \
        "$package_to_profile" \
        "$app_version_code" \
        "$average_cpu_cycles" \
        "$average_cache_misses" \
        "$average_page_faults" >> "$summary_simpleperf_result"
    fi
  done
  if [[ "${#process_to_profile_array[@]}" -gt 1 ]]; then
    package_to_profile="$package"
  fi
fi

if [[ $quiet_mode -lt 2 ]]; then
  echo "=============================== END OF TEST ON $device_serial ==============================="
fi
