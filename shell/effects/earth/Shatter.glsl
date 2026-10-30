// The earth wallpaper transition's layout, shared by its shaders: the shards are
// Voronoi cells in log-polar space around the impact, so they are crushed rubble at the
// middle and grow into broad slabs toward the edges, and the crack front reaches each
// in turn. Needs `u.center` (px, the point of impact) and `u.reach` (px, to the
// furthest corner).
//
// hash() is chaotic enough that two shaders compiled apart can round it differently,
// so each random choice is made in one place, the cells and chips tables, and read
// from there.
#include "../common/common.glsl"

const float TAU = 6.2831853;
// Shards around the impact, and how much longer they run along a ray than across it.
const float N = 30.0;
const float KU = 0.72;
const float JITTER = 0.85;
const float R0 = 14.0;
// The crack front's time to the furthest corner.
const float FRONT = 0.45;
const vec2 LIGHT = vec2(-0.55, -0.83);
// The cells table covers the cells along a ray from X0, KX of them, each in CELL
// texels; the chips table covers the screen's chip grid from CHIP_X0, in CHIP texels.
const float X0 = -4.0;
const float KX = 32.0;
const float CELL = 3.0;
const float CHIP_G = 64.0;
const float CHIP_X0 = -2.0;
const float CHIP = 3.0;

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

// ── Debris ──

// A lumpy dust puff at `c`, radius `r`, as (coverage, shade): thinning out toward its
// edge, and shaded softly away from the light, so it reads as dust, not a blot.
vec2 puff(vec2 p, vec2 c, float r, float seed) {
    vec2 o = p - c;
    vec2 dir = o / max(length(o), 1e-3);
    float lumps = (vnoise(dir * 1.8 + seed * 9.0) - 0.5) * 0.5 * r
                + (vnoise(dir * 5.0 + seed * 3.0 + 4.0) - 0.5) * 0.2 * r;
    float d = length(o) - r - lumps;
    float body = smoothstep(r * 0.3, -r * 0.45, d) * (0.65 + 0.35 * vnoise(p / 14.0 + seed * 5.0));
    return vec2(body, smoothstep(-0.7 * r, 0.9 * r, o.y + o.x * 0.4));
}
