#version 440
#extension GL_GOOGLE_include_directive : enable
// A waterbending whip: a tapered tube of water along a spiral into (or out of) a
// center, shaded in flat bands with a white highlight along one side and a few
// trailing droplets.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
    vec2 resolution;
    vec2 center;
    float r0;
    float k;
    float th0;
    float spin;
    float head;
    float len;
    float tubeWidth;
    vec4 cDeep;
    vec4 cMid;
    vec4 cLight;
    vec4 cFoam;
} u;
#include "../../lib/common.glsl"

void main() {
    vec2 p = qt_TexCoord0 * u.resolution;
    // The tube's skin ripples a little as it flows.
    vec2 q = p + (vec2(vnoise(p / 40.0 + u.time * 1.5), vnoise(p / 40.0 - u.time * 1.5)) - 0.5) * 6.0;
    vec2 tube = tubeStroke(q, u.center, u.r0, u.k, u.th0, u.spin, u.head, u.len, u.tubeWidth);
    float inside = cover(tube.x);
    float n = tube.y;                                  // -1..1 across the tube

    vec3 col = u.cMid.rgb;
    col = mix(col, u.cDeep.rgb, cover(-n - 0.35));     // shadow side
    col = mix(col, u.cLight.rgb, cover(n - 0.2) * cover(0.75 - n));
    col = mix(col, u.cFoam.rgb, cover(n - 0.42) * cover(0.62 - n));
    vec3 rimCol = u.cDeep.rgb * 0.7;
    float rim = cover(tube.x + 2.0) - inside;

    // Droplets shed from the tail.
    float drops = 0.0;
    for (int i = 0; i < 5; i++) {
        float fi = float(i);
        float uu = u.head - u.len - 0.25 - 0.3 * fi;
        float rr = u.r0 * exp(-u.k * uu) + (hash(vec2(fi, 1.0)) - 0.5) * 40.0;
        float th = u.th0 + u.spin * uu;
        vec2 dp = u.center + rr * vec2(cos(th), sin(th));
        float size = mix(3.0, 7.0, hash(vec2(fi, 2.0))) * clamp(u.head - u.len - 0.25 - 0.3 * fi, 0.0, 1.0);
        drops = max(drops, cover(size - length(p - dp)));
    }

    vec3 outCol = mix(rimCol, col, inside);
    float a = max(max(inside, rim), drops);
    outCol = mix(outCol, u.cLight.rgb, drops * (1.0 - inside));
    fragColor = vec4(outCol * a, a) * u.qt_Opacity;
}
