#version 440
#extension GL_GOOGLE_include_directive : enable
// Air backdrop, drawn once over a surface's base color: a far and a near
// bank of cloud, flat-shaded with a lit crest, threads of wind bending across the
// panel, each in its own waves, and curling up or down at their tips, and a few
// leaves and specks caught in them. It stays a few percent off the base so text reads.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;
    vec4 cBase;
    vec4 cDeep;
    vec4 cText;
    vec4 cAccent;
    vec4 cLeafBack;
} u;
#include "../common/common.glsl"

// A bank of billows: > 0 inside. Its crest sits near `top` px and heaps into round
// heads of about `scale` px, big ones with smaller ones riding on them.
float bank(vec2 p, float top, float scale, float seed) {
    float heads = 0.0;
    for (int o = 0; o < 2; o++) {
        float k = o == 0 ? 1.0 : 0.45;
        float x = p.x / (scale * k) + seed + 7.0 * float(o);
        for (int i = -1; i <= 1; i++) {
            float c = floor(x) + float(i);
            float r = 0.3 + 0.9 * pow(hash(vec2(c, seed + float(o))), 1.5);
            float dx = x - c - 0.5 - 0.4 * (hash(vec2(seed, c)) - 0.5);
            heads = max(heads, k * (sqrt(max(r * r - dx * dx, 0.0)) + (o == 0 ? 0.0 : 0.5 * r)));
        }
    }
    float crest = top - scale * (heads + 0.2 * fbm(vec2(p.x / scale * 2.0, seed)));
    return (p.y - crest) / scale;
}

void main() {
    vec2 p = qt_TexCoord0 * u.size;
    float H = u.size.y;
    vec3 col = u.cBase.rgb;

    // A haze of light high up.
    float haze = clamp(1.0 - p.y / (H * 0.45), 0.0, 1.0);
    col = mix(col, u.cText.rgb, 0.035 * haze * haze);

    // Wind first, so the near bank passes in front of it.
    vec3 wind = mix(u.cText.rgb, u.cAccent.rgb, 0.25);
    for (int i = 0; i < 6; i++) {
        float fi = float(i);
        float y0 = H * (0.10 + 0.13 * fi + 0.05 * hash(vec2(fi, 2.0)));
        float amp = 12.0 + 16.0 * hash(vec2(fi, 3.0));
        float len = u.size.x * (0.3 + 0.4 * hash(vec2(fi, 4.0)));
        float x0 = (u.size.x - len - 30.0) * hash(vec2(fi, 5.0));
        float phase = 6.2831853 * hash(vec2(fi, 6.0));
        // Each its own wavelength, with a smaller ripple riding on it.
        float lambda = mix(50.0, 110.0, hash(vec2(fi, 8.0)));
        float lambda2 = lambda * mix(0.35, 0.5, hash(vec2(fi, 9.0)));
        float amp2 = amp * mix(0.12, 0.3, hash(vec2(fi, 10.0)));
        float phase2 = 6.2831853 * hash(vec2(fi, 11.0));
        float t = (p.x - x0) / len;
        float dist = 1e3;
        float w = 0.0;
        if (t > -0.05 && t < 1.0) {
            float y = y0 + amp * sin(p.x / lambda + phase) + amp2 * sin(p.x / lambda2 + phase2);
            float slope = amp / lambda * cos(p.x / lambda + phase) + amp2 / lambda2 * cos(p.x / lambda2 + phase2);
            dist = abs(p.y - y) / sqrt(1.0 + slope * slope);
            // Tapered from nothing at the tail, full where it curls.
            w = 1.0 * smoothstep(0.0, 0.6, t);
        }
        // The tip rolls over into a tightening curl, along the way the thread was going:
        // forward, then up and back, or down and back, once or nearly twice round.
        float xt = x0 + len;
        vec2 tip = vec2(xt, y0 + amp * sin(xt / lambda + phase) + amp2 * sin(xt / lambda2 + phase2));
        vec2 along = normalize(vec2(1.0, amp / lambda * cos(xt / lambda + phase) + amp2 / lambda2 * cos(xt / lambda2 + phase2)));
        float turn = hash(vec2(fi, 12.0)) < 0.35 ? -1.0 : 1.0;
        vec2 up = vec2(along.y, -along.x) * turn;
        float R0 = 8.0 + 6.0 * hash(vec2(fi, 7.0));
        float thMax = mix(4.6, 9.5, hash(vec2(fi, 13.0)));
        float shrink = 0.5 / thMax;
        vec2 rel = p - (tip + up * R0);
        vec2 lq = vec2(dot(rel, along), dot(rel, -up));
        float th0 = atan(lq.x, lq.y);
        th0 = th0 < 0.0 ? th0 + 6.2831853 : th0;
        for (int k = 0; k < 2; k++) {
            float th = th0 + 6.2831853 * float(k);
            if (th < thMax) {
                float d = abs(length(lq) - R0 * (1.0 - shrink * th));
                if (d < dist) {
                    dist = d;
                    w = 1.0 - th / (thMax * 1.1);
                }
            }
        }
        col = mix(col, wind, 0.11 * cover(w - dist + 0.3) * step(0.01, w));
    }

    // Far bank: higher, smaller, faint; near bank: low and broad, with a lit crest.
    float far = bank(p, H * 0.50, 30.0, 3.0);
    col = mix(col, u.cText.rgb, 0.035 * band(far, 0.0));
    float near = bank(p, H * 0.78, 50.0, 11.0);
    col = mix(col, u.cText.rgb, 0.05 * band(near, 0.0));
    col = mix(col, u.cText.rgb, 0.03 * band(near, 0.0) * (1.0 - band(near, 0.18)));
    col = mix(col, u.cDeep.rgb, 0.06 * band(near, 1.2));

    // Leaves and specks, scattered in the open sky above the near bank.
    vec2 cell = floor(p / 150.0);
    vec4 rnd = vec4(hash2(cell), hash2(cell + 5.0));
    if (rnd.x < 0.4 && p.y < H * 0.74) {
        vec2 c = (cell + 0.2 + 0.6 * rnd.yz) * 150.0;
        float ang = 6.2831853 * rnd.w;
        float L = 7.0 + 4.0 * rnd.y;
        vec2 q = mat2(cos(ang), -sin(ang), sin(ang), cos(ang)) * (p - c);
        float d = sdLeaf(q, L, L * 0.62);
        float body = cover(-d);
        float rib = cover(0.5 - abs(q.x)) * step(abs(q.y), L * 0.75);
        vec3 face = rnd.z > 0.5 ? u.cAccent.rgb : u.cLeafBack.rgb;
        col = mix(col, mix(face, u.cDeep.rgb, 0.5 * rib), body * 0.36);
    }
    vec2 scell = floor(p / 31.0);
    if (hash(scell + 1.7) < 0.035 && p.y < H * 0.75) {
        vec2 s = (scell + 0.2 + 0.6 * hash2(scell)) * 31.0;
        float streak = length((p - s) / vec2(2.5 + 2.0 * hash(scell), 0.7));
        col = mix(col, u.cText.rgb, 0.14 * (1.0 - smoothstep(0.6, 1.2, streak)));
    }

    fragColor = vec4(col, 1.0) * u.qt_Opacity;
}
