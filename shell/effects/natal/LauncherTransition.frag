#version 440
#extension GL_GOOGLE_include_directive : enable
// The launcher itself through the transition. Opening, it shows through a skin of
// frost feathers that thaws from many points at once, each hole spreading at its own
// pace behind a bright melting edge, and the frost draws back to a rime of fine
// feathers clinging outside its corners and edges, which stays while it is open.
// Closing, it is wrapped as a present: two flaps of berry paper with a fine gold
// pattern swing up from its sides and fold over it, their pale inside showing until
// they turn, shaded by how they face the light and creased at the hinge, the second's
// hemmed edge shadowing the first; a gold ribbon wraps it both ways and a bow pops up
// where they cross; and the package lifts away, its shadow left behind.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 origin;        // px, this item's top-left on screen
    vec2 resolution;    // px, this item's size
    vec4 rect;          // px, the panel
    float radius;       // its corners' radius
    float capture;      // 1 draws the captured panel
    float thaw;         // 0..1 the frost thawing away
    float rime;         // 0..1 the rime grown
    float leave;        // 0..1 over the exit
    vec4 lift;          // the package: offset (px), scale, tilt (rad)
    float fade;         // the package's opacity as it goes
    vec4 cFrost;
    vec4 cIce;
    vec4 cFrostLit;
    vec4 cPaper;
    vec4 cPaperDeep;
    vec4 cPaperLit;
    vec4 cPaperBack;
    vec4 cPaperBackShade;
    vec4 cGold;
    vec4 cGoldDeep;
    vec4 cGoldLit;
    vec4 cShadow;
} u;
layout(binding = 1) uniform sampler2D source;
#include "../common/common.glsl"

float span(float x, float a, float b) { return clamp((x - a) / (b - a), 0.0, 1.0); }
float ease(float x) { return x * x * (3.0 - 2.0 * x); }

// Distance to a frost feather: a stem from the origin along +x, L long, with barbs
// slanting forward off both sides, longest near the root, unevenly.
float feather(vec2 q, float L, float seed) {
    if (L < 0.5 || q.x < -1.5 || q.x > L + 1.5 || abs(q.y) > 0.45 * L + 1.5)
        return 1e3;
    float d = sdSeg(q, vec2(0.0), vec2(L, 0.0));
    float sp = max(2.3, 0.17 * L);
    float ay = abs(q.y);
    float sideSeed = q.y > 0.0 ? 1.0 : 2.0;
    float k0 = floor((q.x - ay * 0.84) / sp);
    for (int i = 0; i <= 1; i++) {
        float k = (k0 + float(i)) * sp;
        if (k < 0.5 * sp || k > L - 0.5 * sp)
            continue;
        float len = (L - k) * 0.5 * mix(0.6, 1.0, hash(vec2(k + seed, sideSeed)));
        d = min(d, sdSeg(vec2(q.x, ay), vec2(k, 0.0), vec2(k, 0.0) + vec2(0.64, 0.77) * len));
    }
    return d;
}

// The frost skin over the panel: a pale veil, and feathers grown across it from
// scattered seeds, in cells of 44 px.
vec4 frostSkin(vec2 p) {
    const float CELL = 44.0;
    vec2 g = floor(p / CELL);
    float d = 1e3;
    for (int y = -1; y <= 1; y++)
        for (int x = -1; x <= 1; x++) {
            vec2 cell = g + vec2(x, y);
            vec2 root = (cell + 0.2 + 0.6 * hash2(cell)) * CELL;
            float ang = TAU * hash(cell + 3.7);
            vec2 dir = vec2(cos(ang), sin(ang));
            vec2 lq = p - root;
            float L = mix(24.0, 46.0, hash(cell + 5.3));
            d = min(d, feather(vec2(dot(lq, dir), dot(lq, vec2(-dir.y, dir.x))), L, cell.x * 7.0 + cell.y));
        }
    vec4 o = over(vec4(0.0), u.cFrost.rgb, 0.45);
    return over(o, u.cIce.rgb, 0.8 * cover(0.6 - d));
}

