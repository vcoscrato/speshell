#version 440
#extension GL_GOOGLE_include_directive : enable
// A shard of the old wallpaper broken loose: it tilts away from the light a shade at a
// time, shows its broken rim, lit where it faces the light and dark in its thickness
// where it faces away, and fades as it crumbles at the end of its fall.
layout(location = 0) in vec2 p;
layout(location = 1) in vec4 a0;   // its pivot, and its offset from where it stood (px)
layout(location = 2) in vec4 a1;   // its scale and turn, how far through its fall, and its extent
layout(location = 3) in vec4 a2;   // its shard, in the cells table
layout(location = 0) out vec4 fragColor;
#include "Shards.glsl"

void main() {
    vec2 pivot = a0.xy;
    float s = a1.x;
    float k = a1.z;
    // The point of the old wallpaper that shows here, if it is in this shard.
    vec2 q = pivot + rot(p - pivot - a0.zw, a1.y) / s;
    if (distance(q, pivot) > a1.w * 1.5 + 6.0 || texture(cellMap, q / u.resolution).xy != a2.xy)
        discard;
    vec4 tex = texture(source, q / u.resolution);
    // Tilting away from the light: a flat shade darker, then another.
    tex.rgb *= mix(1.0, 0.8, step(0.2, k)) * mix(1.0, 0.82, step(0.55, k));
    // Its broken rim: lit where it faces the light, its thickness dark where it faces
    // away, each widest where it faces most.
    vec4 rim = texture(crackMap, q / u.resolution);
    float e = rim.x;
    vec2 en = rim.yz;
    vec2 qd = q - u.center;
    float qV = length(qd) * TAU / N, qU = qV / KU;
    vec2 sn = normalize((en.x / qU) * qd + (en.y / qV) * vec2(-qd.y, qd.x) + 1e-5);
    float facing = dot(sn, LIGHT);
    float thick = clamp(qV * 0.1, 2.0, 11.0) * smoothstep(0.0, 0.25, k);
    float es = e * s;
    tex.rgb = mix(tex.rgb, mix(tex.rgb, u.cCrack.rgb, 0.65), cover(thick * smoothstep(0.0, 0.6, -facing) - es));
    tex.rgb = mix(tex.rgb, mix(tex.rgb, u.cLip.rgb, 0.6), cover(max(2.0, thick * 0.6) * smoothstep(0.0, 0.6, facing) - es));
    tex.rgb = mix(tex.rgb, u.cCrack.rgb, cover(1.3 - es));
    fragColor = tex * (1.0 - smoothstep(0.85, 1.0, k)) * u.qt_Opacity;
}
