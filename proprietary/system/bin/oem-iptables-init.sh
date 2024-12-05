#!/system/bin/sh
/system/bin/iptables -w -N oem_in
/system/bin/iptables -w -I INPUT -j oem_in
/system/bin/ip6tables -w -N oem_in
/system/bin/ip6tables -w -I INPUT -j oem_in
