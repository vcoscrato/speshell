#version 440
#extension GL_GOOGLE_include_directive : enable
// What the wind carries: leaves tumbling around a center, each
// gusting along at its own pace and flipping over as it turns, and specks of dust
// streaking ahead of them. Flat two-tone leaves with a dark outline and a midrib.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
    vec2 resolution;
    vec2 origin;       // px, this item's top-left on screen
    vec2 center;
    float leaves;      // number of leaves (up to 16)
    float dust;        // number of dust specks (up to 24)
    float r0;          // px, middle orbit radius
    float spin;        // +1 counter-clockwise on screen, -1 clockwise
    float head;        // rad travelled along the spiral
    float leafSize;    // px, half-length of a leaf
    float turbulence;  // px the leaves are buffeted off their path
    vec4 mask;         // px rect the debris passes behind (zero size: none)
    float maskRadius;
    vec4 cLeaf;
    vec4 cLeafBack;
    vec4 cOutline;
    vec4 cDust;
    vec4 cGlint;
} u;
#include "../../lib/common.glsl"

// Debris item `seed`: its random traits, and how far along its path it is (rad).
vec4 traits(float seed) {
    return vec4(hash(vec2(seed, 1.3)), hash(vec2(seed, 2.9)), hash(vec2(seed, 4.1)), hash(vec2(seed, 6.7)));
}

float progress(vec4 rnd, float rate) {
    // Each piece gusts along at its own pace, now ahead of the others, now behind.
    return u.head * rate * mix(0.75, 1.3, rnd.x) - 1.5 * rnd.y
         + 0.45 * sin(u.time * mix(0.7, 1.6, rnd.z) + 6.2831853 * rnd.w);
}

// Where the item is: its center on screen, and its heading (rad).
vec3 orbit(float seed, vec4 rnd, float uu, float th) {
    float R = u.r0 * mix(0.8, 1.3, rnd.z) * (1.0 + 0.12 * sin(uu * 1.7 + rnd.x * 6.0));
    vec2 pos = u.center + R * vec2(cos(th), sin(th))
             + u.turbulence * vec2(sin(u.time * 1.3 + seed * 2.1) + 0.5 * sin(u.time * 2.9 + seed * 5.3),
                                   cos(u.time * 1.1 + seed * 3.7) + 0.5 * cos(u.time * 3.3 + seed * 1.9));
    return vec3(pos, th + u.spin * 1.5707963);
}

// Whether the item at angle th around the center can be near a pixel at angle thp,
// radius rp, within `slack` px: a cheap test before placing it.
bool nearby(float thp, float rp, float th, float slack) {
    float dth = abs(mod(thp - th + 3.1415927, 6.2831853) - 3.1415927);
    return dth * min(rp, u.r0 * 0.8) < slack;
}

void main() {
    vec2 p = u.origin + qt_TexCoord0 * u.resolution;
    float keep = 1.0;
    if (u.mask.z > 0.0) {
        keep = cover(sdRoundRect(p - u.mask.xy - u.mask.zw * 0.5, u.mask.zw * 0.5, u.maskRadius) - 2.0);
        if (keep <= 0.0) {
            fragColor = vec4(0.0);
            return;
        }
    }

    // Every piece orbits within a ring; skip pixels outside it.
    float rp = length(p - u.center);
    float slack = 1.5 * u.turbulence + 1.6 * u.leafSize + 22.0;
    if (rp < u.r0 * 0.7 - slack || rp > u.r0 * 1.46 + slack) {
        fragColor = vec4(0.0);
        return;
    }

    float thp = atan(p.y - u.center.y, p.x - u.center.x);
    vec4 col = vec4(0.0);

    // Dust: short streaks along the flow, drawn first so leaves cover them.
    for (int j = 0; j < 24; j++) {
        float fj = float(j);
        if (fj >= u.dust)
            break;
        float seed = fj + 100.0;
        vec4 rnd = traits(seed);
        float uu = progress(rnd, 1.6);
        float th = 6.2831853 * rnd.w + u.spin * uu;
        if (!nearby(thp, rp, th, 1.5 * u.turbulence + 26.0))
            continue;
        vec3 o = orbit(seed, rnd, uu, th);
        vec2 dir = vec2(cos(o.z), sin(o.z));
        vec2 rel = p - o.xy;
        float along = dot(rel, dir);
        float lenS = mix(7.0, 20.0, hash(vec2(fj, 9.1)));
        float across = abs(dot(rel, vec2(-dir.y, dir.x)));
        float w = 1.8 * clamp(0.5 + along / lenS, 0.15, 1.0);   // fat at the front
        float d = max(abs(along) - lenS, 0.0);
        float a = cover(w - length(vec2(d, across))) * 0.75;
        col = mix(col, vec4(u.cDust.rgb, 1.0), a);
    }

    for (int i = 0; i < 16; i++) {
        float fi = float(i);
        if (fi >= u.leaves)
            break;
        vec4 rnd = traits(fi);
        float uu = progress(rnd, 1.0);
        float th = 6.2831853 * rnd.w + u.spin * uu;
        if (!nearby(thp, rp, th, 1.5 * u.turbulence + 1.6 * u.leafSize + 4.0))
            continue;
        vec3 o = orbit(fi, rnd, uu, th);
        vec2 rel = p - o.xy;
        float L = u.leafSize * mix(0.7, 1.2, hash(vec2(fi, 7.7)));
        if (dot(rel, rel) > L * L * 2.2)
            continue;
        // Tumbling: it spins in the plane and flips over, thinning as it turns edge-on.
        float spinRate = mix(-4.5, 4.5, hash(vec2(fi, 3.3)));
        float ang = o.z + u.time * spinRate + 6.2831853 * hash(vec2(fi, 8.8));
        float flip = cos(u.time * mix(2.0, 5.5, hash(vec2(fi, 5.5))) + fi * 1.7);
        float thin = max(abs(flip), 0.16);
        vec2 q = vec2(cos(ang) * rel.x + sin(ang) * rel.y, -sin(ang) * rel.x + cos(ang) * rel.y);
        float W = L * 0.45;
        float x = q.x / L;
        float edge = (W * (1.0 - x * x) - abs(q.y) / thin) * thin; // ≈ px inside
        edge = min(edge, (1.0 - abs(x)) * L * 0.6);
        // A short stem off the base.
        float stem = 0.9 - length(vec2(max(q.x - L * 1.3, 0.0) + max(L * 0.95 - q.x, 0.0), q.y));
        float body = cover(edge);
        float outline = max(cover(edge + 1.6), cover(stem));
        if (outline <= 0.0)
            continue;
        vec3 face = flip > 0.0 ? u.cLeaf.rgb : u.cLeafBack.rgb;
        // Flat light on the upper half, and a dark midrib.
        face = mix(face, mix(face, u.cGlint.rgb, 0.28), cover(q.y * sign(flip) - W * 0.25 * (1.0 - x * x)));
        face = mix(face, u.cOutline.rgb, cover(0.8 - abs(q.y)) * step(abs(q.x), L * 0.85) * thin);
        vec3 leafCol = mix(u.cOutline.rgb, face, body);
        col = mix(col, vec4(leafCol, 1.0), outline);
    }

    fragColor = col * keep * u.qt_Opacity;
}
