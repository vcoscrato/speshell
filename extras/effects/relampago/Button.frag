#version 440
#extension GL_GOOGLE_include_directive : enable
// Relâmpago's button face: racing paint with a sheen across the top, slanted speed
// stripes, and a checkered flag at the right end. Hovered, the stripes race left and a
// bolt of uneven runs crackles along the foot, taking a new shape every tenth of a
// second.
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
    vec4 cPaint;
    vec4 cRubber;
    vec4 cFlag;
    vec4 cCore;
    vec4 cGlow;
} u;
#include "../../lib/common.glsl"

void main() {
    vec2 p = qt_TexCoord0 * u.area;
    float h = u.area.y;
    vec3 col = u.cPaint.rgb;

    // A sheen across the top of the paint.
    col = mix(col, mix(col, u.cFlag.rgb, 0.14), band(h * 0.3 - p.y, 0.0));

    // Speed stripes, slanted, racing left while hovered.
    float s = fract((p.x + p.y * 0.7 + u.time * h * 9.0) / (h * 0.55));
    col = mix(col, mix(u.cPaint.rgb, u.cRubber.rgb, 0.2), band(0.16, s) * band(s, 0.0) * (1.0 - band(p.y, h * 0.9)));
    col = mix(col, mix(u.cPaint.rgb, u.cRubber.rgb, 0.2), step(s, 0.16));

    // The flag: two columns of small checks at the right end, inside the label's padding.
    float cell = h / 8.0;
    float fx = u.area.x - p.x;
    vec2 c = floor(vec2(fx, p.y) / cell);
    vec3 check = mod(c.x + c.y, 2.0) < 1.0 ? u.cRubber.rgb : u.cFlag.rgb;
    col = mix(col, check, step(fx, cell * 2.0) * 0.9);

    // The bolt along the foot.
    float seed = floor(u.time * 10.0);
    float d = boltDist(vec2(p.x, p.y - h * 0.82), h * 0.3, h * 0.08, seed);
    col = mix(col, u.cGlow.rgb, cover(1.8 - d) * u.glow * 0.8);
    col = mix(col, u.cCore.rgb, cover(0.8 - d) * u.glow);

    col = mix(col, u.cRubber.rgb, 0.12 * u.press);
    fragColor = vec4(col, 1.0) * u.qt_Opacity;
}
