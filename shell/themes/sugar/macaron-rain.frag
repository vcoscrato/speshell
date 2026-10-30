#version 440
#extension GL_GOOGLE_include_directive : enable
// A shower of macarons on a spring evening. Clouds of candyfloss heap up over the
// land, pink melting into blue across them, threads of spun sugar wound round their
// billows; the sun hides behind the greatest and lines it with gold, and its rays fan
// out under them. From their flat bellies macarons rain down in slanting shafts with a
// drizzle of syrup and a few sprinkles, tumbling as they fall, every flavor in its own
// shell and filling. They land in a lake of milk between banks of strawberry and
// pistachio cream: rings spread where they drop, some float, and the banks are dotted
// with the ones that came down before, sprinkles lying round them. In front, on a bank
// of cream with puddles of milk in its hollows, three have landed in a stack and one stands on its edge against another. Far off,
// small clouds rain on soft hills, all of it mirrored in the milk.
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
float ASPECT;
vec2 SUN;
const float HORIZON = 0.3;
// How far the rain drifts sideways for each unit it falls.
const float SLANT = 0.16;
// Toward the sun, in screen space with z toward the viewer.
const vec3 LIGHT = vec3(0.48, 0.56, 0.68);

// Coverage of a signed distance in q, without derivatives, so it is safe anywhere.
float fill(float d) {
    return smoothstep(PX, -PX, d);
}

// Five-stop sky ramp, horizon to zenith: peach, pink, lilac, periwinkle.
vec3 sky(float t) {
    vec3 a = rgb(255, 226, 204), b = rgb(250, 196, 204), c = rgb(214, 172, 214);
    vec3 d = rgb(152, 146, 206), e = rgb(86, 84, 150);
    if (t < 0.2) return mix(a, b, t / 0.2);
    if (t < 0.45) return mix(b, c, (t - 0.2) / 0.25);
    if (t < 0.72) return mix(c, d, (t - 0.45) / 0.27);
    return mix(d, e, (t - 0.72) / 0.28);
}

// A flavor's shell and filling, for h in 0..1.
void flavor(float h, out vec3 shell, out vec3 filling) {
    int i = int(floor(h * 8.0));
    if (i == 0) { shell = rgb(238, 124, 152); filling = rgb(184, 50, 82); }        // raspberry, jam
    else if (i == 1) { shell = rgb(186, 212, 146); filling = rgb(240, 238, 210); } // pistachio, cream
    else if (i == 2) { shell = rgb(252, 218, 116); filling = rgb(255, 242, 196); } // lemon, curd
    else if (i == 3) { shell = rgb(186, 160, 226); filling = rgb(110, 60, 108); }  // lavender, blackcurrant
    else if (i == 4) { shell = rgb(128, 82, 70); filling = rgb(66, 38, 36); }      // chocolate, ganache
    else if (i == 5) { shell = rgb(250, 236, 214); filling = rgb(255, 251, 242); } // vanilla, buttercream
    else if (i == 6) { shell = rgb(204, 154, 114); filling = rgb(242, 218, 190); } // coffee, buttercream
    else { shell = rgb(250, 190, 202); filling = rgb(255, 240, 238); }             // rose, cream
}

// The radius of a macaron's section at height a along its axis, in units of its
// radius: the domed underside of the lower shell, its frilled foot, the filling bulging
// a little, the upper shell's foot, and its higher dome. Gives the slope of the radius
// and the part: 0 shell, 1 foot, 2 filling.
float section(float a, out float slope, out float part) {
    if (a < -0.22) {
        float s = (a + 0.22) / 0.2;
        float r = sqrt(max(1e-4, 1.0 - s * s));
        slope = -s / (0.2 * r);
        part = 0.0;
        return r;
    }
    if (a < -0.1) {
        slope = 0.0;
        part = 1.0;
        return 0.96;
    }
    if (a < 0.1) {
        float s = a / 0.1;
        slope = -0.8 * s;
        part = 2.0;
        return 0.84 + 0.04 * (1.0 - s * s);
    }
    if (a < 0.22) {
        slope = 0.0;
        part = 1.0;
        return 0.96;
    }
    float s = (a - 0.22) / 0.3;
    float r = sqrt(max(1e-4, 1.0 - s * s));
    slope = -s / (0.3 * r);
    part = 0.0;
    return r;
}

// How far p (in a macaron's frame) lies outside its section at height a, seen with
// its top tipped toward the viewer by k (cz the cosine), roughly.
float sectionDistance(vec2 p, float a, float k, float cz) {
    float sl, pt;
    float rho = section(a, sl, pt);
    vec2 R = vec2(rho, max(k * rho, 0.012));
    vec2 o = vec2(p.x, p.y - a * cz);
    float f = dot(o / R, o / R) - 1.0;
    return f / (2.0 * length(o / (R * R)) + 1e-4);
}

