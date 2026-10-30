# Skate1Native

An unofficial native port of **skate** (EA Black Box, 2007) for Windows, Linux
(Steam Deck) and Android, made by statically recompiling the Xbox 360 executable to C++ with
[ReXGlue](https://github.com/rexglue/rexglue-sdk) v0.10.0. Same approach as Skate2Port.

Unofficial project, not affiliated with or endorsed by Electronic Arts. Based on
[Skate1Recompiled](https://github.com/cookingwithsimon/Skate1Recompiled) by cookingwithsimon.

**No game files are included.** You need your own Xbox 360 copy of skate as an ISO.
Everything derived from the game (extracted files, decrypted image, generated C++)
is produced locally and is ignored by git.

Status: boots, intro videos, menus, audio, career start and Freeskate all work.
The main menu has a quit entry (`main_menu_quit = false` removes it).
See [NOTES.md](NOTES.md) for the boot log, fixes and how Skate 1 differs from Skate 2,
and [docs/native_d3d.md](docs/native_d3d.md) for the native renderer.

## Building

Everyone builds the game from their own copy: no binaries are published, since they
would contain recompiled game code.

On Linux, `build-linux.sh` checks what is missing, then does everything:

```sh
./build-linux.sh --iso "Skate. (USA).iso"      # Linux and Steam Deck package
./build-linux.sh --target android              # Android APK, built from the PC
./build-linux.sh --check                       # only check the prerequisites
```

It needs podman or docker, 40 GB free and ideally 16 GB of memory; the first build
takes a long time. `--native` adds the native renderer, and builds its shader cache
from your game files the first time.

### Windows

Requirements: Windows, Visual Studio 2022 Build Tools, LLVM/Clang 18+, CMake 3.25+,
Ninja, Python 3. ReXGlue requires Clang.

```bat
git clone https://github.com/Kurtisone/Skate1Native
cd Skate1Native

rem 1. Extract your own ISO into game/
powershell -ExecutionPolicy Bypass -File tools\extract_iso.ps1 -Iso "Skate. (USA).iso" -Out game

rem 2. Configure (builds the SDK as part of the project)
devenv.bat cmake --preset win-amd64-relwithdebinfo

rem 3. Build the rexglue tool, then recompile the game (about 9 minutes)
devenv.bat cmake --build out/build/win-amd64-relwithdebinfo --target rexglue
third_party\rexglue-sdk\out\win-amd64\rexgluerd.exe codegen skate1_manifest.toml

rem 4. Reconfigure so CMake sees the generated sources, then build
devenv.bat cmake --preset win-amd64-relwithdebinfo
devenv.bat cmake --build out/build/win-amd64-relwithdebinfo
```

Copy `config/skate1.runtime.toml` next to `skate1.exe` as `skate1.toml`. It
holds the settings Skate 1 needs (GPU plugin, vsync, depth conversion, memory
coherency). Since SDK 0.10 the GPU emulation is a separate library,
`rexgpu-xenos`, copied next to the exe by the build and selected by
`gpu_plugin = 'xenos'`; without that line the game starts with no GPU.
After the first build, codegen reruns on its own whenever its inputs change.
`game_data_root` may be relative to the exe. A `portable.txt` beside the exe keeps
saves in a `userdata` folder there.

To make the intro movies skippable, create an empty `game/data/AllowMovieSkip.txt`
(the game checks for it; the retail disc doesn't ship it).

To use an SDK checkout elsewhere, configure with `-DREXSDK_DIR=<path>`.

### macOS (Apple Silicon, untested)

The SDK supports macOS on ARM64 through Vulkan on MoltenVK. Nobody has run the
game on a Mac yet, so expect rendering bugs; reports in the issues are welcome.
Intel Macs are not supported. Apple Clang is rejected by the SDK, so use
Homebrew LLVM.

```sh
brew install llvm cmake ninja python molten-vk vulkan-loader
git clone https://github.com/Kurtisone/Skate1Native
cd Skate1Native

python3 tools/extract_iso.py "Skate. (USA).iso" game

# Build the rexglue tool from the SDK on its own: the project can't be
# configured until codegen has written generated/rexglue.cmake.
cmake -S third_party/rexglue-sdk -B out/sdk -G Ninja -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_C_COMPILER=/opt/homebrew/opt/llvm/bin/clang \
  -DCMAKE_CXX_COMPILER=/opt/homebrew/opt/llvm/bin/clang++ \
  -DCMAKE_OSX_ARCHITECTURES=arm64 -DREXGLUE_ENABLE_TRACY=OFF
cmake --build out/sdk --target rexglue
REXGLUE=third_party/rexglue-sdk/out/mac-arm64/rexglue   # the SDK writes the tool here, not under out/sdk
"$REXGLUE" codegen skate1_manifest.toml   # answer yes if it asks to write generated files

cmake --preset macos-arm64-relwithdebinfo
cmake --build out/build/macos-arm64-relwithdebinfo
```

The build copies `libMoltenVK.dylib`, the Vulkan loader and a `MoltenVK_icd.json`
next to the `skate1` binary. Copy `config/skate1.runtime.toml` there as
`skate1.toml` and put the extracted `game/` folder beside it, or point
`game_data_root` at it. The `d3d12_*` settings are ignored on macOS.

## SDK

`third_party/rexglue-sdk` is the vendored SDK (no submodules): rexglue-sdk v0.10.0
with the changes of the rexglue-skate3 fork, plus the fixes this port needs. See
[THIRD_PARTY.md](THIRD_PARTY.md) for sources and credits. Among those fixes:

- **codegen: vpkuwus/vpkuhus aliasing.** When the destination register equals a
  source (`vpkuwus v0,v12,v0`), the generated code overwrote its input mid-way.
  Skate 1's VP6 video decoder always uses that form, causing green block
  corruption in every video. Still present upstream in v0.10.0.
- **readback_resolve_force_length**: always reads back one exact resolve length
  (the Skate 1 photo target).
- **Guest backtrace** on calls to unregistered functions (finding missed functions).
- **imgui**: works with stock imgui (v1.92.5, the upstream pin; the fork's pinned
  commit is not fetchable), and the overlay draw loop uses `CmdLists.Size`.

The GPU page-state flicker fix and the Win32 Alt-key fix are gone: v0.10.0 fixes
the first itself and replaced the Win32 window with SDL. The presets build with
`REXGLUE_ENABLE_PERF_COUNTERS=OFF` (about 6% CPU saved on the GPU thread).

Linux builds of SDL need the X11 development headers, including libXi
(XInput2), plus an audio backend (ALSA, PulseAudio or PipeWire).

## Layout

| Path | What |
|---|---|
| `skate1_manifest.toml` | ReXGlue project manifest |
| `config/skate1_functions.toml` | setjmp/longjmp and function boundary overrides |
| `config/skate1.runtime.toml` | runtime settings to copy next to the exe |
| `src/` | app shell, game hooks (frame cap, single-pass scene, quit entry) |
| `src/native_gpu/` | native D3D renderer (plume + XenosRecomp shaders) |
| `docs/` | native renderer notes, D3D function map |
| `tools/` | ISO extractor, codegen/build/run loop, missed-function scanners, screenshot and input scripts, Deck and Android builds, frame replayer (`native_replay`) |

## Credits

ReXGlue, Xenia, rexglue-skate3, Unleashed Recompiled and the libraries in
[THIRD_PARTY.md](THIRD_PARTY.md) by their authors. skate is a trademark of Electronic Arts.
