// What LauncherTransition.ground.vert and its fragment shader share: the uniforms,
// and where each dust puff and rock chip is.
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 rect;         // this item's rect on screen (px)
    vec2 origin;       // px, crack center on the ground line
    float crackLen;    // px, half length
    float crackOpen;   // 0..1
    float burst;       // s since the debris burst (< 0 before)
    float dust;        // 0..1 dust puff progress
    float spread;      // px, half width the dust spans
    float rows;        // the mesh's rows of vertices
    vec4 cDust;
    vec4 cDustShade;
    vec4 cRock;
    vec4 cDark;
} u;
#include "../common/common.glsl"

const int PUFFS = 9;
const int CHIPS = 14;

// How far the dust puffs have swelled.
float grown() {
    return 1.0 - pow(1.0 - u.dust, 2.5);
}

// Dust puff i along the ground, swelling, rising a little, and spreading out: its
// center and radius (px).
vec3 puff(float fi) {
    float grow = grown();
    float x = u.origin.x + (fi / 8.0 - 0.5) * 2.0 * u.spread + (hash(vec2(fi, 4.0)) - 0.5) * 60.0;
    float r = mix(8.0, 20.0 + 26.0 * hash(vec2(fi, 5.0)), grow);
    return vec3(x + (x - u.origin.x) * 0.35 * grow, u.origin.y - r * 0.4 - 46.0 * grow * hash(vec2(fi, 6.0)), r);
}

// Rock chip i, flung up from the crack and tumbling under gravity: its center, turn,
// and size (px).
vec4 chip(float fi) {
    vec2 h = hash2(vec2(fi, 9.0));
    vec2 start = vec2(u.origin.x + (h.x - 0.5) * 1.6 * u.crackLen, u.origin.y);
    vec2 vel = vec2((h.x - 0.5) * 420.0, -380.0 - 260.0 * h.y);
    vec2 pos = start + vel * u.burst + vec2(0.0, 1400.0) * u.burst * u.burst * 0.5;
    return vec4(pos, u.burst * (h.y - 0.5) * 16.0, 4.0 + 8.0 * hash(vec2(fi, 11.0)));
}
