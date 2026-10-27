// Shared helpers for element shaders. Coordinates are screen pixels unless noted.

float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

float vnoise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    vec2 w = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1, 0)), w.x),
               mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), w.x), w.y);
}

float fbm(vec2 p) {
    float a = 0.5, s = 0.0;
    for (int i = 0; i < 3; i++) { s += a * vnoise(p); p *= 2.03; a *= 0.5; }
    return s;
}

// Piecewise-linear noise in -0.5..0.5: straight runs between random kinks at whole x.
float zig(float x, float seed) {
    float i = floor(x), f = fract(x);
    return mix(hash(vec2(i, seed)), hash(vec2(i + 1.0, seed)), f) - 0.5;
}

vec2 rot(vec2 v, float a) {
    float c = cos(a), s = sin(a);
    return vec2(c * v.x - s * v.y, s * v.x + c * v.y);
}

// Divergence-free swirl: the curl of a scalar noise potential.
vec2 curl(vec2 p, float t) {
    float e = 0.05;
    vec2 q = p + vec2(0.0, t);
    float n1 = fbm(q + vec2(0, e)), n2 = fbm(q - vec2(0, e));
    float n3 = fbm(q + vec2(e, 0)), n4 = fbm(q - vec2(e, 0));
    return vec2(n1 - n2, -(n3 - n4)) / (2.0 * e);
}

// Value noise with quintic easing, so its slope (and a curl taken from it) has no
// kinks at the grid lines.
float vnoise5(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    vec2 w = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
    return mix(mix(hash(i), hash(i + vec2(1, 0)), w.x),
               mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), w.x), w.y);
}

// A smooth turbulent flow at q (in units of its largest swirls): the curl of two
// octaves of noise drifting past each other, mostly the broad one, so it bends
// lines into gentle sweeps without crinkling them.
vec2 swirl(vec2 q, float t) {
    const float e = 0.08;
    vec2 a = vec2(0.0, t), b = vec2(-0.7 * t, 5.0);
    #define POT(x) (vnoise5((x) + a) + 0.15 * vnoise5((x) * 1.9 + b))
    float n1 = POT(q + vec2(0, e)), n2 = POT(q - vec2(0, e));
    float n3 = POT(q + vec2(e, 0)), n4 = POT(q - vec2(e, 0));
    #undef POT
    return vec2(n1 - n2, n4 - n3) / (2.0 * e);
}

