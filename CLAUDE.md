# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A fork of NetHack whose real purpose is the native macOS Cocoa front end in `win/cocoa/` (originally by Dirk Zimmermann). This branch (`nethack-5.0`) carries the NetHack 5.0.0 core, merged from upstream's `NetHack-5.0.0_Released` tag; `master` is the older 3.6.6 version. Nearly all work is in `win/cocoa/`; the rest of the tree is the upstream core (`src/`, `include/`, `util/`, `dat/`) plus other platform/window ports (`sys/*`, `win/*`) that aren't used by this build. Keep core edits minimal and behind `#ifdef COCOA_GRAPHICS` so upstream merges stay easy.

## Building

The only build path is `win/cocoa/Makefile` (there is no Xcode project). From a fresh checkout:

```sh
make -C win/cocoa   # -> win/cocoa/build/NetHack.app
open win/cocoa/build/NetHack.app
```

Full Xcode must be installed at `/Applications/Xcode.app`, because `ibtool` (XIB compilation) isn't in the Command Line Tools. The Makefile sets `DEVELOPER_DIR` itself when `xcode-select` points at the Command Line Tools. A fresh Xcode also needs `sudo xcodebuild -license accept` and `xcodebuild -runFirstLaunch`. The app is ad-hoc signed; no signing identity is needed.

The Makefile:
- Its `core` step runs upstream's build from the top of the tree: `sys/unix/setup.sh hints/macOS.500` (once), `make fetch-lua` (once, downloads Lua), then `make all` every time (incremental). That provides `lib/lua/liblua-*.a`, `dat/nhdat`, `makedefs`, `dlb`, `util/tilemap` and `util/tile2bmp`. It also builds upstream's tty `src/nethack`, which the app doesn't use. Its `expr: syntax error` messages are harmless.
- Compiles core `src/*.c` (the list is `CORE_SRC`), `sys/unix/{unixmain,unixres,unixunix}.c`, `sys/share/posixregex.c`, and the Cocoa `*.c`/`*.m`/`iHack/*.m` (ARC), then links with `lib/lua/liblua-*.a`.
- Generates `src/tile.c` via `util/Makefile` and the tile sheet `build/tiles16.bmp` via `tile2bmp`.
- Compiles `en.lproj/*.xib`, builds the icon, fills `NetHack-Info.plist` (bundle id `net.hack.cocoa.NetHack5`, version 5.0.0), copies `nhdat`/`license`/`symbols`/`sysconf`/images into `Resources`, and codesigns with `NetHack.entitlements`.
- `win/cocoa/Makefile` matches the top-level `.gitignore`'s `Makefile` rule; it is tracked, so new copies need `git add -f`.

Gotchas:
- `NHDEFS` in the Makefile must match the feature flags `util/tilemap` sees, `NOMAIL` especially. A mismatch doesn't fail the build; it misaligns the glyph→tile map and shows the wrong tiles.
- Include order is `-I. -IiHack -I$(TOP)/include` because the Cocoa `TileSet.h` and core `tileset.h` collide on the case-insensitive filesystem.
- New core source files in a future upstream merge must be added to `CORE_SRC`.
- The minimum macOS is 12.0 (`MACOSX_DEPLOYMENT_TARGET`), the lowest Xcode 27's SDK supports. It is exported so upstream's Lua build, whose hints set no target, matches. Make doesn't notice a target change: after changing it, delete `lib/lua/*.a` and `lib/lua-*/src/*.o` so Lua rebuilds, or the link warns.
- `tile2bmp` rejects long output paths, so the sheet is written in `util/` and then moved.

There are no tests and no linter. `.clang-format` (LLVM-based, 4-space indent, 78 cols, no tabs) and `DEVEL/code_style.txt` describe upstream's C style; the Cocoa Objective-C files use their own older style (tabs). Match the file you're editing.

To run with options and skip the role picker: `NETHACKOPTIONS="role:Valkyrie,race:human,gender:female,align:neutral" win/cocoa/build/NetHack.app/Contents/MacOS/NetHack`. When role, race, gender and alignment are all set and valid, `cocoa_player_selection` doesn't show the dialog.

## Cocoa port architecture

