#version 440
#extension GL_GOOGLE_include_directive : enable
// A blow strikes the outgoing wallpaper and breaks it from the point of impact out.
// The shards are Voronoi cells in log-polar space around the impact, so they are
// crushed rubble at the middle and grow into broad slabs toward the edges; some
// neighbours along a ray stay joined, so their sizes vary more. Cracks race out
// along the rays first, unevenly, then branch across between them; then each shard,
// at its own moment, jerks up, tilts, and drops, turning and shrinking as it falls
// away with dust where it stood. Chips of the old wallpaper are flung from the cracks.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 resolution;
    vec2 center;       // px, the point of impact
    float time;        // s since the impact
    float reach;       // px, from the impact to the furthest corner
    vec4 cCrack;
    vec4 cLip;
    vec4 cDust;
    vec4 cDustShade;
} u;
layout(binding = 1) uniform sampler2D source;
#include "../../lib/common.glsl"

const float TAU = 6.2831853;
// Shards around the impact, and how much longer they run along a ray than across it.
const float N = 30.0;
const float KU = 0.72;
const float JITTER = 0.85;
const float R0 = 14.0;
// The crack front's time to the furthest corner, and each shard's fall.
const float FRONT = 0.45;
const vec2 LIGHT = vec2(-0.55, -0.83);

// ── Log-polar cells: x = (along the ray, around the impact), in cell units ──

vec2 warped(vec2 p) {
    vec2 d = p - u.center;
    float r = length(d);
    // Bent by noise in proportion to the radius, so the rays wander at every scale.
    return d + r * 0.09 * (vec2(vnoise(p / 170.0), vnoise(p / 170.0 + 7.3)) - 0.5);
}

vec2 toCells(vec2 p) {
    vec2 d = warped(p);
    return vec2(log(max(length(d), R0) / R0) * N / TAU * KU, atan(d.y, d.x) / TAU * N);
}

vec2 toScreen(vec2 x) {
    float r = R0 * exp(x.x * TAU / (N * KU));
    float a = x.y * TAU / N;
    return u.center + r * vec2(cos(a), sin(a));
}

vec2 wrapId(vec2 c) {
    return vec2(c.x, mod(c.y, N));
}

vec2 siteOf(vec2 c) {
    return c + 0.5 + (hash2(wrapId(c) + 0.31) - 0.5) * JITTER;
}

// The cell of x (raw, unwrapped).
vec2 cellOf(vec2 x) {
    vec2 g = floor(x), best = g;
    float bestD = 1e9;
    for (int j = -1; j <= 1; j++)
        for (int i = -1; i <= 1; i++) {
            vec2 c = g + vec2(i, j);
            vec2 o = x - siteOf(c);
            float d = dot(o, o);
            if (d < bestD) { bestD = d; best = c; }
        }
    return best;
}

// The shard a cell belongs to: about half the rays join pairs of cells along them.
vec2 groupOf(vec2 c) {
    vec2 w = wrapId(c);
    float off = step(0.5, hash(vec2(w.y, 2.7)));
    float pair = floor((w.x + off) * 0.5);
    bool joined = hash(vec2(pair, w.y + 5.1)) < 0.55;
    return vec2(joined ? pair * 2.0 - off : w.x, w.y) + vec2(joined ? 0.5 : 0.0, 0.0);
}

// ── Timing ──

// How fast the front runs along the ray at angle a: some rays lead.
float lead(float a) {
    vec2 o = vec2(cos(a), sin(a));
    return mix(0.72, 1.3, vnoise(o * 2.2 + 3.0));
}

// When the crack front reaches radius r on the ray at angle a, s.
float crackAt(float r, float a) {
    return FRONT * pow(max(r - R0, 0.0) / u.reach, 1.35) / lead(a);
}

// A shard's pivot on screen (the middle of its cells) and the moment it breaks loose.
vec3 shardOf(vec2 c, vec2 grp) {
    vec2 xs = fract(grp.x) > 0.25
        ? (siteOf(vec2(floor(grp.x), c.y)) + siteOf(vec2(floor(grp.x) + 1.0, c.y))) * 0.5
        : siteOf(c);
    vec2 pivot = toScreen(xs);
    vec2 pd = pivot - u.center;
    // Rubble at the middle goes at once; further out the slabs hang on unevenly,
    // and a few hang on a while longer.
    float h = hash(grp + 0.7);
    float tr = 0.1 + crackAt(length(pd), atan(pd.y, pd.x)) * 1.3 + 0.45 * h * h
             + 0.2 * step(hash(grp + 1.9), 0.2) * step(40.0, length(pd));
    return vec3(pivot, tr);
}

