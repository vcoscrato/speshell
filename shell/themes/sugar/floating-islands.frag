#version 440
#extension GL_GOOGLE_include_directive : enable
// Sugar heaven: waffle cones floating in the sky at the golden hour over a sea of
// whipped cream, each heaped with cream that drips over its rim. The greatest, left
// of the sun, carries a rotunda of white sugar and a grove of meringue trees, with
// strawberries lying in its cream and a rolled wafer stuck in it; an islet floats
// under its lip, and broken bits of cone drift round it. Smaller cones drift further
// off, paler with the distance, with a tower of sugar under a fondant roof, meringue
// trees, or a strawberry of their own. Towers of candyfloss
// stand on the horizon and rise out of the nearer cream, lit pink on the sun's side;
// the sun shines in rings, its rays fanning through the sky, and powdered sugar drifts
// down through the light, the highest grains glittering in the dusk.
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
vec2 SUN;

// Coverage of a signed distance in q, without derivatives, so it is safe anywhere.
float fill(float d) {
    return smoothstep(PX, -PX, d);
}

// Five-stop sky ramp, horizon to zenith.
vec3 sky(float t) {
    vec3 a = rgb(255, 234, 200), b = rgb(253, 204, 176), c = rgb(240, 160, 166);
    vec3 d = rgb(182, 112, 156), e = rgb(88, 56, 104);
    if (t < 0.2) return mix(a, b, t / 0.2);
    if (t < 0.45) return mix(b, c, (t - 0.2) / 0.25);
    if (t < 0.72) return mix(c, d, (t - 0.45) / 0.27);
    return mix(d, e, (t - 0.72) / 0.28);
}

// The distance to the edge of a heap's puffs `from` to `to` (0 the highest, 15 the
// lowest); see heap(). From 0, a core fills the gaps the puffs leave between them.
float puffs(vec2 q, vec2 c, float w, float h, float seed, int from, int to) {
    vec2 pc = q - c;
    pc.y -= clamp(pc.y, 0.0, h * 0.65);
    float d = from == 0 ? length(pc) - w * 0.38 : 1e5;
    for (int i = from; i <= to; i++) {
        float t = 1.0 - float(i) / 15.0;
        vec2 hh = hash2(vec2(float(i), seed));
        float r = w * mix(0.62, 0.3, t) * (0.8 + 0.4 * hh.y);
        vec2 o = vec2(c.x + (hh.x - 0.5) * 1.6 * w * (1.0 - 0.65 * t), c.y + t * h);
        d = min(d, length(q - o) - r);
    }
    return d;
}

// A tower of candyfloss on its foot c, w half wide and h high: puffs heaped up, the
// lower in front. It is lit as one body in three flat tones, not ball by ball: light
// along its edge toward the sun, a band of shade along the edge away from it, and the
// front puffs lit along their own edges, which shapes it into billows.
vec3 heap(vec3 col, vec2 q, vec2 c, float w, float h, float seed, vec3 lit, vec3 mid, vec3 shade, vec3 rim, vec3 hz, float haze) {
    if (abs(q.x - c.x) > w * 1.8 || q.y > c.y + h + w)
        return col;
    float dAll = puffs(q, c, w, h, seed, 0, 15);
    if (dAll > PX)
        return col;
    vec2 toSun = normalize(SUN - c + vec2(0.0, 0.25 * h));
    // The front puffs, where they are, else the whole.
    float dFront = puffs(q, c, w, h, seed, 9, 15);
    bool front = dFront < 0.0;
    int from = front ? 9 : 0;
    float lightBand = w * 0.16, shadeBand = w * 0.3;
    // Lit near the edge toward the sun, unless the way there crosses deep through a
    // puff, which would light slivers inside notches of the edge.
    float dl = min(puffs(q + toSun * lightBand, c, w, h, seed, from, 15),
                   puffs(q + toSun * lightBand * 0.6, c, w, h, seed, from, 15) + lightBand * 0.4);
    float dsh = puffs(q - toSun * shadeBand, c, w, h, seed, 0, 15);
    vec3 m = mid;
    m = mix(m, shade, 1.0 - fill(dsh));
    m = mix(m, lit, 1.0 - fill(dl));
    // A rim of light right at its sunny edge.
    float sunward = 1.0 - fill(puffs(q + toSun * w * 0.05, c, w, h, seed, 0, 15));
    m = mix(m, rim, (1.0 - fill(dAll + w * 0.025)) * sunward);
    return mix(col, mix(m, hz, haze), fill(dAll));
}

// Billows of the sea of cream, uneven: now and then a broader swell rides among them,
// and their height wanders along the bank (0..1-ish).
float swell(float x, float freq, float seed) {
    float broad = 0.85 * lobes(x + 0.29 / freq, freq * 0.45, seed + 23.0) + 0.1;
    return max(billows(x, freq, seed), broad) * (0.75 + 0.5 * vnoise(vec2(x * freq * 0.3, seed + 31.0)));
}

