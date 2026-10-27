#version 440
#extension GL_GOOGLE_include_directive : enable
// Ember dusk: a volcano erupting under smoke clouds lit from below, lava running
// down its flanks; across the valley a fortress of tiered crimson roofs stands
// on a cliff against the low sun. A lava river winds through the valley floor
// between basalt columns, and embers drift up through the smoke.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 resolution;
} u;
#include "../../effects/common/common.glsl"
#include "../landscape.glsl"

// Five-stop sky ramp, horizon to zenith.
vec3 sky(float t) {
    vec3 a = rgb(240, 132, 58), b = rgb(186, 58, 40), c = rgb(110, 26, 32);
    vec3 d = rgb(50, 14, 22), e = rgb(20, 8, 12);
    if (t < 0.25) return mix(a, b, t / 0.25);
    if (t < 0.5) return mix(b, c, (t - 0.25) / 0.25);
    if (t < 0.75) return mix(c, d, (t - 0.5) / 0.25);
    return mix(d, e, (t - 0.75) / 0.25);
}

// A fortress of tiered roofs standing on (base), `s` its scale: dark walls,
// crimson roofs with gold-trimmed eaves that turn up at the tips, lit windows.
vec3 fortress(vec3 col, vec2 q, vec2 base, float s) {
    vec3 wall = rgb(36, 14, 16), roof = rgb(112, 24, 24), trim = rgb(236, 168, 72), glow = rgb(255, 184, 92);
    vec2 p = (q - base) / s;
    // Main hall: three tiers, and a wing on each side.
    for (int w = -1; w <= 1; w++) {
        float fw = float(w);
        vec2 o = p - vec2(fw * 1.55, 0.0);
        int tiers = w == 0 ? 3 : 2;
        float scale = w == 0 ? 1.0 : 0.72;
        for (int i = 0; i < 3; i++) {
            if (i >= tiers)
                break;
            float fi = float(i);
            float y0 = fi * 0.82 * scale;
            float ww = (0.95 - 0.26 * fi) * scale;
            float ax = abs(o.x);
            float wallIn = cover(ww - ax) * cover(o.y - y0) * cover(y0 + 0.42 * scale - o.y);
            col = mix(col, wall, wallIn);
            float wx = fract(o.x / (0.28 * scale) + 0.5) - 0.5;
            float win = cover(0.12 - abs(wx)) * cover(0.1 * scale - abs(o.y - y0 - 0.2 * scale)) * cover(ww - 0.1 - ax);
            col = mix(col, glow, wallIn * win);
            float ry = o.y - (y0 + 0.4 * scale);
            float rw = (ww + 0.34 * scale) - ry * 1.6;
            float eave = 0.18 * scale * pow(clamp(ax / (ww + 0.34 * scale), 0.0, 1.0), 5.0);
            float roofIn = cover(rw - ax) * cover(ry - eave) * cover(0.3 * scale - ry);
            col = mix(col, roof, roofIn);
            col = mix(col, trim, roofIn * cover(0.035 - abs(ry - eave - 0.02)));
        }
    }
    // A spire with a gold finial over the main hall.
    float ty = p.y - 2.5;
    float tw = 0.1 * clamp(1.0 - ty / 0.7, 0.0, 1.0);
    col = mix(col, roof, cover(tw - abs(p.x)) * cover(ty) * cover(0.7 - ty));
    col = mix(col, trim, cover(0.06 - length(p - vec2(0.0, 3.25))));
    return col;
}

