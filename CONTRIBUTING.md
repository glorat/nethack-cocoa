# Contributing

Bug reports and pull requests for the Mac app are welcome. Problems with the game itself, ones that also happen in the terminal version, belong with [NetHack upstream](https://github.com/NetHack/NetHack).

## Building and testing

Follow [Building from source](.github/README.md#building-from-source) in the README first. Run `git lfs install` before cloning, or the tile sets are left as placeholder files the app rejects. A freshly installed Xcode also needs `sudo xcodebuild -license accept` and `xcodebuild -runFirstLaunch`.

```sh
make -C win/cocoa          # -> win/cocoa/build/NetHack.app
make -C win/cocoa test     # unit tests, also run by CI
```

To skip the role picker while testing:

```sh
NETHACKOPTIONS="role:Valkyrie,race:human,gender:female,align:neutral" win/cocoa/build/NetHack.app/Contents/MacOS/NetHack
```

## Where things are

The Mac app is in [`win/cocoa`](win/cocoa). Everything else is the NetHack core, kept close to upstream so new NetHack releases can be merged in. If you must change the core, keep the change small and inside `#ifdef COCOA_GRAPHICS`.

[`CLAUDE.md`](CLAUDE.md) describes how the app is put together: its two threads, how the core talks to the windows, and the build's pitfalls.

## Pull requests

- Open them against `main`. CI builds the app and runs the tests on every pull request.
- Add tests in `win/cocoa/Tests` for logic you change where you can. The tests don't link the core, so testable logic goes in plain classes.
- Match the style of the file you're editing. The Cocoa files use tabs.
- Add one short line for players under `## Unreleased` in [`CHANGELOG.md`](CHANGELOG.md) for anything they'd notice.
- Keys should work the same as in the terminal version.

By contributing you agree that your work is licensed under the license of the files you change, or for new files, of the directory you add them to: GPL v2 in `win/cocoa`, the NetHack General Public License elsewhere (see [`LICENSE`](LICENSE)).
