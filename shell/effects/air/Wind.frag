#version 440
#extension GL_GOOGLE_include_directive : enable
// Wind as a real 2D flow. The air follows the complex potential
//     w(z) = U (z e^-ia + obstacle e^ia / z) + (q + i g) log z
// in a space where the unit circle is an ellipse around the launcher: a breeze at
// angle a that parts around the obstacle, plus a vortex (g) and a source or sink
// (q). Streamlines are the level lines of psi = Im w, so they never cross, crowd
// together where the air speeds up and spread where it slows. Streaks are drawn
// along them as tapered swooshes, travelling downstream along phi = Re w, with a
// translucent sheet of air beside each one, over mist wound into the flow. A
// smooth turbulence bends the whole flow at once.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
    vec2 resolution;
    vec2 origin;       // px, this item's top-left on screen
    vec2 center;
    vec2 axes;         // px, half-axes of the ellipse that is the unit circle in flow space
    float wind;        // U, breeze strength
    float windAngle;   // a, rad: the direction the breeze blows toward
    float obstacle;    // 0..1, how much the breeze parts around the ellipse
    float vortex;      // circulation, in streak periods per turn; whole numbers keep streaks seamless
    float source;      // outflow in streamlines per turn (negative: a sink); a multiple of 12
    float spacing;     // psi between streamlines
    float dash;        // phi per streak period
    float travel;      // streak periods travelled so far (drives the motion)
    float duty;        // fraction of a period a streak covers
    float density;     // fraction of streamlines that carry streaks
    float lineWidth;   // px, half-width of a streak at its thickest
    float sheet;       // opacity of the sheet of air beside each streak
    float inner;       // flow-space radius the streaks fade in from
    float outer;       // flow-space radius they fade out by
    float mist;        // 0..1
    float turbulence;  // px
    vec4 mask;         // px rect the wind passes behind (zero size: none)
    float maskRadius;
    vec4 cBody;
    vec4 cRim;
} u;
#include "../common/common.glsl"

vec2 cmul(vec2 a, vec2 b) { return vec2(a.x * b.x - a.y * b.y, a.x * b.y + a.y * b.x); }

// Index i wrapped to period n (n = 0: no wrap).
float wrap(float i, float n) { return n > 0.0 ? mod(i, n) : i; }

