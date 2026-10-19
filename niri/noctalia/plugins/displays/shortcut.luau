--!nonstrict
-- Control center tile that opens nwg-displays. Noctalia's own Monitor tab is
-- compiled in and can't take extra buttons, so this lives with the shortcuts.
-- nwg-displays writes ~/.config/niri/outputs.kdl; niri's config.kdl includes it.

shortcut.setLabel("Displays")
shortcut.setIcon("device-desktop")

-- Launched through niri, not directly: started via runAsync, nwg-displays died
-- a few seconds after opening, while it ran fine from a terminal. runAsync looks
-- meant for short commands (Noctalia's binary carries a timeout and kill for it).
-- `niri msg action spawn` returns at once and niri owns the app.
function onClick()
    noctalia.runAsync({ "niri", "msg", "action", "spawn", "--", "nwg-displays" }, function() end)
end
