# Return of Dr. Destructo for GFOS

Return of Dr. Destructo, Max Savenkov's remake of the ZX Spectrum game
Island of Dr. Destructo (https://github.com/MaxSavenkov/drdestructo2), built
for GFOS (AmigaOS 3.2.3 with GFOpenUp, 68040) on amigaallegro: Allegro 5
over SDL2.module, GL.module and OpenGPU, with Ogg Vorbis for the sounds and
DUMB for the .it music.

## Build

    STOVE=~/AmiCradle/stoves/os32-gcc16-open6 OUT=out ./build-amiga.sh

The game, amigaallegro, ogg, vorbis and DUMB are fetched at the commits in
`dd2.lock` and `scripts/build-allegro.sh`; nothing third-party is kept here.
The game's own Lua 5.1, luabind, tinyxml and Boost headers are compiled from
its checkout. Allegro and the game's objects are kept between runs, so a run
that ends out of time says so and the next run goes on.

`patches/0002-std-shared-ptr-copy.patch`: with std::shared_ptr (GCC 16)
the sound instance copy assigns instead of the boost-only `reset(ptr)`.

`patches/0001-gfos-no-joystick-guid.patch`: amigaallegro has no
`al_get_joystick_guid_string` (upstream needs its own Allegro patch for it),
so every pad takes the game's default mapping.

The part is `out/Parts/DrDestructo`:

    GFOpenUpTool INSTALL Parts/DrDestructo

installs `SYS:Games/DrDestructo/` with the game data in `Data/`. The game
runs in its own drawer, so it starts the same from its icon or a Shell, and
keeps its settings and scores there.

## Tests

    sh tests/test_host.sh
    DD2_SRC=<checkout of the game> sh tests/test_lock.sh
    DD2_SRC=<checkout of the game> sh tests/host_syntax.sh

`test_lock.sh` checks the pins, the `$VER` string, that `amiga/sources.txt`
is exactly the game's CMake source lists and that the patches apply.
`test-part.sh` checks the GFOpenUp Part writer. `host_syntax.sh` compiles
every source with the host compiler and the build flags (patches applied)
against host Allegro 5 headers, and skips without them.

## Rights

The game code is MIT and its art CC-BY-SA 4.0 (`License-Code.txt`,
`License-Art.txt` in the part). A rights review is still due before release.

## Licence

The Amiga build files here are MIT (LICENSE).
Copyright (c) 2026 AmiCradle Team.
Designed, tested and delivered by The AmiCradle Team.
