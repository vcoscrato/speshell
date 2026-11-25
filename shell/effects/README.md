# Effects

An effects directory animates the launcher, wallpaper changes, and Speshell's controls, paints the backdrop of its surfaces, and draws the clock panel's face, for any theme that names it with `effects = <name>` in its `theme.ini`. Speshell looks in its own `effects/` (`/usr/share/speshell/effects` when installed) and `~/.local/share/speshell/effects`; a user directory replaces a shipped one of the same name. If effects fail to load, Speshell notifies and runs without them.

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
├── <Name>.glsl                   GLSL the shaders of one part share: uniforms, placement, constants
├── <Name>.js                     color recipes several parts share (Cosmos, Flame, Water, Stone, Bolt, Sugar)
├── common -> ../common           symlink that gives QML `import "common"` (the types below) and `common/Colors.js`
└── qsb/                          git-ignored: `just shaders` compiles each `<Name>.frag` to `qsb/<Name>.qsb`, and each `<Name>.vert` to `qsb/<Name>.vert.qsb`
```

A QML file that draws more than one shader names the others `<Qml>.<piece>.frag` (`LauncherTransition.ground.frag`); a shader several parts share is named for what it draws (`Portal.frag`, `Burn.frag`). Shaders include the shared library by relative path: `#include "../common/common.glsl"`, which defines `PI` and `TAU`, noise, distances, and a clock face's angles (`at`, `turnOf`, `handFrame`). A part loads its shader as `Qt.resolvedUrl("qsb/<Name>.qsb")`. A vertex shader defines `VERTEX_SHADER` before its includes, which leaves out the helpers that need derivatives (`band`, `cover`).

Speshell must run smoothly on an integrated GPU, so a shader that fills the screen must not loop over every piece of the effect for every pixel. Work that does not depend on the pixel goes where it runs once:

- **Pieces on their own quads.** Many small things (debris, shards, boulders) each get a quad, or a box or diamond in one strip of a `GridMesh`, that a vertex shader fits to where the piece is, so a pixel pays only for the pieces over it; one strip draws many pieces at once, where an item for each would cost a draw apiece: `air/Debris.vert`, `earth/Boulders.vert`, `earth/WallpaperTransition.vert`.
- **Tables.** What is the same for every pixel this frame (where droplets are), or for the whole transition (a layout, a path), is drawn once by a small `ShaderEffect` into a float `ShaderEffectSource` (`format: ShaderEffectSource.RGBA32F`, `smooth: false`, `hideSource: true`, an explicit `textureSize`) that the main shader reads: `water/LauncherTransition.drops.frag`, `relampago/WallpaperTransition.tear.frag`.
- **Low resolution.** A smooth field is drawn small and read back filtered: `air/Wind.drift.frag`.

`hash()` is chaotic enough that two shaders compiled apart can round it differently, so make each random choice in one shader and read it from there.

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

