#version 440
#extension GL_GOOGLE_include_directive : enable
// The captured panel as a stone slab pushed up out of the ground. Only the part
// above the ground line shows. While `stone` is up the panel wears a banded rock
// face with chipped edges and faint cracks; it fades to the plain panel.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 rect;         // this item's rect on screen (px)
    vec4 panel;        // panel rect at rest (px)
    float radius;
    float ground;      // px, screen y of the ground line
    vec2 offset;       // px, slab displacement from rest
    float stone;       // 0..1
    vec4 cLight;
    vec4 cMid;
    vec4 cDark;
} u;
layout(binding = 1) uniform sampler2D source;
#include "../../lib/common.glsl"

void main() {
    vec2 p = u.rect.xy + qt_TexCoord0 * u.rect.zw;
    vec2 q = p - u.offset;                                 // point on the slab at rest
    vec2 c = u.panel.xy + u.panel.zw * 0.5;
    float chip = (vnoise(q / 11.0) - 0.5) * 9.0 * u.stone;
    float d = sdRoundRect(q - c, u.panel.zw * 0.5, mix(u.radius, 3.0, u.stone)) + max(chip, 0.0);
    float aa = clamp(fwidth(d), 1e-3, 1.5);
    float body = smoothstep(aa, -aa, d);
    float aboveGround = smoothstep(0.75, -0.75, p.y - u.ground);

    vec4 content = texture(source, clamp((q - u.panel.xy) / u.panel.zw, 0.0, 1.0));
    // Rock face: angular facets in three flat tones, dark seams, and faint strata.
    vec2 site = voronoiSite(q, 64.0, 0.95);
    float tone = hash(site * 0.013);
    vec3 rock = tone < 0.4 ? u.cMid.rgb : (tone < 0.75 ? u.cLight.rgb : mix(u.cMid.rgb, u.cDark.rgb, 0.55));
    float strata = fract(q.y / 22.0 + vnoise(vec2(q.x / 90.0, 3.0)) * 0.8);
    rock = mix(rock, rock * 0.86, step(0.82, strata));
    float seam = 1.0 - smoothstep(0.8, 1.8, voronoiEdge(q, 64.0, 0.95));
    rock = mix(rock, u.cDark.rgb, seam);
    // Edge highlight on top, shadow at the sides.
    rock = mix(rock, u.cLight.rgb * 1.15, smoothstep(5.0 + aa, 5.0 - aa, -d) * step(q.y, c.y));

    vec3 col = mix(content.rgb, rock * max(content.a, 1.0), u.stone);
    float a = max(content.a, u.stone);
    fragColor = vec4(col, a) * body * aboveGround * u.qt_Opacity;
}
