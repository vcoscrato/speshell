#version 440
#extension GL_GOOGLE_include_directive : enable
// Water held while the launcher is open: two streams chase each other around the
// panel just outside its border. Each one surges and slackens, stretching thin when
// fast and bunching up when slow; waves run down it from the head and flail its tail,
// which swells into beads but stays one stream; it hugs the panel where it swings inward and merges with
// the other stream when they meet. Droplets fly off straight where a stream rounds a
// corner and drop from its tail. Shaded in flat bands, with highlights and bubbles
// carried along with the water.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
    vec4 rect;         // this item's rect on screen (px)
    vec4 panel;        // panel rect on screen (px)
    float radius;      // panel corner radius (px)
    float gap;         // px between the panel border and the streams' spine
    float flow;        // 0 no water .. 1 full streams
    float speed;       // mean px/s along the border
    float tubeWidth;   // half-width (px)
    vec4 cDeep;
    vec4 cMid;
    vec4 cLight;
    vec4 cFoam;
} u;
#include "../common/common.glsl"

const int STREAMS = 2;
const float GRAVITY = 240.0;   // px/s², pulling droplets down the screen

// Smooth union of two "inside" fields (> 0 inside): water merging under surface tension.
float smax(float a, float b, float k) {
    float h = clamp(0.5 + 0.5 * (a - b) / k, 0.0, 1.0);
    return mix(b, a, h) + k * h * (1.0 - h);
}

// Head position along the border (px of arc) and its speed, for stream i. Each
// surges on its own rhythm, so the streams close in on each other and fall apart.
vec2 streamHead(float fi, float t, float P) {
    float w1 = 0.55 + 0.21 * fi, w2 = 1.31 - 0.17 * fi;
    float a1 = 0.48 * u.speed / w1, a2 = 0.22 * u.speed / w2;
    float ph = fi * 2.4;
    float head = t * u.speed + fi * P / float(STREAMS) + a1 * sin(w1 * t + ph) + a2 * sin(w2 * t + ph * 1.7);
    float vel = u.speed + a1 * w1 * cos(w1 * t + ph) + a2 * w2 * cos(w2 * t + ph * 1.7);
    return vec2(head, vel);
}

// A droplet at q of radius `size`, stretched along its velocity `v` (px/s).
float droplet(vec2 p, vec2 q, vec2 v, float size) {
    float sp = length(v);
    vec2 dir = sp > 1.0 ? v / sp : vec2(1.0, 0.0);
    float stretch = 1.0 + clamp(sp / 260.0, 0.0, 1.2);
    vec2 rel = p - q;
    vec2 loc = vec2(dot(rel, dir) / stretch, dot(rel, vec2(-dir.y, dir.x)));
    return size - length(loc);
}

