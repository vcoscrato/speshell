#version 440
#extension GL_GOOGLE_include_directive : enable
// The launcher, piped and eaten. While it is open a piping bag pipes a shell border of
// frosting clockwise round it from its top-left, just outside its edge: shells ribbed
// by the star nozzle, each swelling from a point to a round head, shaded round. The
// bag rides the border's head, leaning back and out so it never covers the panel, and
// lifts away when done; then glacé cherries are set on it one by one, each falling
// onto the shells from above, its shadow closing in, and landing with a hop. Eaten,
// bites with scalloped tooth marks take the panel and its border away, their edges
// showing the sponge inside and a line of cream.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 origin;        // px, this item's top-left on screen
    vec2 resolution;    // px, this item's size
    vec4 rect;          // px, the panel
    float radius;       // its corners' radius
    float capture;      // 1 draws the captured panel
    float pipe;         // 0..1 the bag's way round the border
    float arrive;       // 0..1 the bag coming in
    float lift;         // 0..1 the bag lifting away when done
    vec4 cherry0;       // each cherry: where it sits (px, from the panel's center),
    vec4 cherry1;       // the angle facing out there, its way down 0..1 (0: none)
    vec4 cherry2;
    vec4 cherry3;
    vec4 cherry4;
    vec4 cherry5;
    vec4 cherry6;
    vec4 cherry7;
    vec4 bite0;         // each bite: center (px), radius (px), seed
    vec4 bite1;
    vec4 bite2;
    vec4 bite3;
    vec4 cFrost;
    vec4 cFrostLight;
    vec4 cFrostShade;
    vec4 cFilm;
    vec4 cMetal;
    vec4 cMetalShade;
    vec4 cSponge;
    vec4 cCream;
    vec4 cBerry;
    vec4 cBerryDeep;
    vec4 cBerryLight;
    vec4 cStem;
} u;
layout(binding = 1) uniform sampler2D source;
#include "../common/common.glsl"
#include "Bag.glsl"

const float PI = 3.1415927;
const float OFF = 4.0;          // px the border's middle sits outside the panel
const float SHELL = 6.5;        // px, a shell's half width at its head
const float CHERRY = 8.5;       // px, a cherry's radius

// Signed distance to a bite: a round mouthful whose edge is scalloped by teeth, the
// rounds of each tooth's mark biting outward, cusps between them.
float biteDist(vec2 p, vec4 b) {
    if (b.z < 0.5)
        return 1e3;
    vec2 d = p - b.xy;
    float n = max(6.0, floor(b.z / 8.0));
    float a = atan(d.y, d.x);
    float amp = min(6.0, b.z * 0.09);
    return length(d) - b.z - amp * abs(sin(a * n * 0.5 + b.w));
}

vec2 rrNormal(vec2 q, vec2 h, float r) {
    vec2 e = vec2(0.5, 0.0);
    return normalize(vec2(sdRoundRect(q + e.xy, h, r) - sdRoundRect(q - e.xy, h, r),
                          sdRoundRect(q + e.yx, h, r) - sdRoundRect(q - e.yx, h, r)) + 1e-5);
}

