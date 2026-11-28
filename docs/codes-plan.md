# Codes: plan

One feature, used two ways: a code unlocks the **Supporter Pack** (paid,
looks only, sold on itch.io with a different code for each buyer), and a
**creator code** gives a creator who features the app their perks. Later
packs use the same system. Codes are checked offline. The app holds only
public keys, so nobody can forge a code, but a code that is shared works for
whoever pastes it; that was accepted for a cosmetic pack. The update check
stays the only network use.

Status: approved by the developer on 2026-11-25 (decision D33 in
`docs/v3-launch-plan.md`). Steps 1 to 8 are built: the real key is key 1
(2026-11-26), its canary is in `codes_test.gd`, and the creator pool is
made. The VM checks come next. It touches the economy save, a
discuss-first area, which is why it was planned and approved before any
code. It ships first, as 3.2.0, before Critter Studio, which moves to the
release after (decided 2026-11-26).

## What the player gets

1. **System › Codes.** A box to paste a code into and a Redeem button. Below
   it, what this PC has unlocked, each with a Copy button so the code can be
   kept somewhere safe. Before anything is unlocked, one line says what codes
   are for and links to the pack's itch.io page. That line is the only place
   the app mentions the pack.
2. **The Shop** gets a small "Have a code?" link in its header that opens
   System › Codes. Pack items stay out of the Shop until they are owned. Once
   owned, they show among the rest marked "Supporter Pack" where the price
   would be.
3. **Redeeming:**
   - A good Supporter code shows a thank-you note and opens the Shop.
   - A creator code shows a note listing what it gave.
   - Pasting a code again says it is already redeemed here.
   - A code that doesn't check out says "That code doesn't look right. Copy
     it again, all of it." Nothing unlocks.
   - A code of a kind this version doesn't know (a later pack) is kept, and
     the note says to update. It unlocks once the app knows the kind.
4. **About** gets one line for supporters: "Supporter: thank you."

## The code

| Part | Bytes | What it holds |
|---|---|---|
| Header | 4 | Byte 0: key number (high 4 bits: 1 to 14 for real keys, 15 for the test key) and kind (low 4 bits). Bytes 1 to 3: serial number, big-endian, 1 to 16,777,215, counted per kind. |
| Signature | 64 | ECDSA P-256 over SHA-256 of `"CritterOverlay code v1"`, a zero byte, then the header. Stored raw as r then s. |

- **Kinds:** 1 Supporter, 2 creator, 3 to 13 for later packs, 14 spare, 15
  the canary (grants nothing; see Tests).
- **Text:** the 68 bytes in Crockford base32 come to 109 characters, shown
  in groups of 5 joined by dashes:
  `24000-AM87H-HHQV2-4XTFH-T4700-SS1FY-CK832-H10P4-6G9MZ-...` (22 groups).
  That is too long to type comfortably, so codes are pasted: from itch's key
  page, or from the creator's email. A signature can't be made shorter, and
  the alternative (short codes checked against hashes shipped in the app)
  would need an app release before each new batch worked.
- **Reading a paste:** upper-case it, drop everything but letters and
  digits (spaces, dashes and the line breaks an email adds), and read O as
  0 and I or L as 1. Then it must be exactly 109 characters.
- **Checking:** Godot's own `Crypto.verify` with a `CryptoKey` loaded from
  the public key's PEM, the raw signature turned into DER first. No native
  code and no new dependency. Tested on 4.7.2 with a throwaway key: a good
  signature passes and a changed byte fails.
- **Which code is which:** a code is known by its header (key, kind,
  serial), not its text. ECDSA allows a second valid signature for the same
  header, so the text alone could not tell two copies apart.
- **Public keys** live in `codes.gd` by key number. A key is never removed,
  so every code ever sold keeps working. A new key gets the next number.

## Where it is kept