float sdRoundRect(vec2 p, vec2 halfSize, float r) {
    vec2 q = abs(p) - halfSize + r;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

float sdSeg(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a, ba = b - a;
    return length(pa - ba * clamp(dot(pa, ba) / max(dot(ba, ba), 1e-8), 0.0, 1.0));
}

// Pointed leaf along y: the lens between two circles of radius r set d apart.
float sdLeaf(vec2 p, float r, float d) {
    p = abs(p);
    float b = sqrt(r * r - d * d);
    return ((p.y - b) * d > p.x * b) ? length(p - vec2(0.0, b)) : length(p - vec2(-d, 0.0)) - r;
}

// Corner k of a lightning bolt's zigzag, in px: corners about P apart along x,
// unevenly, alternating up and down by uneven amounts up to A.
vec2 boltCorner(float k, float P, float A, float seed) {
    return vec2((k + 0.4 * (hash(vec2(k, seed + 5.0)) - 0.5)) * P,
                (mod(k, 2.0) * 2.0 - 1.0) * mix(0.3, 1.0, hash(vec2(k, seed))) * A);
}

// Distance from q (x along the bolt, y across it, px) to its zigzag of straight runs.
float boltDist(vec2 q, float P, float A, float seed) {
    float i = floor(q.x / P);
    float d = 1e3;
    for (int k = -1; k <= 1; k++) {
        float c = i + float(k);
        d = min(d, sdSeg(q, boltCorner(c, P, A, seed), boltCorner(c + 1.0, P, A, seed)));
    }
    return d;
}

// Anti-aliased hard step: the cel-shading primitive.
float band(float v, float t) {
    float w = fwidth(v) * 0.75;
    return smoothstep(t - w, t + w, v);
}

// Premultiplied color: `col` at coverage `a` laid over `under`.
vec4 over(vec4 under, vec3 col, float a) {
    return vec4(col, 1.0) * a + under * (1.0 - a);
}

// Ragged distance from an ignition point. A front sits where burnField == radius;
// the sim burns fuel along it and the reveal shows the panel inside it. `scale`
// grows the large wobbles for bigger fronts; the fine fray stays pixel-sized.
float burnField(vec2 p, vec2 origin, float scale) {
    vec2 q = (p - origin) * vec2(0.85, 1.15);
    float warp = (fbm(p / (55.0 * scale)) - 0.5) * 110.0 * scale + (vnoise(p / 14.0) - 0.5) * 18.0;
    return length(q) + warp;
}

// Nearest point on a log spiral around c with radius r0 * exp(-k * u) at angle
// th0 + spin * u, wobbling by `wobble` (fraction of the radius). Returns
// (distance to the spine in px, u there, spiral radius there, signed distance:
// > 0 outside the spine).
vec4 spiralCoord(vec2 p, vec2 c, float r0, float k, float th0, float spin, float wobble) {
    vec2 rel = p - c;
    float r = max(length(rel), 1.0);
    float base = (atan(rel.y, rel.x) - th0) * spin;
    float uR = log(r0 / r) / k;
    float u = base + round((uR - base) / 6.2831853) * 6.2831853;
    float R = r0 * exp(-k * u) * (1.0 + wobble * sin(u * 1.7 + th0 * 3.0));
    float sd = (r - R) / sqrt(1.0 + k * k);
    return vec4(abs(sd), u, R, sd);
}

// Antialiased coverage of a signed "inside" distance, robust to the jumps where
// spiralCoord switches windings.
float cover(float s) {
    float aa = clamp(fwidth(s), 1e-3, 1.5);
    return smoothstep(-aa, aa, s);
}

vec2 hash2(vec2 p) {
    return vec2(hash(p), hash(p + 17.31));
}

// Voronoi site of the cell around p, for cells of `size` px. Each grid square
// holds one site, jittered by `jitter` (0..1).
vec2 voronoiSite(vec2 p, float size, float jitter) {
    vec2 g = floor(p / size);
    vec2 best = vec2(0.0);
    float bestD = 1e9;
    for (int y = -1; y <= 1; y++)
        for (int x = -1; x <= 1; x++) {
            vec2 cell = g + vec2(x, y);
            vec2 site = (cell + 0.5 + (hash2(cell) - 0.5) * jitter) * size;
            float d = dot(p - site, p - site);
            if (d < bestD) { bestD = d; best = site; }
        }
    return best;
}

// Distance from p to the nearest Voronoi cell border (approximate).
float voronoiEdge(vec2 p, float size, float jitter) {
    vec2 a = voronoiSite(p, size, jitter);
    vec2 g = floor(p / size);
    float edge = 1e9;
    for (int y = -1; y <= 1; y++)
        for (int x = -1; x <= 1; x++) {
            vec2 cell = g + vec2(x, y);
            vec2 b = (cell + 0.5 + (hash2(cell) - 0.5) * jitter) * size;
            if (dot(b - a, b - a) < 1.0)
                continue;
            edge = min(edge, dot((a + b) * 0.5 - p, normalize(b - a)));
        }
    return edge;
}

// Arc length along the border of a rounded rect (half size `h`, corner radius `r`)
// to the border point nearest p, measured clockwise on screen from the top-left
// end of the top edge. The full loop is rrPerimeter(h, r). Points deep inside get a
// meaningless value; use it only near the border.
float rrPerimeter(vec2 h, float r) {
    return 4.0 * (h.x + h.y - 2.0 * r) + 6.2831853 * r;
}

float rrArc(vec2 p, vec2 h, float r) {
    float a = h.x - r, b = h.y - r, q = 1.5707963 * r;
    if (abs(p.x) <= a)
        return p.y < 0.0 ? p.x + a : 3.0 * a + 2.0 * q + 2.0 * b - p.x;
    if (abs(p.y) <= b)
        return p.x > 0.0 ? 2.0 * a + q + p.y + b : 4.0 * a + 3.0 * q + 3.0 * b - p.y;
    if (p.x > 0.0) {
        if (p.y < 0.0) { vec2 v = p - vec2(a, -b); return 2.0 * a + r * atan(v.x, -v.y); }
        vec2 v = p - vec2(a, b);
        return 2.0 * a + q + 2.0 * b + r * atan(v.y, v.x);
    }
    if (p.y > 0.0) { vec2 v = p - vec2(-a, b); return 4.0 * a + 2.0 * q + 2.0 * b + r * atan(-v.x, v.y); }
    vec2 v = p - vec2(-a, -b);
    return 4.0 * a + 3.0 * q + 4.0 * b + r * atan(-v.y, -v.x);
}

// The border point at arc length s (see rrArc), relative to the rect's center.
vec2 rrPoint(float s, vec2 h, float r) {
    float a = h.x - r, b = h.y - r, q = 1.5707963 * r;
    s = mod(s, rrPerimeter(h, r));
    if (s < 2.0 * a) return vec2(s - a, -h.y);
    s -= 2.0 * a;
    if (s < q) { float f = s / r; return vec2(a, -b) + r * vec2(sin(f), -cos(f)); }
    s -= q;
    if (s < 2.0 * b) return vec2(h.x, s - b);
    s -= 2.0 * b;
    if (s < q) { float f = s / r; return vec2(a, b) + r * vec2(cos(f), sin(f)); }
    s -= q;
    if (s < 2.0 * a) return vec2(a - s, h.y);
    s -= 2.0 * a;
    if (s < q) { float f = s / r; return vec2(-a, b) + r * vec2(-sin(f), cos(f)); }
    s -= q;
    if (s < 2.0 * b) return vec2(-h.x, b - s);
    s -= 2.0 * b;
    float f = s / r;
    return vec2(-a, -b) + r * vec2(-cos(f), -sin(f));
}
