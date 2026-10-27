#version 440
#extension GL_GOOGLE_include_directive : enable
// Water backdrop, drawn once over a surface's base color: the panel seen
// from under water. A rippled surface glints at the top, caustics net the light below
// it and fade with depth, shafts of light slant down, the water deepens toward the
// bottom, and strings of bubbles rise. It stays a few percent off the base so text
// reads.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;
    vec4 cBase;
    vec4 cDeep;
    vec4 cText;
    vec4 cLight;
} u;
#include "../common/common.glsl"

void main() {
    vec2 p = qt_TexCoord0 * u.size;
    float H = u.size.y;
    float depth = p.y / H;

    // Deeper water darkens in two soft steps.
    vec3 col = mix(u.cBase.rgb, u.cDeep.rgb, smoothstep(0.35, 1.0, depth) * 0.6);

    // Shafts of light slanting down from the surface, fading with depth.
    float slant = p.x + 0.35 * p.y;
    float shafts = vnoise(vec2(slant / 38.0, 1.0)) * vnoise(vec2(slant / 13.0, 4.0));
    float reach = 1.0 - smoothstep(0.0, 0.75, depth);
    col = mix(col, u.cLight.rgb, 0.05 * band(shafts, 0.32) * reach + 0.035 * band(shafts, 0.5) * reach);

    // Caustics: the bright net of light focused by the surface, stretched as it sinks.
    // Two nets of different sizes overlap; their lines thin out and break where the
    // light is weaker, so no regular mesh shows.
    vec2 warp = vec2(fbm(p / 50.0), fbm(p / 50.0 + 4.0)) * 40.0;
    vec2 cp = (p + warp) * vec2(1.0, 1.0 + 0.8 * depth);
    float edge = min(voronoiEdge(cp, 52.0, 1.0), voronoiEdge(cp * 1.37 + 31.0, 52.0, 1.0) + 0.5);
    float light = smoothstep(0.35, 0.75, fbm(p / 80.0 + 2.0));
    float net = 1.0 - smoothstep(0.2, 0.9 + 2.0 * light, edge);
    float caustic = net * light * (1.0 - smoothstep(0.0, 0.38, depth));
    col = mix(col, mix(u.cLight.rgb, u.cText.rgb, 0.3), 0.085 * caustic);

    // The surface: a band of ripples catching the light along the very top.
    float surf = 14.0 + 5.0 * sin(p.x / 23.0) + 3.0 * sin(p.x / 9.0 + 1.3);
    col = mix(col, u.cLight.rgb, 0.07 * (1.0 - smoothstep(surf - 1.0, surf + 1.0, p.y)));
    col = mix(col, u.cText.rgb, 0.12 * cover(1.0 - abs(p.y - surf)));

    // Bubbles: a few columns, each a wobbling string of rings, smaller as they rise.
    // Slots along the string are spaced unevenly, and some stay empty.
    for (int i = 0; i < 3; i++) {
        float fi = float(i);
        float x0 = u.size.x * (0.2 + 0.65 * hash(vec2(fi, 1.0)));
        float start = H * (0.6 + 0.3 * hash(vec2(fi, 2.0)));
        float gap = 30.0 + 16.0 * hash(vec2(fi, 3.0));
        float k = floor((start - p.y) / gap);
        if (k < 0.0 || k > 12.0)
            continue;
        for (int j = 0; j < 2; j++) {
            float kk = k + float(j) - 0.5 + 0.5 * sign(fract((start - p.y) / gap) - 0.5);
            if (hash(vec2(fi + 2.0, kk)) < 0.3)
                continue;
            float by = start - (kk + 0.5) * gap + 0.6 * gap * (hash(vec2(fi, kk)) - 0.5);
            float bx = x0 + 10.0 * sin(by / 37.0 + fi * 2.0) + 6.0 * (hash(vec2(kk, fi)) - 0.5);
            float r = mix(4.2, 1.3, kk / 12.0) * (0.6 + 0.8 * hash(vec2(fi + 5.0, kk)));
            vec2 v = p - vec2(bx, by);
            float ring = cover(0.75 - abs(length(v) - r));
            float shine = cover(r * 0.35 - length(v - vec2(-0.35, -0.35) * r));
            col = mix(col, mix(u.cLight.rgb, u.cText.rgb, 0.4), 0.2 * max(ring, shine) * (1.0 - kk / 16.0));
        }
    }

    fragColor = vec4(col, 1.0) * u.qt_Opacity;
}
