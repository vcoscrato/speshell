#version 440
#extension GL_GOOGLE_include_directive : enable
// Frost over the old wallpaper, thawing onto the new, read from the table the frost
// pass worked out. Under the frost the image is scattered (a blurred mip) and paled in
// steps as the frost thickens; the fronds stand out snow white, lit on the side toward
// the light and shaded on the other, their newest growth bright and a few glints on
// them. Behind the frost the old image gives way to the new while it is frosted over.
// Ahead of the thaw the frost goes slushy; behind it the glass is wet, refracting the
// new image at a rim lit toward the light, under a light film of water that dries.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 resolution;
    float time;
    float seed;
    float swapAt;       // s, when the image behind the frost turns to the new one
    float thawEnd;
    vec4 cIce;
    vec4 cSnow;
    vec4 cShade;
    vec4 cGlint;
} u;
layout(binding = 1) uniform sampler2D field;
layout(binding = 2) uniform sampler2D outgoing;
layout(binding = 3) uniform sampler2D incoming;
#include "../common/common.glsl"

float S;
const vec2 LIGHT = vec2(-0.6, -0.8);     // toward the light, up and to the left

vec3 scatter(sampler2D img, vec2 uv, float lod) {
    vec2 o = vec2(3.0, 2.0) * S / u.resolution * exp2(lod - 3.0);
    return 0.5 * (textureLod(img, uv + o, lod).rgb + textureLod(img, uv - o, lod).rgb);
}

void main() {
    vec2 uv = qt_TexCoord0;
    vec2 p = uv * u.resolution;
    S = u.resolution.y / 1080.0;
    float t = u.time;
    vec2 px = 1.0 / u.resolution;
    vec4 f = texture(field, uv);
    float tf = f.r, h = f.g, tt = f.b + 1.0;
    float hl = texture(field, uv + LIGHT * 1.5 * S * px).g;
    // The thaw's slope, over a few px, finer than the half floats' steps.
    vec4 fx = texture(field, uv + vec2(4.0 * S, 0.0) * px);
    vec4 fy = texture(field, uv + vec2(0.0, 4.0 * S) * px);
    vec2 gt = vec2(fx.b - f.b, fy.b - f.b) / (4.0 * S);

    float age = t - tf;
    float melt = t - tt;
    float swap = smoothstep(u.swapAt, u.swapAt + 0.2, t);
    float lod = 4.2 + log2(max(S * u.resolution.y / 1080.0, 1.0));
    vec3 behind = mix(scatter(outgoing, uv, lod), scatter(incoming, uv, lod), swap);
    vec3 sharp = swap < 1.0 ? texture(outgoing, uv).rgb : vec3(0.0);

    // Clear glass ahead of the frost, a faint breath of fog just ahead of it.
    vec3 col = mix(sharp, mix(behind, u.cIce.rgb, 0.3), 0.35 * band(age, -0.1) * (1.0 - swap));

    // The frost, thicker in steps as it ages; late frost catches up as the window
    // frosts over, so no thin patch is left.
    float thick = age + 2.0 * max(t - 0.85, 0.0);
    float dens = 0.5 + 0.14 * band(thick, 0.25) + 0.12 * band(thick, 0.6);
    vec3 frost = mix(behind, u.cIce.rgb, dens);
    float fern = band(h, 0.05);
    vec3 fc = mix(frost, u.cSnow.rgb, 0.55 + 0.25 * band(h, 0.6));
    fc = mix(fc, u.cGlint.rgb, 0.8 * band(h - hl, 0.04) * band(h, 0.3));
    fc = mix(fc, u.cShade.rgb, 0.45 * band(hl - h, 0.05));
    frost = mix(frost, fc, fern);
    // The newest growth catches the light.
    frost = mix(frost, u.cGlint.rgb, 0.7 * fern * (1.0 - band(age, 0.12)));

    // Glints: one candidate a cell, on a frond, twinkling as it freezes.
    float cs = 44.0 * S;
    vec2 g = floor(p / cs);
    vec2 gc = (g + 0.3 + 0.4 * hash2(g + u.seed * 50.0)) * cs;
    vec4 gf = texture(field, gc * px);
    float ga = (t - gf.r) / 0.45;
    if (hash(g + u.seed * 70.0) < 0.4 && gf.g > 0.35 && ga > 0.0 && ga < 1.0 && t < gf.b + 0.95) {
        vec2 q = abs(rot(p - gc, 0.3 * hash(g + 3.0)));
        float R = mix(4.0, 9.0, hash(g + 5.0)) * S * sin(PI * ga);
        float star = pow(q.x, 0.6) + pow(q.y, 0.6) - pow(R, 0.6);
        frost = mix(frost, u.cGlint.rgb, 0.95 * cover(-star));
    }

    float gl = max(length(gt), 1e-4);
    float edge = melt / gl;                          // px into the thaw
    // Ahead of the thaw the frost goes wet and translucent, lighter, in two steps.
    vec3 slush = mix(texture(incoming, uv).rgb, u.cIce.rgb, 0.55);
    frost = mix(frost, slush, 0.4 * band(melt, -0.14) + 0.35 * band(melt, -0.06));

    // The wet glass behind it.
    vec2 nrm = -gt / gl;                             // toward the thawed side
    float wet = 1.0 - smoothstep(0.0, min(0.35, u.thawEnd + 0.12 - tt), melt);
    float clearA = cover(edge);
    float rimD = edge;
    vec2 off = nrm * 4.0 * S * wet * exp(-max(rimD, 0.0) / (8.0 * S));
    vec3 glass = texture(incoming, uv - off * px).rgb;
    // A light film of water, clearing from the rim inward as it dries.
    glass = mix(glass, u.cIce.rgb, 0.22 * wet * (1.0 - band(rimD, 9.0 * S)) + 0.12 * wet);
    float rim = cover(1.8 * S - abs(rimD - 1.0 * S)) * wet;
    glass = mix(glass, u.cGlint.rgb, rim * (dot(nrm, LIGHT) < -0.1 ? 0.6 : 0.25));

    float frostA = cover(age);
    col = mix(col, frost, frostA);
    col = mix(col, glass, clearA * frostA + (1.0 - frostA) * swap);
    float shown = max(1.0 - clearA, wet);            // dry thawed glass is the new image itself
    fragColor = vec4(col, 1.0) * shown * u.qt_Opacity;
}