// A glacé cherry over o: ch as the cherry uniforms, light the light's direction on
// screen. It falls from above, larger and its shadow apart from it, lands at 0.7
// and hops; glossy round, a dimple where its stem leaves, leaning out from the panel.
vec4 cherry(vec4 o, vec2 q, vec4 ch, vec2 light) {
    float k = ch.w;
    if (k <= 0.0 || length(q - ch.xy) > 40.0)
        return o;
    float fall = min(1.0, k / 0.7);
    float land = max(0.0, (k - 0.7) / 0.3);
    // Its height over the border: falling, then a small hop after landing.
    float z = 1.0 - fall * fall + 0.2 * sin(PI * land) * (1.0 - land);
    float R = CHERRY * (1.0 + 0.8 * z);
    float fade = smoothstep(0.0, 0.25, k);
    vec2 n = vec2(cos(ch.z), sin(ch.z));
    vec2 t = vec2(-n.y, n.x);

    // Its shadow on the frosting, apart from it and soft while it is high.
    vec2 sc = ch.xy - light * (1.5 + 16.0 * z);
    float soft = 1.0 + 5.0 * z;
    o = over(o, u.cFrostShade.rgb * 0.4, 0.5 * (1.0 - 0.6 * z) * fade * smoothstep(soft, -soft, length(q - sc) - R));

    // The body, shaded as a sphere lit from the light's side and a little above.
    vec2 pd = (q - ch.xy) / R;
    float l = length(pd);
    vec3 N = vec3(pd, sqrt(max(0.0, 1.0 - l * l)));
    float diff = max(0.0, dot(N, normalize(vec3(light, 1.1))));
    vec3 col = mix(u.cBerryDeep.rgb, u.cBerry.rgb, smoothstep(0.05, 0.8, diff));
    col = mix(col, u.cBerryLight.rgb, 0.55 * smoothstep(0.85, 1.0, diff));
    // The frosting's pink thrown back into its shaded rim.
    col = mix(col, u.cFrost.rgb, 0.35 * smoothstep(0.6, 1.0, l) * smoothstep(0.0, 0.6, dot(pd, -light) / max(l, 1e-3)));
    vec2 dimple = n * 0.25;
    col = mix(col, u.cBerryDeep.rgb, 0.55 * (1.0 - smoothstep(0.0, 0.32, length(pd - dimple))));
    // A window of light on the lit side, long across the light.
    vec2 hp = pd - light * 0.42;
    float spec = 1.0 - length(vec2(dot(hp, light) / 0.11, dot(hp, vec2(-light.y, light.x)) / 0.2));
    col = mix(col, u.cFilm.rgb, clamp(spec * R * 0.25, 0.0, 1.0));
    o = over(o, col, fade * cover(R - length(q - ch.xy)));

    // The stem, from the dimple, leaning out and bending to one side.
    float s = R / CHERRY;
    vec2 a = ch.xy + n * R * 0.25;
    vec2 m = a + n * R * 1.3;
    vec2 e = a + n * R * 2.1 + t * R * 0.9;
    float d = 1e3;
    vec2 prev = a;
    for (int j = 1; j <= 4; j++) {
        float f = float(j) / 4.0;
        vec2 b = mix(mix(a, m, f), mix(m, e, f), f);
        d = min(d, sdSeg(q, prev, b));
        prev = b;
    }
    o = over(o, u.cStem.rgb * 0.55, fade * cover(1.3 * s - d));
    o = over(o, u.cStem.rgb, fade * cover(0.65 * s - d));
    return o;
}

