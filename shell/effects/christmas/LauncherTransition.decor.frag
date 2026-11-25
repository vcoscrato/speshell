#version 440
#extension GL_GOOGLE_include_directive : enable
// Draws each piece of the strip where LauncherTransition.decor.vert puts it: flakes,
// round in the distance and six-armed crystals near; the string's dark twisted wire;
// tapered glass bulbs on their sockets, lit from inside, twinkling; the drift on the
// top edge, billowing as it settles, lit along its rim and over-hanging the edge a
// little; each bulb's glow in rings; and puffs of snow. The snow and the glow keep off
// the panel.
layout(location = 0) in vec2 p;
layout(location = 1) in vec4 piece;
layout(location = 2) in vec4 shape;
layout(location = 3) in vec4 look;
layout(location = 0) out vec4 fragColor;
#include "LauncherTransition.decor.glsl"

const vec2 LIGHT = vec2(-0.55, -0.83);

float panelDist(vec2 q) { return sdRoundRect(q - center(), halfSize(), rad()); }

vec3 bulbColor(float i) {
    return i < 0.5 ? u.cBulb0.rgb : i < 1.5 ? u.cBulb1.rgb : i < 2.5 ? u.cBulb2.rgb : i < 3.5 ? u.cBulb3.rgb : u.cBulb4.rgb;
}

// Signed distance to a teardrop along +y: a circle of r1 at the origin, one of r2 at h.
float sdUnevenCapsule(vec2 q, float r1, float r2, float h) {
    q.x = abs(q.x);
    float b = (r1 - r2) / h;
    float a = sqrt(1.0 - b * b);
    float k = dot(q, vec2(-b, a));
    if (k < 0.0)
        return length(q) - r1;
    if (k > a * h)
        return length(q - vec2(0.0, h)) - r2;
    return dot(q, vec2(a, b)) - r1;
}

vec4 flakeColor() {
    vec2 d = p - piece.xy;
    float R = piece.z;
    float a;
    if (look.z < 1.5) {
        a = cover(R - length(d));
    } else {
        // Six arms, each with a pair of twigs, round a dot.
        vec2 q = rot(d, piece.w);
        float ang = mod(atan(q.y, q.x), PI / 3.0) - PI / 6.0;
        vec2 s = length(q) * vec2(cos(ang), abs(sin(ang)));
        float arm = sdSeg(s, vec2(0.0), vec2(R, 0.0));
        float twig = sdSeg(s, vec2(0.55 * R, 0.0), vec2(0.8 * R, 0.3 * R));
        a = max(cover(0.55 - min(arm, twig)), cover(0.75 - length(q)));
    }
    vec3 col = look.z < 0.5 ? mix(u.cSnow.rgb, u.cSnowShade.rgb, 0.4) : u.cSnow.rgb;
    return vec4(col, 1.0) * a * look.y * cover(panelDist(p) - 0.5);
}

vec4 wireColor() {
    float across = abs(shape.x) * 2.6;
    // Two strands twisted together.
    float strand = fract(piece.x / 3.2 + shape.x * 0.6);
    vec3 col = mix(u.cWire.rgb, u.cWireLit.rgb, 0.7 * band(strand, 0.5) * (1.0 - band(strand, 0.85)));
    return vec4(col, 1.0) * cover(1.15 - across) * look.y;
}

vec4 bulbColorAt() {
    vec2 dir = piece.zw, n = vec2(-dir.y, dir.x);
    float s = shape.x;
    vec2 rel = (p - piece.xy) / s;
    vec2 q = vec2(dot(rel, n), dot(rel, dir));
    vec3 col = bulbColor(shape.z);
    float lit = clamp(shape.y, 0.0, 1.4);
    vec4 o = vec4(0.0);
    // The socket, a little wider at its mouth, ridged.
    float sock = max(abs(q.x) - mix(1.8, 2.25, clamp(q.y / 3.8, 0.0, 1.0)), max(-0.4 - q.y, q.y - 3.9));
    vec3 sc = mix(u.cSocket.rgb, u.cSocketLit.rgb, band(-dot(n, LIGHT) * q.x, 0.6) * 0.8);
    sc = mix(sc, u.cDark.rgb, 0.5 * cover(0.45 - abs(q.y - 2.3)));
    o = over(o, sc, cover(-sock));
    // The glass: round near the socket, tapering to a blunt point.
    float g = sdUnevenCapsule(q - vec2(0.0, 6.2), 2.9, 0.95, 4.6);
    vec3 dim = mix(col, u.cDark.rgb, 0.55);
    vec3 gc = mix(dim, col, smoothstep(0.0, 0.6, lit));
    // Shaded on the side away from the light, hot in the middle when lit.
    vec2 m = piece.xy + dir * GLASS * s;
    float side = dot(p - m, LIGHT) / s;
    gc = mix(gc, mix(gc, u.cDark.rgb, 0.4), band(-side, 1.3));
    gc = mix(gc, mix(col, u.cGlint.rgb, 0.55), lit * 0.8 * cover(-1.3 - g));
    // A window of light on the lit side.
    vec2 hp = rel - (dir * 6.6 + LIGHT * 1.35);
    float hl = length(vec2(dot(hp, dir) / 1.9, dot(hp, n) / 0.65));
    gc = mix(gc, u.cGlint.rgb, 0.85 * cover(1.0 - hl));
    o = over(o, gc, cover(-g));
    return o * shape.w;
}

