#!/usr/bin/env python3
"""Makes the custom symbol images of the food categories that SF Symbols does not have.

    python3 scripts/make-category-symbols.py             Write the symbol sets into the asset catalog.
    python3 scripts/make-category-symbols.py --preview D Write also one plain SVG file for each symbol into folder D.

The symbols are a wedge of cheese (dairy), a steak (meat), and a slice of bread (bakery). They have the same subjects
as `ic_cheese`, `ic_food_steak`, and `ic_bread_slice` of the Android app, but they are drawn again in the style of SF
Symbols: an outline form and a filled form, with round corners and the line weight of the system symbols.

Each symbol is drawn on a 24 by 24 grid from round polygons, circles, and lines with a width. The script draws each
symbol with three line widths and writes them as the variants Ultralight-S, Regular-S, and Black-S of a symbol
template (version 3.0). The three variants have the same commands in the same order, so Xcode calculates each other
weight and scale from them. A symbol image then follows the text size, the text weight, and the tint, as a system
symbol does.

Do not edit the SVG files by hand. Change the shapes in this file and run it again. It uses the Python standard
library only.
"""
import json
import math
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CATALOG = ROOT / "CVKEFridge" / "Resources" / "Assets.xcassets" / "Symbols"

# The line width on the grid for each weight of the template.
WEIGHTS = {"Ultralight": 0.45, "Regular": 1.55, "Black": 2.5}
# The x position of each variant on the artboard of the template.
VARIANT_X = {"Ultralight": 560.0, "Regular": 1440.0, "Black": 2900.0}
# One unit of the grid in units of the template, for the small scale at 100 points.
UNIT = 4.2
# The centre of the cap height above the baseline, and the cap height, in units of the template.
CAP_HEIGHT = 70.459
CENTRE_Y = -CAP_HEIGHT / 2
# The free space at each side of a symbol, in units of the template.
MARGIN = 7.0
# The baseline of each scale on the artboard of the template. The symbols are on the baseline of the small scale.
SCALE_BASELINES = {"S": 696.0, "M": 1126.0, "L": 1556.0}
BASELINE = SCALE_BASELINES["S"]
# The smallest corner radius. A corner keeps its curve command when its radius is too small for the line width.
MIN_RADIUS = 0.02


def sub(a, b):
    return (a[0] - b[0], a[1] - b[1])


def add(a, b):
    return (a[0] + b[0], a[1] + b[1])


def mul(a, k):
    return (a[0] * k, a[1] * k)


def unit(a):
    length = math.hypot(a[0], a[1])
    return (a[0] / length, a[1] / length)


def cross(a, b):
    return a[0] * b[1] - a[1] * b[0]


def corners(points):
    """For each point of a closed polygon: the point, the direction to it, and the direction from it."""
    count = len(points)
    result = []
    for index, point in enumerate(points):
        before = unit(sub(point, points[index - 1]))
        after = unit(sub(points[(index + 1) % count], point))
        result.append((point, before, after))
    return result


def round_polygon(points, radii):
    """The commands of a closed polygon with round corners. The y axis goes down, and the points go clockwise.

    A corner that turns to the inside of the shape is convex. A corner that turns to the outside is concave, and it
    gets the same curve on its other side.
    """
    commands = []
    count = len(points)
    reach = []
    for index, (point, before, after) in enumerate(corners(points)):
        radius = max(radii[index], MIN_RADIUS)
        turn = math.acos(max(-1.0, min(1.0, before[0] * after[0] + before[1] * after[1])))
        reach.append(radius * math.tan(turn / 2))
    for index in range(count):
        # The curves of the two ends of a side must not go across each other.
        side = math.hypot(*sub(points[(index + 1) % count], points[index]))
        if reach[index] + reach[(index + 1) % count] > side + 1e-6:
            sys.exit("The corners %d and %d of %r are too round for the side between them" % (index, index + 1, points))
    for index, (point, before, after) in enumerate(corners(points)):
        radius = max(radii[index], MIN_RADIUS)
        turn = math.acos(max(-1.0, min(1.0, before[0] * after[0] + before[1] * after[1])))
        tangent = reach[index]
        handle = radius * 4 / 3 * math.tan(turn / 4)
        start = sub(point, mul(before, tangent))
        end = add(point, mul(after, tangent))
        commands.append(("M" if index == 0 else "L", [start]))
        commands.append(("C", [add(start, mul(before, handle)), sub(end, mul(after, handle)), end]))
    commands.append(("Z", []))
    return commands


def inset(points, radii, width):
    """The polygon that is `width` inside the polygon, with the radii that keep the line width at each corner."""
    lines = []
    count = len(points)
    for index, point in enumerate(points):
        direction = unit(sub(points[(index + 1) % count], point))
        normal = (-direction[1], direction[0])
        lines.append((add(point, mul(normal, width)), direction))
    new_points = []
    new_radii = []
    for index, (point, before, after) in enumerate(corners(points)):
        (p1, d1), (p2, d2) = lines[index - 1], lines[index]
        # The point where the two moved sides meet.
        k = cross(sub(p2, p1), d2) / cross(d1, d2)
        new_points.append(add(p1, mul(d1, k)))
        convex = cross(before, after) > 0
        new_radii.append(radii[index] - width if convex else radii[index] + width)
    return new_points, new_radii


