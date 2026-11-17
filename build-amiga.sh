#!/bin/sh
# Builds Return of Dr. Destructo (Max Savenkov's remake of Island of
# Dr. Destructo) for GFOS (AmigaOS 3.2.3 with GFOpenUp) with a stove, on
# amigaallegro (Allegro 5 over SDL2.module, GL.module and OpenGPU), with Ogg
# Vorbis for its sounds and DUMB for its .it music:
#   STOVE=.../stoves/os32-gcc16-open6 OUT=out ./build-amiga.sh
# The game and amigaallegro are fetched at what dd2.lock gives; nothing
# third-party is kept here. The game's own Lua 5.1, luabind, tinyxml and
# Boost headers are built from its checkout. Allegro is built once and kept;
# a run that ends out of time says so, and the next run goes on (objects too).
# OUT gets Parts/DrDestructo, a GFOpenUp part:
#   GFOpenUpTool INSTALL Parts/DrDestructo  -> SYS:Games/DrDestructo/
# MIT, like the game's code. Copyright (c) 2026 AmiCradle Team.
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$HERE/dd2.lock"
STOVE=${STOVE:-"$HOME/AmiCradle/stoves/os32-gcc16-open6"}
WORK="${WORK:-$HOME/.cache/amigadrdestructo/build}"; OUT="${OUT:-$WORK/out}"
JOBS=${JOBS:-$(nproc 2>/dev/null || echo 4)}; export JOBS
BUDGET_TOTAL=${BUDGET_TOTAL:-840}
TC="$STOVE/prefix"; PATH="$TC/bin:$PATH"; export PATH
mkdir -p "$WORK" "$OUT"; OUT=$(cd "$OUT" && pwd)
t0=$(date +%s)
left() { echo $(( BUDGET_TOTAL - ( $(date +%s) - t0 ) )); }
m68k-amigaos-gcc --version | head -n 1

# --- amigaallegro with Ogg Vorbis (kept between runs) ------------------------------
set +e
ALLEGRO_BUDGET=$(( BUDGET_TOTAL - 60 )) sh "$HERE/scripts/build-allegro.sh" "$STOVE" "$WORK" "$ALLEGRO_GIT" "$ALLEGRO_COMMIT" > "$WORK/allegro.out"
rc=$?
set -e
[ $rc -eq 3 ] && { echo "out of time in allegro, run again to go on"; exit 0; }
[ $rc -eq 0 ] || { tail -20 "$WORK/allegro.out"; exit $rc; }
PFX=$(tail -n 1 "$WORK/allegro.out"); VP="$WORK/vorbis-prefix"
echo "allegro: $PFX ($(( $(date +%s) - t0 )) s)"

