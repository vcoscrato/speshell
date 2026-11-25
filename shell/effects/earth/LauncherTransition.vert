#version 440
#extension GL_GOOGLE_include_directive : enable
// Fits the slab's mesh: its first four rows to the whole item, where the slab draws,
// and each four after them round a crumb where it is now, collapsed to a point while
// it is not falling: a point at the box's top left, its top edge, its bottom edge,
// and a point at its bottom right, so the quads between boxes have no area. It also
// works out the cracks the landing sends up, once for the slab rather than for each
// of its pixels.
layout(location = 0) in vec4 qt_Vertex;
layout(location = 1) in vec2 qt_MultiTexCoord0;
layout(location = 0) out vec4 v;     // the screen point (px), what this is (0 the slab, 1 a crumb), and a crumb's fade
layout(location = 1) out vec4 piece; // a crumb's center on screen (px), turn, and size
layout(location = 2) out vec4 ray0;  // each crack: its direction, length, and where its branch leaves it, signed by its side
layout(location = 3) out vec4 ray1;
layout(location = 4) out vec4 ray2;
layout(location = 5) out vec4 ray3;
layout(location = 6) out vec4 bends; // how far each crack has bent off its line where its branch leaves it
#define VERTEX_SHADER
#include "LauncherTransition.glsl"

// Crack i of a few fanning upward from where the slab landed, unevenly: its
// direction and length, and where its branch leaves it, signed by the side it goes.
vec4 ray(float fi, out float bend) {
    float len = u.panel.w * 1.05;
    float a = -1.5708 + (fi - 1.5) * 0.62 + (hash(vec2(fi, 1.7)) - 0.5) * 0.35;
    float L = len * mix(0.45, 0.95, hash(vec2(fi, 2.9)));
    float at = L * mix(0.3, 0.55, hash(vec2(fi, 4.1)));
    bend = zig(at / 34.0, fi) * 16.0 + zig(at / 9.0, fi + 7.0) * 4.0;
    return vec4(cos(a), sin(a), L, hash(vec2(fi, 5.3)) < 0.5 ? -at : at);
}

void main() {
    float row = floor(qt_MultiTexCoord0.y * (u.rows - 1.0) + 0.5);
    float slot = floor(row / 4.0);
    float corner = row - slot * 4.0;
    vec4 box = u.rect.xyxy + vec4(0.0, 0.0, u.rect.zw);
    v = vec4(0.0);
    piece = vec4(0.0);
    ray0 = ray1 = ray2 = ray3 = vec4(0.0);
    bends = vec4(0.0);
    if (slot < 0.5) {
        ray0 = ray(0.0, bends.x);
        ray1 = ray(1.0, bends.y);
        ray2 = ray(2.0, bends.z);
        ray3 = ray(3.0, bends.w);
    } else {
        // Crumbs, two from each column from the panel's left on.
        float n = slot - 1.0;
        float k = mod(n, 2.0);
        float fade;
        vec4 c = crumb(floor(u.panel.x / CRUMB_COLUMN) + floor(n / 2.0), k, fade);
        c.xy += u.offset;
        // It reaches at most sqrt(2) times its size and the outline past its middle.
        float e = (c.w + 2.4) * 1.4143 + 1.0;
        box = fade > 0.0 && c.y - e < u.ground ? vec4(c.xy - e, c.xy + e) : vec4(0.0);
        v = vec4(0.0, 0.0, 1.0, fade);
        piece = c;
    }
    float x = corner < 0.5 ? box.x : (corner > 2.5 ? box.z : mix(box.x, box.z, qt_MultiTexCoord0.x));
    vec2 p = box.z > box.x ? vec2(x, corner < 1.5 ? box.y : box.w) : vec2(-64.0);
    v.xy = p;
    gl_Position = u.qt_Matrix * vec4(p - u.rect.xy, 0.0, qt_Vertex.w);
}
