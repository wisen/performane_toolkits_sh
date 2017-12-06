@echo on
del /q /s lmdd_test_result.log
@echo == HW Info ==  > lmdd_test_result.log
@adb root
@echo stop android runtime...
@adb shell stop
@adb shell sleep 10
@adb shell cat /proc/cpuinfo >> lmdd_test_result.log

@echo pushing...
@adb push bin\lmdd /data
@adb shell chmod 777 /data/lmdd

del /q /s lmdd_partition_eMMCSDIos_fs_info.log
@echo === Mount Info ======================== > lmdd_partition_eMMCSDIos_fs_info.log
@adb shell mount >>lmdd_partition_eMMCSDIos_fs_info.log

@echo === df Info =========================== >> lmdd_partition_eMMCSDIos_fs_info.log
@adb shell df /storage/* >>lmdd_partition_eMMCSDIos_fs_info.log
@adb shell df /data >>lmdd_partition_eMMCSDIos_fs_info.log

@echo === emmc ios Info =========================== >> lmdd_partition_eMMCSDIos_fs_info.log
@adb shell cat /sys/block/mmcblk0/device/cid >>lmdd_partition_eMMCSDIos_fs_info.log
@adb shell cat /sys/kernel/debug/mmc0/clock >>lmdd_partition_eMMCSDIos_fs_info.log
@adb shell cat /sys/kernel/debug/mmc0/ios >>lmdd_partition_eMMCSDIos_fs_info.log

@echo === sdcard ios Info =========================== >> lmdd_partition_eMMCSDIos_fs_info.log
@adb shell cat /sys/kernel/debug/mmc1/clock >>lmdd_partition_eMMCSDIos_fs_info.log
@adb shell cat /sys/kernel/debug/mmc1/ios >>lmdd_partition_eMMCSDIos_fs_info.log

@echo === fs Info =========================== >> lmdd_partition_eMMCSDIos_fs_info.log
@echo dirty_ratio: >> lmdd_partition_eMMCSDIos_fs_info.log
@adb shell cat /proc/sys/vm/dirty_ratio >>lmdd_partition_eMMCSDIos_fs_info.log
@echo dirty_background_ratio: >> lmdd_partition_eMMCSDIos_fs_info.log
@adb shell cat /proc/sys/vm/dirty_background_ratio >>lmdd_partition_eMMCSDIos_fs_info.log

@echo === Security Info =========================== >> lmdd_partition_eMMCSDIos_fs_info.log
@adb shell getenforce >> lmdd_partition_eMMCSDIos_fs_info.log

@echo === Encrypt Info =========================== >> lmdd_partition_eMMCSDIos_fs_info.log
@adb shell getprop ro.crypto.state >>lmdd_partition_eMMCSDIos_fs_info.log
@adb shell getprop vold.decrypt >>lmdd_partition_eMMCSDIos_fs_info.log

@echo === block Info =========================== >> lmdd_partition_eMMCSDIos_fs_info.log
@echo === [name] =========================== >> lmdd_partition_eMMCSDIos_fs_info.log
@adb shell ls /sys/block/mmcblk0/queue/ >>lmdd_partition_eMMCSDIos_fs_info.log
@echo === [value] =========================== >> lmdd_partition_eMMCSDIos_fs_info.log
@adb shell cat /sys/block/mmcblk0/queue/* >>lmdd_partition_eMMCSDIos_fs_info.log

del /q /s lmdd_memory_info.log
@echo === Meminfo Info =========================== > lmdd_memory_info.log
@adb shell cat /proc/meminfo >>lmdd_memory_info.log
@echo === zoneinfo =========================== >> lmdd_memory_info.log
@adb shell cat /proc/zoneinfo >>lmdd_memory_info.log
@echo === zraminfo =========================== >> lmdd_memory_info.log
@adb shell cat /proc/zraminfo >>lmdd_memory_info.log
@echo === dumpsys meminfo =========================== >> lmdd_memory_info.log
@adb shell dumpsys meminfo >>lmdd_memory_info.log
@echo === procrank =========================== >> lmdd_memory_info.log
@adb shell procrank >>lmdd_memory_info.log
@echo === memory_layout =========================== >> lmdd_memory_info.log
@adb shell cat /proc/mtk_memcfg/memory_layout >>lmdd_memory_info.log
@echo === memory_usage =========================== >> lmdd_memory_info.log
@adb shell cat /proc/mali/memory_usage >>lmdd_memory_info.log
@echo === lowmemorykiller =========================== >> lmdd_memory_info.log
@adb shell cat /sys/module/lowmemorykiller/parameters/adj >>lmdd_memory_info.log
@adb shell cat /sys/module/lowmemorykiller/parameters/minfree >>lmdd_memory_info.log
@echo === /proc/sys/vm/swappiness =========================== >> lmdd_memory_info.log
@adb shell cat /proc/sys/vm/swappiness >>lmdd_memory_info.log
@echo === vmallocinfo =========================== >> lmdd_memory_info.log
@adb shell cat /proc/vmallocinfo >>lmdd_memory_info.log
@echo === ion_mm_heap =========================== >> lmdd_memory_info.log
@adb shell cat /sys/kernel/debug/ion/ion_mm_heap >>lmdd_memory_info.log
@echo === buffer_total_size_kb =========================== >> lmdd_memory_info.log
@adb shell cat /sys/kernel/debug/tracing/buffer_total_size_kb >>lmdd_memory_info.log
@echo === gpu_memory =========================== >> lmdd_memory_info.log
@adb shell cat /sys/kernel/debug/mali/gpu_memory >> lmdd_memory_info.log
@adb shell cat /d/pvr/driver_stats >> lmdd_memory_info.log
@adb shell ls -l /d/pvr/pid >> lmdd_memory_info.log
@adb shell cat /d/pvr/pid/*/process_stats >> lmdd_memory_info.log
@echo === slabinfo =========================== >> lmdd_memory_info.log
@adb shell cat /proc/slabinfo >>lmdd_memory_info.log
@echo === buddyinfo =========================== >> lmdd_memory_info.log
@adb shell cat /proc/buddyinfo >>lmdd_memory_info.log
@echo === ps =========================== >> lmdd_memory_info.log
@adb shell ps -t >>lmdd_memory_info.log
@echo === gfxinfo =========================== >> lmdd_memory_info.log
@adb shell dumpsys gfxinfo >>lmdd_memory_info.log
@echo === service list =========================== >> lmdd_memory_info.log
@adb shell service list >>lmdd_memory_info.log

