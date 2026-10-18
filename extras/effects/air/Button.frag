#version 440
#extension GL_GOOGLE_include_directive : enable
// Air's button face: the accent, lighter along a wavering band of sky at the top and
// shaded at the foot, with dashes of wind along gently curving streamlines above and
// below the label. Hovered, the dashes blow through and a leaf tumbles along.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 area;
    float glow;
    float press;
    vec2 at;
    float time;
    vec4 cBase;
    vec4 cWind;
    vec4 cShade;
    vec4 cLeaf;
} u;
#include "../../lib/common.glsl"

void main() {
    vec2 p = qt_TexCoord0 * u.area;
    float h = u.area.y;
    vec3 col = u.cBase.rgb;

    // Sky above, shade below, each behind a wavering edge.
    col = mix(col, mix(col, u.cWind.rgb, 0.14), band(h * 0.26 + 1.2 * sin(p.x / 13.0) - p.y, 0.0));
    col = mix(col, mix(col, u.cShade.rgb, 0.1), band(p.y - h * 0.8 - 1.0 * sin(p.x / 17.0 + 2.0), 0.0));

    // Dashes of wind along streamlines clear of the label.
    float blow = u.time * h * 3.2;
    for (int i = 0; i < 3; i++) {
        float fi = float(i);
        float y = h * (i == 0 ? 0.16 : (i == 1 ? 0.86 : 0.5)) + h * 0.07 * sin((p.x - blow * 0.3) / (h * 0.55) + fi * 2.1);
        float period = h * (2.2 + 0.7 * fi);
        float s = fract((p.x - blow * (1.0 + 0.3 * fi) + fi * 37.0) / period);
        float dash = smoothstep(0.0, 0.1, s) * smoothstep(0.5, 0.25, s);
        // The middle line only blows while hovered, so it never sits behind the label.
        float k = i == 2 ? u.glow * 0.5 : 0.55 + 0.35 * u.glow;
        col = mix(col, u.cWind.rgb, cover(0.55 - abs(p.y - y)) * dash * k);
    }

    // A leaf riding the wind across while hovered.
    float span = u.area.x + h * 2.0;
    float lx = mod(u.time * 0.45 * span, span) - h;
    vec2 leaf = vec2(lx, h * 0.24 + h * 0.1 * sin(lx / (h * 0.5)));
    vec2 q = rot(p - leaf, u.time * 5.0);
    col = mix(col, mix(u.cLeaf.rgb, u.cShade.rgb, 0.15), cover(-sdLeaf(q, h * 0.15, h * 0.1)) * u.glow);

    col = mix(col, u.cShade.rgb, 0.12 * u.press);
    fragColor = vec4(col, 1.0) * u.qt_Opacity;
}
