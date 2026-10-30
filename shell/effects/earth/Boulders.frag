#version 440
#extension GL_GOOGLE_include_directive : enable
// Behind the boulders held aloft around the open launcher, broad faint bands of dust
// circle far out, ragged and soft at the edges. The stones, the boulders, and the
// motes are drawn each on a quad of its own (Boulders.vert), so that a pixel pays only
// for the pieces over it; these bands go round the whole panel.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
#include "Boulders.glsl"

void main() {
    vec2 p = u.rect.xy + qt_TexCoord0 * u.rect.zw;
    vec2 c0 = panelCenter();
    vec2 h = u.panel.zw * 0.5;
    vec3 col = vec3(0.0);
    float a = 0.0;
    float hold = held();

    for (int j = 0; j < 2; j++) {
        float fj = float(j);
        float dist = 95.0 + 70.0 * fj;
        vec2 hh = h + dist;
        float rr = min(10.0 + dist * 1.8, min(hh.x, hh.y));
        vec2 rel = p - c0;
        float d = sdRoundRect(rel, hh, rr);
        // The ribbon strays at most 55 px from its line (wave, width, and ragged edge).
        if (abs(d) > 60.0)
            continue;
        float P = rrPerimeter(hh, rr);
        float s = rrArc(rel, hh, rr);
        float behind = mod(-u.time * (26.0 - 8.0 * fj) + fj * P * 0.5 - s, P);
        float len = P * 0.42 * hold;
        if (behind > len)
            continue;
        float tt = behind / max(len, 1.0);
        // Both fit the lap, so the ribbon meets itself where s wraps: whole waves,
        // and the noise cross-fading into its own start over the last stretch (the
        // only place that needs the second lookup).
        float laps = max(1.0, floor(P / 1070.0 + 0.5));
        float wave = 22.0 * sin(6.2831853 * laps * s / P - u.time * 0.4 + fj * 2.4);
        float wrap = smoothstep(P - 160.0, P, s);
        vec2 rq = vec2(s / 40.0 + u.time * 0.3, d / 18.0 + fj * 5.0);
        float rag = fbm(rq);
        if (wrap > 0.0)
            rag = mix(rag, fbm(rq - vec2(P / 40.0, 0.0)), wrap);
        rag = (rag - 0.5) * 22.0;
        float w = (16.0 + 8.0 * fj) * pow(sin(3.14159265 * tt), 0.7);
        float f = w + rag - abs(d - wave);
        if (f <= 0.0)
            continue;
        // Thinning out over its last few px, and thicker and thinner along it, as dust
        // is; the same cross-fade keeps that seamless where s wraps.
        vec2 dq = vec2(s / 90.0 - u.time * 0.15, d / 30.0 + fj * 3.0);
        float thick = fbm(dq);
        if (wrap > 0.0)
            thick = mix(thick, fbm(dq - vec2(P / 90.0, 0.0)), wrap);
        over(col, a, u.cLight.rgb, smoothstep(0.0, 6.0, f) * smoothstep(0.2, 0.7, thick) * (0.15 - 0.04 * fj));
    }

    fragColor = vec4(col, a) * shown(p) * u.qt_Opacity;
}
