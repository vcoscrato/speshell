#version 440
#extension GL_GOOGLE_include_directive : enable
// A crack along the ground line, rock chips flung from it, and cel-shaded dust
// puffs billowing along it. The chips are boxes of their own after the band of the
// crack and dust in the same mesh (LauncherTransition.ground.vert), which places the
// puffs too.
layout(location = 0) in vec4 v;
layout(location = 1) in vec4 d0;
layout(location = 2) in vec4 d1;
layout(location = 3) in vec4 d2;
layout(location = 4) in vec4 d3;
layout(location = 5) in vec4 d4;
layout(location = 6) in vec4 d5;
layout(location = 7) in vec4 d6;
layout(location = 0) out vec4 fragColor;
#include "LauncherTransition.ground.glsl"

// Puff `c` (center and radius) at p: its coverage and, lit from above, its shade.
// Its lumpy cauliflower outline, from two noise octaves, reaches at most 0.32 of its
// radius past the circle: a pixel well clear of that skips it.
void addPuff(vec2 p, vec3 c, float fi, float grow, inout float cover_, inout float shade) {
    vec2 rel = p - c.xy;
    float r = c.z;
    if (dot(rel, rel) > pow(r * 1.32 + 4.0, 2.0))
        return;
    float ang = atan(rel.y, rel.x);
    float lumps = (vnoise(vec2(ang * 2.2 + fi * 7.0, grow)) - 0.5) * 0.45 * r
                + (vnoise(vec2(ang * 6.0 + fi * 3.0, 0.0)) - 0.5) * 0.18 * r;
    float d = length(rel) - r - lumps;
    float k = cover(-d);
    cover_ = max(cover_, k);
    // The lower part of each puff is in shade.
    shade = max(shade, k * cover(rel.y - r * 0.2));
}

// A rock chip: a cut stone, lit on top, outlined.
vec4 rockChip(vec2 p) {
    float ang = d0.z;
    vec2 lp = mat2(cos(ang), -sin(ang), sin(ang), cos(ang)) * (p - d0.xy);
    float size = d0.w;
    float d = max(max(abs(lp.x) - size, abs(lp.y) - size * 0.7), (lp.x + lp.y) * 0.75 - size * 0.55);
    float chip = cover(-d) * v.w;
    float rim = cover(-d + 1.5) * v.w;
    vec3 col = mix(u.cDark.rgb * rim, lp.y < 0.0 ? u.cDust.rgb : u.cRock.rgb, chip);
    return vec4(col, rim);
}

void main() {
    vec2 p = v.xy;
    if (v.z > 0.5) {
        fragColor = rockChip(p) * u.qt_Opacity;
        return;
    }
    vec3 col = vec3(0.0);
    float a = 0.0;

    // Dust: puffs along the ground that swell, rise a little, and thin out.
    if (u.dust > 0.0 && u.dust < 1.0) {
        float cover_ = 0.0, shade = 0.0;
        float grow = grown();
        addPuff(p, d0.xyz, 0.0, grow, cover_, shade);
        addPuff(p, vec3(d0.w, d1.xy), 1.0, grow, cover_, shade);
        addPuff(p, vec3(d1.zw, d2.x), 2.0, grow, cover_, shade);
        addPuff(p, d2.yzw, 3.0, grow, cover_, shade);
        addPuff(p, d3.xyz, 4.0, grow, cover_, shade);
        addPuff(p, vec3(d3.w, d4.xy), 5.0, grow, cover_, shade);
        addPuff(p, vec3(d4.zw, d5.x), 6.0, grow, cover_, shade);
        addPuff(p, d5.yzw, 7.0, grow, cover_, shade);
        addPuff(p, d6.xyz, 8.0, grow, cover_, shade);
        float thin = 1.0 - smoothstep(0.3, 0.75, u.dust);
        a = cover_ * thin * 0.55;
        col = mix(u.cDust.rgb, u.cDustShade.rgb, shade) * a;
    }

    // Crack: a jagged dark seam with a pale lip, which strays at most 16 px from the
    // ground line.
    float dx = abs(p.x - u.origin.x);
    if (abs(p.y - u.origin.y) < 24.0 && dx < u.crackLen) {
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
    }
    fragColor = vec4(col, a) * u.qt_Opacity;
}
