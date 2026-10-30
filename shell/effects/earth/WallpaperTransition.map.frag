#version 440
#extension GL_GOOGLE_include_directive : enable
// Works out, once, what the earth wallpaper transition needs to know about each
// screen point that does not change as it plays: where the point lies among the cells,
// and the crack it is beside. `which` picks the map:
//   0: the shard it is in
//   1: its distance to the nearest border with another shard (px, at most 255), which
//      way that border runs (in cells units), and when its crack opens
// The transition reads both where a pixel stands and, for a falling shard, at the
// point of the old wallpaper it shows.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 resolution;
    vec2 center;       // px, the point of impact
    float reach;       // px, from the impact to the furthest corner
    float which;
} u;
layout(binding = 1) uniform sampler2D cells;
#include "Shatter.glsl"

// Texel k of a cell's entry in the cells table (WallpaperTransition.cells.frag).
vec4 cellData(vec2 c, float k) {
    vec2 w = wrapId(c);
    float col = clamp(w.x - X0, 0.0, KX - 1.0) * CELL + k;
    return texture(cells, vec2((col + 0.5) / (KX * CELL), (w.y + 0.5) / N));
}

void main() {
    vec2 p = qt_TexCoord0 * u.resolution;
    vec2 x = toCells(p);
    vec2 g = floor(x);
    vec2 a = g;
    vec2 sa = vec2(0.0);
    vec2 ownG = vec2(0.0);
    float bestD = 1e9;
    for (int j = -1; j <= 1; j++)
        for (int i = -1; i <= 1; i++) {
            vec2 c = g + vec2(i, j);
            vec4 cd = cellData(c, 0.0);
            vec2 o = x - (c + cd.xy);
            float dd = dot(o, o);
            if (dd < bestD) { bestD = dd; a = c; sa = c + cd.xy; ownG = cd.zw; }
        }
    if (u.which < 0.5) {
        fragColor = vec4(ownG, 0.0, 0.0);
        return;
    }

    // The nearest border to another shard, in px, and how it runs.
    vec2 d0 = p - u.center;
    float r = length(d0);
    float pxV = r * TAU / N;
    float pxU = pxV / KU;
    float edge = 1e9;
    vec2 nrm = vec2(1.0, 0.0);
    vec2 other = a;
    for (int j = -1; j <= 1; j++)
        for (int i = -1; i <= 1; i++) {
            vec2 c = g + vec2(i, j);
            vec4 nb = cellData(c, 0.0);
            if (c == a || nb.zw == ownG)
                continue;
            vec2 sc = c + nb.xy;
            vec2 n = normalize(sc - sa);
            // Distance to the bisector, scaled from cell units to px.
            float e = dot((sa + sc) * 0.5 - x, n) / length(vec2(n.x / pxU, n.y / pxV));
            if (e < edge) { edge = e; nrm = n; other = c; }
        }
    // Rays crack as the front passes; the branches across them a moment later.
    float across = step(abs(nrm.y), abs(nrm.x));
    vec2 pair = wrapId(a) + wrapId(other);
    float crackT = crackAt(r, atan(d0.y, d0.x)) + across * (0.05 + 0.2 * hash(pair + 0.4));
    fragColor = vec4(min(edge, 255.0), nrm, crackT);
}
