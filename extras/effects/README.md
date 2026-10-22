# Effects

An effects directory animates the launcher, wallpaper changes, and Speshell's controls, paints the backdrop of its surfaces, and draws the clock panel's face, for any theme that names it with `effects = <name>` in its `theme.ini`. Speshell looks in `extras/effects` and `~/.local/share/speshell/effects`; a user directory replaces a shipped one of the same name. If effects fail to load, Speshell notifies and runs without them.

Every effect here has these files; a part that draws with a shader another part shares has no `.frag` of its own. Each shader sits beside the QML that draws it, under the same name:

```
<name>/
├── Effects.qml                   entry point: API version and the parts
├── LauncherTransition.qml/.frag  the launcher opening, staying open, and closing
├── WallpaperTransition.qml/.frag the change from one wallpaper to the next
├── Backdrop.qml/.frag            the still painting behind the bar, its dropdowns, and the launcher
├── Interactions.qml/.frag        the effects on Speshell's controls
├── Knob.qml/.frag                the thumb of Speshell's sliders and switches
├── Clock.qml/.frag               the clock panel's face
├── <Part>.qml/.frag              pieces the transitions use (Flames, Wind, Whip, ...)
├── <Name>.js                     color recipes several parts share (Flame, Water, Stone, Bolt)
├── common -> ../../lib           symlink that gives QML `import "common"` (EffectClock, ClockTime, Particles) and `common/Colors.js`
└── qsb/                          git-ignored: `just shaders` compiles each `<Name>.frag` to `qsb/<Name>.qsb`
```

A QML file that draws more than one shader names the others `<Qml>.<piece>.frag` (`LauncherTransition.ground.frag`); a shader several parts share is named for what it draws (`Portal.frag`, `Burn.frag`). Shaders include the shared library by relative path: `#include "../../lib/common.glsl"`. A part loads its shader as `Qt.resolvedUrl("qsb/<Name>.qsb")`.

## API

`Effects.qml` declares API version 1. Every part is optional:

```qml
import QtQuick

QtObject {
    readonly property int apiVersion: 1
    readonly property Component launcherTransition: Component { LauncherTransition {} }
    readonly property Component wallpaperTransition: Component { WallpaperTransition {} }
    readonly property Component backdrop: Component { Backdrop {} }
    readonly property Component interactions: Component { Interactions {} }
    readonly property Component knob: Component { Knob {} }
    readonly property Component clock: Component { Clock {} }
}
```

