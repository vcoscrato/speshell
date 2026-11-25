#version 440
#extension GL_GOOGLE_include_directive : enable
// The captured panel as a stone slab pushed up out of the ground. Only the part
// above the ground line shows. The slab is one cut stone: faint strata, a bevel lit
// from the top left, a groove carved round its face, and chipped edges. Landing
// cracks it from the bottom middle out; then its shell crumbles off in chunks, top
// first, each dropping, turning, and shrinking away with crumbs falling from it, to
// leave the panel. Run backwards, the chunks fly back into place before it sinks.
// The crumbs are boxes of their own after the slab's in the same mesh
// (LauncherTransition.vert), so the slab's pixels don't look for them.
layout(location = 0) in vec4 v;     // the screen point (px), what this is (0 the slab, 1 a crumb), and a crumb's fade
layout(location = 1) in vec4 piece; // a crumb's center on screen (px), turn, and size
layout(location = 2) in vec4 ray0;  // each crack: its direction, length, and where its branch leaves it, signed by its side
layout(location = 3) in vec4 ray1;
layout(location = 4) in vec4 ray2;
layout(location = 5) in vec4 ray3;
layout(location = 6) in vec4 bends; // how far each crack has bent off its line where its branch leaves it
layout(location = 0) out vec4 fragColor;
layout(binding = 1) uniform sampler2D source;
#include "LauncherTransition.glsl"

const vec2 LIGHT = vec2(-0.55, -0.83);

// Distance from q to the border of the chunk at site `a`, among the sites of the
// 3x3 cells round q, as voronoiEdge() measures it but from sites already found.
float edgeTo(vec2 q, vec2 a, vec2 b) {
    return dot(b - a, b - a) < 1.0 ? 1e9 : dot((a + b) * 0.5 - q, normalize(b - a));
}

