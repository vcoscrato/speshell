#version 440
#extension GL_GOOGLE_include_directive : enable
// A whirlwind eye opens at the center and widens until the outgoing wallpaper is
// gone. Its edge is torn into tongues that curl with the spin; around it the
// wallpaper is wrung into the spin, smeared along it, and the rim is a bright band
// of air.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 resolution;
    vec2 center;
    float eye;         // px, eye radius
    float twist;       // rad, rotation at the rim
    float spin;
    float time;
    vec4 cRim;
    vec4 cHaze;
    vec4 cGlint;
} u;
layout(binding = 1) uniform sampler2D source;
#include "../common/common.glsl"

void main() {
    vec2 p = qt_TexCoord0 * u.resolution;
    vec2 rel = p - u.center;
    float r = length(rel);
    vec2 dir = rel / max(r, 1.0);
    // The eye is lopsided, and its edge torn into tongues of wind that curl along
    // spiral arms and drift round with the spin.
    float eye = max(u.eye, 1.0);
    vec2 arm = rot(dir, u.spin * (1.6 * log(max(r, 1.0) / eye) - 0.9 * u.time));
    float tear = fbm(arm * 2.3 + 7.0) - 0.5 + 0.45 * (vnoise(arm * 7.0 + 3.0) - 0.5);
    float rim = eye * (1.0 + 0.12 * (vnoise(dir * 1.5 + 4.0) - 0.5)) + tear * min(0.3 * eye + 6.0, 110.0);
    float out_ = r - rim;                                  // > 0 outside the eye

    // Wrung into the spin: turned most at the rim, and smeared along the turn there.
    float k = exp(-max(out_, 0.0) / (0.35 * max(u.eye, 120.0)));
    float a = u.twist * u.spin * k;
    float smear = 0.035 * u.twist * u.spin * k * k;
    vec4 col = vec4(0.0);
    for (int i = 0; i < 3; i++) {
        float ai = a + smear * float(i);
        vec2 q = mat2(cos(ai), -sin(ai), sin(ai), cos(ai)) * rel;
        col += texture(source, (u.center + q) / u.resolution) * (i == 0 ? 0.5 : 0.25);
    }

    // Near the rim the wallpaper pales into the wind before it is torn away.
    float aa = clamp(fwidth(out_), 1e-3, 1.5);
    float haze = 1.0 - smoothstep(40.0 - aa, 40.0 + aa, out_);
    float band1 = 1.0 - smoothstep(16.0 - aa, 16.0 + aa, out_);
    float band2 = 1.0 - smoothstep(6.0 - aa, 6.0 + aa, out_);
    col.rgb = mix(col.rgb, u.cHaze.rgb * col.a, haze * 0.35);
    col.rgb = mix(col.rgb, u.cRim.rgb * col.a, band1 * 0.55);
    col.rgb = mix(col.rgb, u.cGlint.rgb * col.a, band2 * 0.9);
    fragColor = col * smoothstep(-aa, aa, out_) * u.qt_Opacity;
}
