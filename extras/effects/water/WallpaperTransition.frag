#version 440
#extension GL_GOOGLE_include_directive : enable
// A drop lands and a ripple ring spreads out from it. Inside the ring is the new
// wallpaper, still rippling; outside is the old one, bulging as the ring nears.
// The ring's slopes are shaded in flat light and dark bands.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 resolution;
    vec2 center;
    float ring;        // px, front radius
    float strength;    // px of displacement at the front
    float calm;        // 0..1 how far the trailing ripples have died down
    vec4 cLight;
    vec4 cDark;
} u;
layout(binding = 1) uniform sampler2D outgoingTex;
layout(binding = 2) uniform sampler2D incomingTex;
#include "../../lib/common.glsl"

void main() {
    vec2 p = qt_TexCoord0 * u.resolution;
    vec2 rel = p - u.center;
    float r = max(length(rel), 1.0);
    vec2 dir = rel / r;
    float wob = (vnoise(dir * 2.0 + 5.0) - 0.5) * 24.0;
    float d = r - u.ring + wob;                            // < 0 inside the ring

    // Height of the water surface: a crest at the front and decaying ripples behind.
    float lambda = 64.0;
    float front = exp(-pow(d / 34.0, 2.0));
    float trail = step(d, 0.0) * exp(d / 190.0) * (1.0 - u.calm);
    float h = front * cos(d / lambda * 6.2831853 * 0.5) + trail * sin(d / lambda * 6.2831853);
    float slope = -front * sin(d / lambda * 3.1415927) + trail * cos(d / lambda * 6.2831853);
    vec2 uv = (p - dir * h * u.strength) / u.resolution;

    float aa = clamp(fwidth(d), 1e-3, 1.5);
    float inner = smoothstep(aa, -aa, d);
    vec4 col = mix(texture(outgoingTex, uv), texture(incomingTex, uv), inner);

    // Flat shading: lit slopes, shaded slopes, and a bright crest line.
    float energy = max(front, trail);
    col.rgb = mix(col.rgb, u.cLight.rgb, cover(slope - 0.45) * 0.35 * energy);
    col.rgb = mix(col.rgb, u.cDark.rgb, cover(-slope - 0.45) * 0.3 * energy);
    col.rgb = mix(col.rgb, u.cLight.rgb, cover(3.0 - abs(d + 4.0)) * 0.85);
    fragColor = col * u.qt_Opacity;
}
