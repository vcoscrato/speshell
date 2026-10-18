#version 440
#extension GL_GOOGLE_include_directive : enable
// Air's knob: a ball of wind, arms of air spiralling in it that spin as it travels.
// Held or hovered, the arms catch the light and wisps circle it. The item is larger
// than the knob, to fit the wisps.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 area;          // the item's size, px
    float size;         // the knob's diameter, px
    float turn;         // radians it has spun
    float glow;         // 0..1 held or hovered
    float dim;          // 0..1 switched off
    float time;
    vec4 cBody;
    vec4 cWind;
    vec4 cAccent;
    vec4 cOutline;
} u;
#include "../../lib/common.glsl"

void main() {
    vec2 p = (qt_TexCoord0 - 0.5) * u.area;
    float R = u.size * 0.5 - 1.0;
    float r = length(p);
    float a = atan(p.y, p.x);
    vec4 o = vec4(0.0);

    // Wisps circling it.
    float k = u.glow * (1.0 - u.dim);
    for (int i = 0; i < 2; i++) {
        float fi = float(i);
        float th = mod(a - u.time * (5.0 + fi) - fi * 3.1415927, 6.2831853);
        float rr = R * (1.38 + 0.12 * fi);
        float along = 1.0 - th / 2.2;
        if (along > 0.0)
            o = over(o, u.cWind.rgb, cover(0.3 + 0.8 * along - abs(r - rr)) * along * 0.8 * k);
    }

    // The ball, and the arms in it.
    float d = r - R;
    vec3 body = mix(u.cBody.rgb, u.cWind.rgb, 0.08);
    vec3 col = mix(body, u.cOutline.rgb, 0.3 * band(dot(p, vec2(0.5, 0.8)), R * 0.3));
    vec3 arm = mix(mix(u.cWind.rgb, u.cAccent.rgb, 0.65 * u.glow), u.cOutline.rgb, 0.45 * u.dim);
    for (int i = 0; i < 3; i++) {
        float fi = float(i);
        // Log spiral arms: radius falls as the angle winds in.
        float th = mod(a - u.turn - fi * 2.0943951 + log(max(r, 0.5) / R) * 2.2, 6.2831853);
        float w = 0.5 + 0.9 * (r / R);
        col = mix(col, arm, cover(w - th * r * 0.5) * step(1.5, r));
    }
    col = mix(col, arm, cover(1.6 - r));
    o = over(o, u.cOutline.rgb, cover(-d));
    o = over(o, col, cover(-d - 1.2));
    fragColor = o * u.qt_Opacity;
}
