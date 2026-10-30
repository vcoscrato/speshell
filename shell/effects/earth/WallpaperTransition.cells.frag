#version 440
#extension GL_GOOGLE_include_directive : enable
// Works out the earth wallpaper transition's shards once, into a float table that its
// shader looks up: CELL texels for each cell along a ray (from X0) and around the
// impact, holding
//   0: its site's offset from the cell's corner (cell units), and the shard it is in
//   1: that shard's pivot (px), the moment it breaks loose, negative if it crumbles
//      to dust from this cell, and how long it falls, negative if it joins two cells
//   2: its spin, the dust's seed, and the shard again, beside them
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 center;       // px, the point of impact
    float reach;       // px, from the impact to the furthest corner
} u;
#include "Shatter.glsl"

vec2 siteOf(vec2 c) {
    return c + 0.5 + (hash2(wrapId(c) + 0.31) - 0.5) * JITTER;
}

// The shard a cell belongs to: about half the rays join pairs of cells along them.
vec2 groupOf(vec2 c) {
    vec2 w = wrapId(c);
    float off = step(0.5, hash(vec2(w.y, 2.7)));
    float pair = floor((w.x + off) * 0.5);
    bool joined = hash(vec2(pair, w.y + 5.1)) < 0.55;
    return vec2(joined ? pair * 2.0 - off : w.x, w.y) + vec2(joined ? 0.5 : 0.0, 0.0);
}

// A shard's pivot on screen (the middle of its cells) and the moment it breaks loose.
vec3 shardOf(vec2 c, vec2 grp) {
    vec2 xs = fract(grp.x) > 0.25
        ? (siteOf(vec2(floor(grp.x), c.y)) + siteOf(vec2(floor(grp.x) + 1.0, c.y))) * 0.5
        : siteOf(c);
    vec2 pivot = toScreen(xs);
    vec2 pd = pivot - u.center;
    // Rubble at the middle goes at once; further out the slabs hang on unevenly,
    // and a few hang on a while longer.
    float h = hash(grp + 0.7);
    float tr = 0.1 + crackAt(length(pd), atan(pd.y, pd.x)) * 1.3 + 0.45 * h * h
             + 0.2 * step(hash(grp + 1.9), 0.2) * step(40.0, length(pd));
    return vec3(pivot, tr);
}

void main() {
    vec2 t = floor(qt_TexCoord0 * vec2(KX * CELL, N));
    float k = mod(t.x, CELL);
    vec2 c = vec2(floor(t.x / CELL) + X0, t.y);
    vec2 grp = groupOf(c);
    bool joined = fract(grp.x) > 0.25;
    if (k < 0.5) {
        fragColor = vec4(siteOf(c) - c, grp);
    } else if (k < 1.5) {
        // About half the shards crumble into dust, each from one of its cells.
        bool dust = (!joined || c.x == floor(grp.x)) && hash(grp + 4.4) < 0.5;
        vec3 sh = shardOf(c, grp);
        float dur = mix(0.5, 0.75, hash(grp + 2.9));
        fragColor = vec4(sh.xy, dust ? -sh.z : sh.z, joined ? -dur : dur);
    } else {
        fragColor = vec4((hash(grp + 8.3) - 0.5) * 1.8, hash(grp + 6.1), grp);
    }
}