// 1D value noise repeating every n units (n = 0: never).
float pnoise(float x, float n) {
    float i = floor(x), f = fract(x);
    return mix(hash(vec2(wrap(i, n), 0.7)), hash(vec2(wrap(i + 1.0, n), 0.7)), f * f * (3.0 - 2.0 * f));
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

    vec2 rel = p - u.center;
    if (u.turbulence > 0.0)
        rel += swirl(rel / (1.6 * min(u.axes.x, u.axes.y)), u.time * 0.3) * u.turbulence;
    vec2 z = rel / u.axes;
    float r = max(length(z), 1e-3);
    float fade = smoothstep(u.inner, u.inner + 0.2, r) * (1.0 - smoothstep(u.outer * 0.7, u.outer, r));
    if (fade <= 0.0) {
        fragColor = vec4(0.0);
        return;
    }
    float th = atan(z.y, z.x);
    vec2 inv = vec2(z.x, -z.y) / (r * r);                  // 1 / z
    vec2 e = vec2(cos(u.windAngle), sin(u.windAngle));     // e^ia
    vec2 eC = vec2(e.x, -e.y);                             // e^-ia
    float g = u.vortex * u.dash / 6.2831853;
    float q = u.source * u.spacing / 6.2831853;
    vec2 wb = u.wind * (cmul(z, eC) + u.obstacle * cmul(e, inv));
    float phi = wb.x + q * log(r) - g * th;
    float psi = wb.y + g * log(r) + q * th;
    // dw/dz, for the px distance between streamlines (Cauchy-Riemann: grad psi = (Im, Re)).
    vec2 dw = u.wind * (eC - u.obstacle * cmul(e, cmul(inv, inv))) + cmul(vec2(q, g), inv);
    float grad = length(vec2(dw.y / u.axes.x, dw.x / u.axes.y)) / u.spacing;  // streamlines per px

    // The streamline nearest p. Streamlines come in bundles of three that blow
    // together, each line a little out of step. With a source, psi jumps by a whole
    // number of streamlines round the circle, so the traits repeat to match.
    float lv = psi / u.spacing;
    float k = floor(lv + 0.5);
    float dl = lv - k;                                     // streamlines across from it
    float dist = abs(dl) / max(grad, 1e-5);                // px
    float n = abs(u.source);
    float grp = floor(k / 3.0), j = k - 3.0 * grp;
    float gid = wrap(grp, n / 3.0);
    vec4 rnd = vec4(hash(vec2(gid, 1.7)), hash(vec2(gid, 4.3)), hash(vec2(gid, 7.9)), hash(vec2(gid, 2.6)));
    float own = hash(vec2(wrap(k, n), 5.1));
    // Where streamlines crowd too closely the streaks thin out instead of clumping.
    float room = smoothstep(2.5, 6.0, 1.0 / max(grad, 1e-5) / u.lineWidth);

    float body = 0.0, line = 0.0, sheetA = 0.0;
    if (rnd.x < u.density && own < 0.85) {
        // Along the streamline: phi jumps by a whole number of periods round the
        // vortex, so the streaks stay seamless.
        float s = phi / u.dash - u.travel * mix(0.8, 1.25, rnd.y) + rnd.z + 0.04 * j * (own - 0.4);
        float d = u.duty * mix(0.6, 1.4, rnd.w) * mix(0.7, 1.0, own);
        float t = fract(s) / d;                            // 0 tail .. 1 head
        if (t < 1.0) {
            float w = u.lineWidth * mix(0.6, 1.2, rnd.y) * (j == 1.0 ? 1.0 : 0.7)
                    * pow(t, 0.6) * pow(clamp((1.0 - t) / 0.18, 0.0, 1.0), 0.6);
            // The outline thins with the streak, so both ends come to a point.
            body = clamp(w - dist + 0.5, 0.0, 1.0);
            line = clamp(w + min(1.6, 0.6 * w) - dist + 0.5, 0.0, 1.0) * clamp(2.0 * w, 0.0, 1.0);
            // The sheet trails on one side, toward the next streamline.
            float sw = 0.45 * pow(sin(3.1415927 * t), 0.6);
            sheetA = step(0.0, dl) * clamp((sw - dl) / max(grad, 1e-5) + 0.5, 0.0, 1.0);
        }
    }
    float a0 = fade * room;
    line *= a0;
    sheetA *= a0 * u.sheet;

    // Mist: wisps drawn out along the streamlines, drifting downstream slower than
    // the streaks, in faint flat tones.
    float mistA = 0.0, mistTone = 0.0;
    if (u.mist > 0.0) {
        float x = lv / 4.0;
        float across = pnoise(x, n / 4.0) * 0.6 + pnoise(x * 2.3 + 0.37 * n, n * 2.3 / 4.0) * 0.4;
        float along = 0.5 + 0.5 * sin(6.2831853 * (phi / u.dash - u.travel * 0.5 + 2.0 * across));
        float m = across * along * u.mist * fade;
        mistA = band(m, 0.32) * 0.045 + band(m, 0.45) * 0.055;
        mistTone = band(m, 0.45);
    }

    // Premultiplied layers, back to front: mist, sheets, streaks.
    vec3 col = mix(u.cRim.rgb, u.cBody.rgb, mistTone) * mistA;
    float a = mistA;
    col = mix(col, mix(u.cRim.rgb, u.cBody.rgb, 0.6), sheetA);
    a = sheetA + a * (1.0 - sheetA);
    vec3 lineCol = mix(u.cRim.rgb, u.cBody.rgb, body);
    col = mix(col, lineCol, line);
    a = line + a * (1.0 - line);
    fragColor = vec4(col, a) * keep * u.qt_Opacity;
}
