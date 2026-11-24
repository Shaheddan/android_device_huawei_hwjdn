#!/vendor/bin/sh
#
# Swap to storage (Settings > System > Performance > Memory): a swap file on /data
# that takes over once compressed RAM (zram) is full. The tablet's 3.10 kernel has no zram
# writeback, so this is a plain swap file. Size in MB from persist.vendor.kiwi.perf.swap
# (0, 512, 1024 or 2048). Started by init once per boot right after zram is on;
# swapon without -p gives the file a lower priority than zram, so zram always fills
# first. The file is written out once with dd (swapon refuses files with holes) and
# kept for the next boots; picking Off deletes it.
#
# What happened ends up in vendor.kiwi.perf.swap: the size in use, 0 for off,
# "nospace" (not enough free space on /data) or "failed". A size that failed once
# (say /data was formatted f2fs, which can't swap on this kernel) isn't retried every
# boot, that would write the whole file each time; switching it off and on retries.

F=/data/vendor/swap/swapfile

MB=$(getprop persist.vendor.kiwi.perf.swap)
case "$MB" in
    512|1024|2048) ;;
    *) MB=0 ;;
esac

if [ "$MB" = 0 ]; then
    rm -f "$F" "$F".failed-*
    setprop vendor.kiwi.perf.swap 0
    exit 0
fi

if [ -e "$F.failed-$MB" ]; then
    setprop vendor.kiwi.perf.swap failed
    exit 0
fi

# Already on (the service was started twice): leave it alone.
if grep -q "^$F " /proc/swaps; then
    setprop vendor.kiwi.perf.swap "$MB"
    exit 0
fi

fail() {
    rm -f "$F"
    [ "$1" = failed ] && touch "$F.failed-$MB"
    setprop vendor.kiwi.perf.swap "$1"
    exit 0
}

if [ "$(stat -c %s "$F" 2>/dev/null)" != "$((MB * 1048576))" ]; then
    rm -f "$F"
    # Leave at least 1 GB free on /data once the file is there.
    set -- $(df -k /data | tail -n 1)
    [ "$(( ${4:-0} / 1024 ))" -ge "$((MB + 1024))" ] || fail nospace
    dd if=/dev/zero of="$F" bs=1048576 count="$MB" 2>/dev/null || fail failed
    chmod 600 "$F"
    mkswap "$F" >/dev/null 2>&1 || fail failed
fi

if swapon "$F" 2>/dev/null; then
    setprop vendor.kiwi.perf.swap "$MB"
elif mkswap "$F" >/dev/null 2>&1 && swapon "$F" 2>/dev/null; then
    # the header was damaged; it is just swap, so rewrite it
    setprop vendor.kiwi.perf.swap "$MB"
else
    fail failed
fi
