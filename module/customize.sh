#!/system/bin/sh
# Manager-sourced installer: default extraction is intentionally replaced.
SKIPUNZIP=1

[ "${BOOTMODE:-false}" = true ] || abort 'Use the root manager while Android is running; recovery install is unsupported.'

MODULE_VERSION=$(grep '^version=' "$MODPATH/module.prop" | cut -d= -f2-)
ui_print '========================================'
ui_print " HarmonyOS Boot Animation $MODULE_VERSION"
ui_print ' Original artwork / HyperOS 1 paths'
ui_print '========================================'

unzip -o "$ZIPFILE" module.prop customize.sh post-fs-data.sh post-mount.sh service.sh uninstall.sh action.sh 'common/*' 'payload/*' README.md LICENSE -d "$MODPATH" >&2 || abort 'Could not extract module files.'
[ -f "$MODPATH/common/lib.sh" ] && [ -f "$MODPATH/payload/bootanimation.zip" ] || abort 'Incomplete module ZIP.'
MODDIR=$MODPATH
. "$MODPATH/common/lib.sh"

if [ "${APATCH:-false}" = true ]; then
  ROOT_MANAGER=APatch
  ROOT_VERSION=${APATCH_VER:-${APATCH_VER_CODE:-unknown}}
elif [ "${KSU:-false}" = true ]; then
  ROOT_MANAGER=KernelSU
  ROOT_VERSION=${KSU_VER:-unknown}
elif [ -n "${MAGISK_VER:-}" ] || [ -f /data/adb/magisk/util_functions.sh ]; then
  ROOT_MANAGER=Magisk
  ROOT_VERSION=${MAGISK_VER:-unknown}
else
  abort 'This installer requires Magisk, KernelSU (including Next) or APatch.'
fi

if [ "${KSU_RUNTIME_MODE:-}" = late-load ] || [ "${KSU_LATE_LOAD:-0}" = 1 ]; then
  abort 'KSU late-load occurs after boot animation; use an early-boot root mode before installing.'
fi

EXPECTED_HASH=$(tr -d '\r\n ' < "$MODPATH/common/payload.sha256")
ACTUAL_HASH=$(sha256sum "$MODPATH/payload/bootanimation.zip" 2>/dev/null) || abort 'sha256sum unavailable; cannot verify payload.'
ACTUAL_HASH=${ACTUAL_HASH%% *}
[ ${#EXPECTED_HASH} -eq 64 ] && [ "$ACTUAL_HASH" = "$EXPECTED_HASH" ] || abort 'Animation checksum mismatch. Download the complete ZIP again.'
ANIMATION_HEADER=$(unzip -p "$MODPATH/payload/bootanimation.zip" desc.txt 2>/dev/null | head -n 1)
case "$ANIMATION_HEADER" in
  [0-9]*' '[0-9]*' '[0-9]*) ;;
  *) abort 'Invalid animation descriptor.' ;;
esac
unzip -t "$MODPATH/payload/bootanimation.zip" >/dev/null 2>&1 || abort 'Animation ZIP failed integrity test.'

: > "$MODPATH/install.log"
printf 'module=%s\nmanager=%s\nmanager_version=%s\npayload_sha256=%s\n' "$MODULE_VERSION" "$ROOT_MANAGER" "$ROOT_VERSION" "$EXPECTED_HASH" >> "$MODPATH/install.log"
printf 'device=%s\nhyperos_property=%s\nmiui_property=%s\n' "$(getprop ro.product.device)" "$(getprop ro.mi.os.version.name)" "$(getprop ro.miui.ui.version.name)" >> "$MODPATH/install.log"
ui_print "- Root manager: $ROOT_MANAGER $ROOT_VERSION"