// The panel thawing: holes open round seeds 60 px apart, each from its own moment,
// ragged, behind a bright melting edge.
vec4 frosted(vec2 p, vec2 uv) {
    vec4 body = texture(source, uv);
    const float CELL = 60.0;
    vec2 g = floor(p / CELL);
    float best = 1e3;
    for (int y = -1; y <= 1; y++)
        for (int x = -1; x <= 1; x++) {
            vec2 cell = g + vec2(x, y);
            vec2 site = (cell + 0.5 + (hash2(cell) - 0.5) * 0.85) * CELL;
            best = min(best, length(p - site) / CELL * 0.75 + 0.55 * hash(cell + 7.7));
        }
    best += (fbm(p / 21.0) - 0.5) * 0.24;
    float melt = u.thaw * 1.5 - 0.1 - best;
    float frost = 1.0 - cover(melt);
    float rim = cover(melt + 0.05) * (1.0 - cover(melt));
    vec4 fr = frostSkin(p);
    vec4 o = fr * frost * body.a + body * (1.0 - fr.a * frost);
    return mix(o, vec4(u.cFrostLit.rgb, 1.0) * body.a, 0.85 * rim);
}

// The rime outside the border: feathers rooted on the edge about 7 px apart, long and
// fanning out at the corners, short and sparse along the edges.
vec4 rimeAt(vec2 q, vec2 h, float r, float grow) {
    float P = rrPerimeter(h, r);
    float s = rrArc(q, h, r);
    float n = floor(P / 7.0);
    float sp = P / n;
    float a = h.x - r, b = h.y - r, qq = 1.5707963 * r;
    vec4 mids = vec4(2.0 * a + 0.5 * qq, 2.0 * a + 2.0 * b + 1.5 * qq, 4.0 * a + 2.0 * b + 2.5 * qq, 4.0 * a + 4.0 * b + 3.5 * qq);
    float j0 = floor(s / sp);
    float d = 1e3;
    for (int i = -2; i <= 2; i++) {
        float j = mod(j0 + float(i), n);
        float sj = (j + 0.5 + 0.6 * (hash(vec2(j, 3.3)) - 0.5)) * sp;
        // How near a corner it grows, and which side of it.
        vec4 off = sj - mids;
        off = off - P * floor(off / P + 0.5);
        vec4 ao = abs(off);
        float near = min(min(ao.x, ao.y), min(ao.z, ao.w));
        float toward = near == ao.x ? off.x : near == ao.y ? off.y : near == ao.z ? off.z : off.w;
        float cn = exp(-near / 20.0);
        if (hash(vec2(j, 5.1)) > mix(0.22, 1.0, cn))
            continue;
        vec2 root = rrPoint(sj, h, r);
        vec2 t = normalize(rrPoint(sj + 0.5, h, r) - rrPoint(sj - 0.5, h, r) + 1e-6);
        vec2 dir = rot(vec2(t.y, -t.x), (hash(vec2(j, 7.7)) - 0.5) * 0.9 + sign(toward) * 0.55 * cn);
        float L = mix(4.5, 16.0, cn) * mix(0.55, 1.15, hash(vec2(j, 9.9))) * grow;
        vec2 lq = q - root;
        d = min(d, feather(vec2(dot(lq, dir), dot(lq, vec2(-dir.y, dir.x))), L, j));
    }
    return vec4(u.cIce.rgb, 1.0) * 0.8 * cover(0.5 - d);
}

// The gold pattern on the paper: small six-pointed stars on a staggered lattice, each
// turned its own way and a little larger or smaller.
float pattern(vec2 f) {
    const float S = 22.0;
    vec2 g = f / S;
    g.x += 0.5 * mod(floor(g.y), 2.0);
    vec2 cell = floor(g);
    vec2 m = rot((fract(g) - 0.5) * S, hash(cell) * 1.05);
    float d = 1e3;
    for (int i = 0; i < 3; i++) {
        vec2 dir = vec2(cos(float(i) * PI / 3.0), sin(float(i) * PI / 3.0)) * mix(2.6, 3.4, hash(cell + 2.1));
        d = min(d, sdSeg(m, -dir, dir));
    }
    return cover(0.55 - d);
}

