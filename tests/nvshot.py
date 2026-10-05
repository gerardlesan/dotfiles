#!/usr/bin/env python3
"""Screenshot test for the Neovim config: does it START CLEAN and RENDER CLEAN?

    python3 tests/nvshot.py [SCENARIO ...]      default: all of them

Runs the real config (`nvim --embed`, your ~/.config/nvim) as a UI client —
ext_linegrid, rgb — replays each scenario's keys and resizes, and paints the
composed grid to tests/shots/<scenario>_<step>.png with JetBrains Mono Nerd
Font. Nothing touches the desktop: no window, no screen capture.

It FAILS (exit 1) when, during a scenario,
  - Neovim printed an error or warning (`msg_show` of an error kind, or an
    `E123:` line in :messages), or
  - anything reached the notifier at WARN or above, or
  - one of the scenario's `checks` (Lua expressions) is false.

Then LOOK at the PNGs — colour and layout are judged by eye; the asserts only
catch what is mechanical. Scenarios:
  python   fastfetch/art.py: top, body, a resize narrow and wide, completion
  rust     tests/rust-sample: needs rust-analyzer (waits 15 s for it), hover,
           completion, the cursor on a diagnostic
  ui       explorer + two splits resized three ways, picker, `:` palette
  dashboard  the start screen, full size and narrow

Needs python-msgpack and python-pillow (both pacman packages).
"""
import os, re, subprocess, sys, time, threading
import msgpack
from PIL import Image, ImageDraw, ImageFont

FONT = "/usr/share/fonts/TTF/JetBrainsMonoNerdFont-%s.ttf"
PX = 17
fonts = {k: ImageFont.truetype(FONT % v, PX) for k, v in
         {(0, 0): "Regular", (1, 0): "Bold", (0, 1): "Italic", (1, 1): "BoldItalic"}.items()}
CW = round(fonts[0, 0].getlength("M"))
ASC, DESC = fonts[0, 0].getmetrics()
CH = int((ASC + DESC) * 1.12)
BASE = (CH - ASC - DESC) // 2 + ASC


