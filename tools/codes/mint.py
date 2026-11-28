"""Makes and checks Critter Overlay codes (docs/codes-plan.md).

A code is 68 bytes: a 4-byte header and an ECDSA P-256 signature over it.

  header     byte 0: key number (high 4 bits, 1 to 14 real, 15 the test key)
             and kind (low 4 bits); bytes 1 to 3: the serial, big-endian
  signature  ECDSA P-256 over SHA-256 of "CritterOverlay code v1", a zero
             byte, then the header; stored raw as r then s (32 bytes each)

It is written as 109 Crockford base32 characters in groups of 5 joined by
dashes. The app (godot/codes.gd) holds only the public keys.

Usage:
  python tools/codes/mint.py new-key --out KEYFILE
  python tools/codes/mint.py batch --key KEYFILE --kind supporter --from 101
      --count N --out CODEFILE --ledger LEDGER --to "where they went"
  python tools/codes/mint.py canary --key KEYFILE
  python tools/codes/mint.py check CODE

The private key is a passphrase-encrypted PEM file kept outside every repo.
Every path comes from an argument, and a path inside a git work tree is
refused, so a key, a batch or the ledger can't land in a repo by mistake.
The passphrase is asked for at the terminal (or read from stdin when that
isn't a terminal).

A key is used through the public key the app trusts: batch and canary look
for this key's public key in godot/codes.gd (or, for the test key, in
godot/admin.gd) and take the key number from there, refusing a key the app
doesn't hold. check verifies against the same files.

The ledger is a CSV of every batch (date, key, kind, first, last, to). batch
refuses a serial the ledger already has for that kind, under any key, since
a revoked code is named by its kind and serial.

Needs the cryptography package. A developer-only tool; nothing here ships.
"""

import argparse
import base64
import csv
import datetime as dt
import getpass
import re
import sys
from pathlib import Path

from cryptography.exceptions import InvalidSignature
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.hazmat.primitives.asymmetric.utils import (
    decode_dss_signature, encode_dss_signature)

REPO = Path(__file__).resolve().parents[2]
KEY_FILES = [REPO / "godot" / "codes.gd", REPO / "godot" / "admin.gd"]

DOMAIN = b"CritterOverlay code v1\x00"
ALPHABET = "0123456789ABCDEFGHJKMNPQRSTVWXYZ"   # Crockford: no I, L, O, U
CODE_BYTES = 68
CODE_CHARS = 109                                 # 68 * 8 = 544 bits, 1 to spare
MAX_SERIAL = 0xFFFFFF
TEST_KEY = 15
KINDS = {"supporter": 1, "creator": 2}
CANARY = 15
NAMES = {1: "Supporter", 2: "creator", 14: "spare", 15: "canary"}
MIN_PASSPHRASE = 12
LEDGER_FIELDS = ["date", "key", "kind", "first", "last", "to"]


class Refused(Exception):
    pass


# --- The text -------------------------------------------------------------------

def encode(data: bytes) -> str:
    n = int.from_bytes(data, "big") << (CODE_CHARS * 5 - len(data) * 8)
    chars = [ALPHABET[(n >> (5 * i)) & 31] for i in reversed(range(CODE_CHARS))]
    text = "".join(chars)
    return "-".join(text[i:i + 5] for i in range(0, len(text), 5))


def read_paste(text: str) -> bytes:
    """A pasted code to its 68 bytes, as the app reads it: upper case, only
    letters and digits, O as 0 and I or L as 1."""
    t = re.sub(r"[^0-9A-Z]", "", text.upper())
    t = t.replace("O", "0").replace("I", "1").replace("L", "1")
    if len(t) != CODE_CHARS:
        raise Refused(f"that is {len(t)} characters; a code has {CODE_CHARS}")
    n = 0
    for c in t:
        v = ALPHABET.find(c)
        if v < 0:
            raise Refused(f"{c} is never in a code")
        n = n << 5 | v
    if n & 1:
        raise Refused("the last character is not one a code ends with")
    return (n >> 1).to_bytes(CODE_BYTES, "big")


def header(key_no: int, kind: int, serial: int) -> bytes:
    return bytes([key_no << 4 | kind]) + serial.to_bytes(3, "big")


def parse_header(data: bytes) -> tuple:
    return data[0] >> 4, data[0] & 15, int.from_bytes(data[1:4], "big")


def kind_name(kind: int) -> str:
    return NAMES.get(kind, f"later pack (kind {kind})")


