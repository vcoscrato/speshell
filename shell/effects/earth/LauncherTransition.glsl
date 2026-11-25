// What LauncherTransition.vert and LauncherTransition.frag share: the uniforms, how
// the slab's stone breaks into chunks and when each goes, and the crumbs that fall
// off its face as it crumbles.
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 rect;         // this item's rect on screen (px)
    vec4 panel;        // panel rect at rest (px)
    float radius;
    float ground;      // px, screen y of the ground line
    vec2 offset;       // px, slab displacement from rest
    float cracks;      // 0..1 cracks spreading from the bottom middle
    float crumble;     // 0 whole .. 1 every chunk gone
    float rows;        // the mesh's rows of vertices
    vec4 cLight;
    vec4 cMid;
    vec4 cDark;
    vec4 cEdge;
} u;
#include "../common/common.glsl"

const float CHUNK = 64.0;
const float JIT = 0.9;
// How much of the crumble each chunk's own fall takes.
const float W = 0.8;
// Crumbs: two from each column this wide, across the widest launcher.
const float CRUMB_COLUMN = 30.0;
const int CRUMB_COLUMNS = 42;

// The site of a cell's chunk, as voronoiSite() places it, so chunks break along the
// cracks drawn between them.
vec2 chunkSite(vec2 cell) {
    return (cell + 0.5 + (hash2(cell) - 0.5) * JIT) * CHUNK;
}

// Where the slab landed: the middle of its bottom edge, at rest.
vec2 impact() {
    return vec2(u.panel.x + u.panel.z * 0.5, u.panel.y + u.panel.w);
}

// How far from the impact a point on the slab is, 0..1 at its furthest corners.
float reach(vec2 q) {
    return clamp(distance(q, impact()) / max(length(vec2(u.panel.z * 0.5, u.panel.w)), 1.0), 0.0, 1.0);
}

// When the chunk around `site` starts to go, 0..1: outward from the impact, unevenly.
float chunkStart(vec2 site) {
    return clamp(0.55 * reach(site) + 0.45 * hash(site * 0.031), 0.0, 1.0);
}

float chunkAge(vec2 site) {
    return clamp((u.crumble * (1.0 + W) - chunkStart(site)) / W, 0.0, 1.0);
}

// Crumb k of column ci, falling off the face as the stone around where it starts
// goes: its center on the slab at rest, its turn, and its size; `fade` is how much
// of it shows (0 before it falls, once it has gone, and for a column off the face).
vec4 crumb(float ci, float k, out float fade) {
    vec2 h = hash2(vec2(ci, k + 3.0));
    vec2 start = vec2((ci + h.x) * CRUMB_COLUMN, u.panel.y + 12.0 + h.y * (u.panel.w - 24.0));
    float age = (u.crumble * (1.0 + W) - chunkStart(start)) * 0.9;
    bool shows = age > 0.0 && age <= 0.75 && u.crumble < 1.0
        && start.x > u.panel.x + 4.0 && start.x < u.panel.x + u.panel.z - 4.0;
    fade = shows ? 1.0 - smoothstep(0.55, 0.75, age) : 0.0;
    vec2 pos = start + vec2((h.x - 0.5) * 40.0 * age, 900.0 * age * age);
    return vec4(pos, age * 9.0 + h.x * 6.0, mix(1.6, 3.4, hash(vec2(ci, k + 9.0))));
}
