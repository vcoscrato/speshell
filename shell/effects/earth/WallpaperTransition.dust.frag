#version 440
#extension GL_GOOGLE_include_directive : enable
// The dust a shard crumbles into as it falls, drifting up where it stood, behind the
// shards still falling.
layout(location = 0) in vec2 p;
layout(location = 1) in vec4 a0;   // the puff's middle and radius (px), and its seed
layout(location = 2) in vec4 a1;   // how far it has thinned out
layout(location = 3) in vec4 a2;
layout(location = 0) out vec4 fragColor;
#include "Shards.glsl"

void main() {
    vec2 pf = puff(p, a0.xy, a0.z, a0.w);
    float k = pf.x * 0.4 * pow(1.0 - a1.x, 1.3);
    fragColor = vec4(mix(u.cDust.rgb, u.cDustShade.rgb, pf.y), 1.0) * k * u.qt_Opacity;
}
