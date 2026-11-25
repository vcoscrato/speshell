#version 440
#extension GL_GOOGLE_include_directive : enable
// Worked out once for each transition: when frost reaches each point of the screen and
// how high it stands there, and when it thaws. Crystals start at the screen's corners,
// along its edges, and later at a few specks inside it; each grows a fan of fronds: a
// curved spine with branches leaning toward its tip on both sides, longest near its
// root, and barbs along the longer branches. Spines grow fastest, branches out from
// them, barbs last, and the matte frost between fills in behind them, so the frost
// arrives as a dendrite. Each crystal claims what it reaches first, and what comes
// late is hurried in, in the same order, so all of it is in by growEnd. The thaw spreads
// from a few warm spots, gathering speed, lobed and ragged at two scales.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 resolution;
    float seed;
    float growEnd;      // s, by when everything has frosted
    float thawEnd;      // s, by when everything has thawed
    float thawScale;    // the furthest any point lies from the spots, in their reaches
    vec4 spot0;         // warm spots: center (px), start (s), reach (px)
    vec4 spot1;
    vec4 spot2;
    vec4 spot3;
    vec4 spot4;
    vec4 spot5;
} u;
#include "../common/common.glsl"

float S;                // px per px of a 1080 px tall screen
float bestT, bestH;     // the earliest arrival so far, and the height there

float rnd(float i, float k) {
    return hash(vec2(i * 7.13 + k * 1.71, u.seed * 91.7 + k * 3.1));
}

// One frond's spine: angle, curvature, length (px), speed (px/s).
struct Spine { float a; float bend; float len; float speed; };

// Arrival time along a line from a point that froze at t0: it widens to half width w
// over 0.2 s, and past w hardly at all, so the fill takes over.
float lineT(float t0, float d, float w) {
    return t0 + d * 0.2 / w + max(d - w, 0.0) * 0.05;
}

void keep(float t, float h) {
    if (t < bestT) {
        bestT = t;
        bestH = h;
    }
}

// The barbs along one branch, in its frame: a along it from its root, c across.
void barbs(vec2 q, float id, float lb, float tRoot, float speed) {
    if (lb < 26.0 * S)
        return;
    float side = sign(q.y);
    float w2 = abs(q.y);
    float sp = mix(6.0, 9.0, rnd(id, 20.0)) * S;
    float beta = mix(0.85, 1.05, rnd(id, 21.0));
    float cb = cos(beta), sb = sin(beta);
    float a0 = q.x - w2 * cb / sb;
    float off = side < 0.0 ? 0.5 : 0.0;
    float m0 = floor(a0 / sp - off);
    for (int k = 0; k <= 1; k++) {
        float m = m0 + float(k);
        float am = (m + off + 0.3 * (rnd(id + m * 0.37, 22.0) - 0.5)) * sp;
        if (am < 2.0 * S || am > lb)
            continue;
        float x = am / lb;
        float lc = min(0.32 * lb, 17.0 * S) * pow(1.0 - x, 0.7) * mix(0.45, 1.0, rnd(id + m * 0.37, 23.0));
        vec2 r = vec2(q.x - am, w2);
        float along = dot(r, vec2(cb, sb));
        float d = sdSeg(r, vec2(0.0), vec2(cb, sb) * lc);
        float w = 0.75 * S;
        float t = lineT(tRoot + am / speed + clamp(along, 0.0, lc) / (speed * 1.4), d, w);
        keep(t, 0.45 * max(1.0 - d / w, 0.0));
    }
}

// The branches of one spine, in its frame: u along it from the root, v across.
void branches(vec2 q, float id, Spine s, float t0) {
    float side = sign(q.y);
    float w = abs(q.y);
    float sp = mix(15.0, 23.0, rnd(id, 10.0)) * S;
    float off = side < 0.0 ? 0.5 : 0.0;
    float u0 = q.x - w * 0.62;
    float n0 = floor(u0 / sp - off);
    float vb = s.speed * 0.62;
    float bestD = 1e9;
    vec2 bq = vec2(0.0);
    float bid = 0.0, blb = 0.0, bt = 0.0;
    for (int k = -1; k <= 1; k++) {
        float n = n0 + float(k);
        float bi = id * 3.7 + n * 0.53 + off * 11.0;
        float un = (n + off + 0.35 * (rnd(bi, 11.0) - 0.5)) * sp;
        if (un < 4.0 * S || un > s.len * 0.94)
            continue;
        float x = un / s.len;
        float lb = 0.4 * s.len * pow(1.0 - x, 0.9) * smoothstep(0.0, 0.12, x) * mix(0.45, 1.0, rnd(bi, 12.0));
        if (rnd(bi, 13.0) < 0.1)
            lb *= 0.3;
        lb = min(lb, 150.0 * S);
        float al = mix(0.78, 1.05, rnd(bi, 14.0));
        vec2 dir = vec2(cos(al), sin(al));
        vec2 r = vec2(q.x - un, w);
        float a = dot(r, dir);
        float c = dir.x * r.y - dir.y * r.x;
        // Each branch bows a little toward the spine's tip.
        c += 0.25 * a * a / max(lb, 1.0) * (rnd(bi, 15.0) - 0.3);
        float d = (a < 0.0) ? length(vec2(a, c)) : (a > lb ? length(vec2(a - lb, c)) : abs(c));
        float tr = t0 + un / s.speed * (1.0 + 0.35 * un / s.len);
        float wb = mix(1.55, 0.6, clamp(a / lb, 0.0, 1.0)) * S;
        float t = lineT(tr + clamp(a, 0.0, lb) / vb, d, wb);
        keep(t, 0.72 * max(1.0 - d / wb, 0.0));
        if (d < bestD) {
            bestD = d;
            bq = vec2(a, c);
            bid = bi;
            blb = lb;
            bt = tr;
        }
    }
    if (bestD < 20.0 * S)
        barbs(bq, bid, blb, bt, vb);
}