class UI:
    def __init__(self, cwd, args, cols, rows):
        env = dict(os.environ, TERM="xterm-ghostty", TERM_PROGRAM="ghostty", COLORTERM="truecolor")
        env.pop("NVIM", None)
        self.p = subprocess.Popen(["nvim", "--embed", *args], cwd=cwd, env=env,
                                  stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
        self.msgid = 0
        self.pending = {}
        self.hl = {0: {}}
        self.defaults = (0xffffff, 0, 0xff0000)
        self.grid = None
        self.cursor = (0, 0)
        self.msgs = []
        self.lock = threading.Lock()
        threading.Thread(target=self.reader, daemon=True).start()
        self.request("nvim_ui_attach", cols, rows, {"rgb": True, "ext_linegrid": True})

    def resize_grid(self, cols, rows):
        self.cols, self.rows = cols, rows
        self.grid = [[[" ", 0] for _ in range(cols)] for _ in range(rows)]

    def reader(self):
        up = msgpack.Unpacker(raw=False, strict_map_key=False, unicode_errors="replace")
        while True:
            data = self.p.stdout.read1(65536)
            if not data:
                return
            up.feed(data)
            for m in up:
                if not isinstance(m, list):
                    continue
                if m[0] == 1:
                    ev = self.pending.pop(m[1], None)
                    if ev:
                        ev.append(m[2:]); ev[0].set()
                elif m[0] == 2 and m[1] == "redraw":
                    with self.lock:
                        for batch in m[2]:
                            for args in batch[1:]:
                                self.event(batch[0], args)
                elif m[0] == 0:          # request from nvim: answer nil
                    self.p.stdin.write(msgpack.packb([1, m[1], None, None])); self.p.stdin.flush()

    def event(self, name, a):
        if name == "grid_resize":
            self.resize_grid(a[1], a[2])
        elif name == "default_colors_set":
            self.defaults = tuple(a[:3])
        elif name == "hl_attr_define":
            self.hl[a[0]] = a[1]
        elif name == "grid_clear":
            self.resize_grid(self.cols, self.rows)
        elif name == "grid_cursor_goto":
            self.cursor = (a[1], a[2])
        elif name == "grid_line":
            _, row, col, cells = a[:4]
            hl = 0
            for cell in cells:
                text = cell[0]
                if len(cell) > 1:
                    hl = cell[1]
                rep = cell[2] if len(cell) > 2 else 1
                for _ in range(rep):
                    if 0 <= row < self.rows and col < self.cols:
                        self.grid[row][col] = [text, hl]
                    col += 1
        elif name == "grid_scroll":
            _, top, bot, left, right, rows, _ = a
            g = self.grid
            if rows > 0:
                for r in range(top, bot - rows):
                    g[r][left:right] = [c[:] for c in g[r + rows][left:right]]
            else:
                for r in range(bot - 1, top - rows - 1, -1):
                    g[r][left:right] = [c[:] for c in g[r + rows][left:right]]
        elif name == "msg_show":
            self.msgs.append(("msg_show", a[0], "".join(ch[1] for ch in a[1])))

    def request(self, method, *args, timeout=20):
        self.msgid += 1
        ev = [threading.Event()]
        self.pending[self.msgid] = ev
        self.p.stdin.write(msgpack.packb([0, self.msgid, method, list(args)]))
        self.p.stdin.flush()
        if not ev[0].wait(timeout):
            raise TimeoutError(method)
        err, res = ev[1]
        if err:
            raise RuntimeError(f"{method}: {err}")
        return res

    def shot(self, path):
        with self.lock:
            fg0, bg0, sp0 = self.defaults
            img = Image.new("RGB", (self.cols * CW, self.rows * CH))
            d = ImageDraw.Draw(img)
            rgb = lambda v: ((v >> 16) & 255, (v >> 8) & 255, v & 255)
            for r, line in enumerate(self.grid):
                for c, (text, hl) in enumerate(line):
                    at = self.hl.get(hl, {})
                    fg = at.get("foreground", fg0); bg = at.get("background", bg0)
                    if at.get("reverse"):
                        fg, bg = bg, fg
                    x, y = c * CW, r * CH
                    d.rectangle([x, y, x + CW - 1, y + CH - 1], fill=rgb(bg))
                    if text.strip():
                        f = fonts[int(bool(at.get("bold"))), int(bool(at.get("italic")))]
                        o = ord(text[0])
                        if 0x2500 <= o <= 0x259f:       # box drawing: stretch to the cell like a terminal
                            self.box(d, text, x, y, rgb(fg), f)
                        else:
                            d.text((x, y + BASE), text, font=f, fill=rgb(fg), anchor="ls")
                    sp = rgb(at.get("special", fg))
                    if at.get("underline"):
                        d.line([x, y + CH - 2, x + CW, y + CH - 2], fill=sp)
                    if at.get("undercurl"):
                        for i in range(0, CW, 2):
                            d.point((x + i, y + CH - 2 - (i // 2) % 2), fill=sp)
                    if at.get("strikethrough"):
                        d.line([x, y + CH // 2, x + CW, y + CH // 2], fill=rgb(fg))
            img.save(path)

    def box(self, d, ch, x, y, fg, f):
        # paint the glyph into a cell-sized tile scaled vertically so lines join
        tile = Image.new("L", (CW, ASC + DESC))
        ImageDraw.Draw(tile).text((0, ASC), ch, font=f, fill=255, anchor="ls")
        tile = tile.resize((CW, CH))
        d.bitmap((x, y), tile, fill=fg)



REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(REPO, "tests", "shots")
# Each Lua check runs in the editor after the steps and must return true.
CODE_CHECKS = [
    "vim.wo.colorcolumn == ''",                               # no bar in the middle
    # type hints: on in Rust (inference hides every type), off elsewhere
    "vim.lsp.inlay_hint.is_enabled({ bufnr = 0 }) == (vim.bo.filetype == 'rust')",
    "vim.diagnostic.config().virtual_text.current_line == true",
    "not vim.o.listchars:find('extends')",                    # no edge chevrons
]
SCENARIOS = {
    "python": dict(cwd="fastfetch", args=["art.py"], checks=CODE_CHECKS, steps=[
        ["wait", 6], ["keys", "gg"], ["shot", "top"],
        ["keys", "/def scene_wheel<CR>zt:noh<CR>"], ["wait", 4], ["shot", "body"],  # tokens arrive per range
        ["keys", "42G"], ["shot", "diagnostic"],
        ["keys", "50Go    np.ar"], ["wait", 2.5], ["shot", "complete"], ["keys", "<Esc>u"],
        ["resize", 96, 30], ["shot", "narrow"], ["resize", 200, 52], ["shot", "wide"]]),
    "rust": dict(cwd="tests/rust-sample", args=["src/main.rs"], checks=CODE_CHECKS, steps=[
        ["wait", 15], ["keys", "gg"], ["shot", "top"], ["keys", "50Gzz"], ["shot", "middle"],
        ["keys", "74G0fsK"], ["wait", 2.5], ["shot", "hover"], ["keys", "<Esc>"],
        ["keys", "75GO    items.in"], ["wait", 2.5], ["shot", "complete"], ["keys", "<Esc>u"],
        ["keys", "92G"], ["shot", "diagnostic"], ["resize", 96, 30], ["shot", "narrow"]]),
    "ui": dict(cwd=".", args=["nvim/lua/config/palette.lua"], checks=[], steps=[
        ["wait", 4], ["keys", " e"], ["wait", 2], ["shot", "explorer"],
        ["keys", "<C-w>l"], ["keys", ":vsplit fastfetch/fetch.py<CR>"], ["wait", 2], ["shot", "split"],
        ["resize", 104, 32], ["shot", "split_narrow"], ["resize", 200, 52], ["shot", "split_wide"],
        ["resize", 150, 44], ["keys", " ff"], ["wait", 1.5], ["keys", "art"], ["shot", "picker"],
        ["keys", "<Esc><Esc>:set nu"], ["shot", "cmdline"], ["keys", "<Esc>"]]),
    "dashboard": dict(cwd=".", args=[], checks=[], steps=[
        ["wait", 4], ["shot", "full"], ["resize", 90, 30], ["shot", "narrow"]]),
}


def run(name, sc):
    ui = UI(os.path.join(REPO, sc["cwd"]), sc["args"], 150, 44)
    for step in sc["steps"]:
        k = step[0]
        if k == "wait":
            time.sleep(step[1])
        elif k == "keys":
            ui.request("nvim_input", step[1])
            time.sleep(0.6)
        elif k == "resize":
            ui.request("nvim_ui_try_resize", step[1], step[2])
            time.sleep(1.5)
        elif k == "shot":
            time.sleep(0.5)
            ui.shot(os.path.join(OUT, f"{name}_{step[1]}.png"))
    problems = [f"msg_show[{kind}]: {text}" for _, kind, text in ui.msgs
                if kind in ("emsg", "echoerr", "lua_error", "rpc_error", "wmsg")]
    msgs = ui.request("nvim_exec2", "messages", {"output": True})["output"]
    problems += [f":messages: {l}" for l in msgs.splitlines() if re.match(r"\s*E\d+:", l) or "Error" in l]
    problems += [f"notify: {n}" for n in ui.request("nvim_exec_lua", """
      local ok, h = pcall(function() return Snacks.notifier.get_history() end)
      local out = {}
      for _, n in ipairs(ok and h or {}) do
        if (n.level == "warn" or n.level == "error") then out[#out+1] = (n.title or "") .. " " .. n.msg end
      end
      return out""", [])]
    for chk in sc["checks"]:
        if not ui.request("nvim_exec_lua", f"return {chk}", []):
            problems.append(f"check failed: {chk}")
    ui.p.kill()
    return problems


def main():
    os.makedirs(OUT, exist_ok=True)
    names = sys.argv[1:] or list(SCENARIOS)
    failed = 0
    for name in names:
        problems = run(name, SCENARIOS[name])
        print(f"{'FAIL' if problems else 'ok  '}  {name}")
        for p in problems:
            print("      " + p)
        failed += bool(problems)
    print(f"screenshots: {OUT}")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
