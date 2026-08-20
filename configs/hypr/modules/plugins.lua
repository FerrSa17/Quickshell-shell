if hl.plugin.hyprglass then
    local hg = hl.plugin.hyprglass

    local function tint(c, alpha)
        return tonumber(c:match("%x%x%x%x%x%x"), 16) * 256
            + math.floor(alpha * 255 + 0.5)
    end

    hg.preset("clear", {
        glass_opacity = 0.8,
        blur_strength = 1.5,
        dark = { brightness = 0.7 },
        light = { brightness = 1.2 },
    })

    hg.preset("contrasted", {
        inherits = "high_contrast",
        contrast = 1.2,
        adaptive_dim = 1.5,
        dark = { tint_color = 0x02142aa9 },
    })

    hg.preset("glass", {
        blur_strength = 2.0,
        blur_iterations = 3,
        chromatic_aberration = 0.8,
        fresnel_strength = 0.8,
        edge_thickness = 0.08,
        tint_color = tint("#1a1b26", 0.12),
        lens_distortion = 0.9,
        brightness = 1.0,
        contrast = 1.7,
        saturation = 1,
        vibrancy = 0.8,
        vibrancy_darkness = 1,
        adaptive_boost = 0.5,
    })

    -- Apple liquid-glass for Quickshell bar + popups (layer namespace "quickshell")
    hg.preset("apple", {
        blur_strength = 2.2,
        blur_iterations = 3,
        refraction_strength = 0.55,
        chromatic_aberration = 0.3,
        fresnel_strength = 0.5,
        specular_strength = 0.75,
        edge_thickness = 0.05,
        lens_distortion = 0.3,
        dark = {
            brightness = 0.82,
            contrast = 0.90,
            saturation = 0.80,
            vibrancy = 0.15,
            adaptive_dim = 0.4,
        },
        light = {
            brightness = 1.12,
            contrast = 0.92,
            saturation = 0.85,
            vibrancy = 0.12,
            adaptive_boost = 0.4,
        },
    })

    hg.config({
        enabled = true,
        default_theme = "light",
        default_preset = "apple",
        edge_thickness = 0,
        fresnel_strength = 0,
        specular_strength = 0,
        refraction_strength = 0,
        chromatic_aberration = 0,
        layers = { enabled = true },
    })

    hg.layer("quickshell", { exclude = true })
    hg.layer("quickshell-frame", { exclude = true })
    hg.layer("quickshell-desktop", { exclude = true })
    hg.layer("quickshell-screenshot", { exclude = true })
    hg.layer("selection", { exclude = true })

    hl.window_rule({ match = { class = "mpv" }, tag = "+hyprglass_disabled" })
    hl.window_rule({ match = { fullscreen = true }, tag = "+hyprglass_disabled" })
end
