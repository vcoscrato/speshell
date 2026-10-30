#version 440
#extension GL_GOOGLE_include_directive : enable
// Draws a captured item between two burn fronts. Inside the reveal front it appears
// behind a white-hot line, glow, and char band; ahead of the consume front it
// scorches, chars, and glows, and behind that front it is gone. Refilling (reopened
// mid-exit), the item shows wherever either front leaves it, the reveal front burns
// only across the hole, and the consume front's scorch and glow die down.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 rect;          // this item's rect on screen (px)
    vec2 revealOrigin;
    float revealR;
    vec2 burnOrigin;
    float burnR;
    float refill;       // 1 while the reveal front fills a consumed hole
    float fade;         // 0..1 how far the consume front's marks have died down
    float fieldScale;   // burn front wobble scale
    vec4 cGlow;
    vec4 cHot;
    vec4 cChar;
    vec4 cScorch;       // what the consume front is about to take
} u;
layout(binding = 1) uniform sampler2D source;
#include "../common/common.glsl"

float under(float x, float edge, float aa) {
    return 1.0 - smoothstep(edge - aa, edge + aa, x);
}

void main() {
    vec2 p = u.rect.xy + qt_TexCoord0 * u.rect.zw;
    vec4 content = texture(source, qt_TexCoord0);
    // Band widths wander so the bands do not read as concentric rings.
    float w = 0.6 + 0.8 * vnoise(p / 45.0);

    // A reveal front past any screen is no front at all (the wallpaper transition's).
    float r = u.revealR < 1e4 ? u.revealR - burnField(p, u.revealOrigin, 1.0) : 1e5;  // > 0 revealed
    float ar = max(fwidth(r), 1e-3);
    float c = burnField(p, u.burnOrigin, u.fieldScale) - u.burnR;      // > 0 not yet consumed
    float ac = fwidth(c);
    float revealed = smoothstep(-ar, ar, r);
    float kept = smoothstep(-ac, ac, c);
    // Refilling, the reveal front has only the hole to burn across.
    float front = mix(1.0, 1.0 - kept, u.refill);
    // The consume front marks the panel it has yet to take, not the hole a refill
    // brings back.
    float marks = (1.0 - u.fade) * mix(1.0, kept, u.refill);

    vec3 col = content.rgb;
    // Scorch toward brown ahead of the consume front, keeping some light and dark.
    float luma = dot(col, vec3(0.299, 0.587, 0.114)) / max(content.a, 0.001);
    col = mix(col, u.cScorch.rgb * (0.55 + 0.9 * luma) * content.a, under(c, 70.0 * w, ac) * 0.8 * marks);
    float charred = max(under(r, 22.0, ar) * 0.85 * front, under(c, 22.0 * w, ac) * 0.9 * marks);
    col = mix(col, u.cChar.rgb * content.a, charred);
    col = mix(col, u.cGlow.rgb * content.a, max(under(r, 13.0, ar) * front, under(c, 9.0 * w, ac) * marks));
    col = mix(col, u.cHot.rgb * content.a, max(under(r, 4.0, ar) * front, under(c, 3.0 * w, ac) * marks));

    float visible = mix(revealed * kept, max(revealed, kept), u.refill);
    fragColor = vec4(col, content.a) * visible * u.qt_Opacity;
}
