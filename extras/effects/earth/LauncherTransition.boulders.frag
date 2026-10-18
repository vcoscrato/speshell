#version 440
#extension GL_GOOGLE_include_directive : enable
// Rocks held aloft around the open launcher: faceted boulders that rise out of the
// ground one after another, bob and tumble slowly while the launcher is open, and
// drop back when it closes. Each is a convex polygon with a lit top face and sides
// in flat tones by facing; pebbles circle the bigger ones. Behind them a ring of
// small stones circles far out, and dust motes rise past in front.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
    vec4 rect;         // this item's rect on screen (px)
    vec4 panel;        // panel rect on screen (px)
    float ground;      // px, screen y of the ground line
    float lift;        // 0..1 entrance: rocks rise in turn
    float fall;        // 0..1 exit: rocks drop in turn
    vec4 cLight;
    vec4 cMid;
    vec4 cDark;
    vec4 cEdge;
} u;
#include "../../lib/common.glsl"

const int ROCKS = 7;
const int SIDES = 7;
// Rest position as a fraction of the panel plus a px offset (xy, zw), and the size
// (px). Older GLSL targets have no constant arrays.
vec4 place(int i, out float size) {
    if (i == 0) { size = 26.0; return vec4(0.0, 0.36, -54.0, 0.0); }
    if (i == 1) { size = 12.0; return vec4(0.0, 0.8, -32.0, 0.0); }
    if (i == 2) { size = 16.0; return vec4(0.14, 0.0, 0.0, -40.0); }
    if (i == 3) { size = 30.0; return vec4(0.8, 0.0, 0.0, -58.0); }
    if (i == 4) { size = 22.0; return vec4(1.0, 0.58, 50.0, 0.0); }
    if (i == 5) { size = 10.0; return vec4(1.0, 0.16, 28.0, 0.0); }
    size = 8.0;
    return vec4(0.5, 0.0, 0.0, -26.0);
}

float backOut(float x) {
    float c = 1.7;
    return 1.0 + (c + 1.0) * pow(x - 1.0, 3.0) + c * pow(x - 1.0, 2.0);
}

mat2 rot(float a) {
    float cs = cos(a), sn = sin(a);
    return mat2(cs, sn, -sn, cs);
}

// Premultiplied "over" of a flat color with coverage k.
void over(inout vec3 col, inout float a, vec3 c, float k) {
    col = mix(col, c, k);
    a = mix(a, 1.0, k);
}

// A small five-sided chip at `lp` (its own frame): signed distance, < 0 inside.
float chip(vec2 lp, float size, float seed) {
    float d = -1e3;
    for (int k = 0; k < 5; k++) {
        float fk = float(k);
        float th = (fk + 0.4 * hash(vec2(seed, fk))) * 1.2566371;
        d = max(d, dot(lp, vec2(cos(th), sin(th))) - size * (0.8 + 0.35 * hash(vec2(fk, seed))));
    }
    return d;
}

// Draws a chip at `pos`, tumbling at `ang`, lit from `light`, in the given tones.
void drawChip(inout vec3 col, inout float a, vec2 p, vec2 pos, float size, float ang, float seed,
              vec2 light, vec3 lit, vec3 shade, float alpha) {
    vec2 o = p - pos;
    if (dot(o, o) > size * size * 2.5)
        return;
    vec2 lp = rot(ang) * o;
    float d = chip(lp, size, seed);
    // Top-lit: the half facing the light is the light tone.
    vec3 c = mix(shade, lit, cover(dot(o, -light) / max(size, 1.0) + 0.1));
    vec3 withEdge = mix(u.cEdge.rgb, c, cover(-d - 1.0));
    over(col, a, withEdge, cover(-d + 0.6) * alpha);
}

const int FAR = 14;
const int MOTES = 26;