// A flap of paper hinged at the panel's side (side -1 left, 1 right), turned phi from
// lying folded over the panel (0) back out past upright (PI). Nearer the viewer as it
// stands, its free edge looms taller.
vec4 flap(vec4 under, vec2 q, vec2 h, float r, float phi, float side) {
    float W = 2.0 * h.x * 0.62;
    float c = cos(phi), sn = sin(phi);
    if (abs(c) < 0.015)
        return under;
    float x = side < 0.0 ? q.x + h.x : h.x - q.x;
    float uu = x / c;
    float y = q.y / (1.0 + 0.32 * max(uu, 0.0) * sn / W);
    vec2 f = vec2(side < 0.0 ? -h.x + uu : h.x - uu, y);
    float d = max(sdRoundRect(f, h + 0.75, r), uu - W);
    // The flap's shadow along its free edge on what it covers, once it lies flat.
    float sh = cover(-max(sdRoundRect(f, h, r), abs(uu - W - 1.6) - 1.6)) * smoothstep(0.75, 1.0, c) * 0.35;
    under = over(under, u.cShadow.rgb, sh * under.a);
    if (d > 2.0)
        return under;
    bool front = c > 0.0;
    vec3 nrm = front ? vec3(side * sn, 0.0, c) : vec3(-side * sn, 0.0, -c);
    float lam = dot(nrm, normalize(vec3(-0.45, -0.5, 0.75)));
    vec3 col;
    if (front) {
        col = mix(u.cPaperDeep.rgb, u.cPaper.rgb, band(lam, 0.35));
        col = mix(col, u.cPaperLit.rgb, band(lam, 0.8));
        vec3 gold = mix(u.cGoldDeep.rgb, u.cGold.rgb, band(lam, 0.35));
        col = mix(col, gold, pattern(f + vec2(side * 7.0, side * 5.0)) * smoothstep(0.25, 0.6, abs(c)));
    } else {
        col = mix(u.cPaperBackShade.rgb, u.cPaperBack.rgb, band(lam, 0.4));
    }
    // Creased at the hinge; the free edge turned under in a hem.
    col = mix(col, col * 0.72, cover(1.6 - uu));
    col = mix(col, mix(col, u.cPaperLit.rgb, 0.35), band(uu, W - 3.5));
    col = mix(col, col * 0.7, cover(0.6 - abs(uu - W + 3.5)));
    return over(under, col, cover(-d));
}

// Two crossed ribbons, a bow where they cross, at cross: each band wraps in from the
// panel's edges as grow runs 0..1.
vec4 ribbon(vec4 o, vec2 q, vec2 h, vec2 cr, float w, float gv, float gh, float inside) {
    // Vertical, then horizontal over it: shadow, band, darker edges, a line of sheen.
    float shownV = max(cover(-h.y + gv * (cr.y + h.y) - q.y), cover(q.y - (h.y - gv * (h.y - cr.y))));
    float shownH = max(cover(-h.x + gh * (cr.x + h.x) - q.x), cover(q.x - (h.x - gh * (h.x - cr.x))));
    shownV *= step(0.001, gv);
    shownH *= step(0.001, gh);
    float dv = abs(q.x - cr.x) - w;
    float dh = abs(q.y - cr.y) - w;
    o = over(o, u.cPaperDeep.rgb * 0.7, 0.5 * inside * shownV * cover(-(abs(q.x - cr.x - 1.5) - w)));
    vec3 cv = mix(u.cGold.rgb, u.cGoldDeep.rgb, cover(dv + 1.1));
    cv = mix(cv, u.cGoldLit.rgb, cover(0.7 - abs(q.x - cr.x + 0.4 * w)));
    o = over(o, cv, inside * shownV * cover(-dv));
    o = over(o, u.cGoldDeep.rgb * 0.75, 0.55 * inside * shownH * cover(-(abs(q.y - cr.y - 1.6) - w)));
    vec3 ch = mix(u.cGold.rgb, u.cGoldDeep.rgb, cover(dh + 1.1));
    ch = mix(ch, u.cGoldLit.rgb, cover(0.7 - abs(q.y - cr.y + 0.4 * w)));
    return over(o, ch, inside * shownH * cover(-dh));
}