def reverse(points, radii):
    """The same polygon in the opposite direction, so that it makes a hole in a shape around it."""
    return points[::-1], radii[::-1]


def circle(centre, radius, hole=False):
    """The commands of a circle. A hole goes in the opposite direction."""
    radius = max(radius, MIN_RADIUS)
    k = radius * 0.5522847498
    cx, cy = centre
    points = [(cx + radius, cy), (cx, cy + radius), (cx - radius, cy), (cx, cy - radius)]
    # The direction of the circle at each point, clockwise.
    directions = [(0, 1), (-1, 0), (0, -1), (1, 0)]
    order = [0, 3, 2, 1] if hole else [0, 1, 2, 3]
    sign = -k if hole else k
    commands = [("M", [points[order[0]]])]
    for step in range(4):
        a = order[step]
        b = order[(step + 1) % 4]
        commands.append(("C", [add(points[a], mul(directions[a], sign)), sub(points[b], mul(directions[b], sign)),
                               points[b]]))
    commands.append(("Z", []))
    return commands


def outline(points, radii, width):
    """A line of the `width` along the inside of the polygon: the polygon, and its inset as a hole."""
    return round_polygon(points, radii) + round_polygon(*reverse(*inset(points, radii, width)))


# The shapes. Each function returns the commands of one symbol for a line width.

# A wedge of cheese from the side: a low end at the left, a high end at the right, and three holes.
CHEESE = [(2.4, 11.4), (21.6, 4.4), (21.6, 19.6), (2.4, 19.6)]
CHEESE_RADII = [2.0, 2.2, 2.2, 2.0]
CHEESE_HOLES = [((16.1, 13.2), 2.05), ((8.7, 14.9), 1.45), ((11.9, 11.4), 0.95)]


def cheese(width):
    # A heavy line leaves less room in the wedge: the holes become smaller and move away from the line.
    heavy = max(0.0, width - WEIGHTS["Regular"])
    light = max(0.0, WEIGHTS["Regular"] - width)
    commands = outline(CHEESE, CHEESE_RADII, width)
    for (x, y), radius in CHEESE_HOLES:
        commands += circle((x - heavy * 0.1, y + heavy * 0.45), radius - heavy * 0.3 - light * 0.25)
    return commands


def cheese_fill(width):
    grow = (WEIGHTS["Regular"] - width) * 0.12
    commands = round_polygon(CHEESE, CHEESE_RADII)
    for centre, radius in CHEESE_HOLES:
        commands += circle(centre, radius + 0.25 + grow, hole=True)
    return commands


# A steak: a wide round part at the top, a narrow end at the bottom right, and the round bone.
STEAK = [(3.2, 2.6), (20.8, 2.6), (20.8, 21.4), (11.6, 21.4), (11.6, 17.2), (3.2, 12.4)]
STEAK_RADII = [5.6, 6.4, 3.8, 2.8, 2.2, 7.0]
STEAK_BONE = (10.3, 8.6)


def steak(width):
    # A heavy line leaves less room: the bone moves to the centre of the wide part.
    heavy = max(0.0, width - WEIGHTS["Regular"])
    centre = (STEAK_BONE[0] + heavy * 0.5, STEAK_BONE[1] + heavy * 0.6)
    bone = 2.6 + width * 0.2
    commands = outline(STEAK, STEAK_RADII, width)
    commands += circle(centre, bone)
    commands += circle(centre, bone - width * 0.85, hole=True)
    return commands


def steak_fill(width):
    gap = 0.75 + width * 0.3
    commands = round_polygon(STEAK, STEAK_RADII)
    commands += circle(STEAK_BONE, 3.1 + gap * 0.5, hole=True)
    commands += circle(STEAK_BONE, 3.1 - gap * 0.5)
    return commands


# A slice of bread: the wide round top of the loaf, and the narrow body below it.
BREAD = [(2.2, 2.8), (21.8, 2.8), (21.8, 9.6), (19.2, 12.8), (19.2, 21.2), (4.8, 21.2), (4.8, 12.8), (2.2, 9.6)]
BREAD_RADII = [5.4, 5.4, 3.0, 1.2, 2.6, 2.6, 1.2, 3.0]


def bread(width):
    return outline(BREAD, BREAD_RADII, width)


def bread_fill(width):
    return round_polygon(BREAD, BREAD_RADII)


SYMBOLS = {
    "cvke.cheese": cheese,
    "cvke.cheese.fill": cheese_fill,
    "cvke.steak": steak,
    "cvke.steak.fill": steak_fill,
    "cvke.bread.slice": bread,
    "cvke.bread.slice.fill": bread_fill,
}


def number(value):
    text = "%.3f" % value
    return text.rstrip("0").rstrip(".") if "." in text else text


