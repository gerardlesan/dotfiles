#!/bin/sh
# summon-workspace.sh NAME ORDER...
#
# Mod+1..4: show named workspace NAME on the monitor you're on. If it lives on
# another monitor it's moved here first (niri's own focus-workspace would send
# you to the other screen instead), then slotted back into its declared place:
# after whichever of the named workspaces before it in ORDER are on this
# monitor. ORDER is every named workspace in config.kdl declaration order.
#
# Only niri IPC calls, no daemon: if it breaks, put the commented-out
# focus-workspace binds in config.kdl back and delete this file.
set -eu
want=$1
shift

out=$(niri msg -j focused-output | jq -r .name)
ws=$(niri msg -j workspaces)
cur=$(printf '%s' "$ws" | jq -r --arg w "$want" '.[] | select(.name == $w) | .output')

if [ "$cur" != "$out" ]; then
    niri msg action move-workspace-to-monitor --reference "$want" "$out"
    # 1 + named workspaces declared before NAME that are already on this monitor
    # (from the snapshot taken before the move, which didn't touch them).
    idx=$(printf '%s' "$ws" | jq --arg w "$want" --arg o "$out" '
        . as $all
        | ($ARGS.positional | index($w)) as $i
        | [$ARGS.positional[:$i][] as $n | select(any($all[]; .name == $n and .output == $o))]
        | length + 1' --args "$@")
    niri msg action move-workspace-to-index --reference "$want" "$idx"
fi
niri msg action focus-workspace "$want"
