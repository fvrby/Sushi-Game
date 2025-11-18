--[[
    enemy.lua - Enemy Entity
    
    Cubo rojo que persigue al jugador.
    - Spawn desde los bordes de la pantalla
    - Movimiento hacia el jugador (seek behavior)
    - Sistema de vida (2 hits para morir)
    - Usa pooling
]]

local Entity = require("src.entities.entity")
local Constants = require("src.core.constants")

local Enemy = setmetatable({}, {__index = Entity})
Enemy.__index = Enemy

--[[
    Constructor
    
    @return Enemy instance
]]
function Enemy:new()
    local enemy = Entity.new(self)
    
    -- Dimensiones
    enemy.width = Constants.ENEMY_WIDTH
    enemy.height = Constants.ENEMY_HEIGHT
    
    -- Movimiento
    enemy.speed = 0     -- Se randomiza al activar
    
    -- Vida
    enemy.health = Constants.ENEMY_HEALTH
    enemy.maxHealth = Constants.ENEMY_HEALTH
    
    -- Visual
    enemy.hitFlash = 0  -- Timer para flash al recibir daño
    
    return enemy
end

--[[
    Activar enemigo
    
    @param x, y - Posición inicial
]]
function Enemy:activate(x, y)
    Entity.activate(self, x, y)
    
    -- Randomizar velocidad
    self.speed = love.math.random(
        Constants.ENEMY_SPEED_MIN,
        Constants.ENEMY_SPEED_MAX
    )
    
    -- Reset vida
    self.health = self.maxHealth
    self.hitFlash = 0
end

--[[
    Update loop
    
    @param dt           - Delta time
    @param targetX, targetY - Posición del jugador
]]
function Enemy:update(dt, targetX, targetY)
    if not self.active then
        return
    end
    
    -- Mover hacia el jugador
    self:moveTowards(dt, targetX, targetY)
    
    -- Actualizar flash de daño
    if self.hitFlash > 0 then
        self.hitFlash = self.hitFlash - dt
    end
end

--[[
    Mover hacia un punto (seek behavior)
    
    @param dt       - Delta time
    @param tx, ty   - Target position
]]
function Enemy:moveTowards(dt, tx, ty)
    -- Calcular dirección
    local cx, cy = self:getCenter()
    local dx = tx - cx
    local dy = ty - cy
    
    -- Normalizar
    local dist = math.sqrt(dx * dx + dy * dy)
    if dist > 0 then
        dx = dx / dist
        dy = dy / dist
    end
    
    -- Aplicar movimiento
    self.x = self.x + dx * self.speed * dt
    self.y = self.y + dy * self.speed * dt
end

--[[
    Recibir daño
    
    @param amount - Cantidad de daño
    @return boolean - true si murió
]]
function Enemy:takeDamage(amount)
    self.health = self.health - amount
    self.hitFlash = 0.1     -- 100ms de flash
    
    return self.health <= 0
end

--[[
    Verificar si está muerto
    
    @return boolean
]]
function Enemy:isDead()
    return self.health <= 0
end

--[[
    Obtener centro (la posición es esquina superior izquierda)
    
    @return centerX, centerY
]]
function Enemy:getCenter()
    return self.x + self.width / 2, self.y + self.height / 2
end

--[[
    Dibujar el enemigo
]]
function Enemy:draw()
    if not self.active then
        return
    end
    
    -- Color base o flash
    local color
    if self.hitFlash > 0 then
        color = {1, 1, 1, 1}    -- Blanco al recibir daño
    else
        color = Constants.COLOR_ENEMY
    end
    
    -- Glow effect
    love.graphics.setColor(color[1], color[2], color[3], 0.3)
    love.graphics.rectangle(
        "fill",
        self.x - 4, self.y - 4,
        self.width + 8, self.height + 8,
        4, 4    -- Bordes redondeados
    )
    
    -- Cuerpo principal
    love.graphics.setColor(color)
    love.graphics.rectangle(
        "fill",
        self.x, self.y,
        self.width, self.height,
        2, 2
    )
    
    -- Highlight (esquina superior izquierda)
    love.graphics.setColor(1, 1, 1, 0.3)
    love.graphics.rectangle(
        "fill",
        self.x + 2, self.y + 2,
        self.width * 0.3, self.height * 0.3,
        1, 1
    )
    
    -- Indicador de vida (solo si no está a full)
    if self.health < self.maxHealth then
        self:drawHealthBar()
    end
    
    love.graphics.setColor(1, 1, 1, 1)
end

--[[
    Dibujar barra de vida
]]
function Enemy:drawHealthBar()
    local barWidth = self.width
    local barHeight = 3
    local barX = self.x
    local barY = self.y - barHeight - 2
    
    -- Fondo
    love.graphics.setColor(0.2, 0.2, 0.2, 0.8)
    love.graphics.rectangle("fill", barX, barY, barWidth, barHeight)
    
    -- Vida actual
    local healthPercent = self.health / self.maxHealth
    love.graphics.setColor(1 - healthPercent, healthPercent, 0, 1)
    love.graphics.rectangle("fill", barX, barY, barWidth * healthPercent, barHeight)
end

--[[
    Dibujar hitbox (debug)
]]
function Enemy:drawDebug()
    if not self.active then
        return
    end
    
    love.graphics.setColor(1, 0, 0, 0.5)
    love.graphics.rectangle("line", self.x, self.y, self.width, self.height)
    
    -- Centro
    local cx, cy = self:getCenter()
    love.graphics.circle("fill", cx, cy, 2)
    
    love.graphics.setColor(1, 1, 1, 1)
end

return Enemy
