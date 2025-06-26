#!/vendor/bin/sh
#
# This script is for storage related init service including the below
#  - adjusting storage total size to the nearest power of 2.
#

ufs_size_prop="ro.boot.hardware.ufs"

ufs_size_str=`getprop "ro.boot.hardware.ufs"`
ufs_size=`echo "$ufs_size_str" | sed 's/[^0-9].*//'`
block_size=`getprop "ro.boot.hardware.cpu.pagesize"`

if [[ -z "$ufs_size" || -z "$block_size" ]]; then
	exit 1
fi

# Function to find the nearest LOWER power of 2
nearest_lower_power_of_2() {
	local num=$1

	if [[ "$num" -le 0 ]]; then
		return 1
	fi

	local power=1

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

	local ten_percent=$((lower_power / 10))

	if [[ "$((num - lower_power))" -le "$ten_percent" ]]; then
		local difference=$((num - lower_power))
		echo "$difference"
		return 0
	else
		return 1
	fi
}

difference=$(diff_from_nearest_lower_power_of_2 "$ufs_size")

if [[ $? -eq 0 ]]; then
	reserved_blocks=$((difference * (1024 * 1024 * 1024 / block_size)))
	echo "1" > /dev/sys/fs/by-name/userdata/carve_out
	echo "$reserved_blocks" > /dev/sys/fs/by-name/userdata/reserved_blocks
fi