// The top of an island's cream at x, for island() of the same c, w, H, and seed.
float islandTop(float x, vec2 c, float w, float H, float seed) {
    float dx = (x - c.x) / w;
    return c.y + H * pow(max(0.0, 1.0 - dx * dx), 0.35) * (0.7 + 0.3 * billows(x / w, 3.0, seed));
}

// A floating island, its top at c, w half wide: a cone of waffle D deep, its lattice
// of ridges wrapping round it and its rolled rim at the top, lit toward the sun, under
// a layer of whipped cream H thick that drips over its lip.
vec3 island(vec3 col, vec2 q, vec2 c, float w, float H, float D, float seed, vec3 hz, float haze) {
    float dx = (q.x - c.x) / w;
    float env = max(0.0, 1.0 - dx * dx);
    float sx = sign(SUN.x - c.x);

    // The cone, leaning a little, and how far round it a point lies, -1..1.
    float depth = (c.y - q.y) / D;
    float lean = 0.12 * (hash(vec2(seed, 1.0)) - 0.5);
    float hw = pow(max(0.0, 1.0 - depth), 0.92);
    float across = (dx - lean * depth) / max(hw, 1e-3);
    float waffle = smoothstep(1.0 + PX / w / max(hw, 0.02), 1.0, abs(across)) * cover(c.y + H * 0.2 - q.y) * step(depth, 1.0);
    float u = asin(clamp(across, -1.0, 1.0));
    float light = sin(u) * sx;
    vec3 wc = light > 0.42 ? rgb(240, 186, 112) : light > -0.2 ? rgb(218, 148, 86) : light > -0.7 ? rgb(188, 116, 74) : rgb(156, 90, 70);
    // Its lattice: straight ridges crossing both ways, raised and pale, over
    // pressed-in cells, each shadowed on the side away from the sun.
    float n = 4.2;
    float la = (dx - lean * depth) * n, lb = depth * D / w * n * 0.7;
    float aa = PX / w * n * 1.5;
    float f1 = fract(la + lb), f2 = fract(la - lb);
    float g = min(min(f1, 1.0 - f1), min(f2, 1.0 - f2));
    float ridge = smoothstep(0.1 + aa, 0.1, g);
    float side = (f1 < 0.5 ? 1.0 : -1.0) * sx;
    vec3 pressed = mix(wc, rgb(150, 82, 62), 0.22);
    pressed = mix(pressed, mix(wc, rgb(122, 64, 54), 0.42), smoothstep(0.1, 0.18 + aa, g) * (1.0 - smoothstep(0.18, 0.28, g)) * step(0.0, -side));
    wc = mix(pressed, mix(wc * 1.06, rgb(255, 220, 160), 0.18 * step(0.0, light + 0.2)), ridge);
    // Its rolled rim, just under the cream.
    float rim = cover(depth - 0.0) * (1.0 - smoothstep(0.075, 0.075 + PX / D, depth));
    wc = mix(wc, mix(wc * 1.08, rgb(248, 204, 140), 0.3), rim);
    wc = mix(wc, wc * 0.7, rim * (1.0 - band(abs(depth - 0.075), 0.012)));
    // The pink of the cream below, on its lowest part.
    wc = mix(wc, mix(wc, rgb(214, 132, 150), 0.3), smoothstep(0.75, 1.0, depth));
    col = mix(col, mix(wc, hz, haze), waffle);

    // The cream, in billows over the top and drips of uneven length over the lip.
    float top = islandTop(q.x, c, w, H, seed);
    float cell = w * 0.08;
    float f = fract(q.x / cell) * 2.0 - 1.0;
    float len = H * (0.2 + 1.6 * pow(hash(vec2(floor(q.x / cell), seed + 9.0)), 2.5)) * pow(max(0.0, 1.0 - f * f), 0.3);
    float creamFill = cover(top - q.y) * cover(q.y - (c.y - len * step(0.1, env))) * step(abs(dx), 0.99);
    float term = dx * sx + 0.35;
    vec3 cr = mix(rgb(236, 202, 212), rgb(255, 246, 238), smoothstep(-0.4, 0.4, term));
    cr = mix(cr, rgb(255, 230, 206), (1.0 - band(top - q.y, H * 0.12)) * smoothstep(0.0, 0.5, term));
    cr = mix(cr, mix(cr, rgb(210, 166, 186), 0.5), 1.0 - band(q.y, c.y + H * 0.05));
    col = mix(col, mix(cr, hz, haze), creamFill);

    return col;
}

