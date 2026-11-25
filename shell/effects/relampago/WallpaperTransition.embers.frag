#version 440
#extension GL_GOOGLE_include_directive : enable
// Works out, each frame, which of the relâmpago wallpaper transition's embers reach
// each band of BAND rows, and where they are, so a pixel looks only at the few in its
// band: a column per band, and two rows for each of SLOTS embers, in the order they
// are drawn: (where it is, px, its radius, or -1 past the last), and (how much of
// its life is left, its tint, the way it flies).
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float s;            // how far the halves have split, 0..1
    float gap;          // px between them
    float columns;      // the bolt table's width
    float bands;
} u;
layout(binding = 1) uniform sampler2D tear;     // WallpaperTransition.tear.frag
#include "Tear.glsl"

vec4 traits(float i) {
    return texture(tear, vec2((i + 0.5) / u.columns, 0.75));
}

void main() {
    float band = floor(qt_TexCoord0.x * u.bands);
    float row = floor(qt_TexCoord0.y * float(2 * SLOTS));
    float slot = floor(row / 2.0);
    float top = band * BAND, bottom = top + BAND;
    float found = 0.0;
    fragColor = vec4(0.0, 0.0, -1.0, 0.0);
    for (int i = 0; i < EMBERS; i++) {
        float fi = float(2 * FORKS + 2 * i);
        vec4 h = traits(fi);
        float rate = mix(0.8, 1.6, h.z);
        float age = u.s * rate;
        float ey = h.x + 260.0 * age * age - 60.0 * age;
        if (ey + REACH < top || ey - REACH > bottom)
            continue;
        if (found == slot) {
            // Burnt out within about a third of a second, so the new wallpaper is left clean.
            float life = 1.0 - smoothstep(0.12, 0.32, u.s);
            // Carried out with its half (the gap grows as s^2.1) and falling.
            vec2 vel = vec2(u.gap * 2.1 / max(u.s, 1e-3) * h.y, (520.0 * age - 60.0) * rate);
            fragColor = mod(row, 2.0) < 0.5
                ? vec4(traits(fi + 1.0).x + u.gap * h.y, ey, mix(3.0, 6.0, h.z) * life, 1.0)
                : vec4(life, h.w, normalize(vel + vec2(0.0, 1e-3)));
            break;
        }
        found += 1.0;
    }
}