// The top edge's y at x, from the panel's center, following its corners.
float edgeY(float x, vec2 h, float r) {
    float d = min(max(abs(x) - (h.x - r), 0.0), r);
    return -(h.y - r) - sqrt(max(0.0, r * r - d * d));
}

vec4 driftColor() {
    vec2 h = halfSize();
    float r = rad();
    vec2 q = p - center();
    float gone = 1.0 - smoothstep(0.0, 0.3, u.leave);
    float ye = edgeY(q.x, h, r);
    // Thinning out round the corners.
    float envX = 1.0 - smoothstep(h.x - r - 6.0, h.x - 1.0, abs(q.x));
    // Billows about 18 px apart, each settling at its own pace.
    const float S = 18.0;
    float k0 = floor(q.x / S);
    float d = 1e3;
    vec2 own = vec2(0.0);
    float ownR = 1.0;
    for (int i = -1; i <= 1; i++) {
        float k = k0 + float(i);
        float xk = (k + 0.5 + 0.55 * (hash(vec2(k, 1.7)) - 0.5)) * S;
        float Rk = mix(7.0, 13.0, hash(vec2(k, 2.9)));
        float t0 = 0.9 + 2.6 * hash(vec2(k, 4.3));
        float g = smoothstep(t0, t0 + 4.5 + 4.0 * hash(vec2(k, 6.1)), u.open);
        float envK = 1.0 - smoothstep(h.x - r - 6.0, h.x - 1.0, abs(xk));
        float Hk = mix(5.0, 11.0, hash(vec2(k, 8.3))) * g * envK * gone;
        vec2 ck = vec2(xk, edgeY(xk, h, r) - Hk + Rk);
        float dk = length(q - ck) - Rk;
        if (dk < d) {
            d = dk;
            own = ck;
            ownR = Rk;
        }
    }
    float grown = smoothstep(1.0, 8.0, u.open) * envX * gone;
    float top = min(d, (ye - 4.0 * grown) - q.y);
    // It hangs over the edge a little.
    float lip = 1.6 * grown;
    float body = max(top, q.y - (ye + lip));
    float a = cover(-body);
    vec3 col = u.cSnow.rgb;
    // Shade low down and on each billow's side away from the light, lit along its rim.
    float depthIn = max(0.0, ye - q.y);
    col = mix(col, u.cSnowShade.rgb, 0.55 * band(dot((q - own) / ownR, vec2(0.75, 0.66)), 0.5));
    col = mix(col, u.cSnowShade.rgb, cover(q.y - ye + 0.4));
    col = mix(col, u.cSnowLit.rgb, cover(1.4 + top) * step(0.6, depthIn));
    vec4 o = vec4(col, 1.0) * a;
    // Its shadow on the panel just under the lip.
    float sh = cover(q.y - (ye + lip)) * cover(ye + lip + 1.3 - q.y) * cover(-top + 0.5) * 0.35 * smoothstep(0.1, 0.4, grown);
    o = over(o, u.cDark.rgb, sh * (1.0 - a));
    return o;
}

vec4 glowColor() {
    float dist = length(p - piece.xy);
    float R = piece.z * (0.9 + 0.1 * min(shape.y, 1.0));
    float l = clamp(shape.y, 0.0, 1.6);
    float a = 0.04 * cover(R - dist) + 0.07 * cover(0.62 * R - dist) + 0.12 * cover(0.38 * R - dist);
    vec3 col = mix(bulbColor(shape.z), u.cGlint.rgb, 0.12);
    return vec4(col, 1.0) * a * l * shape.w * cover(panelDist(p) - 0.5);
}

vec4 puffColor() {
    float a = cover(piece.z - length(p - piece.xy));
    return vec4(u.cSnow.rgb, 1.0) * a * look.y * 0.85 * cover(panelDist(p) - 0.5);
}

void main() {
    float kind = look.x;
    vec4 o;
    if (kind < -0.5)
        discard;
    else if (kind < 0.5)
        o = flakeColor();
    else if (kind < 1.5)
        o = wireColor();
    else if (kind < 2.5)
        o = bulbColorAt();
    else if (kind < 3.5)
        o = driftColor();
    else if (kind < 4.5)
        o = glowColor();
    else
        o = puffColor();
    fragColor = o * u.qt_Opacity;
}
