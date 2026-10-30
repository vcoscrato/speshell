#version 440
#extension GL_GOOGLE_include_directive : enable
// A waterbending whip: a stream of water along a spiral into (or out of) a center.
// Its round head swells and wobbles and throws off spray; behind it the water
// swells and slackens, ripples like a cracked whip toward the tail, and thins to a
// string of beads that break off as droplets and fall behind. Shaded in flat bands,
// with a broken highlight along one side and foam on the head.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
    vec2 resolution;
    vec2 center;
    float r0;
    float k;
    float th0;
    float spin;
    float head;
    float len;
    float tubeWidth;
    vec4 cDeep;
    vec4 cMid;
    vec4 cLight;
    vec4 cFoam;
} u;
#include "../common/common.glsl"

const float TAU = 6.2831853;

// Arc length (px) along the spine from spiral parameter v up to the head.
float arcTo(float v) {
    return sqrt(1.0 + u.k * u.k) * u.r0 / u.k * (exp(-u.k * v) - exp(-u.k * u.head));
}

vec2 spiralAt(float v) {
    float th = u.th0 + u.spin * v;
    return u.center + u.r0 * exp(-u.k * v) * vec2(cos(th), sin(th));
}

// Unit direction the water runs at v, toward the head.
vec2 tangentAt(float v) {
    float th = u.th0 + u.spin * v;
    return normalize(vec2(-u.k * cos(th) - u.spin * sin(th), -u.k * sin(th) + u.spin * cos(th)));
}

// The whip's "inside" field (> 0 inside) at spiral parameter v, sd px off its spine
// (> 0 outward), for a whip L px long. Sets n (-1..1 across) and how far behind the
// head it is (px).
float strand(float v, float sd, float L, inout float n, inout float behind, inout float wide) {
    float W = u.tubeWidth;
    float b = arcTo(v);
    // Its half-width reaches at most 1.7 W, and its ripples move its spine 0.7 W.
    if (b < 0.0 || b > L || abs(sd) > 2.5 * W + 4.0)
        return -1e3;
    float t = u.time;
    float tt = b / max(L, 1.0);                          // 0 at the head .. 1 at the tail
    // A round head that swells and wobbles, then a body that thins steadily to the
    // tail, swelling and slackening as it flows.
    float nose = sqrt(clamp(b / (1.05 * W), 0.0, 1.0));
    float bulb = 1.0 + 0.24 * exp(-b / (1.8 * W)) * (1.0 + 0.35 * sin(t * 12.0));
    float taper = pow(smoothstep(1.02, 0.2, tt), 0.75);
    float swell = 1.0 + 0.2 * sin(b / (2.1 * W) - t * 4.0)
                + 0.32 * (vnoise(vec2(b / (1.4 * W) - t * 2.6, 3.0)) - 0.5);
    // The thinning tail beads up (Rayleigh–Plateau), and its last beads pinch off.
    float pinch = smoothstep(0.5, 0.95, tt);
    // Unevenly spaced, as real beads are.
    float beadPhase = b / (0.26 * W) + 3.0 * vnoise(vec2(b / (1.3 * W), 11.0)) - t * 7.0;
    float beads = 1.0 - pinch * (0.55 + 0.45 * pinch) * (0.5 + 0.5 * sin(beadPhase));
    float w = W * nose * bulb * taper * swell * beads;
    // Ripples run back from the head and grow toward the tail, like a cracked whip.
    float off = W * (0.06 + 0.4 * tt * tt) * sin(b / (2.6 * W) - t * 10.0)
              + (vnoise(vec2(b / (3.0 * W) + t * 0.8, 7.0)) - 0.5) * 0.4 * W * tt;
    float dd = sd - off;
    float f = w - abs(dd);
    n = dd / max(w, 1.0);
    behind = b;
    wide = w;
    return f;
}

// A droplet at q of radius `size`, drawn out along `dir` by `stretch`.
float droplet(vec2 p, vec2 q, vec2 dir, float stretch, float size) {
    vec2 rel = p - q;
    vec2 loc = vec2(dot(rel, dir) / stretch, dot(rel, vec2(-dir.y, dir.x)));
    return size - length(loc);
}

