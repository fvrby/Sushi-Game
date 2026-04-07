--[[
    boss_bullet.lua - Boss Bullet / Bomb / Pellet

    Sirve para los tres tipos de proyectil del jefe:

    Normal  – radio = BOSS_BULLET_RADIUS,  speed = BOSS_BULLET_SPEED
    Bomba   – radio = BOSS_BOMB_RADIUS,    speed = BOSS_BOMB_SPEED,
              isBomb = true, explodeAt = distancia de detonación
    Perdigón– radio = BOSS_PELLET_RADIUS,  speed = BOSS_PELLET_SPEED
              (se asignan después de activate() desde main.lua)

    update() devuelve:
      true      – vivo
      false     – fuera de pantalla, eliminar
      "explode" – bomba alcanzó su distancia de detonación
]]

local Entity = require("src.entities.entity")
local Constants = require("src.core.constants")

local BossBullet = setmetatable({}, {__index = Entity})
BossBullet.__index = BossBullet

function BossBullet:new()
    local b = Entity.new(self)

    b.radius       = Constants.BOSS_BULLET_RADIUS
    b.width        = b.radius * 2
    b.height       = b.radius * 2
    b.speed        = Constants.BOSS_BULLET_SPEED
    b.dx           = 0
    b.dy           = 0
    b.damage       = Constants.BOSS_BULLET_DAMAGE
    b.isBomb       = false
    b.distTraveled = 0
    b.explodeAt    = math.huge

    return b
end

--[[
    Activar. Siempre resetea todos los campos a los valores por defecto,
    para que los perdigones reutilizados del pool no hereden propiedades
    de una bomba anterior.
]]
function BossBullet:activate(x, y, dx, dy)
    Entity.activate(self, x, y)
    self.dx = dx or 0
    self.dy = dy or 0

    self.radius       = Constants.BOSS_BULLET_RADIUS
    self.width        = self.radius * 2
    self.height       = self.radius * 2
    self.speed        = Constants.BOSS_BULLET_SPEED
    self.isBomb       = false
    self.distTraveled = 0
    self.explodeAt    = math.huge
end

function BossBullet:update(dt)
    if not self.active then return true end

    self.x = self.x + self.dx * self.speed * dt
    self.y = self.y + self.dy * self.speed * dt

    if self.isBomb then
        self.distTraveled = self.distTraveled + self.speed * dt
        if self.distTraveled >= self.explodeAt then
            return "explode"
        end
    end

    if self:isOutOfBounds() then
        return false
    end
    return true
end

function BossBullet:isOutOfBounds()
    local m = self.radius * 2
    return self.x < -m or
           self.x > Constants.WINDOW_WIDTH  + m or
           self.y < -m or
           self.y > Constants.WINDOW_HEIGHT + m
end

-- La posición x,y es el CENTRO de la bala
function BossBullet:getBounds()
    return self.x - self.radius, self.y - self.radius,
           self.radius * 2,      self.radius * 2
end

function BossBullet:collidesWithPlayer(player)
    local px, py, pw, ph = player:getBounds()
    local cx = math.max(px, math.min(self.x, px + pw))
    local cy = math.max(py, math.min(self.y, py + ph))
    local dx = self.x - cx
    local dy = self.y - cy
    return (dx * dx + dy * dy) < (self.radius * self.radius)
end

function BossBullet:draw()
    if not self.active then return end

    local c = Constants.COLOR_BOSS_BULLET

    if self.isBomb then
        -- Bomba: más grande y con efecto de pulso
        local pulse = 1 + 0.1 * math.sin(love.timer.getTime() * 8)
        love.graphics.setColor(c[1], c[2], c[3], 0.2)
        love.graphics.circle("fill", self.x, self.y, self.radius * pulse * 2.2)
        love.graphics.setColor(c[1] * 0.6, c[2] * 0.8, 1, 1)
        love.graphics.circle("fill", self.x, self.y, self.radius * pulse)
    else
        -- Bala normal / perdigón
        love.graphics.setColor(c[1], c[2], c[3], 0.22)
        love.graphics.circle("fill", self.x, self.y, self.radius * 2.1)
        love.graphics.setColor(c)
        love.graphics.circle("fill", self.x, self.y, self.radius)
    end

    -- Highlight
    love.graphics.setColor(1, 1, 1, 0.55)
    love.graphics.circle("fill",
        self.x - self.radius * 0.3,
        self.y - self.radius * 0.3,
        self.radius * 0.32)

    love.graphics.setColor(1, 1, 1, 1)
end

function BossBullet:drawDebug()
    if not self.active then return end
    love.graphics.setColor(0.5, 0.8, 1, 0.5)
    love.graphics.circle("line", self.x, self.y, self.radius)
    love.graphics.setColor(1, 1, 1, 1)
end

return BossBullet
