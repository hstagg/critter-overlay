# The Studio window: the D0 design (draft)

Drafted on 2026-11-27 for the D0 session with the developer; **not approved
yet**. Once approved, D2-D7 follow these pages and the decisions go in the
plan's log. The background is in `docs/custom-critters-build-plan.md` (P18,
P26, decision 2, 4.1-4.7, 5.3 and D0-D7).

Open any `.html` file in a browser (served, or straight from disk). Each page is drawn
at the Studio's minimum size, 1280 x 800, in the app's own look: it links
`../my-critters/critter.css` (the A0 tokens, type, buttons, chips and cards)
and adds `studio.css` for what the Studio adds. *Dark theme*, top right,
switches every window to `th-dark`; `#dark` on the address does the same.

The critters are drawn by `art.js`, a small JavaScript copy of
`godot/studio/shape_svg.gd`: the same shape types, the two-pass outline,
markings clipped inside, the four eye presets, blush and the automatic parts.
So what these pages show is what the engine can draw. The starters are the
eight in D5; Mochi is the shapes critter from the A0 pages.

| Page | What it shows |
|---|---|
| `Start.html` | **First time in**: eight starters, each a picture, a name and how it moves; beside them, *Or start blank* with the four body plans, each with a line on how it moves and which parts you draw |
| `Builder.html` | **The main window**: layers grouped by pose on the left, the tool rail, the canvas (frame, headroom, ground, zoom), the colour panel and the whole-critter style on the right, and the live preview (Walk, Sit, Nap). `?` opens the shortcuts |
| `Pins.html` | **Pins mode**: the joints as dots with labels, one being dragged, its suggested place and the box it must stay in, the leg's swing drawn faintly, and a test move with the pins on it |
| `Save.html` | **Save**: name, how it walks, size and pop sound, then *Keep*. Below it, the moment Mochi walks onto the desk, with the Studio still open behind |
| `Empty.html` | **States**: a blank start (needed parts flagged, the first tip, the empty-part hint, Save off), an empty optional part, the second and third tips, Save with parts missing, and the unsaved-changes prompt |

Shared files: `studio.css`, `art.js` (critters), `canvas.js` (the canvas),
`icons.js` (the icon sprite, same style as A0's) and `board.js` (the board's
toggles, not part of the app).

## Key decisions in this draft

- **One window, two modes.** *Shapes* and *Pins* are a switch in the top bar,
  not separate windows or steps. Pins can be skipped entirely: they are
  suggested from the shapes and kept in step with them until the player drags one.
- **Layers are grouped by pose**, as D2 says: *Every pose* (head, eyes, ears,
  tail, nose), *Walking*, *Sitting*, *Napping* and *Extras*. Plain names
  ("Front leg", "Far ear"), never the file names (`leg-front`, `ear-r`).
- **What's missing says what it costs.** A needed part is a red dashed row
  marked *Needed*, with a count at the top ("5 needed to walk") and Save off
  until they're drawn. An optional part that's empty is a grey dashed row
  that says what the critter can't do without it ("Without one: no tail
  swish"), from the behaviour table in 4.6.
- **Automatic parts are shown, not hidden**: *Far legs*, *Closed eyes*, and
  each pose not yet drawn ("Sitting body, Automatic") with *Draw this pose*.
  The player sees what they get for free.
- **Starters first.** The Start page leads with the eight starters (the
  round cat is the easiest start); a blank start asks for the body plan with
  a line on how each moves and what you'd draw. Same "how it moves" wording
  as A0's chooser.
- **The colour panel is the A2 picker laid flat**, always open for the
  selected shape: *From the critters*, *In this critter* (D4's palette row),
  *Used lately*, the square, the hue strip and hex. Outline and Marking sit
  under it. Eyes and Blush are for the whole critter. The outline colour
  and width can't be changed (D4).
- **The preview is always there**, bottom right, live, with Walk, Sit and
  Nap, and Blink, Look around and Swish tail (only the moves the critter
  has). In Pins mode it becomes the *Test move*, with the pins drawn on it.
- **Save is a short dialog**, not a page: name, gait (only the plan's gaits,
  each with a line and the species it comes from), size and sound as A0's
  detail view has them, and *Send it to my desk now*. After *Keep*, the
  critter walks on from the screen edge, a toast says so, and the Studio
  stays open, saved (P18).
- **Tips are three short bubbles** on first use (pick a part then a shape;
  move, resize, turn; watch the preview), each skippable. After that, each
  empty part has its own hint card on the canvas with two or three likely
  shapes ("Add a shape to draw the tail").
- **Leaving with changes asks once**: *Save and go back*, *Don't save* or
  *Stay here*. The same prompt for the window's close button.

## Open questions for the developer

1. **The starters.** The brief named a bunny; D5's eight have none. Swap one
   (the round mouse, say) for a bunny with the hop gait?
2. **Eye presets.** D4 lists big, sleepy, sparkly and simple dot; the engine
   (`shapes.gd`) has big, round, dot and lash. The pages use the engine's.
   Which set ships?
3. **Can the body plan change later?** The Start page treats it as fixed.
   Changing it would mean redrawing the needed parts; is that worth an
   action, or is *Make a copy* plus starting again enough?
4. **Pins mode as a switch or a step in Save?** This draft keeps it a mode
   anyone can open, but never forces it. Is that too hidden for a critter
   whose legs bend wrongly?
5. **Try on my desk** before saving (a temporary critter that walks while
   the Studio stays open). Worth adding beside Save, or is the preview enough?
6. **The guide cat** on a blank start: one guide per plan (cat, bear, chick,
   slime), or the kitten for every plan?
7. **Where the toast sits** on the desktop moment: top right here, so it
   doesn't cover the critter walking on along the bottom. Does that match
   the app's toasts?
8. **Extras list.** The rows show *Open mouth* and "6 more". Should every
   optional part be listed (long), or added from a menu (hidden)?
