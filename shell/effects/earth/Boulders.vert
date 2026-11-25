#version 440
#extension GL_GOOGLE_include_directive : enable
// Fits each box of a Boulders strip around one piece where it is now, and hands its
// fragment shader what it needs to draw it; a piece that is gone collapses to a
// point. Every piece takes four rows of the strip: a point at its box's top left, the
// top edge, the bottom edge, and a point at its bottom right, so the quads between
// pieces have no area. A dust band takes a run of rows along the arc it covers, its
// strip reaching the most the ribbon strays from its line to either side, with a
// point at each end. `p` is the screen point, as the fragment shaders take it.
layout(location = 0) in vec4 qt_Vertex;
layout(location = 1) in vec2 qt_MultiTexCoord0;
layout(location = 0) out vec2 p;
layout(location = 1) out vec4 a0;
layout(location = 2) out vec4 a1;
layout(location = 3) out vec3 m0;      // a boulder's turn, as the columns of a rotation
layout(location = 4) out vec3 m1;
layout(location = 5) out vec3 m2;
#define VERTEX_SHADER
#include "Boulders.glsl"

// Rotation by Euler angles about x, then y, then z.
mat3 rot3(vec3 e) {
    vec3 c = cos(e), s = sin(e);
    mat3 rx = mat3(1.0, 0.0, 0.0, 0.0, c.x, s.x, 0.0, -s.x, c.x);
    mat3 ry = mat3(c.y, 0.0, -s.y, 0.0, 1.0, 0.0, s.y, 0.0, c.y);
    mat3 rz = mat3(c.z, s.z, 0.0, -s.z, c.z, 0.0, 0.0, 0.0, 1.0);
    return rz * ry * rx;
}

void main() {
    float row = floor(qt_MultiTexCoord0.y * (u.rows - 1.0) + 0.5);
    float side = qt_MultiTexCoord0.x;
    a0 = vec4(0.0);
    a1 = vec4(0.0);
    m0 = vec3(1.0, 0.0, 0.0);
    m1 = vec3(0.0, 1.0, 0.0);
    m2 = vec3(0.0, 0.0, 1.0);
    const float BAND_ROWS = float(SEGMENTS + 3);
    float bandRows = u.kind < 0.5 ? float(BANDS) * BAND_ROWS : 0.0;

    if (row < bandRows) {
        // A dust band: the arc from its tail to its head, out to 62 px either side of
        // its line (the ribbon strays at most 57 px from it).
        float fj = floor(row / BAND_ROWS);
        float r = row - fj * BAND_ROWS;
        float rr, P, head;
        vec2 hh = bandRect(fj, rr, P, head);
        float len = P * 0.42 * held();
        float seg = clamp(r - 1.0, 0.0, float(SEGMENTS));
        float s = head + 2.0 - (len + 4.0) * seg / float(SEGMENTS);
        vec2 b = rrPoint(s, hh, rr);
        vec2 n = (b - clamp(b, rr - hh, hh - rr)) / rr;
        float off = r < 0.5 || r > float(SEGMENTS) + 1.5 ? -62.0 : mix(-62.0, 62.0, side);
        a0 = vec4(0.0, fj, 0.0, 0.0);
        p = len > 0.0 ? panelCenter() + b + n * off : vec2(-64.0);
        gl_Position = u.qt_Matrix * vec4(p - u.rect.xy, 0.0, qt_Vertex.w);
        return;
    }

    float slot = floor((row - bandRows) / 4.0);
    float corner = row - bandRows - slot * 4.0;
    // The piece's box on screen: (left, top, right, bottom); empty while it is gone.
    vec4 box = vec4(0.0);
    if (u.kind < 0.5) {
        vec3 r;
        vec3 s = farStone(slot, r);
        // A chip reaches at most sqrt(2.5) times its size from its center.
        float e = s.z * 1.6 + 2.0;
        if (s.z > 0.0)
            box = vec4(s.xy - e, s.xy + e);
        a0 = vec4(1.0, slot, s.z, u.time * mix(-1.2, 1.2, r.x) + slot);
        a1 = vec4(s.xy, mix(0.55, 0.85, r.z), 0.0);
    } else if (u.kind < 1.5) {
        float size, seed, rise, drop;
        int i = int(slot);
        vec2 pos = boulder(i, size, seed, rise, drop);
        // Its pebbles circle out to 2.1 times its size, and grit trickles 50 px below.
        float e = size * 2.1 + 8.0;
        box = vec4(pos - e, pos + vec2(e, max(e, size + 56.0)));
        a0 = vec4(pos, size, slot);
        a1 = vec4(seed, rise, drop, 0.0);
        mat3 M = rot3(vec3(seed + u.time * (hash(vec2(slot, 2.3)) - 0.5) * 0.9,
                           seed * 1.7 + u.time * (hash(vec2(slot, 4.1)) - 0.5) * 0.8,
                           seed * 0.6 + u.time * (hash(vec2(slot, 5.9)) - 0.5) * 0.7));
        m0 = M[0];
        m1 = M[1];
        m2 = M[2];
    } else {
        float alpha;
        vec4 m = mote(slot, alpha);
        float e = m.z * 1.42 + 2.0;
        if (alpha > 0.0)
            box = vec4(m.xy - e, m.xy + e);
        a0 = vec4(2.0, m.z, m.w, alpha);
        a1 = vec4(m.xy, 0.0, 0.0);
    }
    float x = corner < 0.5 ? box.x : (corner > 2.5 ? box.z : mix(box.x, box.z, side));
    p = box.z > box.x ? vec2(x, corner < 1.5 ? box.y : box.w) : vec2(-64.0);
    gl_Position = u.qt_Matrix * vec4(p - u.rect.xy, 0.0, qt_Vertex.w);
}
