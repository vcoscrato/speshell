#version 440
#extension GL_GOOGLE_include_directive : enable
// Cosmos's knob: a banded planet, lit from the top left, whose bands turn as it rolls
// and whose moon orbits as it travels, passing behind it. Held or hovered, a ring
// tilts around it. The planet fills the knob's square, its dark rim reaching just past it
// so it caps the track's end at 100%; the moon and the ring draw outside, in an item
// larger than the knob.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 area;          // the item's size, px
    float size;         // the planet's diameter, px
    float turn;         // radians it has turned
    float glow;         // 0..1 held or hovered
    float dim;          // 0..1 switched off
    vec4 cBody;
    vec4 cBand;
    vec4 cLight;
    vec4 cShade;
    vec4 cRing;
} u;
#include "../common/common.glsl"

void main() {
    vec2 p = (qt_TexCoord0 - 0.5) * u.area;
    // The rim's outer edge sits half a pixel past the square, the body's colour inside it.
    float R = u.size * 0.5 + 0.5;
    vec4 o = vec4(0.0);

    // The ring, tilted: its far half behind the planet, its near half in front.
    vec2 rq = vec2(p.x * 0.94 + p.y * 0.34, -p.x * 0.34 + p.y * 0.94);
    float ringD = abs(length(rq * vec2(1.0, 3.2)) - R * 1.55) / 1.6;
    float ring = cover(1.0 - ringD) * u.glow * (1.0 - u.dim);
    float front = step(0.0, rq.y);

    // The moon, orbiting on a tilted ellipse as the planet travels.
    float m = u.turn * 0.6 + 0.8;
    vec2 moon = vec2(cos(m), sin(m) * 0.38) * R * 1.75;
    moon = vec2(moon.x * 0.94 - moon.y * 0.34, moon.x * 0.34 + moon.y * 0.94);
    bool moonBehind = sin(m) < 0.0;
    float md = length(p - moon) - R * 0.3;
    vec3 moonCol = mix(u.cLight.rgb, u.cShade.rgb, 0.45 * band(dot(p - moon, vec2(0.6, 0.8)), 0.0));
    if (moonBehind) {
        o = over(o, u.cShade.rgb, cover(-md));
        o = over(o, moonCol, cover(-md - 1.0));
    }
    o = over(o, u.cRing.rgb, ring * (1.0 - front));

    // The planet: bands that turn with it, a cel-shaded terminator.
    float d = length(p) - R;
    // Turning clockwise as it travels right, like a rolling ball.
    float c = cos(u.turn), s = sin(u.turn);
    vec2 q = mat2(c, -s, s, c) * p;
    // Two broad bands across it, few enough to read at a knob's size.
    float bands = sin(q.y / R * 2.6 + 0.4 + 0.9 * sin(q.x / R * 1.6));
    vec3 col = mix(u.cBody.rgb, u.cBand.rgb, band(bands, 0.45));
    col = mix(col, u.cLight.rgb, 0.35 * band(-dot(p, vec2(0.6, 0.8)), R * 0.45));
    col = mix(col, u.cShade.rgb, 0.55 * band(dot(p, vec2(0.6, 0.8)), R * 0.25));
    col = mix(col, u.cShade.rgb, 0.45 * u.dim);
    // A lit limb on the top left, so the planet reads against an accent-coloured fill.
    float limb = band(-dot(p / R, vec2(0.6, 0.8)) - 0.35, 0.0) * (1.0 - cover(-d - 2.6));
    col = mix(col, u.cLight.rgb, 0.6 * limb * (1.0 - u.dim));
    o = over(o, u.cShade.rgb, cover(-d));
    o = over(o, col, cover(-d - 1.4));

    o = over(o, u.cRing.rgb, ring * front);
    if (!moonBehind) {
        o = over(o, u.cShade.rgb, cover(-md));
        o = over(o, moonCol, cover(-md - 1.0));
    }
    fragColor = o * u.qt_Opacity;
}
