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
--[[
    Inicializar sistema de audio

    @param savedConfig - tabla opcional con musicVolume, sfxShootVolume,
                         sfxExplosionVolume (proveniente de Config.data)
]]
function Audio:init(savedConfig)
    -- Aplicar volúmenes guardados si los hay
    if savedConfig then
        if savedConfig.musicVolume    then self.musicVolume    = savedConfig.musicVolume    end
        if savedConfig.sfxShootVolume then self.sfxShootVolume = savedConfig.sfxShootVolume end
        if savedConfig.sfxExplosionVolume then
            self.sfxExplosionVolume = savedConfig.sfxExplosionVolume
        end
    end

    -- Cargar música
    self:loadMusic("main",     "assets/audio/music/Train-to-limache.mp3")
    self:loadMusic("boss",     "assets/audio/music/SMB2-BOSS-THEME.mp3")
    self:loadMusic("winsound", "assets/audio/music/SMW-WinSound.mp3", false)  -- sin loop

    -- Cargar SFX
    self:loadSFX("shoot",     "assets/audio/sfx/bullet.wav")
    self:loadSFX("explosion", "assets/audio/sfx/explosion.wav")
    self:loadSFX("menu",      "assets/audio/sfx/Menu.wav")
end

--[[
    Cargar archivo de música
    
    @param name - Identificador
    @param path - Ruta al archivo
]]
--[[
    @param looping - boolean, default true
]]
function Audio:loadMusic(name, path, looping)
    local success, result = pcall(function()
        return love.audio.newSource(path, "stream")
    end)

    if success then
        if looping == nil then looping = true end
        result:setLooping(looping)
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
        music:seek(0)   -- Siempre reinicia desde el principio
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
    elseif name == "menu" then
        volume = 0.6
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
