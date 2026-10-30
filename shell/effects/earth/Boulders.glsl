// What Boulders.vert and its fragment shaders share: the uniforms, and where each
// piece is at the time, so the vertex shader can fit a quad to a piece and its
// fragment shader draw just that piece.
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
    vec4 rect;         // the Boulders item's rect on screen (px)
    vec4 panel;        // panel rect on screen (px)
    float ground;      // px, screen y of the ground line
    float lift;        // 0..1 entrance: rocks rise in turn
    float fall;        // 0..1 exit: rocks drop in turn
    float kind;        // the piece's kind: 0 a far stone, 1 a boulder, 2 a dust mote
    float piece;       // its index among its kind
    vec4 cLight;
    vec4 cMid;
    vec4 cDark;
    vec4 cEdge;
} u;
#include "../common/common.glsl"

const int ROCKS = 7;
const int FAR = 14;
const int MOTES = 26;

vec2 panelCenter() {
    return u.panel.xy + u.panel.zw * 0.5;
}

// How far the drifts and motes have come in: they show once the rocks rise, and go
// as they drop.
float held() {
    return clamp(u.lift * 1.4, 0.0, 1.0) * (1.0 - u.fall);
}

mat2 rot(float a) {
    float cs = cos(a), sn = sin(a);
    return mat2(cs, sn, -sn, cs);
}

float backOut(float x) {
    float c = 1.7;
    return 1.0 + (c + 1.0) * pow(x - 1.0, 3.0) + c * pow(x - 1.0, 2.0);
}

// ── Far stones: small dark stones circling slowly well behind the boulders ──

// Far stone i's random draws (distance, phase, size and speed), its center, and its
// size (px; 0 while it is gone).
vec3 farStone(float fi, out vec3 r) {
    vec2 h = u.panel.zw * 0.5;
    r = vec3(hash(vec2(fi, 31.1)), hash(vec2(fi, 32.7)), hash(vec2(fi, 35.3)));
    float dist = mix(70.0, 200.0, r.x);
    vec2 hh = h + dist;
    float rr = min(10.0 + dist * 1.8, min(hh.x, hh.y));
    float P = rrPerimeter(hh, rr);
    vec2 pos = panelCenter() + rrPoint(r.y * P - u.time * mix(9.0, 20.0, r.z), hh, rr);
    pos.y += 5.0 * sin(u.time * 1.1 + fi * 1.7);
    float appear = smoothstep(0.0, 1.0, clamp(u.lift * 1.8 - 0.05 * fi, 0.0, 1.0));
    float drop = clamp(u.fall * 1.6 - 0.05 * fi, 0.0, 1.0);
    pos.y += drop * drop * 260.0;
    float size = max(0.0, mix(3.5, 8.0, r.z * r.z) * appear * (1.0 - drop));
    return vec3(pos, size);
}

// ── Boulders ──

// Rest position as a fraction of the panel plus a px offset (xy, zw), and the size
// (px). Older GLSL targets have no constant arrays.
vec4 place(int i, out float size) {
    if (i == 0) { size = 26.0; return vec4(0.0, 0.36, -54.0, 0.0); }
    if (i == 1) { size = 12.0; return vec4(0.0, 0.8, -32.0, 0.0); }
    if (i == 2) { size = 16.0; return vec4(0.14, 0.0, 0.0, -40.0); }
    if (i == 3) { size = 30.0; return vec4(0.8, 0.0, 0.0, -58.0); }
    if (i == 4) { size = 22.0; return vec4(1.0, 0.58, 50.0, 0.0); }
    if (i == 5) { size = 10.0; return vec4(1.0, 0.16, 28.0, 0.0); }
    size = 8.0;
    return vec4(0.5, 0.0, 0.0, -26.0);
}

// Boulder i's center, its size (px), its seed, and how far it has risen and dropped.
vec2 boulder(int i, out float size, out float seed, out float rise, out float drop) {
    float fi = float(i);
    vec4 pl = place(i, size);
    vec2 rest = u.panel.xy + u.panel.zw * pl.xy + pl.zw;
    seed = hash(vec2(fi, 7.7)) * 6.2831853;
    rest.y += 7.0 * sin(u.time * 1.7 + seed) * (size / 26.0 + 0.4);
    rest.x += 4.0 * sin(u.time * 0.55 + seed * 2.0);
    rise = backOut(clamp(u.lift * 1.6 - 0.1 * fi, 0.0, 1.0));
    drop = clamp(u.fall * 1.5 - 0.08 * fi, 0.0, 1.0);
    vec2 from = vec2(rest.x, u.ground + size * 1.3);
    vec2 pos = mix(from, rest, rise);
    pos.y += drop * drop * (u.ground + size * 1.3 - rest.y);
    return pos;
}

// ── Dust motes rising past the launcher, in front ──

// Mote i's center and size (px), its spin, and its opacity.
vec4 mote(float fi, out float alpha) {
    vec3 r = vec3(hash(vec2(fi, 51.3)), hash(vec2(fi, 52.9)), hash(vec2(fi, 54.1)));
    float life = mix(3.5, 6.5, r.z);
    float age = fract(u.time / life + r.y);
    float x = u.panel.x - 180.0 + r.x * (u.panel.z + 360.0) + 14.0 * sin(u.time * (0.6 + r.z) + fi);
    float y = u.ground + 40.0 - age * (u.panel.w + 200.0) * mix(0.6, 1.0, r.z);
    float fade = smoothstep(0.0, 0.15, age) * smoothstep(1.0, 0.7, age);
    alpha = fade * 0.8 * held();
    return vec4(x, y, mix(1.5, 3.2, r.y), u.time * 1.5 + fi);
}

#ifndef VERTEX_SHADER
// Premultiplied "over" of a flat color with coverage k.
void over(inout vec3 col, inout float a, vec3 c, float k) {
    col = mix(col, c, k);
    a = mix(a, 1.0, k);
}

// What every piece leaves out: the panel itself, and anything outside the Boulders
// item, as the one shader that drew them all once clipped them to it.
float shown(vec2 p) {
    vec2 h = u.panel.zw * 0.5;
    vec2 inRect = step(u.rect.xy, p) * step(p, u.rect.xy + u.rect.zw);
    return cover(sdRoundRect(p - panelCenter(), h, 10.0) - 2.0) * inRect.x * inRect.y;
}
#endif