void main() {
    vec2 p = u.rect.xy + qt_TexCoord0 * u.rect.zw;
    vec2 c = u.panel.xy + u.panel.zw * 0.5;
    vec2 h = u.panel.zw * 0.5 + u.gap;
    float r = u.radius + u.gap;
    float P = rrPerimeter(h, r);
    vec2 rel = p - c;
    float s = rrArc(rel, h, r);
    float d0 = sdRoundRect(rel, h, r);                    // across the spine: > 0 outside
    float t = u.time;
    float w0 = u.tubeWidth * mix(0.5, 1.0, u.flow);

    // ── The streams ──
    float field = -1e3, rimField = -1e3, n = 0.0, along = 0.0, own = 0.0, wOwn = 0.0, thickOwn = 1.0;
    for (int i = 0; i < STREAMS; i++) {
        float fi = float(i);
        vec2 hv = streamHead(fi, t, P);
        float vRel = hv.y / u.speed;                     // 1 at mean speed
        // Fast water stretches out thin; slow water bunches up thick.
        float len = P * 0.27 * u.flow * mix(0.65, 1.0, clamp(vRel, 0.0, 1.6));
        float thick = w0 * clamp(inversesqrt(max(len, 1.0) / (P * 0.27 * max(u.flow, 0.05))), 0.85, 1.25);
        // Measured from this stream's head, so nothing here breaks where s wraps.
        float behind = mod(hv.x - s, P);
        if (behind > len + 3.0 * thick)
            continue;
        float tt = behind / max(len, 1.0);               // 0 at the head .. 1 at the tail

        // Width: a round, wobbling bulb at the head tapering to the tail, where the
        // thinning stream beads up (Rayleigh–Plateau). The necks never close: cut
        // apart against the panel's straight border, the beads read as a broken line.
        float bulb = 1.0 + 0.4 * exp(-behind / (2.2 * thick)) * (1.0 + 0.3 * sin(t * 13.0 + fi * 2.0));
        // The last beads pinch off altogether, so the tail frays into drops.
        float pinch = mix(0.12, 1.0, smoothstep(0.4, 0.95, tt)) * (1.0 + 0.9 * smoothstep(0.8, 1.0, tt));
        float beadPhase = behind / 8.5 + 2.5 * vnoise(vec2(behind / 40.0, fi * 5.0 + 1.0)) - t * 4.0 + fi * 3.0;
        float beads = 1.0 - 0.5 * pinch * (0.5 + 0.5 * sin(beadPhase));
        // Swelling and slackening on two scales, unevenly, so it never reads as a tube.
        float swell = 1.0 + 0.2 * sin(behind / 41.0 + t * 2.3 + fi * 5.0)
                    + 0.3 * (vnoise(vec2(behind / 26.0 - t * 1.7, fi * 7.0 + 2.0)) - 0.5);
        float w = thick * sqrt(clamp(behind / (1.2 * thick), 0.0, 1.0))
                * pow(smoothstep(1.0, 0.3, tt), 0.65) * bulb * beads * swell;

        // Spine: waves start at the head and run down the stream, growing toward the
        // flailing tail; now and then a big one cracks down it like a whip.
        float waveSpeed = 210.0;
        float tr = t - behind / waveSpeed;               // when this bit of wave left the head
        float crack = pow(0.5 + 0.5 * sin(tr * 0.47 + fi * 2.9), 10.0);
        float amp = (2.0 + 8.0 * tt) * (1.0 + 2.2 * crack);
        float off = amp * sin((behind - waveSpeed * t) / 31.0 + fi * 1.3)
                  + (vnoise(vec2(behind / 70.0 - t * 0.9, fi * 13.0)) - 0.5) * 12.0 * (0.3 + tt);
        // Swinging inward, the water flattens against the panel instead of crossing it.
        off = max(off, w - u.gap + 2.0);
        float dd = d0 - off;

        float f = w - abs(dd);
        if (f > field) {
            n = dd / max(w, 1.0);
            along = behind;
            own = fi;
            wOwn = w;
            thickOwn = thick;
        }
        field = smax(field, f, 5.0);
        // The outline thins with the water, so pinched necks vanish instead of
        // leaving hairlines.
        rimField = smax(rimField, f + min(2.0, 0.5 * w) - 0.6, 5.0);
    }
    float inside = cover(field - 0.6);
    float rim = cover(rimField);

    // ── Droplets ──
    float drops = -1e3;
    float a = h.x - r, b = h.y - r, q = 1.5707963 * r;
    for (int i = 0; i < STREAMS; i++) {
        float fi = float(i);
        vec2 hv = streamHead(fi, t, P);
        float vel = clamp(hv.y, 30.0, 1.3 * u.speed);
        float len = P * 0.27 * u.flow * mix(0.65, 1.0, clamp(hv.y / u.speed, 0.0, 1.6));

        // Where a stream rounds a corner, droplets keep going straight and fly off.
        for (int j = 0; j < 4; j++) {
            float fj = float(j);
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
            for (int k = 0; k < 3; k++) {
                vec3 rnd = vec3(hash(vec2(lap * 4.0 + fj, fi * 7.0 + float(k))),
                                hash(vec2(lap * 4.0 + fj + 0.5, fi * 7.0 + float(k) + 3.1)),
                                hash(vec2(lap * 4.0 + fj + 0.25, fi * 7.0 + float(k) + 5.7)));
                // Most fly off as the head goes round; some later, from the body.
                float tau = sinceHead - rnd.x * rnd.x * len / vel * 0.7;
                float life = 0.55 + 0.3 * rnd.y;
                if (tau < 0.0 || tau > life)
                    continue;
                float ang = mix(0.08, 0.55, rnd.z);
                vec2 v0 = (tan_ * cos(ang) + nrm * sin(ang)) * vel * mix(0.7, 1.15, rnd.y);
                float drag = 3.2;
                float e = exp(-drag * tau);
                vec2 dp = cp + v0 * (1.0 - e) / drag + vec2(0.0, 0.5 * GRAVITY * tau * tau);
                vec2 v = v0 * e + vec2(0.0, GRAVITY * tau);
                float size = mix(2.2, 4.6, rnd.z) * sqrt(1.0 - tau / life) * u.flow;
                drops = max(drops, droplet(p, dp, v, size));
            }
        }

        // Beads breaking off the tail lag behind, drift outward, and fall.
        for (int k = 0; k < 3; k++) {
            float fk = float(k);
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
            vec2 dp = c + bp + out_ * (u.gap * 0.3 + 30.0 * tau * hash(vec2(seed, fi + fk)))
                    + vec2(0.0, 0.5 * GRAVITY * tau * tau);
            vec2 v = dir * vel * exp(-drag * tau) + vec2(0.0, GRAVITY * tau);
            float size = mix(2.0, 3.6, hash(vec2(seed + 0.5, fi + fk))) * smoothstep(0.0, 0.12, age) * (1.0 - age * age) * u.flow;
            drops = max(drops, droplet(p, dp, v, size));
        }

        // Spray flung off the head, mostly outward, falling behind it.
        vec2 hp = rrPoint(hv.x, h, r);
        vec2 hdir = normalize(rrPoint(hv.x + 2.0, h, r) - rrPoint(hv.x - 2.0, h, r));
        vec2 hout = vec2(hdir.y, -hdir.x);
        for (int k = 0; k < 3; k++) {
            float fk = float(k);
            float cyc = t * (2.2 + 0.7 * hash(vec2(fk, fi + 8.0))) + hash(vec2(fk, fi + 5.0));
            float age = fract(cyc);
            float seed = floor(cyc);
            vec3 rnd = vec3(hash(vec2(seed, fi * 3.0 + fk + 9.1)), hash(vec2(seed + 3.3, fi * 3.0 + fk)),
                            hash(vec2(fi * 3.0 + fk, seed + 6.2)));
            float side = rnd.y < 0.8 ? 1.0 : -0.6;
            vec2 dp = c + hp - hdir * (0.3 * w0 + age * (10.0 + 30.0 * rnd.x))
                    + hout * side * (0.8 * w0 + age * (8.0 + 22.0 * rnd.y))
                    + vec2(0.0, 0.5 * GRAVITY * age * age * 0.1);
            float size = mix(1.4, 3.0, rnd.z) * smoothstep(0.0, 0.12, age) * (1.0 - age) * u.flow;
            drops = max(drops, droplet(p, dp, hdir * vel * 0.6, size));
        }
    }
    float dropIn = cover(drops), dropRim = cover(drops + 1.5);

    // ── Shading: flat bands across the tube ──
    vec3 col = u.cMid.rgb;
    col = mix(col, u.cDeep.rgb, cover(n - 0.38));         // the outer side is in shade
    col = mix(col, u.cLight.rgb, cover(-n - 0.12) * cover(0.86 + n));
    // Highlight streaks and bubbles ride along with the water.
    // Each streak swells and narrows to a point along its length.
    float streak = 0.2 * smoothstep(0.45, 0.75, vnoise(vec2(along / 19.0, own * 9.0)));
    col = mix(col, u.cFoam.rgb, cover(streak - 0.03 - abs(n + 0.48 + 0.14 * sin(along / 23.0))));
    vec2 id = vec2(floor(along / 15.0), own);
    vec2 bub = vec2((fract(along / 15.0) - 0.5) * 15.0, (n - (hash(id) - 0.5) * 0.9) * wOwn);
    float bubble = step(0.7, hash(id + 3.3)) * step(5.0, wOwn);
    col = mix(col, u.cFoam.rgb, bubble * cover(1.7 - length(bub)));
    // Foam on the leading face of each head.
    col = mix(col, u.cFoam.rgb, cover(0.75 * thickOwn - along - 3.0 * n * n) * cover(0.8 - abs(n)));

    vec3 dropCol = mix(u.cDeep.rgb * 0.7, u.cLight.rgb, dropIn);
    vec3 outCol = mix(u.cDeep.rgb * 0.7, col, inside);
    float waterA = rim;
    outCol = mix(dropCol, outCol, waterA);
    float alpha = max(waterA, dropRim);
    fragColor = vec4(outCol * alpha, alpha) * u.qt_Opacity;
}
