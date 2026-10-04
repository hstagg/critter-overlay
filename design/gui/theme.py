LIGHT = dict(ground="#F7F3FC", side="#EDE5F8", surface="#FFFFFF", raised="#FFFFFF", line="#E4DAF2", div="#F1EBF9",
  track="#ECE3F7", ink="#251A35", ink2="#5D5173", ink3="#6A5F83", **{"ink-body": "#3D3152", "ph-ink": "#8F84A6", "ph-bg": "#F5F0FB",
  "acc-ink": "#6B3FC0", "acc-ink-h": "#4F2B93", "btn-ink": "#FFFFFF", "btn-lip": "#4B2A8C", "sec-line": "#D5C8E8", "off-line": "#B1A3C8",
  "chip-line": "#DCD0EC", "chip-sel": "#F2EBFD", "nav-h": "#E2D6F3", "tip-bg": "#2F2143", "tip-ink": "#F7F1FF", "dng-bg": "#FFF0F2",
  "dng-ink": "#A3283F", "dng-line": "#EDB7C1", "ok-ring": "#DDF3E8", "rh-bg": "#E9EEFC", "rh-line": "#CBD6F4", "rh-text": "#3F4C78",
  "rh-ink": "#33479A", "stage-ground": "#DCCFEF", "badge-line": "#4A3466"},
  accent="#A07EEA", outline="#4A3466", lip="#4A3466", btn="#7C4DD6", dash="#C8BBDC", stage="#E9E0F5", zz="#5C6F86", knob="#FFFFFF", sil="brightness(0)", **{"sil-op": "0.18"})
DARK = dict(ground="#1C1524", side="#150F1C", surface="#271E31", raised="#32283F", line="#3D3150", div="#32283F",
  track="#3A2E4A", ink="#F5EFFC", ink2="#CBBFDD", ink3="#A99DBE", **{"ink-body": "#E0D7EC", "ph-ink": "#8C80A2", "ph-bg": "#211A2B",
  "acc-ink": "#C8A8FF", "acc-ink-h": "#DEC9FF", "btn-ink": "#FFFFFF", "btn-lip": "#2E1858", "sec-line": "#4D3F62", "off-line": "#6E5F86",
  "chip-line": "#4A3D5E", "chip-sel": "#3C2D57", "nav-h": "#241B2F", "tip-bg": "#F0E8FB", "tip-ink": "#251A35", "dng-bg": "#3A1A26",
  "dng-ink": "#FF9DB0", "dng-line": "#6A2C3F", "ok-ring": "#1E3A2E", "rh-bg": "#1D2442", "rh-line": "#33406C", "rh-text": "#B8C5EE",
  "rh-ink": "#A9BBFF", "stage-ground": "#2A2036", "badge-line": "#1A1124"},
  accent="#9C78E8", outline="#BBA6E0", lip="#0F0A15", btn="#7C4DD6", dash="#55466C", stage="#1C1524", zz="#A9BBDD", knob="#F5EFFC", sil="brightness(0) invert(1)", **{"sil-op": "0.2"})
# tiers: key, name, fill, light tint, light ink, dark tint, dark ink
TIERS_HEX = [
  ("common", "Common", "#D9CEC2", "#F3EEE8", "#66594C", "#3A3330", "#DCCFC2"),
  ("uncommon", "Uncommon", "#86D9B0", "#E0F6EB", "#22795A", "#183A2E", "#8FE3BA"),
  ("rare", "Rare", "#7FBCF5", "#E1EFFD", "#2363A8", "#182D47", "#9CCBFA"),
  ("epic", "Epic", "#F590B4", "#FDE7EF", "#A62A5C", "#45192C", "#FFA6C6"),
  ("legendary", "Legendary", "#FFCF5C", "#FFF2CC", "#8C5A00", "#3D2E0C", "#FFD77A"),
]
SP_HEX = {"kitten": "#F3E6D6", "rabbit": "#EFE4F4", "duckling": "#FBF0CF", "turtle": "#E4F1DF", "hedgehog": "#F1E3D6",
          "squirrel": "#F6E1D1", "otter": "#E6EEF3", "panda": "#E9ECE4", "unicorn": "#F1E6F7", "golden": "#FAF0CC"}
def _mix(a, b, t):
    a = [int(a[i:i+2], 16) for i in (1, 3, 5)]; b = [int(b[i:i+2], 16) for i in (1, 3, 5)]
    return "#" + "".join(f"{round(x*t + y*(1-t)):02X}" for x, y in zip(a, b))
SP_DARK = {k: _mix(v, "#2E2338", 0.46) for k, v in SP_HEX.items()}

def _vars(d, dark):
    out = {f"--{k}": v for k, v in d.items()}
    for k, n, fill, lt, li, dt, di in TIERS_HEX:
        out[f"--t-{k}-fill"] = fill
        out[f"--t-{k}-tint"] = dt if dark else lt
        out[f"--t-{k}-ink"] = di if dark else li
    for k, v in (SP_DARK if dark else SP_HEX).items():
        out[f"--sp-{k}"] = v
    return ";".join(f"{k}:{v}" for k, v in out.items())
THEME_CSS = ":root,.th-light{" + _vars(LIGHT, False) + "}\n.th-dark{" + _vars(DARK, True) + "}\n"

def _lum(h):
    c = [int(h[i:i+2], 16) / 255 for i in (1, 3, 5)]
    c = [x / 12.92 if x <= 0.03928 else ((x + 0.055) / 1.055) ** 2.4 for x in c]
    return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]
def cr(a, b):
    la, lb = sorted([_lum(a), _lum(b)], reverse=True); return (la + 0.05) / (lb + 0.05)

if __name__ == "__main__":
    pairs = [("ink","ground"),("ink","surface"),("ink","side"),("ink","raised"),("ink2","surface"),("ink2","side"),("ink2","ground"),("ink2","track"),
             ("ink3","surface"),("ink3","ground"),("ink3","side"),("ink-body","surface"),("acc-ink","surface"),("acc-ink","ground"),("acc-ink","side"),
             ("acc-ink","track"),("btn-ink","btn"),("dng-ink","dng-bg"),("dng-ink","surface"),("tip-ink","tip-bg"),("rh-text","rh-bg"),("rh-ink","rh-bg")]
    for name, d, dark in (("LIGHT", LIGHT, False), ("DARK", DARK, True)):
        bad = []
        for a, b in pairs:
            r = cr(d[a], d[b]); bad.append(f"{a}/{b} {r:.2f}" + (" FAIL" if r < 4.5 else ""))
        for k, n, fill, lt, li, dt, di in TIERS_HEX:
            t, i = (dt, di) if dark else (lt, li)
            bad.append(f"{k} ink/tint {cr(i,t):.2f}" + (" FAIL" if cr(i,t) < 4.5 else "") + f" ink/surface {cr(i,d['surface']):.2f}" + (" FAIL" if cr(i,d['surface']) < 4.5 else "") + f" fill/surface {cr(fill,d['surface']):.2f}")
        bad.append(f"accent vs surface (non-text 3:1) {cr(d['accent'], d['surface']):.2f}; outline vs surface {cr(d['outline'], d['surface']):.2f}; outline vs side {cr(d['outline'], d['side']):.2f}")
        print(name); print("\n".join("  " + x for x in bad))
    print({k: v for k, v in SP_DARK.items()})
