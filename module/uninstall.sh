#!/system/bin/sh
MODDIR=${0%/*}
[ -f "$MODDIR/common/lib.sh" ] || exit 0
. "$MODDIR/common/lib.sh"
HSTAGE=uninstall
unbind_own_targets
# Nothing was written outside the module. System overlays disappear on reboot.
exit 0
