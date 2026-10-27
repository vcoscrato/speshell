#version 440
#extension GL_GOOGLE_include_directive : enable
// Sugar backdrop, drawn once over a surface's base color: dark chocolate with a soft
// grain; two drizzles of cream looping across the lower part; and along the bottom,
// below where a panel's controls sit, a ganache layer topped by a piped shell border
// of frosting.
// It stays a few percent off the base so text reads.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;
    vec4 cBase;
    vec4 cInk;
    vec4 cCream;
    vec4 cFrost;
} u;
#include "../common/common.glsl"

void main() {
    vec2 p = qt_TexCoord0 * u.size;
    float W = u.size.x, H = u.size.y;
    float m = min(W, H);
    vec3 col = u.cBase.rgb;

    // Chocolate: a soft mottle, darkening low down.
    col = mix(col, u.cInk.rgb, 0.18 * smoothstep(0.35, 0.75, fbm(p / 90.0)));
    col = mix(col, u.cInk.rgb, 0.2 * smoothstep(0.5, 1.0, p.y / H));

    // Two drizzles of cream looping across the lower part.
    for (int i = 0; i < 2; i++) {
        float fi = float(i);
        float y0 = H - m * (0.42 - 0.12 * fi);
        float x = p.x / (m * 0.16) + fi * 1.7;
        // A looping line: a slanted wave that doubles back on itself now and then.
        float y = y0 + m * 0.045 * sin(x * 1.3 + fi) + m * 0.02 * sin(x * 3.1 + 2.0 * fi);
        float w = mix(0.8, 1.8, 0.5 + 0.5 * sin(x * 0.7 + fi * 3.0));
        col = mix(col, u.cCream.rgb, 0.07 * cover(w - abs(p.y - y)));
    }

    // Along the bottom: ganache, and a shell border of frosting piped along its top.
    float ganache = H - m * 0.075 + m * 0.006 * sin(p.x / 23.0);
    col = mix(col, u.cInk.rgb, 0.35 * cover(p.y - ganache));
    float P = m * 0.05;
    float k = floor(p.x / P);
    float f = fract(p.x / P);
    // Each shell swells from a point to a round head and trails off into the next.
    float shellH = m * 0.022 * sin(3.1416 * pow(f, 0.7)) * mix(0.85, 1.0, hash(vec2(k, 2.0)));
    float sy = ganache - m * 0.002;
    float dShell = abs(p.y - sy) - shellH;
    col = mix(col, u.cFrost.rgb, 0.1 * cover(-dShell));
    col = mix(col, u.cCream.rgb, 0.06 * cover(-dShell) * band(sy - p.y, shellH * 0.3) * step(f, 0.6));

    fragColor = vec4(col, 1.0) * u.qt_Opacity;
}