// A rotunda of white sugar standing on b, `s` its unit: a plinth, five columns round a
// shaded hall, a cornice, and a ribbed dome with a finial of gold, lit toward the sun.
vec3 rotunda(vec3 col, vec2 q, vec2 b, float s) {
    vec2 p = (q - b) / s;
    float e = PX / s;
    float sx = sign(SUN.x - b.x);
    vec3 lit = rgb(255, 248, 240), mid = rgb(240, 212, 214), shade = rgb(206, 160, 182), hall = rgb(150, 100, 132);
    vec3 m = col;
    // The hall behind the columns.
    float inHall = smoothstep(e, -e, abs(p.x) - 2.0) * smoothstep(-e, e, p.y - 0.5) * smoothstep(e, -e, p.y - 3.0);
    m = mix(m, hall, inHall);
    // The columns, each lit on its sunny side.
    for (int i = 0; i < 5; i++) {
        float cx = -1.8 + 0.9 * float(i);
        float d = abs(p.x - cx) - 0.24;
        float on = smoothstep(e, -e, d) * smoothstep(-e, e, p.y - 0.5) * smoothstep(e, -e, p.y - 3.0);
        vec3 cc = mix(mid, lit, step(0.0, (p.x - cx) * sx));
        cc = mix(cc, shade, step(1.5, abs(cx)) * step((p.x - cx) * sx, 0.0) * 0.6);
        m = mix(m, cc, on);
    }
    // Plinth and cornice: steps lit on top.
    float plinth = smoothstep(e, -e, abs(p.x) - 2.4) * smoothstep(-e, e, p.y + 0.6) * smoothstep(e, -e, p.y - 0.5);
    m = mix(m, mix(mid, lit, smoothstep(-e, e, p.y - 0.25)), plinth);
    float cornice = smoothstep(e, -e, abs(p.x) - 2.25) * smoothstep(-e, e, p.y - 3.0) * smoothstep(e, -e, p.y - 3.5);
    m = mix(m, mix(mid, lit, smoothstep(-e, e, p.y - 3.3)), cornice);
    // The dome, in three tones with a rib down it, and its finial.
    vec2 dp = (p - vec2(0.0, 3.5)) / vec2(2.0, 1.7);
    float dome = smoothstep(e * 2.0, -e * 2.0, length(dp) - 1.0) * smoothstep(-e, e, p.y - 3.5);
    vec3 dc = mix(shade, mid, smoothstep(-0.3, -0.2, dp.x * sx));
    dc = mix(dc, lit, smoothstep(0.15, 0.25, dp.x * sx + dp.y * 0.6));
    dc = mix(dc, mid, 1.0 - smoothstep(0.06 - e, 0.06 + e, abs(dp.x * 2.0 - 0.5 * sx)));
    m = mix(m, dc, dome);
    float stem = smoothstep(e, -e, abs(p.x) - 0.08) * smoothstep(-e, e, p.y - 5.1) * smoothstep(e, -e, p.y - 5.7);
    float knob = smoothstep(e, -e, length(p - vec2(0.0, 5.8)) - 0.22);
    m = mix(m, rgb(236, 186, 104), max(stem, knob));
    m = mix(m, rgb(255, 230, 170), knob * smoothstep(0.0, 0.1, (p.x * sx) + 0.05) * step(5.82, p.y));
    return m;
}

// A tree of piped meringue standing on b, s its half width at the foot, `tall` its
// height in s: tiers of meringue, each flaring out over the one below with a ruffled
// hem, lit toward the sun and shadowed under each hem, a gold dragée on top.
vec3 rosette(vec3 col, vec2 q, vec2 b, float s, float tall, vec3 lit, vec3 mid, vec3 shade, vec3 hz, float haze) {
    vec2 p = (q - b) / s;
    if (abs(p.x) > 1.4 || p.y < -0.3 || p.y > tall + 0.6)
        return col;
    float e = PX / s;
    float t = clamp(p.y / tall, 0.0, 1.0);
    float tiers = 4.0;
    // fr runs 0 at a tier's hem to 1 at its top, where the next one's hem covers it.
    float fr = fract(t * tiers - 0.08 * cos(p.x * 9.0));
    float base = 1.0 - t * 0.92;
    float wdt = base * (0.42 + 0.58 * pow(1.0 - fr, 0.6));
    float body = smoothstep(e, -e, abs(p.x) - wdt) * smoothstep(-e, e, p.y) * smoothstep(e, -e, p.y - tall);
    float sx = sign(SUN.x - b.x);
    float u = p.x / max(wdt, 1e-3) * sx;
    vec3 m = mix(shade, mid, smoothstep(-0.45, -0.35, u));
    m = mix(m, lit, smoothstep(0.2, 0.3, u));
    // The shadow under each hem.
    m = mix(m, shade, smoothstep(0.75, 0.8, fr) * 0.8);
    col = mix(col, mix(m, hz, haze), body);
    float dg = length(p - vec2(0.0, tall + 0.15)) - 0.2;
    vec3 gold = mix(rgb(214, 160, 86), rgb(255, 232, 170), step(0.0, p.x * sx + 0.05));
    return mix(col, mix(gold, hz, haze), smoothstep(e, -e, dg));
}