@Rem @echo === ls -l /storage/sdcard* Info =================== >> lmdd_test_result.log
@Rem @adb shell ls -l /storage/sdcard* >>lmdd_test_result.log

@FOR %%I in (data cache) DO @(

@echo ===%%I lmdd write test =========================== >> lmdd_test_result.log
@echo ===%%I lmdd write test ===========================
@FOR %%J in (8k 32k 64k 128k 512k 2m 8m 32m 64m 128m 256m) DO @(
@echo === %%J === >> lmdd_test_result.log
@echo === %%J ===
@adb shell /data/lmdd if=internal of=/%%I/dumb move=%%J fsync=1 >> lmdd_test_result.log
@adb shell /data/lmdd if=internal of=/%%I/dumb move=%%J fsync=1 >> lmdd_test_result.log
@adb shell /data/lmdd if=internal of=/%%I/dumb move=%%J fsync=1 >> lmdd_test_result.log
@adb shell /data/lmdd if=internal of=/%%I/dumb move=%%J fsync=1 >> lmdd_test_result.log
@adb shell /data/lmdd if=internal of=/%%I/dumb move=%%J fsync=1 >> lmdd_test_result.log
@adb shell /data/lmdd if=internal of=/%%I/dumb move=%%J fsync=1 >> lmdd_test_result.log
@adb shell /data/lmdd if=internal of=/%%I/dumb move=%%J fsync=1 >> lmdd_test_result.log
@adb shell /data/lmdd if=internal of=/%%I/dumb move=%%J fsync=1 >> lmdd_test_result.log
@adb shell /data/lmdd if=internal of=/%%I/dumb move=%%J fsync=1 >> lmdd_test_result.log
@adb shell /data/lmdd if=internal of=/%%I/dumb move=%%J fsync=1 >> lmdd_test_result.log
)
)

@FOR %%I in (data cache) DO @(
@echo ===%%I lmdd read test ============================ >> lmdd_test_result.log
@echo ===%%I lmdd read test ============================
@FOR %%J in (8k 32k 64k 128k 512k 2m 8m 32m 64m 128m 256m) DO @(
@echo === %%J === >> lmdd_test_result.log
@echo === %%J ===
@adb shell "echo 3 > /proc/sys/vm/drop_caches"
@adb shell /data/lmdd if=/%%I/dumb of=internal move=%%J fsync=1 >> lmdd_test_result.log
@adb shell "echo 3 > /proc/sys/vm/drop_caches"
@adb shell /data/lmdd if=/%%I/dumb of=internal move=%%J fsync=1 >> lmdd_test_result.log
@adb shell "echo 3 > /proc/sys/vm/drop_caches"
@adb shell /data/lmdd if=/%%I/dumb of=internal move=%%J fsync=1 >> lmdd_test_result.log
@adb shell "echo 3 > /proc/sys/vm/drop_caches"
@adb shell /data/lmdd if=/%%I/dumb of=internal move=%%J fsync=1 >> lmdd_test_result.log
@adb shell "echo 3 > /proc/sys/vm/drop_caches"
@adb shell /data/lmdd if=/%%I/dumb of=internal move=%%J fsync=1 >> lmdd_test_result.log
@adb shell "echo 3 > /proc/sys/vm/drop_caches"
@adb shell /data/lmdd if=/%%I/dumb of=internal move=%%J fsync=1 >> lmdd_test_result.log
@adb shell "echo 3 > /proc/sys/vm/drop_caches"
@adb shell /data/lmdd if=/%%I/dumb of=internal move=%%J fsync=1 >> lmdd_test_result.log
@adb shell "echo 3 > /proc/sys/vm/drop_caches"
@adb shell /data/lmdd if=/%%I/dumb of=internal move=%%J fsync=1 >> lmdd_test_result.log
@adb shell "echo 3 > /proc/sys/vm/drop_caches"
@adb shell /data/lmdd if=/%%I/dumb of=internal move=%%J fsync=1 >> lmdd_test_result.log
@adb shell "echo 3 > /proc/sys/vm/drop_caches"
@adb shell /data/lmdd if=/%%I/dumb of=internal move=%%J fsync=1 >> lmdd_test_result.log
)
)

@adb shell rm /data/lmdd

@echo *******************
@echo ****  test OK  ****
@echo *******************

@echo ******************* >> lmdd_test_result.log
@echo ****  test OK  **** >> lmdd_test_result.log
@echo ******************* >> lmdd_test_result.log

@adb reboot
@pause 