#version 440
#extension GL_GOOGLE_include_directive : enable
// Earth backdrop, drawn once over a surface's base color: a cut through
// layered rock. Strata of slightly different stone tilt and buckle across the panel,
// a few layers are cracked into blocks, pebbles lie scattered, and two small, faint
// clusters of jade crystal grow out of the walls near the bottom, cel-shaded by facet. It stays a few percent off the
// base so text reads.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;
    vec4 cBase;
    vec4 cDeep;
    vec4 cText;
    vec4 cAccent;
} u;
#include "../../lib/common.glsl"

// One crystal: a hexagonal prism seen side-on, growing from `root` along `dir` for
// `len` px, `w` px wide. Returns (coverage, facet shade 0..1).
vec2 crystal(vec2 p, vec2 root, vec2 dir, float len, float w) {
    vec2 rel = p - root;
    float y = dot(rel, dir);
    float x = dot(rel, vec2(-dir.y, dir.x));
    float tip = len - w * 1.1;
    float sd = max(abs(x) - w, max(-y, y - (len - abs(x) * 1.1)));
    float cover1 = cover(-sd);
    // Three faces: a lit one, a narrow middle one, a shaded one; the tip facets
    // catch more light than the sides.
    float face = x < -w * 0.25 ? 1.0 : (x < w * 0.3 ? 0.6 : 0.25);
    face = y > tip - abs(x) * 0.0 && y > len - w * 1.1 - abs(x) * 0.2 ? min(1.0, face + 0.35) : face;
    return vec2(cover1, face);
}

void main() {
    vec2 p = qt_TexCoord0 * u.size;
    float H = u.size.y;

    // Strata: layers follow a buckled, tilted height field; each takes its own shade.
    float tilt = p.y - 0.12 * p.x - 22.0 * sin(p.x / 150.0 + 1.0) - 14.0 * fbm(p / vec2(140.0, 60.0));
    // Thickness varies layer to layer; the noise term stays monotonic in tilt.
    float layer = tilt / 44.0 + 0.55 * vnoise(vec2(tilt / 110.0, 0.5)) + 0.25 * vnoise(vec2(tilt / 37.0, 3.5));
    float id = floor(layer);
    float f = fract(layer);
    float shade = hash(vec2(id, 3.0));
    vec3 col = mix(u.cBase.rgb, shade > 0.5 ? u.cText.rgb : u.cDeep.rgb, abs(shade - 0.5) * 0.07);
    // Seams between layers, and grain within them.
    float seamW = fwidth(layer);
    col = mix(col, u.cDeep.rgb, 0.35 * (1.0 - smoothstep(0.0, 1.5 * seamW, min(f, 1.0 - f))));
    col = mix(col, u.cDeep.rgb, 0.10 * band(fbm(vec2(p.x / 9.0, layer * 5.0)), 0.62));

    // Some layers are cracked into blocks.
    if (hash(vec2(id, 7.0)) < 0.35) {
        float e = voronoiEdge(p * vec2(1.0, 1.8), 40.0, 0.8);
        col = mix(col, u.cDeep.rgb, 0.3 * (1.0 - smoothstep(0.3, 1.2, e)));
    }

    // Pebbles: rounded, flat-lit stones with a dark lower rim.
    vec2 cell = floor(p / 36.0);
    if (hash(cell + 4.0) < 0.10) {
        vec2 c = (cell + 0.25 + 0.5 * hash2(cell)) * 36.0;
        float r = 2.0 + 3.0 * hash(cell + 1.0);
        vec2 v = (p - c) / vec2(1.0 + 0.5 * hash(cell + 2.0), 1.0);
        float body = cover(r - length(v));
        float lower = step(0.0, v.y + v.x * 0.3);
        col = mix(col, mix(u.cText.rgb, u.cDeep.rgb, 0.4 + 0.5 * lower), body * 0.16);
    }

    // Jade: two small clusters growing out of the walls near the bottom, where a
    // tall panel runs out of content, faint enough to stay with the rock.
    vec3 jade = u.cAccent.rgb;
    for (int i = 0; i < 7; i++) {
        float fi = float(i);
        bool right = i < 4;
        vec2 base = right ? vec2(u.size.x - 6.0, H - 34.0) : vec2(6.0, H - 70.0);
        float a = (right ? -2.45 : -0.75) + (hash(vec2(fi, 1.0)) - 0.5) * 1.0;
        vec2 dir = vec2(cos(a), sin(a));
        vec2 root = base + vec2(0.0, (hash(vec2(fi, 3.0)) - 0.5) * 30.0);
        float len = 14.0 + 20.0 * hash(vec2(fi, 4.0));
        float w = len * (0.17 + 0.05 * hash(vec2(fi, 5.0)));
        vec2 c = crystal(p, root, dir, len, w);
        vec3 facet = mix(u.cDeep.rgb, mix(jade, u.cText.rgb, 0.2 * c.y), 0.35 + 0.65 * c.y);
        col = mix(col, facet, c.x * 0.13);
    }

    fragColor = vec4(col, 1.0) * u.qt_Opacity;
}
