#version 440
#extension GL_GOOGLE_include_directive : enable
// One of the dust motes rising past the launcher, in front: a small turning square.
layout(location = 0) in vec2 p;
layout(location = 0) out vec4 fragColor;
#include "Boulders.glsl"

void main() {
    float alpha;
    vec4 m = mote(u.piece, alpha);
    vec2 o = rot(m.w) * (p - m.xy);
    float k = cover(m.z - max(abs(o.x), abs(o.y))) * alpha;
    fragColor = vec4(u.cLight.rgb, 1.0) * k * shown(p) * u.qt_Opacity;
}
