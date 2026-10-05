#!/usr/bin/env python3
"""fastfetch with an animated logo. Called from fish_greeting.

    fetch.py [SCENE]        adrian, wheel or petrova; default: a random one, never
                            the same twice in a row

Three ways to show the logo, picked per run:

  loop     The default (FETCH_ANIM unset). The logo
           is kitty Unicode-placeholder text: ordinary cells that scroll, sit in
           scrollback and clear exactly like text. A forked child re-sends the
           next frame's PNG under the same image id ~12x a second, and Ghostty
           swaps the pixels in place. Only one frame is ever decoded.
  native   FETCH_ANIM=native, for a terminal that plays kitty animations itself
           (kitty; Ghostty from 1.4, PR #13943). fastfetch sends every frame once
           and nothing keeps running — but the terminal holds every frame decoded:
           ~1.7 MB a frame here, ~250 MB per fetch for adrian. Kept, not default:
           the loop costs one frame and looks the same.
  text     SSH sessions, or a terminal that reports no pixel size: one still
           frame as truecolor characters.

This file must start fast: it never imports numpy. Rendering lives in art.py
and only runs when a cell size has no baked frames yet.
"""
import base64, fcntl, os, random, re, signal, struct, subprocess, sys, termios, time

SCENES = ("adrian", "wheel", "petrova")
ANIM = os.environ.get("FETCH_ANIM", "loop")      # loop | native
# Columns the info pane needs beside the logo (config.jsonc's widest row, plus
# the logo's padding). Narrower than logo + this, the pane would wrap and tear
# the placeholder rows apart, so the logo is dropped instead.
PANE_COLS = 58

HERE = os.path.dirname(os.path.realpath(__file__))
ART = os.path.join(HERE, "art.py")
CACHE = os.path.join(os.environ.get("XDG_CACHE_HOME", os.path.expanduser("~/.cache")), "fastfetch-art")
RUN = os.environ.get("XDG_RUNTIME_DIR") or CACHE

# kitty rowcolumn-diacritics.txt: the Nth entry encodes row/column N of a placeholder
DIA = [chr(int(h, 16)) for h in (
    "0305 030D 030E 0310 0312 033D 033E 033F 0346 034A 034B 034C 0350 0351 0352 0357 035B 0363 "
    "0364 0365 0366 0367 0368 0369 036A 036B 036C 036D 036E 036F 0483 0484 0485 0486 0487 0592 "
    "0593 0594 0595 0597 0598 0599 059C 059D 059E 059F 05A0 05A1 05A8 05A9").split()]


def fastfetch(*logo):
    # The CPU row shows usage first, then the model — but fastfetch's cpuusage
    # module has no name field, so the name comes in through the environment
    # (config.jsonc reads it as {$FETCH_CPU}).
    with open("/proc/cpuinfo") as f:
        name = next((l.split(":", 1)[1] for l in f if l.startswith("model name")), "")
    name = re.sub(r"^(AMD|Intel\(R\) Core\(TM\))\s+|\s+(with .*|\d+-Core Processor)$", "", name.strip())
    os.environ["FETCH_CPU"] = name.ljust(19)      # the row's width; config.jsonc cannot pad it
    os.execvp("fastfetch", ["fastfetch", "-c", os.path.join(HERE, "config.jsonc"), *logo])


def pick_scene():
    """Random, but never the scene that greeted you last time."""
    last = os.path.join(CACHE, "last")
    try:
        prev = open(last).read().strip()
    except OSError:
        prev = ""
    scene = random.choice([s for s in SCENES if s != prev])
    os.makedirs(CACHE, exist_ok=True)
    with open(last, "w") as f:
        f.write(scene)
    return scene


def cell_size():
    """(cols, cw, ch): terminal width, and the cell size in device pixels,
    measured from the tty. Ghostty fills ws_xpixel/ws_ypixel with the grid's
    pixel size, padding excluded."""
    try:
        rows, cols, xp, yp = struct.unpack("HHHH", fcntl.ioctl(1, termios.TIOCGWINSZ, b"\0" * 8))
    except OSError:
        return None
    return (cols, round(xp / cols), round(yp / rows)) if xp and yp and cols and rows else None


def baked(scene):
    """{(cw, ch): dir} of finished renders for a scene."""
    out, root = {}, os.path.join(CACHE, scene)
    for d in os.listdir(root) if os.path.isdir(root) else ():
        m = re.fullmatch(r"(\d+)x(\d+)", d)
        if m and os.path.exists(os.path.join(root, d, "meta")):
            out[int(m[1]), int(m[2])] = os.path.join(root, d)
    return out


def bake_later(scene, cw, ch):
    """Render this cell size in the background for next time. The .tmp dir
    art.py works in doubles as the lock; one older than 10 min is a crash."""
    tmp = os.path.join(CACHE, scene, f"{cw}x{ch}.tmp")
    try:
        if time.time() - os.path.getmtime(tmp) < 600:
            return
    except OSError:
        pass
    subprocess.Popen(["nice", "-n", "15", sys.executable, ART, "render", scene, str(cw), str(ch)],
                     stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                     start_new_session=True)


