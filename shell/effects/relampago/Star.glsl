// Relâmpago's comic starbursts, shared by its particles (Bits.frag), the strikes on the
// launcher's border (LauncherTransition.track.frag), and the wallpaper's
// (WallpaperTransition.frag): the spiky star each is drawn from, popping out past
// full size with backOut.

// Signed distance to a star of n spikes, valleys at radius ri, each spike reaching an
// uneven radius from ro * 0.7 to ro.
float starDist(vec2 p, float n, float ri, float ro, float seed) {
    float a = atan(p.y, p.x) / TAU * n;
    float k = floor(a);
    float d = 1e3;
    float inside = 0.0;
    for (int j = -1; j <= 1; j++) {
        float c = k + float(j);
        float v0 = c * TAU / n, v1 = (c + 1.0) * TAU / n, vt = (c + 0.5) * TAU / n;
        float rt = ro * mix(0.7, 1.0, hash(vec2(mod(c, n), seed)));
        vec2 a0 = vec2(cos(v0), sin(v0)) * ri;
        vec2 a1 = vec2(cos(v1), sin(v1)) * ri;
        vec2 tip = vec2(cos(vt), sin(vt)) * rt;
        d = min(d, min(sdSeg(p, a0, tip), sdSeg(p, tip, a1)));
        if (j == 0) {
            // Inside this spike's sector when on the inner side of both its edges.
            vec2 e0 = tip - a0, e1 = a1 - tip;
            float s0 = e0.x * (p.y - a0.y) - e0.y * (p.x - a0.x);
            float s1 = e1.x * (p.y - tip.y) - e1.y * (p.x - tip.x);
            inside = (s0 > 0.0 && s1 > 0.0) || length(p) < ri ? 1.0 : 0.0;
        }
    }
    return inside > 0.5 ? -d : d;
}