// A tower of white sugar standing on b, `s` its unit: a round shaft with arched
// windows, a gallery with a balustrade near the top, and a cone roof of strawberry
// fondant with a finial of gold, lit toward the sun.
vec3 tower(vec3 col, vec2 q, vec2 b, float s, vec3 hz, float haze) {
    vec2 p = (q - b) / s;
    if (abs(p.x) > 2.0 || p.y < -0.3 || p.y > 10.2)
        return col;
    float e = PX / s;
    float sx = sign(SUN.x - b.x);
    vec3 lit = rgb(255, 248, 240), mid = rgb(240, 212, 214), shade = rgb(206, 160, 182), dark = rgb(150, 100, 132);
    vec3 m = col;
    float cov = 0.0;
    // The shaft, tapering a little.
    float sw = 1.0 - 0.012 * p.y;
    float shaft = smoothstep(e, -e, abs(p.x) - sw) * smoothstep(-e, e, p.y) * smoothstep(e, -e, p.y - 5.2);
    float u = p.x / sw * sx;
    vec3 sc = mix(shade, mid, smoothstep(-0.45, -0.35, u));
    sc = mix(sc, lit, smoothstep(0.2, 0.3, u));
    m = mix(m, sc, shaft);
    cov = max(cov, shaft);
    // Arched windows, and a door.
    for (int i = 0; i < 3; i++) {
        vec2 wp = p - (i == 0 ? vec2(0.0, 0.0) : vec2(-0.2 * sx, 0.6 + 1.9 * float(i)));
        float hw = i == 0 ? 0.32 : 0.18, hh = i == 0 ? 0.75 : 0.6;
        float d = wp.y < hh ? abs(wp.x) - hw : length(wp - vec2(0.0, hh)) - hw;
        m = mix(m, dark, smoothstep(e, -e, d) * smoothstep(-e, e, wp.y) * shaft);
    }
    // The gallery: a ledge on a band of corbels, and a balustrade along it.
    float ledge = smoothstep(e, -e, abs(p.x) - 1.3) * smoothstep(-e, e, p.y - 5.2) * smoothstep(e, -e, p.y - 5.5);
    float corbel = smoothstep(e, -e, abs(p.x) - 1.1) * smoothstep(-e, e, p.y - 4.85) * smoothstep(e, -e, p.y - 5.2)
        * step(0.45, fract(p.x * 2.2 + 0.25));
    float rail = smoothstep(e, -e, abs(p.x) - 1.22) * smoothstep(-e, e, p.y - 5.5) * smoothstep(e, -e, p.y - 6.0)
        * max(step(5.88, p.y), step(0.5, fract(p.x * 3.0)));
    m = mix(m, mix(mid, lit, smoothstep(-e, e, p.y - 5.38)), ledge);
    m = mix(m, mix(shade, mid, step(0.0, p.x * sx)), max(corbel, rail));
    cov = max(cov, max(ledge, max(corbel, rail)));
    // The roof, a cone flaring at its eaves.
    float ry = (p.y - 6.0) / 3.2;
    float rw = 1.45 * pow(max(0.0, 1.0 - ry), 1.25);
    float roof = smoothstep(e, -e, abs(p.x) - rw) * smoothstep(-e, e, p.y - 5.95) * smoothstep(e, -e, ry - 1.0);
    float ru = p.x / max(rw, 1e-3) * sx;
    vec3 rc = mix(rgb(192, 88, 122), rgb(238, 128, 156), smoothstep(-0.35, -0.25, ru));
    rc = mix(rc, rgb(255, 176, 192), smoothstep(0.3, 0.4, ru));
    rc = mix(rc, rgb(170, 76, 110), (1.0 - smoothstep(0.0, 0.35, ry)) * smoothstep(-e, e, 6.25 - p.y) * 0.5);
    m = mix(m, rc, roof);
    cov = max(cov, roof);
    float stem = smoothstep(e, -e, abs(p.x) - 0.07) * smoothstep(-e, e, p.y - 9.1) * smoothstep(e, -e, p.y - 9.7);
    float knob = smoothstep(e, -e, length(p - vec2(0.0, 9.8)) - 0.2);
    m = mix(m, mix(rgb(222, 170, 96), rgb(255, 230, 170), step(0.0, p.x * sx + 0.04)), max(stem, knob));
    cov = max(cov, max(stem, knob));
    return mix(col, mix(m, hz, haze), cov);
}

