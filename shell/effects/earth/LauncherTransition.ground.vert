#version 440
#extension GL_GOOGLE_include_directive : enable
// Fits the ground's mesh: its first four rows to the band the crack and dust take,
// and each four after them round a rock chip where it is now, all within the item,
// and collapsed to a point while they are not there: a point at the box's top left,
// its top edge, its bottom edge, and a point at its bottom right, so the quads
// between boxes have no area. It also places the dust puffs, once for the band
// rather than for each of its pixels.
layout(location = 0) in vec4 qt_Vertex;
layout(location = 1) in vec2 qt_MultiTexCoord0;
layout(location = 0) out vec4 v;    // the screen point (px), what this is (0 the crack and dust, 1 a chip), and a chip's fade
layout(location = 1) out vec4 d0;   // the puffs' centers and radii, packed in turn; a chip's center, turn, and size in d0
layout(location = 2) out vec4 d1;
layout(location = 3) out vec4 d2;
layout(location = 4) out vec4 d3;
layout(location = 5) out vec4 d4;
layout(location = 6) out vec4 d5;
layout(location = 7) out vec4 d6;
#define VERTEX_SHADER
#include "LauncherTransition.ground.glsl"

void main() {
    float row = floor(qt_MultiTexCoord0.y * (u.rows - 1.0) + 0.5);
    float slot = floor(row / 4.0);
    float corner = row - slot * 4.0;
    vec4 box = vec4(0.0);
    v = vec4(0.0);
    d0 = d1 = d2 = d3 = d4 = d5 = d6 = vec4(0.0);
    if (slot < 0.5) {
        // The crack strays at most 16 px from the ground line, and the puffs reach
        // at most 129 px above it and 47 px below.
        bool dusty = u.dust > 0.0 && u.dust < 1.0;
        if (dusty || u.crackOpen > 0.0) {
            float w = max(u.crackLen, dusty ? 1.35 * u.spread + 110.0 : 0.0);
            box = vec4(u.origin.x - w, u.origin.y - (dusty ? 130.0 : 24.0), u.origin.x + w, u.origin.y + (dusty ? 48.0 : 24.0));
        }
        if (dusty) {
            vec3 p0 = puff(0.0), p1 = puff(1.0), p2 = puff(2.0), p3 = puff(3.0), p4 = puff(4.0);
            vec3 p5 = puff(5.0), p6 = puff(6.0), p7 = puff(7.0), p8 = puff(8.0);
            d0 = vec4(p0, p1.x);
            d1 = vec4(p1.yz, p2.xy);
            d2 = vec4(p2.z, p3);
            d3 = vec4(p4, p5.x);
            d4 = vec4(p5.yz, p6.xy);
            d5 = vec4(p6.z, p7);
            d6 = vec4(p8, 0.0);
        }
    } else if (u.burst > 0.0 && u.burst < 1.2) {
        // A chip reaches at most 1.3 times its size (at most 12 px), and its outline
        // and edge 3 px more.
        vec4 c = chip(slot - 1.0);
        box = vec4(c.xy - 20.0, c.xy + 20.0);
        v = vec4(0.0, 0.0, 1.0, 1.0 - smoothstep(0.8, 1.2, u.burst));
        d0 = c;
    }
    box = vec4(max(box.xy, u.rect.xy), min(box.zw, u.rect.xy + u.rect.zw));
    float x = corner < 0.5 ? box.x : (corner > 2.5 ? box.z : mix(box.x, box.z, qt_MultiTexCoord0.x));
    vec2 p = box.z > box.x && box.w > box.y ? vec2(x, corner < 1.5 ? box.y : box.w) : vec2(-64.0);
    v.xy = p;
    gl_Position = u.qt_Matrix * vec4(p - u.rect.xy, 0.0, qt_Vertex.w);
}
