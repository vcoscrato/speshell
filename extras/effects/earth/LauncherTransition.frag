#version 440
#extension GL_GOOGLE_include_directive : enable
// The captured panel as a stone slab pushed up out of the ground. Only the part
// above the ground line shows. The slab is one cut stone: faint strata, a bevel lit
// from the top left, a groove carved round its face, and chipped edges. Landing
// cracks it from the bottom middle out; then its shell crumbles off in chunks, top
// first, each dropping, turning, and shrinking away with crumbs falling from it, to
// leave the panel. Run backwards, the chunks fly back into place before it sinks.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 rect;         // this item's rect on screen (px)
    vec4 panel;        // panel rect at rest (px)
    float radius;
    float ground;      // px, screen y of the ground line
    vec2 offset;       // px, slab displacement from rest
    float cracks;      // 0..1 cracks spreading from the bottom middle
    float crumble;     // 0 whole .. 1 every chunk gone
    vec4 cLight;
    vec4 cMid;
    vec4 cDark;
    vec4 cEdge;
} u;
layout(binding = 1) uniform sampler2D source;
#include "../../lib/common.glsl"

const vec2 LIGHT = vec2(-0.55, -0.83);
const float CHUNK = 46.0;
const float JIT = 0.9;
// How much of the crumble each chunk's own fall takes.
const float W = 0.35;

vec2 chunkSite(vec2 cell) {
    return (cell + 0.5 + (hash2(cell + 0.7) - 0.5) * JIT) * CHUNK;
}

// When the chunk around `site` starts to go, 0..1: top first, unevenly.
float chunkStart(vec2 site) {
    float yN = clamp((site.y - u.panel.y) / max(u.panel.w, 1.0), 0.0, 1.0);
    return clamp(0.72 * yN + 0.28 * hash(site * 0.031), 0.0, 1.0);
}

float chunkAge(vec2 site) {
    return clamp((u.crumble * (1.0 + W) - chunkStart(site)) / W, 0.0, 1.0);
}

// The slab's outline at rest: the panel's shape with chipped edges, < 0 inside.
float slabDist(vec2 q, vec2 c) {
    float chip = (vnoise(q / 9.0) - 0.5) * 7.0 + (vnoise(q / 3.5 + 4.0) - 0.5) * 2.0;
    return sdRoundRect(q - c, u.panel.zw * 0.5, 3.0) + max(chip, 0.0);
}

// The stone at q (slab coordinates at rest), `d` its outline distance.
vec3 stone(vec2 q, vec2 c, float d) {
    // Strata: broad, barely different layers, gently bent.
    float layer = (q.y - u.panel.y) / 26.0 + 0.35 * sin(q.x / 120.0 + 1.3) + 0.5 * fbm(q / vec2(160.0, 50.0));
    float id = floor(layer);
    float hs = hash(vec2(id, 3.7));
    vec3 col = hs < 0.35 ? mix(u.cMid.rgb, u.cDark.rgb, 0.18)
             : hs < 0.75 ? u.cMid.rgb : mix(u.cMid.rgb, u.cLight.rgb, 0.16);
    col = mix(col, mix(col, u.cDark.rgb, 0.3), 1.0 - band(fract(layer), 0.06));
    // Grit.
    vec2 gc = floor(q / 5.0);
    col = mix(col, mix(col, u.cDark.rgb, 0.22), step(0.975, hash(gc + 1.3)));
    col = mix(col, mix(col, u.cLight.rgb, 0.2), step(0.985, hash(gc + 8.1)));
    // Bevel: the edge toward the light catches it, the far edges fall into shade.
    vec2 w = abs(q - c) - u.panel.zw * 0.5;
    vec2 n = w.x > w.y ? vec2(sign(q.x - c.x), 0.0) : vec2(0.0, sign(q.y - c.y));
    float facing = dot(n, LIGHT);
    float bevel = cover(5.0 + d);
    col = mix(col, facing > 0.0 ? mix(u.cMid.rgb, u.cLight.rgb, 0.7) : mix(u.cMid.rgb, u.cDark.rgb, 0.7), bevel);
    // A groove carved round the face: in shade on its lit side, lit on the other.
    float g = abs(d + 13.0);
    col = mix(col, u.cDark.rgb, cover(1.1 - g));
    col = mix(col, mix(u.cMid.rgb, u.cLight.rgb, 0.55), cover(0.8 - abs(d + 14.8)) * step(facing, 0.0));
    col = mix(col, mix(u.cMid.rgb, u.cLight.rgb, 0.55), cover(0.8 - abs(d + 11.2)) * step(0.0, facing));
    return col;
}

