#version 440
#extension GL_GOOGLE_include_directive : enable
// One of the boulders held aloft around the open launcher: a faceted rock that rises
// out of the ground, bobs and tumbles slowly while the launcher is open, and drops
// back when it closes. It is a lopsided convex polyhedron, cut by planes around a
// squashed sphere and traced straight along the view, that tumbles slowly in 3D;
// each face is one flat tone, carried smoothly along a dark-to-light ramp by how it
// meets a single light at the top left, so faces turn through the light as the rock
// rolls instead of jumping between a few shades. A ring of dust turns under the
// bigger ones and pebbles circle them.
layout(location = 0) in vec2 p;
layout(location = 0) out vec4 fragColor;
#include "Boulders.glsl"

// Toward the light: up and to the left, and out of the screen.
const vec3 LIGHT3 = vec3(-0.42, -0.62, 0.66);
const int FACES = 14;

// A small five-sided chip at `lp` (its own frame): signed distance, < 0 inside.
float chip(vec2 lp, float size, float seed) {
    float d = -1e3;
    for (int k = 0; k < 5; k++) {
        float fk = float(k);
        float th = (fk + 0.4 * hash(vec2(seed, fk))) * 1.2566371;
        d = max(d, dot(lp, vec2(cos(th), sin(th))) - size * (0.8 + 0.35 * hash(vec2(fk, seed))));
    }
    return d;
}

// Draws a chip at `pos`, tumbling at `ang`, lit from `light`, in the given tones.
void drawChip(inout vec3 col, inout float a, vec2 p, vec2 pos, float size, float ang, float seed,
              vec2 light, vec3 lit, vec3 shade, float alpha) {
    vec2 o = p - pos;
    if (dot(o, o) > size * size * 2.5)
        return;
    vec2 lp = rot(ang) * o;
    float d = chip(lp, size, seed);
    // Top-lit: the half facing the light is the light tone.
    vec3 c = mix(shade, lit, cover(dot(o, light) / max(size, 1.0) + 0.1));
    vec3 withEdge = mix(u.cEdge.rgb, c, cover(-d - 1.0));
    over(col, a, withEdge, cover(-d + 0.6) * alpha);
}

// Rotation by Euler angles about x, then y, then z.
mat3 rot3(vec3 e) {
    vec3 c = cos(e), s = sin(e);
    mat3 rx = mat3(1.0, 0.0, 0.0, 0.0, c.x, s.x, 0.0, -s.x, c.x);
    mat3 ry = mat3(c.y, 0.0, -s.y, 0.0, 1.0, 0.0, s.y, 0.0, c.y);
    mat3 rz = mat3(c.z, s.z, 0.0, -s.z, c.z, 0.0, 0.0, 0.0, 1.0);
    return rz * ry * rx;
}

vec3 hash3(float x) {
    return vec3(hash(vec2(x, 1.3)), hash(vec2(x, 2.9)), hash(vec2(x, 4.7)));
}

// A face's flat tone: its light along the stone's dark-mid-light ramp, nudged a
// little by `id` so neighbors facing alike still part.
vec3 stoneTone(vec3 n, float id) {
    float t = clamp(smoothstep(0.0, 1.0, dot(n, LIGHT3)) + 0.06 * (hash(vec2(id, 8.1)) - 0.5), 0.0, 1.0);
    return t < 0.5 ? mix(u.cDark.rgb, u.cMid.rgb, t * 2.0)
                   : mix(u.cMid.rgb, u.cLight.rgb, t * 2.0 - 1.0);
}