# There is no stable cross-fork HAS_METAMODULE flag. Only known, inspected
# release names are treated as definitely requiring a provider. Unknown older
# versions can have built-in mounting; do not guess from kernel version codes.
REQUIRES_META=false
if [ "$ROOT_MANAGER" = KernelSU ]; then
  VERSION_TOKEN=$(printf '%s' "$ROOT_VERSION" | sed -n 's/^[^0-9]*\([0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\).*/\1/p')
  case "$VERSION_TOKEN" in 3.3.1|3.4.2) REQUIRES_META=true ;; esac
elif [ "$ROOT_MANAGER" = APatch ] && [ "${APATCH_VER_CODE:-}" = 11282 ]; then
  REQUIRES_META=true
fi

if [ "$ROOT_MANAGER" != Magisk ]; then
  if find_active_meta; then
    ui_print "- Active metamodule metadata: ${META_DIR##*/}"
    if [ ! -f "$META_DIR/metamount.sh" ]; then
      ui_print '! Provider has no optional metamount.sh hook; confirm it mounts system overlays early.'
    fi
    ui_print '- Runtime mounting will be audited after reboot.'
    printf 'mount_provider=%s\nprovider_runtime_verified=no\n' "$META_DIR" >> "$MODPATH/install.log"
  elif [ "$REQUIRES_META" = true ]; then
    abort 'No ready mounting metamodule. Install/enable a compatible provider, reboot, then install this module. Pending updates are not ready.'
  else
    ui_print '! Mounting ability is unknown for this root version.'
    ui_print '! Modern KSU/APatch need an enabled mounting metamodule.'
    ui_print '! If a provider was just installed/updated, reboot first.'
    printf 'mount_provider=unknown_or_legacy_builtin\nprovider_runtime_verified=no\n' >> "$MODPATH/install.log"
  fi
else
  printf 'mount_provider=Magisk_builtin\nprovider_runtime_verified=no\n' >> "$MODPATH/install.log"
fi

SYSTEM_COUNT=0
BIND_COUNT=0
: > "$MODPATH/common/system-targets.txt"
: > "$MODPATH/common/system-mappings.txt"
: > "$MODPATH/common/bind-targets.txt"