float sdUnevenCapsule(vec2 q, float r1, float r2, float hh) {
    q.x = abs(q.x);
    float b = (r1 - r2) / hh;
    float a = sqrt(1.0 - b * b);
    float k = dot(q, vec2(-b, a));
    if (k < 0.0)
        return length(q) - r1;
    if (k > a * hh)
        return length(q - vec2(0.0, hh)) - r2;
    return dot(q, vec2(a, b)) - r1;
}

// A bow loop from the knot out along dir: a teardrop, its opening in shade.
vec2 loopDist(vec2 b, vec2 dir, float R, float L) {
    vec2 n = vec2(-dir.y, dir.x);
    vec2 lq = vec2(dot(b, n), dot(b, dir));
    float outer = sdUnevenCapsule(lq, 0.1, R, L);
    float hole = sdUnevenCapsule(lq - vec2(0.05 * sign(dir.x), 0.2), 0.02, R * 0.5, L * 0.68);
    return vec2(outer, hole);
}

// A tail from the knot to its end, a little curved, cut in a swallowtail.
float tailDist(vec2 b, vec2 end) {
    float len = length(end);
    vec2 dir = end / len, n = vec2(-dir.y, dir.x);
    float t = dot(b, dir);
    float w = mix(0.12, 0.16, clamp(t / len, 0.0, 1.0));
    float ac = dot(b, n) - 0.07 * sin(PI * clamp(t / len, 0.0, 1.0)) * sign(end.x);
    return max(abs(ac) - w, max(-t, t - len + 0.13 * (1.0 - min(abs(ac) / w, 1.0))));
}

// The bow, in units of its size: tails, two loops, and the knot; each part edged in
// deeper gold and shaded away from the light, over its shadow.
vec4 bow(vec4 o, vec2 b, float px) {
    vec2 tl = vec2(-0.52, 0.95), tr = vec2(0.62, 0.86);
    vec2 dl = normalize(vec2(-1.0, -0.45)), drr = normalize(vec2(1.0, -0.33));
    vec2 sb = b - vec2(0.05, 0.08);
    vec2 sl = loopDist(sb, dl, 0.32, 0.6), sr = loopDist(sb, drr, 0.35, 0.66);
    float sd = min(min(tailDist(sb, tl), tailDist(sb, tr)), min(min(sl.x, sr.x), sdRoundRect(sb, vec2(0.14, 0.15), 0.06)));
    o = over(o, u.cShadow.rgb, 0.4 * cover(-sd));
    float rimW = 1.1 / px;
    // Tails, a shade deeper, folded on one half.
    for (int i = 0; i < 2; i++) {
        vec2 e = i == 0 ? tl : tr;
        float d = tailDist(b, e);
        vec3 c = mix(u.cGold.rgb, u.cGoldDeep.rgb, 0.3 + 0.4 * band(dot(b, vec2(-e.y, e.x)) * sign(e.x), 0.0));
        c = mix(c, u.cGoldDeep.rgb * 0.85, cover(d + rimW));
        o = over(o, c, cover(-d));
    }
    // Loops.
    for (int i = 0; i < 2; i++) {
        vec2 dir = i == 0 ? dl : drr;
        vec2 l = i == 0 ? loopDist(b, dl, 0.32, 0.6) : loopDist(b, drr, 0.35, 0.66);
        float lit = dot(normalize(b - dir * 0.5 + 1e-4), vec2(-0.55, -0.83));
        vec3 c = mix(u.cGoldDeep.rgb, u.cGold.rgb, band(lit, -0.25));
        c = mix(c, u.cGoldLit.rgb, band(lit, 0.6) * 0.8);
        c = mix(c, u.cGoldDeep.rgb * 0.85, cover(l.x + rimW));
        c = mix(c, mix(u.cGoldDeep.rgb, u.cShadow.rgb, 0.35), cover(-l.y));
        o = over(o, c, cover(-l.x));
    }
    // The knot, pinched in two creases.
    float k = sdRoundRect(b, vec2(0.14, 0.15), 0.06);
    vec3 kc = mix(u.cGold.rgb, u.cGoldLit.rgb, band(-(b.x + b.y), 0.06) * 0.8);
    kc = mix(kc, u.cGoldDeep.rgb, cover(0.6 * rimW - abs(abs(b.x) - 0.06)) * 0.6);
    kc = mix(kc, u.cGoldDeep.rgb * 0.85, cover(k + rimW));
    return over(o, kc, cover(-k));
}

