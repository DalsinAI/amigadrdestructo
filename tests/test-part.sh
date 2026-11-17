#!/bin/sh
# Unit test for scripts/write-part.sh on a fake part drawer.
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
D="$T/Games/DrDestructo"; mkdir -p "$D/Data/Levels" "$D/Data/Music" "$D/Data/Sounds"
for f in DrDestructo DrDestructo.info ReadMe Data/Music/music.xml Data/Levels/level1.xml Data/Sounds/engine1.ogg; do : > "$D/$f"; done
sh "$HERE/scripts/write-part.sh" "$T" 1.0
fail() { echo "FAIL: $*"; cat "$T/Part"; exit 1; }
[ "$(sed -n 1p "$T/Part")" = "part DrDestructo 1.0" ] || fail header
grep -qx 'needs 68040' "$T/Part" || fail needs
grep -qx 'copy "Games/DrDestructo/DrDestructo" "SYS:Games/DrDestructo/DrDestructo"' "$T/Part" || fail program
grep -qx 'default "Games/DrDestructo/DrDestructo.info" "SYS:Games/DrDestructo/DrDestructo.info"' "$T/Part" || fail icon
grep -qx 'copy "Games/DrDestructo/Data/Levels/level1.xml" "SYS:Games/DrDestructo/Data/Levels/level1.xml"' "$T/Part" || fail level
[ "$(grep -c '^copy\|^default' "$T/Part")" = 6 ] || fail count
echo "test-part: pass"
