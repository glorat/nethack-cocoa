# UI tests

Scripted tests that play a real game in `NetHackUITest.app`, a copy of the app with
`TestDriver.m` linked in. The driver sends key and mouse events through AppKit the
way a player's would, waits until the game is waiting for input again, and checks
what the windows show. Each `*.nhtest` file is one game, started fresh.

```sh
make -C win/cocoa uitest                              # build the test app, run every script
make -C win/cocoa uitest UITESTS=UITests/dialogs.nhtest
win/cocoa/UITests/run.sh UITests/dialogs.nhtest       # rerun without rebuilding
```

The app takes the keyboard focus while it runs, so leave the Mac alone until it's done.
`run.sh` keeps the display awake while it runs (`caffeinate -d`), because a locked screen
can't give the app the focus; it doesn't stop you locking the Mac yourself.
`UITEST_TIMING=1 UITests/run.sh ...` reports where the time goes: start-up in stages,
and for each step the time for AppKit to deliver its events, for the game to finish
with them, and for the screen to catch up.

The test app has its own bundle ID, so it never touches the real app's preferences or
saved games. Its games live in
`~/Library/Containers/io.github.glorat.nethack.uitest/Data/uitest/<test>/`, along with
`failure.png` (and `failure-dialog.png`) when a test fails. The output of each launch is
in `build/uitest-logs/`.

## Writing a test

Every check should guard a behaviour a player would notice breaking. Before adding one,
make sure it fails when that behaviour is broken; a check that can't fail is noise.

The dungeon is random, so:

- pick menu rows and inventory items by their text (`pick`, `sidebar.@text`), not by letter;
- pass turns with `pass`, a forced search, since a plain `s` is refused beside a hidden monster;
- use wizard mode (`@wizard`, the player is `uitest`) to put the hero in a known state;
- start without a pet (`pettype:none`) when it could get in the way;
- restore saved games in normal play: wizard mode asks whether to keep the save file.

### Directives

Lines starting with `@`, at the top of the file:

| Directive | Meaning |
|---|---|
| `@options <opts>` | Added to `NETHACKOPTIONS` (`name:uitest,!legacy,!tutorial` are always set) |
| `@config <line>` | A line of the game's configuration file, e.g. `MENUCOLOR="garlic"=red` |
| `@wizard` | Start in wizard mode |
| `@tutorial` | Let the game ask whether to play the tutorial |
| `@appearance light\|dark` | Force the window appearance |
| `@relaunch` | Everything after this runs in a second launch of the same game |

### Steps

Each step waits for the game to be waiting for input again before the next one.

| Step | Meaning |
|---|---|
| `type <text>` | Type the characters, one at a time, letting the app catch up after each |
| `enter <text>` | Type a whole line into the text box that has the focus, then press Return |
| `key <name> ...` | `return`, `escape`, `space`, `ctrl-<letter>` |
| `pass <n>` | Let `n` turns go by |
| `pick <text>` | Type the letter of the open menu's row containing `text` |
| `toward <name>` | Type the direction key toward the adjacent square showing `name` (skipping squares hiding a monster or trap) |
| `step <name>` | Move the hero onto that square; fails if the hero didn't move |
| `click sidebar <letter>` | Click an inventory sidebar row |
| `click wearing <slot>` | Click a Wearing panel slot (`weapon`, `shield`, `cloak`, ...) |
| `click map <dx> <dy>` | Click the map square at that offset from the hero |
| `click map-near <name>` | Click an adjacent square showing `name` |
| `click map-unexplored` | Click an unexplored square at least four columns from the hero |
| `choose <Menu>/<Item>` | Choose a menu bar item; fails if it's disabled |
| `expect-exit` | The app should quit by itself |
| `check <key> <op> <value>` | Ops: `==` `!=` `contains` `!contains` `matches` (regex) `>=` `<=`; `""` is empty |
| `print <key>` / `snapshot <name>` / `pause <s>` | For writing and debugging tests |

### What a check can look at

| Key | Value |
|---|---|
| `status.<field>` | `name role dlvl hp pw level xplabel xp ac gold str dex con int wis cha turn` as shown |
| `status.badges` | e.g. `Burdened:caution Stone:danger` (severities `info caution warning danger`) |
| `status.mark.<field>` / `status.marks` | Change arrows: `up worse`, `down better`; all of them as `ac:up worse ...` |
| `dialog` / `dialog.kind` | All text in the open dialog / `Menu YesNo Direction Input ExtCommand Message Alert` or `none` |
| `menu.letters`, `menu.<letter>`, `menu.@<text>`, `.style` | Rows of the open menu; style is a colour name (`default green red ...`) plus `bold`, `underline`, `background` |
| `menu.headings`, `menu.headings.style`, `menu.question` | Headings, their styles, and whether the menu is shown as answer buttons |
| `menu.misaligned` | Fields of column headings that don't start where an item's field does; `""` when they all line up |
| `sidebar.letters`, `sidebar.<letter>`, `sidebar.@<text>`, `.style`, `sidebar.headings[.style]` | The inventory sidebar, the same way |
| `wearing.<slot>` | The slot's tooltip, or the slot's name when empty |
| `map.<dx>,<dy>`, `.marks`, `.bg` | What a square shows, its marks (`pet pile peaceful ridden detected`), the floor under it |
| `map.find.<name>`, `map.count.<name>`, `map.with.<mark>`, `map.cursor` | Marks of every square showing `name`; how many there are; names of squares with a mark; the cursor's offset from the hero |
| `messages`, `messages.new` | The message log; only what the last step added |
| `menubar.<Menu>/<Item>` | `enabled` or `disabled` |
| `tileset.size` | e.g. `128x128` |
| `game.input` | What the game is waiting for: `command`, `position` (a map spot) or `other` (still inside a command) |
