# Hedgehog, work in progress (not approved)

Not merged into v3. Three attempts so far; none approved yet.

1. `attempt1-round-face.png`: front-facing round cream face in a symmetric spiky
   halo, sitting up. Rejected: the round face does not read as a hedgehog, it
   needs a snout.
2. `attempt2-snout-rig.png`: three-quarter head with a long snout, few chunky
   quills, ears on top. Rejected: not cute; ears read as a mouse's.
3. `hh_sheet.png`: drawn from scratch as one illustration before rigging
   (`hedgehog.py` builds it; `render.gd` rasterises SVG headless:
   `godot --headless -s render.gd -- in.svg out.png 2`). Standing on four
   legs, dense fuzzy quills over head and back, short snout, cream chest,
   ball with face peeking out, nap. Not yet judged; to revisit.

Direction from review: always on four legs (never sitting up on hind legs);
quills numerous and dense, almost fluffy, covering the top of the head too;
the ball is a fully spiky ball with eyes and a little nose sticking out; face
shape matters most (a snout, anime-cute, not a round teddy face).

The rig in `godot/critters/hedgehog.gd` and `godot/art/hedgehog/` is for
attempt 2 and will be redone from the approved design.
