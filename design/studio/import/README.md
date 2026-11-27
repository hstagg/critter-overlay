# Importing: the design for review (C0)

Not approved yet. Once approved, C4's screens, C5 (drop a file), E3 and
F3's marking screen and G2's install dialog follow these pages. The plan
is `docs/custom-critters-build-plan.md` (step C0, P4, P11, P25, P26).

Open any `.html` file in a browser. They reuse A0's `critter.css` and page
shell (the Settings window at its size, My critters selected), so they read
as more pages of `design/studio/my-critters/`. `import.css` adds the few
pieces A0 didn't have (checklist rows, pins, steppers, the Keep bar).
The dark box in the corner is for the mock-up only: it switches states
and the dark theme. A state can be linked as `Kit.html#missing`.

| Page | What it shows | States |
|---|---|---|
| `Choose.html` | **Draw in your own app** and **Bring an animation**: the body picker with a picture of each, Start from a template (Get the drawing templates, How to make a critter), the drop area and Pick a file, and what each kind of file becomes | Drawn, dropped without a template, Animated, no layers, wrong size |
| `Kit.html` | **The kit importer** (C4): the art with draggable joints next to the critter walking, Walk/Sit/Nap/Blink/Look, What it can do (parts found, what each missing part costs, what was left out of the file, unrecognised layers with a drop-down), body, gait, size, speed, sound, Where's its head? (F1), and the Keep bar with the name | Ready, file changed, needs a head |
| `Frames.html` | **The frame importer** (E3): its moves with what each is borrowed from, per move the file or tag, frames a second and loops, Where's its head? per move with marked frames (F3), then faces, ground nudge, step length, size, sound, and the P11 checks | Walk, an extra move (Wave), no walk |
| `Picture.html` | **Use a picture**, today's sticker importer in the same layout: Background, Faces, Size, plus the sound | Ready, looks like a strip of frames, can't open |
| `Install.html` | **A critter from someone** (G2, G1): a dialog over My critters with the critter moving, who made it, the licence, the trust line and Install | .critter file, CRIT1- code, made from a picture, name taken, needs a newer version, damaged |

## Decisions in this design

- **One shape for every importer.** Back link, title with the kind's badge,
  the file it came from, the preview and the checks, then a Keep bar that
  stays at the bottom with the name, Cancel and Keep. Only the middle
  changes per kind. The sticker importer moves into this shape too.
- **The preview is the real critter** (P25): it walks on the right in the
  kind's own well colour, and the pose buttons make it sit, nap, blink and
  look. The art with its joints sits on the left, at the same size.
- **Checks say what it means, not what's wrong.** "No open mouth: no
  yawning or sneezing", grouped as found, missing, left out of the file and
  not recognised. Only a missing required part (head, walk) stops Keep,
  and the Keep bar says why.
- **Reload is always on show** with a "Watching the file" line and a live
  dot. When the file changes, a note says what changed; joints, name and
  settings are kept (C4).
- **Templates and the guide live on the Choose page**, beside the body
  picker, where someone starting to draw needs them. Kit.html links to the
  guide from "Which layer names does it look for?".
- **The body is picked before the file**, with the cast critters as
  pictures. A file from a template knows its body and skips the question;
  any other drawing gets "Which body is it closest to?" after the drop.
  Body can be changed on the kit page.
- **Dropping works anywhere and routes by file type**, with the table of
  what each file becomes on the Choose page. There is no "drag over"
  highlight: Godot only reports a file once it is dropped.
- **Use a picture keeps opening the file picker straight away**, as it
  does today; there is nothing to choose first. A very wide PNG gets
  "This looks like a strip of frames" with a way across to the animation
  importer.
- **Where's its head? is a card on the kit page** with a hat to try on,
  and **a panel per move on the frames page**: mark frame 1, then any frame
  where the head moves; marked frames carry a hat badge, and a move with no
  marks says it shows no clothes. Both only appear once clothes for
  homemade critters are on (R4).
- **Install shows the critter before anything is written** (G2), with
  "Only install critters from people you trust" on every variant. A
  critter made from a picture carries decision 5's note. A taken name adds
  "Noodle 2" rather than replacing anything. Codes have no author, so they
  say so, and offer Edit in the Studio first (G1).

## Open questions for the developer

1. **Photoshop files.** The page says .psd can't be read and to export
   PNG layers. Is that right for R1, or should a .psd get a friendlier
   page of its own?
2. **Get the drawing templates** saves all four bodies at once. Or should
   it save only the body that's picked?
3. **Codes: Add, or Keep?** G1 says Keep; this design uses Install for
   files and Add for codes, since nothing is being kept yet. One word for
   both might be better.
4. **`ai_made`.** Should Install show "Made with AI help" when the author
   set it? Not drawn yet.
5. **Step length** is in pixels with "short" and "long" ends. Would a
   plainer slider without the number read better?
6. **Watching pictures.** Use a picture has no Reload or watching, as
   today. Worth adding for people who touch up the picture?
