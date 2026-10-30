#version 440
#extension GL_GOOGLE_include_directive : enable
// Works out, each frame, which of the relâmpago wallpaper transition's embers reach
// each band of BAND rows, and where they are, so a pixel looks only at the few in its
// band: a column per band, and two rows for each of SLOTS embers, in the order they
// are drawn: (where it is, px, its radius, or -1 past the last), and (how much of
// its life is left, its tint).
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
        float fi = float(FORKS + 2 * i);
        vec4 h = traits(fi);
        float age = u.s * mix(0.8, 1.6, h.z);
        float ey = h.x + 260.0 * age * age - 60.0 * age;
        if (ey + 6.0 < top || ey - 6.0 > bottom)
            continue;
        if (found == slot) {
            float life = 1.0 - smoothstep(0.5, 1.0, age);
            fragColor = mod(row, 2.0) < 0.5
                ? vec4(traits(fi + 1.0).x + u.gap * h.y, ey, mix(2.0, 4.0, h.z) * life, 1.0)
                : vec4(life, h.w, 0.0, 1.0);
            break;
        }
        found += 1.0;
    }
}