// A strawberry lying in the cream at b, s long, tilted by `tilt`: its body broad at
// the shoulders and narrowing to the tip, in reds lit toward the sun, dotted with
// seeds, under a star of green leaves.
vec3 strawberry(vec3 col, vec2 q, vec2 b, float s, float tilt, vec3 hz, float haze) {
    vec2 p = rot(q - b, -tilt) / s;
    if (dot(p, p) > 1.6)
        return col;
    float e = PX / s * 1.2;
    float sx = sign(SUN.x - b.x);
    // y runs from the tip, -0.6, to the shoulders, 0.4.
    float y = clamp((p.y + 0.6) / 1.0, 0.0, 1.0);
    float wdt = 0.42 * pow(y, 0.6) * sqrt(max(0.0, 1.0 - pow(max(0.0, (p.y - 0.25) / 0.2), 2.0)));
    float body = smoothstep(e, -e, abs(p.x) - wdt) * smoothstep(-0.6 - e, -0.6 + e, p.y) * step(p.y, 0.46);
    vec2 ls = rot(vec2(sx, 0.4), tilt);
    float u = p.x / max(wdt, 1e-3) * sign(ls.x);
    vec3 m = mix(rgb(176, 36, 62), rgb(222, 58, 78), smoothstep(-0.45, -0.35, u));
    m = mix(m, rgb(250, 110, 112), smoothstep(0.3, 0.4, u) * smoothstep(-0.5, 0.0, p.y));
    // Seeds, in staggered rows, each in its dimple.
    vec2 sg = vec2(p.x / max(wdt, 0.05) * 2.2, p.y * 7.0);
    sg.x += 0.5 * mod(floor(sg.y), 2.0);
    vec2 sc = fract(sg) - 0.5;
    float seed = smoothstep(0.17, 0.11, length(sc * vec2(1.0, 1.3))) * step(abs(u), 0.92) * step(p.y, 0.3);
    m = mix(m, rgb(252, 214, 130), seed * 0.9);
    col = mix(col, mix(m, hz, haze), body);
    // The leaves: five points from the top, and a stub of stalk.
    vec2 lp = p - vec2(0.0, 0.42);
    float ang = atan(lp.x, -lp.y);
    float rr = length(lp);
    float lobe = abs(fract(ang / 1.2566 + 0.5) - 0.5) * 2.0;
    float leaf = smoothstep(e, -e, rr - 0.36 * (1.0 - 0.75 * lobe)) * step(-0.12, lp.y + 0.2 * (1.0 - lobe));
    vec3 lc = mix(rgb(70, 132, 74), rgb(124, 184, 96), step(0.0, lp.x * sign(ls.x)));
    col = mix(col, mix(lc, hz, haze), leaf);
    float stalk = smoothstep(e, -e, abs(lp.x) - 0.035) * step(0.0, lp.y) * step(lp.y, 0.18);
    return mix(col, mix(rgb(96, 150, 80), hz, haze), stalk);
}

// A rolled wafer stuck in the cream at b, its far end at b + dir * len, `r` its radius:
// golden, spiralled with rolled seams, lit toward the sun, its open end showing the
// rolls inside.
vec3 wafer(vec3 col, vec2 q, vec2 b, vec2 dir, float len, float r, vec3 hz, float haze) {
    vec2 nrm = vec2(-dir.y, dir.x);
    vec2 d = q - b;
    float along = dot(d, dir), off = dot(d, nrm);
    if (along < -r || along > len + r * 2.0 || abs(off) > r * 2.0)
        return col;
    float sx = sign(dot(SUN - b, nrm));
    float tube = fill(abs(off) - r) * fill(-along) * fill(along - len);
    float u = off / r * sx;
    vec3 m = mix(rgb(196, 128, 70), rgb(232, 172, 98), smoothstep(-0.5, -0.35, u));
    m = mix(m, rgb(252, 214, 150), smoothstep(0.35, 0.5, u));
    float seam = fract((along + off * 0.6) / (r * 1.6));
    m = mix(m, m * 0.72, smoothstep(0.0, 0.06, seam) * (1.0 - smoothstep(0.1, 0.18, seam)));
    // Dipped in chocolate at its far end.
    float dip = smoothstep(len * 0.72 - PX, len * 0.72 + PX, along + off * 0.25);
    vec3 ch = mix(rgb(70, 38, 40), rgb(126, 74, 62), smoothstep(-0.2, 0.0, u));
    ch = mix(ch, rgb(196, 140, 120), fill(abs(u - 0.5) * r - r * 0.08));
    m = mix(m, ch, dip);
    col = mix(col, mix(m, hz, haze), tube);
    // Its open end, an ellipse.
    vec2 ep = vec2(dot(q - b - dir * len, dir) / (r * 0.4), off / r);
    float end = fill((length(ep) - 1.0) * r * 0.4);
    vec3 em = mix(rgb(176, 112, 64), rgb(110, 62, 46), fill((length(ep) - 0.6) * r * 0.4));
    return mix(col, mix(mix(em, rgb(80, 44, 42), 0.5), hz, haze), end);
}

// A glint: four points of light.
float glint(vec2 q, vec2 c, float r) {
    vec2 d = abs(q - c) / r;
    return fill((sqrt(d.x) + sqrt(d.y) - 1.0) * r * 0.5);
}