void main() {
    vec2 p = u.origin + qt_TexCoord0 * u.resolution;
    vec2 h = u.rect.zw * 0.5;
    vec2 c = u.rect.xy + h;
    vec2 q = p - c;
    float dr = sdRoundRect(q, h, u.radius);
    vec2 nrm = rrNormal(q, h, u.radius);
    vec2 light = normalize(vec2(-0.5, -0.85));

    // What the bites have left.
    float bd = min(min(biteDist(p, u.bite0), biteDist(p, u.bite1)), min(biteDist(p, u.bite2), biteDist(p, u.bite3)));
    float alive = cover(bd);
    vec4 o = vec4(0.0);

    // ── The panel while it is eaten, its bitten edges showing sponge ──
    if (u.capture > 0.5 && dr < 1.0) {
        vec2 uv = (p - u.rect.xy) / u.rect.zw;
        vec4 body = texture(source, uv);
        if (bd < 14.0) {
            float hole = step(0.8, hash(floor(p / 2.5)));
            vec3 sp = mix(u.cSponge.rgb, u.cSponge.rgb * 0.7, hole);
            sp = mix(sp, u.cSponge.rgb * 0.82, band(dot(-normalize(p - c + 1e-4), light), 0.4) * 0.5);
            vec4 edge = over(vec4(0.0), sp, cover(10.0 - bd));
            edge = over(edge, u.cCream.rgb, cover(1.3 - abs(bd - 6.0)));
            edge = over(edge, u.cSponge.rgb * 0.5, cover(1.0 - bd) * 0.8);
            body = edge * body.a + body * (1.0 - edge.a);
        }
        o = body * alive;
    }

    // ── The shell border, piped round to the bag ──
    float perim = rrPerimeter(h, u.radius);
    float v = dr - OFF;
    if (abs(v) < SHELL + 3.0 && u.pipe > 0.0) {
        float s = rrArc(q, h, u.radius);
        float n = floor(perim / 16.0 + 0.5);
        float P = perim / n;
        float f = fract(s / P);
        float w = SHELL * (0.3 + 0.7 * sin(PI * pow(f, 0.62)));
        float head = u.pipe * perim;
        float d = abs(v) - w;
        // Not yet piped past the bag; a round end where it is.
        if (u.pipe < 1.0)
            d = max(d, s - head);
        float lit = dot(nrm, light);
        float x = v / max(w, 0.5) * sign(lit + 0.3);
        vec3 bc = mix(u.cFrost.rgb, u.cFrostShade.rgb, band(-x, 0.3));
        bc = mix(bc, u.cFrostLight.rgb, band(x, 0.4));
        bc = mix(bc, u.cFrostShade.rgb * 0.8, band(-x, 0.8) * 0.6);
        float rib = fract(f * 3.0 + v / max(w, 0.5) * 0.45 + 0.2);
        bc = mix(bc, u.cFrostShade.rgb, 0.45 * band(rib, 0.72) * (1.0 - band(rib, 0.9)));
        vec4 b = over(vec4(0.0), u.cFrostShade.rgb * 0.7, cover(1.0 - d) * 0.75);
        b = over(b, bc, cover(-d));
        o = b * alive + o * (1.0 - b.a * alive);
    }

    // ── The cherries on the border ──
    if (dr > -20.0 && dr < 50.0) {
        vec4 ch = vec4(0.0);
        ch = cherry(ch, q, u.cherry0, light);
        ch = cherry(ch, q, u.cherry1, light);
        ch = cherry(ch, q, u.cherry2, light);
        ch = cherry(ch, q, u.cherry3, light);
        ch = cherry(ch, q, u.cherry4, light);
        ch = cherry(ch, q, u.cherry5, light);
        ch = cherry(ch, q, u.cherry6, light);
        ch = cherry(ch, q, u.cherry7, light);
        o = ch * alive + o * (1.0 - ch.a * alive);
    }

    // ── The piping bag at the head of the border, leaning back and out ──
    float bagOn = u.arrive * (1.0 - u.lift);
    if (bagOn > 0.0) {
        float head = u.pipe * perim;
        vec2 hq = rrPoint(head, h, u.radius);
        vec2 hn = rrNormal(hq, h, u.radius);
        vec2 tang = normalize(rrPoint(head + 2.0, h, u.radius) - rrPoint(head - 2.0, h, u.radius) + 1e-5);
        vec2 ax = normalize(hn * 0.8 - tang * 0.6);
        vec2 tip = c + hq + hn * (OFF + 3.0) + ax * (160.0 * (1.0 - u.arrive) + 200.0 * u.lift * u.lift);
        vec2 lq = p - tip;
        vec2 perp = vec2(ax.y, -ax.x);
        perp *= dot(perp, light) > 0.0 ? -1.0 : 1.0;
        vec2 bq = vec2(dot(lq, ax), dot(lq, perp));
        if (bq.x > -4.0 && bq.x < 130.0 && abs(bq.y) < 40.0) {
            vec4 b = pipingBag(bq, 82.0, mix(0.8, 0.3, u.pipe), 0.35) * bagOn;
            o = b + o * (1.0 - b.a);
        }
    }

    fragColor = o * u.qt_Opacity;
}
