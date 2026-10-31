# Skate1Native

Unofficial native port of **skate** (EA Black Box, 2007), statically recompiled from
Xbox 360 to C++ with [ReXGlue](https://github.com/rexglue/rexglue-sdk). Runs on Linux, Steam
Deck and Android with the native renderer (no GPU emulation), up to 60 FPS on the Deck.

Not affiliated with Electronic Arts. Based on
[Skate1Recompiled](https://github.com/cookingwithsimon/Skate1Recompiled) by cookingwithsimon.

**No game files or binaries are provided:** you build it from your own Xbox 360 copy.

## Build

```sh
./build-linux.sh
```

It finds your ISO, asks for Linux and Steam Deck or Android, checks what is missing and
resumes if interrupted. Options: `--iso <file>`, `--target android`, `--emulated`, `--check`.

Needs podman or docker, 40 GB free and ideally 16 GB of memory.
Windows and macOS instructions, untested with the native renderer:
[docs/building.md](docs/building.md).

## Play

RB+Start opens a menu: 30, 40 or 60 FPS, resolution (720p to 1440p), VSync, quit. The native build starts at 60 on
the Deck and at 30 on Android.

## More

[Native renderer](docs/native_d3d.md) · [Development notes](NOTES.md) ·
[Credits](THIRD_PARTY.md)

GPL-3.0. skate is a trademark of Electronic Arts.
