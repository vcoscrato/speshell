#version 440
#extension GL_GOOGLE_include_directive : enable
// Sugar's clock face: a raspberry tart from above. A shell of sweet pastry, fluted sixty
// times round, one flute a minute, and dusted with powdered sugar on its far rim; vanilla
// cream under a clear glaze that holds the window's light; raspberries at the hours,
// larger at the quarters; lancet hands of dark chocolate turning under a raspberry, and
// a thread of coulis for the seconds.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 area;          // the item's size, px
    float hourTurn;     // each hand's turns from twelve, clockwise
    float minuteTurn;
    float secondTurn;
    float seconds;      // 1 shows the thread of coulis
    vec4 cCrust;
    vec4 cCrustDeep;
    vec4 cCrustLight;
    vec4 cCream;
    vec4 cCreamShade;
    vec4 cSheen;
    vec4 cChocolate;
    vec4 cChocolateDark;
    vec4 cBerry;
    vec4 cBerryDeep;
    vec4 cBerryLight;
} u;
#include "../common/common.glsl"

const float TAU = 6.2831853;
const float PI = 3.1415927;
const vec2 LIGHT = vec2(-0.6, -0.8);    // toward the light, up and to the left

vec2 at(float turn, float r) {
    float a = turn * TAU;
    return vec2(sin(a), -cos(a)) * r;
}

float turnOf(vec2 p) {
    return fract(atan(p.x, -p.y) / TAU + 1.0);
}

// p in a hand's frame: x across it, y out along it.
vec2 handFrame(vec2 p, float turn) {
    return rot(p, -turn * TAU) * vec2(1.0, -1.0);
}

// A raspberry of radius rr at c, seen from above with its hollow up: a small dark
// hollow, six plump drupelets round it and ten more round them, which make its edge
// bumpy. Each is a glossy sphere lit from the upper left, a little uneven, and the
// whole berry is a dome, deeper red toward its far side.
vec4 raspberry(vec4 o, vec2 p, vec2 c, float rr, float seed) {
    vec2 q = p - c;
    float l = length(q);
    o = over(o, u.cCreamShade.rgb * 0.65, 0.6 * smoothstep(rr * 0.35, -rr * 0.15, length(q - vec2(rr * 0.18, rr * 0.26)) - rr));
    if (l > rr * 1.25)
        return o;
    float spin = seed * 1.7;
    float best = 1e3, bestR = 1.0;
    vec2 bc = vec2(0.0);
    for (int i = 0; i < 2; i++) {
        float cnt = i == 0 ? 6.0 : 10.0;
        float ring = rr * (i == 0 ? 0.38 : 0.74);
        float off = spin + float(i) * 0.3;
        float k = floor((atan(q.y, q.x) - off) / TAU * cnt + 0.5);
        for (int j = -1; j <= 1; j++) {
            float kj = k + float(j);
            float ang = (kj + 0.12 * (hash(vec2(kj, seed + float(i))) - 0.5)) / cnt * TAU + off;
            float dr = rr * (i == 0 ? 0.27 : 0.28) * (0.9 + 0.2 * hash(vec2(seed + float(i) * 5.0, kj)));
            float d = length(q - vec2(cos(ang), sin(ang)) * ring) - dr;
            if (d < best) {
                best = d;
                bc = vec2(cos(ang), sin(ang)) * ring;
                bestR = dr;
            }
        }
    }
    vec2 n = (q - bc) / bestR;
    float dome = dot(q / rr, -LIGHT);
    vec3 col = mix(u.cBerry.rgb, u.cBerryLight.rgb, 0.6 * smoothstep(0.0, 0.8, dot(n, LIGHT)));
    col = mix(col, u.cBerryDeep.rgb, 0.75 * smoothstep(0.55, 1.0, length(n)) + 0.3 * smoothstep(-0.2, 1.0, dome));
    col = mix(col, u.cSheen.rgb, 0.8 * cover((0.22 - length(n - LIGHT * 0.45)) * bestR) * (1.0 - 0.5 * smoothstep(0.0, 1.0, dome)));
    vec3 gap = mix(u.cBerryDeep.rgb, u.cChocolateDark.rgb, 0.5);
    o = over(o, gap, cover(-best + 0.7));
    o = over(o, col, cover(-best));
    return over(o, gap, cover(rr * 0.13 - l));
}

// A lancet hand: a long leaf, widest a third of the way out, its point sharp, a
// short stem behind the pivot ending in a round tail. Signed distance.
float lancet(vec2 q, float len, float w, float tail) {
    float t = q.y / len;
    float hw = w * (t < 0.33 ? mix(0.45, 1.0, sin(t / 0.33 * PI * 0.5)) : (1.0 - t) / 0.67);
    float blade = max(abs(q.x) - max(hw, 0.0), max(-q.y, q.y - len));
    float stem = max(abs(q.x) - w * 0.45, max(-q.y - tail, q.y));
    return min(min(blade, stem), length(q + vec2(0.0, tail)) - w * 0.9);
}

