# CLAUDE.md

## What this repo is

A fork of NetHack whose real purpose is the native macOS Cocoa front end in `win/cocoa/` (originally by Dirk Zimmermann). `main` carries the NetHack 5.0.0 core, merged from upstream's `NetHack-5.0.0_Released` tag; `nethack-3.6` is the older 3.6.6 version and is not maintained. Nearly all work is in `win/cocoa/`; the rest of the tree is the upstream core (`src/`, `include/`, `util/`, `dat/`) plus other platform/window ports (`sys/*`, `win/*`) that aren't used by this build. Keep core edits minimal and behind `#ifdef COCOA_GRAPHICS` so upstream merges stay easy.

## Building and testing

The only build path is `win/cocoa/Makefile` (there is no Xcode project):

```sh
make -C win/cocoa          # -> win/cocoa/build/NetHack.app
make -C win/cocoa test     # XCTest unit tests in win/cocoa/Tests/ (also run by CI)
open win/cocoa/build/NetHack.app
```

To skip the role picker: `NETHACKOPTIONS="role:Valkyrie,race:human,gender:female,align:neutral" win/cocoa/build/NetHack.app/Contents/MacOS/NetHack`.

Full Xcode must be installed at `/Applications/Xcode.app`, because `ibtool` (XIB compilation) isn't in the Command Line Tools; the Makefile sets `DEVELOPER_DIR` itself when `xcode-select` points at the Command Line Tools. A fresh Xcode also needs `sudo xcodebuild -license accept` and `xcodebuild -runFirstLaunch`. The app is ad-hoc signed; no signing identity is needed.

The tests link only the code under test plus a stub `NhEventQueue`, not the core, so logic worth testing goes in plain classes, with window controllers kept thin. There is no linter. `.clang-format` and `DEVEL/code_style.txt` describe upstream's C style; the Cocoa Objective-C files use their own older style (tabs). Match the file you're editing.

Gotchas:
- The Makefile's `core` step runs upstream's `setup.sh` and `fetch-lua` once, then builds only the core targets the app needs, not `make all`.
- `NHDEFS` in the Makefile must match the feature flags `util/tilemap` sees, `NOMAIL` especially. A mismatch doesn't fail the build; it misaligns the glyph→tile map and shows the wrong tiles. `DEFAULT_WINDOW_SYS`, `NOCWD_ASSUMPTIONS`, `SYSCF`, `DLB` and `NOMAIL` come from `NHDEFS`, not `config.h`.
- Include order is `-I. -IiHack -I$(TOP)/include` because the Cocoa `TileSet.h` and core `tileset.h` collide on the case-insensitive filesystem.
- New core source files in a future upstream merge must be added to `CORE_SRC`.
- Make doesn't notice a change to `MACOSX_DEPLOYMENT_TARGET` (12.0, the lowest Xcode 27's SDK supports), `ARCHFLAGS` or `VERSION`: run `make -C win/cocoa clean` first.
- Local builds are for this Mac's architecture; releases pass `ARCHFLAGS="-arch arm64 -arch x86_64"`.
- The painted sheets `Resources/tiles/tiles64.png` and `tiles128.png` are in Git LFS. Without `git lfs` a checkout has pointer files there, and the app rejects them as tile sets.
- `win/cocoa/Makefile` matches the top-level `.gitignore`'s `Makefile` rule; it is tracked, so new copies need `git add -f`.
- `tile2bmp` rejects long output paths, so the sheet is written in `util/` and then moved.

## Conventions

- Every user-visible change gets a line under `## Unreleased` in `CHANGELOG.md`, in the same commit: one short sentence, written for players.

## Releasing

Releases are made by tag only, never by pushes to `main`. Tags are `v<NetHack version>-<app revision>`, e.g. `v5.0.0-1`, then `v5.0.0-2`; the revision restarts at 1 for a new NetHack version. Before tagging, rename `## Unreleased` to `## 5.0.0-N (date)` and commit. Pushing the tag runs `.github/workflows/release.yml`, which reuses `ci.yml` and publishes a GitHub Release whose notes are that `CHANGELOG.md` section; it fails if the section is missing. `ci.yml` also builds the universal app for pushes to `main` and pull requests, and caches LFS objects because LFS downloads count against the repo's quota. The app isn't notarized, so users approve it once with Open Anyway.

## Cocoa port architecture

