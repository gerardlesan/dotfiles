#!/usr/bin/env python3
"""desktop-helper.py ORDER...

Two behaviours niri has no config option for, driven from its event stream:

  * The external monitor is the main one. At login, and whenever the set of
    connected monitors changes, the named workspaces (ORDER: every named
    workspace in config.kdl declaration order) move to the first non-laptop
    output, in that order, and focus goes there. Monitors change name when
    you swap them (DP-1, HDMI-A-1...), so "not eDP-*" is the rule, not a name.
    Between changes it leaves them alone, so Mod+1..4 summoning still works.

  * The first window on a workspace opens full width. A tiled window that
    opens onto a workspace with no other windows at all gets 100%; the rest
    keep the default 3/4. Every window counts, floating ones included:
    counting only tiled ones widened a window opened beside a fullscreen
    one. Floating windows never get it, and neither does Ghostty: its
    window rule sets its own fixed width.

Started once by spawn-sh-at-startup in config.kdl; a config reload doesn't
restart it. If it dies, both behaviours just stop: nothing else depends on it.
Run it by hand in a terminal to see why.
"""
import json
import subprocess
import sys

ORDER = sys.argv[1:]
SKIP_FULL_WIDTH = {"com.mitchellh.ghostty"}  # app-ids whose window rule sets a width


def act(*args):
    subprocess.run(["niri", "msg", "action", *args], check=False)


def make_external_main(workspaces):
    externals = sorted({w["output"] for w in workspaces if w["output"] and not w["output"].startswith("eDP")})
    if not externals:
        return
    main = externals[0]
    where = {w["name"]: w["output"] for w in workspaces if w["name"]}
    for i, name in enumerate(ORDER, start=1):
        if name not in where:
            continue
        if where[name] != main:
            act("move-workspace-to-monitor", "--reference", name, main)
        act("move-workspace-to-index", "--reference", name, str(i))
    act("focus-monitor", main)


def main():
    outputs = None  # set of connected outputs; None until the first event
    windows = {}  # id -> window, as last reported
    stream = subprocess.Popen(["niri", "msg", "-j", "event-stream"], stdout=subprocess.PIPE, text=True)
    for line in stream.stdout:
        event = json.loads(line)
        if "WorkspacesChanged" in event:
            workspaces = event["WorkspacesChanged"]["workspaces"]
            now = {w["output"] for w in workspaces}
            # Moving workspaces below fires this again with the same outputs,
            # so comparing sets is also what stops it from looping.
            if now != outputs:
                outputs = now
                make_external_main(workspaces)
        elif "WindowsChanged" in event:  # full snapshot, sent first: not "new"
            windows = {w["id"]: w for w in event["WindowsChanged"]["windows"]}
        elif "WindowOpenedOrChanged" in event:
            w = event["WindowOpenedOrChanged"]["window"]
            is_new = w["id"] not in windows
            windows[w["id"]] = w
            if is_new and not w["is_floating"] and w["workspace_id"] is not None \
                    and w["app_id"] not in SKIP_FULL_WIDTH:
                alone = not any(x["workspace_id"] == w["workspace_id"] and x["id"] != w["id"]
                                for x in windows.values())
                if alone:
                    act("set-window-width", "--id", str(w["id"]), "100%")
        elif "WindowClosed" in event:
            windows.pop(event["WindowClosed"]["id"], None)


if __name__ == "__main__":
    main()
