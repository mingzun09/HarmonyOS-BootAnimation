#!/system/bin/sh
# Common POSIX/BusyBox-ash helpers. Never write an OEM or theme original.

hlog() {
  printf '[%s] %s\n' "${HSTAGE:-unknown}" "$*" >> "$MODDIR/boot.log" 2>/dev/null || :
}

module_enabled() {
  [ ! -f "$MODDIR/disable" ] && [ ! -f "$MODDIR/remove" ]
}

meta_is_active() {
  case "$1" in /data/adb/modules/*) ;; *) return 1 ;; esac
  [ -d "$1" ] && [ -f "$1/module.prop" ] || return 1
  [ ! -f "$1/disable" ] && [ ! -f "$1/remove" ] && [ ! -f "$1/update" ] || return 1
  META_ID=${1##*/}
  [ ! -d "/data/adb/modules_update/$META_ID" ] || return 1
  awk '
    index($0, "=") {
      key=substr($0, 1, index($0, "=")-1)
      value=substr($0, index($0, "=")+1)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", key)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
      if (key == "metamodule") ready=(value == "1" || tolower(value) == "true")
    }
    END {exit(ready ? 0 : 1)}
  ' "$1/module.prop" 2>/dev/null
}

find_active_meta() {
  META_DIR=
  if [ -L /data/adb/metamodule ]; then
    META_CANDIDATE=$(readlink -f /data/adb/metamodule 2>/dev/null)
    if [ -n "$META_CANDIDATE" ] && [ -d "$META_CANDIDATE" ]; then
      # A valid selected pointer takes precedence, even when not ready. Never
      # silently select a second provider that the core will not use.
      if meta_is_active "$META_CANDIDATE"; then
        META_DIR=$META_CANDIDATE
        return 0
      fi
      return 1
    fi
  fi
  for META_PROP in /data/adb/modules/*/module.prop; do
    [ -f "$META_PROP" ] || continue
    META_CANDIDATE=${META_PROP%/module.prop}
    if meta_is_active "$META_CANDIDATE"; then
      META_DIR=$META_CANDIDATE
      return 0
    fi
  done
  return 1
}

allowed_bind_target() {
  case "$1" in
    /data/system/theme/bootanimation|/data/system/theme/bootanimation.zip|/data/system/theme/bootanimation-dark.zip) return 0 ;;
    /oem/media/*)
      BIND_NAME=${1#/oem/media/}
      case "$BIND_NAME" in ''|.*|*..*|*[!A-Za-z0-9._-]*) return 1 ;; esac
      return 0 ;;
  esac
  return 1
}

source_is_safe() {
  case "$1" in common/bind-[0-9][0-9].zip) ;; *) return 1 ;; esac
  [ -f "$MODDIR/$1" ] && [ ! -L "$MODDIR/$1" ]
}

target_is_safe() {
  allowed_bind_target "$1" || return 1
  [ -f "$1" ] && [ ! -L "$1" ] || return 1
  # Do not follow a theme-directory alias into an unexpected location.
  if [ "${1#/data/}" != "$1" ]; then
    [ ! -L /data/system ] && [ ! -L /data/system/theme ] || return 1
  else
    [ ! -L /oem ] && [ ! -L /oem/media ] || return 1
  fi
  return 0
}

file_is_mounted() {
  [ -r /proc/self/mountinfo ] || return 1
  awk -v target="$1" '$5 == target {found=1} END {exit(found ? 0 : 1)}' /proc/self/mountinfo 2>/dev/null
}

same_file() {
  LEFT_ID=$(stat -c '%d:%i' "$1" 2>/dev/null) || return 1
  RIGHT_ID=$(stat -c '%d:%i' "$2" 2>/dev/null) || return 1
  [ -n "$LEFT_ID" ] && [ "$LEFT_ID" = "$RIGHT_ID" ]
}

bind_one() {
  RELATIVE=$1
  TARGET=$2
  source_is_safe "$RELATIVE" && allowed_bind_target "$TARGET" || { hlog "refused invalid bind entry"; return 1; }
  SOURCE=$MODDIR/$RELATIVE
  if ! target_is_safe "$TARGET"; then
    hlog "bind skipped (absent, symlink or directory): $TARGET"
    return 0
  fi
  [ -r /proc/self/mountinfo ] || { hlog "bind skipped: mountinfo unavailable"; return 1; }
  if file_is_mounted "$TARGET"; then
    if same_file "$SOURCE" "$TARGET"; then
      hlog "own bind already present: $TARGET"
      return 0
    fi
    hlog "conflicting file mount, not stacking another bind: $TARGET"
    return 1
  fi
  # Use Android toybox ls for SELinux contexts; BusyBox builds vary.
  CONTEXT=
  CONTEXT_LINE=$(/system/bin/ls -Zd "$TARGET" 2>/dev/null)
  for CONTEXT_TOKEN in $CONTEXT_LINE; do
    case "$CONTEXT_TOKEN" in u:object_r:*:s0*) CONTEXT=$CONTEXT_TOKEN; break ;; esac
  done
  if [ -z "$CONTEXT" ]; then
    hlog "bind skipped: cannot read original SELinux context: $TARGET"
    return 1
  fi
  chcon "$CONTEXT" "$SOURCE" >/dev/null 2>&1 || {
    hlog "bind skipped: cannot set matching context: $TARGET"
    return 1
  }
  if mount --bind "$SOURCE" "$TARGET" 2>/dev/null; then
    if same_file "$SOURCE" "$TARGET"; then
      hlog "bound existing file (original untouched), $CONTEXT: $TARGET"
    else
      hlog "mount returned success but visibility check failed: $TARGET"
      return 1
    fi
  else
    hlog "bind failed (namespace/SELinux/mount provider): $TARGET"
    return 1
  fi
  return 0
}

bind_existing_targets() {
  [ -f "$MODDIR/common/bind-targets.txt" ] || return 0
  while IFS='|' read -r RELATIVE TARGET; do
    [ -n "$RELATIVE" ] && [ -n "$TARGET" ] || continue
    bind_one "$RELATIVE" "$TARGET" || :
  done < "$MODDIR/common/bind-targets.txt"
}

unbind_own_targets() {
  [ -f "$MODDIR/common/bind-targets.txt" ] || return 0
  while IFS='|' read -r RELATIVE TARGET; do
    source_is_safe "$RELATIVE" && target_is_safe "$TARGET" || continue
    SOURCE=$MODDIR/$RELATIVE
    # Never unmount a stock filesystem or another module's file mount.
    if file_is_mounted "$TARGET" && same_file "$SOURCE" "$TARGET"; then
      if umount "$TARGET" 2>/dev/null; then
        hlog "removed own temporary bind: $TARGET"
      else
        hlog "own bind busy; reboot will remove it: $TARGET"
      fi
    fi
  done < "$MODDIR/common/bind-targets.txt"
}

audit_system_targets() {
  VISIBLE_COUNT=0
  TARGET_COUNT=0
  [ -f "$MODDIR/common/system-targets.txt" ] || return 0
  while IFS= read -r ACTUAL; do
    [ -n "$ACTUAL" ] || continue
    TARGET_COUNT=$((TARGET_COUNT + 1))
    if [ -f "$ACTUAL" ] && cmp -s "$MODDIR/payload/bootanimation.zip" "$ACTUAL"; then
      VISIBLE_COUNT=$((VISIBLE_COUNT + 1))
      hlog "animation visible to this hook namespace: $ACTUAL"
    else
      hlog "not covered in this hook namespace: $ACTUAL"
    fi
  done < "$MODDIR/common/system-targets.txt"
  hlog "system paths visible: $VISIBLE_COUNT/$TARGET_COUNT (not a visual boot test)"
  if [ "$VISIBLE_COUNT" -eq 0 ]; then
    hlog "WARNING: check active mounting metamodule, module conflicts and root late-load."
  fi
}
