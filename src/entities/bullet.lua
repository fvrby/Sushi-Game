--[[
    bullet.lua - Bullet Entity
    
    Proyectil disparado por el jugador.
    - Movimiento lineal en dirección fija
    - Se desactiva al salir de pantalla o impactar
    - Usa pooling
]]

local Entity = require("src.entities.entity")
local Constants = require("src.core.constants")

local Bullet = setmetatable({}, {__index = Entity})
Bullet.__index = Bullet

--[[
    Constructor
    
    @return Bullet instance
]]
function Bullet:new()
    local bullet = Entity.new(self)
    
    -- Dimensiones (circular)
    bullet.radius = Constants.BULLET_RADIUS
    bullet.width = bullet.radius * 2
    bullet.height = bullet.radius * 2
    
    -- Movimiento
    bullet.speed = Constants.BULLET_SPEED
    bullet.dx = 0       -- Dirección normalizada X
    bullet.dy = 0       -- Dirección normalizada Y
    
    -- Daño
    bullet.damage = Constants.BULLET_DAMAGE
    
    return bullet
end

--[[
    Activar la bala
    
    @param x, y     - Posición inicial
    @param dx, dy   - Dirección normalizada
]]
function Bullet:activate(x, y, dx, dy)
    Entity.activate(self, x, y)
    
    self.dx = dx or 0
    self.dy = dy or 0
end

--[[
    Update loop
    
    @param dt - Delta time
    @return boolean - false si debe desactivarse
]]
function Bullet:update(dt)
    if not self.active then
        return true
    end
    
    -- Mover en dirección
    self.x = self.x + self.dx * self.speed * dt
    self.y = self.y + self.dy * self.speed * dt
    
    -- Verificar límites de pantalla
    if self:isOutOfBounds() then
        return false
    end
    
    return true
end

--[[
    Verificar si está fuera de pantalla
    
    @return boolean
]]
function Bullet:isOutOfBounds()
    return self.x < -self.radius or
           self.x > Constants.WINDOW_WIDTH + self.radius or
           self.y < -self.radius or
           self.y > Constants.WINDOW_HEIGHT + self.radius
end

--[[
    Obtener bounding box (para AABB desde centro)
    
    @return x, y, width, height
]]
function Bullet:getBounds()
    return self.x - self.radius,
           self.y - self.radius,
           self.width,
           self.height
end

--[[
    Verificar colisión circular con AABB
    
    @param other - Entidad con getBounds()
    @return boolean
]]
function Bullet:collidesWithAABB(other)
    local bx, by, bw, bh = other:getBounds()
    
    -- Encontrar punto más cercano del rectángulo al centro del círculo
    local closestX = math.max(bx, math.min(self.x, bx + bw))
    local closestY = math.max(by, math.min(self.y, by + bh))
    
    -- Calcular distancia al cuadrado
    local dx = self.x - closestX
    local dy = self.y - closestY
    local distanceSquared = dx * dx + dy * dy
    
    return distanceSquared < (self.radius * self.radius)
end

--[[
    Dibujar la bala
]]
function Bullet:draw()
    if not self.active then
        return
    end
    
    -- Glow effect (círculo más grande, semi-transparente)
    love.graphics.setColor(1, 1, 0.5, 0.3)
    love.graphics.circle("fill", self.x, self.y, self.radius * 2)
    
    -- Bala principal
    love.graphics.setColor(Constants.COLOR_BULLET)
    love.graphics.circle("fill", self.x, self.y, self.radius)
    
    -- Highlight
    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.circle("fill", self.x - 1, self.y - 1, self.radius * 0.4)
    
    love.graphics.setColor(1, 1, 1, 1)
end

--[[
    Dibujar hitbox (debug)
]]
function Bullet:drawDebug()
    if not self.active then
        return
    end
    
    love.graphics.setColor(1, 1, 0, 0.5)
    love.graphics.circle("line", self.x, self.y, self.radius)
    love.graphics.setColor(1, 1, 1, 1)
end

return Bullet
