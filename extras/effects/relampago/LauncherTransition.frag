#version 440
#extension GL_GOOGLE_include_directive : enable
// The captured panel racing along: drawn at its offset, leaning with its braking
// or acceleration, crisp at the front with a motion-blurred ghost streaming off
// behind it. The ghost runs to racing red, and a bolt of yellow zigzags through it.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 origin;        // px, this item's top-left on screen
    vec2 resolution;    // px, this item's size
    vec4 rect;          // px, the panel at rest
    float offset;       // px, how far it is from rest along x
    float smear;        // px, length of the ghost behind it
    float dir;          // +1 moving right, -1 moving left
    float lean;         // px the top edge leads the bottom
    float heat;         // 0..1 how red and lit the ghost runs
    vec4 cPaint;
    vec4 cGlow;
    vec4 cEdge;
    vec4 cCore;
} u;
layout(binding = 1) uniform sampler2D source;
#include "../../lib/common.glsl"

vec4 panelAt(vec2 local) {
    vec2 uv = local / u.rect.zw;
    vec4 c = texture(source, uv);
    return c * step(0.0, uv.x) * step(uv.x, 1.0) * step(0.0, uv.y) * step(uv.y, 1.0);
}

void main() {
    vec2 p = u.origin + qt_TexCoord0 * u.resolution;
    vec2 local = p - u.rect.xy - vec2(u.offset, 0.0);
    // Leaning: the top runs ahead of the bottom.
    local.x += u.lean * (local.y / u.rect.w - 0.5) * 2.0;

    vec4 crisp = panelAt(local);
    vec4 col = crisp;
    if (u.smear > 1.0) {
        // Where the panel was a moment ago, fading with age; dithered so the taps
        // don't band, and streaked along the rows.
        vec4 ghost = vec4(0.0);
        float wsum = 0.0;
        float jit = hash(p);
        for (int i = 0; i < 14; i++) {
            float t = (float(i) + jit) / 14.0;
            float w = 1.0 - t * 0.9;
            ghost += panelAt(local + vec2(u.dir * u.smear * t, 0.0)) * w;
            wsum += w;
        }
        ghost /= wsum;
        ghost *= 0.65 + 0.35 * vnoise(vec2(local.x / 90.0, local.y / 3.0));
        // How far behind the panel's tail this is, 0..1 of the ghost's length.
        float back = u.dir > 0.0 ? local.x : u.rect.z - local.x;
        float behind = clamp(-back / max(u.smear, 1.0), 0.0, 1.0);
        ghost.rgb = mix(ghost.rgb, u.cPaint.rgb * ghost.a, u.heat * (0.45 + 0.55 * behind));
        col = crisp + ghost * (1.0 - crisp.a);

        // The bolt decal streaming off the tail: thick at the panel, tapering to a
        // point, its centerline stepping back at two kinks.
        float L = u.smear;
        float s = -back;                                    // px behind the tail
        if (s > -2.0 && s < L) {
            float t = clamp(s / L, 0.0, 1.0);
            // A ribbon whose centerline slants down along each of three runs and
            // jumps back up between them, less than its width, so the edges step
            // like a bolt's.
            float seg = L / 3.0;
            float k = fract(s / seg);
            float cy = u.rect.w * (0.52 + 0.075 * (2.0 * k - 1.0));
            float th = u.rect.w * 0.12 * pow(1.0 - t, 0.8);
            float d = abs(local.y - cy) - th;
            float a = cover(-d) * u.heat;
            vec3 bc = mix(u.cGlow.rgb, u.cEdge.rgb, smoothstep(0.25, 0.8, t));
            float rim = cover(-d - 2.5);
            col = mix(col, vec4(u.cPaint.rgb * 0.6, 1.0), a);
            col = mix(col, vec4(bc, 1.0), a * rim);
            col = mix(col, vec4(u.cCore.rgb, 1.0), a * cover(-d - th * 0.6) * (1.0 - t));
        }
    }
    fragColor = col * u.qt_Opacity;
}