// Distance to the cracks the landing sends up from `from`: a few jagged rays fanning
// upward, each with a branch, grown to `grow` of their length.
float landingCracks(vec2 q, vec2 from, float len, float grow) {
    float d = 1e3;
    for (int i = 0; i < 4; i++) {
        float fi = float(i);
        float a = -1.5708 + (fi - 1.5) * 0.62 + (hash(vec2(fi, 1.7)) - 0.5) * 0.35;
        float L = len * mix(0.45, 0.95, hash(vec2(fi, 2.9)));
        vec2 dir = vec2(cos(a), sin(a));
        vec2 o = q - from;
        float along = dot(o, dir);
        float across = dot(o, vec2(-dir.y, dir.x));
        float bend = zig(along / 34.0, fi) * 16.0 + zig(along / 9.0, fi + 7.0) * 4.0;
        float reach = L * grow;
        float main_ = along > 0.0 && along < reach ? abs(across - bend) : 1e3;
        // Thinner toward its tip.
        d = min(d, main_ - 1.4 * (1.0 - along / max(L, 1.0)));
        // A branch off it, partway up.
        float at = L * mix(0.3, 0.55, hash(vec2(fi, 4.1)));
        float ba = a + (hash(vec2(fi, 5.3)) < 0.5 ? -0.7 : 0.7);
        vec2 bdir = vec2(cos(ba), sin(ba));
        vec2 bo = o - dir * at - vec2(-dir.y, dir.x) * (zig(at / 34.0, fi) * 16.0 + zig(at / 9.0, fi + 7.0) * 4.0);
        float bal = dot(bo, bdir);
        float bac = dot(bo, vec2(-bdir.y, bdir.x)) - zig(bal / 20.0, fi + 3.0) * 8.0;
        float breach = (reach - at) * 0.6;
        if (bal > 0.0 && bal < breach)
            d = min(d, abs(bac) - 0.6 * (1.0 - bal / max(L * 0.6, 1.0)));
    }
    return d;
}