- **`user://codes.json`**, its own file, written through `save_file.gd`
  like the other saves (.tmp, .bak, and a damaged file set aside):
  `{"version": 1, "codes": [{"code", "key", "kind", "serial", "at"}]}`.
  - Every code is checked again on load, so editing the file unlocks
    nothing.
  - Keys the file doesn't know are kept on save (the settings rule).
  - A file from a newer version is read but never written, as the economy
    save does.
- **Why not in `economy.json`:** the economy save drops keys it doesn't know
  when it saves, so going back a version would lose a purchase. Start over
  rewrites it too, and Start over must never take a purchase away. A
  separate file avoids both. Start over and Reset all leave `codes.json`
  alone.
- **Owning:** pack items are never copied into `owned`. `economy.owns()`,
  `owns_dye()` and the showpiece check ask the codes store, which works out
  the packs from the codes it holds. One table in `codes.gd` lists what each
  pack contains (its clothes, showpiece and dye), and what each kind of code
  grants: Supporter grants the Supporter Pack; creator grants the Supporter
  Pack and the creator pack.
- **The economy save** gains one key, `code_purses_paid`: the codes whose
  creator berries have been paid. They are written in the same save as the
  berries, so a crash can't pay twice or lose them. No `SAVE_VERSION` bump,
  because older versions ignore a key they don't know.
- **Forward compatibility, added to the economy save:** `from_dict` keeps
  any keys it doesn't know and `to_dict` writes them back. A later version's
  keys then survive a run of this one. A version from before this change
  still drops them; the worst that does is pay a creator's purse twice.
- **Clothes from a pack that this PC no longer owns** (the file deleted, or
  an older version): `worn` keeps the id. The game already skips ids it can't
  draw or doesn't own, so nothing breaks, and owning the pack again brings
  the item back.
- **Revoked codes:** a short list in `codes.gd` (kind and serial) for a code
  that leaks badly. A code on the list can't be redeemed from then on.
  Anyone who already redeemed it keeps what it gave, since nothing is ever
  taken away.

## The Supporter Pack

Looks only. It never touches berries, luck, rarity or anything random.

- **Three clothes on one theme:** a hat, a neck item and a face item, each
  drawn for every species by `design/wear/build.py`, in a new
  `design/wear/items_pack.py`.
- **One showpiece:** a bed or house that critters nap in, drawn as SVG in
  `godot/art/props/` like the basket, tent and cottage, with its sleep spots
  in `prop.gd`.
- **One dye** the Shop doesn't sell, which colours any dyeable item. It
  joins `Wear.DYES` marked as the pack's.

The art comes first:

1. Claude draws three candidate themes, each with a hat, a neck item and a
   face item, rendered on the cast with `design/wear/sheet.py`. It also
   draws three showpiece candidates and three dye colours, shown on items.
2. The developer picks by picker. Only the picks go into the builder.

