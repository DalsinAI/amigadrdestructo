#!/bin/sh
# dd2.lock pins full commits; $VER carries the locked version;
# amiga/sources.txt is exactly the game's SOURCES_ENGINE + SOURCES_GAME and
# the Lua, luabind and tinyxml SOURCES of its CMake files (DD2_SRC=<checkout>),
# and patches/ still apply.
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
. "$HERE/dd2.lock"
for c in "$DD2_COMMIT" "$ALLEGRO_COMMIT"; do echo "$c" | grep -Eqx '[0-9a-f]{40}' || { echo "FAIL commit $c"; exit 1; }; done
grep -q "DrDestructo $DD2_VERSION " "$HERE/amiga/amiga_start.c" || { echo "FAIL \$VER"; exit 1; }
grep -q 'DrDestructo $DD2_VERSION (17.11.2026) GFOS' "$HERE/build-amiga.sh" || { echo "FAIL \$VER check"; exit 1; }
[ "$(sort "$HERE/amiga/sources.txt" | uniq -d)" = "" ] || { echo "FAIL duplicate sources"; exit 1; }
grep -q 'f6ee2e9b36e14613cbd7b8ee678251c4cbdfdc9f' "$HERE/scripts/build-allegro.sh" || { echo "FAIL DUMB pin"; exit 1; }
if [ -n "${DD2_SRC:-}" ]; then
    up=$({ sed -n '/^set( SOURCES_ENGINE/,/^)/p;/^set( SOURCES_GAME/,/^)/p' "$DD2_SRC/CMakeLists.txt" | grep -oE 'src/[A-Za-z0-9_/]+\.cpp'
           for l in lua luabind tinyxml; do
               sed -n '/^set( SOURCES/,/^)/p' "$DD2_SRC/libs/src/$l/CMakeLists.txt" | grep -oE '[A-Za-z0-9_/]+\.(c|cpp)' | sed "s|^|libs/src/$l/|"
           done; } | sort)
    [ "$(sort "$HERE/amiga/sources.txt")" = "$up" ] || { echo "FAIL sources differ from the game's CMake files"; exit 1; }
    while read -r f; do [ -f "$DD2_SRC/$f" ] || { echo "FAIL missing $f"; exit 1; }; done < "$HERE/amiga/sources.txt"
    for p in "$HERE"/patches/*.patch; do [ -f "$p" ] || continue; patch -s --dry-run -d "$DD2_SRC" -p1 < "$p" || { echo "FAIL $p"; exit 1; }; done
fi
echo "test_lock: pass"
