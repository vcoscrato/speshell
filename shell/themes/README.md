# Themes

The themes Speshell ships. Each folder holds a `theme.ini` (name, the description the theme gallery shows, palette, `effects = <name>`), its wallpaper `<painting>.jpg`, and `<painting>.frag`, the shader that paints it. `landscape.glsl` holds the helpers the paintings share. The effects are in [`../effects`](../effects/README.md). Everything here is original work.

| Theme | Effects | Wallpaper (painting) | Launcher | Wallpaper change | Controls | Clock face |
|---|---|---|---|---|---|---|
| Cosmos (default) | `cosmos` | `spiral-galaxy` | Opens out of a flaring star; planets orbit it while open | Supernova: a filamented shock front flinging comets of ejecta, with sparks in its wake | Planet knobs with a moon; star dust trails, glints, constellations drawn out from what you pick | An orrery: the hour's planet and the minute's ringed giant circle the sun, held to it like hands, and a comet runs the seconds |
| Fire | `fire` | `ember-dusk` | An ember flares and throws sparks, and the panel burns in behind its edge; flames simmer around it | Burns away from the middle in tongues of flame, embers drifting up off the burnt ground | Ember knobs that flame when held; the track burns behind them, sparks, smoke; what you pick catches fire, with embers floating up | Charcoal cracked with embers inside a ring of flames; forged blades for hands and an ember running the seconds |
| Air | `air` | `cloud-sea` | Unwinds out of a whirlwind; a breeze with leaves circles it | Whirlwind eye with a torn, wind-blown edge | Spinning wind-ball knobs; a gust of breath from behind blows a dragged knob along, carrying specks and leaves; curls of wind | Cloud banks and circling wind over a compass rose; a leaf and a feather for hands, and a leaf riding round with the seconds |
| Water | `water` | `polar-night` | A water whip coils into it and clears through rippling caustics; two streams chase its border among orbs, currents, and mist held in the air | A drop lands: a crown splashes and a jet leaps, and its ripple spreads | Drop knobs that stretch as they move; water pours off as a slider goes down and rains onto it as it goes up, ripples; a drop splashes a crown up from what you pick, flinging drops that ripple where they land | A pool with drifting caustics; glassy currents for hands round a whirlpool, and a drop each second that ripples |
| Earth | `earth` | `jade-valley` | Punches up out of cracked ground as a carved stone slab that cracks on landing and crumbles away; faceted boulders, lit from one side, hover with pebbles and dust rings | Struck: cracks run out from the impact and branch, and the shards break loose one by one and fall away in dust | Rolling stone knobs; kicked-up rock chips and dust; what you pick throws pebbles, chips, and grit that bounce where they land, over a burst of dust | Layered, cracked stone with jade at the hours; a pale stone hour hand and a jade minute hand, and a gold pebble rolling in a groove |
| Relâmpago | `relampago` | `thunder-road` | Races in from the left, stretched by its speed, in a glossy red streak with a bolt decal through it, brakes with sparks and skid marks, and squashes to a stop in a comic starburst and cartoon tire smoke as lightning strikes all around it; while open, speed dashes trail behind it, electricity crackles on its border, and now and then a bolt strikes it; tears away on two trails of fire | A cartoon bolt, a new one each time, bursts where it lands and splits it; the inked, glowing halves race apart | Cartoon racing-wheel knobs that blur and trail speed dashes, carrying a stepped bolt decal along the filled track, charged while held; fat sparks, zigzag arcs, a starburst on release, bolts and glints on what you pick | A tachometer with a redline; needles on a checkered cap, and a bolt striking out to each second |
| Sugar | `sugar` | `meringue-peaks` | Opens at once, and while you use it a piping bag pipes a shell border of frosting round it, slowly, outside its edge, then lifts away; sugar pearls are set into the border one by one and now and then catch the light; eaten away in bites that show the sponge inside and throw crumbs | A curtain of glaze pours down over it, drips running ahead and drops falling off them | Frosting piped along the filled track, ending at the knob in a kiss of meringue; a piping bag comes down onto it as the pointer nears and pipes as the value rises, and an offset spatula scrapes the frosting back as it falls; a switch is an éclair with a chocolate disc for its thumb, glazed in strawberry fondant behind the disc when on and bare when off; a glint now and then, powdered sugar sifted down over what you pick | A raspberry tart from above: a fluted shell dusted with powdered sugar, glazed vanilla cream, raspberries at the hours, larger at the quarters, lancet hands of dark chocolate, and a thread of coulis for the seconds |

## Making themes

Names are lowercase-kebab for theme folders and paintings; QML components are PascalCase, and an effect's shaders take the name of the QML that draws them. A theme and its effects share a name (`fire`), and its painting is named for its scene (`ember-dusk`). Any theme can use any effects.

- **Original work only.** No fan art, photos, fonts, or code under another license. Wallpapers are painted by shaders, so their whole source is in the repository.
- **A wallpaper is committed with its painting.** After editing a theme's `<painting>.frag`, run `just paint <theme>` and commit the `.jpg` in the same change.
- **`just check` passes** before effects changes are merged. It fails on any QML error or warning, or a transition that never finishes.
- **Stay within the GPU budget:** under 0.5 ms per frame at 1080p in every phase (`just bench`). The current costs are in [effects/README.md](../effects/README.md#cost).
- **Compiled shaders are build output.** `just shaders` writes the effects' to git-ignored `qsb/` folders beside their sources, and the package build runs it. Paintings compile into the previews' cache, since only `just paint` uses them.

**Retune a palette.** Edit `<theme>/theme.ini`. Its keys are listed in `cosmos/theme.ini`; missing ones fall back to Cosmos. Open the theme gallery (`!theme` in the launcher) to see it previewed, or `just shot <theme> themes`.

**Paint a wallpaper.**

```bash
just paint fire                          # renders fire/ember-dusk.frag into fire/ember-dusk.jpg
WIDTH=1920 HEIGHT=1080 just paint fire   # quicker draft while iterating
just paint                               # every theme's
```

Start a new painting from an existing one: it shows the uniform block, the `common.glsl` and `landscape.glsl` includes, and the header comment that describes the scene.

**Add a theme.** Create `<theme>/` with a `theme.ini` and a painting, run `just paint <theme>`, and add it to the table above.

**Build or change effects.** Copy the closest effect directory (with its `common` symlink, made with `ln -s ../common common`), follow [effects/README.md](../effects/README.md), and iterate with the previews in [preview/](../../preview/README.md).
