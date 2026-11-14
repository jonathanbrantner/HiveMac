#!/usr/bin/env python3
"""Converts the Cannon branch of Natro Macro's go-to-field scripts (paths/gtf-*.ahk, GPL-3.0) into HiveMac route files.

Natro keeps the movement keys held across the whole flight (send "{a down}", HyperSleep, send "{space 2}", HyperSleep,
send "{a up}"), so this emits keydown / keyup / wait steps and never "hold" steps for movement: a hold releases its keys,
which made the character drift off course in the air. Space presses are short taps (two quick jumps open the glider).

Usage: convert_natro_cannon.py <dir with gtf-*.ahk> <output dir (config/paths/natro/to_field)>
"""
import json, re, sys, os

KEYS = {"FwdKey": "w", "BackKey": "s", "LeftKey": "a", "RightKey": "d", "RotLeft": "ROTL", "RotRight": "ROTR"}
SLUG = {"blueflower": "blue_flower", "mountaintop": "mountain_top", "pinetree": "pine_tree"}


def expr(text):
    """Evaluate an AHK string expression like  "{e up}{" LeftKey " down}"  into the plain text it produces."""
    out = ""
    for m in re.finditer(r'"([^"]*)"|(\w+)', text):
        if m.group(1) is not None:
            out += m.group(1)
        else:
            name = m.group(2)
            if name not in KEYS:
                raise ValueError("unknown name " + name)
            out += KEYS[name]
    return out


def tap_space(n):
    steps = []
    for i in range(n):
        steps.append({"type": "hold", "keys": ["space"], "seconds": 0.08})
        steps.append({"type": "wait", "seconds": 0.06})
    return steps


def send_steps(s):
    steps = []
    for tok in re.findall(r"\{([^}]*)\}", s):
        parts = tok.split()
        name = parts[0]
        arg = parts[1] if len(parts) > 1 else None
        if name in ("ROTL", "ROTR"):
            steps.append({"type": "rotate", "direction": "left" if name == "ROTL" else "right", "count": int(arg or 1)})
        elif arg in ("down", "up"):
            steps.append({"type": "keydown" if arg == "down" else "keyup", "keys": [name]})
        elif name == "space":
            steps += tap_space(int(arg or 1))
        else:
            n = int(arg or 1)
            steps += [{"type": "tap", "key": name, "count": n}]
    return steps


def convert(branch):
    steps = []
    for raw in branch:
        line = raw.split(";")[0].strip()
        if not line:
            continue
        if line == "nm_gotoramp()":
            steps.append({"type": "gotoramp"})
        elif line == "nm_gotocannon()":
            steps.append({"type": "gotocannon"})
        elif re.match(r'(?i)send\s+"', line):
            steps += send_steps(expr(line[line.index('"'):]))
        elif re.match(r"(?i)(hypersleep)\(\s*(\d+)\s*\)", line):
            steps.append({"type": "wait", "seconds": int(re.findall(r"\d+", line)[0]) / 1000})
        elif re.match(r"(?i)sleep\s+\d+", line):
            steps.append({"type": "wait", "seconds": int(re.findall(r"\d+", line)[0]) / 1000})
        elif line.startswith("nm_Walk("):
            args = [a.strip() for a in line[len("nm_Walk("):line.rindex(")")].split(",")]
            tiles = float(args[0])
            keys = [KEYS[a] for a in args[1:]]
            steps.append({"type": "walk", "keys": keys, "tiles": tiles})
        else:
            raise ValueError("cannot convert: " + line)
    return steps


def main(src, dst):
    for fn in sorted(os.listdir(src)):
        if not (fn.startswith("gtf-") and fn.endswith(".ahk")):
            continue
        text = open(os.path.join(src, fn), encoding="utf-8-sig").read().replace("\r", "")
        m = re.search(r'if \(MoveMethod = "Cannon"\) \{\n(.*?)\n\} else \{', text, re.S)
        if not m:
            print("no cannon branch:", fn)
            continue
        name = fn[4:-4]
        slug = SLUG.get(name, name)
        try:
            steps = convert(m.group(1).split("\n"))
        except ValueError as e:
            print("SKIPPED", fn, e)
            continue
        data = {"name": slug + "_cannon", "source": "NatroMacro paths/" + fn + " (cannon branch)", "walk_speed": 28.0,
                "notes": "Converted from Natro Macro (GPL-3.0) by scripts/convert_natro_cannon.py. Movement keys stay held through the flight like Natro.",
                "steps": steps}
        out = os.path.join(dst, slug + "_cannon.json")
        json.dump(data, open(out, "w"), indent=2)
        print("wrote", out, len(steps), "steps")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
