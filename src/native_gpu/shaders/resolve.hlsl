// skate1 - native D3D layer: Resolve (EDRAM render target -> texture).
// Full-screen triangle; the pixel shader loads the source surface at the
// destination pixel + offset and converts it to what the game's texture
// fetches expect:
//   mode 0: color * scale (a resolve converts the value to the destination
//           format, which is the host texture's)
//   mode 3: 8_8_8_8 color in memory order (x = blue, as D3D's A8R8G8B8 copies
//           lay it out; the game's fetches swizzle it back).
//   mode 1: depth packed as D24S8 (depth << 8 | stencil) in an 8_8_8_8
//           texture, as a depth resolve read through an 8_8_8_8 fetch sees
//           it (Skate tags objects in the stencil and reads the tag back).

struct PushConstants
{
    uint SourceIndex;
    uint Mode;
    float Scale;
    int OffsetX;
    int OffsetY;
    uint StencilIndex;
};

[[vk::push_constant]] ConstantBuffer<PushConstants> g_Push;
[[vk::binding(0, 0)]] Texture2D<float4> g_Textures[];
// The same heap, for stencil views.
[[vk::binding(0, 0)]] Texture2D<uint4> g_UintTextures[];

float4 VSMain(uint id : SV_VertexID) : SV_Position
{
    float2 uv = float2((id << 1) & 2, id & 2);
    return float4(uv * 2.0 - 1.0, 0.0, 1.0);
}

float4 PSMain(float4 position : SV_Position) : SV_Target
{
    int2 p = int2(position.xy) + int2(g_Push.OffsetX, g_Push.OffsetY);
    float4 value = g_Textures[g_Push.SourceIndex].Load(int3(p, 0));
    if (g_Push.Mode == 1)
    {
        uint stencil = g_UintTextures[g_Push.StencilIndex].Load(int3(p, 0)).x & 0xFF;
        uint packed = (uint(saturate(value.x) * 16777215.0 + 0.5) << 8) | stencil;
        return float4(packed & 0xFF, (packed >> 8) & 0xFF, (packed >> 16) & 0xFF, packed >> 24) / 255.0;
    }
    if (g_Push.Mode == 3)
    {
        return value.bgra;
    }
    return value * g_Push.Scale;
}

// Presentation: the front buffer packed as A2B10G10R10 (the presenter's
// guest output format) into an R32_UINT target, read back and copied as is.
uint PSPack(float4 position : SV_Position) : SV_Target
{
    // Rendered larger than shown (Scale > 1): the average of the pixel's area.
    float4 value = 0.0;
    if (g_Push.Scale > 1.0)
    {
        const float2 corners[4] = {float2(0.25, 0.25), float2(0.75, 0.25), float2(0.25, 0.75), float2(0.75, 0.75)};
        for (int i = 0; i < 4; ++i)
        {
            value += g_Textures[g_Push.SourceIndex].Load(int3(int2((floor(position.xy) + corners[i]) * g_Push.Scale), 0));
        }
        value *= 0.25;
    }
    else
    {
        value = g_Textures[g_Push.SourceIndex].Load(int3(int2(position.xy) + int2(g_Push.OffsetX, g_Push.OffsetY), 0));
    }
    // The front buffer copy is in memory order (blue first).
    value = saturate(value).bgra;
    uint3 rgb = uint3(value.rgb * 1023.0 + 0.5);
    return rgb.r | (rgb.g << 10) | (rgb.b << 20) | (3u << 30);
}
