--[[
    conf.lua - LÖVE Configuration
    
    Este archivo se ejecuta ANTES que main.lua.
    Configura la ventana, módulos habilitados y settings de rendimiento.
    
    Documentación: https://love2d.org/wiki/Config_Files
]]

function love.conf(t)
    -- Identidad del juego (usado para save directory)
    t.identity = "sushi-survivors"
    t.version = "11.4"                  -- Versión de LÖVE requerida
    t.console = false                   -- Consola de debug en Windows (true para desarrollo)
    
    -- Configuración de ventana
    t.window.title = "Sushi Survivors"
    t.window.width = 1280
    t.window.height = 720
    t.window.resizable = false          -- Fijo para simplificar el rendering
    t.window.vsync = 1                  -- 1 = vsync on (previene tearing, caps a refresh rate)
    t.window.msaa = 0                   -- Anti-aliasing (0 = off, innecesario para pixel art)
    t.window.minwidth = 1280
    t.window.minheight = 720
    
    -- Módulos habilitados
    -- Deshabilitamos lo que no usamos para reducir overhead
    t.modules.audio = true              -- Necesario: música y SFX
    t.modules.data = true               -- Necesario: serialización
    t.modules.event = true              -- Necesario: game loop
    t.modules.font = true               -- Necesario: texto UI
    t.modules.graphics = true           -- Necesario: rendering
    t.modules.image = true              -- Necesario: cargar sprites
    t.modules.joystick = false          -- No usado: solo keyboard/mouse
    t.modules.keyboard = true           -- Necesario: input
    t.modules.math = true               -- Necesario: random, vectors
    t.modules.mouse = true              -- Necesario: apuntado
    t.modules.physics = false           -- No usado: colisiones custom
    t.modules.sound = true              -- Necesario: audio backend
    t.modules.system = true             -- Necesario: OS info
    t.modules.thread = false            -- No usado: single-threaded
    t.modules.timer = true              -- Necesario: delta time
    t.modules.touch = false             -- No usado: desktop only
    t.modules.video = false             -- No usado: no video playback
    t.modules.window = true             -- Necesario: ventana
end
