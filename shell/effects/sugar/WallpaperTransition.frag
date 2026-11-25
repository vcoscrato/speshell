#version 440
#extension GL_GOOGLE_include_directive : enable
// Glaze poured from above over the old wallpaper. Each stretch of the screen runs at
// its own pace and tongues race ahead of the rest, so the lower edge never sweeps
// straight; under it hang drips of every width and length, some swelling into a bead
// that stretches its neck, lets go, and falls with a droplet behind it. The glaze piles
// into a rounded rim along that edge and round every drip, lit from the upper left and
// shaded in bands, with slow folds in its surface that carry the sheen down with the
// flow, and a soft shadow on the wallpaper below. Behind the pour it thins out in
// runnels, translucent over the new wallpaper, and slides off the bottom with the old.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 resolution;
    float progress;     // 0..1
    float seed;         // 0..1, a new pour each time
    vec4 cInk;
    vec4 cFrost;
    vec4 cFrostLight;
    vec4 cFrostShade;
    vec4 cFilm;
} u;
layout(binding = 1) uniform sampler2D source;
#include "../common/common.glsl"

float W, H, S, D, CELL;
const float THICK = 0.3;        // the opaque glaze's length, a share of the height
const float FILM = 0.11;        // how far its thin tail reaches behind it at most
const float FALL = 2.6;         // a falling bead's pull, screen heights per second squared
const float POUR = 1.7;         // seconds the pour takes

// Smooth noise along x, 0..1, one random value at each whole x.
float n1(float x, float s) {
    float i = floor(x), f = fract(x);
    return mix(hash(vec2(i, s)), hash(vec2(i + 1.0, s)), f * f * (3.0 - 2.0 * f));
}

// The glaze's body at column x: how far its smooth front has run, broad stretches
// of the screen running faster or slower.
float body(float x) {
    return -0.17 * H + 0.11 * H * n1(x / (W * 0.13), S) + D * (0.8 + 0.24 * n1(x / (W * 0.21), S + 3.0));
}

// The tongues that race ahead of the body's front at column x, growing as the pour
// goes on.
float tongue(float x) {
    float n = 0.65 * n1(x / (W * 0.085), S + 6.0) + 0.35 * n1(x / (W * 0.037), S + 8.0);
    n = smoothstep(0.3, 0.88, n);
    return D * 0.19 * n * n + 4.0 * sin(x / 41.0 + S);
}