register_system() {
  ACTUAL=$1
  DESTINATION=$2
  case "$DESTINATION" in system/*) ;; *) abort 'Internal destination check failed.' ;; esac
  case "$DESTINATION" in *..*|*[!A-Za-z0-9._/-]*) abort 'Unsafe module destination.' ;; esac
  if grep -Fx "$ACTUAL" "$MODPATH/common/system-targets.txt" >/dev/null 2>&1; then
    return 0
  fi
  mkdir -p "$MODPATH/${DESTINATION%/*}" || abort 'Cannot create module overlay directory.'
  cp -f "$MODPATH/payload/bootanimation.zip" "$MODPATH/$DESTINATION" || abort 'Cannot copy animation.'
  printf '%s\n' "$ACTUAL" >> "$MODPATH/common/system-targets.txt"
  printf '%s|%s\n' "$ACTUAL" "$DESTINATION" >> "$MODPATH/common/system-mappings.txt"
  printf 'system_target=%s -> %s\n' "$ACTUAL" "$DESTINATION" >> "$MODPATH/install.log"
  SYSTEM_COUNT=$((SYSTEM_COUNT + 1))
}

register_bind() {
  allowed_bind_target "$1" || abort 'Unsafe bind target.'
  if awk -F '|' -v target="$1" '$2 == target {found=1} END {exit(found ? 0 : 1)}' "$MODPATH/common/bind-targets.txt" 2>/dev/null; then
    return 0
  fi
  BIND_COUNT=$((BIND_COUNT + 1))
  [ "$BIND_COUNT" -le 99 ] || abort 'Too many bind candidates.'
  BIND_RELATIVE=$(printf 'common/bind-%02d.zip' "$BIND_COUNT")
  cp -f "$MODPATH/payload/bootanimation.zip" "$MODPATH/$BIND_RELATIVE" || abort 'Cannot prepare independent bind source.'
  printf '%s|%s\n' "$BIND_RELATIVE" "$1" >> "$MODPATH/common/bind-targets.txt"
  printf 'bind_candidate=%s (only if an existing safe regular file)\n' "$1" >> "$MODPATH/install.log"
}

# Module directories, not live system files, are populated here. Standard root
# mounting providers understand system/{product,vendor,system_ext}.
register_system /system/media/bootanimation.zip system/media/bootanimation.zip
[ ! -f /system/media/bootanimation-dark.zip ] || register_system /system/media/bootanimation-dark.zip system/media/bootanimation-dark.zip

PRODUCT_MEDIA=
if [ -d /product/media ]; then
  PRODUCT_MEDIA=/product/media
elif [ -d /system/product/media ]; then
  PRODUCT_MEDIA=/system/product/media
fi
if [ -n "$PRODUCT_MEDIA" ]; then
  register_system "$PRODUCT_MEDIA/bootanimation.zip" system/product/media/bootanimation.zip
  [ ! -f "$PRODUCT_MEDIA/bootanimation-dark.zip" ] || register_system "$PRODUCT_MEDIA/bootanimation-dark.zip" system/product/media/bootanimation-dark.zip
fi

for PARTITION in vendor system_ext; do
  REAL_MEDIA=
  if [ -d "/$PARTITION/media" ]; then
    REAL_MEDIA=/$PARTITION/media
  elif [ -d "/system/$PARTITION/media" ]; then
    REAL_MEDIA=/system/$PARTITION/media
  fi
  [ -n "$REAL_MEDIA" ] || continue
  for NAME in bootanimation.zip bootanimation-dark.zip; do
    [ ! -f "$REAL_MEDIA/$NAME" ] || register_system "$REAL_MEDIA/$NAME" "system/$PARTITION/media/$NAME"
  done
done

# Some Xiaomi regional configurations use an additional existing asset. These
# are candidates observed in public modules, not a claimed Xiaomi priority list.
for REGIONAL in /system/media/theme/bootanimation.zip /system/media/theme/cust_config/*/bootanimation.zip; do
  [ -f "$REGIONAL" ] || continue
  register_system "$REGIONAL" "system/${REGIONAL#/system/}"
done

# Xiaomi theme implementations differ: support both extensionless and ZIP
# candidates, but never create, delete, rename, chmod or overwrite originals.
register_bind /data/system/theme/bootanimation
register_bind /data/system/theme/bootanimation.zip
register_bind /data/system/theme/bootanimation-dark.zip
[ ! -f /oem/media/bootanimation.zip ] || register_bind /oem/media/bootanimation.zip

CUSTOM_BOOT_FILE=$(getprop ro.product.bootanim.file)
printf 'ro.product.bootanim.file=%s\n' "$CUSTOM_BOOT_FILE" >> "$MODPATH/install.log"
case "$CUSTOM_BOOT_FILE" in
  ''|*..*|*[!A-Za-z0-9._/-]*) CUSTOM_BOOT_FILE= ;;
