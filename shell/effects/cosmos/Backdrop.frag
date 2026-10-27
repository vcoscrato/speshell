#version 440
#extension GL_GOOGLE_include_directive : enable
// Cosmos backdrop, drawn once over a surface's base color: a faint nebula
// lane crossing the panel in cel-shaded steps, star dust thickest along it, and a few
// four-point glints. Everything stays a few percent off the base so text reads.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;
    vec4 cBase;
    vec4 cDeep;
    vec4 cText;
    vec4 cAccent;
} u;
#include "../common/common.glsl"

// Signed distance across the lane: it runs from the top right down to the lower
// left, meandering, and widens toward the middle.
float lane(vec2 p) {
    vec2 q = p / u.size.x;
    float axis = q.x + 0.42 * q.y - 1.05 - 0.10 * sin(q.y * 2.3 + 0.8) - 0.18 * (fbm(q * 1.6 + 3.0) - 0.5);
    return axis / (0.22 + 0.10 * sin(q.y * 1.7));
}

void main() {
    vec2 p = qt_TexCoord0 * u.size;
    float d = lane(p);

    // Nebula: three flat steps of glow, with dark dust tearing through the core.
    float cloud = exp(-d * d * 1.6) * (0.55 + 0.9 * fbm(p / 70.0 + vec2(0.0, 4.0)));
    float steps = band(cloud, 0.35) * 0.35 + band(cloud, 0.6) * 0.35 + band(cloud, 0.9) * 0.3;
    // Dust drifts along the nebula in soft dark wisps, faded at their ends; hard
    // steps here read as slashes.
    vec2 along = vec2(dot(p, vec2(0.387, -0.922)), dot(p, vec2(0.922, 0.387)));
    float dust = smoothstep(0.42, 0.66, fbm(along / vec2(130.0, 46.0) + 9.0) * exp(-d * d * 4.0));
    vec3 warm = mix(u.cAccent.rgb, u.cText.rgb, 0.35);
    vec3 col = u.cBase.rgb;
    col = mix(col, warm, steps * 0.075);
    col = mix(col, u.cDeep.rgb, dust * 0.28);

    // Star dust: one candidate per cell, likelier along the lane.
    float density = 0.05 + 0.22 * exp(-d * d * 1.2);
    vec2 cell = floor(p / 7.0);
    vec2 h = hash2(cell);
    if (hash(cell + 31.7) < density) {
        vec2 star = (cell + 0.2 + 0.6 * h) * 7.0;
        float r = 0.45 + 0.75 * pow(hash(cell + 7.1), 3.0);
        float s = 1.0 - smoothstep(r - 0.5, r + 0.5, length(p - star));
        col = mix(col, u.cText.rgb, s * (0.18 + 0.4 * h.x));
    }

    // Glints: rare brighter stars with a soft four-point spike.
    vec2 gcell = floor(p / 120.0);
    if (hash(gcell + 5.3) < 0.22) {
        vec2 g = (gcell + 0.2 + 0.6 * hash2(gcell + 2.0)) * 120.0;
        vec2 v = abs(p - g);
        float spike = max(exp(-v.x * 1.1) * exp(-v.y * 0.16), exp(-v.y * 1.1) * exp(-v.x * 0.16));
        float core = exp(-dot(v, v) * 0.45);
        col = mix(col, mix(u.cText.rgb, u.cAccent.rgb, 0.3), clamp(spike * 0.22 + core * 0.55, 0.0, 0.55));
    }

    fragColor = vec4(col, 1.0) * u.qt_Opacity;
}