// Crystal i: root, start, the direction it grows in, its spines' reach, and how many.
void crystal(vec2 p, float i, vec2 root, vec2 dir, float t0, float reach, float fan, int count) {
    vec2 rel = p - root;
    float r = length(rel);
    float speed = 1.6 * reach / mix(0.62, 0.8, rnd(i, 1.0));
    float fillSpeed = speed * 0.5;
    // Nothing of it can come earlier than its spines' fastest.
    if (t0 + max(r - reach * 0.4, 0.0) / speed > bestT)
        return;
    // The matte frost between its fronds, in blotches.
    float rf = r + 0.45 * reach * (fbm(p / (110.0 * S) + vec2(i * 5.3, u.seed * 11.0)) - 0.5);
    keep(t0 + 0.06 + max(rf, 0.0) / fillSpeed, 0.0);
    float phi = atan(rel.y, rel.x);
    float a0 = atan(dir.y, dir.x);
    for (int j = 0; j < 5; j++) {
        if (j >= count)
            break;
        float id = i * 5.0 + float(j);
        float fj = count > 1 ? float(j) / float(count - 1) - 0.5 : 0.0;
        Spine s;
        s.a = a0 + fan * fj + 0.35 * fan / float(count) * (rnd(id, 2.0) - 0.5) + (count > 1 ? 0.0 : 0.4 * (rnd(id, 2.0) - 0.5));
        s.bend = 0.7 * (rnd(id, 3.0) - 0.5);
        s.len = reach * mix(0.55, 1.0, rnd(id, 4.0));
        s.speed = speed;
        float ang = s.a + s.bend * (r / s.len) * (r / s.len);
        float dphi = phi - ang;
        dphi = dphi - TAU * floor(dphi / TAU + 0.5);
        if (abs(dphi) > 1.4)
            continue;
        vec2 q = vec2(r * cos(dphi), r * sin(dphi));
        if (abs(q.y) > 0.45 * s.len + 12.0 * S || q.x > s.len * 1.05 + 10.0 * S)
            continue;
        float ws = mix(2.8, 0.9, clamp(q.x / s.len, 0.0, 1.0)) * S;
        float ds = q.x > s.len ? length(q - vec2(s.len, 0.0)) : abs(q.y);
        float ts = t0 + clamp(q.x, 0.0, s.len) / s.speed * (1.0 + 0.35 * clamp(q.x, 0.0, s.len) / s.len);
        keep(lineT(ts, ds, ws), max(1.0 - ds / ws, 0.0));
        branches(q, id, s, t0);
    }
}

// Point x along the screen's border, clockwise from the top-left corner, just outside
// it, and the way in there.
void border(float x, float W, float H, out vec2 at, out vec2 inward) {
    float o = 3.0 * S;
    if (x < W) { at = vec2(x, -o); inward = vec2(0.0, 1.0); return; }
    x -= W;
    if (x < H) { at = vec2(W + o, x); inward = vec2(-1.0, 0.0); return; }
    x -= H;
    if (x < W) { at = vec2(W - x, H + o); inward = vec2(0.0, -1.0); return; }
    x -= W;
    at = vec2(-o, H - x);
    inward = vec2(1.0, 0.0);
}

float thawOf(vec2 p, vec4 s, float i) {
    if (s.w <= 0.0)
        return 1e3;
    // Drawn out sideways, as a breath spreads, and a little tilted.
    vec2 rel = rot(p - s.xy, 0.5 * (rnd(i, 30.0) - 0.5)) * vec2(1.0, 1.6);
    float r = length(rel);
    vec2 dir = rel / max(r, 1.0);
    // Lobed, and ragged along its edge, never further than its plain reach.
    float lobe = 1.0 - 0.4 * fbm(dir * 2.2 + vec2(i * 7.0, u.seed * 13.0));
    lobe *= 1.0 - 0.22 * fbm(p / (60.0 * S) + vec2(i * 3.0, u.seed * 7.0));
    float d = r * lobe / s.w / u.thawScale;
    // Slow to open, then spreading faster, so the last of the frost goes briskly.
    return s.z + (u.thawEnd - s.z) * pow(min(d, 1.0), 0.8);
}

