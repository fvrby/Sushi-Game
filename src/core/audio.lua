--[[
    audio.lua - Audio Management System
    
    Maneja toda la reproducción de audio:
    - Música de fondo (loop)
    - Efectos de sonido (one-shot)
    - Volúmenes independientes por categoría
    - Clonación de SFX para sonidos simultáneos
    
    Uso:
        local Audio = require("src.core.audio")
        
        Audio:init()
        Audio:playMusic("main")
        Audio:playSFX("shoot")
        Audio:setMusicVolume(0.5)
]]

local Constants = require("src.core.constants")

local Audio = {}
Audio.__index = Audio

-- Storage
Audio.music = {}
Audio.sfx = {}
Audio.currentMusic = nil

-- Volúmenes (0-1)
Audio.musicVolume = Constants.MUSIC_VOLUME_DEFAULT
Audio.sfxShootVolume = Constants.SFX_SHOOT_VOLUME_DEFAULT
Audio.sfxExplosionVolume = Constants.SFX_EXPLOSION_VOLUME_DEFAULT

--[[
    Inicializar sistema de audio
    
    Carga todos los assets de audio.
    Usa pcall para evitar crashes si faltan archivos.
]]
function Audio:init()
    -- Cargar música
    self:loadMusic("main", "assets/audio/music/Sushi_Game_OST_Armageddon.mp3")
    
    -- Cargar SFX
    self:loadSFX("shoot", "assets/audio/sfx/pistol-shot.wav")
    self:loadSFX("explosion", "assets/audio/sfx/Synthetic-explosion.wav")
end

--[[
    Cargar archivo de música
    
    @param name - Identificador
    @param path - Ruta al archivo
]]
function Audio:loadMusic(name, path)
    local success, result = pcall(function()
        return love.audio.newSource(path, "stream")
    end)
    
    if success then
        result:setLooping(true)
        result:setVolume(self.musicVolume)
        self.music[name] = result
    else
        print("Warning: No se pudo cargar música: " .. path)
    end
end

--[[
    Cargar efecto de sonido
    
    @param name - Identificador
    @param path - Ruta al archivo
]]
function Audio:loadSFX(name, path)
    local success, result = pcall(function()
        return love.audio.newSource(path, "static")
    end)
    
    if success then
        self.sfx[name] = result
    else
        print("Warning: No se pudo cargar SFX: " .. path)
    end
end

--[[
    Reproducir música
    
    @param name - Identificador de la música
]]
function Audio:playMusic(name)
    -- Detener música actual
    if self.currentMusic then
        self.currentMusic:stop()
    end
    
    local music = self.music[name]
    if music then
        music:setVolume(self.musicVolume)
        music:play()
        self.currentMusic = music
    end
end

--[[
    Pausar/reanudar música
]]
function Audio:toggleMusic()
    if self.currentMusic then
        if self.currentMusic:isPlaying() then
            self.currentMusic:pause()
        else
            self.currentMusic:play()
        end
    end
end

--[[
    Detener música
]]
function Audio:stopMusic()
    if self.currentMusic then
        self.currentMusic:stop()
        self.currentMusic = nil
    end
end

--[[
    Verificar si la música está sonando
    
    @return boolean
]]
function Audio:isMusicPlaying()
    return self.currentMusic and self.currentMusic:isPlaying()
end

--[[
    Reproducir efecto de sonido
    
    @param name - Identificador del SFX
]]
function Audio:playSFX(name)
    local sfx = self.sfx[name]
    if not sfx then
        return
    end
    
    -- Determinar volumen según tipo
    local volume = 1
    if name == "shoot" then
        volume = self.sfxShootVolume
    elseif name == "explosion" then
        volume = self.sfxExplosionVolume
    end
    
    -- Clonar para permitir múltiples instancias simultáneas
    local clone = sfx:clone()
    clone:setVolume(volume)
    clone:play()
end

--[[
    Establecer volumen de música
    
    @param volume - 0 a 1
]]
function Audio:setMusicVolume(volume)
    self.musicVolume = math.max(0, math.min(1, volume))
    
    if self.currentMusic then
        self.currentMusic:setVolume(self.musicVolume)
    end
end

--[[
    Establecer volumen de disparo
    
    @param volume - 0 a 1
]]
function Audio:setShootVolume(volume)
    self.sfxShootVolume = math.max(0, math.min(1, volume))
end

--[[
    Establecer volumen de explosión
    
    @param volume - 0 a 1
]]
function Audio:setExplosionVolume(volume)
    self.sfxExplosionVolume = math.max(0, math.min(1, volume))
end

--[[
    Obtener volúmenes actuales
    
    @return musicVol, shootVol, explosionVol
]]
function Audio:getVolumes()
    return self.musicVolume, self.sfxShootVolume, self.sfxExplosionVolume
end

--[[
    Reproducir sonido de prueba (para settings)
    
    @param type - "shoot" o "explosion"
]]
function Audio:playTestSound(type)
    self:playSFX(type)
end

return Audio