// A macaron at c, r its radius, its axis turned `spin` from upright and its top tipped
// toward the viewer by `tip` (0..1, how much of the top shows), of flavor h. It is
// stacked from thin sections, the highest that covers a pixel being the one seen
// there, and lit in flat tones: its shells glossy, its feet ruffled.
vec3 macaron(vec3 col, vec2 q, vec2 c, float r, float spin, float tip, float h, vec3 hz, float haze) {
    vec2 d = q - c;
    if (dot(d, d) > r * r * 1.6)
        return col;
    vec2 p = rot(d, -spin) / r + vec2(0.0, 0.05);
    float k = tip, cz = sqrt(1.0 - k * k);
    float e = PX / r;
    float seen = -1.0, cov = 0.0;
    const float STEP = 0.94 / 56.0;
    for (int i = 0; i < 56; i++) {
        float a = -0.42 + STEP * (float(i) + 0.5);
        float cv = smoothstep(e, -e, sectionDistance(p, a, k, cz));
        if (cv > 0.5)
            seen = a;
        cov = max(cov, cv);
    }
    if (cov <= 0.0)
        return col;
    // Between the highest section that covers it and the next, which does not.
    if (seen > -0.42) {
        float lo = seen, hi = min(seen + STEP, 0.519);
        for (int i = 0; i < 6; i++) {
            float mid = 0.5 * (lo + hi);
            if (sectionDistance(p, mid, k, cz) < 0.0)
                lo = mid;
            else
                hi = mid;
        }
        seen = lo;
    }
    seen = max(seen, -0.42);
    float sl, pt;
    float rho = section(seen, sl, pt);
    // Where on that section's ring the pixel lies, and the surface's normal there.
    float Z = clamp((seen * cz - p.y) / max(k, 0.012), -rho, rho);
    vec2 radial = vec2(p.x, Z) / max(1e-4, length(vec2(p.x, Z)));
    vec3 n = normalize(vec3(radial.x, -sl, radial.y));
    n = vec3(n.x, n.y * cz - n.z * k, n.y * k + n.z * cz);
    n.xy = rot(n.xy, spin);
    vec3 L = normalize(LIGHT);
    float l = dot(n, L);

    vec3 shell, filling;
    flavor(h, shell, filling);
    vec3 base = pt == 2.0 ? filling : shell;
    if (pt == 1.0) {
        // The foot: a ruffle of little bubbles, paler than the shell, in uneven
        // upright ridges with pits between.
        float around = atan(radial.y, radial.x);
        float ridge = vnoise(vec2(around * 34.0, p.y * 3.0 + h * 20.0));
        float pit = vnoise(vec2(around * 80.0, p.y * 26.0 + h * 50.0));
        base = mix(shell, rgb(255, 250, 244), 0.18);
        base = mix(base, mix(base, shell * 0.85, 0.6), smoothstep(0.45, 0.7, ridge));
        base = mix(base, shell * 0.8, smoothstep(0.7, 0.82, pit) * 0.5);
    }
    vec3 lit = mix(base, rgb(255, 250, 244), 0.24);
    vec3 shade = mix(base * 0.7, rgb(112, 92, 156), 0.2);
    vec3 m = mix(shade, base, smoothstep(0.02, 0.1, l));
    m = mix(m, lit, smoothstep(0.62, 0.7, l));
    // A soft sheen on the shells, and a glint where the light catches them.
    float spec = max(0.0, dot(reflect(-L, n), vec3(0.0, 0.0, 1.0)));
    float glossy = pt == 1.0 ? 0.0 : 1.0;
    m = mix(m, mix(m, rgb(255, 255, 255), 0.35), smoothstep(0.8, 0.84, spec) * glossy);
    m = mix(m, rgb(255, 255, 255), smoothstep(0.95, 0.97, spec) * glossy * 0.85);
    // The filling, a little darker where the shells shade it.
    if (pt == 2.0)
        m = mix(m, m * 0.82, 1.0 - smoothstep(0.0, 0.06, 0.1 - abs(seen)));
    col = mix(col, mix(m, hz, haze), cov);
    return col;
}

// Its shadow on what it rests on: a soft ellipse under c.
vec3 restShadow(vec3 col, vec2 q, vec2 c, float r, vec3 tone) {
    vec2 o = (q - c - vec2(-0.3 * r, -0.42 * r)) / vec2(1.25 * r, 0.32 * r);
    return mix(col, tone, (1.0 - smoothstep(0.6, 1.0, length(o))) * 0.5);
}

const int PUFFS = 28;
// Where the front puffs start among them.
const int FRONT = 19;

