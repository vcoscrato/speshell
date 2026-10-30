#version 440
#extension GL_GOOGLE_include_directive : enable
// Earth backdrop, drawn once over a surface's base color: a cut through
// layered rock. Strata of slightly different stone tilt and buckle across the panel,
// a few layers are cracked into blocks, and pebbles of every shape lie scattered. It
// stays a few percent off the base so text reads.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;
    vec4 cBase;
    vec4 cDeep;
    vec4 cText;
} u;
#include "../common/common.glsl"

// The edge distance of the pebble in `cell`, at c and about r across: a lopsided round,
// squashed and turned its own way, and in some cells chipped flat on a side or two.
float pebble(vec2 p, vec2 c, float r, vec2 cell) {
    vec2 q = rot(p - c, hash(cell + 5.0) * 3.1415927);
    q.x /= 1.0 + 0.5 * hash(cell + 2.0);
    float a = atan(q.y, q.x);
    float d = length(q) - r * (1.0 + 0.16 * sin(2.0 * a + 6.3 * hash(cell + 6.0)) + 0.08 * sin(3.0 * a + 6.3 * hash(cell + 7.0)));
    float chip = hash(cell + 8.0);
    if (chip < 0.4) {
        float b = 6.2831853 * hash(cell + 9.0);
        d = max(d, dot(q, vec2(cos(b), sin(b))) - r * 0.5);
        if (chip < 0.15)
            d = max(d, dot(q, vec2(cos(b + 2.2), sin(b + 2.2))) - r * 0.6);
    }
    return d;
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

    // Pebbles, each its own size, shape, and stone: lit along the edge toward the
    // light at the top left, in shade along the far one.
    vec2 cell = floor(p / 36.0);
    if (hash(cell + 4.0) < 0.10) {
        vec2 c = (cell + 0.3 + 0.4 * hash2(cell)) * 36.0;
        float r = 1.8 + 3.2 * pow(hash(cell + 1.0), 1.5);
        vec2 toLight = vec2(-0.55, -0.83) * r * 0.4;
        float body = cover(-pebble(p, c, r, cell));
        float lit = 1.0 - cover(-pebble(p + toLight, c, r, cell));
        float dark = 1.0 - cover(-pebble(p - toLight, c, r, cell));
        float tone = hash(cell + 3.0);
        vec3 stone = mix(u.cText.rgb, u.cDeep.rgb, 0.3 + 0.4 * tone);
        stone = mix(stone, u.cDeep.rgb, 0.6 * dark);
        stone = mix(stone, u.cText.rgb, 0.5 * lit * (1.0 - dark));
        col = mix(col, stone, body * mix(0.12, 0.2, hash(cell + 10.0)));
    }

    fragColor = vec4(col, 1.0) * u.qt_Opacity;
}
