// What the two streams circling the open launcher share: the shader that draws them
// and the one that works out their droplets each frame. Needs `u.speed`.
const int STREAMS = 2;
// Droplets per stream: three off each corner, three beads off the tail, three of spray.
const int DROPS = 18;
const float GRAVITY = 240.0;   // px/s², pulling droplets down the screen

// Head position along the border (px of arc) and its speed, for stream i. Each
// surges on its own rhythm, so the streams close in on each other and fall apart.
vec2 streamHead(float fi, float t, float P) {
    float w1 = 0.55 + 0.21 * fi, w2 = 1.31 - 0.17 * fi;
    float a1 = 0.48 * u.speed / w1, a2 = 0.22 * u.speed / w2;
    float ph = fi * 2.4;
    float head = t * u.speed + fi * P / float(STREAMS) + a1 * sin(w1 * t + ph) + a2 * sin(w2 * t + ph * 1.7);
    float vel = u.speed + a1 * w1 * cos(w1 * t + ph) + a2 * w2 * cos(w2 * t + ph * 1.7);
    return vec2(head, vel);
}
