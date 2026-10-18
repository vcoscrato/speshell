#version 440
#extension GL_GOOGLE_include_directive : enable
// Low-resolution flame simulation. Feeds back into itself every step of `dt` s:
// R = fuel density, G = heat. Velocity is buoyancy plus curl-noise turbulence.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
    float dt;
    float emit;        // 0..1 strength of the simmering rim around the panel
    float frontFuel;   // 0..1 strength of flames along the burn front
    vec2 resolution;   // screen size in px
    vec4 panel;        // panel rect in px
    float radius;
    vec2 origin;
    float burnR;
    float fieldScale;
    float clearBehind; // 1: no flames over the panel once the front has passed
} u;
layout(binding = 1) uniform sampler2D state;
#include "../../lib/common.glsl"

void main() {
    vec2 uv = qt_TexCoord0;
    vec2 p = uv * u.resolution;
    vec2 c = u.panel.xy + u.panel.zw * 0.5;

    vec4 here = texture(state, uv);
    vec2 v = vec2(0.0, -100.0 - 230.0 * here.g)
           + curl(p / 190.0, u.time * 0.5) * (60.0 + 90.0 * (1.0 - here.g))
           + curl(p / 70.0, u.time * 1.4) * 60.0 * (1.2 - here.g);
    vec4 prev = texture(state, uv - v * u.dt / u.resolution);

    // Linear burn-out erodes thin edges first, so tongues taper to points.
    float dens = max(prev.r * exp(-0.6 * u.dt) - 1.15 * u.dt, 0.0);
    float heat = max(prev.g - 2.2 * u.dt, 0.0);

    // Rim fuel: discrete wandering jets along the outline, hottest on top.
    float d = sdRoundRect(p - c, u.panel.zw * 0.5, u.radius);
    float rim = smoothstep(14.0, 3.0, d) * step(0.0, d);
    float topBias = mix(0.5, 1.0, smoothstep(c.y, u.panel.y, p.y));
    float s = p.x + (p.y - u.panel.y) * sign(p.x - c.x);
    float jets = vnoise(vec2(s / 20.0, u.time * 1.1)) * 0.75 + vnoise(vec2(s / 9.0, u.time * 2.6)) * 0.25;
    jets = smoothstep(0.40, 0.68, jets);
    float src = rim * topBias * jets * u.emit;

    // Front fuel: flames lick up off the burning edge as it sweeps the panel.
    // Fuel patches sit still on screen and catch as the front reaches them.
    float bf = burnField(p, u.origin, u.fieldScale);
    float onFront = smoothstep(26.0, 4.0, abs(bf - u.burnR + 6.0)) * step(d, 6.0);
    float patches = vnoise(p / 26.0 + vec2(0.0, u.time * 0.9)) * 0.7 + vnoise(p / 11.0 - vec2(0.0, u.time * 2.0)) * 0.3;
    float frontJets = smoothstep(0.38, 0.68, patches);
    src = max(src, onFront * (0.35 + 0.65 * frontJets) * u.frontFuel);

    dens = max(dens, src);
    heat = max(heat, src);
    // Nothing burns over panel areas the front passed a while ago.
    // Faded rather than cut: a hard cut at quarter resolution shows as stair steps.
    float behind = u.clearBehind * step(d, 0.0) * smoothstep(35.0, 75.0, u.burnR - bf);
    dens *= 1.0 - behind;
    heat *= 1.0 - behind;

    fragColor = vec4(dens, heat, 0.0, 1.0);
}
