// What LauncherTransition.decor.vert and .frag share: the uniforms, and the pieces.
// They come in one strip, back to front: the far and middle snow, the string's wire as
// a ribbon of rows along it, the bulbs, the drift on the top edge, the bulbs' glow,
// puffs of the drift, and the near snow. Every piece but the wire is a diamond of
// three rows of vertices (a point, a pair, a point), which can be any quadrilateral,
// so the joins between pieces have no area.
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 origin;        // px, this item's top-left on screen
    vec4 rect;          // px, the panel
    float radius;       // its corners' radius
    float time;         // s, for the snow and the twinkling
    float open;         // s the launcher has been open, which paces the hanging
    float leave;        // 0..1 over the exit
    float exitTime;     // s, the exit's length
    float topRuns;      // runs the string takes along the top, clipped to its edge
    float swags;        // swags it hangs in round the rest
    float bulbs;        // bulbs on it
    float hangStart;    // s open when the first run is hung
    float hangGap;      // s from one run or swag to the next
    vec4 cWire;
    vec4 cWireLit;
    vec4 cSocket;
    vec4 cSocketLit;
    vec4 cBulb0;
    vec4 cBulb1;
    vec4 cBulb2;
    vec4 cBulb3;
    vec4 cBulb4;
    vec4 cGlint;
    vec4 cDark;
    vec4 cSnow;
    vec4 cSnowShade;
    vec4 cSnowLit;
} u;
#include "../common/common.glsl"

const int FAR = 64;
const int MID = 40;
const int WIRE = 560;
const int BULBS = 128;
const int PUFFS = 28;
const int NEAR = 22;
const int ROWS = 3 * (FAR + MID) + WIRE + 3 * (BULBS + 1 + BULBS + PUFFS + NEAR);

// A bulb's length from where it leaves the wire to its tip (px), and its glass's middle.
const float BULB = 12.0;
const float GLASS = 7.4;

// The panel's half size, center, and corner radius.
vec2 halfSize() { return 0.5 * u.rect.zw; }
vec2 center() { return u.rect.xy + 0.5 * u.rect.zw; }
float rad() { return min(u.radius, 0.5 * min(u.rect.z, u.rect.w)); }
