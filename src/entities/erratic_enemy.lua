--[[
    erratic_enemy.lua - Erratic Enemy Entity

    Variante del enemigo que se mueve de forma errática:
    - Cada 0.2-0.6s elige un nuevo ángulo aleatorio sesgado hacia el jugador
    - Más rápido que el enemigo normal pero con solo 1 HP
    - Visual: diamante morado giratorio
]]

local Entity = require("src.entities.entity")
local Enemy  = require("src.entities.enemy")
local Constants = require("src.core.constants")

local ErraticEnemy = setmetatable({}, {__index = Enemy})
ErraticEnemy.__index = ErraticEnemy

--[[
    Constructor
]]
function ErraticEnemy:new()
    local enemy = Entity.new(self)

    -- Dimensiones
    enemy.width  = Constants.ERRATIC_ENEMY_WIDTH
    enemy.height = Constants.ERRATIC_ENEMY_HEIGHT

    -- Movimiento
    enemy.speed        = 0
    enemy.currentAngle = 0      -- Ángulo de movimiento actual
    enemy.wanderTimer  = 0      -- Tiempo hasta el próximo cambio de dirección

    -- Vida
    enemy.health    = Constants.ERRATIC_ENEMY_HEALTH
    enemy.maxHealth = Constants.ERRATIC_ENEMY_HEALTH

    -- Visual
    enemy.hitFlash  = 0
    enemy.rotation  = 0         -- Rotación visual del diamante

    return enemy
end

--[[
    Activar

    @param x, y - Posición inicial
]]
function ErraticEnemy:activate(x, y)
    Entity.activate(self, x, y)

    self.speed        = love.math.random(Constants.ERRATIC_SPEED_MIN, Constants.ERRATIC_SPEED_MAX)
    self.health       = self.maxHealth
    self.hitFlash     = 0
    self.hasPowerUp   = false
    self.rotation     = love.math.random() * math.pi * 2
    self.currentAngle = love.math.random() * math.pi * 2
    -- Timer aleatorio para que no todos cambien al mismo tiempo
    self.wanderTimer  = love.math.random() * Constants.ERRATIC_WANDER_INTERVAL_MAX
end

--[[
    Update loop

    @param dt           - Delta time
    @param targetX, targetY - Posición del jugador
]]
function ErraticEnemy:update(dt, targetX, targetY)
    if not self.active then return end

    -- Rotación visual constante
    self.rotation = self.rotation + dt * 3

    -- Actualizar dirección errática
    self.wanderTimer = self.wanderTimer - dt
    if self.wanderTimer <= 0 then
        local cx, cy = self:getCenter()

        -- Ángulo base hacia el jugador
        local baseAngle = math.atan2(targetY - cy, targetX - cx)

        -- Desviación aleatoria grande
        local deviation = (love.math.random() - 0.5) * 2 * Constants.ERRATIC_WANDER_STRENGTH
        self.currentAngle = baseAngle + deviation

        -- Próximo cambio
        self.wanderTimer = Constants.ERRATIC_WANDER_INTERVAL_MIN +
            love.math.random() * (Constants.ERRATIC_WANDER_INTERVAL_MAX - Constants.ERRATIC_WANDER_INTERVAL_MIN)
    end

    -- Mover en el ángulo actual
    self.x = self.x + math.cos(self.currentAngle) * self.speed * dt
    self.y = self.y + math.sin(self.currentAngle) * self.speed * dt

    -- Actualizar flash de daño
    if self.hitFlash > 0 then
        self.hitFlash = self.hitFlash - dt
    end
end

--[[
    Dibujar el enemigo errático (diamante morado giratorio)
]]
function ErraticEnemy:draw()
    if not self.active then return end

    local cx, cy = self:getCenter()
    local half = self.width / 2

    -- Color base o flash
    local color
    if self.hitFlash > 0 then
        color = {1, 1, 1, 1}
    else
        color = Constants.COLOR_ERRATIC_ENEMY
    end

    -- Brillo arcoiris si es portador de power-up (heredado de Enemy)
    self:drawRainbowGlow()

    love.graphics.push()
    love.graphics.translate(cx, cy)
    love.graphics.rotate(self.rotation)

    -- Glow morado normal
    love.graphics.setColor(color[1], color[2], color[3], 0.25)
    love.graphics.polygon("fill",
        0, -(half + 5),
        (half + 5), 0,
        0, (half + 5),
        -(half + 5), 0
    )

    -- Cuerpo diamante
    love.graphics.setColor(color)
    love.graphics.polygon("fill",
        0, -half,
        half, 0,
        0, half,
        -half, 0
    )

    -- Highlight
    love.graphics.setColor(1, 1, 1, 0.35)
    love.graphics.polygon("fill",
        0, -half,
        half * 0.5, -half * 0.3,
        0, 0,
        -half * 0.5, -half * 0.3
    )

    love.graphics.pop()

    -- Barra de vida (siempre oculta para este enemigo porque muere de un hit,
    -- pero la dejamos por si se cambia ERRATIC_ENEMY_HEALTH en el futuro)
    if self.health < self.maxHealth then
        self:drawHealthBar()
    end

    love.graphics.setColor(1, 1, 1, 1)
end

--[[
    Dibujar hitbox (debug)
]]
function ErraticEnemy:drawDebug()
    if not self.active then return end

    local cx, cy = self:getCenter()
    local half = self.width / 2

    love.graphics.setColor(0.7, 0.2, 1, 0.5)
    love.graphics.rectangle("line", self.x, self.y, self.width, self.height)
    love.graphics.circle("fill", cx, cy, 2)

    -- Flecha de dirección actual
    love.graphics.setColor(1, 0.5, 1, 0.8)
    love.graphics.line(cx, cy,
        cx + math.cos(self.currentAngle) * 25,
        cy + math.sin(self.currentAngle) * 25
    )

    love.graphics.setColor(1, 1, 1, 1)
end

return ErraticEnemy