void main() {
    vec2 p = (qt_TexCoord0 - 0.5) * u.area;
    float R = min(u.area.x, u.area.y) * 0.5 - 1.5;
    float r = length(p);
    float turn = turnOf(p);
    float lit = dot(p / R, LIGHT);
    vec4 o = vec4(0.0);

    // ── The shell, fluted sixty times, each flute rounded toward the light ──
    float ph = fract(turn * 60.0);
    float outer = R * (0.965 + 0.035 * sin(PI * ph));
    vec2 tn = normalize(vec2(-p.y, p.x) + 1e-4);
    vec3 crust = mix(u.cCrust.rgb, u.cCrustLight.rgb, 0.5 * smoothstep(-0.3, 0.9, lit));
    crust = mix(crust, u.cCrustDeep.rgb, 0.55 * smoothstep(0.2, 1.0, (ph - 0.5) * 2.0 * dot(tn, -LIGHT) + 0.3) * smoothstep(R * 0.86, R * 0.92, r));
    crust = mix(crust, u.cCrustDeep.rgb, 0.4 * smoothstep(0.5, 0.75, fbm(p / (R * 0.06))));
    // Powdered sugar, sifted on the far rim: a haze, and grains, each a dot.
    float sift = smoothstep(0.35, 0.8, fbm(p / (R * 0.1) + 5.0)) * smoothstep(-0.4, 0.6, -p.y / R);
    float g = max(1.6, R * 0.02);
    vec2 gc = floor(p / g);
    vec2 gp = (gc + 0.5 + (hash2(gc) - 0.5) * 0.6) * g;
    float grain = step(0.45, hash(gc + 3.0)) * cover(g * 0.32 - length(p - gp));
    crust = mix(crust, u.cSheen.rgb, sift * (0.35 + 0.6 * grain));
    o = over(o, u.cCrustDeep.rgb * 0.7, cover(outer - r + 0.8));
    o = over(o, crust, cover(outer - r));

    // ── The inner wall, in shadow, and the glazed cream ──
    float Rf = R * 0.86;
    o = over(o, u.cCrustDeep.rgb, cover(Rf + R * 0.025 - r));
    vec3 cream = mix(u.cCream.rgb, u.cCreamShade.rgb, 0.25 * smoothstep(Rf * 0.6, Rf, r) * smoothstep(-0.2, 0.8, -lit));
    vec2 m = p / Rf;
    float cres = smoothstep(0.55, 0.8, length(m)) * (1.0 - smoothstep(0.8, 0.92, length(m)));
    cream = mix(cream, u.cSheen.rgb, 0.4 * cres * smoothstep(0.3, 0.95, dot(normalize(m + 1e-4), LIGHT)));
    o = over(o, cream, cover(Rf - r));

    // ── Raspberries at the hours, larger at the quarters; a berry's neighbors too,
    // for the shadow it casts past its own hour ──
    float hour = floor(turn * 12.0 + 0.5);
    for (int k = -1; k <= 1; k++) {
        float h = mod(hour + float(k), 12.0);
        o = raspberry(o, p, at(h / 12.0, R * 0.7), R * (mod(h, 3.0) < 0.5 ? 0.11 : 0.085), h);
    }

    // ── The lancet hands in dark chocolate, their shadows first, each lit along its
    // left edge ──
    vec2 sh = vec2(R * 0.022, R * 0.032);
    float hd = lancet(handFrame(p, u.hourTurn), R * 0.48, R * 0.06, R * 0.08);
    float md = lancet(handFrame(p, u.minuteTurn), R * 0.74, R * 0.045, R * 0.1);
    float shd = min(lancet(handFrame(p - sh, u.hourTurn), R * 0.48, R * 0.06, R * 0.08),
                    lancet(handFrame(p - sh, u.minuteTurn), R * 0.74, R * 0.045, R * 0.1));
    o = over(o, u.cCreamShade.rgb * 0.6, 0.45 * cover(-shd + 0.5));
    o = over(o, mix(u.cChocolateDark.rgb, u.cChocolate.rgb, 0.8 * step(handFrame(p, u.minuteTurn).x, 0.0)), cover(-md));
    o = over(o, mix(u.cChocolateDark.rgb, u.cChocolate.rgb, 0.8 * step(handFrame(p, u.hourTurn).x, 0.0)), cover(-hd));

    // ── A thread of coulis with the seconds ──
    if (u.seconds > 0.5) {
        vec2 q = handFrame(p, u.secondTurn);
        float d = max(abs(q.x) - max(0.6, R * 0.008), max(-q.y - R * 0.16, q.y - R * 0.8));
        d = min(d, length(q + vec2(0.0, R * 0.16)) - R * 0.03);
        o = over(o, u.cBerryDeep.rgb, cover(-d));
    }

    // ── A raspberry at the middle ──
    o = raspberry(o, p, vec2(0.0), R * 0.075, 5.0);

    fragColor = o * u.qt_Opacity;
}