void main() {
    vec2 p = u.rect.xy + qt_TexCoord0 * u.rect.zw;
    vec2 q = p - u.offset;                                 // point on the slab at rest
    vec2 c = u.panel.xy + u.panel.zw * 0.5;
    float aboveGround = smoothstep(0.75, -0.75, p.y - u.ground);
    vec2 crackFrom = vec2(c.x, u.panel.y + u.panel.w);

    // The panel itself, where the stone has gone.
    float dPanel = sdRoundRect(q - c, u.panel.zw * 0.5, u.radius);
    vec4 col = texture(source, clamp((q - u.panel.xy) / u.panel.zw, 0.0, 1.0)) * cover(-dPanel);

    // ── Stone: each chunk standing, or crumbling away from where it stood ──
    vec2 g = floor(q / CHUNK);
    vec2 own = chunkSite(g);
    float bestD = 1e9;
    for (int j = -1; j <= 1; j++)
        for (int i = -1; i <= 1; i++) {
            vec2 s = chunkSite(g + vec2(i, j));
            float dd = dot(q - s, q - s);
            if (dd < bestD) { bestD = dd; own = s; }
        }
    float stoneA = 0.0;
    vec3 stoneC = vec3(0.0);
    if (u.crumble <= 0.0 || chunkAge(own) <= 0.0) {
        float d = slabDist(q, c);
        float body = cover(-d);
        if (body > 0.0) {
            vec3 sc = stone(q, c, d);
            // The cracks: a few jagged ones run up from where it landed, and the chunk
            // borders open just before their chunks go.
            float e = voronoiEdge(q, CHUNK, JIT);
            float soon = smoothstep(0.14, 0.0, chunkStart(own) - u.crumble * (1.0 + W)) * step(0.001, u.crumble);
            float open = soon;
            float lc = landingCracks(q, crackFrom, u.panel.w * 1.05, u.cracks);
            sc = mix(sc, mix(sc, u.cLight.rgb, 0.3), cover(2.6 - lc) * 0.6);
            sc = mix(sc, u.cEdge.rgb, cover(1.1 - lc));
            sc = mix(sc, mix(sc, u.cLight.rgb, 0.25), cover(2.4 - e) * open * 0.6);
            sc = mix(sc, u.cEdge.rgb, cover(1.0 + 0.5 * open - e) * open);
            stoneC = sc;
            stoneA = body;
        }
    }
    if (u.crumble > 0.0) {
        float bestK = -1.0;
        vec2 bq = vec2(0.0);
        for (int j = -1; j <= 1; j++)
            for (int i = -1; i <= 1; i++) {
                vec2 s = chunkSite(g + vec2(i, j));
                float k = chunkAge(s);
                if (k <= 0.0 || k >= 1.0)
                    continue;
                float h = hash(s * 0.017);
                vec2 drop = vec2((h - 0.5) * 12.0 * k, 0.9 * CHUNK * k * k);
                float sc = 1.0 - 0.65 * k;
                vec2 l = rot(q - s - drop, -(h - 0.5) * 2.4 * k) / max(sc, 1e-3);
                vec2 qs = s + l;
                if (dot(l, l) > CHUNK * CHUNK * 1.2)
                    continue;
                if (distance(voronoiSite(qs, CHUNK, JIT), s) > 0.5)
                    continue;
                if (k > bestK) { bestK = k; bq = qs; }
            }
        if (bestK > 0.0) {
            float d = slabDist(bq, c);
            float body = cover(-d);
            if (body > 0.0) {
                vec3 sc = stone(bq, c, d);
                // Tipping forward out of the light: a shade darker, outlined.
                sc = mix(sc, u.cDark.rgb, 0.3 * step(0.25, bestK));
                float e = voronoiEdge(bq, CHUNK, JIT) * (1.0 - bestK);
                sc = mix(sc, u.cEdge.rgb, cover(1.3 - e));
                body *= 1.0 - smoothstep(0.75, 1.0, bestK);
                stoneC = mix(stoneC, sc, body);
                stoneA = max(stoneA, body);
            }
        }
    }
    col = over(col, stoneC, stoneA);

    // ── Crumbs falling off the face as it crumbles ──
    if (u.crumble > 0.0 && u.crumble < 1.0) {
        const float COL = 30.0;
        float cx = floor(q.x / COL);
        for (int i = -1; i <= 1; i++)
            for (int k = 0; k < 2; k++) {
                float ci = cx + float(i);
                vec2 h = hash2(vec2(ci, float(k) + 3.0));
                vec2 start = vec2((ci + h.x) * COL, u.panel.y + 12.0 + h.y * (u.panel.w - 24.0));
                float t0 = clamp(0.72 * h.y + 0.28 * hash(vec2(ci, float(k))), 0.0, 1.0);
                float age = (u.crumble * (1.0 + W) - t0) * 0.9;
                if (age <= 0.0 || age > 0.75)
                    continue;
                vec2 pos = start + vec2((h.x - 0.5) * 40.0 * age, 900.0 * age * age);
                float size = mix(1.6, 3.4, hash(vec2(ci, float(k) + 9.0)));
                vec2 o = rot(q - pos, age * 9.0 + h.x * 6.0);
                float dc = max(max(abs(o.x), abs(o.y) * 1.3), (o.x + o.y) * 0.8) - size;
                float fade = 1.0 - smoothstep(0.55, 0.75, age);
                col = over(col, u.cEdge.rgb, cover(-dc + 0.9) * fade);
                col = over(col, o.y < 0.0 ? mix(u.cMid.rgb, u.cLight.rgb, 0.5) : u.cMid.rgb, cover(-dc) * fade);
            }
    }
    fragColor = col * aboveGround * u.qt_Opacity;
}
