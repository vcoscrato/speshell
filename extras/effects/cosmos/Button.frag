#version 440
#extension GL_GOOGLE_include_directive : enable
// Cosmos's button face: the accent, banded darker toward the bottom like a lane of
// night, a planet whose lit limb rises at the right end, and stars. Hovered, the
// stars twinkle and a comet crosses the top.
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
    vec4 cBase;
    vec4 cLight;
    vec4 cShade;
    vec4 cRim;
} u;
#include "../../lib/common.glsl"

void main() {
    vec2 p = qt_TexCoord0 * u.area;
    float h = u.area.y;
    vec3 col = u.cBase.rgb;

    // A lane of night: one darker band along the bottom, its edge gently curved.
    float lane = band(p.y - h * 0.72 - 1.5 * sin(p.x / 23.0), 0.0);
    col = mix(col, mix(col, u.cShade.rgb, 0.12), lane);

    // The planet at the right end, its limb lit from above.
    vec2 c = vec2(u.area.x + h * 0.05, h * 1.3);
    float R = h * 0.78;
    float d = length(p - c) - R;
    vec3 planet = mix(u.cBase.rgb, u.cShade.rgb, 0.24);
    planet = mix(planet, mix(u.cBase.rgb, u.cShade.rgb, 0.36), band(p.y - c.y + R * 0.72, 0.0));
    col = mix(col, planet, cover(-d));
    vec3 rim = mix(u.cRim.rgb, u.cLight.rgb, 0.4 + 0.3 * u.glow);
    col = mix(col, rim, cover(1.1 - abs(d + 0.6)) * smoothstep(c.y - R * 0.4, c.y - R, p.y));

    // Stars, twinkling while hovered.
    vec2 cell = floor(p / 7.0);
    vec2 star = (cell + 0.2 + 0.6 * hash2(cell + 3.1)) * 7.0;
    float bright = step(0.82, hash(cell + 9.7));
    float twinkle = 0.55 + 0.45 * sin(u.time * (4.0 + 5.0 * hash(cell)) + hash(cell + 1.3) * 6.28) * u.glow;
    col = mix(col, u.cLight.rgb, cover(0.75 - length(p - star)) * bright * twinkle * 0.8 * (1.0 - cover(-d)));

    // The comet, its tail streaming behind it.
    float span = u.area.x + h * 4.0;
    float head = mod(u.time * 0.6 * span, span) - h * 1.5;
    float y = h * 0.2 + (head - p.x) * 0.05;
    float along = (head - p.x) / (h * 2.4);
    float tail = (1.0 - along) * step(0.0, along) * step(along, 1.0);
    float width = mix(1.3, 0.2, along);
    col = mix(col, u.cLight.rgb, cover(width - abs(p.y - y)) * tail * u.glow);
    col = mix(col, u.cLight.rgb, cover(1.4 - length(p - vec2(head, h * 0.2))) * u.glow);

    col = mix(col, u.cShade.rgb, 0.12 * u.press);
    fragColor = vec4(col, 1.0) * u.qt_Opacity;
}
