#version 440
#extension GL_GOOGLE_include_directive : enable
// The old wallpaper split by lightning. A bolt forks down the screen and everything
// flashes; then the image tears apart along the bolt's path and the two halves race
// off to either side, smeared by their speed, their torn edges glowing and cooling,
// embers spilling from the tear into the gap where the new wallpaper shows.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 resolution;
    float progress;     // 0..1
    vec4 cCore;
    vec4 cGlow;
    vec4 cEdge;
    vec4 cPaint;
} u;
layout(binding = 1) uniform sampler2D source;
#include "../../lib/common.glsl"

const float STRIKE = 0.1;       // the bolt reaching the bottom
const float SPLIT = 0.16;       // the halves starting to move

float tearX(float y) {
    return u.resolution.x * (0.5 + 0.16 * zig(y / 150.0, 1.0) + 0.05 * zig(y / 40.0, 2.0) + 0.012 * zig(y / 11.0, 3.0));
}

float span(float x, float a, float b) { return clamp((x - a) / (b - a), 0.0, 1.0); }

void main() {
    vec2 p = qt_TexCoord0 * u.resolution;
    float t = u.progress;
    float W = u.resolution.x;
    float tx = tearX(p.y);
    float s = span(t, SPLIT, 1.0);
    float gap = W * 0.72 * pow(s, 2.1);
    float speed = W * 0.72 * 2.1 * pow(s, 1.1);          // px per unit of s
    float blur = min(140.0, speed * 0.05);

    // Each half, crisp along its torn edge, its colors smeared along its motion by
    // taps back toward where it was; streaks of hot light trail off the edge.
    vec4 col = vec4(0.0);
    float heat = 1.0 - span(t, 0.3, 0.95);
    float jit = hash(p);
    for (int side = 0; side < 2; side++) {
        float dir = side == 0 ? -1.0 : 1.0;
        vec2 src = p - vec2(dir * gap, 0.0);
        float own = side == 0 ? tx - src.x : src.x - tx;  // px inside this half, < 0 past its edge
        if (own > -2.0) {
            vec4 acc = vec4(0.0);
            float wsum = 0.0;
            for (int i = 0; i < 4; i++) {
                float k = (float(i) + jit) / 4.0;
                // Taps stay inside the half, so the edge does not smear into the gap.
                vec2 q = src - vec2(dir * min(blur * k, max(own - 1.0, 0.0)), 0.0);
                acc += texture(source, q / u.resolution) * (1.0 - 0.5 * k);
                wsum += 1.0 - 0.5 * k;
            }
            vec4 half_ = acc / wsum * cover(own);
            // The torn edge, white-hot and cooling to red.
            if (s > 0.0 && heat > 0.0) {
                float e = 1.0 - smoothstep(0.0, 10.0 * heat + 2.0, own);
                vec3 hot = mix(u.cPaint.rgb, u.cEdge.rgb, heat);
                hot = mix(hot, u.cGlow.rgb, smoothstep(0.4, 1.0, heat) * (1.0 - smoothstep(0.0, 4.0, own)));
                half_.rgb = mix(half_.rgb, hot * half_.a, e);
            }
            col = half_ + col * (1.0 - half_.a);
        }
        if (own < 0.0 && s > 0.0) {
            float back = -own;
            float streak = band(vnoise(vec2(p.y / 3.0, float(side) * 9.0)), 0.45);
            float trail = exp(-back / (blur * 0.6 + 4.0)) * heat * (0.35 + 0.65 * streak);
            vec3 tc = mix(u.cPaint.rgb, u.cEdge.rgb, exp(-back / 20.0));
            col = mix(col, vec4(tc, 1.0), trail * 0.85 * (1.0 - col.a));
        }
    }

    // Embers spilling into the gap, carried apart and falling.
    // Embers stay within the gap's reach of the tear, so most pixels skip them.
    if (s > 0.0 && s < 0.95 && abs(p.x - tx) < gap + 0.3 * W) {
        for (int i = 0; i < 32; i++) {
            float fi = float(i);
            vec4 h = vec4(hash(vec2(fi, 1.0)), hash(vec2(fi, 2.0)), hash(vec2(fi, 3.0)), hash(vec2(fi, 4.0)));
            float y0 = h.x * u.resolution.y;
            float dir = h.y < 0.5 ? -1.0 : 1.0;
            float age = s * mix(0.8, 1.6, h.z);
            float ey = y0 + 260.0 * age * age - 60.0 * age;
            if (abs(p.y - ey) > 5.0)
                continue;
            vec2 ep = vec2(tearX(y0) + dir * gap * mix(0.2, 0.9, h.w), ey);
            float life = 1.0 - smoothstep(0.5, 1.0, age);
            float r = mix(1.5, 3.5, h.z) * life;
            float d = length(p - ep);
            vec3 ec = mix(u.cEdge.rgb, u.cGlow.rgb, h.w);
            col = mix(col, vec4(ec, 1.0), cover(r - d) * life);
        }
    }

    // The bolt, striking down and flickering out, and the flash it throws.
    float flash = smoothstep(0.0, STRIKE, t) * (1.0 - smoothstep(STRIKE, 0.42, t));
    col.rgb += u.cCore.rgb * col.a * 0.45 * flash * flash;
    col.rgb = min(col.rgb, vec3(col.a));
    float on = (1.0 - smoothstep(0.3, 0.45, t)) * step(0.2, hash(vec2(floor(t * 60.0), 9.0)) + step(t, STRIKE));
    float tip = u.resolution.y * min(1.0, t / STRIKE);
    if (on > 0.0 && p.y < tip) {
        float bx = tx;
        float bx2 = tearX(p.y + 1.0);
        float d = abs(p.x - bx) / sqrt(1.0 + (bx2 - bx) * (bx2 - bx));
        // Forks running off the main channel.
        float fork = 1e3;
        for (int i = 0; i < 6; i++) {
            float fi = float(i);
            float y0 = u.resolution.y * (0.05 + 0.15 * fi + 0.06 * hash(vec2(fi, 5.0)));
            float len = 120.0 + 160.0 * hash(vec2(fi, 6.0));
            float f = (p.y - y0) / len;
            if (f < 0.0 || f > 1.0)
                continue;
            float side = hash(vec2(fi, 7.0)) < 0.5 ? -1.0 : 1.0;
            float fx = tearX(y0) + side * f * len * 0.7 + 22.0 * zig(p.y / 18.0, fi + 11.0);
            fork = min(fork, abs(p.x - fx) - 1.5 * (1.0 - f));
        }
        float w = 2.5 * (1.0 - s);
        vec4 b = vec4(0.0);
        b = mix(b, vec4(u.cEdge.rgb, 1.0), cover(w + 14.0 - d) * 0.35);
        b = mix(b, vec4(u.cGlow.rgb, 1.0), cover(w + 4.0 - d));
        b = mix(b, vec4(u.cCore.rgb, 1.0), cover(w - d));
        b = mix(b, vec4(u.cGlow.rgb, 1.0), cover(2.2 - fork));
        b = mix(b, vec4(u.cCore.rgb, 1.0), cover(0.8 - fork));
        col = mix(col, b, b.a * on);
    }

    fragColor = col * u.qt_Opacity;
}
