#version 440
#extension GL_GOOGLE_include_directive : enable
// Earth's button face: cut jade. Voronoi facets, each tilted its own way, take one of
// three cel bands by how squarely they face the light, and fine seams part them.
// Hovered, the light swings across, so the facets turned to it glint in turn.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 area;
    float glow;
    float press;
    vec2 at;
    float time;
    vec4 cJade;
    vec4 cGlint;
    vec4 cShade;
} u;
#include "../../lib/common.glsl"

void main() {
    vec2 p = qt_TexCoord0 * u.area;
    float h = u.area.y;
    float size = h * 0.62;

    vec2 site = voronoiSite(p, size, 0.85);
    vec2 tilt = (hash2(site * 0.13) - 0.5) * 1.1;
    vec3 normal = normalize(vec3(tilt, 1.0));
    float swing = -0.6 + sin(u.time * 1.6) * 1.1;
    vec3 light = normalize(vec3(sin(swing) * 0.7, -0.6, 0.8));
    float lit = dot(normal, light);

    vec3 col = mix(u.cJade.rgb, u.cShade.rgb, 0.16);
    col = mix(col, u.cJade.rgb, step(0.82, lit));
    col = mix(col, mix(u.cJade.rgb, u.cGlint.rgb, 0.16), step(0.93, lit));
    // The facet squarely to the light glints.
    col = mix(col, mix(u.cJade.rgb, u.cGlint.rgb, 0.55), step(0.985, lit) * (0.4 + 0.6 * u.glow));

    // Seams between facets.
    float seam = voronoiEdge(p, size, 0.85);
    col = mix(col, mix(u.cJade.rgb, u.cShade.rgb, 0.3), cover(0.55 - seam) * 0.8);

    col = mix(col, u.cShade.rgb, 0.12 * u.press);
    fragColor = vec4(col, 1.0) * u.qt_Opacity;
}