# --- Keys -----------------------------------------------------------------------

def public_b64(key) -> str:
    der = key.public_key().public_bytes(
        serialization.Encoding.DER, serialization.PublicFormat.SubjectPublicKeyInfo)
    return base64.b64encode(der).decode()


def trusted_keys() -> dict:
    """{key number: public key} from the app's sources, as `N: "MFkw..."`."""
    out = {}
    for f in KEY_FILES:
        if f.exists():
            for no, b64 in re.findall(r'^\s*(\d+)\s*:\s*"(MF[0-9A-Za-z+/=]{100,})"',
                                      f.read_text(encoding="utf-8"), re.M):
                out[int(no)] = b64
    return out


def load_public(b64: str):
    return serialization.load_der_public_key(base64.b64decode(b64))


def git_tree(path: Path):
    """The git work tree holding path, if any."""
    p = path.expanduser().resolve()
    for d in [p, *p.parents]:
        if (d / ".git").exists():
            return d
    return None


def outside_git(path: str, what: str) -> Path:
    p = Path(path).expanduser().resolve()
    tree = git_tree(p)
    if tree:
        raise Refused(f"the {what} ({p}) is inside the git work tree {tree}; "
                      "keep it in a private folder outside every repo")
    return p


def passphrase(prompt: str, confirm=False) -> bytes:
    if sys.stdin.isatty():
        first = getpass.getpass(prompt)
        if confirm and getpass.getpass("Again: ") != first:
            raise Refused("the two passphrases differ")
    else:
        first = sys.stdin.readline().rstrip("\r\n")
        if confirm and sys.stdin.readline().rstrip("\r\n") != first:
            raise Refused("the two passphrases differ")
    return first.encode()


def load_key(path: str):
    p = outside_git(path, "key")
    if not p.is_file():
        raise Refused(f"no key at {p}")
    data = p.read_bytes()
    if b"ENCRYPTED" not in data:
        raise Refused(f"{p} is not passphrase-encrypted")
    try:
        key = serialization.load_pem_private_key(data, passphrase("Passphrase: "))
    except (ValueError, TypeError):
        raise Refused("wrong passphrase, or not a key file")
    if not isinstance(key, ec.EllipticCurvePrivateKey) or key.curve.name != "secp256r1":
        raise Refused(f"{p} is not a P-256 key")
    pub = public_b64(key)
    for no, b64 in trusted_keys().items():
        if b64 == pub:
            return key, no
    raise Refused("the app doesn't trust this key yet: add its public key to "
                  f"KEYS in godot/codes.gd first:\n  {pub}")


# --- Codes ----------------------------------------------------------------------

def sign(key, key_no: int, kind: int, serial: int) -> str:
    h = header(key_no, kind, serial)
    r, s = decode_dss_signature(key.sign(DOMAIN + h, ec.ECDSA(hashes.SHA256())))
    code = encode(h + r.to_bytes(32, "big") + s.to_bytes(32, "big"))
    if verify(code)[0] != "real":
        raise Refused("a code just made does not check out; nothing was written")
    return code


def verify(text: str) -> tuple:
    """("real" | "not real" | "unknown key", key number, kind, serial)."""
    data = read_paste(text)
    key_no, kind, serial = parse_header(data)
    b64 = trusted_keys().get(key_no)
    if not b64:
        return "unknown key", key_no, kind, serial
    r = int.from_bytes(data[4:36], "big")
    s = int.from_bytes(data[36:68], "big")
    try:
        load_public(b64).verify(encode_dss_signature(r, s), DOMAIN + data[:4],
                                ec.ECDSA(hashes.SHA256()))
    except (InvalidSignature, ValueError):
        return "not real", key_no, kind, serial
    return "real", key_no, kind, serial


def read_ledger(path: Path) -> list:
    if not path.exists():
        return []
    with path.open(newline="", encoding="utf-8") as f:
        return list(csv.DictReader(f))


# --- Commands -------------------------------------------------------------------

