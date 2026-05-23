## What's new in v1.10.0

### Personality controls for built-in animals

The Animals tab now has Speed, Idle rate, and Trail style sliders for each built-in species — the same controls that custom critters already had. Set the kitten to supersonic, give the turtle sparkle trails, put the panda into permanent narcoleptic mode.

### More trail styles

Trail options expanded from 3 to 7: **Dots, Stars, Sparkles, Bubbles, Glitter, Hearts**. Available for both built-in and custom critters. Each style has tuned particle rates and physics — bubbles drift upward, glitter fires at high rate with short life, hearts fade slowly.

### Custom critter size slider

New Size control in the custom critter gear panel: tiny / small / normal / large / huge (0.5x to 2.5x). Each critter can be its own scale independently of the global animal size setting.

### More preset sounds + sound file upload

14 sound profiles now available for custom critters (up from 8). New presets: squeak, chirp, bloop, pop, grunt, bell. A new Upload button lets you use your own `.wav` or `.mp3` file as a critter's pop sound. Preview any preset or uploaded file with the new play button before saving.

### Custom critters in the Audio tab

Custom critters now appear in the Audio tab with individual on/off toggles, matching the built-in species layout.

### Thrown critter physics fix

A thrown critter that collides and loses most of its momentum now transitions to scatter state rather than continuing off-screen. Throw one into a cluster of animals — it either punches through (fast enough) or gets absorbed and bounces around.

### Bug fix: custom critter trails

Trail styles set on custom critters were silently ignored since v1.8. Fixed — trails now actually emit particles when a trail style other than None is selected.