def path_data(commands, transform):
    parts = []
    for letter, points in commands:
        parts.append(letter + " ".join("%s %s" % (number(x), number(y)) for x, y in map(transform, points)))
    return " ".join(parts)


def bounds(commands):
    xs = [p[0] for _, points in commands for p in points]
    ys = [p[1] for _, points in commands for p in points]
    return min(xs), min(ys), max(xs), max(ys)


def template(name, draw):
    """The text of the symbol template of one symbol."""
    guides = []
    groups = []
    # The three weights have the same box, so that the symbol does not move when the weight changes.
    left, top, right, bottom = bounds(draw(WEIGHTS["Regular"]))
    width = (right - left) * UNIT
    for weight, line in WEIGHTS.items():
        x0 = VARIANT_X[weight]

        def place(point, left=left, top=top, bottom=bottom):
            return ((point[0] - left) * UNIT, CENTRE_Y + (point[1] - (top + bottom) / 2) * UNIT)

        style = "fill:none;stroke:#00AEEF;stroke-width:0.5;opacity:1.0;"
        guides.append('  <line id="left-margin-%s-S" style="%s" x1="%s" x2="%s" y1="600" y2="720"/>'
                      % (weight, style, number(x0 - MARGIN), number(x0 - MARGIN)))
        guides.append('  <line id="right-margin-%s-S" style="%s" x1="%s" x2="%s" y1="600" y2="720"/>'
                      % (weight, style, number(x0 + width + MARGIN), number(x0 + width + MARGIN)))
        groups.append('  <g id="%s-S" transform="matrix(1 0 0 1 %s %s)">\n   <path d="%s"/>\n  </g>'
                      % (weight, number(x0), number(BASELINE), path_data(draw(line), place)))
    guide = "fill:none;stroke:#27AAE1;opacity:1;stroke-width:0.5;"
    # The template needs the baseline and the cap line of each of the three scales, also with symbols of one scale.
    scale_guides = []
    for scale, baseline in SCALE_BASELINES.items():
        scale_guides.append('  <line id="Baseline-%s" style="%s" x1="263" x2="3036" y1="%s" y2="%s"/>'
                            % (scale, guide, number(baseline), number(baseline)))
        scale_guides.append('  <line id="Capline-%s" style="%s" x1="263" x2="3036" y1="%s" y2="%s"/>'
                            % (scale, guide, number(baseline - CAP_HEIGHT), number(baseline - CAP_HEIGHT)))
    return "\n".join([
        '<?xml version="1.0" encoding="UTF-8"?>',
        "<!-- %s: a symbol of CVKE Fridge. scripts/make-category-symbols.py makes this file. Do not edit it. -->" % name,
        '<svg version="1.1" xmlns="http://www.w3.org/2000/svg" width="3300" height="2200">',
        ' <g id="Notes">',
        '  <rect height="2200" id="artboard" style="fill:white;opacity:1" width="3300" x="0" y="0"/>',
        '  <text id="template-version" style="stroke:none;fill:black;font-family:sans-serif;font-size:13;'
        'text-anchor:end;" transform="matrix(1 0 0 1 3036 1933)">Template v.3.0</text>',
        '  <text id="descriptive-name" style="stroke:none;fill:black;font-family:sans-serif;font-size:13;'
        'text-anchor:end;" transform="matrix(1 0 0 1 3036 1969)">%s</text>' % name,
        " </g>",
        ' <g id="Guides">',
        *scale_guides,
        *guides,
        " </g>",
        ' <g id="Symbols">',
        *groups,
        " </g>",
        "</svg>",
        "",
    ])


def preview(draw):
    """A plain SVG file with the three weights side by side, to look at the shapes."""
    paths = []
    for index, line in enumerate(WEIGHTS.values()):
        def place(point, index=index):
            return (point[0] + index * 28 + 2, point[1] + 2)

        paths.append('<path d="%s"/>' % path_data(draw(line), place))
    return ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 88 28" width="880" height="280">'
            '<rect width="88" height="28" fill="white"/>%s</svg>\n' % "".join(paths))


def main():
    for name, draw in SYMBOLS.items():
        folder = CATALOG / (name + ".symbolset")
        folder.mkdir(parents=True, exist_ok=True)
        (folder / (name + ".svg")).write_text(template(name, draw), encoding="utf-8")
        contents = {
            "info": {"author": "xcode", "version": 1},
            "symbols": [{"filename": name + ".svg", "idiom": "universal"}],
        }
        (folder / "Contents.json").write_text(json.dumps(contents, indent=2) + "\n", encoding="utf-8")
    (CATALOG / "Contents.json").write_text(
        json.dumps({"info": {"author": "xcode", "version": 1}}, indent=2) + "\n", encoding="utf-8")
    if "--preview" in sys.argv:
        target = Path(sys.argv[sys.argv.index("--preview") + 1])
        target.mkdir(parents=True, exist_ok=True)
        for name, draw in SYMBOLS.items():
            (target / (name + ".svg")).write_text(preview(draw), encoding="utf-8")


if __name__ == "__main__":
    main()