void main() {
    vec2 p = qt_TexCoord0 * u.resolution;
    W = u.resolution.x;
    H = u.resolution.y;
    S = u.seed * 37.0;
    CELL = max(44.0, W / 32.0);
    float t = u.progress;
    // Gathering speed as it goes, until even its slowest tail is off the bottom.
    D = H * 2.12 * pow(t, 1.35);

    float bx = body(p.x);
    float top = bx - H * THICK * (0.85 + 0.3 * n1(p.x / (W * 0.13), S + 9.0));
    // Above the thin tail's furthest reach, only the new wallpaper.
    if (p.y < top - H * FILM * 1.3 - 4.0) {
        fragColor = vec4(0.0);
        return;
    }
    float tg = tongue(p.x);
    float fx = bx + tg;
    // Its slope, the tongues' taken a pixel apart, as their steep sides need.
    float fs = dFdx(bx) + tongue(p.x + 1.0) - tg;
    float db = (p.y - fx) / sqrt(1.0 + fs * fs);    // > 0 below the lower edge

    // The drips, joined to the edge by a smooth minimum that fillets where they meet,
    // and the beads that fell from them; none reach deep into the glaze, and far below
    // its edge only the falling beads.
    float k1 = floor(p.x / CELL);
    bool deep = p.y < fx - 60.0;
    bool far = p.y > fx + 0.3 * H;
    vec4 drops = vec4(0.0);
    vec3 glint = vec3(-1e4, -1e4, 1.0); // the nearest bead's center and radius
    for (int j = -1; j <= 1; j++) {
        float k = k1 + float(j);
        vec4 h = vec4(hash(vec2(k, S)), hash(vec2(k, S + 1.0)), hash(vec2(k, S + 2.0)), hash(vec2(k, S + 3.0)));
        float hb = hash(vec2(k, S + 4.0));
        bool beaded = h.z > 0.4 && hb > 0.3;
        if (h.x < 0.2 || deep || (far && !beaded))
            continue;
        float x = (k + 0.15 + 0.7 * fract(h.x * 7.31)) * CELL;
        float r = CELL * mix(0.07, 0.32, max(h.y * h.y, h.z * 0.8));
        float s0 = mix(0.03, 0.5, h.w);
        float grow = smoothstep(s0, s0 + mix(0.3, 0.75, fract(h.w * 5.3)), t);
        float L = H * mix(0.004, 0.21, pow(h.z, 2.3)) * grow + r;
        float root = body(x) + tongue(x);
        float tipY = root + L;
        float shaft = r * 0.78;
        float dc = sdSeg(p, vec2(x, root - r), vec2(x, tipY - shaft)) - shaft;
        // A bead at the tips of the longer ones, swelling as it stretches, its neck
        // drawing out just before it lets go and falls.
        if (beaded) {
            float rb = r * mix(1.15, 1.55, hb);
            float td = s0 + mix(0.35, 0.6, fract(hb * 3.7));
            float neck = smoothstep(td - 0.09, td, t);
            float again = smoothstep(td, td + 0.35, t);
            float swell = t < td ? smoothstep(s0 + 0.1, td, t) : 0.55 * again;
            float br = rb * mix(0.5, 1.0, swell);
            vec2 bc = vec2(x, tipY - shaft + br * 0.4 + (t < td ? neck * br * 1.4 : 0.0));
            float bd = length(p - bc) - br;
            float kb = mix(shaft * 0.9, shaft * 0.25, t < td ? neck : 0.0);
            float m = max(kb - abs(dc - bd), 0.0) / kb;
            dc = min(dc, bd) - m * m * kb * 0.25;
            if (length(p - bc) < length(p.xy - glint.xy))
                glint = vec3(bc, br);
            // The bead that let go, a teardrop stretched as it falls, and a droplet
            // pinched off behind it.
            if (t > td) {
                float age = (t - td) * POUR;
                vec2 q = p - vec2(x, tipY - shaft + rb * 1.8 + 0.5 * FALL * H * age * age);
                float tail = rb * (1.0 + 4.0 * age);
                float dd = length(q * vec2(1.0, 0.9)) - rb;
                float dt = sdSeg(q, vec2(0.0), vec2(0.0, -tail)) - rb * 0.28 * (1.0 - smoothstep(0.0, 0.4, age));
                float mk = rb * 0.6;
                float mm = max(mk - abs(dd - dt), 0.0) / mk;
                dd = min(dd, dt) - mm * mm * mk * 0.25;
                float sat = length(q + vec2(0.0, rb * (2.6 + 9.0 * age))) - rb * 0.3 * smoothstep(0.03, 0.12, age);
                if (min(dd, sat) < rb * 2.0) {
                    vec2 qn = q / rb;
                    vec3 dcol = mix(u.cFrost.rgb, u.cFrostShade.rgb, band(dot(qn, vec2(0.55, 0.45)), 0.35));
                    dcol = mix(dcol, u.cFilm.rgb, cover(0.2 - length((qn + vec2(0.36, 0.3)) * vec2(1.0, 0.75))));
                    vec4 b = over(vec4(0.0), u.cFrost.rgb, cover(-sat));
                    b = over(b, dcol, cover(-dd));
                    drops = b + drops * (1.0 - b.a);
                }
            }
        }
        float kk = shaft * 0.95;
        float m = max(kk - abs(db - dc), 0.0) / kk;
        db = min(db, dc) - m * m * kk * 0.25;
    }

    // The thin tail behind the pour, reaching furthest up in round-topped runnels
    // that lag behind, of uneven widths and lengths.
    const float RW = 0.07;
    float rk = floor(p.x / (W * RW));
    float film = H * FILM * 0.18 * (1.0 + n1(p.x / 60.0, S + 11.0));
    for (int j = -1; j <= 1 && p.y < top + 28.0; j++) {
        float k = rk + float(j);
        vec3 h = vec3(hash(vec2(k, S + 12.0)), hash(vec2(k, S + 13.0)), hash(vec2(k, S + 14.0)));
        float c = (k + 0.2 + 0.6 * h.x) * W * RW;
        float w = W * RW * mix(0.25, 0.8, h.y);
        float ax = (p.x - c) / w;
        film = max(film, H * FILM * pow(h.z, 1.5) * sqrt(max(0.0, 1.0 - ax * ax)));
    }
    float thin = clamp((p.y - top + film) / (film + 28.0), 0.0, 1.0);

    // The rim: distance into the glaze from its lower edge, and the way out of it.
    float e = -db;
    vec2 out2 = vec2(dFdx(db), dFdy(db));
    out2 /= max(length(out2), 1e-4);

    // The old wallpaper, below where the glaze is opaque, shadowed under its edge and
    // under the falling beads.
    vec4 col = texture(source, p / u.resolution) * cover(p.y - top - 28.0);
    float shade = (1.0 - smoothstep(-2.0, 22.0, db)) * cover(db + 2.0);
    col.rgb = mix(col.rgb, u.cInk.rgb * col.a, 0.32 * shade);
    col = drops + col * (1.0 - drops.a);

    float inside = cover(-db) * cover(p.y - top + film);
    if (inside > 0.0) {
        // The glaze's surface: a rim that rises from the edge, crests, and dips behind
        // it before the flat, tilted by the folds, lit from the upper left.
        // Slow folds in its surface, carried down with the flow, their slope across
        // taken a few pixels apart so the bands stay smooth.
        float fy = (p.y - bx) / 300.0 + S * 1.3;
        float fold = vnoise(vec2(p.x / 110.0, fy)) + 0.4 * vnoise(vec2(p.x / 47.0, fy * 1.7 + 5.0));
        float fold2 = vnoise(vec2((p.x + 3.0) / 110.0, fy)) + 0.4 * vnoise(vec2((p.x + 3.0) / 47.0, fy * 1.7 + 5.0));
        vec2 fg = vec2((fold2 - fold) / 3.0 * 40.0, 0.0);
        const float LIP = 15.0;
        float sq = (e - 1.7 * LIP) / (0.75 * LIP);
        float g = 2.0 * exp(-e / (0.42 * LIP)) - 0.18 * exp(-sq * sq);
        vec3 N = normalize(vec3(out2 * g - fg * smoothstep(1.6 * LIP, 3.0 * LIP, e), 1.0));
        vec3 L = normalize(vec3(-0.4, -0.75, 0.55));
        float dif = dot(N, L);
        float spec = dot(N, normalize(L + vec3(0.0, 0.0, 1.0)));
        vec3 gc = mix(u.cFrostShade.rgb, u.cFrost.rgb, max(band(dif, 0.28), band(e, 1.6 * LIP)));
        gc = mix(gc, mix(u.cFrost.rgb, u.cFrostShade.rgb, 0.14), band(0.46 - dif, 0.0) * band(dif, 0.28) * band(thin, 0.82) * band(e, 3.0 * LIP));
        gc = mix(gc, mix(u.cFrost.rgb, u.cFrostLight.rgb, 0.5), band(dif, 0.61));
        gc = mix(gc, u.cFrostLight.rgb, band(dif, 0.7));
        gc = mix(gc, u.cFilm.rgb, band(spec, 0.968));
        // Paler where it thins.
        gc = mix(gc, mix(gc, u.cFrostLight.rgb, 0.45), 1.0 - band(thin, 0.82));
        gc = mix(gc, mix(gc, u.cFrostLight.rgb, 0.6), 1.0 - band(thin, 0.4));
        // A glint on the bead nearest, up on its lit side.
        vec2 gq = (p - glint.xy) / max(glint.z, 1.0) + vec2(0.38, 0.4);
        gc = mix(gc, u.cFilm.rgb, cover(0.17 - length(gq * vec2(1.0, 0.7))));
        float a = mix(0.6, 0.84, band(thin, 0.4));
        a = mix(a, 1.0, band(thin, 0.82));
        vec4 c = vec4(gc, 1.0) * a * inside;
        col = c + col * (1.0 - c.a);
    }

    fragColor = col * u.qt_Opacity;
}