esac
if [ -n "$CUSTOM_BOOT_FILE" ]; then
  CUSTOM_DESTINATION=
  case "$CUSTOM_BOOT_FILE" in
    /product/media/*) CUSTOM_DESTINATION=system/product/media/${CUSTOM_BOOT_FILE#/product/media/} ;;
    /system/product/media/*) CUSTOM_DESTINATION=system/product/media/${CUSTOM_BOOT_FILE#/system/product/media/} ;;
    /system/media/*) CUSTOM_DESTINATION=system/media/${CUSTOM_BOOT_FILE#/system/media/} ;;
    /vendor/media/*) CUSTOM_DESTINATION=system/vendor/media/${CUSTOM_BOOT_FILE#/vendor/media/} ;;
    /system/vendor/media/*) CUSTOM_DESTINATION=system/vendor/media/${CUSTOM_BOOT_FILE#/system/vendor/media/} ;;
    /system_ext/media/*) CUSTOM_DESTINATION=system/system_ext/media/${CUSTOM_BOOT_FILE#/system_ext/media/} ;;
    /system/system_ext/media/*) CUSTOM_DESTINATION=system/system_ext/media/${CUSTOM_BOOT_FILE#/system/system_ext/media/} ;;
    /oem/media/*)
      if allowed_bind_target "$CUSTOM_BOOT_FILE"; then
        [ ! -f "$CUSTOM_BOOT_FILE" ] || register_bind "$CUSTOM_BOOT_FILE"
      else
        ui_print '! Unsupported nested/hidden OEM property path; safely skipped.'
        printf 'unsupported_oem_property=%s\n' "$CUSTOM_BOOT_FILE" >> "$MODPATH/install.log"
      fi ;;
    /*|*/*) ui_print '! Nonstandard boot animation property path; see install.log.' ;;
    *)
      if [ -n "$PRODUCT_MEDIA" ]; then
        CUSTOM_DESTINATION=system/product/media/$CUSTOM_BOOT_FILE
        CUSTOM_BOOT_FILE=$PRODUCT_MEDIA/$CUSTOM_BOOT_FILE
      fi ;;
  esac
  if [ -n "$CUSTOM_DESTINATION" ] && [ -f "$CUSTOM_BOOT_FILE" ]; then
    register_system "$CUSTOM_BOOT_FILE" "$CUSTOM_DESTINATION"
  fi
fi

# No skip_mount / .replace / system.prop / sepolicy.rule is installed.
set_perm_recursive "$MODPATH" 0 0 0755 0644 u:object_r:system_file:s0
for SCRIPT in customize.sh post-fs-data.sh post-mount.sh service.sh uninstall.sh action.sh; do
  set_perm "$MODPATH/$SCRIPT" 0 0 0755
done
set_perm "$MODPATH/common/lib.sh" 0 0 0644

# Default module permissions first, then match existing asset labels on each
# independent overlay file. In particular, vendor assets need not be system_file.
while IFS='|' read -r ACTUAL DESTINATION; do
  [ -f "$ACTUAL" ] || continue
  ZIP_CONTEXT=
  ZIP_CONTEXT_LINE=$(/system/bin/ls -Zd "$ACTUAL" 2>/dev/null)
  for ZIP_CONTEXT_TOKEN in $ZIP_CONTEXT_LINE; do
    case "$ZIP_CONTEXT_TOKEN" in u:object_r:*:s0*) ZIP_CONTEXT=$ZIP_CONTEXT_TOKEN; break ;; esac
  done
  if [ -n "$ZIP_CONTEXT" ]; then
    chcon "$ZIP_CONTEXT" "$MODPATH/$DESTINATION" >/dev/null 2>&1 || abort "Could not match existing asset SELinux label: $ACTUAL"
    printf 'system_context=%s|%s\n' "$ACTUAL" "$ZIP_CONTEXT" >> "$MODPATH/install.log"
  else
    ui_print "! Original asset context unavailable; standard module label retained: $ACTUAL"
    printf 'system_context_unavailable=%s\n' "$ACTUAL" >> "$MODPATH/install.log"
  fi
done < "$MODPATH/common/system-mappings.txt"

printf 'system_target_count=%s\nbind_candidate_count=%s\ninstallation_completed=yes\n' "$SYSTEM_COUNT" "$BIND_COUNT" >> "$MODPATH/install.log"
ui_print "- Prepared $SYSTEM_COUNT system target(s), $BIND_COUNT safe bind candidate(s)."
ui_print '- White HarmonyOS wordmark on black + blue breathing underline, 30 FPS.'
ui_print '- Disable other boot animation modules, then reboot.'
ui_print '- This does not change the first MI/Redmi/POCO bootloader logo.'
ui_print '- Module action shows logs; no physical phone test has been performed.'
