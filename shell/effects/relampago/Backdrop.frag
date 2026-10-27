#version 440
#extension GL_GOOGLE_include_directive : enable
// Relâmpago backdrop, drawn once over a surface's base color: asphalt with
// a fine grain of aggregate, a checkered flag waving in from the top corner, a few
// pinstripes, and a faint forked bolt low across the bottom, below where a panel's
// controls sit. It stays a few percent off the base so text reads.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;
    vec4 cBase;
    vec4 cDeep;
    vec4 cText;
    vec4 cPaint;
    vec4 cGlow;
} u;
#include "../common/common.glsl"

void main() {
    vec2 p = qt_TexCoord0 * u.size;
    float W = u.size.x, H = u.size.y;
    float m = min(W, H);
    vec3 col = u.cBase.rgb;

    // Asphalt: specks of aggregate, light and dark, and a faint sheen low down.
    vec2 g = floor(p / 3.0);
    float h = hash(g);
    col = mix(col, u.cText.rgb, 0.03 * step(0.93, h));
    col = mix(col, u.cDeep.rgb, 0.25 * step(h, 0.06));
    col = mix(col, u.cDeep.rgb, 0.18 * smoothstep(0.55, 1.0, p.y / H));

    // A checkered flag in the top-right corner, rippling, fading away from it.
    vec2 fq = vec2(W - p.x, p.y);
    float wave = 6.0 * sin(fq.x / 40.0 + fq.y / 70.0);
    vec2 cell = floor((fq + vec2(0.0, wave)) / 15.0);
    float checker = mod(cell.x + cell.y, 2.0);
    float corner = 1.0 - smoothstep(0.0, m * 0.55, length(fq * vec2(1.0, 1.25)));
    float shade = 0.5 + 0.5 * sin(fq.x / 40.0 + fq.y / 70.0 + 1.2);
    col = mix(col, u.cText.rgb, 0.05 * corner * checker * (0.6 + 0.4 * shade));
    col = mix(col, u.cDeep.rgb, 0.3 * corner * (1.0 - checker));

    // Pinstripes along the top-left, trailing off.
    for (int i = 0; i < 3; i++) {
        float fi = float(i);
        float y = 18.0 + 7.0 * fi;
        float len = W * (0.42 - 0.09 * fi);
        float t = p.x / len;
        float w = 0.9 * (1.0 - t);
        col = mix(col, i == 1 ? u.cGlow.rgb : u.cPaint.rgb, (i == 1 ? 0.18 : 0.2) * cover(w - abs(p.y - y)) * step(t, 1.0));
    }

    // The bolt: falling from the right of the bottom quarter to the bottom left,
    // in sharp uneven zigzags with two forks, thickest at the top and coming to a
    // point where it strikes; faint red, edged in gold.
    vec2 a = vec2(W * 0.98, max(H * 0.72, H - m * 0.6));
    vec2 b = vec2(W * 0.12, H + 4.0);
    vec2 dir = normalize(b - a);
    vec2 nrm = vec2(-dir.y, dir.x);
    float L = length(b - a);
    vec2 rel = p - a;
    float s = dot(rel, dir) / L;
    float v = dot(rel, nrm);
    float P = L / 6.0, A = m * 0.06;
    float d = 1e3;
    if (s > -0.05 && s < 1.05) {
        float th = m * 0.016 * (1.0 - 0.85 * s) * smoothstep(0.0, 0.04, s);
        d = boltDist(vec2(s * L + P * 0.5, v), P, A, 3.0) - th;
    }
    for (int i = 0; i < 2; i++) {
        float fi = float(i);
        // From a corner of the main bolt, slanting off and tapering out.
        float k = 1.0 + 2.0 * fi;
        vec2 c = boltCorner(k, P, A, 3.0);
        vec2 o = a + dir * (c.x - P * 0.5) + nrm * c.y;
        vec2 fdir = normalize(vec2(i == 0 ? 0.2 : -0.9, 1.0));
        vec2 fr = p - o;
        float fs = dot(fr, fdir);
        float fl = P * 1.2;
        if (fs > 0.0 && fs < fl) {
            float fv = dot(fr, vec2(-fdir.y, fdir.x));
            float fth = m * 0.01 * (1.0 - fs / fl);
            // Its zigzag shifted so its first corner sits on the main bolt.
            vec2 c0 = boltCorner(0.0, P * 0.45, A * 0.35, 9.0 + fi);
            d = min(d, boltDist(vec2(fs, fv) + c0, P * 0.45, A * 0.35, 9.0 + fi) - fth);
        }
    }
    col = mix(col, u.cPaint.rgb, 0.08 * cover(-d));
    col = mix(col, u.cGlow.rgb, 0.16 * cover(1.0 - abs(d)));

    fragColor = vec4(col, 1.0) * u.qt_Opacity;
}
