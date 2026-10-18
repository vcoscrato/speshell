#version 440
#extension GL_GOOGLE_include_directive : enable
// The captured panel seen through a sheet of water. The sheet grows from an orb at
// the center into the panel's shape, sloshing past its edges; as it settles the
// tint, ripples, and caustics clear until only the panel is left.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
    vec4 rect;         // this item's rect on screen (px)
    vec4 panel;        // panel rect on screen (px)
    float radius;
    float grow;        // 0 nothing .. 1 the orb has filled the panel
    float settle;      // 0 all water .. 1 clear panel
    vec4 cDeep;
    vec4 cMid;
    vec4 cLight;
    vec4 cFoam;
} u;
layout(binding = 1) uniform sampler2D source;
#include "../../lib/common.glsl"

void main() {
    vec2 p = u.rect.xy + qt_TexCoord0 * u.rect.zw;
    vec2 c = u.panel.xy + u.panel.zw * 0.5;
    vec2 rel = p - c;
    float wet = 1.0 - u.settle;

    // Shape: a growing orb clipped to the panel, which sloshes past the edges while wet.
    float slosh = 14.0 * wet * sin(u.time * 9.0 + rel.x / 60.0) + (vnoise(p / 50.0 + u.time * 2.0) - 0.5) * 22.0 * wet;
    float rectD = sdRoundRect(rel, u.panel.zw * 0.5, u.radius) - slosh;
    float reach = length(u.panel.zw) * 0.5;
    float orbD = length(rel * vec2(1.0, 1.3)) - u.grow * (reach * 1.35 + 30.0) + (vnoise(p / 35.0 + u.time * 3.0) - 0.5) * 30.0;
    float d = max(rectD, orbD);                          // < 0 inside the water
    float aa = clamp(fwidth(d), 1e-3, 1.5);
    float inside = smoothstep(aa, -aa, d);

    // Refraction: ripples bend the panel while wet.
    float n1 = vnoise(p / 38.0 + vec2(u.time * 1.3, 0.0));
    float n2 = vnoise(p / 38.0 + vec2(0.0, u.time * 1.1) + 9.0);
    vec2 bend = (vec2(n1, n2) - 0.5) * 18.0 * wet;
    vec2 uv = (p + bend - u.panel.xy) / u.panel.zw;
    vec4 content = texture(source, clamp(uv, 0.0, 1.0));
    content *= step(sdRoundRect(p + bend - c, u.panel.zw * 0.5, u.radius), 0.0);

    // Water body in flat bands: deeper toward the middle, a bright meniscus at the edge.
    float depth = -d;
    vec3 water = mix(u.cMid.rgb, u.cDeep.rgb, smoothstep(30.0 - aa, 30.0 + aa, depth));
    water = mix(water, u.cLight.rgb, smoothstep(9.0 + aa, 9.0 - aa, depth));
    water = mix(water, u.cFoam.rgb, smoothstep(3.0 + aa, 3.0 - aa, depth));
    // Caustics: a net of light focused by the ripples, morphing as they move. Lines
    // are wider where the ripples crest, with foam-white cores on the brightest.
    vec2 cq = p + (vec2(n1, n2) - 0.5) * 34.0 + vec2(u.time * 16.0, -u.time * 11.0);
    float edge = voronoiEdge(cq, 48.0, 0.9);
    float crest = n1 + n2;
    float lineW = 1.6 + 2.4 * smoothstep(0.7, 1.4, crest);
    float body = step(10.0, depth);
    water = mix(water, u.cLight.rgb, cover(lineW - edge) * body);
    water = mix(water, u.cFoam.rgb, cover(lineW * 0.38 - edge) * smoothstep(0.9, 1.3, crest) * body);

    float tint = wet * 0.78;
    vec3 col = mix(content.rgb, water * max(content.a, 0.85), tint);
    float a = max(content.a, tint);
    fragColor = vec4(col, a) * inside * u.qt_Opacity;
}
