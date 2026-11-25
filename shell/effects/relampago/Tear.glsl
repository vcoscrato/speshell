// The layout of the relâmpago wallpaper transition's bolt table
// (WallpaperTransition.tear.frag).
const int FORKS = 4;
const int EMBERS = 32;
// The embers are sorted into bands of BAND rows each frame, up to SLOTS in a band
// (WallpaperTransition.embers.frag); an ember and its tail reach REACH px above and
// below its head.
const float BAND = 16.0;
const int SLOTS = 8;
const float REACH = 16.0;
