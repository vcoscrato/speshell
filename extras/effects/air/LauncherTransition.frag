#version 440
#extension GL_GOOGLE_include_directive : enable
// Draws the captured panel wound into a vortex. At wind = 1 it is twisted tight and
// hidden; as wind falls to 0 it unwinds into place, appearing from the eye outward
// behind a bright ring of air.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 area;         // this item's rect on screen (px)
    vec4 rect;         // the panel's rect on screen (px)
    vec2 center;       // vortex eye (px)
    float wind;        // 1 wound up .. 0 settled
    float spin;
    float reach;       // px, distance from the eye to the farthest corner
    vec4 cRing;
} u;
layout(binding = 1) uniform sampler2D source;
#include "../../lib/common.glsl"

void main() {
    vec2 p = u.area.xy + qt_TexCoord0 * u.area.zw;
    vec2 rel = p - u.center;
    float r = length(rel);
    // Inner parts lag furthest behind, so the panel looks wrung out.
    float a = u.wind * 2.4 * u.spin * exp(-r / (0.6 * u.reach));
    vec2 q = mat2(cos(a), -sin(a), sin(a), cos(a)) * rel;
    vec2 uv = (u.center + q - u.rect.xy) / u.rect.zw;
    vec4 content = texture(source, uv);
    content *= step(0.0, uv.x) * step(uv.x, 1.0) * step(0.0, uv.y) * step(uv.y, 1.0);

    // Revealed inside a wobbling radius that grows as the wind drops.
    vec2 dir = rel / max(r, 1.0);
    float wobble = (vnoise(dir * 1.6 + vec2(u.wind * 2.0, 3.0)) - 0.5) * 0.3 * u.reach;
    float edge = (1.0 - u.wind) * (u.reach * 1.3 + 60.0) - 30.0 + wobble;
    float x = edge - r;                                   // > 0 revealed
    float aa = fwidth(x) + 1e-3;
    float shown = smoothstep(-aa, aa, x);
    float ring = (1.0 - smoothstep(6.0 - aa, 6.0 + aa, x)) * shown;
    vec4 col = mix(content, u.cRing * content.a, ring * 0.85);
    fragColor = col * shown * u.qt_Opacity;
}
