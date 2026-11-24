# My critters: the approved design (A0)

Approved on 2026-11-24. The A2 code and every later screen that adds to My
critters follow these pages. The decisions behind them are in
`docs/custom-critters-build-plan.md` (step A0 and the log).

Open any `.html` file in a browser. They are drawn in the app's own look
(`gui/palette.gd`, the GUI mock-ups in `design/gui/`) at the Settings
window's size, light theme; `critter.css` also holds the dark theme
(`th-dark`). The pictures in `art/` are the game's own critters, exported
from the game's art and the kit test fixtures, and stand in for a player's.

| Page | What it shows |
|---|---|
| `Main.html` | **My critters**: a sidebar page after Critters. One grid of every homemade critter, with filter chips by how it was made, a Make a critter button and a hint that files can be dropped on the window |
| `Make.html` | **Make a critter**: the chooser. Build from shapes is the big first card ("No drawing app? Start here"), then Draw in your own app, Bring an animation and Use a picture; under "Got one from someone?", a box for a CRIT1- code and Open a .critter file |
| `Detail.html` | **One critter**: the Critters page's detail layout (on/off, Spawn one now, how often, size, speed, pop sound, clothes) plus Edit, Share, Make a copy and Delete. The Edit button's words depend on how it was made |
| `Empty.html` | **First visit**: with no critters yet, the page itself is the chooser |
| `Entrances.html` | **The ways in**: the Critters page's "Your own" tile (newest critter, count), the Collection's Homemade shelf (same badges, a link across) and the System page's pointer, kept for one release |
| `Grouped.html` | Not chosen. Sections per way, kept for reference |

Words used for each kind, everywhere (badges, chips, Edit buttons):

| Kind | Badge | Edit button |
|---|---|---|
| Built from shapes | Shapes | Edit shapes |
| Drawn in your own app | Drawn | Bring in a new version |
| An animation | Animated | Change frames |
| A picture | Picture | Change picture |

"From a friend" is a note on the card, not a kind.
