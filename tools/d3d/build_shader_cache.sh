#!/usr/bin/env bash
# Build the native D3D layer's shader cache (out/native/shader_cache.cpp) from
# the game's own files with the vendored XenosRecomp (microcode keys):
#   tools/d3d/build_shader_cache.sh
# Runs in the build container (tools/steamdeck/build.sh does it for NATIVE=1)
# once the SDK is built. The archives are harvested once (~3 min); the
# post-processing shaders are in the executable, read from its decoded image.
set -euo pipefail
cd "$(dirname "$0")/../.."
XR=third_party/XenosRecomp
XRB=out/native-tools/xenosrecomp
OUT="${SHADER_CACHE_OUT:-out/native}"
REXGLUE="$(ls third_party/rexglue-sdk/out/linux-amd64/rexglue* | grep -v '\.so' | head -1)"
cmake -S "$XR" -B "$XRB" -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++
cmake --build "$XRB" --target XenosRecomp
if [ ! -d "$OUT/allshaders" ]; then
  python3 tools/d3d/harvest_shaders.py game/data "$OUT/allshaders"
fi
rm -rf "$OUT/image"
LD_LIBRARY_PATH="$(dirname "$REXGLUE")" "$REXGLUE" dump-xex game/default.xex "$OUT/image"
rm -rf "$OUT/cacheinput"
mkdir -p "$OUT/cacheinput"
cp "$OUT"/allshaders/*.bin "$OUT/cacheinput/"
python3 tools/d3d/image_shaders.py "$OUT/image" "$OUT/cacheinput"
XENOS_RECOMP_MICROCODE_KEY=1 XENOS_RECOMP_NO_ZSTD=1 LD_LIBRARY_PATH="$PWD/$XR/thirdparty/dxc-bin/lib/x64" \
  "$XRB/XenosRecomp/XenosRecomp" "$OUT/cacheinput" "$OUT/shader_cache.cpp" \
  "$XR/XenosRecomp/shader_common.h"
echo "$(grep -c '^	{ 0x' "$OUT/shader_cache.cpp") shaders in $OUT/shader_cache.cpp"
