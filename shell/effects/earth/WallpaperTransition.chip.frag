#version 440
#extension GL_GOOGLE_include_directive : enable
// A chip of the old wallpaper flung up from the cracks as the front passes, tumbling,
// lit on its top and in shade below, with a dark rim.
layout(location = 0) in vec2 p;
layout(location = 1) in vec4 a0;   // its middle (px), its size, and its turn
layout(location = 2) in vec4 a1;   // its color, and how far it has faded in and out
layout(location = 3) in vec4 a2;
layout(location = 0) out vec4 fragColor;
#include "Shards.glsl"

void main() {
    float size = a0.z;
    vec2 lp = rot(p - a0.xy, a0.w);
    float dc = max(abs(lp.x) - size, abs(lp.y) - size * 0.7);
    dc = max(dc, (lp.x + lp.y) * 0.7 - size * 0.6);
    vec3 chipCol = a1.rgb * (lp.y < 0.0 ? 1.25 : 0.7);
    vec4 ch = over(vec4(0.0), u.cCrack.rgb, cover(-dc + 1.0));
    ch = over(ch, chipCol, cover(-dc));
    fragColor = ch * a1.a * u.qt_Opacity;
}