void main() {
    vec2 px = qt_TexCoord0 * u.resolution;
    vec2 q = vec2(px.x, u.resolution.y - px.y) / u.resolution.y;
    float aspect = u.resolution.x / u.resolution.y;
    vec2 sun = vec2(aspect * 0.8, 0.44);
    float ds = length(q - sun);
    vec2 crater = vec2(aspect * 0.32, 0.6);

    // Sky in flat bands, hottest around the sun.
    float t = clamp((q.y - 0.22) / 0.78, 0.0, 1.0);
    t = pow(t, 0.7) - 0.1 * exp(-ds * 3.0) + (fbm(vec2(q.x * 1.3, q.y * 5.0)) - 0.5) * 0.05;
    vec3 col = sky(steps(clamp(t, 0.0, 1.0), 11.0));

    // The low sun.
    col = mix(col, mix(col, rgb(255, 170, 80), 0.14), cover(0.24 - ds));
    col = mix(col, mix(col, rgb(255, 184, 96), 0.25), cover(0.155 - ds));
    col = mix(col, rgb(255, 178, 88), cover(0.1 - ds));
    col = mix(col, rgb(255, 222, 156), cover(0.072 - ds));

    // Smoke clouds: dark masses with molten undersides, glowing most over the
    // volcano and the sun.
    float env = smoothstep(0.6, 0.76, q.y);
    float n = fbm(vec2(q.x * 2.0, q.y * 5.0) + vec2(1.0, 3.0)) + 0.3 * vnoise(vec2(q.x * 7.0, q.y * 16.0));
    float nb = fbm(vec2(q.x * 2.0, (q.y + 0.016) * 5.0) + vec2(1.0, 3.0)) + 0.3 * vnoise(vec2(q.x * 7.0, (q.y + 0.016) * 16.0));
    float cloud = band(n * env, 0.58);
    float heat = max(exp(-abs(q.x - crater.x) * 2.2), 0.8 * exp(-abs(q.x - sun.x) * 2.5));
    col = mix(col, mix(rgb(42, 14, 20), rgb(70, 20, 24), heat), cloud);
    float under = cloud * (1.0 - band(nb * env, 0.58));
    col = mix(col, mix(rgb(150, 44, 34), rgb(232, 112, 52), heat), under);

    // The volcano: a broad cone, its crater notched, lit on the sun side.
    float dx = q.x - crater.x;
    float hv = crater.y - 0.5 * pow(max(abs(dx) - 0.03, 0.0) / 0.6, 0.88) * (1.0 + 0.12 * sign(dx)) + (vnoise(vec2(q.x * 50.0, 1.0)) - 0.5) * 0.008;
    hv -= 0.014 * max(0.0, 1.0 - dx * dx / (0.035 * 0.035));
    float volc = below(hv, q.y);

    // The eruption: a leaning column of billows, lit from the crater below.
    float plume = 1e3, plumeLit = 1e3;
    for (int k = 0; k < 14; k++) {
        float fk = float(k);
        float along = fk * 0.5;
        vec2 c = crater + vec2(0.012 * along + 0.006 * along * along + (hash(vec2(fk, 7.0)) - 0.5) * 0.03,
                               0.004 + 0.05 * along);
        float r = 0.022 + 0.01 * along + 0.008 * hash(vec2(fk, 2.0));
        float d = length(q - c) - r + (vnoise(q * 34.0 + fk) - 0.5) * 0.014;
        plume = min(plume, d);
        plumeLit = min(plumeLit, length(q - c - vec2(-0.25, 0.55) * r * 0.5) - r * 0.82);
    }
    float plumeIn = cover(-plume) * (1.0 - volc);
    col = mix(col, rgb(54, 18, 22), plumeIn);
    col = mix(col, rgb(34, 12, 16), plumeIn * cover(plumeLit + 0.004) * step(crater.y + 0.2, q.y));
    float plumeGlow = plumeIn * (1.0 - cover(-plumeLit)) * cover(crater.y + 0.32 - q.y);
    col = mix(col, rgb(214, 86, 44), plumeGlow);
    col = mix(col, rgb(250, 150, 70), plumeGlow * cover(crater.y + 0.14 - q.y));

    // Back ridges on either side.
    float h0 = 0.27 + 0.12 * ridge(q.x + 2.0, 2.2, 1.0);
    col = mix(col, rgb(86, 26, 28), below(h0, q.y));
    col = mix(col, rgb(170, 60, 40), below(h0, q.y) * (1.0 - below(h0 - 0.004, q.y)) * exp(-abs(q.x - sun.x) * 2.0));

    // The volcano's faces and its lava.
    float ridgeLine = (vnoise(vec2(q.y * 10.0, 4.0)) - 0.5) * 0.05;
    vec3 rock = dx > ridgeLine ? rgb(104, 34, 30) : rgb(60, 20, 24);
    rock = mix(rock, dx > ridgeLine ? rgb(84, 28, 26) : rgb(50, 17, 21), band(vnoise(vec2(q.x * 30.0 - q.y * 18.0 * sign(dx), q.y * 110.0)), 0.7));
    col = mix(col, rock, volc);
    for (int i = 0; i < 4; i++) {
        float fi = float(i);
        float drop = crater.y - q.y;
        float side = fi < 1.5 ? -1.0 : 1.0;
        float xs = crater.x + side * (0.012 + 0.004 * fi) + side * drop * (0.55 + 0.35 * fi - (fi > 1.5 ? 0.7 : 0.0))
                 + 0.012 * sin(drop * 38.0 + fi * 2.0);
        float w = 0.0035 + drop * 0.012;
        float lava = cover(w - abs(q.x - xs)) * volc * step(0.0, drop) * cover(0.3 - drop - 0.07 * fi);
        col = mix(col, rgb(236, 92, 38), lava);
        col = mix(col, rgb(255, 196, 98), lava * cover(w * 0.4 - abs(q.x - xs)));
    }
    float glowCrater = cover(0.05 - length((q - crater) * vec2(1.0, 2.6))) * volc;
    col = mix(col, rgb(255, 178, 84), glowCrater);

    // The cliff across the valley, and the fortress on it against the sun.
    float cliffTop = 0.33 + (vnoise(vec2(q.x * 30.0, 6.0)) - 0.5) * 0.01;
    float face = aspect * 0.64 - (0.33 - q.y) * 0.25 + (vnoise(vec2(q.y * 45.0, 8.0)) - 0.5) * 0.03;
    float cliff = below(cliffTop, q.y) * cover(q.x - face);
    vec3 cliffCol = mix(rgb(40, 14, 16), rgb(30, 10, 13), band(vnoise(vec2(q.x * 24.0, q.y * 90.0)), 0.66));
    cliffCol = mix(cliffCol, rgb(150, 52, 36), cover(0.006 - (q.x - face)));
    col = mix(col, cliffCol, cliff);
    col = mix(col, rgb(206, 92, 50), cliff * (1.0 - below(cliffTop - 0.004, q.y)));
    col = fortress(col, q, vec2(aspect * 0.8, cliffTop - 0.002), 0.042);

    // Valley floor, with the lava river winding through it.
    float h1 = 0.24 + 0.03 * ridge(q.x + 5.0, 3.5, 2.0);
    vec2 rq = q;
    float ry = 0.155 + 0.035 * sin(q.x * 3.1 + 1.0) + 0.018 * sin(q.x * 7.3);
    float rw = 0.011 + 0.005 * sin(q.x * 5.0) + 0.006 * smoothstep(0.4, 1.6, q.x);
    float rd = abs(q.y - ry);
    float ground = below(h1, q.y);
    // The floor takes the river's light in flat steps.
    float lit = steps(clamp(exp(-max(rd - rw, 0.0) / 0.022), 0.0, 1.0), 4.0) * smoothstep(crater.x - 0.2, crater.x - 0.02, q.x);
    col = mix(col, mix(rgb(44, 16, 18), rgb(132, 44, 30), lit), ground);
    col = mix(col, rgb(150, 54, 36), ground * (1.0 - below(h1 - 0.004, q.y)));
    float river = cover(rw - rd) * ground * cover(q.x - crater.x + 0.08);
    float crust = band(vnoise(vec2(q.x * 55.0, q.y * 140.0)) + 0.3 * vnoise(vec2(q.x * 160.0, q.y * 300.0)), 0.82);
    col = mix(col, rgb(240, 98, 40), river);
    col = mix(col, rgb(255, 202, 104), river * cover(rw * 0.45 - rd));
    col = mix(col, rgb(92, 26, 20), river * crust * cover(rd - rw * 0.3));

    // Volcanic crags in the foreground corners, split by glowing cracks.
    for (int side = 0; side < 2; side++) {
        float x0 = side == 0 ? q.x : aspect - q.x;
        float reach = side == 0 ? 0.55 : 0.4;
        float hc = (side == 0 ? 0.25 : 0.19) * pow(max(1.0 - x0 / reach, 0.0), 1.4)
                 + 0.03 * ridge(q.x * 1.0 + float(side) * 9.0, 9.0, 21.0 + float(side)) * step(x0, reach);
        float crag = below(hc, q.y);
        if (crag <= 0.0)
            continue;
        // Faces: lit toward the river, and a rim where the glow catches the top.
        float facet = vnoise(vec2(q.x * 26.0, q.y * 9.0 + float(side) * 4.0));
        vec3 rock = mix(rgb(24, 9, 11), rgb(44, 15, 16), band(facet, 0.55));
        rock = mix(rock, rgb(176, 62, 38), 1.0 - below(hc - 0.005, q.y));
        float cv = vnoise(vec2(q.x * 18.0, q.y * 18.0) + float(side) * 7.0);
        float crack = cover(0.012 - abs(cv - 0.5)) * cover(hc - 0.02 - q.y);
        rock = mix(rock, rgb(230, 92, 40), crack);
        rock = mix(rock, rgb(255, 190, 96), crack * cover(0.004 - abs(cv - 0.5)));
        col = mix(col, rock, crag);
    }

    // Embers drifting up, brightest near the lava.
    for (int i = 0; i < 90; i++) {
        vec2 h = hash2(vec2(float(i), 4.2));
        vec2 e = vec2(h.x * aspect, 0.1 + 0.85 * h.y * h.y);
        float r = mix(0.0016, 0.0042, hash(vec2(float(i), 9.0)));
        float glow = 1.0 - 0.7 * e.y;
        col = mix(col, rgb(245, 120, 52), cover(r - length(q - e)) * glow);
        col = mix(col, rgb(255, 214, 140), cover(r * 0.45 - length(q - e)) * glow);
    }
    fragColor = vec4(col, 1.0);
}
