#version 440
#extension GL_GOOGLE_include_directive : enable
// Spiral galaxy: a tilted two-armed galaxy in Gruvbox golds and plums over a
// faint nebula and a field of stars, with a banded gas giant rising in the corner.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 resolution;
} u;
#include "../../effects/common/common.glsl"
#include "../landscape.glsl"

// A bright star with four rays.
float glint(vec2 q, vec2 c, float r) {
    vec2 d = abs(q - c);
    float core = cover(r - length(q - c));
    float rays = max(cover(r * 0.18 - d.y) * cover(r * 7.0 - d.x) * (1.0 - d.x / (r * 7.0)),
                     cover(r * 0.18 - d.x) * cover(r * 7.0 - d.y) * (1.0 - d.y / (r * 7.0)));
    return max(core, rays);
}

void main() {
    vec2 px = qt_TexCoord0 * u.resolution;
    vec2 q = vec2(px.x, u.resolution.y - px.y) / u.resolution.y;
    float aspect = u.resolution.x / u.resolution.y;

    // Deep space, slightly lighter toward the galaxy.
    vec2 gc = vec2(aspect * 0.6, 0.56);
    vec3 col = mix(rgb(22, 24, 25), rgb(40, 36, 38), exp(-length(q - gc) * 1.8));

    // A band of nebula sweeping through the galaxy, in flat steps of plum.
    float sweep = q.y - gc.y + (q.x - gc.x) * 0.42;
    float nebMask = exp(-sweep * sweep / 0.05);
    float neb = (fbm(q * vec2(1.6, 3.2) + vec2(3.0, 1.0)) + 0.35 * fbm(q * 6.0 - 2.0)) * nebMask;
    col = mix(col, rgb(44, 34, 42), band(neb, 0.36));
    col = mix(col, rgb(58, 40, 52), band(neb, 0.5));
    col = mix(col, rgb(74, 46, 62), band(neb, 0.64));

    // Stars, in three layers, never smaller than a pixel or so.
    float minR = 1.3 / u.resolution.y;
    float aa = 0.75 / u.resolution.y;
    float stars = max(starField(q, 0.011, 0.35, 1.0, 0.0011, minR, aa),
                      max(starField(q + 0.37, 0.023, 0.5, 7.0, 0.0017, minR, aa),
                          starField(q + 0.71, 0.06, 0.45, 13.0, 0.0026, minR, aa)));
    col = mix(col, rgb(235, 219, 178), stars);

    // The galaxy, tilted toward the viewer: two logarithmic arms around a bulge.
    vec2 g = rot(q - gc, -0.42);
    g.y /= 0.42;
    float r = length(g);
    float th = atan(g.y, g.x);
    // Broad, slow warps, so the arms' edges run clean rather than brushy.
    float warp = (fbm(g * 3.2) - 0.5) * 0.75 + (vnoise(g * 9.0) - 0.5) * 0.12;
    float arm = 0.5 + 0.5 * cos(2.0 * (th - log(max(r, 1e-3)) * 2.6) + warp);
    // The disc ends at its rim, so the outer arms taper off instead of trailing away.
    float disc = exp(-r / 0.3) * (1.0 - smoothstep(0.5, 0.9, r));
    float density = pow(arm, 1.4) * disc * 1.1 + 0.22 * exp(-r / 0.16) + exp(-r * r / 0.005) * 1.1;
    density *= 0.86 + 0.28 * fbm(g * 7.0);

    // Depth: a faint glow of the disc's old stars around the arms, in two dim steps.
    float halo = exp(-r / 0.2) * (1.0 - smoothstep(0.3, 0.62, r));
    col = mix(col, rgb(46, 36, 42), band(halo + 0.04 * fbm(g * 4.0), 0.2) * 0.8);
    col = mix(col, rgb(56, 40, 50), band(halo, 0.36) * 0.8);
    // Dust lanes trail just inside the arms.
    float lane = 0.5 + 0.5 * cos(2.0 * (th - log(max(r, 1e-3)) * 2.6) + warp + 0.9);
    density *= 1.0 - 0.55 * smoothstep(0.75, 1.0, lane) * smoothstep(0.03, 0.09, r);

    col = mix(col, rgb(98, 52, 72), band(density, 0.12) * 0.85);
    col = mix(col, rgb(177, 98, 134), band(density, 0.24));
    col = mix(col, rgb(214, 93, 14), band(density, 0.4));
    col = mix(col, rgb(254, 128, 25), band(density, 0.56));
    col = mix(col, rgb(250, 189, 47), band(density, 0.75));
    col = mix(col, rgb(251, 241, 199), band(density, 0.98));
    // Star clusters sparkle along the arms.
    float clusters = starField(g * vec2(1.0, 0.42) + 0.13, 0.012, 0.6, 21.0, 0.0016, minR, aa) * band(density, 0.2);
    col = mix(col, rgb(251, 241, 199), clusters);

    // A few bright stars.
    for (int i = 0; i < 9; i++) {
        vec2 h = hash2(vec2(float(i), 31.0));
        vec2 c = vec2(h.x * aspect, 0.15 + 0.8 * h.y);
        if (length(c - gc) < 0.3)
            c.x = mod(c.x + aspect * 0.45, aspect);
        float rr = mix(0.0024, 0.0042, hash(vec2(float(i), 5.0)));
        col = mix(col, rgb(250, 189, 47), glint(q, c, rr * 1.6) * 0.35);
        col = mix(col, rgb(251, 241, 199), glint(q, c, rr));
    }

    // A banded gas giant rising in the lower left, lit from the galaxy.
    vec2 pc = vec2(aspect * 0.08, -0.36);
    float pr = 0.5;
    vec2 pq = q - pc;
    float pd = length(pq);
    if (pd < pr + 0.01) {
        float cy = rot(pq, 0.18).y / pr;
        float bands = vnoise(vec2(cy * 9.0, 2.0)) + 0.3 * vnoise(vec2(cy * 26.0 + pq.x * 2.0, 5.0));
        vec3 body = mix(rgb(60, 56, 54), rgb(80, 73, 69), band(bands, 0.62));
        body = mix(body, rgb(102, 92, 84), band(bands, 0.88));
        vec2 light = normalize(gc - pc);
        float lit = dot(pq / pr, light);
        body = mix(rgb(29, 32, 33), body, band(lit, 0.42));
        // The lit limb: a warm crescent.
        body = mix(body, rgb(214, 93, 14), band(lit, 0.72) * band(pd / pr, 0.94));
        body = mix(body, rgb(250, 189, 47), band(lit, 0.82) * band(pd / pr, 0.975));
        col = mix(col, body, cover(pr - pd));
    }
    // Faint haze around the planet.
    col = mix(col, rgb(214, 93, 14), exp(-max(pd - pr, 0.0) / 0.012) * 0.25 * cover(pd - pr)
        * smoothstep(0.2, 0.8, dot(normalize(pq), normalize(gc - pc))));

    fragColor = vec4(col, 1.0);
}