def text_logo(scene):
    path = os.path.join(CACHE, scene, "text")
    if not os.path.exists(path):
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path + ".part", "w") as f:
            subprocess.run([sys.executable, ART, "text", scene], stdout=f, check=True)
        os.replace(path + ".part", path)
    with open(path) as f:
        lines = f.read().splitlines()
    fastfetch("--file-raw", path, "--logo-width", str(len(re.sub(r"\x1b\[[0-9;]*m", "", lines[0]))),
              "--logo-height", str(len(lines)))


def apc(keys, data=b""):
    return b"\x1b_G" + keys.encode() + (b";" + data if data else b"") + b"\x1b\\"


def send(fd, img, path):
    # a=t only, never a=T: re-transmitting replaces the stored image and keeps
    # its placements; a=T would add a new placement every frame. q=2 so the
    # terminal never answers into the shell's input.
    os.write(fd, apc(f"a=t,f=100,t=f,i={img},q=2", base64.b64encode(path.encode())))


def loop(fd, img, frames, fps, shell_pgid, pidfile):
    """Forked child: advance the frame while the shell owns the terminal.

    Writes only when the shell's process group is in the foreground, i.e. at
    the prompt. Inside vim/less/a build, the frame holds; writing then could
    land inside another program's chunked image upload. Exits when the tty
    goes away, or when a newer fetch on the same tty takes the pidfile.

    The first frame goes out the moment fastfetch exits — the foreground check
    is what waits for it, so there is no head start to sit through (an earlier
    fixed 1 s sleep was most of the "takes a moment to start animating")."""
    os.setpgid(0, 0)
    signal.signal(signal.SIGTTOU, signal.SIG_IGN)
    signal.signal(signal.SIGHUP, signal.SIG_DFL)
    me = str(os.getpid())
    with open(pidfile, "w") as f:
        f.write(me)
    k, tick = 1, 1 / fps
    nxt = time.monotonic()
    while True:
        try:
            if os.tcgetpgrp(fd) == shell_pgid:
                send(fd, img, frames[k % len(frames)])
                k += 1
            with open(pidfile) as f:
                if f.read() != me:
                    os._exit(0)
        except OSError:
            os._exit(0)
        nxt += tick
        time.sleep(max(0, nxt - time.monotonic()))


def main():
    scene = sys.argv[1] if len(sys.argv) > 1 else pick_scene()
    size = None if os.environ.get("SSH_CONNECTION") or not os.isatty(1) else cell_size()
    if size and size[0] < 36 + PANE_COLS:
        return fastfetch("--logo-type", "none")
    cell = size[1:] if size else None
    have = baked(scene) if cell else {}
    if cell and cell not in have:
        bake_later(scene, *cell)
    if not have:
        return text_logo(scene)
    # nearest baked size; Ghostty scales the image to the cell grid either way,
    # so a near miss only costs sharpness until the exact size is baked
    d = have.get(cell) or have[min(have, key=lambda s: abs(s[0] - cell[0]) + abs(s[1] - cell[1]))]
    cols, rows, fps, n = (int(v) for v in open(os.path.join(d, "meta")).read().split())

    if ANIM == "native":
        anim = os.path.join(d, "anim.png")
        if not os.path.exists(anim):
            subprocess.run([sys.executable, ART, "apng", scene, *re.findall(r"\d+", os.path.basename(d))], check=True)
        return fastfetch("--kitty", anim, "--logo-animation-frame", "0",
                         "--logo-width", str(cols), "--logo-height", str(rows))

    frames = [os.path.join(d, f"{i:03d}.png") for i in range(n)]
    fd = os.open(os.ttyname(1), os.O_WRONLY | os.O_NOCTTY)
    img = int.from_bytes(os.urandom(3), "big") | 0x100000      # 24-bit, clear of small ids apps use
    send(fd, img, frames[0])
    os.write(fd, apc(f"a=p,U=1,i={img},c={cols},r={rows},q=2"))
    r, g, b = img >> 16, (img >> 8) & 255, img & 255
    tty = os.ttyname(1).replace("/", "_")
    # one per tty, overwritten each run and never deleted: deleting it from the
    # loop raced fastfetch reading it whenever both share a process group
    logo = os.path.join(RUN, f"fetch-logo{tty}")
    with open(logo, "w") as f:                                  # the id rides in the fg colour
        f.write("\n".join(f"\x1b[38;2;{r};{g};{b}m" + "".join("\U0010EEEE" + DIA[y] + DIA[x] for x in range(cols))
                          + "\x1b[39m" for y in range(rows)))
    pidfile = os.path.join(RUN, f"fetch{tty}.pid")
    shell_pgid = os.getpgid(os.getppid())
    if os.fork() == 0:
        os.close(0)
        loop(fd, img, frames, fps, shell_pgid, pidfile)
    # exec, not spawn: fastfetch's parent stays the shell, so "Shell:" stays right
    fastfetch("--file-raw", logo, "--logo-width", str(cols), "--logo-height", str(rows))


if __name__ == "__main__":
    main()
