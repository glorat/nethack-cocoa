# Changelog

Changes to NetHack for macOS. Changes to the game itself are in NetHack's own [release notes](https://www.nethack.org/).

## Unreleased

### Added

- View → Tile Set → Import... copies a tile set into the app's folder, so it's still there after a restart.
- The Tile Set menu lists every tile set in the folder that holds `.nethackrc`, and Show Tile Sets Folder opens it.
- The `tile_file` option chooses the tile set at launch.

### Changed

- A tile set that can't be used says why.
- The tile size no longer has to be in a tile set's file name.

## 5.0.0-6 (2026-10-19)

### Added

- Blessed items are green and cursed items red in menus and the inventory sidebar.
- Menus and the inventory sidebar show the colors and highlighting set by the menucolors option.
- The map marks peaceful monsters and your steed.
- The map marks item piles and monsters you sense but can't see.
- Hunger, encumbrance and status conditions show as colored badges, with deadly ones in red.
- An arrow next to a stat, AC or level shows for a few turns when it goes up or down.
- When a game ends, a dialog offers to start a new game or quit.

### Changed

- Blue, green and brown are easier to tell apart on the ASCII map.
- Menu headings are larger, and column headings like the spell menu's line up with their columns.

## 5.0.0-5 (2026-10-17)

### Added

- An inventory sidebar lists everything you carry; click an item to choose what to do with it.
- Click an item in the Wearing panel to choose what to do with it.

### Changed

- Commands like wield and quaff show a menu of suitable items, and typing any item's letter still works.

## 5.0.0-4 (2026-10-17)

### Changed

- The app is now called NetHack 5.

### Fixed

- The Wearing panel is an even grid, with worn items drawn at full size.

## 5.0.0-3 (2026-10-16)

### Changed

- Menus are redrawn: lists you pick from show each item's picture and letter, and read-only lists are text you can select and copy.
- Short questions show one button per answer, labelled with its key.
- The direction, extended command (`#`) and typed-answer prompts take the same keys as the terminal.
- The menu bar is reorganised into clearer groups.
- Many painted tiles are redrawn closer to the classic tiles, and wand and spell beams are sharper and easier to tell apart.
- Water, lava, ice, air and cloud look calmer across large areas.
- The download is about 30 MB smaller.

### Fixed

- Menu bar commands do what they say.
- Monsters and objects on lit floor are drawn over the floor instead of on black.
- Walls fill their whole square, with no dark gap beside them.
- The click that brings the window to the front no longer also moves your character.
- Clicking a distant unexplored square no longer starts travel there.
- Closing a message window with Return, space or Esc no longer also answers the next question.
- Read-only lists such as the dungeon overview wait for you to close them, so the tombstone no longer opens on top.
- The app no longer freezes when you hover over the map after a game ends.
- Character names follow the terminal's length and character rules.

## 5.0.0-2 (2026-10-15)

- The app is now called NetHack and has a new bundle ID, `io.github.glorat.nethack`.
- The About box, privacy policy and links now point to this project.

## 5.0.0-1 (2026-10-15)

First release, porting the NetHack Cocoa interface from NetHack 3.6.6 to NetHack 5.0.0.

- New painted tile sets at 64px and 128px; 128px is the default. The classic 16px tiles are still available.
- Tiles are drawn over the floor, water or other terrain beneath them.
- Map zoom with ⌘=, ⌘− and ⌘0, or pinch on a trackpad.
- Universal app for Apple Silicon and Intel Macs.
- The role picker is skipped when your options already choose role, race, gender and alignment.
