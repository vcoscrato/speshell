#version 440
#extension GL_GOOGLE_include_directive : enable
// The captured panel racing along like a cartoon car: drawn at its offset, leaning
// with its braking or acceleration, stretched along its speed and squashed as it
// stops, standing on the road. Behind it streams a streak of glossy candy-red paint,
// outlined in rubber, its tail split into fingers; a bold bolt decal runs through it,
// stepping down along each run and pointed at its tail.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 origin;        // px, this item's top-left on screen
    vec2 resolution;    // px, this item's size
    vec4 rect;          // px, the panel at rest
    float offset;       // px, how far it is from rest along x
    float smear;        // px, length of the streak behind it
    float dir;          // +1 moving right, -1 moving left
    float lean;         // px the top edge leads the bottom
    float stretch;      // > 0 stretched along x and squashed in y; < 0 squashed
    float heat;         // 0..1 how solid the streak runs
    vec4 cPaint;
    vec4 cGlow;
    vec4 cEdge;
    vec4 cCore;
    vec4 cRubber;
} u;
layout(binding = 1) uniform sampler2D source;
#include "../common/common.glsl"

vec4 panelAt(vec2 local) {
    vec2 uv = local / u.rect.zw;
    vec4 c = texture(source, uv);
    return c * step(0.0, uv.x) * step(uv.x, 1.0) * step(0.0, uv.y) * step(uv.y, 1.0);
}

// x of the step that starts run k of the decal, px back from the tail.
float runStart(float k, float P) {
    return (k + 0.3 * (hash(vec2(k, 11.0)) - 0.5)) * P;
}

void main() {
    vec2 p = u.origin + qt_TexCoord0 * u.resolution;
    vec2 local = p - u.rect.xy - vec2(u.offset, 0.0);
    // Stretched about its middle along x and from the road up in y, keeping its area.
    float sx = 1.0 + u.stretch, sy = 1.0 / sx;
    local.x = u.rect.z * 0.5 + (local.x - u.rect.z * 0.5) / sx;
    local.y = u.rect.w - (u.rect.w - local.y) / sy;
    // Leaning: the top runs ahead of the bottom.
    local.x += u.lean * (local.y / u.rect.w - 0.5) * 2.0;

    vec4 col = panelAt(local);
    float H = u.rect.w;
    if (u.smear > 8.0 && u.heat > 0.0) {
        // px behind the panel's tail.
        float s = u.dir > 0.0 ? -local.x : local.x - u.rect.z;
        float L = u.smear * 1.15;
        if (s > -4.0 && s < L) {
            float t = clamp(s / L, 0.0, 1.0);
            // The streak: hugging the road, its top sloping down to the tail, which
            // splits into fingers of uneven length.
            float rowH = H / 5.0;
            float row = floor(local.y / rowH);
            float reach = L * mix(0.55, 1.0, hash(vec2(row, 3.0)));
            float top = H * (0.06 + 0.3 * t * t);
            float body = max(top - local.y, local.y - H * (1.0 - 0.04 * t));
            float split = t > 0.45 ? max(abs(local.y - (row + 0.5) * rowH) - rowH * 0.36, s - reach) : -1e3;
            float d = max(max(body, split), -s);
            float a = min(1.0, u.heat * 1.4);
            vec4 st = over(vec4(0.0), u.cRubber.rgb, cover(2.5 - d));
            vec3 paint = u.cPaint.rgb;
            // Shade low on the body, and a glossy cartoon highlight along its top.
            paint = mix(paint, u.cPaint.rgb * 0.62, band(local.y, H * 0.8));
            float gloss = cover(H * 0.035 - abs(local.y - (top + H * 0.09))) * (1.0 - smoothstep(0.3, 0.7, t));
            paint = mix(paint, mix(u.cPaint.rgb, u.cCore.rgb, 0.75), gloss);
            st = over(st, paint, cover(-d));

            // The decal: runs whose centerline slants down across each and jumps
            // back up by less than its width, so its edges step, from thick at the
            // panel to a point at the tail.
            float P = max(L / 3.2, 30.0);
            float th = H * 0.11 * pow(1.0 - t, 0.7);
            float A = th * 0.6;
            float i = floor(s / P);
            float dd = 1e3, yy = 0.0;
            for (int j = -1; j <= 1; j++) {
                float k = i + float(j);
                float x0 = runStart(k, P), x1 = runStart(k + 1.0, P);
                float f = (s - x0) / (x1 - x0);
                float y = local.y - H * 0.55 - A * (2.0 * f - 1.0);
                float dk = max((abs(y) - th) / sqrt(1.0 + 4.0 * A * A / ((x1 - x0) * (x1 - x0))),
                               max(x0 - s, s - x1));
                if (dk < dd) {
                    dd = dk;
                    yy = y;
                }
            }
            dd = max(dd, -s);
            vec3 bc = mix(u.cGlow.rgb, u.cEdge.rgb, band(yy, th * 0.25));
            st = over(st, u.cRubber.rgb, cover(2.5 - dd));
            st = over(st, bc, cover(-dd));
            st = over(st, u.cCore.rgb, cover(-dd - 2.5) * band(-yy, th * 0.35));
            col = col + st * a * (1.0 - col.a);
        }
    }
    fragColor = col * u.qt_Opacity;
}