void main() {
    vec2 p = u.rect.xy + qt_TexCoord0 * u.rect.zw;
    vec2 c0 = u.panel.xy + u.panel.zw * 0.5;
    vec2 h = u.panel.zw * 0.5;
    vec3 col = vec3(0.0);
    float a = 0.0;
    vec2 light = normalize(vec2(-0.45, -1.0));
    float hold = clamp(u.lift * 1.4, 0.0, 1.0) * (1.0 - u.fall);

    // ── Dust drifts: broad faint bands of dust circling far out, ragged at the edges ──
    for (int j = 0; j < 2; j++) {
        float fj = float(j);
        float dist = 95.0 + 70.0 * fj;
        vec2 hh = h + dist;
        float rr = min(10.0 + dist * 1.8, min(hh.x, hh.y));
        vec2 rel = p - c0;
        float d = sdRoundRect(rel, hh, rr);
        if (abs(d) > 80.0)
            continue;
        float P = rrPerimeter(hh, rr);
        float s = rrArc(rel, hh, rr);
        float behind = mod(-u.time * (26.0 - 8.0 * fj) + fj * P * 0.5 - s, P);
        float len = P * 0.42 * hold;
        if (behind > len)
            continue;
        float tt = behind / max(len, 1.0);
        // Both fit the lap, so the ribbon meets itself where s wraps: whole waves,
        // and the noise cross-fading into its own start over the last stretch.
        float laps = max(1.0, floor(P / 1070.0 + 0.5));
        float wave = 22.0 * sin(6.2831853 * laps * s / P - u.time * 0.4 + fj * 2.4);
        vec2 rq = vec2(s / 40.0 + u.time * 0.3, d / 18.0 + fj * 5.0);
        float rag = (mix(fbm(rq), fbm(rq - vec2(P / 40.0, 0.0)), smoothstep(P - 160.0, P, s)) - 0.5) * 22.0;
        float w = (16.0 + 8.0 * fj) * pow(sin(3.14159265 * tt), 0.7);
        float f = w + rag - abs(d - wave);
        over(col, a, u.cLight.rgb, cover(f) * (0.11 - 0.03 * fj));
    }

    // ── Far layer: small dark stones circling slowly well behind the boulders ──
    for (int i = 0; i < FAR; i++) {
        float fi = float(i);
        vec3 r = vec3(hash(vec2(fi, 31.1)), hash(vec2(fi, 32.7)), hash(vec2(fi, 35.3)));
        float dist = mix(70.0, 200.0, r.x);
        vec2 hh = h + dist;
        float rr = min(10.0 + dist * 1.8, min(hh.x, hh.y));
        float P = rrPerimeter(hh, rr);
        vec2 pos = c0 + rrPoint(r.y * P - u.time * mix(9.0, 20.0, r.z), hh, rr);
        pos.y += 5.0 * sin(u.time * 1.1 + fi * 1.7);
        float appear = smoothstep(0.0, 1.0, clamp(u.lift * 1.8 - 0.05 * fi, 0.0, 1.0));
        float drop = clamp(u.fall * 1.6 - 0.05 * fi, 0.0, 1.0);
        pos.y += drop * drop * 260.0;
        float size = mix(3.5, 8.0, r.z * r.z) * appear * (1.0 - drop);
        if (size <= 0.0)
            continue;
        drawChip(col, a, p, pos, size, u.time * mix(-1.2, 1.2, r.x) + fi, fi + 40.0, light,
                 mix(u.cMid.rgb, u.cDark.rgb, 0.35), mix(u.cDark.rgb, u.cEdge.rgb, 0.3), mix(0.55, 0.85, r.z));
    }

    // ── Boulders, each with pebbles circling it ──
    for (int i = 0; i < ROCKS; i++) {
        float fi = float(i);
        float size;
        vec4 pl = place(i, size);
        vec2 rest = u.panel.xy + u.panel.zw * pl.xy + pl.zw;
        float seed = hash(vec2(fi, 7.7)) * 6.2831853;
        rest.y += 7.0 * sin(u.time * 1.7 + seed) * (size / 26.0 + 0.4);
        rest.x += 4.0 * sin(u.time * 0.55 + seed * 2.0);
        float rise = backOut(clamp(u.lift * 1.6 - 0.1 * fi, 0.0, 1.0));
        float drop = clamp(u.fall * 1.5 - 0.08 * fi, 0.0, 1.0);
        vec2 from = vec2(rest.x, u.ground + size * 1.3);
        vec2 pos = mix(from, rest, rise);
        pos.y += drop * drop * (u.ground + size * 1.3 - rest.y);
        vec2 rel = p - pos;
        float above = smoothstep(0.75, -0.75, p.y - u.ground);

        // Pebbles on tilted orbits: drawn behind the boulder on the far side of
        // their orbit and in front of it on the near side.
        int moons = size > 20.0 ? 2 : (size > 13.0 ? 1 : 0);
        vec2 moonPos[2];
        float moonNear[2];
        for (int m = 0; m < 2; m++) {
            float fm = float(m);
            float th = u.time * (1.3 - 0.35 * fm) * (mod(fi, 2.0) < 1.0 ? 1.0 : -1.0) + seed + fm * 2.6;
            float orbitR = size * (1.65 + 0.45 * fm);
            moonPos[m] = pos + rot(0.35 * (fm - 0.5) + 0.2 * sin(seed)) * vec2(cos(th), 0.38 * sin(th)) * orbitR;
            moonNear[m] = sin(th);
        }
        for (int m = 0; m < 2; m++) {
            if (m < moons && moonNear[m] < 0.0)
                drawChip(col, a, p, moonPos[m], mix(4.2, 3.2, float(m)) * rise * (1.0 - drop), u.time * 2.0 + float(m),
                         fi * 3.0 + float(m), light, u.cMid.rgb, u.cDark.rgb, above);
        }

        // Grit trickling from under the bigger rocks while they hover.
        if (size > 13.0 && rise >= 1.0 && drop <= 0.0 && abs(rel.x) < size && rel.y > 0.0 && rel.y < size + 50.0) {
            for (int j = 0; j < 3; j++) {
                float fj = float(j);
                float age = fract(u.time / 1.7 + fj / 3.0 + seed);
                float cycle = floor(u.time / 1.7 + fj / 3.0 + seed);
                vec2 g = vec2((hash(vec2(fi + fj, cycle)) - 0.5) * size, size * 0.6 + 50.0 * age * age);
                float gs = mix(3.2, 1.6, age);
                float grain = cover(gs - max(abs(rel.x - g.x), abs(rel.y - g.y))) * (1.0 - age * age);
                over(col, a, u.cLight.rgb, grain);
            }
        }

        if (dot(rel, rel) <= size * size * 2.6) {
            // Tumbles slowly, so its lit faces change as it turns.
            float spin = (hash(vec2(fi, 2.3)) - 0.5) * 0.9;
            float ang = seed + u.time * spin + 0.14 * sin(u.time * 0.8 + seed * 1.3);
            mat2 R = rot(ang);
            vec2 lp = R * rel;
            // Convex polygon: the furthest of SIDES jittered half-planes, and the facet it belongs to.
            float d = -1e3;
            vec2 facet = vec2(0.0);
            float dTop = -1e3;
            for (int k = 0; k < SIDES; k++) {
                float fk = float(k);
                float th = (fk + 0.35 * hash(vec2(fi, fk))) * 6.2831853 / float(SIDES);
                vec2 nrm = vec2(cos(th), sin(th));
                float reach = size * (0.82 + 0.3 * hash(vec2(fk, fi + 3.0)));
                float dk = dot(lp, nrm) - reach;
                if (dk > d) { d = dk; facet = nrm; }
                // The top face: the same polygon, shrunk and nudged toward the light.
                dTop = max(dTop, dot(lp - R * light * size * 0.22, nrm) - reach * 0.55);
            }
            vec2 worldN = transpose(R) * facet;
            float lit = dot(worldN, light);
            vec3 rock = lit > 0.35 ? u.cMid.rgb : (lit > -0.4 ? mix(u.cMid.rgb, u.cDark.rgb, 0.5) : u.cDark.rgb);
            rock = mix(rock, u.cLight.rgb, cover(-dTop));
            // A jagged crack across the bigger rocks.
            if (size > 15.0) {
                float along = dot(lp, vec2(-0.6, 0.8));
                float zig = (abs(fract(along / 9.0 + fi * 0.37) - 0.5) - 0.25) * 6.0;
                float crack = abs(dot(lp, vec2(0.8, 0.6)) - size * 0.1 + zig);
                rock = mix(rock, u.cDark.rgb, cover(0.9 - crack) * cover(-d - 3.0) * step(along, size * 0.3));
            }
            vec3 c = mix(u.cEdge.rgb, rock, cover(-d));
            over(col, a, c, cover(-d + 1.6) * above);
        }

        for (int m = 0; m < 2; m++) {
            if (m < moons && moonNear[m] >= 0.0)
                drawChip(col, a, p, moonPos[m], mix(4.2, 3.2, float(m)) * rise * (1.0 - drop), u.time * 2.0 + float(m),
                         fi * 3.0 + float(m), light, u.cLight.rgb, u.cMid.rgb, above);
        }
    }

    // ── Dust motes rising past the launcher, in front ──
    float spreadX = u.panel.z + 360.0;
    for (int i = 0; i < MOTES; i++) {
        float fi = float(i);
        vec3 r = vec3(hash(vec2(fi, 51.3)), hash(vec2(fi, 52.9)), hash(vec2(fi, 54.1)));
        float life = mix(3.5, 6.5, r.z);
        float age = fract(u.time / life + r.y);
        float x = u.panel.x - 180.0 + r.x * spreadX + 14.0 * sin(u.time * (0.6 + r.z) + fi);
        float y = u.ground + 40.0 - age * (u.panel.w + 200.0) * mix(0.6, 1.0, r.z);
        float size = mix(1.5, 3.2, r.y);
        float fade = smoothstep(0.0, 0.15, age) * smoothstep(1.0, 0.7, age);
        vec2 o = rot(u.time * 1.5 + fi) * (p - vec2(x, y));
        float k = cover(size - max(abs(o.x), abs(o.y))) * fade * 0.8 * hold;
        over(col, a, u.cLight.rgb, k);
    }

    // Nothing over the panel itself.
    float off = cover(sdRoundRect(p - c0, h, 10.0) - 2.0);
    fragColor = vec4(col, a) * off * u.qt_Opacity;
}
