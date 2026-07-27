#!/usr/bin/env python3
"""Turn ANSI-colored terminal output into an SVG, for the README.

    zsh tools/samples.zsh prompt | python3 tools/ansi2svg.py --theme dark > out.svg

GitHub strips ANSI escapes from code blocks and sanitizes `style` attributes on
inline HTML, so a colored terminal example can only be an image. SVG keeps it
text — diffable in review, sharp at any zoom — unlike a screenshot.

Reads stdin, writes SVG to stdout. Stdlib only. Handles the SGR subset this
prompt emits: reset, the 8 basic and 8 bright foregrounds, and 256-color
(38;5;N). Anything else is ignored rather than guessed at.
"""
import argparse
import re
import sys

# Terminal palettes. Foreground colors are what `%F{green}` and friends become;
# ANSI has no fixed definition for them, so these are chosen to stay legible on
# each theme's background rather than copied from any one terminal.
THEMES = {
    "dark": {
        "bg": "#0d1117", "fg": "#c9d1d9",
        "basic": ["#484f58", "#ff7b72", "#3fb950", "#d29922",
                  "#58a6ff", "#bc8cff", "#39c5cf", "#b1bac4"],
        "bright": ["#6e7681", "#ffa198", "#56d364", "#e3b341",
                   "#79c0ff", "#d2a8ff", "#56d4dd", "#f0f6fc"],
    },
    "light": {
        "bg": "#ffffff", "fg": "#24292f",
        "basic": ["#24292f", "#cf222e", "#1a7f37", "#9a6700",
                  "#0969da", "#8250df", "#1b7c83", "#6e7781"],
        "bright": ["#57606a", "#a40e26", "#116329", "#7d4e00",
                   "#0550ae", "#6639ba", "#3192aa", "#8c959f"],
    },
}

FONT = ("'JetBrainsMono Nerd Font Mono', 'JetBrains Mono', "
        "ui-monospace, SFMono-Regular, Menlo, Consolas, monospace")

SGR = re.compile(r"\x1b\[([0-9;]*)m")
CELL_W = 0.60          # advance width of a monospace cell, in em
LINE_H = 1.45          # line height, in em
PAD = 12               # px padding inside the rounded rect


def xterm256(n, theme):
    """Hex for a 256-color index: 0-15 palette, 16-231 cube, 232-255 gray."""
    if n < 8:
        return theme["basic"][n]
    if n < 16:
        return theme["bright"][n - 8]
    if n < 232:
        n -= 16
        levels = [0, 95, 135, 175, 215, 255]
        r, g, b = levels[n // 36], levels[(n // 6) % 6], levels[n % 6]
        return "#%02x%02x%02x" % (r, g, b)
    v = 8 + (n - 232) * 10
    return "#%02x%02x%02x" % (v, v, v)


def parse_line(line, theme):
    """[(text, color_or_None)] for one line, applying SGR codes as they appear."""
    spans, pos, color = [], 0, None

    for m in SGR.finditer(line):
        if m.start() > pos:
            spans.append((line[pos:m.start()], color))
        pos = m.end()

        codes = [int(c) for c in m.group(1).split(";") if c != ""] or [0]
        i = 0
        while i < len(codes):
            c = codes[i]
            if c in (0, 39):
                color = None
            elif 30 <= c <= 37:
                color = theme["basic"][c - 30]
            elif 90 <= c <= 97:
                color = theme["bright"][c - 90]
            elif c == 38 and codes[i + 1:i + 2] == [5]:
                color = xterm256(codes[i + 2], theme)
                i += 2
            i += 1

    if pos < len(line):
        spans.append((line[pos:], color))
    return spans


def escape(s):
    return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def render(text, theme_name, font_size, title):
    theme = THEMES[theme_name]
    raw = [l.rstrip("\n") for l in text.splitlines()]
    lines = [parse_line(l, theme) for l in raw]

    # Width from the widest line, measured with the escapes removed.
    # +1 cell of slack: the final glyph may be wider than a cell if it comes
    # from a fallback font.
    cols = max((len(SGR.sub("", l)) for l in raw), default = 0) + 1
    width = round(cols * CELL_W * font_size) + PAD * 2
    height = round(len(lines) * LINE_H * font_size) + PAD * 2

    out = [
        '<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" '
        'viewBox="0 0 %d %d" role="img" aria-label="%s">'
        % (width, height, width, height, escape(title)),
        '<rect width="%d" height="%d" rx="8" fill="%s"/>' % (width, height, theme["bg"]),
        '<text xml:space="preserve" font-family="%s" font-size="%dpx" fill="%s">'
        % (FONT, font_size, theme["fg"]),
    ]

    for row, spans in enumerate(lines):
        y = round(PAD + (row + 0.95) * LINE_H * font_size)
        # Every span gets an explicit x on the cell grid. Letting them flow from
        # one x instead lets drift accumulate: the symbols (│ ↑ ≡ ⊙ ✓) often come
        # from a fallback font whose advance isn't the cell width, which pushed
        # the end of the line outside the viewBox.
        col = 0
        for chunk, color in spans:
            if not chunk:
                continue
            x = PAD + col * CELL_W * font_size
            fill = ' fill="%s"' % color if color else ""
            out.append('<tspan x="%.1f" y="%d"%s>%s</tspan>'
                       % (x, y, fill, escape(chunk)))
            col += len(chunk)

    out += ["</text>", "</svg>", ""]
    return "\n".join(out)


def main():
    ap = argparse.ArgumentParser(description = __doc__)
    ap.add_argument("--theme", choices = sorted(THEMES), default = "dark")
    ap.add_argument("--font-size", type = int, default = 15)
    ap.add_argument("--title", default = "gauge prompt example",
                    help = "accessible label for the image")
    args = ap.parse_args()

    sys.stdout.write(render(sys.stdin.read(), args.theme, args.font_size, args.title))
    return 0


if __name__ == "__main__":
    sys.exit(main())
