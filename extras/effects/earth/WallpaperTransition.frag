#version 440
#extension GL_GOOGLE_include_directive : enable
// Cracks race out from the center across the outgoing wallpaper; then, in a wave
// from the center outward, each shard darkens, shrinks, and drops away.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 resolution;
    vec2 center;
    float crackR;      // px, how far the cracks have spread
    float wave;        // px, how far the crumbling has spread
    vec4 cCrack;
    vec4 cLip;
} u;
layout(binding = 1) uniform sampler2D source;
#include "../../lib/common.glsl"

const float SIZE = 120.0;
const float JITTER = 0.9;

vec2 siteOf(vec2 cell) {
    return (cell + 0.5 + (hash2(cell) - 0.5) * JITTER) * SIZE;
}

// 0 standing .. 1 gone, for the shard around `site`.
float fallOf(vec2 site) {
    return clamp((u.wave - length(site - u.center) - 60.0 * hash(site)) / 260.0, 0.0, 1.0);
}

// The outgoing wallpaper at q on the shard around `site`, fallen by f and scaled by s.
vec4 shade(vec2 q, vec2 site, float f, float s) {
    float edge = voronoiEdge(q, SIZE, JITTER) * s;
    vec4 c = texture(source, q / u.resolution);
    // Cracked: a dark seam with a pale lip, once the crack front has passed.
    float cracked = step(length(q - u.center) + 40.0 * vnoise(q / 50.0), u.crackR);
    c.rgb = mix(c.rgb, u.cLip.rgb, cover(4.0 - edge) * cracked * 0.6);
    c.rgb = mix(c.rgb, u.cCrack.rgb, cover(1.6 - edge) * cracked);
    // Falling shards tilt away from the light: one flat shade darker.
    c.rgb *= mix(1.0, 0.62, step(0.02, f));
    return c * (1.0 - smoothstep(0.55, 1.0, f));
}

void main() {
    vec2 p = qt_TexCoord0 * u.resolution;
    vec2 own = voronoiSite(p, SIZE, JITTER);
    if (fallOf(own) <= 0.0) {
        // Still standing: the common case, one cell lookup.
        fragColor = shade(p, own, 0.0, 1.0) * u.qt_Opacity;
        return;
    }
    vec2 g = floor(p / SIZE);
    vec4 col = vec4(0.0);
    // Shards drop at most about one cell, so only cells beside and above can cover p.
    for (int y = -2; y <= 1; y++)
        for (int x = -1; x <= 1; x++) {
            vec2 site = siteOf(g + vec2(x, y));
            float f = fallOf(site);
            if (f <= 0.0 || f >= 1.0)
                continue;
            float s = 1.0 - 0.45 * f;
            vec2 q = site + (p - vec2(0.0, 110.0 * f * f) - site) / s;   // point on the shard at rest
            if (distance(voronoiSite(q, SIZE, JITTER), site) > 0.5)
                continue;
            col = shade(q, site, f, s);
        }
    fragColor = col * u.qt_Opacity;
}