def cmd_new_key(a):
    out = outside_git(a.out, "key file")
    if out.exists():
        raise Refused(f"{out} already exists; a key is never overwritten")
    if not out.parent.is_dir():
        raise Refused(f"no folder {out.parent}")
    pw = passphrase("New passphrase: ", confirm=True)
    if len(pw) < MIN_PASSPHRASE:
        raise Refused(f"use a passphrase of at least {MIN_PASSPHRASE} characters")
    key = ec.generate_private_key(ec.SECP256R1())
    pem = key.private_bytes(serialization.Encoding.PEM, serialization.PrivateFormat.PKCS8,
                            serialization.BestAvailableEncryption(pw))
    with out.open("xb") as f:
        f.write(pem)
    taken = trusted_keys()
    nxt = next((n for n in range(1, TEST_KEY) if n not in taken), None)
    print(f"Wrote the key to {out}, encrypted with the passphrase.")
    print("Back the file up and keep the passphrase in a password manager.")
    print("Then add its public key to KEYS in godot/codes.gd" +
          (f" as key {nxt}:" if nxt else " (every key number is taken):"))
    print(f'\t{nxt or "N"}: "{public_b64(key)}",')


def cmd_batch(a):
    kind = KINDS.get(a.kind.lower()) or (int(a.kind) if a.kind.isdigit() else 0)
    if not (1 <= kind <= 13):
        raise Refused("kind is supporter, creator, or 3 to 13 for a later pack")
    first, last = a.first, a.first + a.count - 1
    if a.count < 1 or first < 1 or last > MAX_SERIAL:
        raise Refused(f"serials run from 1 to {MAX_SERIAL}")
    out = outside_git(a.out, "code file")
    ledger = outside_git(a.ledger, "ledger")
    if out.exists():
        raise Refused(f"{out} already exists")
    for row in read_ledger(ledger):
        if int(row["kind"]) == kind and int(row["first"]) <= last and first <= int(row["last"]):
            raise Refused(f"serials {row['first']} to {row['last']} of {kind_name(kind)} "
                          f"codes were used on {row['date']} ({row['to']})")
    key, key_no = load_key(a.key)
    codes = [sign(key, key_no, kind, n) for n in range(first, last + 1)]
    # The ledger first: a batch that is then not written wastes its serials
    # rather than leaving them free to be used twice.
    new = not ledger.exists()
    with ledger.open("a", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, LEDGER_FIELDS)
        if new:
            w.writeheader()
        w.writerow({"date": dt.date.today().isoformat(), "key": key_no, "kind": kind,
                    "first": first, "last": last, "to": a.to})
    with out.open("x", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(codes) + "\n")
    print(f"Wrote {len(codes)} {kind_name(kind)} code{'s' if len(codes) > 1 else ''} "
          f"(key {key_no}, serials "
          f"{first} to {last}) to {out}, and added them to the ledger.")


def cmd_canary(a):
    key, key_no = load_key(a.key)
    print(sign(key, key_no, CANARY, a.serial))


def cmd_check(a):
    status, key_no, kind, serial = verify(" ".join(a.code))
    what = f"{kind_name(kind)} code, serial {serial}, key {key_no}"
    if status == "real":
        test = "; the test key, so only the admin build and the tests take it"
        print(f"Real: a {what}{test if key_no == TEST_KEY else ''}.")
        return 0
    if status == "unknown key":
        print(f"Not real: it names key {key_no}, which the app doesn't have ({what}).")
    else:
        print(f"Not real: the signature doesn't match key {key_no} ({what}).")
    return 1


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    sub = ap.add_subparsers(dest="cmd", required=True)
    p = sub.add_parser("new-key", help="make a new passphrase-encrypted key")
    p.add_argument("--out", required=True, help="the new key file, outside every repo")
    p = sub.add_parser("batch", help="make a batch of codes and add it to the ledger")
    p.add_argument("--key", required=True)
    p.add_argument("--kind", required=True, help="supporter, creator, or 3 to 13")
    p.add_argument("--from", dest="first", type=int, required=True, help="first serial")
    p.add_argument("--count", type=int, required=True)
    p.add_argument("--out", required=True, help="the code file, one code a line")
    p.add_argument("--ledger", required=True, help="the private ledger (CSV)")
    p.add_argument("--to", required=True, help="where the batch goes, for the ledger")
    p = sub.add_parser("canary", help="make the canary code, which grants nothing")
    p.add_argument("--key", required=True)
    p.add_argument("--serial", type=int, default=1)
    p = sub.add_parser("check", help="say whether a code is real and what it is")
    p.add_argument("code", nargs="+", help="the code, as pasted")
    a = ap.parse_args(argv)
    try:
        return {"new-key": cmd_new_key, "batch": cmd_batch, "canary": cmd_canary,
                "check": cmd_check}[a.cmd](a) or 0
    except Refused as e:
        print(f"Refused: {e}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
