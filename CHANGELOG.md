# Changelog

Changes to NetHack for macOS. Changes to the game itself are in NetHack's own [release notes](https://www.nethack.org/).

## Unreleased

- Monsters and objects on lit room floor are drawn over the floor instead of on black.
- The click that brings the window to the front no longer also moves your character.
- Clicking a distant square you haven't explored no longer starts travel there. Position prompts such as `;` still accept those squares.

## 5.0.0-2 (2026-10-15)

- The app is now called NetHack and has a new bundle ID, `io.github.glorat.nethack`. Saved games, scores and settings from release 5.0.0-1 don't carry over. To keep your saved games and scores, open NetHack 5.0.0-2 once, quit it, then copy the `nethackdir` folder (and `.nethackrc`, if you have one) from `~/Library/Containers/net.hack.cocoa.NetHack5/Data` to `~/Library/Containers/io.github.glorat.nethack/Data`, replacing what's there.
- The About box, privacy policy and links now point to this project.

## 5.0.0-1 (2026-10-15)

First release, porting the NetHack Cocoa interface from NetHack 3.6.6 to NetHack 5.0.0.

- New painted tile sets at 64px and 128px; 128px is the default. The classic 16px tiles are still available.
- Tiles are drawn over the floor, water or other terrain beneath them.
- Map zoom with ⌘=, ⌘− and ⌘0, or pinch on a trackpad.
- Universal app for Apple Silicon and Intel Macs.
- The role picker is skipped when your options already choose role, race, gender and alignment.
