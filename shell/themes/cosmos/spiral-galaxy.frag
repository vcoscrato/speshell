#version 440
#extension GL_GOOGLE_include_directive : enable
// Spiral galaxy: a tilted two-armed galaxy in Gruvbox golds and plums, its bulge
// glowing in rings, dust lanes trailing inside its arms and knots of young
// stars strung along them. A banded nebula streams through it, its steps lit on
// the side toward the galaxy. A
// globular cluster and a young open cluster shine nearby, two far galaxies show
// the distance, and stars of every size and color fill the dark. In the lower
// left a banded gas giant rises, lit from behind, its ring crossing in front of
// it and passing through its shadow, with its small moon.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 resolution;
} u;
#include "../../effects/common/common.glsl"
#include "../landscape.glsl"

float PX;       // one pixel, in q
vec2 GC;        // the galaxy's center

// Coverage of a signed distance in q, without derivatives, so it is safe anywhere.
float fill(float d) {
    return smoothstep(PX, -PX, d);
}

// A star's color by a hash: mostly cream, some gold, blue-white, peach, and rose.
vec3 starColor(float h) {
    if (h < 0.56) return rgb(235, 219, 178);
    if (h < 0.7) return rgb(246, 206, 120);
    if (h < 0.84) return rgb(176, 198, 184);
    if (h < 0.93) return rgb(248, 166, 104);
    return rgb(222, 156, 170);
}

// One star per cell of size, shown in a fraction keep of the cells: its color, and
// its coverage in a.
vec4 starLayer(vec2 q, float size, float keep, float seed, float maxR) {
    vec2 g = floor(q / size);
    if (hash(g + seed + 3.7) > keep)
        return vec4(0.0);
    vec2 h = hash2(g + seed);
    vec2 c = (g + 0.2 + 0.6 * h) * size;
    float r = max(PX * 1.3, maxR * mix(0.25, 1.0, h.x * h.y));
    float a = smoothstep(PX * 0.75, -PX * 0.75, length(q - c) - r) * mix(0.5, 1.0, h.y);
    return vec4(starColor(hash(g + seed + 9.1)), a);
}

// A bright star of radius r: a core in two rings of halo, and four rays of
// length k * r when k > 0.
vec3 brightStar(vec3 col, vec2 q, vec2 c, float r, float k, vec3 tint) {
    vec2 d = abs(q - c);
    float l = length(q - c);
    col = mix(col, tint, fill(l - r * 3.2) * 0.1);
    col = mix(col, tint, fill(l - r * 1.9) * 0.22);
    if (k > 0.0) {
        float L = r * k;
        float rays = max(fill(d.y - r * 0.16 * (1.0 - d.x / L)) * step(d.x, L),
                         fill(d.x - r * 0.16 * (1.0 - d.y / L)) * step(d.y, L));
        col = mix(col, mix(tint, rgb(251, 241, 199), 0.5), rays);
    }
    return mix(col, rgb(251, 241, 199), fill(l - r));
}

// The spiral's density at disc-plane point g: two logarithmic arms of pitch k
// around a bulge, warped by seed so their edges wander. Returns the density and
// the arm phase.
vec2 spiral(vec2 g, float k, float seed) {
    float r = length(g);
    float th = atan(g.y, g.x);
    float warp = (fbm(g * 3.2 + seed) - 0.5) * 0.75 + (vnoise(g * 9.0 + seed) - 0.5) * 0.12;
    float ph = 2.0 * (th - log(max(r, 1e-3)) * k) + warp;
    float arm = 0.5 + 0.5 * cos(ph);
    float disc = exp(-r / 0.3) * (1.0 - smoothstep(0.5, 0.9, r));
    float density = pow(arm, 1.4) * disc * 1.1 + 0.22 * exp(-r / 0.16) + exp(-r * r / 0.005) * 1.1;
    density *= 0.86 + 0.28 * fbm(g * 7.0 + seed);
    return vec2(density, ph);
}

// Coordinates along the nebula's band (x) and across it (y), the band meandering.
vec2 nebulaCoord(vec2 q, vec2 nd) {
    float a = dot(q - GC, nd);
    float c = dot(q - GC, vec2(-nd.y, nd.x));
    return vec2(a, c + 0.07 * sin(a * 2.2 + 0.6) + 0.03 * sin(a * 5.3 + 2.0));
}

