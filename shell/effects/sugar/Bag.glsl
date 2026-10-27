// A piping bag, seen side on, shared by the knob and the launcher. Its nozzle's tip is
// at the origin and its axis runs along +x: a ridged metal star nozzle, the coupler,
// a cone of translucent plastic filled with frosting up to `level` (0..1 of the body),
// gathered into a twist, and the spare end crumpled past it. K is its scale: it is
// 1.5 K long and 0.8 K across at its widest. Light falls from its -y side. It reads
// u.cFilm, u.cMetal, u.cMetalShade, u.cFrost, u.cFrostLight, and u.cFrostShade, which
// every shader that includes it declares.

// The bag's half width at x along it: the nozzle's cone, the coupler, the body
// widening to round shoulders that gather into the twist, and the spare end.
float bagHalf(float x, float K, float squeeze) {
    if (x < 0.26 * K)
        return mix(0.045, 0.11, x / (0.26 * K)) * K;
    if (x < 0.32 * K)
        return 0.135 * K;
    if (x < 1.14 * K) {
        float t = (x - 0.32 * K) / (0.82 * K);
        float w = mix(0.12, 0.4, min(1.0, pow(t / 0.7, 0.8))) * (1.0 - 0.12 * squeeze * sin(3.1416 * t));
        float g = clamp((t - 0.7) / 0.3, 0.0, 1.0);
        return 0.07 * K + (w - 0.07) * K * sqrt(1.0 - g * g);
    }
    if (x < 1.28 * K)
        return 0.065 * K;
    return mix(0.07, 0.2, smoothstep(1.28 * K, 1.5 * K, x)) * K;
}

vec4 pipingBag(vec2 b, float K, float level, float squeeze) {
    float hb = bagHalf(b.x, K, squeeze);
    float d = max(abs(b.y) - hb, max(-b.x, b.x - 1.5 * K - K * 0.05 * zig(b.y / (K * 0.06), 3.0)));
    float aa = max(0.6, K * 0.012);
    if (d > aa)
        return vec4(0.0);
    float vv = clamp(b.y / max(hb, 0.5), -1.0, 1.0);
    // Round across: shaded away from the light, lit toward it.
    float round_ = sqrt(max(0.0, 1.0 - vv * vv));
    vec3 film = mix(u.cFilm.rgb, u.cMetalShade.rgb, 0.1 + 0.32 * band(vv, 0.35));
    vec3 c;
    float a = 1.0;
    if (b.x < 0.26 * K) {
        // The nozzle: a star tip, its ridges running down to the teeth at its end.
        float ridge = fract(asin(vv) / 3.1416 * 3.0 + 0.5);
        c = mix(u.cMetal.rgb, u.cMetalShade.rgb, band(vv, 0.15));
        c = mix(c, u.cFilm.rgb, band(-vv, 0.55));
        c = mix(c, u.cMetalShade.rgb, 0.55 * (1.0 - band(abs(ridge - 0.5), 0.34)));
    } else if (b.x < 0.32 * K) {
        // The coupler's ring.
        c = mix(mix(u.cMetal.rgb, u.cFilm.rgb, 0.3), u.cMetalShade.rgb, band(vv, 0.1));
    } else if (b.x < 1.14 * K) {
        // Frosting up to its level through the plastic, which shows clear above it;
        // the frosting's swirls pressed against the film, a long gloss on the lit side.
        float t = (b.x - 0.32 * K) / (0.82 * K);
        float lv = level + 0.04 * sin(b.y / K * 18.0);
        vec3 fr = mix(u.cFrost.rgb, u.cFrostShade.rgb, band(vv, 0.3));
        fr = mix(fr, u.cFrostLight.rgb, band(-vv, 0.45));
        float sw = fract((b.x + b.y * 1.3) / (K * 0.26));
        fr = mix(fr, mix(fr, u.cFrostShade.rgb, 0.5), band(sw, 0.8) * (1.0 - band(sw, 0.93)));
        c = t < lv ? fr : film;
        a = t < lv ? 1.0 : 0.82;
        // A crease or two in the plastic, gathering into the twist.
        float cr = abs(fract(vv * 1.5 + 0.5 + 0.2 * t) - 0.5);
        c = mix(c, u.cMetalShade.rgb, 0.3 * smoothstep(0.55, 1.0, t) * (1.0 - band(cr, 0.08)));
        c = mix(c, u.cFilm.rgb, 0.85 * cover(max(0.6, K * 0.03) - abs(vv + 0.6) * hb) * step(0.06, t) * step(t, 0.7));
    } else if (b.x < 1.28 * K) {
        // The twist.
        float ph = fract((b.x * 1.6 - b.y) / (K * 0.09));
        c = mix(film, u.cMetalShade.rgb, 0.35 * band(ph, 0.55));
    } else {
        // The spare end, crumpled into folds.
        float fold = abs(fract(atan(b.y, b.x - 1.14 * K) / 0.35) - 0.5);
        c = mix(film, u.cMetalShade.rgb, 0.3 * band(fold, 0.28));
        a = 0.9;
    }
    // Its silhouette darkens a little at the rim, as a round thing does.
    c = mix(c, c * 0.72, (1.0 - band(round_, 0.28)) * 0.7);
    return vec4(c, 1.0) * a * cover(-d);
}