// ── Debris ──

// A lumpy dust puff at `c`, radius `r`, as (coverage, shade).
vec2 puff(vec2 p, vec2 c, float r, float seed) {
    vec2 o = p - c;
    float ang = atan(o.y, o.x);
    float lumps = (vnoise(vec2(ang * 1.8 + seed * 9.0, seed)) - 0.5) * 0.5 * r
                + (vnoise(vec2(ang * 5.0 + seed * 3.0, 4.0)) - 0.5) * 0.2 * r;
    float d = length(o) - r - lumps;
    return vec2(cover(-d), cover(o.y + o.x * 0.4 - r * 0.15));
}

void main() {
    vec2 p = qt_TexCoord0 * u.resolution;
    float t = u.time;
    // The blow shakes the ground for a moment.
    vec2 shake = vec2(sin(t * 83.0), cos(t * 67.0)) * 5.0 * exp(-t * 11.0);

    vec2 d0 = p - u.center;
    float r = length(d0);
    float ang = atan(d0.y, d0.x);
    vec2 x = toCells(p);
    // px per cell unit across the ray here, and the radial/tangential unit vectors.
    float pxV = r * TAU / N;
    float pxU = pxV / KU;

    // ── Own shard, still standing: the old wallpaper with its cracks ──
    vec2 g = floor(x);
    vec2 a = g;
    float bestD = 1e9;
    for (int j = -1; j <= 1; j++)
        for (int i = -1; i <= 1; i++) {
            vec2 c = g + vec2(i, j);
            vec2 o = x - siteOf(c);
            float dd = dot(o, o);
            if (dd < bestD) { bestD = dd; a = c; }
        }
    vec2 ownG = groupOf(a);
    float release0 = shardOf(a, ownG).z;

    vec4 col = vec4(0.0);
    if (t < release0) {
        vec4 tex = texture(source, (p + shake) / u.resolution);
        // The nearest border to another shard, in px, and how it runs.
        vec2 sa = siteOf(a);
        float edge = 1e9;
        vec2 nrm = vec2(1.0, 0.0);
        vec2 other = a;
        for (int j = -1; j <= 1; j++)
            for (int i = -1; i <= 1; i++) {
                vec2 c = g + vec2(i, j);
                if (c == a || groupOf(c) == ownG)
                    continue;
                vec2 n = normalize(siteOf(c) - sa);
                // Distance to the bisector, scaled from cell units to px.
                float e = dot((sa + siteOf(c)) * 0.5 - x, n) / length(vec2(n.x / pxU, n.y / pxV));
                if (e < edge) { edge = e; nrm = n; other = c; }
            }
        // Rays crack as the front passes; the branches across them a moment later.
        float across = step(abs(nrm.y), abs(nrm.x));
        vec2 pair = wrapId(a) + wrapId(other);
        float crackT = crackAt(r, ang) + across * (0.05 + 0.2 * hash(pair + 0.4));
        float open = smoothstep(crackT, crackT + 0.12, t);
        float w = clamp(pxV * 0.022, 0.7, 2.2) * (0.6 + 0.4 * open);
        // Lit on the side toward the light, in shade on the other.
        vec2 sn = normalize(-(nrm.x / pxU) * d0 / max(r, 1.0) - (nrm.y / pxV) * vec2(-d0.y, d0.x) / max(r, 1.0));
        float faceLit = dot(sn, -LIGHT);
        float bevel = cover(w + 1.6 - edge) * step(0.0, t - crackT);
        tex.rgb = mix(tex.rgb, faceLit > 0.0 ? u.cCrack.rgb : u.cLip.rgb, bevel * 0.28);
        tex.rgb = mix(tex.rgb, u.cCrack.rgb, cover(w - edge) * step(0.0, t - crackT));
        // A beat before it goes, the shard jerks up toward the light.
        float lift = smoothstep(release0 - 0.12, release0, t);
        tex.rgb = mix(tex.rgb, tex.rgb * 1.12 + u.cLip.rgb * 0.04, step(0.5, lift));
        col = tex;
    }

    // ── Falling shards: own and the ones just above, which drop over it ──
    float rMin = r * 0.45, rMax = r * 2.2 + 80.0;
    float earliest = 0.1 + FRONT * pow(max(rMin - R0, 0.0) / u.reach, 1.35) / 1.3 * 1.3;
    float latest = 0.1 + FRONT * pow(rMax / u.reach, 1.35) / 0.72 * 1.3 + 0.65 + 0.75;
    float dust = 0.0, dustShade = 0.0;
    if (t > earliest && t < latest + 0.6) {
        vec2 up = vec2(-KU * sin(ang), -cos(ang)) * 1.9;
        vec2 gB = floor(x + up);
        float bestK = -1.0;
        vec2 bestQ = vec2(0.0);
        float bestS = 1.0;
        for (int b = 0; b < 2; b++) {
            vec2 gc = b == 0 ? g : gB;
            for (int j = -1; j <= 1; j++)
                for (int i = -1; i <= 1; i++) {
                    vec2 c = gc + vec2(i, j);
                    // The second block skips the cells the first has seen.
                    if (b == 1 && abs(c.x - g.x) <= 1.0 && abs(c.y - g.y) <= 1.0)
                        continue;
                    vec2 grp = groupOf(c);
                    bool joined = fract(grp.x) > 0.25;
                    vec3 sh = shardOf(c, grp);
                    vec2 pivot = sh.xy;
                    vec2 pd = pivot - u.center;
                    float pr = length(pd);
                    float tr = sh.z;
                    float dur = mix(0.5, 0.75, hash(grp + 2.9));
                    float tau = t - tr;
                    if (tau < 0.0)
                        continue;
                    float cell = pr * TAU / N;
                    float extent = cell * (joined ? 1.6 : 1.0);
                    // Jerks up, then drops with gravity, turning and pushed out from the blow,
                    // and at the last crumbles to nothing about its middle.
                    float k = tau / dur;
                    float kk = min(k, 1.0);
                    float rise = sin(clamp(kk / 0.18, 0.0, 1.0) * 3.1415927) * 0.1;
                    float fall = pow(max(kk - 0.12, 0.0) / 0.88, 2.0) * 2.0;
                    vec2 off = vec2(0.0, (fall - rise) * cell) + pd / max(pr, 1.0) * cell * 0.25 * kk;
                    // The dust it crumbles into, from about half the shards, drifting up.
                    if (!joined || c.x == floor(grp.x)) {
                        float kd = (tau - dur * 0.62) / 0.55;
                        if (kd > 0.0 && kd < 1.0 && hash(grp + 4.4) < 0.5) {
                            float pr_ = min(extent * 0.42, 44.0) * (0.7 + 0.6 * sqrt(kd));
                            vec2 pc = pivot + off * 0.85 - vec2(0.0, 20.0 * kd);
                            vec2 pf = puff(p, pc, pr_, hash(grp + 6.1));
                            float kp = pf.x * 0.4 * pow(1.0 - kd, 1.3);
                            dust = max(dust, kp);
                            dustShade = max(dustShade, kp * pf.y);
                        }
                    }
                    if (k >= 1.0)
                        continue;
                    float spin = (hash(grp + 8.3) - 0.5) * 1.8;
                    float s = 1.0 - 0.14 * k - 0.86 * smoothstep(0.6, 1.0, k);
                    vec2 q = pivot + rot(p - pivot - off, -spin * k * k) / s;
                    if (distance(q, pivot) > extent * 1.5 + 6.0)
                        continue;
                    if (groupOf(cellOf(toCells(q))) != grp)
                        continue;
                    if (k > bestK) { bestK = k; bestQ = q; bestS = s; }
                }
        }
        if (bestK >= 0.0) {
            vec4 tex = texture(source, bestQ / u.resolution);
            // Tilting away from the light: a flat shade darker, then another.
            tex.rgb *= mix(1.0, 0.8, step(0.2, bestK)) * mix(1.0, 0.82, step(0.55, bestK));
            // Its broken rim: lit along the top, its thickness dark below.
            vec2 xq = toCells(bestQ);
            vec2 aq = cellOf(xq);
            vec2 gq = groupOf(aq);
            vec2 sq = siteOf(aq);
            float qr = length(bestQ - u.center);
            float qV = qr * TAU / N, qU = qV / KU;
            float e = 1e9;
            vec2 en = vec2(0.0);
            vec2 fq = floor(xq);
            for (int j = -1; j <= 1; j++)
                for (int i = -1; i <= 1; i++) {
                    vec2 c = fq + vec2(i, j);
                    if (c == aq || groupOf(c) == gq)
                        continue;
                    vec2 n = normalize(siteOf(c) - sq);
                    float ee = dot((sq + siteOf(c)) * 0.5 - xq, n) / length(vec2(n.x / qU, n.y / qV));
                    if (ee < e) { e = ee; en = n; }
                }
            vec2 qd = bestQ - u.center;
            vec2 sn = normalize((en.x / qU) * qd + (en.y / qV) * vec2(-qd.y, qd.x) + 1e-5);
            float facing = dot(sn, LIGHT);
            float thick = clamp(qV * 0.08, 1.5, 9.0) * smoothstep(0.0, 0.3, bestK);
            tex.rgb = mix(tex.rgb, u.cCrack.rgb, cover(1.3 - e * bestS));
            tex.rgb = mix(tex.rgb, mix(tex.rgb, u.cCrack.rgb, 0.5), cover(thick - e * bestS) * step(facing, -0.2));
            tex.rgb = mix(tex.rgb, mix(tex.rgb, u.cLip.rgb, 0.45), cover(2.2 - e * bestS) * step(0.35, facing));
            float fade = 1.0 - smoothstep(0.85, 1.0, bestK);
            col = tex * fade + col * (1.0 - fade);
        }
    }

    // ── Chips of the old wallpaper flung up from the cracks as the front passes ──
    if (t < FRONT / 0.72 + 0.9) {
        const float G = 64.0;
        vec2 gc = floor(p / G);
        for (int j = -2; j <= 1; j++)
            for (int i = -2; i <= 2; i++) {
                vec2 c = gc + vec2(i, j);
                vec3 h = vec3(hash(c + 0.13), hash(c + 5.7), hash(c + 9.1));
                if (h.x > 0.32)
                    continue;
                vec2 start = (c + 0.2 + 0.6 * h.yz) * G;
                vec2 sd = start - u.center;
                float sr = length(sd);
                float age = t - crackAt(sr, atan(sd.y, sd.x)) - 0.03 - 0.12 * h.y;
                float life = 0.75;
                if (age < 0.0 || age > life)
                    continue;
                vec2 vel = sd / max(sr, 1.0) * mix(30.0, 140.0, h.z) + vec2(0.0, -mix(140.0, 340.0, h.y));
                vec2 pos = start + vel * age + vec2(0.0, 750.0) * age * age;
                float size = mix(2.5, 5.5, h.z * h.x / 0.32) * (sr < 160.0 ? 0.7 : 1.0);
                vec2 lp = rot(p - pos, age * (h.y - 0.5) * 22.0);
                float dc = max(abs(lp.x) - size, abs(lp.y) - size * 0.7);
                dc = max(dc, (lp.x + lp.y) * 0.7 - size * 0.6);
                float fade = smoothstep(0.0, 0.06, age) * (1.0 - smoothstep(0.7, 1.0, age / life));
                vec3 chipCol = texture(source, start / u.resolution).rgb * (lp.y < 0.0 ? 1.25 : 0.7);
                vec4 ch = over(vec4(0.0), u.cCrack.rgb, cover(-dc + 1.0));
                ch = over(ch, chipCol, cover(-dc));
                col = ch * fade + col * (1.0 - ch.a * fade);
            }
    }

    // ── The crater: a burst of dust at the point of impact ──
    if (t < 0.9) {
        float kc = t / 0.9;
        vec2 pf = puff(p, u.center + vec2(0.0, -24.0 * kc), 20.0 + 70.0 * sqrt(kc), 0.37);
        float k = pf.x * 0.5 * pow(1.0 - kc, 1.3);
        dust = max(dust, k);
        dustShade = max(dustShade, k * pf.y);
    }
    vec3 dustCol = mix(u.cDust.rgb, u.cDustShade.rgb, dustShade / max(dust, 1e-4) > 0.5 ? 1.0 : 0.0);
    col = over(col, dustCol, dust);

    fragColor = col * u.qt_Opacity;
}