# --- the game at its pinned commit, with patches/ -------------------------------------
SRC="$WORK/drdestructo2"
PSUM=$(cat "$HERE"/patches/*.patch 2>/dev/null | sha256sum | cut -c1-16)
if [ "$(cat "$SRC/.patched" 2>/dev/null)" != "$DD2_COMMIT-$PSUM" ]; then
    rm -rf "$SRC" "$WORK/obj"; mkdir -p "$SRC"; git -C "$SRC" init -q
    git -C "$SRC" fetch -q --depth 1 "$DD2_GIT" "$DD2_COMMIT"; git -C "$SRC" checkout -q FETCH_HEAD
    for p in "$HERE"/patches/*.patch; do
        [ -f "$p" ] || continue
        patch -s -d "$SRC" -p1 < "$p" || { echo "patch failed: $p"; exit 1; }
    done
    echo "$DD2_COMMIT-$PSUM" > "$SRC/.patched"
fi
# --- compile (objects kept, so a run out of time goes on) and link ---------------------
SYSROOT="$TC/m68k-amigaos"; DEPS="$SYSROOT/port-deps"
ARCH="-mcrt=nix20 -m68040 -m68881 -pthread"
DEFS="-DALLEGRO_STATICLINK=1 -D__AMIGAOS3__=1 -DTIXML_USE_STL -DHAS_STD_SHARED_PTR -DNDEBUG"
INC="-I$SRC/src -I$SRC/src/Engine -I$SRC/src/tinyxml -I$SRC/src/boost -I$SRC/src/luabind -I$SRC/src/lua \
 -I$SRC/src/FastDelegate -I$SRC/libs/src/lua/src -I$PFX/include -I$VP/include -I$SYSROOT/include"
CXXF="$ARCH -std=gnu++14 -Wno-deprecated-declarations -O2 -fomit-frame-pointer $DEFS $INC"
CF="$ARCH -std=gnu17 -O2 -fomit-frame-pointer $DEFS $INC"
O="$WORK/obj"; mkdir -p "$O"; export CF CXXF
{ sed "s|^|$SRC/|" "$HERE/amiga/sources.txt"; echo "$HERE/amiga/amiga_start.c"; } > "$WORK/files.txt"
set +e
timeout "$(left)" sh -c '
    while read -r f; do
        o="'"$O"'/$(echo "$f" | sed "s|^'"$SRC"'/||; s|.*/amiga/|amiga/|; s|/|_|g; s|\.[^.]*$|.o|")"
        echo "$f $o"
    done < "'"$WORK"'/files.txt" | xargs -P "$JOBS" -n 2 sh -c '"'"'
        CF="$0"; CXXF="$1"; s="$2"; o="$3"
        [ -f "$o" ] && [ "$o" -nt "$s" ] && exit 0
        case "$s" in
            *.c) m68k-amigaos-gcc $CF -c "$s" -o "$o.tmp" 2> "$o.log" ;;
            *) m68k-amigaos-g++ $CXXF -c "$s" -o "$o.tmp" 2> "$o.log" ;;
        esac || { cat "$o.log"; rm -f "$o.tmp"; exit 1; }
        mv "$o.tmp" "$o"
    '"'"' "$CF" "$CXXF"
'
rc=$?
set -e
[ $rc -eq 124 ] && { echo "out of time compiling ($(ls "$O"/*.o | wc -l) objects kept), run again to go on"; exit 0; }
[ $rc -eq 0 ] || { echo "compile failed"; exit 1; }
n=$(ls "$O"/*.o | wc -l); want=$(wc -l < "$WORK/files.txt")
[ "$n" -eq "$want" ] || { echo "objects $n of $want"; exit 1; }
m68k-amigaos-g++ $ARCH -o "$WORK/DrDestructo.debug" "$O"/*.o \
    "$PFX/lib/liballegro_monolith-static.a" "$VP/lib/libdumb.a" "$VP/lib/libvorbisfile.a" "$VP/lib/libvorbis.a" "$VP/lib/libogg.a" \
    "$SYSROOT/lib/libSDL2.a" "$SYSROOT/lib/libGL.a" "$DEPS/lib/libpng.a" "$DEPS/lib/libz.a" -lm -lpthread

# --- the GFOpenUp part: Parts/DrDestructo --------------------------------------------------
P="$OUT/Parts/DrDestructo"; D="$P/Games/DrDestructo"; rm -rf "$P"; mkdir -p "$D"
m68k-amigaos-strip -o "$D/DrDestructo" "$WORK/DrDestructo.debug"
cp -R "$SRC/data" "$D/Data"; rm -f "$D/Data/dd2_icon.icns"
cp "$SRC/docs/LICENSE-CODE.txt" "$D/License-Code.txt"; cp "$SRC/docs/LICENSE-ART.txt" "$D/License-Art.txt"
cp "$SRC/docs/ReadMe.txt" "$D/Game.txt"; cp "$HERE/README.md" "$D/ReadMe"
cp "$HERE/amiga/icons/DrDestructo.info" "$HERE/amiga/icons/ReadMe.info" "$D/"
cp "$HERE/amiga/icons/DrDestructo-drawer.info" "$P/Games/DrDestructo.info"
sh "$HERE/scripts/write-part.sh" "$P" "$DD2_VERSION"
ls -l "$D/DrDestructo"
strings "$D/DrDestructo" | grep -q "DrDestructo $DD2_VERSION (17.11.2026) GFOS" || { echo "no \$VER"; exit 1; }
echo "part: $(grep -c '^copy\|^default' "$P/Part") files, $(du -sk "$P" | cut -f1) KB"
echo "total: $(( $(date +%s) - t0 )) s"
