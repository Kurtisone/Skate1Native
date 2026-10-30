# Skate1Native

Unofficial native port of **skate** (EA Black Box, 2007), statically recompiled from
Xbox 360 to C++ with [ReXGlue](https://github.com/rexglue/rexglue-sdk). Runs on Linux, Steam
Deck and Android, at 30 FPS with the native renderer (no GPU emulation).

Not affiliated with Electronic Arts. Based on
[Skate1Recompiled](https://github.com/cookingwithsimon/Skate1Recompiled) by cookingwithsimon.

**No game files or binaries are provided:** you build it from your own Xbox 360 copy.

## Build

```sh
./build-linux.sh --iso "Skate. (USA).iso"      # Linux and Steam Deck
./build-linux.sh --target android --native     # Android APK
./build-linux.sh --native                      # Linux and Deck, native renderer
./build-linux.sh --check                       # check the prerequisites only
```

Needs podman or docker, 40 GB free and ideally 16 GB of memory.
Windows and macOS: [docs/building.md](docs/building.md).

## More

[Native renderer](docs/native_d3d.md) · [Development notes](NOTES.md) ·
[Credits](THIRD_PARTY.md)

GPL-3.0. skate is a trademark of Electronic Arts.
