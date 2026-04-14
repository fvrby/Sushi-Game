--[[
    config.lua - Persistent Configuration

    Guarda y carga la configuración del juego entre sesiones
    usando love.filesystem (directorio de usuario de LÖVE).

    El archivo se guarda en:
        Windows: %APPDATA%\LOVE\sushi-survivors\config.lua
        macOS:   ~/Library/Application Support/LOVE/sushi-survivors/config.lua
        Linux:   ~/.local/share/love/sushi-survivors/config.lua

    Uso:
        local Config = require("src.core.config")
        Config:load()           -- al iniciar
        Config:save()           -- al cambiar valores
        Config.data.musicVolume -- acceder a valores
]]

local Constants = require("src.core.constants")

local Config = {}
Config.__index = Config

Config.FILE = "config.lua"

-- Valores por defecto (se usan si no existe el archivo)
Config.data = {
    musicVolume    = Constants.MUSIC_VOLUME_DEFAULT,
    sfxShootVolume = Constants.SFX_SHOOT_VOLUME_DEFAULT,
    sfxExplosionVolume = Constants.SFX_EXPLOSION_VOLUME_DEFAULT,
}

--[[
    Cargar configuración desde archivo.
    Si el archivo no existe o está corrupto, usa los valores por defecto.
]]
function Config:load()
    local contents, err = love.filesystem.read(self.FILE)
    if not contents then
        -- Archivo no existe todavía, usar defaults
        return
    end

    -- Ejecutar el contenido como código Lua que retorna una tabla
    local chunk, loadErr = load("return " .. contents)
    if not chunk then
        print("Config: no se pudo parsear el archivo, usando defaults. Error: " .. tostring(loadErr))
        return
    end

    local ok, result = pcall(chunk)
    if not ok or type(result) ~= "table" then
        print("Config: datos inválidos en el archivo, usando defaults.")
        return
    end

    -- Aplicar solo los valores reconocidos (evita contaminar con keys extraños)
    if type(result.musicVolume) == "number" then
        self.data.musicVolume = math.max(0, math.min(1, result.musicVolume))
    end
    if type(result.sfxShootVolume) == "number" then
        self.data.sfxShootVolume = math.max(0, math.min(1, result.sfxShootVolume))
    end
    if type(result.sfxExplosionVolume) == "number" then
        self.data.sfxExplosionVolume = math.max(0, math.min(1, result.sfxExplosionVolume))
    end
end

--[[
    Guardar configuración actual al disco.
]]
function Config:save()
    -- Serializar la tabla como Lua literal (simple, sin dependencias)
    local content = string.format(
        "{\n    musicVolume = %.4f,\n    sfxShootVolume = %.4f,\n    sfxExplosionVolume = %.4f,\n}",
        self.data.musicVolume,
        self.data.sfxShootVolume,
        self.data.sfxExplosionVolume
    )

    local ok, err = love.filesystem.write(self.FILE, content)
    if not ok then
        print("Config: no se pudo guardar la configuración. Error: " .. tostring(err))
    end
end

--[[
    Actualizar un valor y guardar inmediatamente.

    @param key   - "musicVolume", "sfxShootVolume" o "sfxExplosionVolume"
    @param value - número 0-1
]]
function Config:set(key, value)
    if self.data[key] ~= nil then
        self.data[key] = math.max(0, math.min(1, value))
        self:save()
    end
end

return Config
