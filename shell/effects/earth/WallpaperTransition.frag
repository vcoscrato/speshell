#version 440
#extension GL_GOOGLE_include_directive : enable
// A blow strikes the outgoing wallpaper and breaks it from the point of impact out.
// The shards are Voronoi cells in log-polar space around the impact (Shatter.glsl);
// some neighbours along a ray stay joined, so their sizes vary more. Cracks race out
// along the rays first, unevenly, then branch across between them; then each shard,
// at its own moment, jerks up, tilts, and drops, turning and shrinking as it falls
// away with dust where it stood. Chips of the old wallpaper are flung from the cracks.
//
// This draws what still stands, with its cracks. What each point is (its shard, the
// crack beside it) comes from `cellMap` and `crackMap`, worked out once; the shards
// that fall, their dust, and the chips are drawn over it, each on a quad of its own
// (WallpaperTransition.vert), so that a pixel pays only for the pieces over it.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 resolution;
    vec2 center;       // px, the point of impact
    float time;        // s since the impact
    float reach;       // px, from the impact to the furthest corner
    vec4 cCrack;
    vec4 cLip;
} u;
layout(binding = 1) uniform sampler2D source;
layout(binding = 2) uniform sampler2D cells;
layout(binding = 3) uniform sampler2D cellMap;
layout(binding = 4) uniform sampler2D crackMap;
#include "Shatter.glsl"

void main() {
    vec2 p = qt_TexCoord0 * u.resolution;
    float t = u.time;
    // A shard's first cell holds when it breaks loose.
    vec2 ownG = texture(cellMap, qt_TexCoord0).xy;
    float col0 = clamp(floor(ownG.x) - X0, 0.0, KX - 1.0) * CELL + 1.0;
    float release0 = abs(texture(cells, vec2((col0 + 0.5) / (KX * CELL), (ownG.y + 0.5) / N)).z);
    if (t >= release0) {
        fragColor = vec4(0.0);
        return;
    }

    // The blow shakes the ground for a moment.
    vec2 shake = vec2(sin(t * 83.0), cos(t * 67.0)) * 5.0 * exp(-t * 11.0);
    vec4 tex = texture(source, (p + shake) / u.resolution);
    // px per cell unit across the ray here, and along it.
    vec2 d0 = p - u.center;
    float r = length(d0);
    float pxV = r * TAU / N;
    float pxU = pxV / KU;
    // The nearest border to another shard, which way it runs, and when it cracks.
    vec4 crack = texture(crackMap, qt_TexCoord0);
    float edge = crack.x;
    vec2 nrm = crack.yz;
    float crackT = crack.w;
    float open = smoothstep(crackT, crackT + 0.12, t);
    float w = clamp(pxV * 0.022, 0.7, 2.2) * (0.6 + 0.4 * open);
    // Lit on the side toward the light, in shade on the other.
    vec2 sn = normalize(-(nrm.x / pxU) * d0 / max(r, 1.0) - (nrm.y / pxV) * vec2(-d0.y, d0.x) / max(r, 1.0));
    float faceLit = dot(sn, -LIGHT);
    float bevel = cover(w + 1.6 - edge) * step(0.0, t - crackT);
    tex.rgb = mix(tex.rgb, faceLit > 0.0 ? u.cCrack.rgb : u.cLip.rgb, bevel * 0.28);
    tex.rgb = mix(tex.rgb, u.cCrack.rgb, cover(w - edge) * step(0.0, t - crackT));
    // A beat before it goes, the shard jerks up toward the light.
    float lift = smoothstep(release0 - 0.12, release0, t);
    tex.rgb = mix(tex.rgb, tex.rgb * 1.12 + u.cLip.rgb * 0.04, step(0.5, lift));
    fragColor = tex * u.qt_Opacity;
}
