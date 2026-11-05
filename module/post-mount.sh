#!/system/bin/sh
# Modern KSU / APatch run this after their mounting metamodule.
MODDIR=${0%/*}
[ -f "$MODDIR/common/lib.sh" ] || exit 0
. "$MODDIR/common/lib.sh"
module_enabled || exit 0
HSTAGE=post-mount
hlog 'post-mount hook (execution alone does not prove the provider mounted)'
bind_existing_targets
exit 0
