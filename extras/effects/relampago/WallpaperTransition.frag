#version 440
#extension GL_GOOGLE_include_directive : enable
// The old wallpaper split by lightning, like a cartoon. A bold bolt, outlined in
// rubber, strikes down the screen in big zigzags, everything flashes, and a comic
// starburst bursts where it lands; then the image tears apart along the bolt's path
// and the two halves race off to either side, crisp, their torn edges inked and
// glowing hot and cooling, speed dashes streaming off them and embers spilling into
// the gap where the new wallpaper shows.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 resolution;
    float progress;     // 0..1
    float seed;         // 0..1, a new bolt each time
    vec4 cCore;
    vec4 cGlow;
    vec4 cEdge;
    vec4 cPaint;
    vec4 cRubber;
} u;
layout(binding = 1) uniform sampler2D source;
#include "../../lib/common.glsl"

const float TAU = 6.2831853;
const float STRIKE = 0.1;       // the bolt reaching the bottom
const float SPLIT = 0.16;       // the halves starting to move

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

float span(float x, float a, float b) { return clamp((x - a) / (b - a), 0.0, 1.0); }

// Signed distance to a star of n spikes, valleys at radius ri, each spike reaching an
// uneven radius from ro * 0.7 to ro.
float starDist(vec2 p, float n, float ri, float ro, float seed) {
    float a = atan(p.y, p.x) / TAU * n;
    float k = floor(a);
    float d = 1e3;
    float inside = 0.0;
    for (int j = -1; j <= 1; j++) {
        float c = k + float(j);
        float v0 = c * TAU / n, v1 = (c + 1.0) * TAU / n, vt = (c + 0.5) * TAU / n;
        float rt = ro * mix(0.7, 1.0, hash(vec2(mod(c, n), seed)));
        vec2 a0 = vec2(cos(v0), sin(v0)) * ri;
        vec2 a1 = vec2(cos(v1), sin(v1)) * ri;
        vec2 tip = vec2(cos(vt), sin(vt)) * rt;
        d = min(d, min(sdSeg(p, a0, tip), sdSeg(p, tip, a1)));
        if (j == 0) {
            vec2 e0 = tip - a0, e1 = a1 - tip;
            float s0 = e0.x * (p.y - a0.y) - e0.y * (p.x - a0.x);
            float s1 = e1.x * (p.y - tip.y) - e1.y * (p.x - tip.x);
            inside = (s0 > 0.0 && s1 > 0.0) || length(p) < ri ? 1.0 : 0.0;
        }
    }
    return inside > 0.5 ? -d : d;
}