float chunkEdge(vec2 q, vec2 a, vec2 s0, vec2 s1, vec2 s2, vec2 s3, vec2 s4, vec2 s5, vec2 s6, vec2 s7, vec2 s8) {
    return min(min(min(edgeTo(q, a, s0), edgeTo(q, a, s1)), min(edgeTo(q, a, s2), edgeTo(q, a, s3))),
               min(min(edgeTo(q, a, s4), edgeTo(q, a, s5)), min(min(edgeTo(q, a, s6), edgeTo(q, a, s7)), edgeTo(q, a, s8))));
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

// Distance from o (from where the slab landed) to one of the cracks the landing sends
// up, a jagged ray with a branch (`ray` and `bend`, as the vertex shader works them
// out), grown to `grow` of its length.
float crack(vec2 o, vec4 ray, float bend0, float fi, float grow) {
    vec2 dir = ray.xy;
    float L = ray.z;
    vec2 side = vec2(-dir.y, dir.x);
    float along = dot(o, dir);
    float across = dot(o, side);
    // The crack bends at most 10 px off its line, and its branch reaches no further
    // than 0.27 of its length to the side: a pixel well clear of both is clear of it.
    float reach = L * grow;
    if (along < -12.0 || along > reach + 12.0 || abs(across) > 24.0 + 0.3 * reach)
        return 1e3;
    float bend = zig(along / 34.0, fi) * 16.0 + zig(along / 9.0, fi + 7.0) * 4.0;
    float main_ = along > 0.0 && along < reach ? abs(across - bend) : 1e3;
    // Thinner toward its tip.
    float d = main_ - 1.4 * (1.0 - along / max(L, 1.0));
    // A branch off it, partway up, 0.7 rad to one side.
    float at = abs(ray.w);
    vec2 bdir = mat2(0.7648422, 0.6442177 * sign(ray.w), -0.6442177 * sign(ray.w), 0.7648422) * dir;
    vec2 bo = o - dir * at - side * bend0;
    float bal = dot(bo, bdir);
    float bac = dot(bo, vec2(-bdir.y, bdir.x)) - zig(bal / 20.0, fi + 3.0) * 8.0;
    float breach = (reach - at) * 0.6;
    if (bal > 0.0 && bal < breach)
        d = min(d, abs(bac) - 0.6 * (1.0 - bal / max(L * 0.6, 1.0)));
    return d;
}

// Distance to the cracks the landing sends up from where the slab landed: a few
// jagged rays fanning upward, each with a branch, grown to `grow` of their length.
float landingCracks(vec2 q, float grow) {
    vec2 o = q - impact();
    return min(min(crack(o, ray0, bends.x, 0.0, grow), crack(o, ray1, bends.y, 1.0, grow)),
               min(crack(o, ray2, bends.z, 2.0, grow), crack(o, ray3, bends.w, 3.0, grow)));
}

// A crumb: a small tumbling chip, lit on top.
vec4 crumbAt(vec2 p) {
    vec2 o = rot(p - piece.xy, piece.z);
    float dc = max(max(abs(o.x), abs(o.y) * 1.3), (o.x + o.y) * 0.8) - piece.w;
    vec4 col = over(vec4(0.0), u.cEdge.rgb, cover(-dc + 0.9) * v.w);
    return over(col, o.y < 0.0 ? mix(u.cMid.rgb, u.cLight.rgb, 0.5) : u.cMid.rgb, cover(-dc) * v.w);
}

void main() {
    vec2 p = v.xy;
    float aboveGround = smoothstep(0.75, -0.75, p.y - u.ground);
    if (v.z > 0.5) {
        fragColor = crumbAt(p) * aboveGround * u.qt_Opacity;
        return;
    }
    vec2 q = p - u.offset;                                 // point on the slab at rest
    vec2 c = u.panel.xy + u.panel.zw * 0.5;
    vec2 crackFrom = impact();

    // The panel itself, where the stone has gone.
    float dPanel = sdRoundRect(q - c, u.panel.zw * 0.5, u.radius);
    vec4 col = texture(source, clamp((q - u.panel.xy) / u.panel.zw, 0.0, 1.0)) * cover(-dPanel);

    // ── Stone: each chunk standing, or crumbling away from where it stood ──
    // The sites of the cells round q, from three rows above it to one below: a chunk
    // falls up to about two and a half cells, so a falling one may come from that far
    // up, and the three rows round q hold the chunk q stands in.
    vec2 g = floor(q / CHUNK);
    vec2 sites[15];
    for (int j = 0; j < 5; j++)
        for (int i = 0; i < 3; i++)
            sites[j * 3 + i] = chunkSite(g + vec2(float(i - 1), float(j - 3)));
    vec2 ownSite = sites[6];
    float bestD = 1e9;
    for (int k = 6; k < 15; k++) {
        float dd = dot(q - sites[k], q - sites[k]);
        if (dd < bestD) { bestD = dd; ownSite = sites[k]; }
    }
    float stoneA = 0.0;
    vec3 stoneC = vec3(0.0);
    if (u.crumble <= 0.0 || chunkAge(ownSite) <= 0.0) {
        float d = slabDist(q, c);
        float body = cover(-d);
        if (body > 0.0) {
            vec3 sc = stone(q, c, d);
            // The cracks: a few jagged ones run up from where it landed, and the chunk
            // borders open just before their chunks go.
            float e = chunkEdge(q, ownSite, sites[6], sites[7], sites[8], sites[9], sites[10], sites[11],
                                sites[12], sites[13], sites[14]);
            float open = smoothstep(0.08, 0.0, chunkStart(ownSite) - u.crumble * (1.0 + W)) * step(0.001, u.crumble);
            float lc = u.cracks > 0.0 ? landingCracks(q, u.cracks) : 1e3;
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
        float bestE = 1e9;
        for (int k = 0; k < 15; k++) {
            vec2 s = sites[k];
            float age = chunkAge(s);
            if (age <= 0.0 || age >= 1.0)
                continue;
            float h = hash(s * 0.017);
            // Knocked away from the impact, then falling, and nearing as it tips forward.
            vec2 away = normalize(s - crackFrom + vec2(0.0, -1.0));
            vec2 drop = away * 18.0 * age + vec2((h - 0.5) * 10.0 * age, 150.0 * age * age);
            float sc = 1.0 + 0.12 * age;
            vec2 l = rot(q - s - drop, -(h - 0.5) * 1.8 * age) / sc;
            vec2 qs = s + l;
            if (dot(l, l) > CHUNK * CHUNK * 1.2 || age <= bestK)
                continue;
            // Only where that point of the slab at rest lies in this chunk.
            vec2 gs = floor(qs / CHUNK);
            vec2 n[9];
            vec2 near = s;
            float nd = 1e9;
            for (int y = 0; y < 3; y++)
                for (int x = 0; x < 3; x++) {
                    vec2 b = chunkSite(gs + vec2(float(x - 1), float(y - 1)));
                    n[y * 3 + x] = b;
                    float dd = dot(qs - b, qs - b);
                    if (dd < nd) { nd = dd; near = b; }
                }
            if (distance(near, s) > 0.5)
                continue;
            bestK = age;
            bq = qs;
            bestE = chunkEdge(qs, s, n[0], n[1], n[2], n[3], n[4], n[5], n[6], n[7], n[8]);
        }
        if (bestK > 0.0) {
            float d = slabDist(bq, c);
            float body = cover(-d);
            if (body > 0.0) {
                vec3 sc = stone(bq, c, d);
                // Tipping forward out of the light: darker as it turns, outlined.
                sc = mix(sc, u.cDark.rgb, 0.35 * smoothstep(0.0, 0.7, bestK));
                float e = bestE;
                sc = mix(sc, mix(sc, u.cLight.rgb, 0.35), cover(3.0 - e) * (1.0 - smoothstep(0.0, 0.5, bestK)));
                sc = mix(sc, u.cEdge.rgb, cover(1.3 - e));
                body *= 1.0 - smoothstep(0.75, 1.0, bestK);
                stoneC = stoneA > 0.0 ? mix(stoneC, sc, body) : sc;
                stoneA = max(stoneA, body);
            }
        }
    }
    col = over(col, stoneC, stoneA);

    fragColor = col * aboveGround * u.qt_Opacity;
}
