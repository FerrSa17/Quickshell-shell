----------------
----  MISC  ----
----------------

hl.config({
    binds = {
        -- Cursor/Electron (and similar) can inhibit compositor shortcuts while
        -- typing. Keep Super+workspace and other WM binds working anyway.
        disable_keybind_grabbing = true,
    },
    misc = {
        force_default_wallpaper = 0,    -- Set to 0 or 1 to disable the anime mascot wallpapers
        disable_hyprland_logo   = true, -- If true disables the random hyprland logo / anime girl background. :(
    },
})


