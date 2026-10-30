#version 440
#extension GL_GOOGLE_include_directive : enable
// Water held in the air around the open launcher, behind the two streams: faint
// broad currents circling far out, wobbling orbs drifting round at different
// depths (the far ones small, faint, and slow), and a fine glittering mist. All of
// it travels clockwise with the streams and keeps off the panel.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
    vec4 rect;         // this item's rect on screen (px)
    vec4 panel;        // panel rect on screen (px)
    float radius;      // panel corner radius (px)
    float flow;        // 0 nothing .. 1 all of it, in turn
    vec4 cDeep;
    vec4 cMid;
    vec4 cLight;
    vec4 cFoam;
} u;
layout(binding = 1) uniform sampler2D motes;  // LauncherTransition.motes.frag
#include "../common/common.glsl"
#include "Held.glsl"

const int CURRENTS = 3;

// Premultiplied "over" of a flat color with coverage k.
void over(inout vec3 col, inout float a, vec3 c, float k) {
    col = mix(col, c, k);
    a = mix(a, 1.0, k);
}

void main() {
    vec2 p = u.rect.xy + qt_TexCoord0 * u.rect.zw;
    vec2 c = u.panel.xy + u.panel.zw * 0.5;
    vec2 h = u.panel.zw * 0.5;
    vec2 rel = p - c;
    float t = u.time;
    vec3 col = vec3(0.0);
    float a = 0.0;
    // Nothing over the panel itself.
    float off = cover(sdRoundRect(rel, h, u.radius) - 3.0);
    if (sdRoundRect(rel, h, u.radius) < 1.0) {
        fragColor = vec4(0.0);
        return;
    }

    // ── Currents: broad translucent ribbons, fainter further out ──
    for (int j = 0; j < CURRENTS; j++) {
        float fj = float(j);
        float dist = 70.0 + 48.0 * fj;
        vec2 hh = h + dist;
        // Rounder than the panel, so the currents read as orbits, not outlines.
        float rr = min(u.radius + dist * 1.8, min(hh.x, hh.y));
        float d = sdRoundRect(rel, hh, rr);
        if (abs(d) > 70.0)
            continue;
        float P = rrPerimeter(hh, rr);
        float s = rrArc(rel, hh, rr);
        float head = t * (75.0 - 14.0 * fj) + fj * P * 0.37;
        float len = P * (0.3 - 0.04 * fj) * u.flow;
        float behind = mod(head - s, P);
        if (behind > len)
            continue;
        float tt = behind / max(len, 1.0);
        // Drifts in and out along its length, with ripples running down it. The
        // drift fits whole waves into a lap, so it meets itself where s wraps.
        float laps = max(1.0, floor(P / 940.0 + 0.5));
        float wave = 24.0 * sin(6.2831853 * laps * s / P + t * 0.45 + fj * 2.1) + 8.0 * sin(behind / 64.0 - t * 1.4 + fj * 2.0)
                   + 4.0 * sin(behind / 23.0 + t * 0.9);
        float w = (7.0 + 3.0 * fj) * pow(sin(3.14159265 * tt), 0.6);
        float f = w - abs(d - wave);
        float k = cover(f) * (0.17 - 0.04 * fj);
        // A brighter thread rides the ribbon's inner edge.
        float thread = cover(1.1 - abs(d - wave + w * 0.55)) * step(0.15, tt) * step(tt, 0.85) * 0.22;
        over(col, a, u.cLight.rgb, max(k, thread * cover(f)));
    }

    // ── Mist: tiny glints drifting round ──
    for (int i = 0; i < MIST; i++) {
        vec4 m = texture(motes, vec2((float(i) + 0.5) / float(MIST + ORBS), 0.25));
        float dm = length(p - m.xy);
        if (dm > m.z + 2.0)
            continue;
        over(col, a, u.cFoam.rgb, cover(m.z - dm) * m.w);
    }

    // ── Orbs: held water, wobbling as it drifts; nearer ones bigger and quicker ──
    for (int i = 0; i < ORBS; i++) {
        float x = (float(i + MIST) + 0.5) / float(MIST + ORBS);
        vec4 m = texture(motes, vec2(x, 0.25));
        vec2 q = m.xy;
        float size = m.z;
        float appear = m.w;
        vec2 o = p - q;
        if (dot(o, o) > size * size * 2.0)
            continue;
        vec2 zs = texture(motes, vec2(x, 0.75)).xy;
        float z = zs.x, seed = zs.y;
        float ang = atan(o.y, o.x);
        float R = size * appear * (1.0 + 0.1 * sin(2.0 * ang + t * 3.1 + seed)
                                       + 0.06 * sin(3.0 * ang - t * 2.3 + seed * 2.0));
        float body = R - length(o);
        vec2 n = o / max(size, 1.0);
        // Lit as clear water from the top left: a dark crescent on the far side, the
        // disc less one moved toward the light, so it curves and tapers to points;
        // inside it, the light that came through gathers in a bright arc.
        vec2 toLight = vec2(-0.55, -0.83);
        float lr = max(R, 0.5);
        float far = length(o - toLight * lr * 0.38) - lr * 0.86;
        vec3 w = u.cMid.rgb;
        w = mix(w, u.cDeep.rgb, cover(far));
        float caustic = cover(body - 1.6) * cover(lr * 0.16 * smoothstep(0.25, 0.9, dot(n, -toLight) * size / lr) - (body - 1.6));
        w = mix(w, mix(u.cLight.rgb, u.cFoam.rgb, 0.4), caustic * step(6.0, size) * 0.85);
        // A glint toward the light, and a smaller one in the arc.
        w = mix(w, u.cFoam.rgb, cover(0.2 - length(n - vec2(-0.36, -0.4))) * step(5.5, size));
        w = mix(w, u.cFoam.rgb, cover(0.07 - length(n - vec2(0.38, 0.5))) * step(10.0, size));
        vec3 orb = mix(mix(u.cDeep.rgb, u.cMid.rgb, 0.3), w, cover(body - 1.2));
        over(col, a, orb, cover(body) * mix(0.55, 1.0, z));
    }

    fragColor = vec4(col, a) * off * u.qt_Opacity;
}