// The nebula's gas at band coordinates nb: swirled streaks stretched along the
// band, thinning away from its middle. Its steps nest one inside the other.
float nebula(vec2 nb) {
    vec2 p = vec2(nb.x * 1.25, nb.y * 3.4);
    p += 0.45 * vec2(fbm(p * 1.1 + vec2(1.7, 9.2)), fbm(p * 1.1 + vec2(8.3, 2.8)));
    return fbm(p + vec2(3.0, 1.0)) + 0.22 * vnoise(p * 3.1) - abs(nb.y) * 1.5;
}

void main() {
    vec2 px = qt_TexCoord0 * u.resolution;
    vec2 q = vec2(px.x, u.resolution.y - px.y) / u.resolution.y;
    PX = 1.0 / u.resolution.y;
    float aspect = u.resolution.x / u.resolution.y;
    GC = vec2(aspect * 0.6, 0.56);
    vec2 toGal = normalize(GC - q + 1e-5);
    float dg = length(q - GC);

    // ── Deep space, lighter toward the galaxy in flat steps ──
    vec2 ge = rot(q - GC, -0.42) * vec2(1.0, 1.6);
    float glow = exp(-length(ge) * 1.7) + (fbm(q * 2.0) - 0.5) * 0.06;
    vec3 col = mix(rgb(20, 22, 23), rgb(42, 36, 40), steps(clamp(glow, 0.0, 1.0), 6.0));

    // Faint far stars, under everything.
    vec4 s0 = starLayer(q, 0.009, 0.4, 1.0, 0.0008);
    col = mix(col, s0.rgb, s0.a * 0.7);

    // ── The nebula: a band streaming through the galaxy, in layers ──
    vec2 nd = normalize(vec2(1.0, -0.42));
    vec2 nb = nebulaCoord(q, nd);
    float lightNear = exp(-dg * 1.6);
    // The gas in nested steps, cool and dim outside, plum and rose toward its
    // middle, each step lit along its edge toward the galaxy.
    vec2 nl = nebulaCoord(q + toGal * 0.009, nd);
    float neb = nebula(nb), nebL = nebula(nl);
    for (int i = 0; i < 5; i++) {
        float th = 0.16 + 0.1 * float(i);
        vec3 body = i == 0 ? rgb(26, 28, 31) : i == 1 ? rgb(44, 32, 42) : i == 2 ? rgb(58, 38, 52) : i == 3 ? rgb(76, 44, 63) : rgb(98, 54, 77);
        vec3 rim = i == 0 ? rgb(32, 34, 38) : mix(mix(body, rgb(120, 66, 90), 0.45), i < 3 ? rgb(132, 72, 98) : rgb(188, 104, 130), lightNear);
        float inside = band(neb, th);
        col = mix(col, body, inside);
        col = mix(col, rim, inside * (1.0 - band(nebL, th)));
    }

    // Brighter stars over the gas.
    vec4 s1 = starLayer(q + 0.37, 0.021, 0.5, 7.0, 0.0016);
    col = mix(col, s1.rgb, s1.a);
    vec4 s2 = starLayer(q + 0.71, 0.05, 0.45, 13.0, 0.0024);
    col = mix(col, s2.rgb, s2.a);

    // ── Two far galaxies: one edge-on, one face-on ──
    {
        vec2 e = rot(q - vec2(0.26, 0.5), 0.5);
        float spindle = length(e * vec2(1.0, 7.5));
        float bulge = length(e * vec2(1.0, 1.6));
        col = mix(col, rgb(84, 64, 62), fill(spindle - 0.05));
        col = mix(col, rgb(170, 128, 96), fill(spindle - 0.032) * 0.9);
        col = mix(col, rgb(214, 170, 120), fill(bulge - 0.008));
        col = mix(col, rgb(240, 222, 180), fill(bulge - 0.0045));
        col = mix(col, rgb(46, 34, 36), fill(abs(e.y + 0.0006) - 0.0011) * fill(abs(e.x) - 0.042));
    }
    {
        vec2 fc = vec2(aspect * 0.86, 0.19);
        vec2 g2 = rot(q - fc, -0.9) / 0.11;
        g2.y /= 0.7;
        if (length(g2) < 1.0) {
            float dd = spiral(g2, 2.2, 4.0).x;
            col = mix(col, rgb(56, 42, 50), band(dd, 0.14));
            col = mix(col, rgb(112, 74, 90), band(dd, 0.28));
            col = mix(col, rgb(190, 132, 92), band(dd, 0.5));
            col = mix(col, rgb(236, 214, 170), band(dd, 0.9));
        }
        // A small elliptical beside it.
        vec2 ep = rot(q - fc - vec2(0.09, -0.05), 0.3) * vec2(1.0, 1.7);
        col = mix(col, rgb(100, 80, 70), fill(length(ep) - 0.006));
        col = mix(col, rgb(214, 190, 150), fill(length(ep) - 0.0028));
    }

    // ── A globular cluster: a ball of old stars, densest at its heart ──
    {
        vec2 cc = vec2(aspect * 0.885, 0.8);
        float cr = length(q - cc);
        col = mix(col, rgb(56, 48, 42), fill(cr - 0.05) * 0.5);
        col = mix(col, rgb(84, 70, 56), fill(cr - 0.026) * 0.6);
        col = mix(col, rgb(150, 124, 88), fill(cr - 0.011) * 0.7);
        vec2 g = floor(q / 0.004);
        vec2 h = hash2(g + 41.0);
        vec2 c = (g + 0.2 + 0.6 * h) * 0.004;
        float keep = exp(-pow(length(c - cc) / 0.03, 2.0));
        float st = step(hash(g + 47.0), keep) * fill(length(q - c) - max(PX * 1.2, 0.0011 * h.x));
        col = mix(col, mix(rgb(246, 206, 120), rgb(251, 241, 199), h.y), st);
    }

    // ── A young open cluster: a knot of hot blue-white stars ──
    {
        vec2 oc = vec2(aspect * 0.33, 0.8);
        for (int i = 0; i < 9; i++) {
            float fi = float(i);
            vec2 h = hash2(vec2(fi, 71.0)) - 0.5;
            vec2 c = oc + h * vec2(0.12, 0.08);
            float r = mix(0.0016, 0.0034, hash(vec2(fi, 72.0)));
            col = brightStar(col, q, c, r, i < 3 ? 5.0 : 0.0, rgb(150, 186, 180));
        }
    }

    // ── The galaxy, tilted toward the viewer ──
    vec2 g = rot(q - GC, -0.42);
    g.y /= 0.42;
    float r = length(g);
    float th = atan(g.y, g.x);
    vec2 sp = spiral(g, 2.6, 0.0);
    float density = sp.x;
    float ph = sp.y;

    // Depth: a faint glow of the disc's old stars around the arms, in two dim steps.
    float halo = exp(-r / 0.2) * (1.0 - smoothstep(0.3, 0.62, r));
    col = mix(col, rgb(48, 36, 44), band(halo + 0.04 * fbm(g * 4.0), 0.2) * 0.85);
    col = mix(col, rgb(60, 42, 54), band(halo, 0.36) * 0.85);

    col = mix(col, rgb(98, 52, 72), band(density, 0.12) * 0.9);
    col = mix(col, rgb(177, 98, 134), band(density, 0.24));
    col = mix(col, rgb(214, 93, 14), band(density, 0.4));
    col = mix(col, rgb(254, 128, 25), band(density, 0.56));
    col = mix(col, rgb(250, 189, 47), band(density, 0.75));
    col = mix(col, rgb(251, 241, 199), band(density, 0.98));

    // Dust lanes trail just inside the arms, broken in places.
    float lane = 0.5 + 0.5 * cos(ph + 0.95);
    float armId = floor(ph / TAU + 0.5);
    float lrr = log(max(r, 1e-3));
    float broken = band(vnoise(vec2(lrr * 5.0, armId * 7.0)) + 0.2 * vnoise(g * 30.0), 0.32);
    float laneIn = band(lane, 0.86) * smoothstep(0.05, 0.1, r) * (1.0 - smoothstep(0.4, 0.55, r)) * broken;
    col = mix(col, mix(rgb(74, 38, 52), rgb(120, 52, 34), exp(-r / 0.1)), laneIn * 0.92);

    // Star clouds sparkle along the arms, blue-white in the outer arms.
    vec4 sc = starLayer(g * vec2(1.0, 0.42) + 0.13, 0.008, 0.6, 21.0, 0.0012);
    col = mix(col, mix(rgb(251, 241, 199), rgb(190, 214, 200), smoothstep(0.18, 0.3, r)), sc.a * band(density, 0.2));

    // Knots of young stars strung along the arms: rose, with a cream heart.
    float a = fract(ph / TAU + 0.5) - 0.5;
    for (int k = -1; k <= 1; k++) {
        float cell = floor(lrr * 6.0) + float(k);
        vec2 hk = hash2(vec2(cell, armId * 13.0 + 5.0));
        if (hk.x > 0.7)
            continue;
        float lk = (cell + 0.2 + 0.6 * hk.y) / 6.0;
        float rk = exp(lk);
        if (rk < 0.1 || rk > 0.5)
            continue;
        float phk = ph - a * TAU + (hk.x - 0.35) * 0.9;
        float thk = th + (phk - ph) * 0.5 + 2.6 * (lk - lrr);
        vec2 gk = rk * vec2(cos(thk), sin(thk));
        vec2 qk = GC + rot(vec2(gk.x, gk.y * 0.42), 0.42);
        float sz = mix(0.003, 0.0075, pow(hash(vec2(cell, armId + 9.0)), 1.5)) * mix(0.7, 1.15, rk / 0.5);
        // A knot of four tiny bright stars.
        for (int j = 0; j < 4; j++) {
            vec2 hj = hash2(vec2(cell * 4.0 + float(j), armId + 17.0)) - 0.5;
            vec2 cj = qk + hj * sz * 2.2;
            float sj = max(PX * 1.1, sz * mix(0.14, 0.3, hj.y + 0.5));
            col = mix(col, mix(rgb(251, 241, 199), rgb(236, 190, 196), hj.x + 0.5), fill(length(q - cj) - sj));
        }
    }

    // The bulge, round and standing out of the disc, glowing in rings.
    vec2 b = rot(q - GC, -0.42) * vec2(1.0, 1.0 / 0.66);
    float rb = length(b) * (1.0 + 0.06 * (vnoise(vec2(atan(b.y, b.x) * 2.0, 3.0)) - 0.5));
    col = mix(col, rgb(250, 189, 47), fill(rb - 0.07) * 0.35);
    col = mix(col, rgb(250, 189, 47), fill(rb - 0.05));
    col = mix(col, rgb(252, 222, 140), fill(rb - 0.034));
    col = mix(col, rgb(251, 241, 199), fill(rb - 0.02));
    // The near side of the disc crosses in front of it in a lane of dust.
    float nearLane = abs(r - 0.085 - 0.01 * (vnoise(vec2(th * 3.0, 1.0)) - 0.5)) - 0.007;
    col = mix(col, rgb(120, 52, 34), fill(nearLane) * smoothstep(0.0, -0.02, g.y) * smoothstep(0.085, 0.05, abs(g.x)) * fill(rb - 0.075) * 0.85);

    // ── A few bright stars, clear of the galaxy ──
    for (int i = 0; i < 11; i++) {
        vec2 h = hash2(vec2(float(i), 31.0));
        vec2 c = vec2(h.x * aspect, 0.2 + 0.78 * h.y);
        if (length((c - GC) * vec2(0.7, 1.0)) < 0.32)
            c.x = mod(c.x + aspect * 0.45, aspect);
        float rr = mix(0.0022, 0.0042, hash(vec2(float(i), 5.0)));
        float kk = mix(5.0, 9.0, hash(vec2(float(i), 6.0)));
        col = brightStar(col, q, c, rr, kk, starColor(hash(vec2(float(i), 8.0)) * 0.95));
    }

    // ── The gas giant, rising in the lower left, lit from behind and to the right ──
    vec2 pc = vec2(0.12, -0.18);
    float pr = 0.42;
    vec2 pq = q - pc;
    float pd = length(pq);
    vec3 L = normalize(vec3(0.7, 0.55, -0.4));
    // Its ring, seen from a little below its plane: the near half crosses in front
    // of the planet, the far half passes behind it, its underside dim. Ringlets,
    // a gap, and the planet's shadow falling across it.
    const float TILT = 0.3, OPEN = 0.3;
    vec2 rp = rot(pq, -TILT);
    float rr = length(vec2(rp.x, rp.y / OPEN)) / pr;
    float ringW = fwidth(rr);
    float ringA = smoothstep(1.45 - ringW, 1.45 + ringW, rr) * smoothstep(1.88 + ringW, 1.88 - ringW, rr);
    float ringlet = vnoise(vec2(rr * 30.0, 2.0)) + 0.4 * vnoise(vec2(rr * 80.0, 6.0));
    float gaps = smoothstep(0.008 - ringW, 0.008 + ringW, abs(rr - 1.74));
    vec3 ringC = mix(rgb(66, 60, 57), rgb(102, 92, 84), band(ringlet, 0.5));
    ringC = mix(ringC, rgb(140, 126, 110), band(ringlet, 0.82) * step(1.55, rr));
    float ringLit = smoothstep(0.1, 0.85, rp.x / (1.88 * pr));
    ringC = mix(ringC * 0.7, mix(ringC, rgb(196, 140, 90), 0.2), ringLit);
    // The ring point in 3D (planet radii), and whether the planet stands between it
    // and the light.
    vec3 P = vec3(rp.x, rp.y, sqrt(1.0 - OPEN * OPEN) * rp.y / OPEN) / pr;
    vec3 Lr = vec3(rot(L.xy, -TILT), L.z);
    float tl = dot(P, Lr);
    float shadow = step(tl, 0.0) * smoothstep(1.0, 0.97, length(P - tl * Lr));
    ringC = mix(ringC, rgb(30, 30, 31), shadow * 0.85);
    float ringAlpha = ringA * gaps * mix(0.6, 1.0, smoothstep(1.5, 1.58, rr));
    if (rp.y < 0.0)
        col = mix(col, ringC, ringAlpha);

    // Faint haze around the lit limb, in two steps.
    float facing = smoothstep(0.1, 0.7, dot(normalize(pq), normalize(L.xy)));
    col = mix(col, rgb(214, 93, 14), fill(pd - pr - 0.016) * facing * 0.14);
    col = mix(col, rgb(254, 128, 25), fill(pd - pr - 0.006) * facing * 0.24);
    if (pd < pr + PX * 2.0) {
        vec2 d = pq / pr;
        vec3 n = vec3(d, sqrt(max(0.0, 1.0 - dot(d, d))));
        // Bands along its equator, the ring's plane; its south pole tipped toward
        // us, so they curve with latitude.
        vec2 dt = rot(d, -TILT);
        float lat = dt.y * sqrt(1.0 - OPEN * OPEN) - n.z * OPEN;
        float lon = atan(dt.x, n.z);
        float wav = 0.006 * sin(lon * 6.0 + lat * 40.0) + 0.006 * (vnoise(vec2(lon * 8.0, lat * 60.0)) - 0.5);
        float zones = vnoise(vec2((lat + wav) * 26.0, 2.0)) + 0.3 * vnoise(vec2((lat + wav) * 70.0, 5.0));
        float belts = vnoise(vec2((lat + wav * 1.4) * 18.0, 8.0));
        vec3 body = mix(rgb(80, 73, 69), rgb(124, 111, 100), band(zones, 0.55));
        body = mix(body, rgb(168, 153, 132), band(zones, 0.9));
        body = mix(body, rgb(130, 88, 66), band(belts, 0.74));
        float lit = dot(n, L);
        vec3 night = mix(rgb(26, 28, 29), body, 0.14);
        vec3 dusk = mix(body * 0.5, rgb(150, 70, 30), 0.15);
        vec3 c = mix(night, dusk, band(lit, 0.42));
        c = mix(c, body, band(lit, 0.58));
        // The lit limb: warm crescents, each the disc less a larger one shifted away
        // from the light, so they taper to points round the limb.
        vec2 l2 = normalize(L.xy);
        c = mix(c, rgb(214, 93, 14), band(length(d + l2 * 0.17), 1.12));
        c = mix(c, rgb(250, 189, 47), band(length(d + l2 * 0.11), 1.09));
        col = mix(col, c, fill(pd - pr));
    }
    if (rp.y >= 0.0)
        col = mix(col, ringC, ringAlpha);

    // ── Its moon, a crescent lit from the same side ──
    {
        vec2 mc = vec2(0.56, 0.33);
        float mr = 0.026;
        vec2 md = (q - mc) / mr;
        float ml = length(md);
        if (ml < 1.2) {
            vec3 mn = vec3(md, sqrt(max(0.0, 1.0 - dot(md, md))));
            float lit = dot(mn, L);
            vec3 m = mix(rgb(44, 40, 40), rgb(124, 111, 100), band(lit, 0.0));
            m = mix(m, rgb(189, 174, 147), band(lit, 0.3));
            // Craters, darker on the lit side.
            for (int i = 0; i < 4; i++) {
                vec2 h = hash2(vec2(float(i), 91.0)) * 1.4 - 0.7;
                float cr = mix(0.12, 0.26, hash(vec2(float(i), 92.0)));
                m = mix(m, m * 0.8, fill((length(md - h) - cr) * mr) * band(lit, 0.0));
            }
            col = mix(col, m, fill((ml - 1.0) * mr));
        }
    }

    fragColor = vec4(col, 1.0);
}
