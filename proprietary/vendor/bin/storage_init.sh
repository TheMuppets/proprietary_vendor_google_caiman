#!/vendor/bin/sh
#
# This script is for storage related init service including the below
#  - adjusting storage total size to the nearest power of 2.
#  - adjusting reserved_segments with 12 x {zone size} for ZUFS.
#

ufs_size_prop="ro.boot.hardware.ufs"

ufs_size_str=`getprop "ro.boot.hardware.ufs"`
ufs_size=`echo "$ufs_size_str" | sed 's/[^0-9].*//'`
block_size=`getprop "ro.boot.hardware.cpu.pagesize"`

sysfs_userdata="/dev/sys/fs/by-name/userdata"

if [[ -z "$ufs_size" || -z "$block_size" ]]; then
	exit 1
fi

# Function to find the nearest LOWER power of 2 (make number 1000 from 1024)
nearest_lower_power_of_2() {
	local num=$1
	local power

	if [[ "$num" -le 0 ]]; then
		return 1
	fi

	if [[ "$num" -ge 1000 ]]; then
		power=1000
	else
		power=1
	fi

	while [[ "$((power * 2))" -le "$num" ]]; do
		power=$((power * 2))
	done

	echo "$power"
	return 0
}

diff_from_nearest_lower_power_of_2() {
	local num=$1
	local lower_power=$(nearest_lower_power_of_2 "$num")

	if [[ $? -ne 0 ]]; then
		return 1
	fi

	local twenty_percent=$((lower_power / 5))

	if [[ "$((num - lower_power))" -le "$twenty_percent" ]]; then
		local difference=$((num - lower_power))
		echo "$difference"
		return 0
	else
		return 1
	fi
}

difference=$(diff_from_nearest_lower_power_of_2 "$ufs_size")

if [[ $? -eq 0 ]] && [[ -e "$sysfs_userdata/carve_out" ]]; then
	reserved_blocks=$((difference * (1024 * 1024 * 1024 / block_size)))
	echo "1" > $sysfs_userdata/carve_out
	echo "$reserved_blocks" > $sysfs_userdata/reserved_blocks
fi

dm_dev_name=$(basename "$(readlink "$sysfs_userdata")")
proc_disk_map="/proc/fs/f2fs/$dm_dev_name/disk_map"
sysfs_reserved_segs="$sysfs_userdata/reserved_segments"
zufs=`getprop "ro.boot.zufs_provisioned"`

if [ "$zufs" != "true" ]; then
	echo "Storage is not ZUFS."
	exit 0
fi

if [ ! -f "$proc_disk_map" ]; then
	echo "$proc_disk_map is not found."
	exit 0
fi

reserved_segs=$(grep "Section size" "$proc_disk_map" | awk '{print $4}' | grep -oE '^[0-9]+$')
if [ -z "$reserved_segs" ]; then
	echo "Invalid section size: $reserved_segs"
	exit 0
fi

# Make it segment count by dividing by 2MB and mutiply it by 12 zones
reserved_segs=$(( (reserved_segs / 2) * 12 ))

if [ ! -f "$sysfs_reserved_segs" ]; then
	echo "$sysfs_reserved_segs is not found."
	exit 0
fi

sysfs_val=$(cat "$sysfs_reserved_segs" | grep -oE '^[0-9]+$')

if [ -z "$sysfs_val" ]; then
	echo "Invalid reserved_segments: $sysfs_val"
	exit 0
fi

if [ "$sysfs_val" -gt "$reserved_segs" ]; then
	echo "$reserved_segs" > "$sysfs_reserved_segs"
	echo "Set reserved_segments with $reserved_segs"
fi

