// What the earth wallpaper transition's falling pieces share: WallpaperTransition.vert
// and the dust, shard, and chip shaders it places. The pieces come as one strip of
// diamonds, three rows of vertices each (top point, left and right, bottom point), so
// the joins between them have no area; a piece that is not showing collapses to a
// point. `slot` is the piece's place in the strip.
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 resolution;
    vec2 center;       // px, the point of impact
    float time;        // s since the impact
    float reach;       // px, from the impact to the furthest corner
    float kind;        // the strip's pieces: 0 dust, 1 shards, 2 chips
    float slots;       // how many pieces the strip holds
    vec2 chipGrid;     // the chips table's size, in grid squares
    vec4 cCrack;
    vec4 cLip;
    vec4 cDust;
    vec4 cDustShade;
} u;
layout(binding = 1) uniform sampler2D source;
layout(binding = 2) uniform sampler2D cells;
layout(binding = 3) uniform sampler2D chips;
layout(binding = 4) uniform sampler2D cellMap;
layout(binding = 5) uniform sampler2D crackMap;
layout(binding = 6) uniform sampler2D order;
#include "Shatter.glsl"

// Texel k of a cell's entry in the cells table (WallpaperTransition.cells.frag).
vec4 cellData(vec2 c, float k) {
    vec2 w = wrapId(c);
    float col = clamp(w.x - X0, 0.0, KX - 1.0) * CELL + k;
    return textureLod(cells, vec2((col + 0.5) / (KX * CELL), (w.y + 0.5) / N), 0.0);
}

// Texel k of a grid square's entry in the chips table (WallpaperTransition.chips.frag).
vec4 chipData(vec2 c, float k) {
    vec2 i = c - CHIP_X0;
    return textureLod(chips, vec2((i.x * CHIP + k + 0.5) / (u.chipGrid.x * CHIP), (i.y + 0.5) / u.chipGrid.y), 0.0);
}

// How a loose shard moves, k of the way through its fall: it jerks up, then drops
// with gravity, pushed out from the blow, and at the last crumbles to nothing about
// its middle. Its offset from where it stood, in px, and its scale.
vec2 shardOffset(vec2 pivot, float k, out float s) {
    vec2 pd = pivot - u.center;
    float pr = length(pd);
    float cell = pr * TAU / N;
    float kk = min(k, 1.0);
    float rise = sin(clamp(kk / 0.18, 0.0, 1.0) * 3.1415927) * 0.1;
    float fall = pow(max(kk - 0.12, 0.0) / 0.88, 2.0) * 2.0;
    s = 1.0 - 0.14 * k - 0.86 * smoothstep(0.6, 1.0, k);
    return vec2(0.0, (fall - rise) * cell) + pd / max(pr, 1.0) * cell * 0.25 * kk;
}
