#version 440
#extension GL_GOOGLE_include_directive : enable
// Low-resolution flame simulation. Feeds back into itself every step of `dt` s:
// R = fuel density, G = heat, B = the fuel's strength where it caught, so the shading
// can band a weak flame by how far through its life it is, and A = the density of a
// second, deeper row of flames behind the first (`layered`), with its own slower flow.
// Velocity is buoyancy plus curl-noise turbulence.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
    float dt;
    float emit;        // 0..1 strength of the simmering rim around the panel
    float frontFuel;   // 0..1 strength of flames along the burn front
    vec2 offset;       // px, where this item's top left lies in the screen
    vec2 resolution;   // this item's size in px
    vec4 panel;        // panel rect in px
    float radius;
    vec2 origin;
    float burnR;
    float burnStep;    // px the front moved since the last step
    float fieldScale;
    float clearBehind; // 1: no flames over the panel once the front has passed
    float trail;       // px behind the front past which flames die fast; 0: no limit
    float layered;     // 1: a deeper row of rim flames burns behind the front one
    float sparse;      // 0..1 the front burns in separate jets however small it is
    float kindle;      // 1: the rim catches only where the front has passed
    float douse;       // 0..1 flames outside the panel burn out faster
} u;
layout(binding = 1) uniform sampler2D state;
#include "../common/common.glsl"

