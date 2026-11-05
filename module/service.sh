#!/system/bin/sh
# One non-blocking late retry and diagnostic pass. No resident daemon.
MODDIR=${0%/*}
[ -f "$MODDIR/common/lib.sh" ] || exit 0
. "$MODDIR/common/lib.sh"
module_enabled || exit 0
HSTAGE=service
hlog 'one late retry; a late retry cannot fix an animation already opened'
bind_existing_targets
audit_system_targets
exit 0
