#version 440
#extension GL_GOOGLE_include_directive : enable
// Works out where the streams' droplets are this frame, once, into a float table that
// LauncherTransition.stream.frag reads: a texel each for STREAMS * DROPS droplets,
// holding in its first row where the droplet is (px) and its radius (0 when it is not
// showing), and in its second its velocity (px/s), by which it stretches.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
    vec4 panel;        // panel rect on screen (px)
    float radius;      // panel corner radius (px)
    float gap;         // px between the panel border and the streams' spine
    float flow;        // 0 no water .. 1 full streams
    float speed;       // mean px/s along the border
    float tubeWidth;   // half-width (px)
} u;
#include "../common/common.glsl"
#include "Streams.glsl"

void main() {
    float slot = floor(qt_TexCoord0.x * float(STREAMS * DROPS));
    bool second = qt_TexCoord0.y > 0.5;
    float fi = floor(slot / float(DROPS));
    int m = int(slot - fi * float(DROPS));
    vec2 c = u.panel.xy + u.panel.zw * 0.5;
    vec2 h = u.panel.zw * 0.5 + u.gap;
    float r = u.radius + u.gap;
    float P = rrPerimeter(h, r);
    float t = u.time;
    float w0 = u.tubeWidth * mix(0.5, 1.0, u.flow);
    vec2 hv = streamHead(fi, t, P);
    float vel = clamp(hv.y, 30.0, 1.3 * u.speed);
    float len = P * 0.27 * u.flow * mix(0.65, 1.0, clamp(hv.y / u.speed, 0.0, 1.6));
    vec2 dp = vec2(0.0), v = vec2(0.0);
    float size = 0.0;

    if (m < 12) {
        // Where a stream rounds a corner, droplets keep going straight and fly off.
        int j = m / 3;
        float fj = float(j), fk = float(m - j * 3);
        float a = h.x - r, b = h.y - r, q = 1.5707963 * r;
        vec2 sg = vec2(j == 0 || j == 1 ? 1.0 : -1.0, j == 0 || j == 3 ? -1.0 : 1.0);
        vec2 nrm = sg * 0.7071068;
        vec2 tan_ = vec2(-nrm.y, nrm.x);              // clockwise on screen, like s
        vec2 cp = c + vec2(a, b) * sg + nrm * r;
        float sc = j == 0 ? 2.0 * a + 0.5 * q
           : j == 1 ? 2.0 * a + 1.5 * q + 2.0 * b
           : j == 2 ? 4.0 * a + 2.5 * q + 2.0 * b
                    : 4.0 * a + 3.5 * q + 4.0 * b;
        float past = hv.x - sc;
        float lap = floor(past / P);
        float sinceHead = (past - lap * P) / vel;    // s since this stream's head rounded it
        vec3 rnd = vec3(hash(vec2(lap * 4.0 + fj, fi * 7.0 + fk)),
                        hash(vec2(lap * 4.0 + fj + 0.5, fi * 7.0 + fk + 3.1)),
                        hash(vec2(lap * 4.0 + fj + 0.25, fi * 7.0 + fk + 5.7)));
        // Most fly off as the head goes round; some later, from the body.
        float tau = sinceHead - rnd.x * rnd.x * len / vel * 0.7;
        float life = 0.55 + 0.3 * rnd.y;
        if (tau >= 0.0 && tau <= life) {
            float ang = mix(0.08, 0.55, rnd.z);
            vec2 v0 = (tan_ * cos(ang) + nrm * sin(ang)) * vel * mix(0.7, 1.15, rnd.y);
            float drag = 3.2;
            float e = exp(-drag * tau);
            dp = cp + v0 * (1.0 - e) / drag + vec2(0.0, 0.5 * GRAVITY * tau * tau);
            v = v0 * e + vec2(0.0, GRAVITY * tau);
            size = mix(2.2, 4.6, rnd.z) * sqrt(1.0 - tau / life) * u.flow;
        }
    } else if (m < 15) {
        // Beads breaking off the tail lag behind, drift outward, and fall.
        float fk = float(m - 12);
        float life = 0.9;
        float age = fract(t / 0.75 + fk / 3.0 + fi * 0.37);
        float tau = age * life;
        float drag = 2.4;
        float lag = vel * (tau - (1.0 - exp(-drag * tau)) / drag);
        float sd = hv.x - len - 6.0 - lag;
        vec2 bp = rrPoint(sd, h, r);
        vec2 dir = normalize(rrPoint(sd + 2.0, h, r) - rrPoint(sd - 2.0, h, r));
        vec2 out_ = vec2(dir.y, -dir.x);
        float seed = floor(t / 0.75 + fk / 3.0 + fi * 0.37);
        dp = c + bp + out_ * (u.gap * 0.3 + 30.0 * tau * hash(vec2(seed, fi + fk)))
           + vec2(0.0, 0.5 * GRAVITY * tau * tau);
        v = dir * vel * exp(-drag * tau) + vec2(0.0, GRAVITY * tau);
        size = mix(2.0, 3.6, hash(vec2(seed + 0.5, fi + fk))) * smoothstep(0.0, 0.12, age) * (1.0 - age * age) * u.flow;
    } else {
        // Spray flung off the head, mostly outward, falling behind it.
        float fk = float(m - 15);
        vec2 hp = rrPoint(hv.x, h, r);
        vec2 hdir = normalize(rrPoint(hv.x + 2.0, h, r) - rrPoint(hv.x - 2.0, h, r));
        vec2 hout = vec2(hdir.y, -hdir.x);
        float cyc = t * (2.2 + 0.7 * hash(vec2(fk, fi + 8.0))) + hash(vec2(fk, fi + 5.0));
        float age = fract(cyc);
        float seed = floor(cyc);
        vec3 rnd = vec3(hash(vec2(seed, fi * 3.0 + fk + 9.1)), hash(vec2(seed + 3.3, fi * 3.0 + fk)),
                        hash(vec2(fi * 3.0 + fk, seed + 6.2)));
        float side = rnd.y < 0.8 ? 1.0 : -0.6;
        dp = c + hp - hdir * (0.3 * w0 + age * (10.0 + 30.0 * rnd.x))
           + hout * side * (0.8 * w0 + age * (8.0 + 22.0 * rnd.y))
           + vec2(0.0, 0.5 * GRAVITY * age * age * 0.1);
        v = hdir * vel * 0.6;
        size = mix(1.4, 3.0, rnd.z) * smoothstep(0.0, 0.12, age) * (1.0 - age) * u.flow;
    }
    fragColor = second ? vec4(v, 0.0, 1.0) : vec4(dp, max(size, 0.0), 1.0);
}