**Two threads.** `NetHackCocoaAppDelegate` starts a background `NSThread` that calls `unixmain()` (upstream's `sys/unix/unixmain.c` `main`, renamed under `COCOA_GRAPHICS`). The game loop runs there, not on the main thread. The main thread runs AppKit.

**Window-port bridge.** `wincocoa.m` defines the `cocoa_procs` `struct window_procs` table (`cocoa_*` functions declared in `wincocoa.h`; the port id is `wp_cocoa`). Status uses the core's `genl_status_*` routines, which feed the old two-line bottom line that `StatsView` parses. The core calls these functions on the game thread. They store state in model objects from `iHack/` (`NhWindow`, `NhMapWindow`, `NhMenuWindow`, `NhStatusWindow`, kept in `g_WindowDict` keyed by `winid`) and then ask `MainWindowController` to show or refresh the UI. When upstream changes the `window_procs` signatures, compare against `win/tty/wintty.c` and `include/winprocs.h`.

**Hopping to the main thread.** `MainWindowController` methods invoked from the game thread check `[NSThread isMainThread]` and re-dispatch themselves with `performSelectorOnMainThread:` (some `waitUntilDone:YES`, some `NO`). Any new UI entry point called from `wincocoa.m` must follow the same pattern.

**Input flows back via `NhEventQueue`.** Blocking window-port calls (`cocoa_nh_poskey`, `cocoa_nhgetch`, `cocoa_select_menu`, `cocoa_yn_function`, `cocoa_getlin`, ext commands, direction prompts) call `[[NhEventQueue instance] nextEvent]`, which waits on an `NSCondition`. UI code on the main thread (`MainView` key/mouse handling, the various `*WindowController`s) answers by calling `addKey:`/`addEvent:`. So a dialog "returns" a value to the game by enqueueing an event, not through a return value.

**Core lock.** The game thread acquires the app delegate's recursive `nethackCoreLock` at startup and holds it while running. It releases it (`unlockNethackCore`) around blocking hand-offs to the main thread (e.g. `showPlayerSelection`, `displayWindow:`) and in `cocoa_prepare_for_exit`. Keep that unlock/relock pairing when adding new blocking main-thread calls.

**UI pieces.** `MainWindowController` owns the main window (map `MainView`, `StatsView`, `EquipmentView`, message area, speech). Modal and panel UIs are separate controllers with XIBs in `en.lproj/`: `MessageWindowController`, `InputWindowController`, `PlayerSelectionWindowController`. `MenuWindowController`, `YesNoWindowController`, `DirectionWindowController` and `ExtCommandWindowController` build their windows in code. The menu turns tty's runs of spaces into shared tab stops so columns line up. `NhKeyFromEvent` (`KeyEvent.m`) maps arrow and keypad keys through the core's `gc.Cmd.dirchars`, not fixed letters, so `number_pad` works.

**Tiles.** `iHack/TileSet.m` maps a glyph to a tile with `glyphmap[glyph].tileidx` (requires `TILES_IN_GLYPHMAP`). The default is the bundled `tiles128.png`; `tiles64.png` and the classic `tiles16.bmp` (generated from `win/share/*.txt`) are also offered. A sheet must use `tile2bmp`'s order (monsters, objects, other, then a greyscale copy of every monster tile for statues, 40 per row), and `MainWindowController` rejects sheets with fewer than `total_tiles_used` tiles. The tile size comes from the file name (`tiles24.png` → 24px, `foo10x20.bmp` → 10×20). The 3.6-era sheets in `win/cocoa/tilesets/` don't match 5.0's layout. The painted sprites have transparent backgrounds: `cocoa_init_nhwindows` sets `iflags.use_background_glyph`, `NhMapWindow` keeps the background glyph `cocoa_print_glyph` receives for each cell, and `MainView` draws it before the glyph.

## Core integration points

Core edits are all under `COCOA_GRAPHICS`; grep for it when the core behaves differently under this port. `sys/unix/unixmain.c`'s `main` is renamed `unixmain`, and after `early_init` it `chdir`s to the bundle's resource directory (`cocoa_resource_dir()`) and calls `set_fqn_prefixes()` (`win/cocoa/cocoa_unix.c`).

Writable files go in `$NETHACKDIR`/`$HACKDIR`, falling back to `~/nethackdir` (inside the sandbox container, `~/Library/Containers/io.github.glorat.nethack/Data/nethackdir`). Read-only data (`nhdat`, `symbols`, `sysconf`, tiles) is read from the bundle's resource directory, which is the working directory. The app is sandboxed (`NetHack.entitlements`); file access problems (save, record, logfile, user tilesets) usually trace back to that.

The core reports inventory changes only inside the game loop, so `cocoa_nh_poskey` calls `cocoa_update_inventory` once when `program_state.in_moveloop` first becomes true; otherwise the equipment view is empty at the start of a game.

Core state in 5.0 lives in per-letter global structs from `include/decl.h` (`gi.invent`, `svp.plname`, `gs.showsyms`, `svd.dungeons`, `gu.urace`, `svl.level`, etc.), not plain globals as in 3.6. When a Cocoa file fails to compile after an upstream merge, look there first.

Don't use the core's prototype-widening macros (`XCHAR_P`, `CHAR_P`, `BOOLEAN_P`; `include/tradstdc.h`) in Objective-C method signatures or ivars. They can expand to different types in different translation units, so a caller and callee disagree on the size; use `int`/`coordxy` explicitly.
