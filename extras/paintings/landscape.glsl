// Helpers for the background paintings. Coordinates: q.x from 0 to the aspect
// ratio, q.y from 0 (bottom) to 1 (top).

// t quantized into n flat steps with antialiased edges (0..1).
float steps(float t, float n) {
    float k = 0.0;
    for (int i = 1; i < 16; i++) {
        if (float(i) >= n)
            break;
        k += band(t, float(i) / n);
    }
    return k / (n - 1.0);
}

// One star per grid cell (of `size`), shown for a fraction `keep` of the cells.
float starField(vec2 q, float size, float keep, float seed, float maxR, float minR) {
    vec2 g = floor(q / size);
    vec2 h = hash2(g + seed);
    if (hash(g + seed + 3.7) > keep)
        return 0.0;
    vec2 c = (g + 0.2 + 0.6 * h) * size;
    float r = max(minR, maxR * mix(0.25, 1.0, h.x * h.y));
    return cover(r - length(q - c)) * mix(0.45, 1.0, h.y);
}

// Coverage of the area below a skyline at height h.
float below(float h, float y) {
    return cover(h - y);
}

// Jagged mountain ridge height (0..1-ish).
float ridge(float x, float freq, float seed) {
    float n = 1.0 - abs(2.0 * vnoise(vec2(x * freq, seed)) - 1.0);
    return 0.65 * n * n + 0.35 * fbm(vec2(x * freq * 2.3, seed + 5.0));
}

// Billowing cloud or hill tops: round lobes of varying height (0..1).
float lobes(float x, float freq, float seed) {
    float s = x * freq + 0.6 * vnoise(vec2(x * freq * 0.5, seed));
    float cell = floor(s);
    float f = fract(s) * 2.0 - 1.0;
    return sqrt(max(0.0, 1.0 - f * f)) * mix(0.45, 1.0, hash(vec2(cell, seed)));
}

// Lobes over lobes: big billows with smaller ones riding on them.
float billows(float x, float freq, float seed) {
    return max(lobes(x, freq, seed), 0.55 * lobes(x + 0.37 / freq, freq * 2.3, seed + 11.0) + 0.3);
}

vec3 rgb(float r, float g, float b) {
    return vec3(r, g, b) / 255.0;
}