void main() {
    vec2 p = qt_TexCoord0 * u.resolution;
    float t = u.progress;
    float W = u.resolution.x, H = u.resolution.y;
    float tx = tearX(p.y);
    float slope = tearX(p.y + 1.0) - tx;
    float norm = 1.0 / sqrt(1.0 + slope * slope);
    float s = span(t, SPLIT, 1.0);
    float gap = W * 0.72 * pow(s, 2.1);
    float heat = 1.0 - span(t, 0.3, 0.95);

    // Each half, sampled crisp: inked along its torn edge, and inside the ink a band
    // of heat that narrows and cools from white-hot to red.
    vec4 col = vec4(0.0);
    for (int side = 0; side < 2; side++) {
        float dir = side == 0 ? -1.0 : 1.0;
        vec2 src = p - vec2(dir * gap, 0.0);
        float own = (side == 0 ? tx - src.x : src.x - tx) * norm;   // px inside, < 0 past its edge
        if (own > -2.0) {
            vec4 half_ = texture(source, src / u.resolution) * cover(own);
            if (s > 0.0) {
                float ink = 2.5 * smoothstep(0.0, 0.05, s);
                float hw = ink + 9.0 * heat;
                vec3 hot = mix(u.cPaint.rgb, u.cEdge.rgb, band(heat, 0.35));
                hot = mix(hot, u.cGlow.rgb, band(heat, 0.6) * (1.0 - band(own, ink + 4.0 * heat)));
                hot = mix(hot, u.cCore.rgb, band(heat, 0.8) * (1.0 - band(own, ink + 1.5 * heat)));
                half_.rgb = mix(half_.rgb, hot * half_.a, cover(hw - own) * step(0.02, heat));
                half_.rgb = mix(half_.rgb, u.cRubber.rgb * half_.a, cover(ink - own));
            }
            col = half_ + col * (1.0 - half_.a);
        }
        // Speed dashes streaming off the edge, back the way it came.
        if (own < 0.0 && s > 0.0 && heat > 0.0) {
            float rowH = 22.0;
            float row = floor(p.y / rowH);
            vec3 h = vec3(hash(vec2(row, 7.0 + float(side))), hash(vec2(row, 9.0 + float(side))),
                          hash(vec2(row, 11.0 + float(side))));
            if (h.x < 0.22) {
                float back = -own;
                float len = (30.0 + gap * 0.18) * mix(0.4, 1.0, h.y) * heat;
                float w = mix(2.0, 4.0, h.z) * sqrt(heat);
                float cy = (row + 0.5) * rowH;
                float d = length(vec2(max(0.0, max(w + 6.0 - back, back - len)), p.y - cy)) - w;
                vec3 dc = h.z < 0.4 ? u.cGlow.rgb : h.z < 0.75 ? u.cEdge.rgb : u.cPaint.rgb;
                vec4 dsh = over(vec4(0.0), u.cRubber.rgb, cover(1.5 - d));
                dsh = over(dsh, dc, cover(-d));
                col = dsh * smoothstep(0.0, 0.3, heat) * (1.0 - col.a) + col;
            }
        }
    }

    // Embers spilling into the gap, carried apart and falling.
    // Embers stay within the gap's reach of the tear, so most pixels skip them.
    if (s > 0.0 && s < 0.95 && abs(p.x - tx) < gap + 0.3 * W) {
        for (int i = 0; i < 32; i++) {
            float fi = float(i);
            vec4 h = vec4(hash(vec2(fi, 1.0)), hash(vec2(fi, 2.0)), hash(vec2(fi, 3.0)), hash(vec2(fi, 4.0)));
            float y0 = h.x * H;
            float dir = h.y < 0.5 ? -1.0 : 1.0;
            float age = s * mix(0.8, 1.6, h.z);
            float ey = y0 + 260.0 * age * age - 60.0 * age;
            if (abs(p.y - ey) > 6.0)
                continue;
            vec2 ep = vec2(tearX(y0) + dir * gap * mix(0.2, 0.9, h.w), ey);
            float life = 1.0 - smoothstep(0.5, 1.0, age);
            float r = mix(2.0, 4.0, h.z) * life;
            float d = length(p - ep);
            vec3 ec = mix(u.cEdge.rgb, u.cGlow.rgb, h.w);
            col = mix(col, vec4(u.cRubber.rgb, 1.0), cover(r + 1.2 - d) * life);
            col = mix(col, vec4(ec, 1.0), cover(r - d) * life);
        }
    }

    // The flash the bolt throws.
    float flash = smoothstep(0.0, STRIKE, t) * (1.0 - smoothstep(STRIKE, 0.42, t));
    col.rgb += u.cCore.rgb * col.a * 0.45 * flash * flash;
    col.rgb = min(col.rgb, vec3(col.a));

    // A comic starburst where it lands, popping out and shrinking away.
    float kb = span(t, STRIKE * 0.85, 0.5);
    if (kb > 0.0 && kb < 1.0) {
        float pk = clamp(kb / 0.25, 0.0, 1.0);
        float sc = (1.0 + 2.7 * pow(pk - 1.0, 3.0) + 1.7 * pow(pk - 1.0, 2.0)) * (1.0 - smoothstep(0.5, 1.0, kb));
        float R = H * 0.3 * max(sc, 0.01);
        vec2 q = rot(p - vec2(tearX(H), H), 0.4 * kb);
        if (length(q) < R * 1.05) {
            float d0 = starDist(q, 12.0, R * 0.5, R, 1.0);
            float d1 = starDist(rot(q, 0.5 * TAU / 12.0), 12.0, R * 0.34, R * 0.7, 2.0);
            float d2 = starDist(q, 12.0, R * 0.18, R * 0.38, 3.0);
            vec4 b = over(vec4(0.0), u.cRubber.rgb, cover(3.0 - d0));
            b = over(b, u.cPaint.rgb, cover(-d0));
            b = over(b, u.cGlow.rgb, cover(-d1));
            b = over(b, u.cCore.rgb, cover(-d2));
            col = b + col * (1.0 - b.a);
        }
    }

    // The bolt, striking down, holding, and blinking out.
    float on = (1.0 - step(0.45, t)) * (step(t, 0.3) + step(0.5, fract((t - 0.3) / 0.15 * 2.0 + 0.25)));
    float tip = H * min(1.0, t / STRIKE);
    if (on > 0.0 && p.y < tip + 12.0) {
        float w = mix(13.0, 6.0, p.y / H) * (1.0 - 0.6 * s);
        float d = abs(p.x - tx) * norm - w;
        // Forks running off its corners, straight and pointed.
        for (int i = 0; i < 4; i++) {
            float fi = float(i);
            float y0 = H * (0.15 + 0.2 * fi + 0.05 * hash(vec2(fi, 5.0)));
            float len = H * (0.06 + 0.05 * hash(vec2(fi, 6.0)));
            float side = mod(fi, 2.0) * 2.0 - 1.0;
            vec2 a = vec2(tearX(y0), y0);
            vec2 m = a + vec2(side * len * 0.55, len * 0.5);
            vec2 b = m + vec2(-side * len * 0.15, len * 0.5);
            float f = clamp((p.y - a.y) / len, 0.0, 1.0);
            d = min(d, min(sdSeg(p, a, m), sdSeg(p, m, b)) - mix(3.5, 0.5, f));
        }
        d = max(d, p.y - tip);
        vec4 b = over(vec4(0.0), u.cEdge.rgb, cover(10.0 - d) * 0.3);
        b = over(b, u.cRubber.rgb, cover(3.0 - d));
        b = over(b, u.cGlow.rgb, cover(-d));
        b = over(b, u.cCore.rgb, cover(-d - 3.5));
        col = b * on + col * (1.0 - b.a * on);
    }

    fragColor = col * u.qt_Opacity;
}