// Smooth maximum of two distances, rounding the corner where they meet by k.
float smax(float a, float b, float k) {
    float h = clamp(0.5 - 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(b, a, h) + k * h * (1.0 - h);
}

// The lumpy line a cloud's belly is cut along: little billows hanging under it.
float belly(float x, vec2 c, float w, float seed) {
    return c.y - w * 0.015 * lobes((x - c.x) / w, 4.0, seed + 4.0) + w * 0.005;
}

// Puff i of a cloud (see cloud()): its center, and its radius in z.
vec3 puff(int i, vec2 c, float w, float h, float seed) {
    float t = 1.0 - float(i) / float(PUFFS - 1);
    vec2 hh = hash2(vec2(float(i), seed));
    float r = w * mix(0.24, 0.15, t) * (0.7 + 0.6 * hh.y) * (hash(vec2(float(i), seed + 5.0)) > 0.82 ? 1.3 : 1.0);
    vec2 o = vec2(c.x + (hh.x - 0.5) * 2.0 * w * (1.0 - 0.62 * t) * 0.88, c.y + h * t * 0.8 + r * 0.25);
    return vec3(o, r);
}

// The distance to the edge of a cloud's puffs from `from` on, its belly cut off with
// rounded corners. From 0 it is the whole cloud: a core filling the gaps between the
// puffs, and small puffs round its dome that make its outline lumpy.
float cloudDist(vec2 q, vec2 c, float w, float h, float seed, int from) {
    float d = 1e5;
    if (from == 0) {
        vec2 e = (q - c - vec2(0.0, 0.28 * h)) / vec2(0.8 * w, 0.42 * h);
        d = (length(e) - 1.0) * 0.42 * h;
        for (int k = 0; k < 14; k++) {
            vec2 hk = hash2(vec2(float(k), seed + 9.0));
            float th = 3.1415927 * (0.05 + 0.9 * (float(k) + 0.2 + 0.6 * hk.x) / 14.0);
            vec2 o = c + vec2(cos(th) * 0.78 * w, sin(th) * 0.84 * h + 0.06 * h);
            d = min(d, length(q - o) - w * mix(0.08, 0.13, hk.y));
        }
    }
    for (int i = from; i < PUFFS; i++) {
        vec3 o = puff(i, c, w, h, seed);
        d = min(d, length(q - o.xy) - o.z);
    }
    return smax(d, belly(q.x, c, w, seed) - q.y, w * 0.05);
}

// A cloud of candyfloss over its belly at c.y, c.x its middle, w half wide and h
// high: puffs heaped into a dome, the lower in front. It is lit as one body in flat
// tones, not ball by ball: light along its edge toward the sun (behind the cloud), a
// band of shade along the edge away from it, and the front puffs lit along their own
// edges and shading what lies behind them, which shapes it into billows.
// Pink melts into blue across it, away from the sun (`blueness` says how far), threads
// of sugar are wound round its puffs, its sunny edge is lined with gold, and its
// belly is in shadow where the rain leaves.
vec3 cloud(vec3 col, vec2 q, vec2 c, float w, float h, float seed, float blueness, vec3 hz, float haze) {
    if (abs(q.x - c.x) > w * 1.3 || q.y > c.y + h * 1.4 || q.y < c.y - w * 0.1)
        return col;
    float dAll = cloudDist(q, c, w, h, seed, 0);
    if (dAll > PX * 2.0)
        return col;
    vec3 pLit = rgb(255, 222, 232), pMid = rgb(250, 178, 208), pShade = rgb(218, 136, 188), pDeep = rgb(170, 104, 166);
    vec3 bLit = rgb(230, 240, 255), bMid = rgb(182, 206, 248), bShade = rgb(140, 152, 218), bDeep = rgb(110, 112, 184);
    vec3 rim = rgb(255, 236, 196);
    vec2 toSun = normalize(SUN - c + vec2(0.0, 0.25 * h));

    // Whether the point is on the front puffs, and the puff it is on.
    float dFront = cloudDist(q, c, w, h, seed, FRONT);
    vec3 on = vec3(c + vec2(0.0, 0.3 * h), 0.6 * w);
    for (int i = 0; i < PUFFS; i++) {
        vec3 o = puff(i, c, w, h, seed);
        if (length(q - o.xy) < o.z)
            on = o;
    }

    // Pink melting into blue across the cloud, away from the sun.
    float drift = dot((c - q) / w, toSun) * 0.5 + 0.5 + 0.3 * (vnoise((q - c) / w * 2.2 + seed) - 0.5);
    float hue = smoothstep(1.0 - blueness - 0.22, 1.0 - blueness + 0.22, drift);
    vec3 lit = mix(pLit, bLit, hue * 0.7);
    vec3 mid = mix(pMid, bMid, hue);
    vec3 shade = mix(pShade, bShade, min(1.0, hue + 0.3));
    vec3 deep = mix(pDeep, bDeep, min(1.0, hue + 0.45));

    // Lit near the edge toward the sun, and the front puffs near their own, unless
    // the way there crosses deep through a puff, which would light slivers inside
    // notches of the edge; shaded near the edge away from it.
    float band = w * 0.1;
    float dl = min(cloudDist(q + toSun * band, c, w, h, seed, 0),
                   cloudDist(q + toSun * band * 0.6, c, w, h, seed, 0) + band * 0.4);
    // The front puffs' own light falls mostly on their tops, so it does not run
    // down their sides into crescents.
    if (dFront < 0.0) {
        vec2 up = normalize(toSun * 0.5 + vec2(0.0, 1.0)) * w * 0.06;
        dl = max(dl, min(cloudDist(q + up, c, w, h, seed, FRONT),
                         cloudDist(q + up * 0.6, c, w, h, seed, FRONT) + length(up) * 0.4));
    }
    // The shade is wider on its side than along its belly, which is shaded apart.
    float dsh = cloudDist(q - toSun * vec2(0.16, 0.07) * w, c, w, h, seed, 0);
    vec3 m = mid;
    m = mix(m, shade, 1.0 - fill(dsh));
    m = mix(m, lit, 1.0 - fill(dl));
    // The front puffs shade what lies just behind them, away from the sun.
    if (dFront > 0.0)
        m = mix(m, mix(m, shade, 0.5), fill(cloudDist(q + toSun * w * 0.03, c, w, h, seed, FRONT)));

    // Threads of spun sugar wound round the puff: short arcs, each at its own radius
    // and angle, paler than the floss they lie on.
    vec2 rel = q - on.xy;
    float dist = length(rel), ang = atan(rel.y, rel.x);
    float thread = 0.0;
    for (int j = 0; j < 2; j++) {
        float fj = float(j);
        float rows = dist / on.z * 11.0 + 0.5 * fj;
        float row = floor(rows);
        vec2 rh = hash2(vec2(row + fj * 31.0, on.x * 97.0 + seed * 7.0));
        float start = rh.x * 6.2831853, len = 0.3 + 0.8 * rh.y;
        float into = mod(ang - start, 6.2831853);
        float arc = step(into, len) * smoothstep(0.0, 0.12, into) * smoothstep(len, len - 0.12, into);
        thread = max(thread, fill(abs(fract(rows) - 0.5) * on.z / 11.0 - PX * 0.55) * arc);
    }
    thread *= smoothstep(0.35, 0.55, dist / on.z) * (1.0 - smoothstep(0.85, 1.0, dist / on.z));
    m = mix(m, mix(m, rgb(255, 248, 252), 0.55), thread * 0.8);

    // Deepest along the belly.
    float low = q.y - belly(q.x, c, w, seed);
    m = mix(m, mix(shade, deep, 0.4), fill(low - w * 0.025));
    // A rim of gold right at its sunny edge, high on the cloud.
    float sunward = 1.0 - fill(cloudDist(q + toSun * w * 0.03, c, w, h, seed, 0));
    m = mix(m, rim, (1.0 - fill(dAll + w * 0.014)) * sunward * smoothstep(c.y + h * 0.15, c.y + h * 0.5, q.y));
    return mix(col, mix(m, hz, haze), fill(dAll));
}

// A small cloud far off: the same, simpler, hazed into the distance.
vec3 farCloud(vec3 col, vec2 q, vec2 c, float w, float h, float seed, vec3 hz, float haze) {
    if (abs(q.x - c.x) > w * 1.3 || q.y > c.y + h * 1.4 || q.y < c.y - w * 0.1)
        return col;
    float dAll = cloudDist(q, c, w, h, seed, 0);
    if (dAll > PX * 2.0)
        return col;
    vec2 toSun = normalize(SUN - c + vec2(0.0, 0.25 * h));
    float hue = smoothstep(0.3, 0.7, dot((c - q) / w, toSun) * 0.5 + 0.5);
    vec3 m = mix(rgb(248, 190, 212), rgb(190, 206, 244), hue);
    m = mix(m, mix(rgb(212, 150, 192), rgb(150, 156, 214), hue), 1.0 - fill(cloudDist(q - toSun * w * 0.22, c, w, h, seed, 0)));
    m = mix(m, rgb(255, 230, 228), 1.0 - fill(cloudDist(q + toSun * w * 0.1, c, w, h, seed, FRONT)));
    return mix(col, mix(m, hz, haze), fill(dAll));
}

// How thickly macarons rain at q: shafts slanting down from the clouds' bellies,
// thinning as they fall.
float rainAt(vec2 q) {
    float dens = 0.0;
    for (int j = 0; j < 3; j++) {
        vec4 cl = j == 0 ? vec4(ASPECT * 0.6, 0.6, 0.38, 1.0)
                : j == 1 ? vec4(ASPECT * 0.13, 0.67, 0.24, 0.8)
                : vec4(ASPECT * 0.95, 0.71, 0.2, 0.7);
        float fall = cl.y - q.y;
        if (fall < 0.0)
            continue;
        float x = cl.x + SLANT * fall;
        float across = abs(q.x - x) / cl.z;
        float shaft = 1.0 - smoothstep(0.55, 0.95, across + 0.15 * (vnoise(vec2(q.x * 7.0, float(j))) - 0.5));
        dens = max(dens, shaft * cl.w * mix(1.0, 0.55, clamp(fall / 0.5, 0.0, 1.0)));
    }
    return dens;
}

// One depth of falling macarons, in cells of S, each r about rFrac of a cell.
vec3 rainLayer(vec3 col, vec2 q, float S, float rFrac, float keep, float seed, float minY, vec3 hz, float haze) {
    vec2 cell = floor(q / S);
    for (int j = -1; j <= 1; j++) {
        for (int i = -1; i <= 1; i++) {
            vec2 g = cell + vec2(float(i), float(j));
            vec2 h = hash2(g + seed);
            vec2 c = (g + 0.15 + 0.7 * h) * S;
            if (c.y < minY)
                continue;
            if (hash(g + seed + 5.1) > rainAt(c) * keep)
                continue;
            float r = S * rFrac * mix(0.75, 1.15, hash(g + seed + 2.3));
            float spin = (hash(g + seed + 7.7) - 0.5) * 6.2831853;
            float tip = mix(0.12, 0.62, hash(g + seed + 8.8));
            col = macaron(col, q, c, r, spin, tip, hash(g + seed + 9.9), hz, haze);
        }
    }
    return col;
}

// Sprinkles, one to a cell of S where kept (`keep`, times `dens`): little rods of
// sugar len long at any angle, in the flavors' colors, lit along one side. Lying,
// they are seen from above and foreshortened.
vec3 sprinkles(vec3 col, vec2 q, float S, float len, float keep, float seed, float dens, bool lying, vec3 hz, float haze) {
    vec2 g = floor(q / S);
    if (hash(g + seed) > keep * dens)
        return col;
    vec2 h = hash2(g + seed + 1.3);
    vec2 c = (g + 0.3 + 0.4 * h) * S;
    float a = hash(g + seed + 2.1) * 6.2831853;
    vec2 dir = vec2(cos(a), sin(a) * (lying ? 0.35 : 1.0)) * len * 0.5 * mix(0.7, 1.0, h.y);
    float r = len * 0.17;
    vec2 pa = c - dir, pb = c + dir;
    float d = sdSeg(q, pa, pb) - r;
    if (d > PX * 2.0)
        return col;
    vec3 shell, filling;
    flavor(hash(g + seed + 3.7), shell, filling);
    vec3 base = mix(shell, shell * shell * 1.1, 0.35);
    // Lit along its side toward the sun, a little shade along the other.
    vec2 n = normalize(vec2(-dir.y, dir.x));
    float side = dot(q - pa, n) / r * sign(dot(n, normalize(SUN - c)));
    vec3 m = mix(base * 0.78, base, smoothstep(-0.35, -0.25, side));
    m = mix(m, mix(base, rgb(255, 252, 246), 0.55), smoothstep(0.3, 0.4, side));
    if (lying)
        col = mix(col, col * 0.8, fill(sdSeg(q, pa + vec2(0.3 * r, -0.6 * r), pb + vec2(0.3 * r, -0.6 * r)) - r) * 0.6);
    return mix(col, mix(m, hz, haze), fill(d));
}

// Syrup drizzling down the shafts: thin slanting streaks in broken lengths.
float drizzle(vec2 q, float spacing, float len, float seed) {
    float u = q.x + SLANT * q.y;
    float id = floor(u / spacing);
    float off = (0.2 + 0.6 * hash(vec2(id, seed))) * spacing;
    float across = abs(u - id * spacing - off) / sqrt(1.0 + SLANT * SLANT);
    float along = fract(q.y / len + hash(vec2(id, seed + 1.0)) * 7.0);
    float on = step(along, 0.3 + 0.2 * hash(vec2(id, seed + 2.0)));
    return fill(across - PX * 0.55) * on * smoothstep(0.0, 0.08, along) * step(hash(vec2(id, seed + 3.0)), 0.7);
}

// The crests of the banks: strawberry falling from the left toward the lake, and
// pistachio rising on the right.
float bankL(float x) {
    return mix(0.36, 0.0, smoothstep(0.1, 0.95, x)) + 0.03 * billows(x + 3.0, 4.0, 6.0);
}

float bankR(float x) {
    return mix(0.0, 0.37, smoothstep(0.95, 1.75, x)) + 0.028 * billows(x + 5.0, 4.5, 7.0);
}

// A glint: four points of light.
float glint(vec2 q, vec2 c, float r) {
    vec2 d = abs(q - c) / r;
    return fill((sqrt(d.x) + sqrt(d.y) - 1.0) * r * 0.5);
}

// Low hills of uneven widths, overlapping: lobes over lobes of another size (0..1).
float hills(float x, float freq, float seed) {
    return max(lobes(x, freq, seed), 0.75 * lobes(x + 0.43 / freq, freq * 1.7, seed + 3.0));
}

// Everything at and past the horizon, which the lake mirrors: the sky, the sun's glow,
// the far clouds raining on the far hills. The mirror leaves out the lit crests.
vec3 farScene(vec2 q, bool mirrored) {
    float ds = length((q - SUN) * vec2(1.0, 1.2));
    float t = clamp((q.y - HORIZON) / (1.0 - HORIZON), 0.0, 1.0);
    t = pow(t, 0.9) - 0.3 * exp(-ds * 2.2) + (fbm(vec2(q.x * 1.3, q.y * 4.0)) - 0.5) * 0.04;
    vec3 col = sky(steps(clamp(t, 0.0, 1.0), 12.0));

    // The sun, behind the great cloud, in rings of light.
    float dsun = length(q - SUN);
    col = mix(col, mix(col, rgb(255, 232, 206), 0.26), cover(0.16 - dsun));
    col = mix(col, rgb(255, 244, 222), cover(0.07 - dsun));

    float crest = mirrored ? 0.0 : 1.0;
    // A range of soft hills far off, hazed nearly into the sky, lit along the crests.
    float rimFar = exp(-abs(q.x - SUN.x) * 1.4);
    float hm = HORIZON + 0.03 + 0.05 * lobes(q.x + 0.3, 1.3, 21.0) * (0.5 + 0.5 * smoothstep(0.1, 0.9, abs(q.x / ASPECT - 0.5) * 2.0));
    col = mix(col, mix(rgb(234, 196, 220), rgb(250, 214, 212), rimFar), below(hm, q.y));
    col = mix(col, mix(rgb(246, 214, 226), rgb(255, 228, 210), rimFar), below(hm, q.y) * (1.0 - below(hm - 0.004, q.y)) * crest);
    float hm2 = HORIZON + 0.016 + 0.026 * lobes(q.x + 1.3, 2.4, 22.0);
    col = mix(col, mix(rgb(226, 186, 214), rgb(244, 204, 206), rimFar), below(hm2, q.y));
    col = mix(col, mix(rgb(242, 208, 224), rgb(255, 224, 208), rimFar), below(hm2, q.y) * (1.0 - below(hm2 - 0.004, q.y)) * crest);

    // Far clouds, hazed, with faint rain under them.
    vec3 hz = mix(rgb(250, 208, 210), rgb(255, 226, 206), exp(-abs(q.x - SUN.x) * 1.5));
    vec2 f0 = vec2(ASPECT * 0.36, 0.42), f1 = vec2(ASPECT * 0.79, 0.45), f2 = vec2(ASPECT * 0.05, 0.47);
    for (int j = 0; j < 3; j++) {
        vec2 f = j == 0 ? f0 : j == 1 ? f1 : f2;
        float w = j == 0 ? 0.075 : j == 1 ? 0.055 : 0.06;
        float fall = f.y - q.y;
        float across = abs(q.x - f.x - SLANT * fall) / (w * 0.8);
        float shaft = (1.0 - smoothstep(0.5, 1.0, across)) * step(0.0, fall) * (1.0 - smoothstep(0.0, f.y - HORIZON + 0.02, fall));
        float strands = 0.5 + 0.5 * vnoise(vec2((q.x + SLANT * q.y) * 260.0, float(j)));
        col = mix(col, rgb(206, 170, 214), shaft * strands * 0.35);
    }
    col = farCloud(col, q, f0, 0.075, 0.06, 11.0, hz, 0.45);
    col = farCloud(col, q, f1, 0.055, 0.045, 12.0, hz, 0.5);
    col = farCloud(col, q, f2, 0.06, 0.05, 13.0, hz, 0.5);

    // Far hills of meringue, pale with the distance, lit along their crests.
    float rimSun = exp(-abs(q.x - SUN.x) * 1.6);
    float h0 = HORIZON + 0.016 * hills(q.x, 2.9, 1.0) + 0.006;
    col = mix(col, rgb(226, 190, 214), below(h0, q.y));
    col = mix(col, mix(rgb(240, 214, 226), rgb(255, 232, 214), rimSun), below(h0, q.y) * (1.0 - below(h0 - 0.004, q.y)) * crest);
    float h1 = HORIZON + 0.008 * hills(q.x + 0.5, 4.7, 2.0);
    col = mix(col, rgb(210, 176, 206), below(h1, q.y));
    col = mix(col, mix(rgb(230, 200, 220), rgb(250, 222, 210), rimSun), below(h1, q.y) * (1.0 - below(h1 - 0.003, q.y)) * crest);
    return col;
}

void main() {
    vec2 px = qt_TexCoord0 * u.resolution;
    vec2 q = vec2(px.x, u.resolution.y - px.y) / u.resolution.y;
    PX = 1.0 / u.resolution.y;
    ASPECT = u.resolution.x / u.resolution.y;
    SUN = vec2(ASPECT * 0.71, 0.84);
    vec3 hz = mix(rgb(250, 208, 210), rgb(255, 226, 206), exp(-abs(q.x - SUN.x) * 1.5));

    vec3 col = farScene(q, false);

    // The lake of milk, mirroring the far scene in broken bands, rippling.
    float lakeTop = HORIZON;
    float inLake = below(lakeTop, q.y);
    // Broken up most just under the horizon, where the far hills meet their mirror.
    float near = 1.0 + 2.0 * smoothstep(0.035, 0.0, lakeTop - q.y);
    float wob = (vnoise(vec2(q.x * 3.0, q.y * 160.0)) - 0.5) * 0.004 + (vnoise(vec2(q.x * 40.0, q.y * 300.0)) - 0.5) * 0.002;
    vec2 mq = vec2(q.x + wob * 2.0 * near, 2.0 * lakeTop - q.y + wob);
    vec3 refl = farScene(mq, true);
    vec3 milk = mix(rgb(244, 230, 238), rgb(255, 240, 230), exp(-abs(q.x - SUN.x) * 2.0));
    float depth = clamp((lakeTop - q.y) / 0.2, 0.0, 1.0);
    vec3 lake = mix(refl, milk, 0.28 + 0.2 * depth);
    // Glints of light across it, thickest under the sun.
    float rip = vnoise(vec2(q.x * 7.0, q.y * 260.0 / (0.3 + depth)));
    float underSun = exp(-abs(q.x - SUN.x - 0.05) * 5.0);
    lake = mix(lake, mix(lake, rgb(255, 250, 244), 0.6), band(rip, 0.86 - 0.12 * underSun) * (0.25 + 0.75 * underSun));
    col = mix(col, lake, inLake);

    // Rings where macarons have dropped in, flattened by the distance.
    for (int i = 0; i < 12; i++) {
        float fi = float(i);
        vec2 hh = hash2(vec2(fi, 51.0));
        vec2 s = vec2(mix(0.62, 1.32, hh.x), mix(0.13, 0.27, hh.y));
        float scale = 1.0 - (s.y - 0.12) / 0.2 * 0.6;
        float rmax = 0.06 * scale * (0.6 + 0.6 * hash(vec2(fi, 52.0)));
        float rr = length((q - s) / vec2(1.0, 0.24));
        float spacing = rmax / 3.2;
        float ring = fill(abs(fract(rr / spacing) - 0.5) * spacing * 0.24 - PX * 0.7)
            * (1.0 - smoothstep(rmax * 0.5, rmax, rr)) * step(spacing * 0.5, rr);
        col = mix(col, rgb(255, 250, 246), ring * inLake * 0.75);
    }
    // Far rain: the smallest macarons, falling on the far hills and the lake.
    col = rainLayer(col, q, 0.04, 0.2, 0.22, 3.0, HORIZON - 0.04, hz, 0.35);

    // The rays of the sun, fanning out under the clouds.
    float ang = atan(q.y - SUN.y, q.x - SUN.x);
    float ray = band(vnoise(vec2(ang * 8.0, 4.0)) + 0.2 * sin(ang * 31.0), 0.6);
    float rays = ray * exp(-length(q - SUN) * 1.1) * smoothstep(HORIZON - 0.12, HORIZON + 0.02, q.y) * (1.0 - smoothstep(0.52, 0.62, q.y));
    col = mix(col, rgb(255, 236, 206), rays * 0.3);

    // Floating macarons, bobbing in the milk.
    for (int i = 0; i < 3; i++) {
        vec2 f = i == 0 ? vec2(ASPECT * 0.55, 0.2) : i == 1 ? vec2(ASPECT * 0.63, 0.135) : vec2(ASPECT * 0.4, 0.25);
        float r = i == 0 ? 0.018 : i == 1 ? 0.026 : 0.012;
        float rr = length((q - f - vec2(0.0, -0.35 * r)) / vec2(1.0, 0.24));
        col = mix(col, rgb(255, 250, 246), fill(abs(rr - r * 1.35) * 0.24 - PX * 0.6) * 0.8);
        col = mix(col, rgb(255, 250, 246), fill(abs(rr - r * 1.9) * 0.24 - PX * 0.5) * 0.45);
        col = macaron(col, q, f, r, i == 1 ? -0.12 : 0.18, 0.5, i == 0 ? 0.05 : i == 1 ? 0.32 : 0.88, hz, i == 2 ? 0.2 : 0.06);
    }

    // The banks: strawberry cream on the left, pistachio on the right, each lit
    // along its crest and dotted with macarons that came down before.
    float rimSun = exp(-abs(q.x - SUN.x) * 1.6);
    float hl = bankL(q.x);
    float hr = bankR(q.x);
    float inL = below(hl, q.y), inR = below(hr, q.y);
    float shoreL = (1.0 - below(hl - 0.012, q.y)) * inL;
    col = mix(col, rgb(240, 188, 200), inL);
    col = mix(col, rgb(222, 160, 182), inL * below(hl - 0.05 - 0.02 * billows(q.x + 1.0, 7.0, 16.0), q.y));
    float grooveLRows = (hl - q.y) / 0.026 + 0.7 * vnoise(vec2(q.x * 5.0, 8.0));
    float grooveL = fract(grooveLRows) + 1.0 - step(0.5, vnoise(vec2(q.x * 9.0, floor(grooveLRows) * 3.1)));
    col = mix(col, rgb(226, 170, 188), inL * (1.0 - band(grooveL, 0.14)) * smoothstep(0.015, 0.04, hl - q.y) * 0.8);
    col = mix(col, mix(rgb(252, 214, 214), rgb(255, 232, 218), rimSun), shoreL);
    float shoreR = (1.0 - below(hr - 0.012, q.y)) * inR;
    col = mix(col, rgb(196, 210, 162), inR);
    col = mix(col, rgb(170, 188, 148), inR * below(hr - 0.05 - 0.02 * billows(q.x + 2.0, 7.0, 17.0), q.y));
    float grooveRRows = (hr - q.y) / 0.026 + 0.7 * vnoise(vec2(q.x * 5.0, 9.0));
    float grooveR = fract(grooveRRows) + 1.0 - step(0.5, vnoise(vec2(q.x * 9.0, floor(grooveRRows) * 3.1)));
    col = mix(col, rgb(180, 198, 152), inR * (1.0 - band(grooveR, 0.14)) * smoothstep(0.015, 0.04, hr - q.y) * 0.8);
    col = mix(col, mix(rgb(226, 236, 196), rgb(248, 240, 206), rimSun), shoreR);
    // Macarons that came down before, resting on the banks over their shadows.
    for (int i = 0; i < 16; i++) {
        float fi = float(i);
        vec2 hh = hash2(vec2(fi, 71.0));
        bool left = i < 8;
        float x = left ? mix(0.03, 0.7, hh.x) : mix(1.1, 1.75, hh.x);
        float top = left ? bankL(x) : bankR(x);
        float y = top - 0.012 - 0.06 * hh.y;
        float r = mix(0.008, 0.013, hash(vec2(fi, 72.0))) * (1.0 - 0.3 * hh.y);
        vec2 c = vec2(x, y + r * 0.2);
        vec3 tone = left ? rgb(200, 138, 164) : rgb(150, 168, 132);
        col = restShadow(col, q, c, r, tone);
        col = macaron(col, q, c, r, (hash(vec2(fi, 73.0)) - 0.5) * 0.5, mix(0.35, 0.7, hash(vec2(fi, 74.0))), hash(vec2(fi, 75.0)), hz, 0.08);
    }
    // Sprinkles that came down with them, lying in the cream.
    col = sprinkles(col, q, 0.022, 0.007, 0.1, 23.0, max(inL * below(hl - 0.012, q.y), inR * below(hr - 0.012, q.y)), true, hz, 0.08);

    // Middle rain.
    col = rainLayer(col, q, 0.08, 0.22, 0.45, 7.0, 0.05, hz, 0.1);
    col = sprinkles(col, q, 0.035, 0.009, 0.1, 21.0, rainAt(q), false, hz, 0.1);

    // The clouds: the small one right, the left one, and the great one before the sun.
    col = cloud(col, q, vec2(ASPECT * 0.95, 0.71), 0.2, 0.16, 3.0, 0.75, hz, 0.12);
    col = cloud(col, q, vec2(ASPECT * 0.13, 0.67), 0.24, 0.2, 2.0, 0.55, hz, 0.05);
    col = cloud(col, q, vec2(ASPECT * 0.6, 0.6), 0.38, 0.3, 1.0, 0.3, hz, 0.0);

    // Syrup drizzling through the shafts.
    float dens = rainAt(q);
    col = mix(col, rgb(255, 244, 236), drizzle(q, 0.011, 0.07, 1.0) * dens * 0.45 * step(0.08, q.y));
    col = mix(col, rgb(255, 248, 242), drizzle(q, 0.023, 0.13, 2.0) * dens * 0.35);

    // The near bank of cream, in the shade of the clouds, lit along its crest and
    // grooved where it was spread; macarons have come to rest on it: a stack of three
    // on the left, and on the right one standing on its edge against another.
    float hf = 0.085 + 0.05 * billows(q.x + 2.3, 2.0, 5.0);
    float inF = below(hf, q.y);
    col = mix(col, rgb(184, 120, 158), inF);
    col = mix(col, rgb(226, 158, 178), inF * (1.0 - below(hf - 0.009, q.y)));
    float u4 = hf - 0.04 + 0.025 * billows(q.x + 6.1, 4.0, 19.0);
    col = mix(col, rgb(152, 96, 140), below(u4, q.y));
    float rowsF = (u4 - q.y) / 0.02 + 0.6 * vnoise(vec2(q.x * 6.0, 4.0));
    float grooveF = fract(rowsF) + 1.0 - step(0.5, vnoise(vec2(q.x * 9.0, floor(rowsF) * 3.1)));
    col = mix(col, rgb(136, 84, 128), below(u4, q.y) * (1.0 - band(grooveF, 0.14)) * smoothstep(0.008, 0.02, u4 - q.y));
    col = sprinkles(col, q, 0.04, 0.014, 0.12, 25.0, below(hf - 0.012, q.y), true, hz, 0.0);
    // Puddles of milk in its hollows, holding the sky, a drop rippling one.
    for (int i = 0; i < 3; i++) {
        vec2 pc = i == 0 ? vec2(0.62, 0.035) : i == 1 ? vec2(1.02, 0.05) : vec2(1.47, 0.028);
        vec2 pr = i == 0 ? vec2(0.11, 0.016) : i == 1 ? vec2(0.07, 0.011) : vec2(0.05, 0.008);
        vec2 po = (q - pc) / pr;
        float edge = (length(po) - 1.0 - 0.08 * (vnoise(vec2(atan(po.y, po.x) * 3.0, float(i))) - 0.5)) * pr.y;
        vec3 pool = mix(farScene(vec2(q.x, 0.62 + (pc.y - q.y) * 6.0), true), rgb(244, 230, 238), 0.35);
        col = mix(col, rgb(214, 160, 184), fill(edge - pr.y * 0.18));
        col = mix(col, pool, fill(edge));
        float rr = length(po - vec2(0.25, 0.1)) * pr.x;
        col = mix(col, rgb(255, 250, 246), fill(abs(rr - pr.x * 0.22) * 0.25 - PX * 0.5) * fill(edge) * 0.8 * step(float(i), 0.5));
        col = mix(col, rgb(255, 250, 246), fill(abs(rr - pr.x * 0.4) * 0.25 - PX * 0.5) * fill(edge) * 0.5 * step(float(i), 0.5));
    }
    vec3 restTone = rgb(124, 76, 122);
    vec2 a = vec2(0.24, 0.1);
    col = restShadow(col, q, a, 0.075, restTone);
    col = macaron(col, q, a, 0.075, 0.0, 0.4, 0.05, hz, 0.0);
    col = macaron(col, q, a + vec2(0.006, 0.062), 0.068, 0.05, 0.42, 0.18, hz, 0.0);
    col = macaron(col, q, a + vec2(0.018, 0.118), 0.062, 0.14, 0.48, 0.7, hz, 0.0);
    vec2 b = vec2(1.56, 0.095);
    col = restShadow(col, q, b + vec2(0.07, 0.0), 0.07, restTone);
    col = macaron(col, q, b + vec2(0.07, 0.0), 0.07, 0.0, 0.62, 0.3, hz, 0.0);
    col = restShadow(col, q, b, 0.05, restTone);
    col = macaron(col, q, b + vec2(-0.012, 0.045), 0.068, 1.25, 0.25, 0.45, hz, 0.0);
    col = restShadow(col, q, vec2(1.3, 0.06), 0.035, restTone);
    col = macaron(col, q, vec2(1.3, 0.06), 0.035, 0.2, 0.6, 0.95, hz, 0.0);

    // Near rain, falling past everything.
    col = rainLayer(col, q, 0.17, 0.25, 0.6, 13.0, 0.16, hz, 0.0);
    col = sprinkles(col, q, 0.07, 0.018, 0.12, 27.0, rainAt(q) * step(0.16, q.y), false, hz, 0.0);

    // Drops of syrup catching the light.
    for (int i = 0; i < 16; i++) {
        float fi = float(i);
        vec2 h = hash2(vec2(fi, 81.0));
        vec2 c = vec2(h.x * ASPECT, mix(0.15, 0.6, h.y));
        col = mix(col, rgb(255, 252, 244), glint(q, c, mix(0.004, 0.009, hash(vec2(fi, 82.0)))) * rainAt(c) * 0.9);
    }

    fragColor = vec4(col, 1.0);
}