void main() {
    int i = int(u.piece);
    float fi = u.piece;
    float size, seed, rise, drop;
    vec2 pos = boulder(i, size, seed, rise, drop);
    vec3 col = vec3(0.0);
    float a = 0.0;
    vec2 light = normalize(vec2(-0.45, -1.0));

    vec2 rel = p - pos;
    float above = smoothstep(0.75, -0.75, p.y - u.ground);

    // Pebbles on tilted orbits: drawn behind the boulder on the far side of
    // their orbit and in front of it on the near side.
    int moons = size > 20.0 ? 2 : (size > 13.0 ? 1 : 0);
    vec2 moonPos[2];
    float moonNear[2];
    for (int m = 0; m < 2; m++) {
        float fm = float(m);
        float th = u.time * (1.3 - 0.35 * fm) * (mod(fi, 2.0) < 1.0 ? 1.0 : -1.0) + seed + fm * 2.6;
        float orbitR = size * (1.65 + 0.45 * fm);
        moonPos[m] = pos + rot(0.35 * (fm - 0.5) + 0.2 * sin(seed)) * vec2(cos(th), 0.38 * sin(th)) * orbitR;
        moonNear[m] = sin(th);
    }
    for (int m = 0; m < 2; m++) {
        if (m < moons && moonNear[m] < 0.0)
            drawChip(col, a, p, moonPos[m], mix(4.2, 3.2, float(m)) * rise * (1.0 - drop), u.time * 2.0 + float(m),
                     fi * 3.0 + float(m), light, u.cMid.rgb, u.cDark.rgb, above);
    }

    // Grit trickling from under the bigger rocks while they hover.
    if (size > 13.0 && rise >= 1.0 && drop <= 0.0 && abs(rel.x) < size && rel.y > 0.0 && rel.y < size + 50.0) {
        for (int j = 0; j < 3; j++) {
            float fj = float(j);
            float age = fract(u.time / 1.7 + fj / 3.0 + seed);
            float cycle = floor(u.time / 1.7 + fj / 3.0 + seed);
            vec2 g = vec2((hash(vec2(fi + fj, cycle)) - 0.5) * size, size * 0.6 + 50.0 * age * age);
            float gs = mix(3.2, 1.6, age);
            float grain = cover(gs - max(abs(rel.x - g.x), abs(rel.y - g.y))) * (1.0 - age * age);
            over(col, a, u.cLight.rgb, grain);
        }
    }

    // A ring of dust kicked up under each bigger rock, turning slowly.
    if (size > 13.0 && abs(rel.y - size * 1.15) < size * 0.6 && abs(rel.x) < size * 1.8) {
        vec2 er = vec2(rel.x / 1.45, (rel.y - size * 1.15) / 0.32) / size;
        float ring = abs(length(er) - 1.0) * size;
        float ra = atan(er.y, er.x);
        float gaps = step(0.42, vnoise(vec2(ra * 2.5 - u.time * 1.4 * (mod(fi, 2.0) * 2.0 - 1.0), fi * 3.0)));
        over(col, a, mix(u.cLight.rgb, u.cMid.rgb, step(0.0, er.y)), cover(1.6 - ring) * gaps * 0.45 * rise * (1.0 - drop) * above);
    }

    if (dot(rel, rel) <= size * size * 2.8) {
        // Screen x right, y down, z toward the viewer. The rock is the set of
        // points behind every one of its planes; along this pixel's view line,
        // planes facing the viewer cap its depth from above and the others from
        // below, so it is here where the lowest cap clears the highest floor, and
        // the face seen is the plane of that lowest cap. Each bound is linear in
        // the pixel, so its gradient turns depth gaps into px for the edges.
        mat3 M = rot3(vec3(seed + u.time * (hash(vec2(fi, 2.3)) - 0.5) * 0.9,
                           seed * 1.7 + u.time * (hash(vec2(fi, 4.1)) - 0.5) * 0.8,
                           seed * 0.6 + u.time * (hash(vec2(fi, 5.9)) - 0.5) * 0.7));
        vec3 squash = vec3(1.15, 0.85, 0.95) * mix(vec3(0.9), vec3(1.1), hash3(fi + 9.0));
        float bounds[FACES];
        vec2 grads[FACES];
        vec3 norms[FACES];
        float top = 1e9, kTop = 0.0;
        vec2 gTop = vec2(0.0);
        vec3 nTop = vec3(0.0, 0.0, 1.0);
        for (int k = 0; k < FACES; k++) {
            float fk = float(k);
            // Spread round the sphere, jittered per rock.
            float z = 1.0 - 2.0 * (fk + 0.5) / float(FACES);
            float ph = fk * 2.3999632 + 1.2 * (hash(vec2(fi, fk + 11.0)) - 0.5);
            vec3 n0 = normalize(vec3(sqrt(1.0 - z * z) * vec2(cos(ph), sin(ph)), z)
                                + 0.25 * (hash3(fi * 17.0 + fk) - 0.5));
            float reach = size * length(n0 * squash) * (0.86 + 0.18 * hash(vec2(fk, fi + 3.0)));
            vec3 n = M * n0;
            n.z = abs(n.z) < 1e-3 ? 1e-3 : n.z;
            bounds[k] = (reach - dot(n.xy, rel)) / n.z;
            grads[k] = -n.xy / n.z;
            norms[k] = n;
            if (n.z > 0.0 && bounds[k] < top) {
                top = bounds[k]; gTop = grads[k]; nTop = n; kTop = fk;
            }
        }
        // The face seen is where the top cap stays lowest: its nearest seam is the
        // nearest line where another cap passes under it, and its share of the
        // rock's outline the nearest line where a floor passes over it.
        float d = 1e9, seam = 1e9, kNext = kTop;
        vec3 nNext = nTop;
        for (int k = 0; k < FACES; k++) {
            float gap = (bounds[k] - top) / max(length(grads[k] - gTop), 1e-3);
            if (norms[k].z < 0.0)
                d = min(d, -gap);
            else if (float(k) != kTop && gap < seam) {
                seam = gap; nNext = norms[k]; kNext = float(k);
            }
        }
        // Seen along the view, the rock is where every cap clears every floor: a
        // convex polygon, each pair of a cap and a floor one of its half-planes.
        // Only when a seam lies nearer than this face's own edge can another face
        // end the rock sooner (one seen edge-on, say); then take the nearest line
        // of any pair. A pixel past any line by a pixel or more is clear of it.
        if (d > -1.0 && seam < min(d, 2.0)) {
            for (int i = 0; i < FACES; i++) {
                for (int j = 0; j < FACES; j++) {
                    if (norms[i].z > 0.0 && norms[j].z < 0.0)
                        d = min(d, (bounds[i] - bounds[j]) / max(length(grads[i] - grads[j]), 1e-3));
                }
            }
        }
        if (d > -1.0) {
            vec3 face = mix(stoneTone(nNext, fi * 31.0 + kNext), stoneTone(nTop, fi * 31.0 + kTop), clamp(seam + 0.5, 0.0, 1.0));
            // A fine ridge where two faces meet, on the bigger rocks.
            face = mix(face, mix(face, u.cEdge.rgb, 0.3), clamp(1.0 - seam, 0.0, 1.0) * step(14.0, size));
            vec3 c = mix(u.cEdge.rgb, face, clamp(d - 0.9, 0.0, 1.0));
            over(col, a, c, clamp(d + 0.5, 0.0, 1.0) * above);
        }
    }

    for (int m = 0; m < 2; m++) {
        if (m < moons && moonNear[m] >= 0.0)
            drawChip(col, a, p, moonPos[m], mix(4.2, 3.2, float(m)) * rise * (1.0 - drop), u.time * 2.0 + float(m),
                     fi * 3.0 + float(m), light, u.cLight.rgb, u.cMid.rgb, above);
    }

    fragColor = vec4(col, a) * shown(p) * u.qt_Opacity;
}
