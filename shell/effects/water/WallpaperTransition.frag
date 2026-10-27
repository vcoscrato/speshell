#version 440
#extension GL_GOOGLE_include_directive : enable
// A drop lands in the middle, seen from above: a ragged crown splashes out from it,
// its spikes flinging droplets that ring where they land, and a jet leaps up and
// falls back, sending a second, fainter ring after the first. The first ring spreads
// out with the new wallpaper inside it, still rippling, and the old one outside,
// bulging as the ring nears; its front bends the images most. The ring's slopes are
// shaded in flat light and dark bands.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 resolution;
    vec2 center;
    float ring;        // px, front radius
    float strength;    // px of displacement at the front
    float calm;        // 0..1 how far the trailing ripples have died down
    float age;         // s since the drop landed
    vec4 cLight;
    vec4 cDark;
    vec4 cWater;
} u;
layout(binding = 1) uniform sampler2D outgoingTex;
layout(binding = 2) uniform sampler2D incomingTex;
#include "../common/common.glsl"

const float TAU = 6.2831853;
const int FLUNG = 12;

// Water seen from above in flat bands over `col`: a dark edge inside its outline,
// the body, and a glint along the edge on the side toward the upper left. `d` > 0
// inside, so a bit that shrinks to nothing leaves nothing behind; `lit` -1..1.
vec3 waterBits(vec3 col, float d, float lit, float S) {
    col = mix(col, u.cDark.rgb, cover(d - 0.5) * 0.8);
    col = mix(col, u.cWater.rgb, cover(d - 1.6));
    return mix(col, u.cLight.rgb, cover(d - 1.6) * cover(1.6 + 1.8 * S - d) * step(0.25, lit));
}

