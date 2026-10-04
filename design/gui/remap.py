import re
M = {
 "#FBF7F1":"ground","#F3E6D6":"sp-kitten","#FFFFFF":"surface","#EADFD2":"line",
 "#F4ECE2":"div","#F0E6DA":"div","#F6EEE5":"div","#F1E7DB":"track","#EAF2FA":"track","#EEE5DA":"track",
 "#2A211C":"ink","#6A5A50":"ink2","#5A4A40":"ink2","#5E4E44":"ink2","#7D6D61":"ink3","#8A7A6E":"ink3",
 "#9C8B7E":"ink3","#B3A496":"ink3","#A39484":"ph-ink","#4E4038":"ink-body","#9A4F1C":"acc-ink","#6E3712":"acc-ink-h",
 "#F2A06A":"accent","#6B4A3A":"outline","#F6C28F":"btn","#3B2A21":"ink","#D9C8B6":"sec-line",
 "#BBA998":"off-line","#B9A797":"off-line","#E2D5C6":"chip-line","#FFF4E8":"chip-sel","#CDBFAF":"dash","#D9CCBE":"dash",
 "#F7F1EA":"ph-bg","#F9F4EE":"ph-bg","#F4EEE7":"ph-bg","#EFE7DD":"ph-bg","#EBDCCB":"nav-h","#FBF2E8":"tip-ink",
 "#FFF1EE":"dng-bg","#A23A2C":"dng-ink","#E9B8B0":"dng-line","#DDF3E8":"ok-ring",
 "#F4EFFA":"rh-bg","#E2D6F2":"rh-line","#5D4F72":"rh-text","#7046B8":"rh-ink","#EFE3D4":"stage","#EAD7C2":"stage-ground",
 "#7D5A43":"acc-ink","#E1F5EC":"t-uncommon-tint","#2B7A5E":"t-uncommon-ink","#E2F0FC":"t-rare-tint","#2C67A8":"t-rare-ink",
 "#FFF3D1":"t-legendary-tint","#94620E":"t-legendary-ink","#6B5D50":"t-common-ink","#8CC2F2":"t-rare-fill",
 "#E4F1DF":"sp-turtle","#E6EEF3":"sp-otter","#F1E6F7":"sp-unicorn",
}
def remap(text):
    def rep(m):
        pre = text[max(0,m.start()-2):m.start()]
        h = m.group(0).upper()
        if pre == '="' or h not in M: return m.group(0)
        return f"var(--{M[h]})"
    return re.sub(r"#[0-9A-Fa-f]{6}", rep, text)
for f in ["pages1.py","pages2.py","pages3.py","pages4.py","parts.py"]:
    s = open(f, encoding="utf-8").read()
    if f == "parts.py":
        i = s.index("# ---------------------------------------------------------------- css")
        s = s[:i] + remap(s[i:])
    elif f == "pages3.py":
        a = s.index("def tray_icon"); b = s.index("def tray_panel")
        s = remap(s[:a]) + s[a:b] + remap(s[b:])
    else:
        s = remap(s)
    open(f, "w", encoding="utf-8").write(s)
