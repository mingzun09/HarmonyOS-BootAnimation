#!/system/bin/sh
MODDIR=${0%/*}
[ -f "$MODDIR/common/lib.sh" ] || exit 0
. "$MODDIR/common/lib.sh"
module_enabled || exit 0
HSTAGE=post-fs-data
: > "$MODDIR/boot.log"
hlog 'early hook; no sleep, no boot-completed property wait'
hlog "mount namespace: self=$(readlink /proc/self/ns/mnt 2>/dev/null) init=$(readlink /proc/1/ns/mnt 2>/dev/null)"
bind_existing_targets
exit 0
