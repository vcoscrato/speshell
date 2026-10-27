.pragma library

// Color helpers for effects, which take every color from the `theme` they receive.

// a blended toward b by t (0..1), opaque.
function mix(a, b, t) {
    return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1);
}

// c with alpha a.
function alpha(c, a) {
    return Qt.rgba(c.r, c.g, c.b, a);
}
