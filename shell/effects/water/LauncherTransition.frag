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
#include "../common/common.glsl"

// Caustic lines from cells of `size` px: (gap between the nearest two sites'
// distances, gap between the nearest and the third). The first is zero along the
// cell borders, the second only where three cells meet, where the light gathers.
vec2 causticGap(vec2 p, float size) {
    vec2 g = floor(p / size);
    float d1 = 1e9, d2 = 1e9, d3 = 1e9;
    for (int y = -1; y <= 1; y++)
        for (int x = -1; x <= 1; x++) {
            vec2 cell = g + vec2(x, y);
            float d = length(p - (cell + hash2(cell)) * size);
            if (d < d1) { d3 = d2; d2 = d1; d1 = d; }
            else if (d < d2) { d3 = d2; d2 = d; }
            else d3 = min(d3, d);
        }
    return vec2(d2 - d1, d3 - d1);
}

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
    // Caustics: light focused by the moving surface. A net of warped cell borders,
    // with a fainter one drifting across it: thin along each border, swelling where
    // the borders meet and gathering to foam there, with a soft glow around them,
    // and dimming here and there as the surface moves.
    vec2 warp = vec2(fbm(p / 110.0 + vec2(u.time * 0.35, 0.0)), fbm(p / 110.0 + vec2(4.0, -u.time * 0.3))) - 0.5;
    vec2 cq = p + (vec2(n1, n2) - 0.5) * 22.0 + warp * 60.0;
    cq += (vec2(vnoise(cq / 26.0 + u.time * 0.6), vnoise(cq / 26.0 + 17.0 - u.time * 0.6)) - 0.5) * 9.0;
    vec2 c1 = causticGap(cq + vec2(u.time * 14.0, -u.time * 9.0), 64.0);
    vec2 c2 = causticGap(rot(cq, 0.9) - vec2(u.time * 8.0, u.time * 12.0) + 40.0, 44.0);
    float crest = n1 + n2;
    float on1 = mix(0.3, 1.0, smoothstep(0.3, 0.7, vnoise(cq / 70.0 + 3.0 + u.time * 0.3)));
    float on2 = smoothstep(0.4, 0.75, vnoise(cq / 55.0 - 7.0 - u.time * 0.25));
    float near1 = 1.0 + 1.4 * smoothstep(14.0, 0.0, c1.y) + 0.5 * smoothstep(0.8, 1.4, crest);
    float near2 = 1.0 + 1.2 * smoothstep(10.0, 0.0, c2.y);
    float body = smoothstep(8.0, 16.0, depth);
    float glow = cover(3.0 * near1 - c1.x) * on1 * 0.22;
    float line = max(cover(1.0 * near1 - c1.x) * on1 * 0.75, cover(0.8 * near2 - c2.x) * on2 * 0.4);
    water = mix(water, u.cLight.rgb, max(glow, line) * body);
    water = mix(water, u.cFoam.rgb, cover(2.2 - c1.y) * on1 * 0.85 * body);

    float tint = wet * 0.78;
    vec3 col = mix(content.rgb, water * max(content.a, 0.85), tint);
    float a = max(content.a, tint);
    fragColor = vec4(col, a) * inside * u.qt_Opacity;
}