**Two threads.** `NetHackCocoaAppDelegate` starts a background `NSThread` that calls `unixmain()` (upstream's `sys/unix/unixmain.c` `main`, renamed under `COCOA_GRAPHICS`). The game loop runs there, not on the main thread. The main thread runs AppKit.

**Window-port bridge.** `wincocoa.m` defines the `cocoa_procs` `struct window_procs` table (`cocoa_*` functions declared in `wincocoa.h`; the port id is `wp_cocoa`). Status uses the core's `genl_status_*` routines, which feed the old two-line bottom line that `StatsView` parses. The core calls these functions on the game thread. They store state in model objects from `iHack/` (`NhWindow`, `NhMapWindow`, `NhMenuWindow`, `NhStatusWindow`, kept in `g_WindowDict` keyed by `winid`) and then ask `MainWindowController` to show or refresh the UI. When upstream changes the `window_procs` signatures, compare against `win/tty/wintty.c` and `include/winprocs.h`.

**Hopping to the main thread.** `MainWindowController` methods invoked from the game thread check `[NSThread isMainThread]` and re-dispatch themselves with `performSelectorOnMainThread:` (some `waitUntilDone:YES`, some `NO`). Any new UI entry point called from `wincocoa.m` must follow the same pattern.

**Input flows back via `NhEventQueue`.** Blocking window-port calls (`cocoa_nh_poskey`, `cocoa_nhgetch`, `cocoa_select_menu`, `cocoa_yn_function`, `cocoa_getlin`, ext commands, direction prompts) call `[[NhEventQueue instance] nextEvent]`, which waits on an `NSCondition`. UI code on the main thread (`MainView` key/mouse handling, the various `*WindowController`s) answers by calling `addKey:`/`addEvent:`. So a dialog "returns" a value to the game by enqueueing an event, not through a return value.

**Core lock.** The game thread acquires the app delegate's recursive `nethackCoreLock` at startup and holds it while running. It releases it (`unlockNethackCore`) around blocking hand-offs to the main thread (e.g. `showPlayerSelection`, `displayWindow:`) and in `cocoa_prepare_for_exit`. Keep that unlock/relock pairing when adding new blocking main-thread calls.

**UI pieces.** `MainWindowController` owns the main window (map `MainView`, `StatsView`, `EquipmentView`, message area, speech via `AVSpeechSynthesizer`). Modal and panel UIs are separate controllers with XIBs in `en.lproj/`: `MenuWindowController`, `MessageWindowController`, `YesNoWindowController`, `DirectionWindowController`, `InputWindowController`, `ExtCommandWindowController`, `PlayerSelectionWindowController`.

**Tiles.** `iHack/TileSet.m` maps a glyph to a tile with `glyphmap[glyph].tileidx` (requires `TILES_IN_GLYPHMAP`). It counts sheet rows from the top because the generated sheet's height isn't a multiple of the tile height. The default is the bundled `tiles16.bmp` generated from `win/share/*.txt`. `MainWindowController` rejects sheets with fewer than `total_tiles_used` tiles. The 3.6-era sheets in `win/cocoa/tilesets/` aren't bundled and don't match 5.0's tile layout. The tile size comes from the tileset's file name (`tiles24.png` → 24px, `foo10x20.bmp` → 10×20) in `-[MainWindowController tileSetSizeFromName:]`. Tileset, ASCII font, speech and similar settings are persisted in `NSUserDefaults` (see `MainWindowController` init/save).

## Core integration points

All under `COCOA_GRAPHICS`. Grep for it when the core behaves differently under this port:
- `include/config.h`: `CHDIR` is not defined.
- `include/winprocs.h` / `src/windows.c`: the `wp_cocoa` id and the `cocoa_procs` entry in `winchoices`.
- `include/extern.h`: the `nethack_exit` prototype.
- `sys/unix/unixmain.c`: `main` is renamed `unixmain`. After `early_init` it `chdir`s to the bundle's resource directory (`cocoa_resource_dir()`, i.e. `+[WinCocoa baseFilePath]`) and calls `set_fqn_prefixes()`.

`DEFAULT_WINDOW_SYS "cocoa"`, `NOCWD_ASSUMPTIONS` (needed so the file prefixes are honoured), `SYSCF`, `DLB` and `NOMAIL` come from `NHDEFS` in the Makefile, not from `config.h`.

`win/cocoa/cocoa_unix.c` contains only `set_fqn_prefixes()`. Upstream's `sys/unix/unixunix.c` handles locking and files. Writable files go in `$NETHACKDIR`/`$HACKDIR`, falling back to `~/nethackdir` (inside the sandbox container, `~/Library/Containers/net.hack.cocoa.NetHack5/Data/nethackdir`), where it creates `perm`, `record`, `logfile`, `xlogfile` and `save/`. Read-only data (`nhdat`, `symbols`, `sysconf`, tiles) is read from the bundle's resource directory, which is the working directory. `win/cocoa/sysconf` is the bundled SYSCF.

The core reports inventory changes only inside the game loop, so `cocoa_nh_poskey` calls `cocoa_update_inventory` once when `program_state.in_moveloop` first becomes true; otherwise the equipment view is empty at the start of a game.

Core state in 5.0 lives in per-letter global structs from `include/decl.h` (`gi.invent`, `svp.plname`, `gs.showsyms`, `svd.dungeons`, `gu.urace`, `svl.level`, etc.), not plain globals as in 3.6. When a Cocoa file fails to compile after an upstream merge, look there first.

Don't use the core's prototype-widening macros (`XCHAR_P`, `CHAR_P`, `BOOLEAN_P`; `include/tradstdc.h`) in Objective-C method signatures or ivars. They can expand to different types in different translation units, so a caller and callee disagree on the size. That bug put the map cursor at x=0; use `int`/`coordxy` explicitly.

The app is sandboxed (`NetHack.entitlements`). File access problems (save, record, logfile, user tilesets) usually trace back to that.
