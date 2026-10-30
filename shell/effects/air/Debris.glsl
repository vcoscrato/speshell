// What Debris.vert and Debris.frag share: the uniforms, and where each piece is. The
// pieces come as one strip of diamonds, three rows of vertices each (top point, left
// and right, bottom point), so the joins between them have no area: first the dust,
// then the leaves over it.
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
    vec2 origin;       // px, this item's top-left on screen
    vec2 center;
    float leaves;      // number of leaves (up to 16)
    float dust;        // number of dust specks (up to 24)
    float r0;          // px, middle orbit radius
    float spin;        // +1 counter-clockwise on screen, -1 clockwise
    float head;        // rad travelled along the spiral
    float leafSize;    // px, half-length of a leaf
    float turbulence;  // px the leaves are buffeted off their path
    vec4 mask;         // px rect the debris passes behind (zero size: none)
    float maskRadius;
    vec4 cLeaf;
    vec4 cLeafBack;
    vec4 cOutline;
    vec4 cDust;
    vec4 cGlint;
} u;
#include "../common/common.glsl"

const int DUST = 24;
const int LEAVES = 16;

// Debris item `seed`: its random traits, and how far along its path it is (rad).
vec4 traits(float seed) {
    return vec4(hash(vec2(seed, 1.3)), hash(vec2(seed, 2.9)), hash(vec2(seed, 4.1)), hash(vec2(seed, 6.7)));
}

float progress(vec4 rnd, float rate) {
    // Each piece gusts along at its own pace, now ahead of the others, now behind.
    return u.head * rate * mix(0.75, 1.3, rnd.x) - 1.5 * rnd.y
         + 0.45 * sin(u.time * mix(0.7, 1.6, rnd.z) + 6.2831853 * rnd.w);
}

// Where the item is: its center on screen, and its heading (rad).
vec3 orbit(float seed, vec4 rnd, float uu, float th) {
    float R = u.r0 * mix(0.8, 1.3, rnd.z) * (1.0 + 0.12 * sin(uu * 1.7 + rnd.x * 6.0));
    vec2 pos = u.center + R * vec2(cos(th), sin(th))
             + u.turbulence * vec2(sin(u.time * 1.3 + seed * 2.1) + 0.5 * sin(u.time * 2.9 + seed * 5.3),
                                   cos(u.time * 1.1 + seed * 3.7) + 0.5 * cos(u.time * 3.3 + seed * 1.9));
    return vec3(pos, th + u.spin * 1.5707963);
}