void main() {
    vec2 p = u.origin + qt_TexCoord0 * u.resolution;
    vec2 h = 0.5 * u.rect.zw;
    vec2 c = u.rect.xy + h;
    float r = min(u.radius, min(h.x, h.y));
    vec2 q = p - c;
    float dr = sdRoundRect(q, h, r);
    vec4 o = vec4(0.0);

    // ── The rime outside the border ──
    if (u.rime > 0.0 && dr > -1.0 && dr < 20.0)
        o = rimeAt(q, h, r, u.rime);

    if (u.leave <= 0.0) {
        // ── The panel thawing out of the frost ──
        if (u.capture > 0.5 && dr < 1.0) {
            vec4 body = frosted(p, (p - u.rect.xy) / u.rect.zw);
            o = body + o * (1.0 - body.a);
        }
        fragColor = o * u.qt_Opacity;
        return;
    }

    // ── The package's shadow, left where it stood as it lifts ──
    float up = span(u.leave, 0.5, 1.0);
    if (up > 0.0) {
        float sd = sdRoundRect(q - vec2(0.0, 6.0), h - 4.0 * up, r);
        float a = 0.34 * smoothstep(0.0, 0.2, up) * (1.0 - up);
        o = over(o, u.cShadow.rgb, a * (0.55 * cover(-sd) + 0.45 * cover(-sd - 8.0)));
    }

    // ── The package, in its own frame ──
    vec2 k = rot(q - u.lift.xy, -u.lift.w) / u.lift.z;
    float kd = sdRoundRect(k, h, r);
    vec4 pk = vec4(0.0);
    if (kd < 1.0) {
        vec2 uv = (k + h) / u.rect.zw;
        pk = texture(source, uv);
    }
    float L = u.leave;
    pk = flap(pk, k, h, r, mix(0.78 * PI, 0.0, ease(span(L, 0.0, 0.24))), -1.0);
    pk = flap(pk, k, h, r, mix(0.78 * PI, 0.0, ease(span(L, 0.07, 0.31))), 1.0);
    vec2 cr = vec2(0.3 * h.x, -0.16 * h.y);
    float w = clamp(min(h.x, h.y) * 0.075, 6.0, 12.0);
    float gv = ease(span(L, 0.28, 0.4)), gh = ease(span(L, 0.31, 0.43));
    if (gv > 0.0)
        pk = ribbon(pk, k, h, cr, w, gv, gh, cover(-kd));
    float pop = span(L, 0.4, 0.53);
    if (pop > 0.0) {
        // Popping up a little past its size, then settling.
        float s = 1.0 + 2.7 * pow(pop - 1.0, 3.0) + 1.7 * pow(pop - 1.0, 2.0);
        float K = clamp(min(h.x, h.y) * 0.55, 36.0, 84.0) * max(s, 0.01);
        vec2 b = rot(k - cr, 0.25 * (1.0 - pop)) / K;
        if (abs(b.x) < 1.2 && b.y > -0.9 && b.y < 1.2)
            pk = bow(pk, b, K);
    }
    o = pk * u.fade + o * (1.0 - pk.a * u.fade);
    fragColor = o * u.qt_Opacity;
}