void main() {
    vec2 p = qt_TexCoord0 * u.resolution;
    float W = u.tubeWidth;
    float t = u.time;
    float L = max(arcTo(u.head - u.len), 0.0);
    // Its skin ripples a little as it flows.
    vec2 q = p + (vec2(vnoise(p / 40.0 + t * 1.5), vnoise(p / 40.0 - t * 1.5)) - 0.5) * 5.0;

    // The nearest winding and its neighbour on this side, so the whip never breaks
    // where the nearest winding switches.
    vec4 sp = spiralCoord(q, u.center, u.r0, u.k, u.th0, u.spin, 0.0);
    float r = length(q - u.center);
    float nrm = sqrt(1.0 + u.k * u.k);
    float n = 0.0, behind = 0.0, w = 0.0, n2 = 0.0, behind2 = 0.0, w2 = 0.0;
    float field = strand(sp.y, sp.w, L, n, behind, w);
    float v2 = sp.y - TAU * sign(u.k) * sign(sp.w);
    float f2 = strand(v2, (r - u.r0 * exp(-u.k * v2)) / nrm, L, n2, behind2, w2);
    if (f2 > field) {
        field = f2;
        n = n2;
        behind = behind2;
        w = w2;
    }
    float inside = cover(field - 0.6);
    // The outline thins with the water, so pinched necks vanish cleanly.
    float rim = cover(field + min(2.0, 0.5 * w) - 0.6);

    // ── Droplets and spray ──
    float drops = -1e3;
    float grown = clamp(L / (3.0 * W), 0.0, 1.0);
    float tailV = u.head - u.len;
    float tailR = u.r0 * exp(-u.k * tailV);
    vec2 tailDir = tangentAt(tailV);
    // The beads lag at most 116 px behind the tail along the spiral and drift 46 px.
    for (int i = 0; i < 6 && distance(p, spiralAt(tailV)) < 190.0; i++) {
        // Beads pinched off the tail lag behind it and drift outward, shrinking.
        float fi = float(i);
        float cyc = t * (1.5 + 0.5 * hash(vec2(fi, 4.0))) + hash(vec2(fi, 1.0));
        float ph = fract(cyc);
        float seed = floor(cyc);
        vec3 rnd = vec3(hash(vec2(seed, fi + 0.3)), hash(vec2(seed + 0.7, fi)), hash(vec2(fi, seed + 2.1)));
        float lagPx = 6.0 + ph * (25.0 + 85.0 * rnd.x);
        float v = tailV - lagPx / max(tailR * nrm, 1.0);
        vec2 dp = spiralAt(v);
        dp += normalize(dp - u.center + 1e-3) * (rnd.y - 0.3) * ph * 46.0;
        float size = mix(1.8, 0.24 * W, rnd.z) * smoothstep(0.0, 0.18, ph) * pow(1.0 - ph, 0.8) * grown;
        drops = max(drops, droplet(p, dp, tailDir, 1.0 + 0.5 * (1.0 - ph), size));
    }
    vec2 headPos = spiralAt(u.head);
    vec2 headDir = tangentAt(u.head);
    vec2 out_ = normalize(headPos - u.center + 1e-3);
    // The spray flies at most about 80 px from the head.
    for (int i = 0; i < 5 && distance(p, headPos) < 100.0; i++) {
        // Spray flung off the head, mostly outward, falling behind it.
        float fi = float(i);
        float cyc = t * (2.6 + 0.8 * hash(vec2(fi, 8.0))) + hash(vec2(fi, 5.0));
        float ph = fract(cyc);
        float seed = floor(cyc);
        vec3 rnd = vec3(hash(vec2(seed, fi + 9.1)), hash(vec2(seed + 3.3, fi)), hash(vec2(fi, seed + 6.2)));
        float side = rnd.y < 0.72 ? 1.0 : -1.0;
        vec2 dp = headPos - headDir * (0.2 * W + ph * (14.0 + 40.0 * rnd.x))
                + out_ * side * (0.55 * W + ph * (8.0 + 26.0 * rnd.y));
        float size = mix(1.4, 3.4, rnd.z) * smoothstep(0.0, 0.12, ph) * (1.0 - ph) * grown;
        drops = max(drops, droplet(p, dp, headDir, 1.4, size));
    }
    float dropIn = cover(drops), dropRim = cover(drops + 1.3);

    // ── Shading: flat bands across the stream ──
    vec3 col = u.cMid.rgb;
    col = mix(col, u.cDeep.rgb, cover(-n - 0.35));     // shadow side
    col = mix(col, u.cLight.rgb, cover(n - 0.2) * cover(0.78 - n));
    // The highlight breaks up as the water swells and slackens.
    // Each glint swells and narrows to a point along its length.
    float streak = 0.18 * smoothstep(0.38, 0.72, vnoise(vec2(behind / 27.0 - t * 1.5, 2.0)));
    col = mix(col, u.cFoam.rgb, cover(streak - 0.03 - abs(n - 0.5 - 0.08 * sin(behind / 29.0))));
    // Foam on the leading face of the head.
    col = mix(col, u.cFoam.rgb, cover(0.5 * W - behind - 0.35 * W * n * n) * cover(0.85 - abs(n)));

    vec3 rimCol = u.cDeep.rgb * 0.7;
    vec3 outCol = mix(rimCol, col, inside);
    vec3 dropCol = mix(rimCol, u.cLight.rgb, dropIn);
    outCol = mix(dropCol, outCol, rim);
    float a = max(rim, dropRim);
    fragColor = vec4(outCol * a, a) * u.qt_Opacity;
}
