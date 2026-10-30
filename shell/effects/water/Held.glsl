// What the water held round the open launcher shares: the shader that draws it and
// the one that works out where its glints and orbs are each frame. Needs `u.radius`.
const int MIST = 22;
const int ORBS = 9;

// A point travelling clockwise along the panel's border pushed out by `dist` px.
vec2 orbit(vec2 h, float dist, float s) {
    return rrPoint(s, h + dist, u.radius + dist);
}
