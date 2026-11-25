#version 440
#extension GL_GOOGLE_include_directive : enable
// A comet around its head at this item's middle: a small bright head in a soft
// coma, a dust tail curving back along its path as it widens and fades, and a
// faint straight ion tail, both streaming away from the panel's light, in flat
// steps.
// Hidden where it passes behind what shows of the panel.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 rect;          // this item's rect on screen (px)
    vec4 panel;         // the panel's rect on screen (px)
    float radius;       // panel corner radius
    vec2 away;          // unit direction from the panel's middle through the head
    vec2 back;          // unit direction the comet came from
    float size;         // head radius (px)
    float tail;         // dust tail length (px)
    float k;            // 0..1 brightness
    vec4 cHead;
    vec4 cDust;
    vec4 cIon;
} u;
#include "../common/common.glsl"

void main() {
    vec2 p = u.rect.xy + qt_TexCoord0 * u.rect.zw;
    vec2 o = p - (u.rect.xy + u.rect.zw * 0.5);
    vec2 side = vec2(-u.away.y, u.away.x);
    float along = dot(o, u.away);
    float across = dot(o, side);
    vec4 acc = vec4(0.0);
    float shut = max(-along, 0.0) / u.size;

    // The ion tail: faint, thin, and straight away from the light.
    float ti = clamp(along / (u.tail * 1.4), 0.0, 1.0);
    float ion = 1.0 - abs(across) / (u.size * 0.5 + max(along, 0.0) * 0.03) - ti - shut;
    acc = over(acc, u.cIon.rgb, 0.2 * (1.0 - ti) * band(ion, 0.05));

    // The dust tail: curving back toward where the comet has been, widening and
    // fading in flat steps as it goes, brightest near the head.
    float bend = dot(u.back, side) * 0.55;
    float t = clamp(along / u.tail, 0.0, 1.0);
    float off = across - bend * along * t;
    float w = u.size * 2.0 + max(along, 0.0) * 0.34;
    float dust = 1.0 - abs(off) / w - 0.55 * t - shut * 0.5;
    float fadeOut = 1.0 - t;
    acc = over(acc, u.cDust.rgb, 0.16 * fadeOut * band(dust, 0.03));
    acc = over(acc, u.cDust.rgb, 0.22 * fadeOut * band(dust, 0.3));
    acc = over(acc, mix(u.cDust.rgb, u.cHead.rgb, 0.5), 0.35 * fadeOut * band(dust, 0.55) * band(0.4, t));

    // The coma in soft rings round a small bright head.
    float d = length(o);
    acc = over(acc, u.cDust.rgb, 0.12 * cover(u.size * 5.0 - d));
    acc = over(acc, mix(u.cDust.rgb, u.cHead.rgb, 0.4), 0.2 * cover(u.size * 3.0 - d));
    acc = over(acc, mix(u.cDust.rgb, u.cHead.rgb, 0.7), 0.45 * cover(u.size * 1.8 - d));
    acc = over(acc, u.cHead.rgb, cover(u.size - d));

    float sd = sdRoundRect(p - u.panel.xy - u.panel.zw * 0.5, u.panel.zw * 0.5, u.radius);
    fragColor = acc * smoothstep(0.0, 1.5, sd) * u.k * u.qt_Opacity;
}
