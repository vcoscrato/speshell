#version 440
#extension GL_GOOGLE_include_directive : enable
// A crack along the ground line, rock chips flung from it, and cel-shaded dust
// puffs billowing along it.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 resolution;
    vec2 offset;       // px, this item's top-left on screen
    vec2 origin;       // px, crack center on the ground line
    float crackLen;    // px, half length
    float crackOpen;   // 0..1
    float burst;       // s since the debris burst (< 0 before)
    float dust;        // 0..1 dust puff progress
    float spread;      // px, half width the dust spans
    vec4 cDust;
    vec4 cDustShade;
    vec4 cRock;
    vec4 cDark;
} u;
#include "../common/common.glsl"

void main() {
    vec2 p = u.offset + qt_TexCoord0 * u.resolution;
    vec3 col = vec3(0.0);
    float a = 0.0;

    // Dust: puffs along the ground that swell, rise a little, and thin out.
    if (u.dust > 0.0 && u.dust < 1.0) {
        float cover_ = 0.0, shade = 0.0;
        for (int i = 0; i < 9; i++) {
            float fi = float(i);
            float x = u.origin.x + (fi / 8.0 - 0.5) * 2.0 * u.spread + (hash(vec2(fi, 4.0)) - 0.5) * 60.0;
            float grow = 1.0 - pow(1.0 - u.dust, 2.5);
            float r = mix(8.0, 20.0 + 26.0 * hash(vec2(fi, 5.0)), grow);
            vec2 cp = vec2(x + (x - u.origin.x) * 0.35 * grow, u.origin.y - r * 0.4 - 46.0 * grow * hash(vec2(fi, 6.0)));
            // Lumpy cauliflower outline from two noise octaves.
            vec2 rel = p - cp;
            float ang = atan(rel.y, rel.x);
            float lumps = (vnoise(vec2(ang * 2.2 + fi * 7.0, grow)) - 0.5) * 0.45 * r
                        + (vnoise(vec2(ang * 6.0 + fi * 3.0, 0.0)) - 0.5) * 0.18 * r;
            float d = length(rel) - r - lumps;
            cover_ = max(cover_, cover(-d));
            // Lit from above: the lower part of each puff is in shade.
            shade = max(shade, cover(-d) * cover(rel.y - r * 0.2));
        }
        float thin = 1.0 - smoothstep(0.3, 0.75, u.dust);
        float dustA = cover_ * thin * 0.55;
        col = mix(u.cDust.rgb, u.cDustShade.rgb, shade);
        a = dustA;
        col *= a;
    }

    // Crack: a jagged dark seam with a pale lip.
    float dx = abs(p.x - u.origin.x);
    float along = clamp(1.0 - dx / max(u.crackLen, 1.0), 0.0, 1.0);
    float seamY = u.origin.y + (vnoise(vec2(p.x / 26.0, 1.0)) - 0.5) * 9.0 + (vnoise(vec2(p.x / 8.0, 2.0)) - 0.5) * 4.0;
    float w = u.crackOpen * 5.0 * pow(along, 0.4);
    // Both fade out as it shuts, so no hairline is left where it was.
    float shut = smoothstep(0.0, 0.15, u.crackOpen);
    float seam = cover(w - abs(p.y - seamY)) * step(0.001, along) * shut;
    float lip = cover(w + 2.0 * u.crackOpen - abs(p.y - seamY - 2.0)) * step(0.001, along) * (1.0 - seam) * shut;
    col = mix(col, u.cDust.rgb, lip * 0.8);
    a = max(a, lip * 0.8);
    col = mix(col, u.cDark.rgb, seam);
    a = max(a, seam);

    // Rock chips: flung up from the crack, tumbling under gravity.
    if (u.burst > 0.0 && u.burst < 1.2) {
        for (int i = 0; i < 14; i++) {
            float fi = float(i);
            vec2 h = hash2(vec2(fi, 9.0));
            vec2 start = vec2(u.origin.x + (h.x - 0.5) * 1.6 * u.crackLen, u.origin.y);
            vec2 vel = vec2((h.x - 0.5) * 420.0, -380.0 - 260.0 * h.y);
            vec2 pos = start + vel * u.burst + vec2(0.0, 1400.0) * u.burst * u.burst * 0.5;
            float ang = u.burst * (h.y - 0.5) * 16.0;
            vec2 lp = mat2(cos(ang), -sin(ang), sin(ang), cos(ang)) * (p - pos);
            float size = 4.0 + 8.0 * hash(vec2(fi, 11.0));
            float d = max(max(abs(lp.x) - size, abs(lp.y) - size * 0.7), (lp.x + lp.y) * 0.75 - size * 0.55);
            float fade = 1.0 - smoothstep(0.8, 1.2, u.burst);
            float chip = cover(-d) * fade;
            float rim = cover(-d + 1.5) * fade;
            col = mix(col, u.cDark.rgb, rim);
            col = mix(col, lp.y < 0.0 ? u.cDust.rgb : u.cRock.rgb, chip);
            a = max(a, rim);
        }
    }
    fragColor = vec4(col, a) * u.qt_Opacity;
}
