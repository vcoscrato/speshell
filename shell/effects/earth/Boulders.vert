#version 440
#extension GL_GOOGLE_include_directive : enable
// Fits the quad of one of the Boulders' pieces to where that piece is now, from the
// same placement its fragment shader draws it at; a piece that is gone collapses to
// nothing. `p` is the screen point, as the fragment shaders take it.
layout(location = 0) in vec4 qt_Vertex;
layout(location = 1) in vec2 qt_MultiTexCoord0;
layout(location = 0) out vec2 p;
#define VERTEX_SHADER
#include "Boulders.glsl"

void main() {
    // The piece's box on screen: (left, top, right, bottom).
    vec4 box;
    if (u.kind < 0.5) {
        vec3 r;
        vec3 s = farStone(u.piece, r);
        // A chip reaches at most sqrt(2.5) times its size from its center.
        float e = s.z > 0.0 ? s.z * 1.6 + 2.0 : 0.0;
        box = vec4(s.xy - e, s.xy + e);
    } else if (u.kind < 1.5) {
        float size, seed, rise, drop;
        vec2 pos = boulder(int(u.piece), size, seed, rise, drop);
        // Its pebbles circle out to 2.1 times its size, and grit trickles 50 px below.
        float e = size * 2.1 + 8.0;
        box = vec4(pos - e, pos + vec2(e, max(e, size + 56.0)));
    } else {
        float alpha;
        vec4 m = mote(u.piece, alpha);
        float e = alpha > 0.0 ? m.z * 1.42 + 2.0 : 0.0;
        box = vec4(m.xy - e, m.xy + e);
    }
    p = mix(box.xy, box.zw, qt_MultiTexCoord0);
    gl_Position = u.qt_Matrix * vec4(p - u.rect.xy, 0.0, qt_Vertex.w);
}
