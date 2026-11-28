# Making your own critters

Critter Overlay has four ways to make a critter of your own. They all end
the same way: a critter that visits your desk with the rest. Open
**Settings › My critters › Make a critter** and pick by what you have.

| Way | What you need | How it moves |
|---|---|---|
| **Build from shapes** | Nothing: it's all in the app | Walks, sits and naps |
| **Draw in your own app** | A drawing app with layers | Walks, sits and naps |
| **Bring an animation** | Frames: a GIF, an animated PNG, a sprite sheet or Aseprite | Plays your frames |
| **Use a picture** | One picture of a critter | Slides along as it is |

You can also drop a file anywhere on the Settings window, or onto a
critter, and it opens in the right place.

---

## Draw in your own app

### 1. Get a template

**Make a critter › Draw in your own app › Get the templates** saves one
file per body, each with a layer per part, a faint critter to draw over
(the `guide` layer) and the joints (the `pins` layer):

| Body | Like | File | Walks |
|---|---|---|---|
| Side-on | the kitten | `side-1.svg` | trot or hop |
| Faces you | the otter | `front-1.svg` | trot, plod, scurry, dart, slide, bounce or sway |
| Upright | the duckling | `upright-1.svg` | waddle or hop |
| Blob | a slime or ghost | `blob-1.svg` | bounce, glide, float or slither |

Each also has a `*-guide.png` at twice the size (600 x 560) for apps that
don't open SVG.

### 2. Draw

- Keep **each part on its own layer**, named as in the template. Upper or
  lower case, spaces, `_` and `-` all work, and "(optional)" is ignored.
- Draw **facing left**, feet on the ground line.
- **Overlap at the joints**: a leg reaches up inside the body, so nothing
  shows a gap when it swings.
- Keep lines bold, like the cast's.
- Leave the `guide` and `pins` layers alone, or delete the guide. The app
  ignores both, apart from reading the pins.

### 3. Bring it back

Save as **SVG** (Inkscape, Affinity, Illustrator), or export **every layer
as a PNG, whole canvas, untrimmed** into a folder or a zip (Procreate,
Photoshop, Clip Studio), or save an **.ora** (Krita, GIMP, MyPaint).
Photoshop's `.psd` can't be read: export the layers as PNGs first.

PNG layers must be the template's size, 300 x 280, or an exact multiple
(600 x 560, 900 x 840, 1200 x 1120).

Then **Pick a file** (or a folder). The kit page shows the critter walking
from your file, and what it can do. Keep the page open while you draw:
each time you save, it's brought in again with its name and settings kept.

### The parts

**Needed** parts are the least a critter can walk with. Everything else is
optional, and a missing one only costs the moves that use it.

| Body | Needed |
|---|---|
| Side-on | `walk-body`, `head`, `eyes`, `leg-front`, `leg-back` |
| Faces you | `body`, `head`, `eyes`, `walk-body`, `leg-front`, `leg-back` |
| Upright | `body`, `head`, `eyes`, `leg-near` |
| Blob | `body`, `eyes` |

What an optional part gives it:

| Part | Without it |
|---|---|
| `tail` | no tail swish (and a side-on critter never chases it) |
| `mouth-open` | no yawning or sneezing; an upright critter doesn't preen or peck |
| `ear-l`, `ear-r` (or `tuft`) | no ear flicks |
| `nose` | no nose twitches |
| `stand-body` | it never stands up to look around |
| `groom-paws` (or `wing-l` when upright) | no grooming |
| `scratch-foot` | no scratching |
| `eyes-closed` | its eyes squash shut to blink and nap |
| `loaf-body` | its nap is made from its other bodies |
| far legs (`leg-front-far`, `leg-back-far`, `leg-far`) | made for it, a shade darker |
| `head-side`, `eye-side` (faces you) | it keeps facing you as it walks |

The kit page lists exactly what's missing and what it costs. A layer it
doesn't recognise gets a drop-down to say which part it is.

---

## Bring an animation

Name each move after what it shows. Only **walk** is needed:

| Move | If it's missing |
|---|---|
| `walk` | needed |
| `sit` | walk's first frame |
| `nap` | sit |
| `blink` | it doesn't blink |
| `held` | sit |
| `thrown` | held |
| `land` | a squash |
| `climb` | walk |

Up to 8 moves of its own, such as `wave` or `dance`, play now and then.

Bring them as:
- **a GIF or animated PNG per move**, named after the move (`walk.gif`,
  `sit.png`), together in a folder or a zip;
- **a folder per move of numbered PNGs** (`walk/0.png`, `walk/1.png`...);
- **Aseprite's JSON** with its sheet: each frame tag is a move.

Draw in the cast's 300 x 280 frame (or up to 4x), facing left. Pixel art
is scaled by whole steps, so it stays crisp. The page warns if the walk's
feet jump about, if a loop doesn't join up, or if art is cut off at the
edge. **Step length** sets how far one walk cycle carries it, so its feet
don't slide.

---

## Use a picture

Any PNG, JPG or WebP. One animal on a plain background works best, or a
picture that's already cut out. The background is taken out (Gentle,
Normal or Strong), and you pick which way it faces and its size. It slides
along as it is.

---

## Sharing

On a critter's page, **Share**:
- **Copy code** (critters built from shapes): a short `CRIT1-` code to send
  however you like. Someone pastes it into **Make a critter › Got a code?**.
- **Save as a file**: a `.critter` file with everything it's made of.

Opening a code or a file shows the critter walking first, with who made
it. Nothing is added until you press **Add** or **Install**.

Only install critters from people you trust. A `.critter` file is checked
like any import: drawings are cleaned, pictures are decoded and saved
again, and nothing in a file is run. Critters made from a picture are
someone's own picture, so only pass them on if they're happy for others to
have it.

---

## Your own sound

On a critter's page, **Pop sound › Add your own**: a WAV or OGG, 2 seconds
and 500 KB at most.
