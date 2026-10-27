#version 440
#extension GL_GOOGLE_include_directive : enable
// Fire's knob: an ember, dark coal webbed with glowing cracks that roll with it. Held
// or hovered, the cracks burn hotter and a flame rises off it, leaning away from the
// way it moves; switched off, it cools to ash. The item is larger than the knob, to
// fit the flame.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 area;          // the item's size, px
    vec2 center;        // the knob's center, from the item's
    float size;         // the knob's diameter, px
    float turn;         // radians it has rolled
    float glow;         // 0..1 held or hovered
    float dim;          // 0..1 switched off
    float lean;         // -1..1 the flame bent by motion
    float time;
    vec4 cCore;
    vec4 cMid;
    vec4 cOuter;
    vec4 cEdge;
    vec4 cCoal;
    vec4 cAsh;
} u;
#include "../common/common.glsl"

void main() {
    vec2 p = (qt_TexCoord0 - 0.5) * u.area - u.center;
    float R = u.size * 0.5 - 1.0;
    vec4 o = vec4(0.0);

    // The flame, behind the ember.
    float f = u.glow * (1.0 - u.dim);
    if (f > 0.01) {
        float H = R * (1.6 + 0.35 * sin(u.time * 13.0) + 0.2 * sin(u.time * 29.0)) * f;
        float t = clamp(-p.y / max(H, 1.0), 0.0, 1.0);
        float sway = (u.lean * 0.9 + 0.18 * sin(t * 4.0 - u.time * 16.0)) * R * t * t;
        float hw = R * 0.75 * pow(1.0 - t, 0.8);
        float d = max(max(abs(p.x - sway) - hw, -p.y - H), p.y - R * 0.3);
        float inside = clamp(-d / max(hw, 1.0), 0.0, 1.0);
        o = over(o, u.cEdge.rgb, cover(-d));
        o = over(o, u.cOuter.rgb, cover(-d - 1.0));
        o = over(o, u.cMid.rgb, band(inside, 0.4) * step(p.y, 0.0));
        o = over(o, u.cCore.rgb, band(inside, 0.72) * step(p.y, 0.0));
    }

    // The ember.
    // Rolling clockwise as it travels right.
    float c = cos(u.turn), s = sin(u.turn);
    vec2 q = mat2(c, -s, s, c) * p;
    float d = length(p) - R;
    float crack = voronoiEdge(q + 40.0, R * 0.9, 0.9);
    float heat = mix(0.55, 1.0, u.glow) * (1.0 - 0.7 * u.dim);
    vec3 coal = mix(u.cCoal.rgb, u.cEdge.rgb, 0.35);
    // Lit from the top left, a cel step darker below.
    coal = mix(coal, u.cCoal.rgb, band(dot(p, vec2(0.5, 0.8)), R * 0.25));
    // Switched off, it cools to ash.
    coal = mix(coal, u.cAsh.rgb, 0.55 * u.dim);
    vec3 col = coal;
    col = mix(col, u.cOuter.rgb, (1.0 - smoothstep(0.6, 1.6, crack)) * heat);
    col = mix(col, u.cMid.rgb, (1.0 - smoothstep(0.2, 0.9, crack)) * heat * heat);
    col = mix(col, u.cCore.rgb, (1.0 - smoothstep(0.0, 0.5, crack)) * u.glow * (1.0 - u.dim));
    o = over(o, u.cEdge.rgb * 0.5, cover(-d));
    o = over(o, col, cover(-d - 1.2));
    fragColor = o * u.qt_Opacity;
}
