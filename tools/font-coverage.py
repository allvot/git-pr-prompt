#!/usr/bin/env python3
"""Does your font actually contain the glyphs this prompt uses?

    python3 tools/font-coverage.py                 # scan installed Nerd Fonts
    python3 tools/font-coverage.py path/to/Font.ttf
    python3 tools/font-coverage.py --names Font.ttf  # family names it registers

Reads the font's `cmap` table directly — stdlib only, no fontTools. Use it when
glyphs show as boxes to tell "the font lacks them" apart from "the terminal
isn't using the font I think it is".

That second case is the common one, and the `--names` output is why: Homebrew's
casks register nameID 1 as the SHORT family ("JetBrainsMono NFM"), while the
long "JetBrainsMono Nerd Font Mono" is only nameID 16. Terminals matching on
nameID 1 silently fall back per character if you configure the long name.
"""
import glob
import os
import struct
import sys

# Codepoint -> what the prompt uses it for. Keep in sync with presets/nerdfont.zsh.
GLYPHS = [
    (0xF407, "pr_open",         "oct-git_pull_request"),
    (0xF4DD, "pr_draft",        "oct-git_pull_request_draft"),
    (0xF419, "pr_merged",       "oct-git_merge"),
    (0xF4DC, "pr_closed",       "oct-git_pull_request_closed"),
    (0xF4A4, "review_approved", "oct-check_circle_fill"),
    (0xF52F, "review_changes",  "oct-x_circle"),
    (0xF441, "review_pending",  "oct-eye"),
    (0xF418, "branch_prefix",   "oct-git_branch"),
    (0xF448, "dirty",           "oct-pencil"),
    (0xF44D, "staged",          "oct-plus"),
    (0xF420, "untracked",       "oct-question"),
    (0xF431, "ahead",           "oct-arrow_up"),
    (0xF433, "behind",          "oct-arrow_down"),
    (0xF51E, "stash",           "oct-stack"),
]


def _table_offset(data, want, base=12):
    count = struct.unpack(">H", data[4:6])[0]
    for i in range(count):
        rec = base + i * 16
        tag, _sum, off, _len = struct.unpack(">4sIII", data[rec:rec + 16])
        if tag == want:
            return off
    return None


def codepoints(path):
    """Every codepoint the font maps, from cmap formats 4 and 12."""
    with open(path, "rb") as fh:
        data = fh.read()

    cmap = _table_offset(data, b"cmap")
    if cmap is None:
        return set()

    n_sub = struct.unpack(">H", data[cmap + 2:cmap + 4])[0]
    found = set()

    for i in range(n_sub):
        rec = cmap + 4 + i * 8
        _plat, _enc, sub_off = struct.unpack(">HHI", data[rec:rec + 8])
        sub = cmap + sub_off
        fmt = struct.unpack(">H", data[sub:sub + 2])[0]

        if fmt == 4:
            seg_x2 = struct.unpack(">H", data[sub + 6:sub + 8])[0]
            seg = seg_x2 // 2
            ends = struct.unpack(">%dH" % seg, data[sub + 14:sub + 14 + seg_x2])
            s_at = sub + 16 + seg_x2
            starts = struct.unpack(">%dH" % seg, data[s_at:s_at + seg_x2])
            for s, e in zip(starts, ends):
                if s != 0xFFFF:
                    found.update(range(s, min(e, 0xFFFF) + 1))

        elif fmt == 12:
            n_groups = struct.unpack(">I", data[sub + 12:sub + 16])[0]
            for g in range(n_groups):
                go = sub + 16 + g * 12
                start, end, _gid = struct.unpack(">III", data[go:go + 12])
                if end - start <= 0x10000:
                    found.update(range(start, end + 1))

    return found


def family_names(path):
    """{nameID: value} for the family-ish records, platform 3 (Windows/Unicode)."""
    with open(path, "rb") as fh:
        data = fh.read()

    name = _table_offset(data, b"name")
    if name is None:
        return {}

    _fmt, count, str_off = struct.unpack(">HHH", data[name:name + 6])
    out = {}
    for i in range(count):
        rec = name + 6 + i * 12
        pid, _eid, _lid, nid, ln, off = struct.unpack(">HHHHHH", data[rec:rec + 12])
        if pid == 3 and nid in (1, 4, 6, 16):
            start = name + str_off + off
            value = data[start:start + ln].decode("utf-16-be", "ignore")
            out.setdefault(nid, value)
    return out


def report(path):
    have = codepoints(path)
    missing = [(c, k, n) for c, k, n in GLYPHS if c not in have]

    print("\n%s" % os.path.basename(path))
    names = family_names(path)
    if names:
        print("  family (nameID 1, what terminals match): %s" % names.get(1, "?"))
        if names.get(16) and names.get(16) != names.get(1):
            print("  typographic family (nameID 16):           %s" % names[16])

    if not missing:
        print("  ✓ all %d prompt glyphs present" % len(GLYPHS))
        return True

    print("  ✗ %d of %d missing:" % (len(missing), len(GLYPHS)))
    for code, key, nerd_name in missing:
        print("      U+%04X  %-16s %s" % (code, key, nerd_name))
    return False


def installed_fonts():
    dirs = [
        os.path.expanduser("~/Library/Fonts"),
        "/Library/Fonts",
        os.path.expanduser("~/.local/share/fonts"),
        os.path.expanduser("~/.fonts"),
        "/usr/share/fonts",
    ]
    hits = []
    for d in dirs:
        for ext in ("ttf", "otf"):
            hits += glob.glob(os.path.join(d, "**", "*.%s" % ext), recursive=True)
    keep = [f for f in hits
            if any(t in os.path.basename(f).lower()
                   for t in ("nerd", "nf-", "powerline"))]
    # One representative per family: Regular only, to keep output short.
    return sorted(f for f in keep if "regular" in f.lower()) or sorted(keep)


def main(argv):
    if argv and argv[0] == "--names":
        for path in argv[1:]:
            print("\n%s" % os.path.basename(path))
            for nid, value in sorted(family_names(path).items()):
                print("  nameID %-3d %s" % (nid, value))
        return 0

    paths = argv or installed_fonts()
    if not paths:
        print("No Nerd Font files found. Install one:")
        print("  brew install --cask font-jetbrains-mono-nerd-font")
        return 1

    ok = all(report(p) for p in paths)

    print("\nGlyphs present but still showing as boxes? The terminal isn't using")
    print("this font. Check the family name above against your terminal config —")
    print("use the nameID 1 spelling.")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