**Colors.** Every part receives `theme`, the active palette as `Theme.qml` names it (`bg`, `crust`, `text`, `accent`, `peach`, `sky`, ...). Any theme may use any effects, so take every color from it, picking slots by meaning: fire from the warm colors, water from the blues, stone from the neutrals. Blend with `mix` and `alpha` from `common/Colors.js`, brighten with `Qt.lighter` where light burns brighter than any theme color (a flame's core, foam), and take a glint or sheen from `text`, the lightest color, never pure white. Speshell sets `theme` just after creating a part, before it draws; declare it as `property var theme: Colors.fallback`, Cosmos's palette by the same names, so colors read from it from the start. The stages below declare it already.

**Stages.** Three types in `common/` carry what parts of a kind share, so a part declares only its own:

- `LauncherStage`: the launcher transition's API, an `EffectClock` as `clock`, the panel captured as `panelTexture` while `capturing` (by default while it comes and goes), and the usual timing. While `active`, `enter` runs 0..1 over `enterTime`, once a reopen mid-exit has run `leave` back to 0; once not, `leave` runs 0..1 over `exitTime`, and `tailTime` after it ends, and while nothing is `lingering`, it emits `closingFinished()`. `advanced(dt)` follows each step, for the part's own.
- `WallpaperStage`: the wallpaper transition's API, `clock`, the old wallpaper captured once as `outgoingTexture`, and `finished()` once `clock.clock` reaches `duration`; progress is a binding on `clock.clock`.
- `Face`: a clock face drawn by one shader, which gets the time as uniforms: `area`, its size; `hourTurn`, `minuteTurn`, and `secondTurn`, from `ClockTime`; `ticking`, 1 while the second hand runs; `sinceTick`; and `time`. A face sets its colors and `fragmentShader`.

**Launcher transition.** Created when the launcher opens and destroyed after it hides. It fills the launcher's full-screen surface above the panel and receives:

| Property | Meaning |
|---|---|
| `panel` | The launcher panel. Capture it with a `ShaderEffectSource` (`hideSource: true`) to draw it yourself. |
| `panelRect` | The panel's geometry. It changes as the result list grows or shrinks. |
| `panelRadius` | The panel's corner radius. |
| `active` | `false` once the launcher closes; `true` again if it reopens during the exit. |
| `theme` | The active palette. |

Emit `closingFinished()` when the exit is done; Speshell hides the launcher anyway after 2.5 s. Input is ignored during the exit.

The lock and login screens play the same transition on their password card, the panel then: it comes in as the screen appears, plays round the card while it shows, and leaves once the password is accepted, the session unlocking or starting when it emits `closingFinished()` (after 2.5 s at most). The card is smaller than the launcher, about as wide as a panel and a few rows tall, so the transition must look right on any `panelRect`.

**Wallpaper transition.** Created once the new wallpaper has loaded, filling the screen above both images:

| Property | Meaning |
|---|---|
| `outgoing` | The old image, on top; at startup, the default wallpaper; and when a change cuts the last transition short, the frame that was on screen. Hide it (`hideSource: true`) and draw it going away. |
| `incoming` | The new image, already showing beneath. |
| `theme` | The active palette, already the new wallpaper's theme. |

Emit `finished()` when done; Speshell removes it after 5 s otherwise. Without a wallpaper transition the old image fades out. The theme gallery plays it too, whenever it previews the theme, often several in a row, each over the last cut short; capture `outgoing` once, as it starts.

**Backdrop.** Painted over the theme's base color and clipped to each surface's rounded shape, behind the bar, its dropdowns, and the launcher; the panels and text sit on it. Speshell paints it at least 1050 px tall (`Theme.backdropHeight`) and shows its top, so a short surface such as the bar or the launcher gets the top band of the painting: keep the busy parts low, below where text sits on a tall dropdown, and the top calm enough for a 28 px bar across a whole screen. It receives `theme`. Speshell renders it once into a texture and redraws it only when its properties change, so it must not animate. Keep it within a few percent of `theme.bg` wherever text may land: it sits behind every panel, including the calendar and the notes.

**Interactions.** Small effects where the user's hand is on Speshell: dragging a slider, flipping a switch, picking something. Created over each screen's bar and its dropdown, above their content, and given no input. It receives `theme`, and Speshell calls its functions, with points and rects in its own coordinates:

| Function | Called when |
|---|---|
| `slide(point at, real dx)` | A slider's knob, centered at `at`, moved `dx` px under the user's drag or wheel. Called for each step of the move. |
| `release(point at)` | The user let go of a slider's knob. |
| `pick(rect area, point at)` | The user picked something: an audio device (its radio dot), a segment, a menu choice, a theme, a workspace, a bar button. `at` is where the pointer clicked, which may lie outside `area` (a device row clicked on its name picks its radio dot), or the middle of `area` for a keyboard pick or a menu choice; start the effect there, since a wide control's middle can be far from the pointer. |
| `toggle(rect area, bool on)` | The user turned a switch on or off; its thumb ends at the right end of `area` when on and the left when off. |

Keep each effect brief (under a second) and small around the control; the panel stays usable under it. Draw nothing and run nothing while idle: `common/Particles.qml` is a pool of short-lived particles whose clock runs only while one lives; `emit(kind, p)` starts one of a kind with a random `seed`, and `rnd(a, b)` picks a number for it. Its clock follows `[Appearance] controlEffectsSpeed`, and with that at 0 Speshell does not create interactions.

**Knob.** The thumb of Speshell's sliders and switches, filling the thumb's square; it may draw outside it. It receives `theme`, `pressed`, `hovered`, `checked` (a switch's state; always `true` on a slider), and `travel`, the thumb's position along its track in px, which moves only under the user's hand: roll or spin it by that. A knob that declares `property point pointer` is also told where the pointer is while it moves over the control, in the knob's own coordinates. A knob that declares `property rect switchArea` is told, on a switch, the whole switch in its own coordinates, so it can draw the switch's body as well as its thumb; it stays empty on a slider. Like the backdrop, it stays with transitions off, so animate it only while held or hovered.

**Clock.** The clock panel's face, filling a square of about 160 to 200 px, and the theme gallery's preview of the theme, up to 400 px, where it is created for a theme that is not yet in use. It receives `theme` and the time as `hours` (0–23), `minutes`, and `seconds`, which change once a second, and `running`, which is false in power saver: then show hours and minutes, no seconds, and keep still, since the face is redrawn only when the minute changes. `common/ClockTime.qml` turns them into what a face draws: each hand's turns from twelve, the hour and minute hands creeping with the time and the second hand ticking into each second over a fifth of a second; `clock`, the ambient time anything else moves by; and `sinceTick`, for anything that answers the tick. The face must read at a glance at its smallest: hour and minute hands told apart by length and weight, and the hours marked. Without a clock part, Speshell draws a plain dial in the theme's colors.


Speshell destroys a transition inside its finishing signal, so nothing may run after the emit. Take time from `EffectClock`, never from your own timers or `Date`. It ticks at the frame rate of the user's power mode (`[Power] mode`, exposed as `frameRate`: every frame the display shows at `maximum`, 60 Hz at `balanced`) and follows their speed for that kind of effect (`[Appearance] launcherTransitionSpeed`, `wallpaperTransitionSpeed`, or `controlEffectsSpeed`, exposed as `timeScale`; a clock face's runs at 1), so its `clock`, `simTime`, and `dt` already run fast or slow. Never assume a frame lasts 1/60 s: a simulation that steps once per frame should step by the time since its last step, as `fire/Flames.qml` does. With transitions off, or in power saver, Speshell does not create them; power saver also drops the interactions and the knob, keeping only the still backdrop, and a still clock face.

## Style

Effects draw in flat, anti-aliased color bands for a cel-shaded look, and shape the captured panel or outgoing wallpaper with a second shader. Ambient animation while the launcher is open stays outside the panel or is masked from it. Air sets the bar for polish: layered depth, small secondary particles, and organic randomness rather than regular, repeated shapes.

## How each works

- **Cosmos** draws its orrery analytically in one shader. The panel stands in the tilted plane like a card on a table, the plane's center set below the panel's by just enough that every orbit's near half passes below the panel and its far half behind it, where the planets slip out of sight; nearer planets are larger. Each planet is a sphere lit from the panel's middle in three flat tones, nearly full behind the panel and half lit in front, with a surface of its own from noise in its longitude and latitude as it turns: pocked rock, swirled bands, ocean with land and caps, rust with a cap, and a banded giant with a storm inside its rings. Orbit lines brighten along the trail behind each planet. Belt dust is one speck to a cell of a grid in angle and radius, each row drifting at its own pace and thinned by waves that fit the belt a whole number of times, so it clumps without a seam. The comet rides its own small item along a parabola timed by Barker's equation, so it creeps in from far out and swings round under the panel, a small head in a coma of soft rings, its dust tail curving back along its path as it widens and fades, and a faint ion tail straight away from the light. A lens-edged portal reveals the panel and the old wallpaper. The supernova's front thickens and thins in filaments, flings comets of ejecta ahead, and leaves sparks behind.
- **Fire** runs a quarter-resolution fluid simulation through a recursive `ShaderEffectSource`, stepping once per rendered frame by the time since its last step. Each flame carries the strength it caught at, so weak flames still band from a hot base, and fuel that loses its heat draws in rather than lingering as a flat patch. The launcher's rim is a low bed along the panel's top with tongues of their own heights rising out of it, and behind them a deeper row, a second density with its own slower flow shaded in duller bands; it catches as the entrance front reaches it, and burns down into the edge, tips first, as the launcher closes. Each step lays a moving front's fuel over all the ground it crossed since the last, so a fast front's flames don't rise in ribs. The closing hole and a front as wide as the screen burn in separate jets that gutter out just behind them; the wallpaper's leaves char that clears in steps behind it, and sheds embers, the controls' particles, off that ground.
- **Air** draws streaks along the stream function of an ideal 2D flow (breeze around an ellipse, vortex, source or sink) bent by curl noise, so they never cross. Leaves and dust ride analytic orbits.
- **Water** draws tubes along a spiral and along the panel's rounded border, modulated by waves from each head, with drag-and-gravity droplets. The sheet and ripple refract the captured images; the sheet's and the clock's caustics are bands of the gap between the nearest two Voronoi distances, so lines swell and gather where three cells meet, warped at two scales. The whip thins to beads that pinch off, and spray and droplets cycle in and out so nothing pops. Orbs, currents, and mist travel along the border pushed outward, so they never cross the panel.
- **Earth** builds the wallpaper's shards from Voronoi cells in log-polar space around the impact, so they grow from rubble to slabs, with cracks timed along the rays and then across them; the slab and its chunks from the same Voronoi cells as the cracks drawn between them, breaking off in order of distance from where it landed plus noise, so no front sweeps across it; and boulders as lopsided convex polyhedra, cut by jittered planes and traced along the view, whose edges are the nearest line where a front plane meets a back one; they tumble in 3D, each face one flat tone carried smoothly along a dark-to-light ramp by its normal against one light. The boulders, the far stones and motes, and the dust bands, each a strip along the arc it covers, are boxes in three meshes, and the slab's crumbs and the ground's chips boxes after the slab and the ground's band in theirs, all fitted by vertex shaders that also work out the landing's cracks and the dust puffs once rather than for every pixel.
- **Relâmpago** draws the racing panel from its capture squashed and stretched by a spring on its speed, trailing a solid red streak split into fingers at its tail, and a bolt-edged ribbon: a centerline that slants along each run and jumps back by less than the ribbon's width, so the edges step. The bolts on the sliders and the backdrop are polylines of uneven runs, drawn by their distance to the nearest few segments so the corners stay whole; a strike's bolt kinks unevenly, leans, tapers to a point, and splays short kinked forks off its corners. Speed lines are wedges that taper from a round head, in hashed rows at three depths, thinned into gusts by noise along each row; arcs along the border follow `rrArc` with piecewise-linear noise for their kinks, re-rolled as they flicker. A bolt strikes the open launcher's top from the sky and lands bare, and the track, which masks the panel, draws where it hits: a starburst popping out of the border and arcs trailing two fronts that race away round it. Sparks, smoke, starbursts, lightning strikes, arcs, and glints are particles; smoke is lumps that swell, rise, drift apart, and shrink away each at its own time; a strike draws from its item's top, so turning the item aims it. The wallpaper tears along a polyline bolt, seeded anew each time, with its forks worked out into the same table; the bolt is drawn by its distance to the path's runs between rows 24 px apart, exact round its corners, banded inside its ink and lighting what lies round it. As it lands the image turns to a halftone impact frame, its dots as big as the image is dark, and shakes; each half is then flung out and tipped about its bottom outer corner, sampled crisp through that transform, and its distance from the edge, corrected for the edge's slope, inks, scorches, and heats the edge, while arcs snap across the gap under the halves, and for its first moments speed streaks hug the edges and sparks fly as teardrops along their velocity, gone before they could litter the new wallpaper.
- **Sugar** pipes the launcher's border while it is open, the panel live under it, as shells along `rrArc`, each swelling from a point to a round head over a period that divides the perimeter, so the loop has no seam, and each a little fuller or leaner and leaning its own way, hashed by its index round the loop; the bag rides the head along `rrPoint`, leaning back along the border and out from the panel so it never covers it; then glacé cherries fall onto the border one by one, each a sphere of its own size lit by one light, its stem bending its own way, larger and its shadow further off while it is high. The bites are discs whose radius is scalloped by `abs(sin)` of the angle, so tooth marks bite outward with cusps between, snapping a little past their size; the last reaches the panel's furthest corner. The glaze's front runs at a pace that varies along the screen, with tongues racing ahead; each drip, a capsule hanging from it, joins it by a smooth minimum that fillets where they meet, and a bead at some tips joins its drip the same way, drawing out a neck before it falls as a teardrop with a droplet behind. Its surface is a height made from the distance to that edge, a rim that crests and dips before the flat, tilted by slow folds that move with the flow, and lit in bands from one light, so the rim, the drips, and the sheen all shade alike; its tail thins to translucent steps under round-topped runnels. The knob is one shader reaching back to the track's start: the piped border is shells whose half height swells from a point to a round head each period, ending in a kiss, a dome smoothly joined to a tapering peak. The bag, shared with the launcher as `Bag.glsl`, is a profile of half widths along its axis (nozzle, coupler, body, twist, crumpled end); it comes down as the knob's `pointer` nears, and when the knob comes well back from the furthest it went, so a trembling hand never swaps them, an offset spatula takes its place. On a switch, the knob draws the whole switch from its `switchArea` as an éclair: choux fluted along its length, and fondant from its left end to a lip that leads the chocolate disc by the disc's share of its travel, so it covers the éclair when on and none of it when off.
- **Christmas** draws the launcher's captured panel under frost feathers, which melt from many seeds that start at different moments, each hole edged in light. The frost leaves feathers rooted on the border, fanning out at the corners. All the decoration is one strip of quads fitted by a vertex shader: snow at three depths with a breeze and a sway; the wire, a ribbon of rows that is laid hook to hook, sags as it goes and springs into lopsided swags; tapered bulbs that light down each swag and twinkle; the drift's billows; glow in rings; and the near snow. Closing, paper flaps swing up and fold over, a ribbon wraps both ways, a bow pops, and the package lifts away while the hooks let go in turn. The wallpaper's frost is worked out once into a half-float table: crystals at the corners, edges and inner specks grow fans of curved spines with forward-leaning branches and barbs, each with its own speed, so taking the earliest time over all of them makes the front a dendrite, filled behind by blotchy matte frost. What would arrive late is hurried in by easing its time toward the end of the growth, so the frost keeps its order and no patch pops in. The thaw time is the earliest over several lobed, sideways-stretched warm spots, ragged at a finer scale too, spreading slowly at first and then faster so the last of it goes briskly; the fronds' thick ice thaws a moment later. Each frame thresholds the table: it blurs and pales the image through a mip in steps, turns it to the new image once the frost there is thick, lights the fronds from the table's height, turns the frost translucent just ahead of the thaw, and refracts the new image at the wet rim along the thaw's slope. The knob is one shader: a glass bauble cel-shaded under a fixed light, whose crimped cap and garnet-set band, on a sphere leaning toward the viewer, roll with its travel. On a slider it reaches back to the track's start: a dark ribbon strung with fairy lights on a sagging wire from a plug. The bulbs' places are hashed per index along the track, so they hold still, and spaced by the knob's resting size, so they don't jump when it grows. On a switch it draws the whole switch from `switchArea`, four bulbs coming on in hashed order with a flicker.

The backdrops are a nebula lane, banked flames, cloud banks with curling wind, an underwater view, rock strata with pebbles, asphalt with a checkered flag and a forked bolt, dark chocolate with drizzles of cream and a piped shell border along the bottom, and a winter pine night: firs drawn from their seeds, tiers drooping to their tips under lumpy caps of snow, in groves on a rolling snowfield, the tallest near one hung with bulbs and a star, over wind-leaning drifts.

The clock faces are each one shader: an orrery whose planets, lit from the sun at the middle, are the hands, and a comet the seconds; a charcoal dial cracked with embers inside a ring of flames from flickering noise, with forged blades for hands; a sky of drifting cloud banks with dashes of wind along spiral streamlines, a compass rose, a leaf and a feather for hands, and a leaf that tumbles round with the seconds; a pool with drifting caustics, glassy currents for hands round a whirlpool, and rings that spread from each second's drop; a disc of bent strata with faceted jade at the hours, a pale stone hour hand and a jade minute hand, and a gold pebble in a carved groove; a tachometer with a redline, needles on a checkered cap, and a bolt that takes a new shape each second and crackles until the next; and a raspberry tart from above, its shell fluted sixty times for the minutes and dusted with powdered sugar, raspberries at the hours, each drupelets round a hollow, lancet hands of dark chocolate, and a thread of coulis for the seconds; and an evergreen wreath from above, three layers of serrated sprigs placed by angle with their shadows, holly leaves as lenses bitten between their spines, berries as lit spheres, a bow at six, gilt hands, and a bead of light for the seconds whose flare and trail fade by `sinceTick`.


On the controls, each effect spawns particles from `common/Particles.qml`, each a small `ShaderEffect` that draws one kind of bit by its age: star dust, glints, and constellations that draw themselves star by star; flames standing on a burning streak, sparks, embers, flashes of ignition, and smoke; a plume of breath that blows a dragged knob along (one shader per direction, not particles), wisps, leaves, and curls of wind; drops that drip off, leap in, or fly off to land in ripples, and crown splashes with the jet that follows; rock chips, pebbles that bounce where they land, grit, and dust; sparks, arcs, starbursts, lightning strikes, glints, and tire smoke; sugar sparkles, powdered sugar sifted down in a spreading fall, puffs of it, and cake crumbs; glints, tiny falling flakes, a warm bloom, and a snowflake whose six arms grow side branches as their tips pass them, then glint and drift apart. Each knob is one small shader turned by its travel, clockwise as it moves right, as a ball rolls: a planet whose moon orbits, an ember, a ball of wind, a drop that stretches by how far a spring-damped copy of its travel lags behind, a faceted stone that rolls, and a racing wheel that blurs by how far a spring-damped copy of its travel lags, and reaches back to the track's start to draw a stepped bolt decal along the fill. Sugar's knob is the frosting piped along the whole fill, with a piping bag or a spatula over it while the pointer is near, and on a switch an éclair glazed in fondant behind a disc of chocolate. Christmas's knob is a glass bauble trailing fairy lights along the fill, and on a switch a string of bulbs that come on one by one.

## Cost

The worst GPU time per frame at 1080p on an Intel UHD 630 (a laptop's integrated GPU) at full clock, read from i915's `drm-engine-render`. Keep every effect under 8 ms there, since the compositor draws on the same GPU:

| Effects | Launcher | Wallpaper |
|---|---|---|
| Cosmos | 4.3 ms | 4.6 ms |
| Fire | 3.3 ms | 7.3 ms |
| Air | 4.8 ms | 7.2 ms |
| Water | 6.1 ms | 5.5 ms |
| Earth | 7.7 ms | 4.2 ms |
| Relâmpago | 4.1 ms | 6.3 ms |
| Sugar | 1.8 ms | 5.9 ms |

GPU time per frame at 1080p on an RTX 3070, measured before `just bench` with a method that read low; `just bench -m` prints a fresh one, best on a GPU that isn't slowing down for heat:

| Effects | Launcher open | Launcher entrance and exit | Wallpaper | Controls | Clock face |
|---|---|---|---|---|---|
| Cosmos | 0.15 ms | 0.16 ms | under 0.03 ms | 0.20 ms | 0.09 ms |
| Fire | 0.14 ms | 0.14 ms | about 0.2 ms | 0.23 ms | 0.12 ms |
| Air | 0.10 ms | 0.16 ms | about 0.26 ms | 0.15 ms | 0.12 ms |
| Water | 0.23 ms | 0.26 ms | 0.03 ms | 0.27 ms | 0.16 ms |
| Earth | 0.09 ms | 0.14 ms | 0.05 ms | 0.26 ms | under 0.03 ms |
| Relâmpago | 0.09 ms | 0.25 ms | 0.04 ms | 0.16 ms | 0.05 ms |
| Sugar | 0.06 ms | 0.10 ms | 0.06 ms | 0.10 ms | under 0.03 ms |
| Christmas | 0.07 ms | 0.09 ms | 0.15 ms | 0.12 ms | 0.21 ms |

The controls column is the whole controls scene, its backdrop included, while effects play; the clock face column is the clock scene, a face at the panel's size and one at twice it, ticking. Nothing runs while the launcher is hidden, the wallpaper is still, no control effect is playing, and the clock panel and the theme gallery are closed. The backdrop renders once when a surface first shows or the theme changes. Re-measure after a change and update this table.
