#version 440
#extension GL_GOOGLE_include_directive : enable
// Works out the relâmpago wallpaper transition's bolt once, into a float table its
// shader reads (WallpaperTransition.frag):
//   row 0: where the bolt crosses each row of the screen (x, px), at row i's middle
//   row 1: FORKS texels, each fork's (x and y where it leaves the bolt, its length,
//          its side), then two texels for each of EMBERS embers: (where it starts on
//          the bolt, its side and spread, its size, its tint), and (x of the bolt there)
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 resolution;
    float seed;
    float columns;      // the table's width
} u;
#include "../common/common.glsl"
#include "Tear.glsl"

// The bolt's path, a new one each time: big zigzags between corners at uneven
// heights, kicked out mostly left and right by turns but now and then twice the same
// way, leaning a little as it falls, with small torn teeth along it.
float tearX(float y) {
    float H = u.resolution.y, W = u.resolution.x;
    float P = H / 4.5;
    float k = floor(y / P);
    float s = u.seed * 97.0;
    #define KINK(i) vec2(((i) + 0.5 * (hash(vec2((i), 2.0 + s)) - 0.5)) * P, \
        (mod((i), 2.0) * 2.0 - 1.0) * (hash(vec2((i), 5.0 + s)) < 0.2 ? -0.45 : 1.0) \
        * mix(0.04, 0.15, hash(vec2((i), 1.0 + s))) * W)
    vec2 a = KINK(k), b = KINK(k + 1.0);
    if (y < a.x) { b = a; a = KINK(k - 1.0); }
    else if (y > b.x) { a = b; b = KINK(k + 2.0); }
    #undef KINK
    float x = mix(a.y, b.y, clamp((y - a.x) / (b.x - a.x), 0.0, 1.0));
    float lean = (u.seed - 0.5) * 0.16 * W * (y / H - 0.5);
    return W * 0.5 + x + lean + 7.0 * zig(y / 23.0, 3.0);
}

void main() {
    float i = floor(qt_TexCoord0.x * u.columns);
    float H = u.resolution.y;
    if (qt_TexCoord0.y < 0.5) {
        fragColor = vec4(tearX(i + 0.5), 0.0, 0.0, 1.0);
    } else if (i < float(FORKS)) {
        // Forks running off the bolt's corners.
        float y0 = H * (0.15 + 0.2 * i + 0.05 * hash(vec2(i, 5.0)));
        float len = H * (0.06 + 0.05 * hash(vec2(i, 6.0)));
        fragColor = vec4(tearX(y0), y0, len, mod(i, 2.0) * 2.0 - 1.0);
    } else if (i < float(FORKS + 2 * EMBERS)) {
        // Embers spilling into the gap.
        float e = floor((i - float(FORKS)) / 2.0);
        vec4 h = vec4(hash(vec2(e, 1.0)), hash(vec2(e, 2.0)), hash(vec2(e, 3.0)), hash(vec2(e, 4.0)));
        float y0 = h.x * H;
        float spread = (h.y < 0.5 ? -1.0 : 1.0) * mix(0.2, 0.9, h.w);
        fragColor = mod(i - float(FORKS), 2.0) < 0.5 ? vec4(y0, spread, h.z, h.w) : vec4(tearX(y0), 0.0, 0.0, 1.0);
    } else {
        fragColor = vec4(0.0);
    }
}
