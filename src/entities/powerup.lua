--[[
    powerup.lua - Power-Up Entity

    Objeto recogible que cae al matar enemigos.
    Por ahora solo existe el tipo "spread" (disparo en arco).

    - Flota en el suelo con efecto bobbing
    - Desaparece tras POWERUP_LIFETIME segundos (parpadea al final)
    - El jugador lo recoge al pasar encima
    - Usa pooling
]]

local Entity = require("src.entities.entity")
local Constants = require("src.core.constants")

local PowerUp = setmetatable({}, {__index = Entity})
PowerUp.__index = PowerUp

--[[
    Constructor
]]
function PowerUp:new()
    local pu = Entity.new(self)

    pu.radius   = Constants.POWERUP_RADIUS
    pu.width    = pu.radius * 2
    pu.height   = pu.radius * 2
    pu.lifetime = 0
    pu.bobTimer = 0
    pu.rotation = 0
    pu.puType   = "spread"

    return pu
end

--[[
    Activar el power-up

    @param cx, cy   - Centro donde aparece (posición del enemigo muerto)
    @param puType   - Tipo de power-up (default "spread")
]]
function PowerUp:activate(cx, cy, puType)
    -- Guardar posición como esquina superior izquierda (compatible con Entity)
    Entity.activate(self, cx - self.radius, cy - self.radius)

    self.lifetime = Constants.POWERUP_LIFETIME
    self.bobTimer = 0
    self.rotation = 0
    self.puType   = puType or "spread"
end

--[[
    Update loop

    @param dt - Delta time
    @return boolean - false si debe desactivarse
]]
function PowerUp:update(dt)
    if not self.active then return true end

    self.lifetime = self.lifetime - dt
    self.bobTimer = self.bobTimer + dt
    self.rotation = self.rotation + dt * 2.5

    if self.lifetime <= 0 then
        return false
    end
    return true
end

--[[
    Obtener centro
]]
function PowerUp:getCenter()
    return self.x + self.radius, self.y + self.radius
end

--[[
    Verificar si el jugador está en rango de recolección

    @param px, py - Posición del jugador (centro)
    @return boolean
]]
function PowerUp:isCollectedBy(px, py)
    local cx, cy = self:getCenter()
    local dx = px - cx
    local dy = py - cy
    return (dx * dx + dy * dy) < (Constants.POWERUP_COLLECT_RADIUS * Constants.POWERUP_COLLECT_RADIUS)
end

--[[
    Dibujar el power-up
]]
function PowerUp:draw()
    if not self.active then return end

    local cx, cy = self:getCenter()
    -- Efecto bobbing vertical
    local bob = math.sin(self.bobTimer * 4) * 3
    cy = cy + bob

    -- Parpadeo cuando queda poco tiempo
    local alpha = 1
    if self.lifetime < 2.5 then
        alpha = 0.4 + 0.6 * math.abs(math.sin(self.lifetime * math.pi * 2.5))
    end

    local c = Constants.COLOR_POWERUP_SPREAD

    -- Glow exterior
    love.graphics.setColor(c[1], c[2], c[3], 0.18 * alpha)
    love.graphics.circle("fill", cx, cy, self.radius * 2.2)

    -- Círculo base
    love.graphics.setColor(c[1], c[2], c[3], alpha)
    love.graphics.circle("fill", cx, cy, self.radius)

    -- Icono: 5 rayos (spread shot) girando
    love.graphics.push()
    love.graphics.translate(cx, cy)
    love.graphics.rotate(self.rotation)
    love.graphics.setColor(1, 1, 1, 0.9 * alpha)
    love.graphics.setLineWidth(1.5)
    local numRays = 5
    for i = 1, numRays do
        local angle = (i - 1) / numRays * math.pi * 2
        love.graphics.line(0, 0,
            math.cos(angle) * self.radius * 0.75,
            math.sin(angle) * self.radius * 0.75
        )
    end
    love.graphics.setLineWidth(1)
    love.graphics.pop()

    -- Brillo central
    love.graphics.setColor(1, 1, 1, 0.7 * alpha)
    love.graphics.circle("fill", cx, cy, self.radius * 0.25)

    love.graphics.setColor(1, 1, 1, 1)
end

return PowerUp