**Colors.** Every part receives `theme`, the active palette as `Theme.qml` names it (`bg`, `crust`, `text`, `accent`, `peach`, `sky`, ...). Any theme may use any effects, so take every color from it, picking slots by meaning: fire from the warm colors, water from the blues, stone from the neutrals. Blend with `mix` and `alpha` from `common/Colors.js`, brighten with `Qt.lighter` where light burns brighter than any theme color (a flame's core, foam), and take a glint or sheen from `text`, the lightest color, never pure white. `theme` is null for a moment after creation, so each color falls back to a literal until it arrives: `root.theme ? root.theme.accent : "#fe8019"`.

**Launcher transition.** Created when the launcher opens and destroyed after it hides. It fills the launcher's full-screen surface above the panel and receives:

| Property | Meaning |
|---|---|
| `panel` | The launcher panel. Capture it with a `ShaderEffectSource` (`hideSource: true`) to draw it yourself. |
| `panelRect` | The panel's geometry. It changes as the result list grows or shrinks. |
| `active` | `false` once the launcher closes; `true` again if it reopens during the exit. |
| `theme` | The active palette. |

Emit `closingFinished()` when the exit is done; Speshell hides the launcher anyway after 2.5 s. Input is ignored during the exit.

**Wallpaper transition.** Created once the new wallpaper has loaded, filling the screen above both images:

| Property | Meaning |
|---|---|
| `outgoing` | The old image, on top; at startup, the default wallpaper. Hide it (`hideSource: true`) and draw it going away. |
| `incoming` | The new image, already showing beneath. |
| `theme` | The active palette, already the new wallpaper's theme. |

Emit `finished()` when done; Speshell removes it after 5 s otherwise. Without a wallpaper transition the old image fades out.

**Backdrop.** Painted over the theme's base color and clipped to each surface's rounded shape, behind the bar, its dropdowns, and the launcher; the panels and text sit on it. Speshell paints it at least 1050 px tall (`Theme.backdropHeight`) and shows its top, so a short surface such as the bar or the launcher gets the top band of the painting: keep the busy parts low, below where text sits on a tall dropdown, and the top calm enough for a 28 px bar across a whole screen. It receives `theme`. Speshell renders it once into a texture and redraws it only when its properties change, so it must not animate. Keep it within a few percent of `theme.bg` wherever text may land: it sits behind every panel, including the calendar and the notes.

**Interactions.** Small effects where the user's hand is on Speshell: dragging a slider, flipping a switch, picking something. Created over each screen's bar and its dropdown, above their content, and given no input. It receives `theme`, and Speshell calls its functions, with points and rects in its own coordinates:

| Function | Called when |
|---|---|
| `slide(point at, real dx)` | A slider's knob, centered at `at`, moved `dx` px under the user's drag or wheel. Called for each step of the move. |
| `release(point at)` | The user let go of a slider's knob. |
| `pick(rect area, point at)` | The user picked something: an audio device (its radio dot), a segment, a menu choice, a theme, a workspace, a bar button. `at` is where the pointer clicked, which may lie outside `area` (a device row clicked on its name picks its radio dot), or the middle of `area` for a keyboard pick or a menu choice; start the effect there, since a wide control's middle can be far from the pointer. |
| `toggle(rect area, bool on)` | The user turned a switch on or off; its thumb ends at the right end of `area` when on and the left when off. |

Keep each effect brief (under a second) and small around the control; the panel stays usable under it. Draw nothing and run nothing while idle: `lib/Particles.qml` is a pool of short-lived particles whose clock runs only while one lives. Its clock follows `[Appearance] controlEffectsSpeed`, and with that at 0 Speshell does not create interactions.

**Knob.** The thumb of Speshell's sliders and switches, filling the thumb's square; it may draw outside it. It receives `theme`, `pressed`, `hovered`, `checked` (a switch's state; always `true` on a slider), and `travel`, the thumb's position along its track in px, which moves only under the user's hand: roll or spin it by that. Like the backdrop, it stays with transitions off, so animate it only while held or hovered.

**Clock.** The clock panel's face, filling a square of about 160 to 200 px. It receives `theme` and the time as `hours` (0–23), `minutes`, and `seconds`, which change once a second, and `running`, which is false in power saver: then show hours and minutes, no seconds, and keep still, since the face is redrawn only when the minute changes. `lib/ClockTime.qml` turns them into what a face draws: each hand's turns from twelve, the hour and minute hands creeping with the time and the second hand ticking into each second over a fifth of a second; `clock`, the ambient time anything else moves by; and `sinceTick`, for anything that answers the tick. The face must read at a glance at its smallest: hour and minute hands told apart by length and weight, and the hours marked. Without a clock part, Speshell draws a plain dial in the theme's colors.


Speshell destroys a transition inside its finishing signal, so nothing may run after the emit. Take time from `EffectClock`, never from your own timers or `Date`. It ticks at the frame rate of the user's power mode (`[Power] mode`, exposed as `frameRate`: every frame the display shows at `maximum`, 60 Hz at `balanced`) and follows their speed for that kind of effect (`[Appearance] launcherTransitionSpeed`, `wallpaperTransitionSpeed`, or `controlEffectsSpeed`, exposed as `timeScale`; a clock face's runs at 1), so its `clock`, `simTime`, and `dt` already run fast or slow. Never assume a frame lasts 1/60 s: a simulation that steps once per frame should step by the time since its last step, as `fire/Flames.qml` does. With transitions off, or in power saver, Speshell does not create them; power saver also drops the interactions and the knob, keeping only the still backdrop, and a still clock face.

## Style

Effects draw in flat, anti-aliased color bands for a cel-shaded look, and shape the captured panel or outgoing wallpaper with a second shader. Ambient animation while the launcher is open stays outside the panel or is masked from it. Air sets the bar for polish: layered depth, small secondary particles, and organic randomness rather than regular, repeated shapes.

## How each works

- **Cosmos** draws its solar system analytically in one shader: tilted orbits, cel-shaded planets, a ringed giant, a moon that passes behind its planet. A lens-edged portal reveals the panel and the old wallpaper. The supernova's front thickens and thins in filaments, flings comets of ejecta ahead, and leaves sparks behind.
- **Fire** runs a quarter-resolution fluid simulation through a recursive `ShaderEffectSource`, stepping once per rendered frame by the time since its last step. Each flame carries the strength it caught at, so weak flames still band from a hot base, and fuel far behind a burn front gutters out. A front as wide as the screen burns in separate jets, and the wallpaper's sheds embers, the controls' particles, off the ground behind it.
- **Air** draws streaks along the stream function of an ideal 2D flow (breeze around an ellipse, vortex, source or sink) bent by curl noise, so they never cross. Leaves and dust ride analytic orbits.
- **Water** draws tubes along a spiral and along the panel's rounded border, modulated by waves from each head, with drag-and-gravity droplets. The sheet and ripple refract the captured images; the sheet's and the clock's caustics are bands of the gap between the nearest two Voronoi distances, so lines swell and gather where three cells meet, warped at two scales. The whip thins to beads that pinch off, and spray and droplets cycle in and out so nothing pops. Orbs, currents, and mist travel along the border pushed outward, so they never cross the panel.
- **Earth** builds the wallpaper's shards from Voronoi cells in log-polar space around the impact, so they grow from rubble to slabs, with cracks timed along the rays and then across them; the slab and its crumbling chunks from Voronoi cells; and boulders as lopsided convex polyhedra, cut by jittered planes and traced along the view, whose edges are the nearest line where a front plane meets a back one; they tumble in 3D, each face one flat tone carried smoothly along a dark-to-light ramp by its normal against one light.
- **Relâmpago** draws the racing panel from its capture squashed and stretched by a spring on its speed, trailing a solid red streak split into fingers at its tail, and a bolt-edged ribbon: a centerline that slants along each run and jumps back by less than the ribbon's width, so the edges step. The bolts on the sliders and the backdrop are polylines of uneven runs, drawn by their distance to the nearest few segments so the corners stay whole. Speed lines are dashes in hashed rows at three depths; arcs along the border follow `rrArc` with piecewise-linear noise for their kinks. Sparks, smoke, starbursts, lightning strikes, arcs, and glints are particles; a strike draws from its item's top, so turning the item aims it. The wallpaper tears along a polyline bolt, seeded anew each time; each half is sampled crisp, and its distance from the edge, corrected for the edge's slope, inks and heats the edge.

The backdrops are a nebula lane, banked flames, cloud banks with curling wind, an underwater view, rock strata with jade, and asphalt with a checkered flag and a forked bolt.

The clock faces are each one shader: an orrery whose planets, lit from the sun at the middle, are the hands, and a comet the seconds; a charcoal dial cracked with embers inside a ring of flames from flickering noise, with forged blades for hands; a sky of drifting cloud banks with dashes of wind along spiral streamlines, a compass rose, a leaf and a feather for hands, and a leaf that tumbles round with the seconds; a pool with drifting caustics, glassy currents for hands round a whirlpool, and rings that spread from each second's drop; a disc of bent strata with faceted jade at the hours, a pale stone hour hand and a jade minute hand, and a gold pebble in a carved groove; and a tachometer with a redline, needles on a checkered cap, and a bolt that takes a new shape each second and crackles until the next.


On the controls, each effect spawns particles from `lib/Particles.qml`, each a small `ShaderEffect` that draws one kind of bit by its age: star dust, glints, and constellations that draw themselves star by star; flames standing on a burning streak, sparks, embers, flashes of ignition, and smoke; a plume of breath that blows a dragged knob along (one shader per direction, not particles), wisps, leaves, and curls of wind; drops that drip off, leap in, or fly off to land in ripples, and crown splashes with the jet that follows; rock chips, pebbles that bounce where they land, grit, and dust; sparks, arcs, starbursts, lightning strikes, glints, and tire smoke. Each knob is one small shader turned by its travel, clockwise as it moves right, as a ball rolls: a planet whose moon orbits, an ember, a ball of wind, a drop that stretches by how far a spring-damped copy of its travel lags behind, a faceted stone that rolls, and a racing wheel that blurs by how far a spring-damped copy of its travel lags, and reaches back to the track's start to draw a stepped bolt decal along the fill.

## Cost

GPU time per frame at 1080p on an RTX 3070, measured before `just bench` with a method that read low; `just bench -m` prints a fresh one, best on a GPU that isn't slowing down for heat:

| Effects | Launcher open | Launcher entrance and exit | Wallpaper | Controls | Clock face |
|---|---|---|---|---|---|
| Cosmos | 0.09 ms | 0.09 ms | 0.01 ms | 0.13 ms | 0.06 ms |
| Fire | 0.33 ms | 0.29 ms | 0.20 ms | 0.21 ms | 0.10 ms |
| Air | 0.19 ms | 0.26 ms | 0.26 ms | 0.08 ms | 0.09 ms |
| Water | 0.41 ms | 0.31 ms | under 0.07 ms | 0.11 ms | 0.09 ms |
| Earth | 0.39 ms | 0.48 ms | 0.23 ms | 0.10 ms | 0.02 ms |
| Relâmpago | 0.08 ms | 0.08 ms | 0.19 ms | 0.08 ms | 0.02 ms |

The controls column is the whole controls scene, its backdrop included, while effects play; the clock face column is the clock scene, a face at the panel's size and one at twice it, ticking. Nothing runs while the launcher is hidden, the wallpaper is still, no control effect is playing, and the clock panel is closed. The backdrop renders once when a surface first shows or the theme changes. Re-measure after a change and update this table.
