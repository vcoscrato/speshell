#version 440
#extension GL_GOOGLE_include_directive : enable
// What the wind carries: leaves tumbling around a center, each
// gusting along at its own pace and flipping over as it turns, and specks of dust
// streaking ahead of them. Flat two-tone leaves with a dark outline and a midrib.
// One piece at a time, where Debris.vert puts it.
layout(location = 0) in vec2 p;
layout(location = 1) in vec4 piece;
layout(location = 2) in vec4 shape;
layout(location = 0) out vec4 fragColor;
#include "Debris.glsl"

void main() {
    float keep = 1.0;
    if (u.mask.z > 0.0) {
        keep = cover(sdRoundRect(p - u.mask.xy - u.mask.zw * 0.5, u.mask.zw * 0.5, u.maskRadius) - 2.0);
        if (keep <= 0.0)
            discard;
    }
    vec2 rel = p - piece.xy;
    vec4 col;

    if (piece.w < 0.5) {
        // A streak of dust, fat at the front.
        vec2 dir = vec2(cos(piece.z), sin(piece.z));
        float along = dot(rel, dir);
        float lenS = shape.x;
        float across = abs(dot(rel, vec2(-dir.y, dir.x)));
        float w = 1.8 * clamp(0.5 + along / lenS, 0.15, 1.0);
        float d = max(abs(along) - lenS, 0.0);
        col = vec4(u.cDust.rgb, 1.0) * cover(w - length(vec2(d, across))) * 0.75;
    } else {
        // A leaf, thinning as it turns edge-on.
        float L = shape.x;
        float ang = shape.y;
        float flip = shape.z;
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
        vec3 face = flip > 0.0 ? u.cLeaf.rgb : u.cLeafBack.rgb;
        // Flat light on the upper half, and a dark midrib.
        face = mix(face, mix(face, u.cGlint.rgb, 0.28), cover(q.y * sign(flip) - W * 0.25 * (1.0 - x * x)));
        face = mix(face, u.cOutline.rgb, cover(0.8 - abs(q.y)) * step(abs(q.x), L * 0.85) * thin);
        col = vec4(mix(u.cOutline.rgb, face, body), 1.0) * outline;
    }
    fragColor = col * keep * u.qt_Opacity;
}
