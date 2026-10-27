#version 440
// A star glint: a round core with a soft halo and four tapering rays, two long
// and two short.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float k;            // 0..1 brightness and size
    float spin;         // ray angle (radians)
    vec4 cHot;
    vec4 cGlow;
} u;

float rays(vec2 q, float len) {
    vec2 a = abs(q);
    return exp(-a.y * 90.0) * max(0.0, 1.0 - a.x / len) + exp(-a.x * 90.0) * max(0.0, 1.0 - a.y / len);
}

void main() {
    vec2 q = qt_TexCoord0 * 2.0 - 1.0;
    float d = length(q);
    float c = cos(u.spin), s = sin(u.spin);
    vec2 r = vec2(c * q.x - s * q.y, s * q.x + c * q.y);
    vec2 r45 = vec2(r.x - r.y, r.x + r.y) * 0.7071068;

    float k = u.k;
    float core = 1.0 - smoothstep(0.05 * k, 0.09 * k + 0.01, d);
    float halo = exp(-d * d / max(0.06 * k * k, 1e-4)) * 0.6;
    float ray = rays(r, 0.95 * k) + 0.5 * rays(r45, 0.45 * k);
    float glow = clamp(halo + ray, 0.0, 1.0) * k;
    float hot = clamp(core + ray * ray * 0.6, 0.0, 1.0) * k;
    vec4 col = vec4(u.cGlow.rgb, 1.0) * glow;
    col = vec4(u.cHot.rgb, 1.0) * hot + col * (1.0 - hot);
    fragColor = col * u.qt_Opacity;
}
