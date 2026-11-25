#version 440
#extension GL_GOOGLE_include_directive : enable
// Works out the relâmpago wallpaper transition's bolt once, into a float table its
// shader reads (WallpaperTransition.frag):
//   row 0: where the bolt crosses each row of the screen (x, px), at row i's middle
//   row 1: two texels for each of FORKS forks, the four corners of its three runs
//          from where it leaves the bolt to its tip ((x, y) of the first two, then of
//          the last two), then two texels for each of EMBERS embers: (where it starts
//          on the bolt, its side and spread, its size, its tint), and (x of the bolt there)
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

// The bolt's path, a new one each time: zigzags between corners at uneven heights,
// kicked out mostly left and right by turns but now and then twice the same way,
// leaning a little as it falls, with smaller kinks along each run and small torn
// teeth along it.
float tearX(float y) {
    float H = u.resolution.y, W = u.resolution.x;
    float P = H / 6.0;
    float k = floor(y / P);
    float s = u.seed * 97.0;
    #define KINK(i) vec2(((i) + 0.45 * (hash(vec2((i), 2.0 + s)) - 0.5)) * P, \
        (mod((i), 2.0) * 2.0 - 1.0) * (hash(vec2((i), 5.0 + s)) < 0.2 ? -0.45 : 1.0) \
        * mix(0.025, 0.075, hash(vec2((i), 1.0 + s))) * W)
    vec2 a = KINK(k), b = KINK(k + 1.0);
    if (y < a.x) { b = a; a = KINK(k - 1.0); }
    else if (y > b.x) { a = b; b = KINK(k + 2.0); }
    #undef KINK
    float x = mix(a.y, b.y, clamp((y - a.x) / (b.x - a.x), 0.0, 1.0));
    float lean = (u.seed - 0.5) * 0.16 * W * (y / H - 0.5);
    return W * 0.5 + x + lean + 26.0 * zig(y / 64.0, 7.0 + s) + 6.0 * zig(y / 19.0, 3.0);
}

void main() {
    float i = floor(qt_TexCoord0.x * u.columns);
    float H = u.resolution.y;
    if (qt_TexCoord0.y < 0.5) {
        fragColor = vec4(tearX(i + 0.5), 0.0, 0.0, 1.0);
    } else if (i < float(2 * FORKS)) {
        // Forks off the bolt, one in each quarter of its height but the last, splaying
        // out to alternate sides in three kinked runs that steepen as they go.
        float f = floor(i / 2.0);
        float s = u.seed * 61.0 + f;
        float y0 = H * (0.12 + 0.19 * f + 0.07 * hash(vec2(f, 5.0 + s)));
        float len = H * mix(0.09, 0.17, hash(vec2(f, 6.0 + s)));
        float side = (mod(f, 2.0) * 2.0 - 1.0) * (hash(vec2(f, 8.0 + s)) < 0.5 ? 1.0 : -1.0);
        vec2 a = vec2(tearX(y0), y0);
        vec2 c[3];
        vec2 at = a;
        for (int j = 0; j < 3; j++) {
            float fj = float(j);
            float ang = mix(0.95, 0.45, fj / 2.0) + 0.35 * (hash(vec2(fj, s + 9.0)) - 0.5);
            at += vec2(side * sin(ang), cos(ang)) * len / 3.0 * mix(0.8, 1.2, hash(vec2(fj, s + 4.0)));
            c[j] = at;
        }
        fragColor = mod(i, 2.0) < 0.5 ? vec4(a, c[0]) : vec4(c[1], c[2]);
    } else if (i < float(2 * FORKS + 2 * EMBERS)) {
        // Embers spilling into the gap.
        float e = floor((i - float(2 * FORKS)) / 2.0);
        float s = u.seed * 53.0;
        vec4 h = vec4(hash(vec2(e, 1.0 + s)), hash(vec2(e, 2.0 + s)), hash(vec2(e, 3.0 + s)), hash(vec2(e, 4.0 + s)));
        float y0 = h.x * H;
        float spread = (h.y < 0.5 ? -1.0 : 1.0) * mix(0.2, 0.9, h.w);
        fragColor = mod(i, 2.0) < 0.5 ? vec4(y0, spread, h.z, h.w) : vec4(tearX(y0), 0.0, 0.0, 1.0);
    } else {
        fragColor = vec4(0.0);
    }
}
