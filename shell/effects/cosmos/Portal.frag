#version 440
#extension GL_GOOGLE_include_directive : enable
// Draws a captured item through a circular portal of radius `circle` around `origin`:
// inside it (or outside, with `outside` set) the item shows, bent near the edge
// like light around a lens, behind a white-hot ring with a warm glow and a faint
// violet haze. With `debris`, as for a supernova, the front runs thick and thin in
// filaments, flings streaks of ejecta ahead of it, and leaves sparks in its wake.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 rect;          // this item's rect on screen (px)
    vec2 origin;
    float circle;       // portal radius (px)
    float outside;      // 1: show the item outside the circle instead of inside
    float lens;         // px the edge bends the item by
    float ringWidth;    // ring scale
    float ring;         // 0..1 ring brightness
    float debris;       // 0..1 filaments, ejecta, and sparks
    vec4 cHot;
    vec4 cGlow;
    vec4 cHaze;
} u;
layout(binding = 1) uniform sampler2D source;
#include "../common/common.glsl"

void main() {
    vec2 p = u.rect.xy + qt_TexCoord0 * u.rect.zw;
    vec2 rel = p - u.origin;
    float d = length(rel);
    vec2 dir = rel / max(d, 1.0);
    // A faint wobble keeps the edge from reading as a ruled circle.
    float edge = u.circle + (vnoise(dir * 5.0 + u.circle / 40.0) - 0.5) * 3.0 * u.ringWidth;
    float s = u.outside > 0.5 ? d - edge : edge - d;     // > 0 shown

    // Near the edge, sample from closer to it, so the item stretches along the rim.
    float bend = u.lens * exp(-max(s, 0.0) / max(u.lens * 2.5, 1.0));
    vec2 sp = p + dir * bend * (u.outside > 0.5 ? -1.0 : 1.0);
    vec4 content = texture(source, clamp((sp - u.rect.xy) / u.rect.zw, 0.0, 1.0));
    float shape = texture(source, qt_TexCoord0).a;

    float w = u.ringWidth;
    // Filaments: the front thickens and thins along its length, drifting as it grows.
    float fil = 0.65 * vnoise(dir * 7.0 + vec2(u.circle / 170.0, 0.0))
              + 0.35 * vnoise(dir * 19.0 - vec2(0.0, u.circle / 90.0));
    float thick = mix(1.0, 0.3 + 1.4 * fil, u.debris);
    float hot = 1.0 - smoothstep(0.6 * w * thick, 2.4 * w * thick, abs(s));
    float glow = exp(-abs(s) / (8.0 * w * mix(1.0, 0.7 + 0.6 * fil, u.debris)));
    float haze = exp(-max(-s, 0.0) / (26.0 * w)) * (1.0 - smoothstep(0.0, 3.0 * w, s));
    // The haze reaches further than the item's edge would cut it: fade it out there,
    // or a launcher portal still smaller than its panel shows the panel's rectangle.
    vec2 inset = min(qt_TexCoord0, 1.0 - qt_TexCoord0) * u.rect.zw;
    haze *= smoothstep(0.0, 28.0 * w, min(inset.x, inset.y));
    vec4 rim = vec4(u.cHaze.rgb, 1.0) * haze * 0.35;
    rim = vec4(u.cGlow.rgb, 1.0) * glow * 0.9 + rim * (1.0 - glow * 0.9);
    rim = vec4(u.cHot.rgb, 1.0) * hot + rim * (1.0 - hot);
    rim *= u.ring * shape;

    vec4 shown = content * cover(s);
    vec4 o = rim + shown * (1.0 - rim.a);

    if (u.debris > 0.0 && u.circle > 60.0) {
        float a = atan(rel.y, rel.x) / 6.2831853 + 0.5;
        float out_ = d - edge;              // px ahead of the front
        // Ejecta: a comet in some of 64 sectors, flying ahead of the front, its round,
        // white-hot head leading and its tail tapering to a point and fading back
        // toward the front.
        float cell = floor(a * 64.0);
        vec3 h = vec3(hash(vec2(cell, 3.1)), hash(vec2(cell, 7.7)), hash(vec2(cell, 1.9)));
        if (h.x > 0.62) {
            float ca = (cell + 0.5 + (h.y - 0.5) * 0.5) / 64.0;
            float across = abs(fract(a - ca + 0.5) - 0.5) * 6.2831853 * d;
            float off = (0.01 + 0.05 * h.z) * u.circle;
            float len = (0.02 + 0.09 * fract(h.x * 7.31) * fract(h.z * 3.7)) * u.circle;
            float along = out_ - off;           // px from its tail
            float t = clamp(along / len, 0.0, 1.0);
            float half_ = (0.35 + 0.55 * h.y) * w * pow(t, 1.4);
            float dist = length(vec2(across, max(along - len, 0.0)));
            float streak = cover(half_ - dist) * cover(along) * mix(0.2, 1.0, t);
            vec3 col = mix(u.cGlow.rgb, u.cHot.rgb, band(along - len + 1.5 * half_, 0.0));
            o = over(o, col, streak * u.ring * u.debris * shape);
        }
        // Sparks the front leaves behind: still points that flash as it passes and fade.
        float rc = floor(d / 22.0);
        float sc = floor(a * 160.0);
        vec2 hs = hash2(vec2(sc, rc));
        if (hs.x > 0.86 && d < edge) {
            float sa = (sc + 0.5 + (hs.y - 0.5) * 0.6) / 160.0 * 6.2831853 - 3.1415927;
            vec2 sp2 = u.origin + vec2(cos(sa), sin(sa)) * (rc + 0.5 + (hs.x - 0.93) * 4.0) * 22.0;
            vec2 sq = abs(p - sp2);
            float life = exp(-(edge - d) / (70.0 * w)) * u.ring * u.debris;
            float r = (0.9 + 1.2 * fract(hs.y * 5.7)) * life;
            float spark = cover(r - length(sq)) + 0.6 * cover(0.5 - min(sq.x, sq.y)) * cover(r * 3.0 - max(sq.x, sq.y));
            o = over(o, mix(u.cHot.rgb, u.cGlow.rgb, 0.3 * fract(hs.x * 11.0)), clamp(spark, 0.0, 1.0) * life);
        }
    }
    fragColor = o * u.qt_Opacity;
}