**Picked (2026-11-26)**, from three themes (Starlight, Sweet shop, Little
hero), three showpieces, three dyes and three creator hats: the Starlight
set (Moon nightcap, Starry capelet, Star glasses), the Moon cradle, the
Royal blue dye (#5865DD), and the Director's beret as the creator hat. The
clothes are ported to `wear_draw.gd` too, so homemade kit critters can wear
them.

**Catalogue:** pack clothes get the tier `pack` in `catalogue.json`, which
has no price.

- `Wear.price()` reads 0 for it.
- `buy()` and `buy_dye()` refuse pack things, so a price of 0 can never mean
  free.
- Gifts already draw only small and medium items.
- Presents brought by visitors skip pack items (today they would divide by
  a price of 0).

## Creator perks

A creator code gives:

- **25,000 berries, once per code:** for dressing critters on camera. After
  Start over they are paid again on the next launch, so a creator can film a
  fresh start; Start over takes the berries back with everything else, so
  nothing builds up.
- **The creator hat:** a pack clothing item drawn for every species, never
  sold. Claude draws the candidates; the developer picks.
- **The Supporter Pack**, so creators can show it.
- **Creator mode:** a Creator section in System, under Codes, and a "Call a
  critter" item in the tray.
  - It calls any **everyday** species in Common, Rare or Epic: pick the
    species and the look, then press Call. The Legendary visitors are left
    out, so they stay a surprise for viewers.
  - Called critters come through the same path as the Admin page's spawns.
    They wear the player's outfits and stay for a normal visit.
  - They don't use a banked roll, record no sighting, pay no first-find
    berries and don't count in the Collection.
  - The Settings key `system.creator_mode` (default on) is an off switch for
    normal play.
  - The cap of 25 critters at once still holds.

A thank-you colour or named hat for creators who actually post stays a
separate, later decision; a spare kind number is free for it.

## A store build with the pack included

A build sold through another store unlocks the Supporter Pack without a
code. `codes.gd` counts the pack as owned when the build has the export
feature tag `pack_included`. That line is added now and can be tested
through an override.

The export preset that carries the tag belongs to that store build's own
planning session, since the distribution format is discuss-first. Creator
codes still redeem in such a build. How later packs reach that store's
players is also that session's question.

The player preset must never carry the tag: `codes_test.gd` reads
`export_presets.cfg` and fails if "Windows Desktop" has `pack_included` or
`admin`.

## Making codes, and keeping the key out of the repo

**`tools/codes/mint.py`** (Python, uses the `cryptography` package, a
developer-only tool and nothing bundled):

- `new-key` writes a new P-256 key, passphrase-encrypted, and prints the
  public key to paste into `codes.gd`.
- `batch --kind supporter --from 101 --count N` writes the codes one per
  line, ready to upload as itch.io external keys (type "Other"). It also
  adds the range to a private ledger: kind, serials, date, where they went.
- `canary` makes the canary code for the tests.
- `check CODE` says whether a code is real and what it is, for answering a
  buyer.

**Rules for the key:**

- The private key is a passphrase-encrypted file in a private folder outside
  every repo. A backup copy of the encrypted file is kept in cloud storage,
  and the passphrase is kept in a password manager.
- `mint.py` takes the key and output paths as arguments and refuses any
  path inside a git work tree. The repo holds no default path.
- `.gitignore` gains `*.pem`, `*.key`, `codes-*.txt` and `codes-ledger*.csv`.
- The Tests workflow gets a step that fails if any tracked file contains a
  PEM private-key header.
- The test key's private half is used once, to make the test codes, then
  thrown away. Only its public key and the codes it signed are committed.

**Ranges:**

- Serials 1 to 100 of each kind are the developer's, for testing on the VM.
- itch batches start at 101.
- The creator pool is a batch of creator codes kept with the private creator
  outreach records, outside this repo. Creators are given codes from that
  pool, so nobody running outreach needs the key.

**Who runs it:** making a batch needs the passphrase, so the developer runs
`mint.py` (or types the passphrase when Claude runs it in a terminal
tab).

**If the key is lost:** a new key number goes into the next release, and
every old code keeps working. **If it leaks:** the same, and future batches
use the new key. Codes made with the leaked key also keep working, because
there is no way to tell them from real ones and nothing is ever taken away.

**What a signature can't stop:** the source is public, so someone could
build a copy with the check taken out. The licence forbids passing such a
copy on. Like any game with paid cosmetics and public source, the code is
an honest lock rather than a safe.

## Admin and the audit

Per CLAUDE.md, each piece lands with its Admin control and audit row in the
same change.

**`admin.gd`:**

- It also trusts the test key (number 15). The player build leaves
  `admin.gd` out, so only the admin build and the tests accept test codes.
- New buttons:
  - **Supporter Pack: on/off** and **Creator: on/off**, for this session
    only, without a code.
  - **Forget codes:** `codes.json` is set aside as
    `codes.json.before-forget` and the redeem flow can be tried again.

**`checks()` in `admin_page.gd`, a new "Codes" group:**

| Check | Run | What to look for |
|---|---|---|
| Redeem a code | System › Codes with the test Supporter code pasted | Press Redeem: the thank-you note. The Shop shows the three clothes as "Supporter Pack", the showpiece puts out, and the dye is on offer for owned items. Pasting it again says it is already redeemed. |
| A code that isn't right | The test code with one letter changed, then one cut short | "Doesn't look right" for both, and nothing unlocks. |
| Creator code | The test creator code pasted | 25,000 berries once (relaunch: no more), the creator hat, the pack, the Creator section and the tray item. |
| Creator mode | Opens System › Creator | Each everyday species in each look walks in wearing its outfit. The Collection and berries don't change. Switched off, the tray item goes. |
| Codes stay | (manual) | Start over, quit and relaunch: the pack and creator mode are still there, and the creator berries come once more for the fresh start. |
| Without a code | Forget codes | No pack items anywhere in the Shop. System › Codes has the one line and the link. |
| A real code | (manual, VM) | One code from the developer's range of the real batch redeems in the installed player build. |

## Tests

**`godot/codes_test.gd`** (new; `run-tests.ps1` and CI pick it up):

- Reading pastes: spaces, dashes, line breaks, lower case, O, I and L.
  Wrong length.
- Committed test codes (Supporter, creator, an unknown kind): each passes
  with the test key. With one byte changed, a code fails. With only the
  real keys trusted, a test code fails.
- **The canary:** a kind-15 code signed with the real key checks out against
  the public key in `codes.gd`. That catches a build that has the wrong key
  in it, and the code is safe to publish because it grants nothing.
- The store:
  - Redeem, reload, still there. Already redeemed.
  - A revoked serial is refused when new and kept when old.
  - An unknown kind is kept and unlocks nothing until its kind is known.
  - A damaged file recovers from its .bak. Unknown keys survive. A newer
    file version is never written.
  - `pack_included` unlocks the pack with no codes.
- `export_presets.cfg`: the player preset carries neither `pack_included`
  nor `admin`.

**`economy_test.gd`:**

- `owns()`, `owns_dye()` and the showpiece check, with and without the pack.
- `buy()` and `buy_dye()` refuse pack things.
- 10,000 gifts and presents never give a pack item.
- The creator purse is paid once, survives a reload, and is paid again
  after Start over.
- Start over leaves the codes alone.

**`save_test.gd`:** economy keys this version doesn't know survive a load
and a save.

**`settings_test.gd`:** the `system.creator_mode` default.

## Order of work

| # | Step | Done when |
|---|---|---|
| 1 | `mint.py`, a throwaway test key, the committed test codes. | `mint.py check` reads them back. |
| 2 | The real key (`new-key`, the developer types the passphrase), its public key in `codes.gd`, the canary. | The canary checks out against it. |
| 3 | `codes.gd`, `codes_test.gd`. | The tests pass. |
| 4 | The economy hooks (owning, buy guards, gifts and presents, the creator purse, keeping unknown keys) with their tests. | `run-tests.ps1` passes. |
| 5 | The art round: candidates, then the developer's picks, then the picked items through `build.py`, the showpiece SVG and the dye. | Pack items render on every species (`--wear-sheet`, on the VM). |
| 6 | System › Codes, the Shop link, the notes, About, with their Admin buttons and audit rows. | The settings tour on the VM shows each state. |
| 7 | Creator mode: the System section, the tray item, calling, with its Admin and audit rows. | The Creator mode audit row passes on the VM. |
| 8 | CI and repo guards: the private-key step and `.gitignore`. | A test commit containing a key header fails CI on a branch. |
| 9 | The whole audit group on the VM with the admin build, then one real code in the player build. Release notes and README. Release. | Every row in the Codes group passes. |
| 10 | Sale set-up, outside the repo: one code from the developer's range uploaded to the pack's itch project as a test (does itch take 109 characters with dashes; how does the claimed key look). Then the batch. | A test purchase shows a code that redeems. |

If itch won't take dashes or the full length, upload codes without dashes;
the Redeem box ignores them either way.
