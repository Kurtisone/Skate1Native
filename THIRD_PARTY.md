# Third-party code

This project started from [Skate1Recompiled](https://github.com/cookingwithsimon/Skate1Recompiled)
by cookingwithsimon; its history is not carried over here.

Everything is vendored in `third_party/`: there are no submodules. Each folder keeps
its own license file, which applies to that code. Commits are the ones copied.

## ReXGlue SDK (`third_party/rexglue-sdk`)

- [rexglue-sdk](https://github.com/rexglue/rexglue-sdk) v0.10.0 by Tom Clay and
  contributors, derived from [Xenia](https://xenia.jp) (Ben Vanik and contributors).
  BSD license, see its `LICENSE`.
- Changes from [rexglue-skate3](https://github.com/mchughalex/rexglue-skate3) by
  mchughalex and contributors, made for the Skate 3 PC recompilation. Skate 1
  keeps its fixes (audio, rendering, memory), and some comments and optional
  settings still name Skate 3.
- This port's own changes. The commit history up to the copy (`94cf105`) is in
  [Kurtisone/rexglue-skate3](https://github.com/Kurtisone/rexglue-skate3), branch
  `skate1-dev`.

## Native renderer

- [Unleashed Recompiled](https://github.com/hedge-dev/UnleashedRecomp), GPL-3.0:
  `src/native_gpu/unleashed`, see its README.
- [XenosRecomp](https://github.com/hedge-dev/XenosRecomp) by hedge-dev (MIT):
  `third_party/XenosRecomp`, with this port's changes on `990d03b` (microcode cache
  keys, uncompressed SPIR-V, half float normals) and its libraries (`fmt`, `xxHash`,
  `zstd`, `smol-v`, `dxc-bin` reduced to the Linux x64 compiler). Tests and docs are
  left out. It builds the shader cache from your own game files.
- [smol-v](https://github.com/aras-p/smol-v): `third_party/smol-v`.
- plume carries one local change: scaled vertex input formats (`abd33fa`).

## Libraries

| Folder | Source | Commit |
|---|---|---|
| `thirdparty/FFmpeg` | https://github.com/wmarti/FFmpeg | `0604b464c7` |
| `thirdparty/catch2` | https://github.com/catchorg/Catch2 | `88abf9bf32` |
| `thirdparty/cli11` | https://github.com/CLIUtils/CLI11 | `bfffd37e1f` |
| `thirdparty/fmt` | https://github.com/fmtlib/fmt | `407c905e45` |
| `thirdparty/glslang` | https://github.com/KhronosGroup/glslang | `f4f1d8a352` |
| `thirdparty/imgui` | https://github.com/ocornut/imgui | `6d910d5487` |
| `thirdparty/inja` | https://github.com/pantor/inja | `7d1b4600b6` |
| `thirdparty/libmspack` | https://github.com/kyz/libmspack | `305907723a` |
| `thirdparty/moltenvk` | https://github.com/KhronosGroup/MoltenVK | `701747d61a` |
| `thirdparty/o1heap` | https://github.com/pavel-kirienko/o1heap | `388a73fd90` |
| `thirdparty/sdl3` | https://github.com/libsdl-org/SDL | `147a8ee32d` |
| `thirdparty/simde` | https://github.com/simd-everywhere/simde | `71fd833d96` |
| `thirdparty/simde/test/munit` | https://github.com/nemequ/munit | `da8f734129` |
| `thirdparty/spdlog` | https://github.com/gabime/spdlog | `79524ddd08` |
| `thirdparty/spirv-headers` | https://github.com/KhronosGroup/SPIRV-Headers | `29981f6524` |
| `thirdparty/spirv-tools` | https://github.com/KhronosGroup/SPIRV-Tools | `9a49b0883b` |
| `thirdparty/tomlplusplus` | https://github.com/marzer/tomlplusplus | `30172438ce` |
| `thirdparty/tracy` | https://github.com/wolfpld/tracy | `05cceee0df` |
| `thirdparty/utfcpp` | https://github.com/nemtrif/utfcpp | `63d64de49f` |
| `thirdparty/vulkan-headers` | https://github.com/KhronosGroup/Vulkan-Headers | `e3b1eec081` |
| `thirdparty/vulkan-loader` | https://github.com/KhronosGroup/Vulkan-Loader | `5f157b62e3` |
| `thirdparty/vulkan-memory-allocator` | https://github.com/GPUOpen-LibrariesAndSDKs/VulkanMemoryAllocator | `1d8f600fd4` |
| `thirdparty/xxHash` | https://github.com/Cyan4973/xxHash | `e626a72bc2` |
| `plume` | https://github.com/renderbag/plume | `abd33fa641` |
| `plume/contrib/D3D12MemoryAllocator` | https://github.com/GPUOpen-LibrariesAndSDKs/D3D12MemoryAllocator | `9ef66bc14e` |
| `plume/contrib/Vulkan-Headers` | https://github.com/KhronosGroup/Vulkan-Headers | `89268a6d17` |
| `plume/contrib/VulkanMemoryAllocator` | https://github.com/GPUOpen-LibrariesAndSDKs/VulkanMemoryAllocator | `29b35ea423` |
| `plume/contrib/volk` | https://github.com/zeux/volk | `be3dbd49bf` |
| `libadrenotools` | https://github.com/bylaws/libadrenotools | `8fae8ce254` |
| `libadrenotools/lib/linkernsbypass` | https://github.com/bylaws/liblinkernsbypass | `aa3975893d` |
