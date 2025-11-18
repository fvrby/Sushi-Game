--[[
    particle.lua - Particle Entity
    
    Partícula visual para efectos de juego.
    - Explosiones al matar enemigos
    - Impactos de bala
    - Movimiento con velocidad inicial + gravedad
    - Fade out durante su vida
    - Usa pooling
]]

local Entity = require("src.entities.entity")
local Constants = require("src.core.constants")

local Particle = setmetatable({}, {__index = Entity})
Particle.__index = Particle

--[[
    Constructor
    
    @return Particle instance
]]
function Particle:new()
    local particle = Entity.new(self)
    
    -- Tamaño
    particle.size = Constants.PARTICLE_SIZE
    
    -- Velocidad
    particle.vx = 0
    particle.vy = 0
    
    -- Vida
    particle.life = 0
    particle.maxLife = 0
    
    -- Color (RGBA)
    particle.color = {1, 1, 1, 1}
    
    return particle
end

--[[
    Activar partícula
    
    @param x, y         - Posición inicial
    @param vx, vy       - Velocidad inicial
    @param color        - Color {r, g, b, a}
    @param lifetime     - Duración en segundos
    @param size         - Tamaño (opcional)
]]
function Particle:activate(x, y, vx, vy, color, lifetime, size)
    Entity.activate(self, x, y)
    
    self.vx = vx or 0
    self.vy = vy or 0
    
    -- Copiar color (evitar referencia compartida)
    self.color = {
        color[1] or 1,
        color[2] or 1,
        color[3] or 1,
        color[4] or 1
    }
    
    self.life = lifetime or Constants.PARTICLE_LIFETIME_MIN
    self.maxLife = self.life
    
    self.size = size or Constants.PARTICLE_SIZE
end

--[[
    Update loop
    
    @param dt - Delta time
    @return boolean - false si debe desactivarse
]]
function Particle:update(dt)
    if not self.active then
        return true
    end
    
    -- Reducir vida
    self.life = self.life - dt
    if self.life <= 0 then
        return false
    end
    
    -- Aplicar gravedad
    self.vy = self.vy + Constants.PARTICLE_GRAVITY * dt
    
    -- Mover
    self.x = self.x + self.vx * dt
    self.y = self.y + self.vy * dt
    
    return true
end

--[[
    Dibujar la partícula
]]
function Particle:draw()
    if not self.active then
        return
    end
    
    -- Alpha basado en vida restante
    local alpha = self.life / self.maxLife
    
    -- Tamaño decrece con la vida
    local size = self.size * (0.3 + 0.7 * alpha)
    
    love.graphics.setColor(
        self.color[1],
        self.color[2],
        self.color[3],
        self.color[4] * alpha
    )
    
    love.graphics.rectangle(
        "fill",
        self.x - size / 2,
        self.y - size / 2,
        size,
        size
    )
    
    love.graphics.setColor(1, 1, 1, 1)
end

return Particle
