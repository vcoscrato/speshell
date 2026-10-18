#version 440
#extension GL_GOOGLE_include_directive : enable
// Water's button face: the accent as a shallow pool, deeper toward the foot behind a
// wavy edge, its floor netted with caustics (warped Voronoi edges), and a bright
// meniscus along the top. Hovered, the caustics drift and rings spread from the
// pointer, one after another.
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
    vec4 cWater;
    vec4 cLight;
    vec4 cFoam;
    vec4 cDeep;
} u;
#include "../../lib/common.glsl"

void main() {
    vec2 p = qt_TexCoord0 * u.area;
    float h = u.area.y;
    vec3 col = u.cWater.rgb;

    // Deeper toward the foot.
    col = mix(col, mix(col, u.cDeep.rgb, 0.16), band(p.y - h * 0.68 - 1.4 * sin(p.x / 11.0 + u.time * 2.0), 0.0));

    // Caustics on the floor, warped by the water above.
    float t = u.time * 0.8;
    vec2 warp = vec2(sin(p.y / 7.0 + t * 1.7), cos(p.x / 9.0 - t * 1.3)) * h * 0.07;
    float edge = voronoiEdge(p + warp + vec2(t * h * 0.3, 0.0), h * 0.55, 0.9);
    col = mix(col, mix(u.cLight.rgb, u.cFoam.rgb, 0.4), cover(0.7 - edge) * (0.22 + 0.18 * u.glow));

    // The meniscus.
    col = mix(col, mix(u.cLight.rgb, u.cFoam.rgb, 0.5), cover(1.6 - p.y) * 0.6);

    // Rings spreading from the pointer.
    float r = length(p - u.at);
    float wave = r - u.time * h * 1.4;
    float ring = abs(fract(wave / (h * 0.55)) - 0.5) * h * 0.55;
    float fade = (1.0 - smoothstep(0.0, h * 1.6, r)) * u.glow;
    col = mix(col, u.cFoam.rgb, cover(0.7 - ring) * fade * 0.5);

    col = mix(col, u.cDeep.rgb, 0.12 * u.press);
    fragColor = vec4(col, 1.0) * u.qt_Opacity;
}