void main() {
    vec2 uv = qt_TexCoord0;
    vec2 p = u.offset + uv * u.resolution;
    vec2 c = u.panel.xy + u.panel.zw * 0.5;

    float d = sdRoundRect(p - c, u.panel.zw * 0.5, u.radius);

    vec4 here = texture(state, uv);
    // Bigger fronts move faster, and their flames rise faster to stand up off them;
    // so do a sparse front's, which burn in tongues.
    float lift = sqrt(u.fieldScale) * (1.0 + 0.7 * u.sparse);
    // Simmering flames sway less near their roots, so they stand up off the edge
    // rather than being blown along it.
    float rooted = u.emit > 0.0 ? mix(0.3, 1.0, smoothstep(4.0, 50.0, d)) : 1.0;
    vec2 v = vec2(0.0, (-100.0 - 230.0 * here.g) * lift)
           + (curl(p / 190.0, u.time * 0.5) * (60.0 + 90.0 * (1.0 - here.g))
           + curl(p / 70.0, u.time * 1.4) * 60.0 * (1.2 - here.g)) * rooted;
    vec4 prev = texture(state, uv - v * u.dt / u.resolution);
    // The deeper row rises slower and sways on broader swirls of its own, so the two
    // rows drift apart like flames at different depths.
    float back = 0.0;
    if (u.layered > 0.5) {
        vec2 vb = vec2(0.0, -115.0) + curl(p / 120.0 + 9.7, u.time * 0.6) * 75.0 * rooted;
        back = texture(state, uv - vb * u.dt / u.resolution).a;
        back = max(back * exp(-0.5 * u.dt) - 1.25 * u.dt, 0.0);
    }

    // Linear burn-out erodes thin edges first, so tongues taper to points.
    float dens = max(prev.r * exp(-0.6 * u.dt) - 1.15 * u.dt, 0.0);
    float heat = max(prev.g - 2.2 * u.dt, 0.0);
    float bf = burnField(p, u.origin, u.fieldScale);
    // Well behind a front the fuel is spent: flames there gutter out within a few
    // frames, cooling as they go, so they stay on the front and rise off it.
    float spent = u.trail > 0.0 ? smoothstep(u.trail * 0.4, u.trail, u.burnR - bf) : 0.0;
    dens = max(dens - 5.0 * spent * u.dt, 0.0) * exp(-5.0 * spent * u.dt);
    heat = max(heat - 4.0 * spent * u.dt, 0.0);

    // Put out, flames over the edge burn down where they stand, the higher the faster.
    float doused = u.douse * smoothstep(-4.0, 8.0, d) * (1.0 + d / 16.0) * u.dt;
    dens = max(dens - 3.0 * doused, 0.0);
    back = max(back - 3.0 * doused, 0.0);

    // Rim fuel: a low bed along the outline with tongues rising out of it.
    // The outline, roughened, so nothing traces its straight edges.
    float dr = d + (vnoise(p / 13.0 + vec2(0.0, u.time * 0.7)) - 0.5) * 8.0;
    float rim = smoothstep(14.0, 3.0, d) * smoothstep(-1.0, 4.0, dr);
    // Only where the outline faces up: along the top, thinning round the corners and
    // gone before they turn into the sides, where jets would rise along the edge as
    // straight streaks or hang in the air beside it.
    vec2 rel = p - c;
    vec2 q = abs(rel) - u.panel.zw * 0.5 + u.radius;
    float facing = rel.y < 0.0 ? (q.x > 0.0 && q.y > 0.0 ? q.y / length(q) : step(q.x, q.y)) : 0.0;
    float topBias = smoothstep(0.45, 0.95, facing);
    float s = p.x + (p.y - u.panel.y) * sign(p.x - c.x);
    // Opening, the edge catches as the front reaches it.
    float base = rim * topBias * mix(1.0, smoothstep(0.0, 40.0, u.burnR - bf), u.kindle);
    // The bed burns all along the edge, its height breathing.
    float bed = 0.25 + 0.09 * vnoise(vec2(s / 15.0, u.time * 2.2));
    // Tongues rise out of it, each to its own height: narrow peaks of a drifting noise,
    // scaled by a slower one, their tops split by quicker licks that burn out apart.
    float peaks = vnoise(vec2(s / 17.0, u.time * 1.2)) * 0.7 + vnoise(vec2(s / 7.0, u.time * 2.8)) * 0.3;
    float tongues = smoothstep(0.45, 0.85, peaks) * (0.3 + 0.7 * vnoise(vec2(s / 61.0 + 3.0, u.time * 0.45)));
    tongues *= 0.55 + 0.45 * smoothstep(0.2, 0.75, vnoise(vec2(s / 5.0, u.time * 3.6)));
    // Kindling, the bed catches before the tongues grow out of it.
    float src = base * (bed * smoothstep(0.0, 0.5, u.emit) + 0.62 * tongues * u.emit);
    float srcHeat = base * min(1.0, 0.52 + 0.65 * tongues) * min(1.0, 2.0 * u.emit);
    // Each flame bands by the fuel its spot burns with at full simmer, so the bed glows
    // only at its roots, the tongues burn white-hot, and kindling flames are red.
    float strength = base * (bed + 0.62 * tongues);
    if (u.layered > 0.5) {
        // The deeper row: fewer, broader, taller tongues from the same edge.
        float far = vnoise(vec2(s / 19.0 + 11.0, u.time * 0.8)) * 0.7 + vnoise(vec2(s / 8.0 + 5.0, u.time * 2.1)) * 0.3;
        float farTongues = smoothstep(0.48, 0.85, far) * (0.45 + 0.55 * vnoise(vec2(s / 47.0 + 8.0, u.time * 0.35)));
        back = max(back, base * (0.22 + 0.7 * farTongues) * u.emit);
    }

    // Front fuel: flames lick up off the burning edge as it sweeps the panel.
    // Fuel patches sit still on screen and catch as the front reaches them. A front as
    // big as the screen's burns in separate jets with gaps between, larger and fewer,
    // so it reads as tongues of flame rather than a solid ring.
    float sparse = max(smoothstep(1.5, 4.0, u.fieldScale), u.sparse);
    // Over all the ground the front crossed since the last step, so a fast front lays
    // its fuel in one piece rather than in a ring per step that rises as ribs.
    float ahead = bf - u.burnR + 6.0;
    float onFront = smoothstep(26.0, 4.0, max(ahead, -ahead - u.burnStep)) * smoothstep(10.0, 2.0, dr);
    float grain = mix(1.0, 1.35, sparse);
    // Taller than wide, so they rise off the front as tongues.
    float patches = vnoise(p / (vec2(20.0, 34.0) * grain) + vec2(0.0, u.time * 0.9)) * 0.7
                  + vnoise(p / (vec2(8.0, 15.0) * grain) - vec2(0.0, u.time * 2.0)) * 0.3;
    float frontJets = smoothstep(mix(0.38, 0.45, sparse), mix(0.68, 0.7, sparse), patches);
    float frontSrc = onFront * (mix(0.25, 0.16, sparse) + mix(0.75, 0.84, sparse) * frontJets) * u.frontFuel;
    if (frontSrc > src) {
        src = frontSrc;
        // Only the jets catch hot; between them the edge smoulders low.
        srcHeat = onFront * (0.25 + 0.6 * frontJets) * u.frontFuel;
        strength = u.frontFuel;
    }

    // Where fuel catches it takes the source's strength; elsewhere it carries its own.
    float caught = smoothstep(-0.03, 0.03, src - dens);
    float carried = mix(prev.b, strength, caught);
    dens = max(dens, src);
    heat = max(heat, srcHeat);
    // Nothing burns over panel areas the front passed a while ago.
    // Faded rather than cut, inside the roughened outline: a hard cut at quarter
    // resolution shows as stair steps, and along the outline as straight lines. With
    // no rim simmering, the front's flames just outside the outline go too, or they
    // linger round it as a frame.
    float reach = mix(12.0, 2.0, step(1e-3, u.emit));
    float behind = u.clearBehind * smoothstep(reach, -8.0, dr) * smoothstep(35.0, 75.0, u.burnR - bf);
    dens *= 1.0 - behind;
    heat *= 1.0 - behind;
    back *= 1.0 - behind;

    fragColor = vec4(dens, heat, carried, back);
}
