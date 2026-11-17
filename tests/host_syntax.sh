#!/bin/sh
# Compiles every source of amiga/sources.txt with the host compiler
# (-fsyntax-only, the flags build-amiga.sh uses, patches applied to a copy)
# against the host's Allegro 5 headers. Catches language-level breakage
# before a stove run. Skips when the host has no Allegro 5 headers.
#   DD2_SRC=<checkout of the game> sh tests/host_syntax.sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
[ -n "${DD2_SRC:-}" ] || { echo "host_syntax: skip (no DD2_SRC)"; exit 0; }
[ -f /usr/include/allegro5/allegro.h ] || { echo "host_syntax: skip (no host Allegro 5)"; exit 0; }
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
cp -R "$DD2_SRC/src" "$DD2_SRC/libs" "$T/"
for p in "$HERE"/patches/*.patch; do [ -f "$p" ] || continue; patch -s -d "$T" -p1 < "$p"; done
cd "$T"
INC="-Isrc -Isrc/Engine -Isrc/tinyxml -Isrc/boost -Isrc/luabind -Isrc/lua -Isrc/FastDelegate -Ilibs/src/lua/src"
fails=0
while read -r f; do
    case "$f" in
        *.c) gcc -std=gnu17 -fsyntax-only $INC "$f" ;;
        *) g++ -std=gnu++14 -D__amigaos__ -Wno-deprecated-declarations -Wno-changes-meaning -include cmath \
               -fsyntax-only -DTIXML_USE_STL -DHAS_STD_SHARED_PTR -DNDEBUG $INC "$f" ;;
    esac 2> err.log || { fails=$((fails + 1)); echo "FAIL $f"; grep -m3 error err.log; }
done < "$HERE/amiga/sources.txt"
[ $fails -eq 0 ] || { echo "host_syntax: $fails failed"; exit 1; }
echo "host_syntax: pass ($(wc -l < "$HERE/amiga/sources.txt") sources)"
