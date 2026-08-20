-----------------------
---- LOOK AND FEEL ----
-----------------------

hl.config({
    general = {
        gaps_in  = 8,
        gaps_out = 20,

        border_size = 0,

        col = {
            active_border   = { colors = {"rgba(1d2021aa)" } },
            inactive_border = "rgba(1d2021aa)",
        },

        resize_on_border = false,

        allow_tearing = false,
    },

    decoration = {
        rounding       = 12,
        rounding_power = 5,

        active_opacity   = 1.0,
        inactive_opacity = 0.8,

        shadow = {
            enabled      = true,
            range        = 0,
            render_power = 1,
            color        = 0x00000000,
        },

        blur = {
            enabled  = false,
            size     = 8,
            passes   = 3,
            new_optimizations = true,
            xray     = false,
            ignore_opacity = true,
        },
    },

    animations = {
        enabled = true,
    },
})

hl.curve("fastSpring",            { type = "bezier", points = { {0.25, 0.1},    {0.25, 1}     } })  -- Быстрый с легким перелетом
hl.curve("smoothSpring",          { type = "bezier", points = { {0.42, 0.0},    {0.58, 1.0}   } })  -- Плавный с эффектом пружины
hl.curve("fastEaseOut",           { type = "bezier", points = { {0.25, 0.1},    {0.25, 1}     } })  -- Быстрый выход
hl.curve("fastEaseInOut",         { type = "bezier", points = { {0.65, 0.0},    {0.35, 1}     } })  -- Симметричный быстрый
hl.curve("smoothFast",            { type = "bezier", points = { {0.4, 0.0},     {0.2, 1}      } })  -- Очень плавный
hl.curve("ultraSmooth",           { type = "bezier", points = { {0.3, 0.0},     {0.1, 1}      } })  -- Максимально плавный
hl.curve("ultraFastSpring",       { type = "bezier", points = { {0.12, 0.85},   {0.28, 1.45}  } })  -- Очень быстрая пружина
hl.curve("bounceFast",            { type = "bezier", points = { {0.175, 0.885}, {0.32, 1.275} } })  -- С легким отскоком

-- Быстрые пружины
hl.curve("fastSpring",            { type = "spring", mass = 1, stiffness = 60, dampening = 15 })      -- Быстрая пружина
hl.curve("ultraFastSpring",       { type = "spring", mass = 0.8, stiffness = 80, dampening = 18 })    -- Очень быстрая
hl.curve("smoothSpring",          { type = "spring", mass = 1.2, stiffness = 45, dampening = 14 })    -- Плавная пружина
hl.curve("glassBounce",           { type = "spring", mass = 1.0, stiffness = 55, dampening = 12 })    -- Liquid Glass open

-- Глобальные анимации
hl.animation({ leaf = "global",        enabled = true,  speed = 2.5, bezier = "fastEaseOut" })
hl.animation({ leaf = "border",        enabled = true,  speed = 1.5, bezier = "smoothFast" })

-- Окна: Glass Bounce (мягкий popin с лёгким overshoot)
hl.animation({ leaf = "windows",       enabled = true,  speed = 3.2, spring = "glassBounce", style = "popin 68%" })
hl.animation({ leaf = "windowsIn",     enabled = true,  speed = 3.8, spring = "glassBounce", style = "popin 68%" })
hl.animation({ leaf = "windowsOut",    enabled = true,  speed = 2.4, bezier = "fastEaseOut", style = "popin 72%" })
-- Fade чуть опережает scale — стекло «наливается»
hl.animation({ leaf = "fadeIn",        enabled = true,  speed = 4.2, bezier = "smoothFast" })
hl.animation({ leaf = "fadeOut",       enabled = true,  speed = 2.0, bezier = "fastEaseOut" })
hl.animation({ leaf = "fade",          enabled = true,  speed = 2.2, bezier = "ultraSmooth" })

-- Слои: slide из краёв (как окна из рамки)
hl.animation({ leaf = "layers",        enabled = true,  speed = 3.0, bezier = "fastSpring" })
hl.animation({ leaf = "layersIn",      enabled = true,  speed = 3.5, bezier = "smoothSpring",   style = "slide" })
hl.animation({ leaf = "layersOut",     enabled = true,  speed = 1.2, bezier = "fastEaseOut",    style = "slide" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true,  speed = 0.8, bezier = "smoothFast" })
hl.animation({ leaf = "fadeLayersOut", enabled = true,  speed = 0.6, bezier = "fastEaseOut" })

-- Рабочие пространства: плавное перетекание
hl.animation({ leaf = "workspaces",    enabled = true,  speed = 4.5, bezier = "ultraSmooth", style = "slidefade" })
hl.animation({ leaf = "workspacesIn",  enabled = true,  speed = 4.5, bezier = "ultraSmooth", style = "slidefade" })
hl.animation({ leaf = "workspacesOut", enabled = true,  speed = 4.0, bezier = "smoothFast",  style = "slidefade" })

-- Зум (быстрый и плавный)
hl.animation({ leaf = "zoomFactor",    enabled = true,  speed = 4.0, bezier = "ultraFastSpring" })
