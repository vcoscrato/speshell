#version 440
#extension GL_GOOGLE_include_directive : enable
// Fits each diamond of the Debris strip (Debris.glsl) around one piece where it is
// now, and hands Debris.frag what it needs to draw it; a piece that is not there
// collapses to a point.
layout(location = 0) in vec4 qt_Vertex;
layout(location = 1) in vec2 qt_MultiTexCoord0;
layout(location = 0) out vec2 p;
layout(location = 1) out vec4 piece;   // its center (px), its heading, and its kind: 0 dust, 1 leaf
layout(location = 2) out vec4 shape;   // dust: its length; leaf: its half-length, turn, and flip
#define VERTEX_SHADER
#include "Debris.glsl"

void main() {
    float row = floor(qt_MultiTexCoord0.y * (3.0 * float(DUST + LEAVES) - 1.0) + 0.5);
    float slot = floor(row / 3.0);
    float role = row - slot * 3.0;
    // How far the piece reaches from its center (0: not there).
    float h = 0.0;
    piece = vec4(0.0);
    shape = vec4(0.0);

    if (slot < float(DUST)) {
        // Dust: short streaks along the flow.
        float fj = slot;
        if (fj < u.dust) {
            float seed = fj + 100.0;
            vec4 rnd = traits(seed);
            float uu = progress(rnd, 1.6);
            float th = 6.2831853 * rnd.w + u.spin * uu;
            vec3 o = orbit(seed, rnd, uu, th);
            float lenS = mix(7.0, 20.0, hash(vec2(fj, 9.1)));
            piece = vec4(o, 0.0);
            shape = vec4(lenS, 0.0, 0.0, 0.0);
            h = lenS + 4.0;
        }
    } else {
        // Leaves, tumbling: each spins in the plane and flips over.
        float fi = slot - float(DUST);
        if (fi < u.leaves) {
            vec4 rnd = traits(fi);
            float uu = progress(rnd, 1.0);
            float th = 6.2831853 * rnd.w + u.spin * uu;
            vec3 o = orbit(fi, rnd, uu, th);
            float L = u.leafSize * mix(0.7, 1.2, hash(vec2(fi, 7.7)));
            float spinRate = mix(-4.5, 4.5, hash(vec2(fi, 3.3)));
            float ang = o.z + u.time * spinRate + 6.2831853 * hash(vec2(fi, 8.8));
            float flip = cos(u.time * mix(2.0, 5.5, hash(vec2(fi, 5.5))) + fi * 1.7);
            piece = vec4(o, 1.0);
            shape = vec4(L, ang, flip, 0.0);
            // A leaf and its stem reach no further than sqrt(2.2) times its half-length.
            h = L * 1.4832 + 1.0;
        }
    }

    // A diamond reaches its points sqrt(2) further than the circle it holds.
    h *= 1.4143;
    vec2 corner = role < 0.5 ? vec2(0.0, -1.0) : (role < 1.5 ? vec2(qt_MultiTexCoord0.x * 2.0 - 1.0, 0.0) : vec2(0.0, 1.0));
    p = h > 0.0 ? piece.xy + corner * h : vec2(-64.0);
    gl_Position = u.qt_Matrix * vec4(p - u.origin, 0.0, qt_Vertex.w);
}