void main() {
    vec2 px = qt_TexCoord0 * u.resolution;
    vec2 q = vec2(px.x, u.resolution.y - px.y) / u.resolution.y;
    PX = 1.0 / u.resolution.y;
    float aspect = u.resolution.x / u.resolution.y;
    SUN = vec2(aspect * 0.63, 0.47);
    float ds = length(q - SUN);
    float horizon = 0.34;

    // Sky in flat bands, warmest round the sun.
    float t = clamp((q.y - horizon) / (1.0 - horizon), 0.0, 1.0);
    t = pow(t, 0.85) - 0.16 * exp(-ds * 2.6) + (fbm(vec2(q.x * 1.2, q.y * 4.0)) - 0.5) * 0.04;
    vec3 col = sky(steps(clamp(t, 0.0, 1.0), 12.0));

    // Sugar glittering high in the dusk.
    float hi = smoothstep(0.7, 0.95, q.y);
    col = mix(col, rgb(255, 236, 230), starField(q, 0.03, 0.4, 3.0, 0.0024, PX * 0.8, PX) * hi);

    // Long wisps of spun sugar, plum with sunlit undersides.
    float env = smoothstep(0.6, 0.68, q.y) * (1.0 - smoothstep(0.86, 0.95, q.y));
    float n = fbm(vec2(q.x * 1.1, q.y * 12.0) + vec2(2.0, 7.0)) + 0.2 * vnoise(vec2(q.x * 5.0, q.y * 36.0));
    float nLow = fbm(vec2(q.x * 1.1, (q.y + 0.007) * 12.0) + vec2(2.0, 7.0)) + 0.2 * vnoise(vec2(q.x * 5.0, (q.y + 0.007) * 36.0));
    float streak = band(n * env, 0.6);
    float warm = exp(-abs(q.x - SUN.x) * 1.3);
    col = mix(col, mix(rgb(164, 98, 142), rgb(220, 128, 146), warm), streak);
    col = mix(col, mix(rgb(240, 156, 156), rgb(255, 212, 176), warm), streak * (1.0 - band(nLow * env, 0.6)));

    // The sun's rays, fanning out through the sky, each its own width.
    float ang = atan(q.y - SUN.y, q.x - SUN.x);
    float ray = band(vnoise(vec2(ang * 7.0, 4.0)) + 0.25 * sin(ang * 23.0), 0.62);
    float rays = ray * exp(-ds * 2.2) * smoothstep(horizon, horizon + 0.05, q.y) * (1.0 - smoothstep(0.7, 0.92, q.y));

    // The sun, in rings of light.
    col = mix(col, mix(col, rgb(255, 226, 190), 0.14), cover(0.24 - ds));
    col = mix(col, mix(col, rgb(255, 234, 202), 0.26), cover(0.14 - ds));
    col = mix(col, rgb(255, 244, 222), cover(0.065 - ds));

    // Towers of candyfloss on the horizon, pale with the distance.
    vec3 hz = mix(rgb(252, 204, 186), rgb(255, 228, 198), exp(-abs(q.x - SUN.x) * 2.0));
    vec3 cLit = rgb(255, 228, 216), cMid = rgb(244, 186, 198), cShade = rgb(198, 148, 192), cRim = rgb(255, 238, 214);
    col = heap(col, q, vec2(aspect * 0.08, horizon - 0.02), 0.12, 0.28, 1.0, cLit, cMid, cShade, cRim, hz, 0.35);
    col = heap(col, q, vec2(aspect * 0.9, horizon - 0.02), 0.1, 0.2, 2.0, cLit, cMid, cShade, cRim, hz, 0.4);
    col = heap(col, q, vec2(aspect * 0.5, horizon - 0.02), 0.07, 0.1, 3.0, cLit, cMid, cShade, cRim, hz, 0.5);
    col = heap(col, q, vec2(aspect * 0.76, horizon - 0.02), 0.05, 0.06, 4.0, cLit, cMid, cShade, cRim, hz, 0.55);
    col = mix(col, rgb(255, 238, 212), rays * 0.2);

    // The far sea of cream, bright with the sun, and its gleam under it.
    float h0 = horizon + 0.012 * billows(q.x, 12.0, 1.0);
    col = mix(col, hz, below(h0, q.y));
    float gleam = exp(-abs(q.x - SUN.x) * 6.0) * (1.0 - band(abs(q.y - horizon + 0.004), 0.004));
    col = mix(col, rgb(255, 240, 216), below(h0, q.y) * gleam * 0.8);

    // Distant islands, small and hazed: one with a tower, one with a grove.
    vec3 mLit = rgb(255, 246, 240), mMid = rgb(244, 214, 220), mShade = rgb(212, 166, 190);
    vec2 d1 = vec2(aspect * 0.93, 0.66), d2 = vec2(aspect * 0.5, 0.58);
    col = island(col, q, d1, 0.035, 0.008, 0.05, 7.0, hz, 0.5);
    col = tower(col, q, vec2(d1.x - 0.006, islandTop(d1.x - 0.006, d1, 0.035, 0.008, 7.0) - 0.002), 0.0034, hz, 0.5);
    col = island(col, q, d2, 0.026, 0.006, 0.035, 8.0, hz, 0.58);
    for (int i = 0; i < 3; i++) {
        float x = d2.x + (float(i) - 1.0) * 0.009;
        col = rosette(col, q, vec2(x, islandTop(x, d2, 0.026, 0.006, 8.0) - 0.001), 0.0032, i == 1 ? 3.6 : 2.6, mLit, mMid, mShade, hz, 0.58);
    }

    // Banks of cream, rolling toward the viewer.
    float rimSun = exp(-abs(q.x - SUN.x) * 1.6);
    float h1 = horizon - 0.02 + 0.03 * swell(q.x + 0.4, 4.5, 2.0);
    col = mix(col, rgb(244, 192, 186), below(h1, q.y));
    col = mix(col, mix(rgb(252, 214, 198), rgb(255, 236, 210), rimSun), below(h1, q.y) * (1.0 - below(h1 - 0.006, q.y)));

    // An island nearer, toward the sun, with a tower, meringue trees, and
    // a strawberry, and a bit of cone drifting under it.
    vec2 near = vec2(aspect * 0.8, 0.53);
    vec2 bit = near + vec2(0.06, -0.1);
    col = island(col, q, bit, 0.012, 0.0025, 0.017, 15.0, hz, 0.24);
    col = rosette(col, q, vec2(bit.x + 0.001, islandTop(bit.x + 0.001, bit, 0.012, 0.0025, 15.0) - 0.001), 0.0042, 2.6, mLit, mMid, mShade, hz, 0.24);
    col = island(col, q, near, 0.075, 0.016, 0.1, 5.0, hz, 0.22);
    col = tower(col, q, vec2(near.x - 0.014, islandTop(near.x - 0.014, near, 0.075, 0.016, 5.0) - 0.003), 0.0072, hz, 0.22);
    col = rosette(col, q, vec2(near.x + 0.03, islandTop(near.x + 0.03, near, 0.075, 0.016, 5.0) - 0.002), 0.0095, 3.2, mLit, mMid, mShade, hz, 0.22);
    col = rosette(col, q, vec2(near.x + 0.05, islandTop(near.x + 0.05, near, 0.075, 0.016, 5.0) - 0.002), 0.007, 2.6, mLit, mMid, mShade, hz, 0.22);
    col = strawberry(col, q, vec2(near.x - 0.05, islandTop(near.x - 0.05, near, 0.075, 0.016, 5.0) + 0.004), 0.018, 1.0, hz, 0.22);

    // The great island, and an islet under its lip with two meringue trees.
    vec2 isle = vec2(aspect * 0.28, 0.55);
    vec2 islet = vec2(isle.x + 0.165, 0.43);
    col = island(col, q, islet, 0.05, 0.012, 0.07, 6.0, hz, 0.08);
    for (int i = 0; i < 2; i++) {
        float x = islet.x + (i == 0 ? -0.008 : 0.016);
        col = rosette(col, q, vec2(x, islandTop(x, islet, 0.05, 0.012, 6.0) - 0.003), i == 0 ? 0.011 : 0.008, i == 0 ? 3.3 : 2.7, mLit, mMid, mShade, hz, 0.08);
    }
    // Broken bits of cone drifting under it, each with its cap of cream: a strawberry
    // lying on one, a little meringue tree on the other.
    vec2 bitA = isle + vec2(-0.21, -0.1), bitB = isle + vec2(0.07, -0.21);
    col = island(col, q, bitA, 0.024, 0.005, 0.034, 11.0, hz, 0.06);
    col = strawberry(col, q, vec2(bitA.x - 0.002, islandTop(bitA.x - 0.002, bitA, 0.024, 0.005, 11.0) + 0.003), 0.016, 0.9, hz, 0.06);
    col = island(col, q, bitB, 0.017, 0.0035, 0.024, 13.0, hz, 0.06);
    col = rosette(col, q, vec2(bitB.x + 0.002, islandTop(bitB.x + 0.002, bitB, 0.017, 0.0035, 13.0) - 0.001), 0.006, 2.7, mLit, mMid, mShade, hz, 0.06);
    col = island(col, q, isle, 0.17, 0.03, 0.22, 2.0, hz, 0.0);
    // A grove of meringue trees beside the rotunda.
    for (int i = 0; i < 4; i++) {
        float x = isle.x + (i == 0 ? -0.075 : i == 1 ? -0.104 : i == 2 ? -0.128 : 0.07);
        float sz = i == 0 ? 0.016 : i == 1 ? 0.012 : i == 2 ? 0.0095 : 0.013;
        float tl = i == 0 ? 3.4 : i == 1 ? 3.0 : i == 2 ? 2.6 : 3.1;
        col = rosette(col, q, vec2(x, islandTop(x, isle, 0.17, 0.03, 2.0) - 0.004), sz, tl, mLit, mMid, mShade, hz, 0.0);
    }
    if (abs(q.x - isle.x) < 0.06 && q.y > isle.y && q.y < isle.y + 0.14)
        col = rotunda(col, q, isle + vec2(0.0, 0.032), 0.02);
    // A wafer stuck in its cream, and strawberries lying in it.
    float wx = isle.x + 0.112;
    col = wafer(col, q, vec2(wx, islandTop(wx, isle, 0.17, 0.03, 2.0) - 0.006), normalize(vec2(0.42, 1.0)), 0.12, 0.0085, hz, 0.0);
    float sx1 = isle.x + 0.135, sx2 = isle.x - 0.145, sx3 = isle.x + 0.092;
    col = strawberry(col, q, vec2(sx1, islandTop(sx1, isle, 0.17, 0.03, 2.0) + 0.006), 0.034, -1.05, hz, 0.0);
    col = strawberry(col, q, vec2(sx3, islandTop(sx3, isle, 0.17, 0.03, 2.0) + 0.008), 0.028, 0.35, hz, 0.0);
    col = strawberry(col, q, vec2(sx2, islandTop(sx2, isle, 0.17, 0.03, 2.0) + 0.005), 0.026, 1.2, hz, 0.0);

    float h2 = 0.27 + 0.04 * swell(q.x + 0.9, 3.2, 3.0);
    col = mix(col, rgb(234, 176, 180), below(h2, q.y));
    col = mix(col, mix(rgb(250, 208, 198), rgb(255, 230, 206), rimSun), below(h2, q.y) * (1.0 - below(h2 - 0.007, q.y)));
    float u2 = h2 - 0.045 + 0.03 * swell(q.x + 4.1, 6.5, 12.0);
    col = mix(col, rgb(216, 154, 166), below(u2, q.y) * below(h2, q.y));

    // Candyfloss rising out of the nearer cream.
    vec3 nLit = rgb(250, 202, 206), nMid = rgb(226, 158, 180), nShade = rgb(174, 116, 158), nRim = rgb(255, 222, 200);
    col = heap(col, q, vec2(aspect * 0.6, 0.2), 0.06, 0.07, 21.0, nLit, nMid, nShade, nRim, hz, 0.1);
    col = heap(col, q, vec2(aspect * 1.0, 0.18), 0.1, 0.1, 22.0, nLit, nMid, nShade, nRim, hz, 0.1);

    float h3 = 0.17 + 0.05 * swell(q.x + 1.7, 2.6, 4.0);
    col = mix(col, rgb(196, 124, 150), below(h3, q.y));
    col = mix(col, mix(rgb(226, 156, 166), rgb(248, 192, 176), rimSun), below(h3, q.y) * (1.0 - below(h3 - 0.009, q.y)));
    float u3 = h3 - 0.055 + 0.035 * swell(q.x + 2.9, 4.0, 13.0);
    col = mix(col, rgb(172, 104, 138), below(u3, q.y));

    float h4 = 0.06 + 0.06 * swell(q.x + 2.3, 1.8, 5.0);
    col = mix(col, rgb(130, 78, 116), below(h4, q.y));
    col = mix(col, rgb(180, 116, 140), below(h4, q.y) * (1.0 - below(h4 - 0.01, q.y)));

    // Candyfloss close by, in the lower left, in the shadow of the evening.
    col = heap(col, q, vec2(0.02, -0.06), 0.2, 0.16, 23.0, rgb(214, 140, 164), rgb(166, 98, 138), rgb(116, 70, 112), rgb(246, 180, 176), hz, 0.0);

    // Powdered sugar drifting down through the light: the nearer grains larger and
    // fainter, and a few catching the sun.
    for (int i = 0; i < 70; i++) {
        float fi = float(i);
        vec2 h = hash2(vec2(fi, 31.0));
        float near = pow(hash(vec2(fi, 32.0)), 3.0);
        vec2 c = vec2(h.x * aspect, mix(0.05, 0.95, h.y));
        float r = mix(0.0012, 0.006, near);
        col = mix(col, rgb(255, 246, 236), fill(length(q - c) - r) * mix(0.9, 0.45, near));
    }
    for (int i = 0; i < 12; i++) {
        float fi = float(i);
        vec2 h = hash2(vec2(fi, 41.0));
        vec2 c = SUN + (h - 0.5) * vec2(1.1, 0.6);
        col = mix(col, rgb(255, 250, 240), glint(q, c, mix(0.005, 0.011, hash(vec2(fi, 42.0)))) * 0.9);
    }

    fragColor = vec4(col, 1.0);
}
