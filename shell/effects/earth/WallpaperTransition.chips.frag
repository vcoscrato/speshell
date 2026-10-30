#version 440
#extension GL_GOOGLE_include_directive : enable
// Works out the chips of the old wallpaper that the crack front flings up, once, into
// a float table that the earth wallpaper transition's shader looks up: CHIP texels for
// each square of its CHIP_G px grid (from CHIP_X0 on both axes), holding
//   0: where it starts (px), when it is flung, and its size (0: no chip there)
//   1: its velocity (px/s) and how fast it turns
//   2: its color, the old wallpaper where it starts
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 resolution;
    vec2 center;       // px, the point of impact
    float reach;       // px, from the impact to the furthest corner
    vec2 grid;         // the table's size, in grid squares
} u;
layout(binding = 1) uniform sampler2D source;
#include "Shatter.glsl"

void main() {
    vec2 t = floor(qt_TexCoord0 * vec2(u.grid.x * CHIP, u.grid.y));
    float k = mod(t.x, CHIP);
    vec2 c = vec2(floor(t.x / CHIP), t.y) + CHIP_X0;
    vec3 h = vec3(hash(c + 0.13), hash(c + 5.7), hash(c + 9.1));
    vec2 start = (c + 0.2 + 0.6 * h.yz) * CHIP_G;
    vec2 sd = start - u.center;
    float sr = length(sd);
    if (k < 0.5) {
        float born = crackAt(sr, atan(sd.y, sd.x)) + 0.03 + 0.12 * h.y;
        float size = mix(2.5, 5.5, h.z * h.x / 0.32) * (sr < 160.0 ? 0.7 : 1.0);
        fragColor = vec4(start, born, h.x > 0.32 ? 0.0 : size);
    } else if (k < 1.5) {
        vec2 vel = sd / max(sr, 1.0) * mix(30.0, 140.0, h.z) + vec2(0.0, -mix(140.0, 340.0, h.y));
        fragColor = vec4(vel, (h.y - 0.5) * 22.0, 0.0);
    } else {
        fragColor = vec4(texture(source, start / u.resolution).rgb, 1.0);
    }
}
