#!/system/bin/sh
MODDIR=${0%/*}
MODULE_VERSION=$(grep '^version=' "$MODDIR/module.prop" 2>/dev/null | cut -d= -f2-)
[ -n "$MODULE_VERSION" ] || MODULE_VERSION=unknown
printf '%s\n' "HarmonyOS Boot Animation $MODULE_VERSION - diagnostics"
if [ -f "$MODDIR/common/lib.sh" ]; then
  . "$MODDIR/common/lib.sh"
  HSTAGE=action
  audit_system_targets
fi
printf '\n%s\n' '--- installation ---'
[ ! -f "$MODDIR/install.log" ] || cat "$MODDIR/install.log"
printf '\n%s\n' '--- latest boot / local namespace ---'
[ ! -f "$MODDIR/boot.log" ] || cat "$MODDIR/boot.log"
printf '\n%s\n' 'If stock animation remains, share these logs and your phone/ROM/root/provider versions.'
exit 0
