# Critter Overlay — AI Art Generation Prompts

One prompt per critter. Upload your reference images alongside each prompt and tell the AI to match that style exactly.

**Best tools:** Microsoft Copilot Designer · Ideogram.ai · Adobe Firefly

---

## How to Use

1. Open your AI image generator
2. Upload your reference images (the hedgehog, turtle, duck sheets you already have)
3. Paste the prompt for the critter you want
4. Tell the AI: **"Match the style of the reference images as closely as possible"**

---

## Grid Layout (same for every critter)

```
TOP-LEFT:     standing still, neutral idle pose
TOP-RIGHT:    standing, happy smile expression  
BOTTOM-LEFT:  walking, right front leg stepped forward
BOTTOM-RIGHT: walking, left front leg stepped forward
```

All poses face **right**.

---

## Prompts

---

### 🦔 Hedgehog
```
2x2 grid of the same chibi hedgehog character in 4 poses on a white background, matching the style of the reference image exactly: top-left standing still neutral, top-right happy smile, bottom-left walking with right leg forward, bottom-right walking with left leg forward. Pure white background, no shadows, no text.
```

---

### 🐱 Kitten
```
2x2 grid of the same chibi orange tabby kitten in 4 poses on a white background, matching the style of the reference images exactly: top-left standing still neutral, top-right happy smile, bottom-left walking with right paw forward, bottom-right walking with left paw forward. The kitten has pointed ears, forehead stripes, whiskers, and a curly tail. Pure white background, no shadows, no text.
```

---

### 🐢 Turtle
```
2x2 grid of the same chibi turtle in 4 poses on a white background, matching the style of the reference images exactly: top-left standing still neutral, top-right happy smile, bottom-left walking with right leg forward, bottom-right walking with left leg forward. Pure white background, no shadows, no text.
```

---

### 🦆 Duck
```
2x2 grid of the same chibi duck in 4 poses on a white background, matching the style of the reference images exactly: top-left standing still neutral, top-right beak open in a happy quack, bottom-left waddling with right foot forward, bottom-right waddling with left foot forward. Pure white background, no shadows, no text.
```

---

### 🐰 Rabbit
```
2x2 grid of the same chibi rabbit in 4 poses on a white background, matching the style of the reference images exactly: top-left standing still neutral, top-right happy smile, bottom-left hopping with right paw forward, bottom-right hopping with left paw forward. The rabbit has very tall floppy ears with pink lining, a fluffy white tail, and a pink nose. Pure white background, no shadows, no text.
```

---

### 🐿️ Squirrel
```
2x2 grid of the same chibi squirrel in 4 poses on a white background, matching the style of the reference images exactly: top-left standing still neutral, top-right happy smile, bottom-left walking with right paw forward, bottom-right walking with left paw forward. The squirrel has a huge fluffy tail arching over its body and chubby cheek pouches. Pure white background, no shadows, no text.
```

---

### 🦦 Otter
```
2x2 grid of the same chibi otter in 4 poses on a white background, matching the style of the reference images exactly: top-left standing still neutral, top-right happy smile, bottom-left walking with right paw forward, bottom-right walking with left paw forward. The otter has a dark brown body with a light cream belly patch and whiskers. Pure white background, no shadows, no text.
```

---

### 🐼 Panda
```
2x2 grid of the same chibi panda in 4 poses on a white background, matching the style of the reference images exactly: top-left standing still neutral, top-right happy smile, bottom-left walking with right leg forward, bottom-right walking with left leg forward. The panda has a white body, black ears, and large black eye patches. Pure white background, no shadows, no text.
```

---

### 🦄 Unicorn
```
2x2 grid of the same chibi unicorn in 4 poses on a white background, matching the style of the reference images exactly: top-left standing still neutral, top-right magical sparkling expression, bottom-left walking gracefully with right leg forward, bottom-right walking gracefully with left leg forward. The unicorn has a white body, a golden spiral horn, and a flowing rainbow-colored mane and tail. Pure white background, no shadows, no text.
```

---

### ✨🐱 Golden Kitten
```
2x2 grid of the same chibi golden kitten in 4 poses on a white background, matching the style of the reference images exactly: top-left standing still neutral, top-right magical sparkling expression, bottom-left walking with right paw forward, bottom-right walking with left paw forward. The golden kitten has shimmering golden fur, a small royal crown on its head, and sparkle effects around its body. Pure white background, no shadows, no text.
```

---

## After Generating

1. Remove background — [remove.bg](https://remove.bg) or Canva, export as PNG
2. Save as `[animal]_sheet.png` in the project folder (e.g. `turtle_sheet.png`)
3. Run `split_sprites.py` to cut into 4 individual PNGs → saved to `assets/`
4. Send to Claude to wire up in the game code