void main() {
    vec2 p = qt_TexCoord0 * u.resolution;
    float W = u.resolution.x, H = u.resolution.y;
    S = H / 1080.0;
    bestT = 1e3;
    bestH = 0.0;

    // The corners first, then the edges, then specks inside.
    for (int c = 0; c < 4; c++) {
        float i = float(c);
        vec2 root = vec2(c == 1 || c == 2 ? W : 0.0, c >= 2 ? H : 0.0);
        vec2 inward = normalize(vec2(c == 1 || c == 2 ? -1.0 : 1.0, c >= 2 ? -1.0 : 1.0));
        root -= inward * 4.0 * S;
        crystal(p, i, root, rot(inward, 0.3 * (rnd(i, 5.0) - 0.5)), 0.05 * rnd(i, 6.0),
                H * mix(0.5, 0.66, rnd(i, 7.0)), 1.45, 4);
    }
    float nW = max(1.0, floor(W / (300.0 * S) + 0.5));
    float nH = max(1.0, floor(H / (300.0 * S) + 0.5));
    float total = 2.0 * (nW + nH);
    for (int e = 0; e < 32; e++) {
        float k = float(e);
        if (k >= total)
            break;
        float i = 4.0 + k;
        // Even shares of each side, jittered.
        float side = k < nW ? 0.0 : (k < nW + nH ? 1.0 : (k < 2.0 * nW + nH ? 2.0 : 3.0));
        float first = side == 0.0 ? 0.0 : (side == 1.0 ? nW : (side == 2.0 ? nW + nH : 2.0 * nW + nH));
        float n = mod(side, 2.0) == 0.0 ? nW : nH;
        float len = mod(side, 2.0) == 0.0 ? W : H;
        float start = side == 0.0 ? 0.0 : (side == 1.0 ? W : (side == 2.0 ? W + H : 2.0 * W + H));
        float x = start + (k - first + 0.5 + 0.6 * (rnd(i, 5.0) - 0.5)) / n * len;
        vec2 root, inward;
        border(x, W, H, root, inward);
        crystal(p, i, root, rot(inward, 0.7 * (rnd(i, 6.0) - 0.5)), mix(0.04, 0.24, rnd(i, 7.0)),
                H * mix(0.28, 0.52, rnd(i, 8.0)), mix(1.1, 1.7, rnd(i, 9.0)), 2 + int(rnd(i, 10.0) * 1.99));
    }
    float nIn = clamp(floor(W / H * 3.4 + 0.5), 4.0, 8.0);
    for (int s = 0; s < 8; s++) {
        float k = float(s);
        if (k >= nIn)
            break;
        float i = 40.0 + k;
        vec2 root = vec2((k + 0.2 + 0.6 * rnd(i, 5.0)) / nIn * W, mix(0.22, 0.78, rnd(i, 6.0)) * H);
        float a = TAU * rnd(i, 7.0);
        crystal(p, i, root, vec2(cos(a), sin(a)), mix(0.14, 0.3, rnd(i, 8.0)),
                H * mix(0.28, 0.4, rnd(i, 9.0)), mix(2.0, 2.8, rnd(i, 10.0)), 3 + int(rnd(i, 11.0) * 1.99));
    }
    // The fill a little blotchy; past g0 what comes late is hurried in, its order kept,
    // all of it by growEnd.
    float tf = bestT + 0.1 * (fbm(p / (80.0 * S) + u.seed * 17.0) - 0.5) * step(bestH, 0.0);
    const float LATE = 0.32;
    float g0 = u.growEnd - LATE;
    tf = tf > g0 ? g0 + LATE * 0.97 * (1.0 - exp((g0 - tf) / LATE)) : tf;

    float tt = min(min(min(thawOf(p, u.spot0, 0.0), thawOf(p, u.spot1, 1.0)), min(thawOf(p, u.spot2, 2.0), thawOf(p, u.spot3, 3.0))),
                   min(thawOf(p, u.spot4, 4.0), thawOf(p, u.spot5, 5.0)));
    // Nothing thaws before it has frosted a while. Stored less a second, which half
    // floats hold finer; the fronds' thick ice is left to the shader drawing it, so the
    // thaw's slope stays smooth across them.
    tt = min(max(tt, tf + 0.45), u.thawEnd);
    fragColor = vec4(tf, bestH, tt - 1.0, 1.0);
}
