#version 440
#extension GL_GOOGLE_include_directive : enable
// One particle of Natal's small effects, by `kind`: 0 a glint, a four-pointed
// twinkle; 1 a snowflake that crystallizes from its middle, six dendrite arms growing
// side branches as their tips pass, a different flake for each seed, that glints and
// then breaks, its arms drifting apart and falling as they fade; 2 a tiny flake that
// drifts down and fades; 3 the warm bloom of fairy lights coming on, flat steps of
// light that swell and fade.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float age;          // 0..1 over its life
    float seed;
    float kind;
    float turn;         // a flake's turn, radians
    float size;         // px across
    vec4 cSnow;
    vec4 cIce;
    vec4 cShade;
    vec4 cSheen;
    vec4 cGlow;
    vec4 cGold;
} u;
#include "../common/common.glsl"

// A four-pointed twinkle of radius s.
float twinkle(vec2 p, float s) {
    vec2 q = abs(p) / max(s, 1e-3);
    return (sqrt(q.x) + sqrt(q.y) - 1.0) * s * 0.45;
}

vec4 glint(vec2 p, float R) {
    float k = clamp(u.age / 0.3, 0.0, 1.0);
    float s = R * sin(PI * min(1.0, u.age * 1.15)) * (1.0 + 0.15 * (1.0 - k));
    if (s < 0.4)
        return vec4(0.0);
    float d = twinkle(rot(p, 0.6 * u.age + u.seed), s);
    vec4 c = over(vec4(0.0), u.cIce.rgb, cover(1.1 - d) * 0.7);
    return over(c, u.cSheen.rgb, cover(-d));
}

// Distance to one arm of the flake along +x, grown to g of its length R: a spine,
// side branches at 60 degrees that sprout as the tip passes them, and on some flakes
// a small plate at the tip.
float arm(vec2 q, float R, float g) {
    q.y = abs(q.y);
    float L = R * g;
    float d = sdSeg(q, vec2(0.0), vec2(L, 0.0));
    float nb = u.seed < 0.5 ? 2.0 : 3.0;
    for (int i = 0; i < 3; i++) {
        float fi = float(i);
        if (fi >= nb)
            break;
        float at = R * mix(0.3, 0.74, (fi + 0.4 * hash(vec2(fi, u.seed))) / nb);
        float full = R * mix(0.18, 0.34, hash(vec2(fi, u.seed + 1.7))) * (1.0 - 0.45 * at / R);
        float l = clamp((L - at) * 0.8, 0.0, full);
        if (l > 0.0)
            d = min(d, sdSeg(q, vec2(at, 0.0), vec2(at, 0.0) + vec2(0.5, 0.866) * l));
    }
    // A hexagonal plate at the tip, on a third of the flakes.
    if (hash(vec2(u.seed, 9.1)) < 0.35 && g > 0.85) {
        vec2 t = abs(q - vec2(L, 0.0));
        float hx = max(t.x * 0.866 + t.y * 0.5, t.y) - R * 0.09 * smoothstep(0.85, 1.0, g);
        d = min(d, max(hx, 0.0));
    }
    return d;
}

vec4 flake(vec2 p, float R) {
    float t = u.age * 0.8;                       // s
    float g = 1.0 - pow(1.0 - clamp(t / 0.25, 0.0, 1.0), 2.2);
    float brk = smoothstep(0.38, 0.62, t);
    float fade = 1.0 - smoothstep(0.45, 0.64, t);
    float w = max(0.55, R * 0.035) * (1.0 - 0.4 * brk);
    float d = 1e3;
    for (int k = 0; k < 6; k++) {
        float th = u.turn + float(k) * PI / 3.0;
        vec2 dir = vec2(cos(th), sin(th));
        // Breaking, each arm drifts out and falls, turning a little.
        vec2 off = dir * brk * R * 0.3 + vec2(0.0, brk * brk * R * 0.35);
        vec2 q = rot(p - off, -th - brk * 0.4 * (hash(vec2(float(k), u.seed)) - 0.5));
        d = min(d, arm(q, R * (1.0 - 0.3 * brk), g));
    }
    // The hexagon it grew from, open in the middle.
    vec2 h = abs(rot(p, u.turn));
    float hex = abs(max(h.x * 0.866 + h.y * 0.5, h.y) - R * 0.12 * g);
    d = min(d, mix(hex, 1e3, brk));
    float shine = smoothstep(0.2, 0.28, t) * (1.0 - smoothstep(0.3, 0.42, t));
    vec3 col = mix(u.cSnow.rgb, u.cSheen.rgb, shine);
    vec4 c = over(vec4(0.0), u.cShade.rgb, cover(w + 1.0 - d) * 0.35 * fade);
    c = over(c, col, cover(w - d) * fade);
    // It glints as it finishes growing.
    float s = R * 0.55 * sin(PI * clamp((t - 0.2) / 0.2, 0.0, 1.0));
    if (s > 0.4) {
        float td = twinkle(rot(p, 0.785), s);
        c = over(c, u.cSheen.rgb, cover(-td));
    }
    return c;
}

vec4 mote(vec2 p, float R) {
    float a = smoothstep(0.0, 0.12, u.age) * (1.0 - smoothstep(0.55, 1.0, u.age));
    vec2 q = p;
    float d = 1e3;
    for (int k = 0; k < 3; k++) {
        vec2 dir = vec2(cos(float(k) * PI / 3.0), sin(float(k) * PI / 3.0));
        d = min(d, sdSeg(q, -dir * R * 0.85, dir * R * 0.85));
    }
    float w = max(0.45, R * 0.13);
    vec4 c = over(vec4(0.0), u.cShade.rgb, cover(w + 0.8 - d) * 0.3 * a);
    c = over(c, mix(u.cSnow.rgb, u.cIce.rgb, u.seed), cover(w - d) * a);
    return over(c, u.cSheen.rgb, cover(w * 1.4 - length(p)) * a);
}

vec4 bloom(vec2 p, float R) {
    float k = smoothstep(0.0, 0.25, u.age);
    float a = k * (1.0 - smoothstep(0.35, 1.0, u.age));
    float r = length(p / vec2(1.0, 0.6)) / (R * mix(0.7, 1.0, k));
    vec4 c = over(vec4(0.0), u.cGold.rgb, cover((1.0 - r) * R) * 0.1 * a);
    return over(c, u.cGlow.rgb, cover((0.62 - r) * R) * 0.14 * a);
}

void main() {
    vec2 p = (qt_TexCoord0 - 0.5) * u.size;
    float R = u.size * 0.5 - 1.0;
    vec4 c = u.kind < 0.5 ? glint(p, R) : u.kind < 1.5 ? flake(p, R * 0.72) : u.kind < 2.5 ? mote(p, R) : bloom(p, R);
    fragColor = c * u.qt_Opacity;
}
