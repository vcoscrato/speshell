#version 440
#extension GL_GOOGLE_include_directive : enable
// Works out where the water held round the open launcher is this frame, once, into a
// float table that LauncherTransition.held.frag reads: a texel for each of MIST glints
// and then ORBS orbs, holding in its first row where it is (px), its size, and for a
// glint how bright it is, for an orb how far it has gathered; and in its second, for
// an orb, its depth and the seed of its wobble.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
    vec4 panel;        // panel rect on screen (px)
    float radius;      // panel corner radius (px)
    float flow;        // 0 nothing .. 1 all of it, in turn
} u;
#include "../common/common.glsl"
#include "Held.glsl"

void main() {
    float slot = floor(qt_TexCoord0.x * float(MIST + ORBS));
    bool second = qt_TexCoord0.y > 0.5;
    vec2 c = u.panel.xy + u.panel.zw * 0.5;
    vec2 h = u.panel.zw * 0.5;
    float t = u.time;

    if (slot < float(MIST)) {
        // Mist: tiny glints drifting round.
        float fi = slot;
        vec3 r = vec3(hash(vec2(fi, 1.3)), hash(vec2(fi, 4.1)), hash(vec2(fi, 9.7)));
        float dist = mix(18.0, 210.0, r.x);
        float P = rrPerimeter(h + dist, u.radius + dist);
        vec2 q = c + orbit(h, dist, r.y * P + t * mix(40.0, 95.0, r.z));
        q.y += 10.0 * sin(t * (0.7 + r.z) + fi);
        float twinkle = pow(0.5 + 0.5 * sin(t * (1.3 + 1.7 * r.y) + fi * 2.3), 3.0);
        float size = mix(1.0, 2.3, r.z) * u.flow;
        fragColor = second ? vec4(0.0) : vec4(q, size, twinkle * mix(0.45, 0.9, r.z));
    } else {
        // Orbs: held water drifting round; nearer ones bigger and quicker.
        float fi = slot - float(MIST);
        float z = hash(vec2(fi, 21.7));
        float seed = hash(vec2(fi, 3.9)) * 6.2831853;
        float dist = mix(36.0, 175.0, hash(vec2(fi, 11.3)));
        float P = rrPerimeter(h + dist, u.radius + dist);
        vec2 q = c + orbit(h, dist, fi / float(ORBS) * P + t * mix(16.0, 48.0, z));
        float size = mix(4.5, 20.0, z * z);
        q.y += 6.0 * sin(t * 1.25 + seed) * (0.5 + z);
        // Gathers in turn as the streams form and drains first when they go.
        float appear = smoothstep(0.0, 1.0, clamp(u.flow * 1.7 - 0.07 * fi, 0.0, 1.0));
        fragColor = second ? vec4(z, seed, 0.0, 0.0) : vec4(q, size, appear);
    }
}