void main() {
    vec2 p = qt_TexCoord0 * u.resolution;
    vec2 rel = p - u.center;
    float r = max(length(rel), 1.0);
    vec2 dir = rel / r;
    float S = u.resolution.y / 1080.0;
    float t = u.age;
    float wob = (vnoise(dir * 2.0 + 5.0) - 0.5) * 24.0;
    float d = r - u.ring + wob;                            // < 0 inside the ring

    // Height of the water surface: a steep crest at the front and decaying ripples
    // behind, then the jet's fainter ring following it out.
    float lambda = 64.0;
    float front = exp(-pow(d / 30.0, 2.0));
    float trail = step(d, 0.0) * exp(d / 190.0) * (1.0 - u.calm);
    float ring2 = max(t - 0.42, 0.0) * 780.0 * S;
    float d2 = r - ring2 + wob * 0.6;
    float second = exp(-pow(d2 / 22.0, 2.0)) * step(0.42, t) * clamp(1.4 - t, 0.0, 1.0) * 0.55;
    float h = front * cos(d / lambda * 3.1415927) + trail * sin(d / lambda * TAU)
            + second * cos(d2 / 40.0 * 3.1415927);
    float slope = -front * sin(d / lambda * 3.1415927) * 1.2 + trail * cos(d / lambda * TAU)
                - second * sin(d2 / 40.0 * 3.1415927);
    vec2 uv = (p - dir * h * u.strength) / u.resolution;

    float aa = clamp(fwidth(d), 1e-3, 1.5);
    float inner = smoothstep(aa, -aa, d);
    vec4 col = mix(texture(outgoingTex, uv), texture(incomingTex, uv), inner);

    // Flat shading: lit slopes, shaded slopes, and a bright crest line.
    float energy = max(max(front, trail), second);
    col.rgb = mix(col.rgb, u.cLight.rgb, cover(slope - 0.45) * 0.35 * energy);
    col.rgb = mix(col.rgb, u.cDark.rgb, cover(-slope - 0.45) * 0.3 * energy);
    col.rgb = mix(col.rgb, u.cLight.rgb, cover(3.0 - abs(d + 4.0)) * 0.85);
    col.rgb = mix(col.rgb, u.cLight.rgb, cover(1.6 - abs(d2 + 3.0)) * 0.5 * second / 0.55);

    // ── The splash, only near the middle and only while it lasts ──
    // Its scale: large enough to read on a wallpaper seen across the room.
    float K = 1.55 * S;
    if (t < 1.1 && r < 330.0 * K) {
        float body = -1e3;
        // The crown: a ragged rim thrown outward, thinning as it goes, with spikes
        // standing out of it unevenly, each tipped with a drop.
        float ca = smoothstep(0.0, 0.38, t);
        float rc = K * mix(8.0, 74.0, 1.0 - pow(1.0 - ca, 2.0));
        float rim = K * mix(7.0, 2.6, ca) * (1.0 - smoothstep(0.3, 0.46, t));
        float ang = atan(rel.y, rel.x);
        float rag = (vnoise(dir * 1.6 + 4.0) - 0.5) * 9.0 * K;
        body = max(body, rim - abs(r - rc - rag));
        float N = 13.0;
        float cell = floor(ang / TAU * N + 0.5);
        for (int k = -1; k <= 1; k++) {
            float ci = cell + float(k);
            float hi = hash(vec2(ci, 3.0));
            float a = (ci + (hi - 0.5) * 0.6) / N * TAU;
            vec2 sd = vec2(cos(a), sin(a));
            float len = K * mix(8.0, 26.0, hash(vec2(ci, 7.0))) * sin(3.1415927 * clamp(t / 0.4, 0.0, 1.0));
            vec2 base = u.center + sd * (rc + rag * 0.5);
            float sp = sdSeg(p, base, base + sd * len);
            float wS = K * mix(3.0, 1.6, clamp(dot(p - base, sd) / max(len, 1.0), 0.0, 1.0))
                     * (1.0 - smoothstep(0.28, 0.4, t));
            body = max(body, wS - sp);
            float tipR = K * 3.4 * smoothstep(0.04, 0.12, t) * (1.0 - smoothstep(0.3, 0.42, t)) * mix(0.7, 1.1, hi);
            body = max(body, tipR - length(p - base - sd * (len + 3.0 * K)));
        }

        // The jet: leaping up toward us, so it swells, then falls back and shrinks.
        float ja = clamp((t - 0.12) / 0.4, 0.0, 1.0);
        float jr = K * 17.0 * sin(3.1415927 * ja) * (1.0 + 0.08 * sin(ang * 3.0 + t * 20.0));
        body = max(body, jr - r);

        // Droplets flung off the crown's spikes fly out, rising and falling, and ring
        // where they land.
        float rings = 0.0;
        for (int i = 0; i < FLUNG; i++) {
            float fi = float(i);
            vec3 rnd = vec3(hash(vec2(fi, 11.0)), hash(vec2(fi, 12.0)), hash(vec2(fi, 13.0)));
            float a = (fi + rnd.x * 0.8) / float(FLUNG) * TAU;
            vec2 sd = vec2(cos(a), sin(a));
            float t0 = 0.05 + 0.08 * rnd.y;
            float fly = mix(0.28, 0.46, rnd.z);
            float f = (t - t0) / fly;
            float dist = K * mix(110.0, 270.0, rnd.y * rnd.z + 0.3 * rnd.x);
            if (f > 0.0 && f < 1.0) {
                vec2 q = u.center + sd * (K * 30.0 + dist * f);
                float size = K * mix(3.0, 5.5, rnd.x) * (1.0 + 0.5 * sin(3.1415927 * f));
                vec2 o = p - q;
                // Drawn out along the way it flies.
                float dd = size - length(vec2(dot(o, sd) / 1.5, dot(o, vec2(-sd.y, sd.x))));
                body = max(body, dd);
            } else if (f >= 1.0) {
                float since = (f - 1.0) * fly;
                vec2 q = u.center + sd * (K * 30.0 + dist);
                float rr = K * (3.0 + 70.0 * since);
                float fade = clamp(1.0 - since / 0.45, 0.0, 1.0);
                rings = max(rings, cover(S * 1.2 - abs(length(p - q) - rr)) * fade * fade);
            }
        }
        col.rgb = mix(col.rgb, u.cLight.rgb, rings * 0.7);
        col.rgb = waterBits(col.rgb, body, dot(dir, vec2(-0.6, -0.8)), S);
        // A bright glint on the jet.
        col.rgb = mix(col.rgb, u.cLight.rgb, cover(jr * 0.3 - 0.5 - length(rel + vec2(0.3, 0.35) * jr)));
    }
    fragColor = col * u.qt_Opacity;
}
