#version 440
#extension GL_GOOGLE_include_directive : enable
// Orders the earth wallpaper transition's shards once, for the order they are drawn
// in: the shard furthest through its fall goes on top, and the one that broke loose
// first mostly is. `which` picks the table, one texel per cell:
//   0: each cell's rank, counting the cells that break loose after it
//   1: for each place in the drawing order, the cell that holds it
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 center;
    float reach;
    float which;
} u;
layout(binding = 1) uniform sampler2D cells;
layout(binding = 2) uniform sampler2D ranks;
#include "Shatter.glsl"

const int CELLS = 960; // KX * N

// When cell i (as numbered along a ray, then around) breaks loose.
float releaseOf(float i) {
    float col = mod(i, KX) * CELL + 1.0;
    return abs(texture(cells, vec2((col + 0.5) / (KX * CELL), (floor(i / KX) + 0.5) / N)).z);
}

void main() {
    float i = floor(qt_TexCoord0.x * float(CELLS));
    float found = 0.0;
    if (u.which < 0.5) {
        float mine = releaseOf(i);
        for (int j = 0; j < CELLS; j++) {
            float other = releaseOf(float(j));
            if (other > mine || (other == mine && float(j) < i))
                found += 1.0;
        }
    } else {
        for (int j = 0; j < CELLS; j++) {
            if (texture(ranks, vec2((float(j) + 0.5) / float(CELLS), 0.5)).x == i)
                found = float(j);
        }
    }
    fragColor = vec4(found, 0.0, 0.0, 1.0);
}
