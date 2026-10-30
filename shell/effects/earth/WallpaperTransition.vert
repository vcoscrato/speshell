#version 440
#extension GL_GOOGLE_include_directive : enable
// Fits each diamond of a strip of the earth wallpaper transition's falling pieces
// (Shards.glsl) around one piece where it is now, and hands its fragment shader what
// it needs to draw it: a dust puff, a falling shard, or a flung chip.
layout(location = 0) in vec4 qt_Vertex;
layout(location = 1) in vec2 qt_MultiTexCoord0;
layout(location = 0) out vec2 p;
layout(location = 1) out vec4 a0;
layout(location = 2) out vec4 a1;
layout(location = 3) out vec4 a2;
#define VERTEX_SHADER
#include "Shards.glsl"

void main() {
    float row = floor(qt_MultiTexCoord0.y * (3.0 * u.slots - 1.0) + 0.5);
    float slot = floor(row / 3.0);
    float role = row - slot * 3.0;
    float t = u.time;
    // The diamond: its middle, and how far its points reach (0: collapsed).
    vec2 mid = vec2(0.0);
    float h = 0.0;
    a0 = vec4(0.0);
    a1 = vec4(0.0);
    a2 = vec4(0.0);

    if (u.kind < 1.5) {
        // Dust: every cell in turn. Shards: in the order the order table gives, the
        // last to break loose first, so the furthest through its fall lies on top.
        float cell = u.kind < 0.5 ? slot : textureLod(order, vec2((slot + 0.5) / (KX * N), 0.5), 0.0).x;
        vec2 c = vec2(mod(cell, KX) + X0, floor(cell / KX));
        vec4 sh = cellData(c, 1.0);
        vec4 more = cellData(c, 2.0);
        vec2 pivot = sh.xy;
        float dur = abs(sh.w);
        float tau = t - abs(sh.z);
        float k = tau / dur;
        float extent = length(pivot - u.center) * TAU / N * (sh.w < 0.0 ? 1.6 : 1.0);
        float s;
        vec2 off = shardOffset(pivot, k, s);
        if (u.kind < 0.5) {
            // The dust a shard crumbles into, from about half the shards, drifting up.
            float kd = (tau - dur * 0.62) / 0.55;
            if (sh.z < 0.0 && kd > 0.0 && kd < 1.0) {
                float radius = min(extent * 0.42, 44.0) * (0.7 + 0.6 * sqrt(kd));
                mid = pivot + off * 0.85 - vec2(0.0, 20.0 * kd);
                // A puff reaches at most 1.65 times its radius.
                h = radius * 1.65 + 2.0;
                a0 = vec4(mid, radius, more.y);
                a1 = vec4(kd, 0.0, 0.0, 0.0);
            }
        } else if (tau >= 0.0 && k < 1.0 && c.x == floor(more.z)) {
            // A shard is drawn once, from its first cell; it reaches no further from
            // its pivot than 1.5 times its extent and 6 px, scaled.
            mid = pivot + off;
            h = s * (extent * 1.5 + 6.0) + 1.0;
            a0 = vec4(pivot, off);
            a1 = vec4(s, -more.x * k * k, k, extent);
            a2 = vec4(more.zw, 0.0, 0.0);
        }
    } else {
        // A chip of the old wallpaper flung up from the cracks as the front passes.
        float gw = u.chipGrid.x;
        vec2 c = vec2(mod(slot, gw), floor(slot / gw)) + CHIP_X0;
        vec4 chip = chipData(c, 0.0);
        float age = t - chip.z;
        float life = 0.75;
        if (chip.w > 0.0 && age >= 0.0 && age <= life) {
            vec4 motion = chipData(c, 1.0);
            mid = chip.xy + motion.xy * age + vec2(0.0, 750.0) * age * age;
            // A chip reaches at most 1.22 times its size from its middle.
            h = chip.w * 1.25 + 3.0;
            float fade = smoothstep(0.0, 0.06, age) * (1.0 - smoothstep(0.7, 1.0, age / life));
            a0 = vec4(mid, chip.w, age * motion.z);
            a1 = vec4(chipData(c, 2.0).rgb, fade);
        }
    }

    // A diamond reaches its points sqrt(2) further than the circle it holds.
    h *= 1.4143;
    vec2 corner = role < 0.5 ? vec2(0.0, -1.0) : (role < 1.5 ? vec2(qt_MultiTexCoord0.x * 2.0 - 1.0, 0.0) : vec2(0.0, 1.0));
    p = h > 0.0 ? mid + corner * h : vec2(-64.0);
    gl_Position = u.qt_Matrix * vec4(p, 0.0, qt_Vertex.w);
}
