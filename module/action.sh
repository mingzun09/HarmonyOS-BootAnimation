#!/system/bin/sh
MODDIR=${0%/*}
printf '%s\n' 'HarmonyOS Boot Animation 1.0.0 - diagnostics'
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
