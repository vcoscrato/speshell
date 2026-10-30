#version 440
#extension GL_GOOGLE_include_directive : enable
// The smooth turbulence that bends the whole of Wind.frag's flow, worked out each
// frame at a fraction of the item's resolution: it changes over hundreds of px, so
// Wind.frag reads it back smoothly, and only pays for one lookup. Its offset (px).
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
    vec2 area;         // px, the size of the Wind item this covers
    vec2 origin;       // px, its top-left on screen
    vec2 center;
    vec2 axes;
    float turbulence;  // px
} u;
#include "../common/common.glsl"

void main() {
    vec2 rel = u.origin + qt_TexCoord0 * u.area - u.center;
    fragColor = vec4(swirl(rel / (1.6 * min(u.axes.x, u.axes.y)), u.time * 0.3) * u.turbulence, 0.0, 1.0);
}
