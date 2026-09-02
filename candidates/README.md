# Fifth-wall candidates

`fifth-wall.sh` renders four candidate replacements for `1-horizon`, which
duplicates `4-scanline` in both subject and brightness. Beirut's palette is
hardcoded so the four can be compared fairly; the chosen one would move into
`make_walls` in `build-pack.sh` and pick up per-theme colour and SEED there.

| candidate | luminance | what it is |
|---|---|---|
| `b-colonnade` | 35 | five pointed arches cut from a dark wall, evening behind — echoes the boot mark |
| `d-shaft` | 34 | one warm beam through the dark; the only vertical composition in the set |
| `a-mashrabiya` | 13 | eight-point stars pierced through a panel, light behind |
| `c-plaster` | 15 | no subject: a warm, mottled, weathered wall |

Colonnade and Shaft are pitched at the slot Horizon leaves (Scanline 53,
Ridge 31, Ember 26). Mashrabiya and Plaster land near Ember instead.

> Two ImageMagick traps hit while building these. A drawn mask keeps an opaque
> **alpha channel**, and `-composite` then uses that alpha as the mask instead of
> the greyscale — so the overlay lands everywhere and the mask appears to do
> nothing. End a drawn mask with `-alpha off -colorspace Gray`. And a three-image
> composite is `dst src mask`, in that order.
