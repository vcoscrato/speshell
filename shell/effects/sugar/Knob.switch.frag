#version 440
#extension GL_GOOGLE_include_directive : enable
// Sugar's switch: an éclair seen from above, the whole switch, with a glossy disc of
// dark chocolate edged in gold for its thumb. The choux is baked golden and unevenly,
// browner toward its rim, and fluted along its length by the star tip. Behind the
// disc lies strawberry fondant, poured from the éclair's left end to a rounded lip
// just past the disc, its long edges wavering short of the rim, glossy with a long
// streak of the window's light and a fleck of gold leaf: switched on, the disc has
// drawn it the whole length; off, the éclair is bare.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 area;          // the item's size, px
    vec2 body;          // the switch's size, px
    vec2 origin;        // px, the switch's top-left in the item
    vec2 thumb;         // px, the disc's center from the switch's top-left
    float radius;       // the disc's radius, px
    float lift;         // 0 pressed down .. 1 hovered, raised off the éclair
    vec4 cChoux;
    vec4 cChouxDeep;
    vec4 cChouxLight;
    vec4 cGlaze;
    vec4 cGlazeLight;
    vec4 cGlazeShade;
    vec4 cSheen;
    vec4 cChocolate;
    vec4 cGold;
    vec4 cGoldShade;
} u;
#include "../common/common.glsl"

const vec2 LIGHT = vec2(-0.6, -0.8);    // toward the light, up and to the left

void main() {
    vec2 p = qt_TexCoord0 * u.area - u.origin;
    float W = u.body.x, H = u.body.y;
    vec2 mid = u.body * 0.5;
    vec4 o = vec4(0.0);

    // ── The choux, a capsule a hair larger than the switch so its track never shows ──
    float d = sdRoundRect(p - mid, mid + 0.4, H * 0.5 + 0.4);
    float v = clamp((p.y - mid.y) / (H * 0.5), -1.0, 1.0);    // across it, -1 lit
    float rim = smoothstep(-H * 0.32, 0.0, d);
    vec3 c = mix(u.cChoux.rgb, u.cChouxLight.rgb, 0.55 * smoothstep(0.1, -0.7, v) * (1.0 - rim));
    c = mix(c, u.cChouxDeep.rgb, 0.75 * rim * smoothstep(-0.6, 0.6, v + 0.35));
    // Baked unevenly, and fluted along its length by the star tip that piped it.
    c = mix(c, u.cChouxDeep.rgb, 0.35 * smoothstep(0.45, 0.75, fbm(p * vec2(0.3, 0.3) + 2.0)));
    float flute = abs(fract(v * 2.2 + 0.08 * sin(p.x * 0.4) + 0.5) - 0.5);
    c = mix(c, u.cChouxDeep.rgb, 0.3 * (1.0 - smoothstep(0.04, 0.22, flute)) * (1.0 - rim));
    o = over(o, c, cover(-d));

    // ── The fondant, from the left end to its lip, a rounded bulge just past the disc ──
    float front = mix(-H * 0.4, W + H * 0.4, (u.thumb.x - H * 0.5) / max(1.0, W - H));
    float wave = 0.5 + 0.5 * sin(p.x * 0.55 + 1.3 * sign(v)) * sin(p.x * 0.23 + 2.0);
    float gd = d + H * (0.11 + 0.06 * wave);
    gd = max(gd, p.x - front - H * 0.22 * (1.0 - v * v));
    if (gd < 2.0) {
        // Its thickness casts a thin shadow onto the choux, below and to the right.
        o = over(o, u.cChouxDeep.rgb * 0.7, 0.6 * cover(0.9 - (gd - 0.6)) * cover(-d));
        vec3 g = mix(u.cGlaze.rgb, u.cGlazeShade.rgb, 0.6 * smoothstep(0.1, 0.9, v));
        g = mix(g, u.cGlazeLight.rgb, 0.5 * smoothstep(0.0, -0.8, v));
        // Its rounded edge, darker where it falls away.
        g = mix(g, u.cGlazeShade.rgb, 0.5 * smoothstep(-1.4, 0.0, gd));
        // The window's light in one long streak, and a small one at the near end.
        float streak = sdSeg(p, vec2(H * 0.5, H * 0.3), vec2(max(H * 0.5, front - H * 0.35), H * 0.3)) - H * 0.065;
        g = mix(g, u.cSheen.rgb, 0.75 * cover(-streak));
        g = mix(g, u.cSheen.rgb, 0.6 * cover(H * 0.05 - length(p - vec2(H * 0.24, H * 0.52))));
        // A fleck of gold leaf, crumpled.
        vec2 fq = rot(p - vec2(W * 0.42, H * 0.64), 0.6);
        float fa = atan(fq.y, fq.x);
        float fd = length(fq * vec2(1.0, 1.5)) - H * 0.09 * (1.0 + 0.3 * sin(fa * 3.0) + 0.2 * sin(fa * 7.0 + 1.0));
        vec3 leaf = mix(u.cGoldShade.rgb, u.cGold.rgb, smoothstep(0.3, 0.7, vnoise(fq * 1.6 + 4.0)));
        g = mix(g, leaf, cover(-fd));
        o = over(o, g, cover(-gd));
    }

    // ── The disc of chocolate, its shadow first ──
    vec2 q = p - u.thumb;
    float R = u.radius;
    vec2 sh = vec2(0.5, 0.8) * mix(0.6, 1.8, u.lift);
    o = over(o, u.cChouxDeep.rgb * 0.45, 0.55 * smoothstep(0.9, -0.9, length(q - sh) - R));
    float dd = length(q) - R;
    if (dd < 1.5) {
        vec2 n = q / R;
        vec3 ch = mix(u.cChocolate.rgb, u.cChocolate.rgb * 0.7, smoothstep(-0.3, 0.9, dot(n, -LIGHT)));
        // Tempered, so it shines: a soft crescent of light near its upper left.
        float cres = smoothstep(0.45, 0.7, length(n)) * (1.0 - smoothstep(0.72, 0.84, length(n)));
        ch = mix(ch, u.cSheen.rgb, 0.4 * cres * smoothstep(0.3, 0.9, dot(normalize(n + 1e-4), LIGHT)));
        // Its edge, in gold, lit toward the light.
        float gw = max(0.7, R * 0.13);
        vec3 gold = mix(u.cGoldShade.rgb, u.cGold.rgb, smoothstep(-0.6, 0.6, dot(n, LIGHT)));
        o = over(o, gold, cover(-dd));
        o = over(o, ch, cover(-dd - gw));
    }

    fragColor = o * u.qt_Opacity;
}
