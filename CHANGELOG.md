# Changelog

Changes to NetHack for macOS. Changes to the game itself are in NetHack's own [release notes](https://www.nethack.org/).

## Unreleased

- Monsters and objects on lit room floor are drawn over the floor instead of on black.
- The click that brings the window to the front no longer also moves your character.
- Clicking a distant square you haven't explored no longer starts travel there. Position prompts such as `;` still accept those squares.
- Menus are redrawn. Lists you choose from, such as inventory, pickup and drop, show each item's picture and letter in a scrolling list: click a row or type its letter, type a number first to take only that many, or move with the arrow keys and press space. Read-only menus such as `^X` attributes and the dungeon overview are plain text you can select and copy. Lines are no longer squeezed into a narrow column.
- The extended command list (`#`) shows only the 31 commands NetHack offers there, such as `#pray`, `#offer` and `#loot`, instead of all 170. Commands with their own key are left out, and wizard-mode commands only appear in wizard mode.
- Stairs, ladders, drawbridges and open doors are redrawn closer to the classic tiles. Stairs and ladders have an arrow for the direction, and doors sit flush in the wall. A trapped door is the ordinary closed door with a red rune.
- Engravings look like faint scratches on the floor instead of a stone slab.
- Walls fill their whole square, so there's no dark gap between a wall and the room beside it.
- The app no longer freezes when you hover over the map after a game ends.
- Closing a message window with Return, space or Esc no longer also answers the next question. Before, closing the window before the tutorial question this way skipped the question and left a second copy of it on screen.
- Short questions asked as a menu, such as whether you want the tutorial, show one button per answer instead of a list with OK and Cancel. In longer menus where you pick one thing, the row under the pointer lights up, a click chooses it, and there's no OK button that did nothing.
- Read-only lists such as the dungeon overview now wait for you to close them before the game goes on. At the end of a game, the tombstone and score list no longer open on top of the overview.
- Wand and spell beams are drawn sharply at full size instead of enlarged from the 16px tiles, and each kind looks different: lightning is jagged, poison gas is a haze, death is a dark ray.
- Water looks like a deeper version of a pool or moat, and lava, ice, air and cloud are calmer across large areas.
- The download is about 30 MB smaller, because the painted tiles now use 256 colours.

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
