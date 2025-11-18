--[[
    player.lua - Player Entity
    
    El gatito protagonista. Maneja:
    - Movimiento en 4 direcciones (con diagonal normalizado)
    - Rotación hacia el mouse
    - Disparo automático
    - Límites de pantalla
    
    No hereda de Entity porque es singleton y no usa pooling.
]]

local Constants = require("src.core.constants")
local Input = require("src.core.input")

local Player = {}
Player.__index = Player

--[[
    Constructor
    
    @return Player instance
]]
function Player:new()
    local player = setmetatable({}, Player)
    
    -- Posición (centro del sprite)
    player.x = Constants.PLAYER_START_X
    player.y = Constants.PLAYER_START_Y
    
    -- Dimensiones
    player.width = Constants.PLAYER_WIDTH
    player.height = Constants.PLAYER_HEIGHT
    
    -- Movimiento
    player.speed = Constants.PLAYER_SPEED
    
    -- Rotación (ángulo hacia el mouse)
    player.angle = 0
    
    -- Disparo
    player.fireRate = Constants.PLAYER_FIRE_RATE
    player.fireCooldown = 0
    
    -- Estado
    player.alive = true
    
    -- Sprite (nil = usar dibujo geométrico)
    player.sprite = nil
    player:loadSprite()
    
    return player
end

--[[
    Intentar cargar sprite desde archivo
]]
function Player:loadSprite()
    local success, result = pcall(function()
        return love.graphics.newImage("assets/sprites/cat.png")
    end)
    
    if success then
        self.sprite = result
    end
end

--[[
    Resetear al estado inicial (para reiniciar partida)
]]
function Player:reset()
    self.x = Constants.PLAYER_START_X
    self.y = Constants.PLAYER_START_Y
    self.angle = 0
    self.fireCooldown = 0
    self.alive = true
end

--[[
    Update loop
    
    @param dt - Delta time
    @return shouldFire - true si debe disparar este frame
]]
function Player:update(dt)
    if not self.alive then
        return false
    end
    
    -- Movimiento
    self:updateMovement(dt)
    
    -- Rotación hacia mouse
    self:updateRotation()
    
    -- Cooldown de disparo
    local shouldFire = self:updateFiring(dt)
    
    return shouldFire
end

--[[
    Actualizar movimiento basado en input
    
    @param dt - Delta time
]]
function Player:updateMovement(dt)
    local dx, dy = Input:getMovementVector()
    
    -- Aplicar velocidad
    self.x = self.x + dx * self.speed * dt
    self.y = self.y + dy * self.speed * dt
    
    -- Limitar a bordes de pantalla
    self:clampToScreen()
end

--[[
    Mantener al jugador dentro de la pantalla
]]
function Player:clampToScreen()
    local halfW = self.width / 2
    local halfH = self.height / 2
    
    if self.x - halfW < 0 then
        self.x = halfW
    elseif self.x + halfW > Constants.WINDOW_WIDTH then
        self.x = Constants.WINDOW_WIDTH - halfW
    end
    
    if self.y - halfH < 0 then
        self.y = halfH
    elseif self.y + halfH > Constants.WINDOW_HEIGHT then
        self.y = Constants.WINDOW_HEIGHT - halfH
    end
end

--[[
    Actualizar rotación hacia el mouse
]]
function Player:updateRotation()
    self.angle = Input:getAngleToMouse(self.x, self.y)
end

--[[
    Manejar cooldown y determinar si debe disparar
    
    @param dt - Delta time
    @return boolean - true si debe disparar
]]
function Player:updateFiring(dt)
    self.fireCooldown = self.fireCooldown - dt
    
    -- Disparo automático mientras el cooldown esté listo
    if self.fireCooldown <= 0 then
        self.fireCooldown = self.fireRate
        return true
    end
    
    return false
end

--[[
    Obtener posición y dirección para crear bala
    
    @return x, y, dirX, dirY
]]
function Player:getFireData()
    local dirX = math.cos(self.angle)
    local dirY = math.sin(self.angle)
    
    -- Spawn bala ligeramente enfrente del jugador
    local spawnDistance = self.width / 2 + 5
    local spawnX = self.x + dirX * spawnDistance
    local spawnY = self.y + dirY * spawnDistance
    
    return spawnX, spawnY, dirX, dirY
end

--[[
    Obtener bounding box para colisión
    
    @return x, y, width, height (esquina superior izquierda)
]]
function Player:getBounds()
    return self.x - self.width / 2,
           self.y - self.height / 2,
           self.width,
           self.height
end

--[[
    Matar al jugador
]]
function Player:die()
    self.alive = false
end

--[[
    Dibujar al jugador
]]
function Player:draw()
    if not self.alive then
        return
    end
    
    if self.sprite then
        self:drawSprite()
    else
        self:drawGeometric()
    end
end

--[[
    Dibujar usando sprite cargado
]]
function Player:drawSprite()
    local ox = self.sprite:getWidth() / 2
    local oy = self.sprite:getHeight() / 2
    
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(
        self.sprite,
        self.x, self.y,
        self.angle,
        1, 1,
        ox, oy
    )
end

--[[
    Dibujar gatito con formas geométricas
    
    El gatito mira hacia la derecha (angle = 0) por defecto.
    Rotamos todo el dibujo según self.angle.
]]
function Player:drawGeometric()
    love.graphics.push()
    love.graphics.translate(self.x, self.y)
    love.graphics.rotate(self.angle)
    
    -- Colores
    local bodyColor = {0.9, 0.7, 0.5}      -- Naranja claro
    local innerEarColor = {1, 0.6, 0.6}    -- Rosa
    local eyeColor = {0.2, 0.2, 0.2}       -- Gris oscuro
    local noseColor = {1, 0.5, 0.5}        -- Rosa
    local whiskerColor = {0.3, 0.3, 0.3}   -- Gris
    
    -- Cuerpo (elipse horizontal - el gato mira a la derecha)
    love.graphics.setColor(bodyColor)
    love.graphics.ellipse("fill", -4, 0, 12, 10)
    
    -- Cola (sale por detrás)
    love.graphics.setLineWidth(3)
    love.graphics.setColor(bodyColor)
    local tailPoints = {-14, 0, -18, -4, -20, -8, -18, -10}
    love.graphics.line(tailPoints)
    
    -- Cabeza (círculo adelante del cuerpo)
    love.graphics.setColor(bodyColor)
    love.graphics.circle("fill", 10, 0, 8)
    
    -- Orejas
    love.graphics.setColor(bodyColor)
    love.graphics.polygon("fill", 6, -8, 10, -14, 14, -8)   -- Oreja izquierda
    love.graphics.polygon("fill", 6, 8, 10, 14, 14, 8)      -- Oreja derecha
    
    -- Interior de orejas
    love.graphics.setColor(innerEarColor)
    love.graphics.polygon("fill", 8, -8, 10, -12, 12, -8)
    love.graphics.polygon("fill", 8, 8, 10, 12, 12, 8)
    
    -- Ojos
    love.graphics.setColor(eyeColor)
    love.graphics.circle("fill", 12, -3, 2)
    love.graphics.circle("fill", 12, 3, 2)
    
    -- Brillo en ojos
    love.graphics.setColor(1, 1, 1)
    love.graphics.circle("fill", 13, -3.5, 0.7)
    love.graphics.circle("fill", 13, 2.5, 0.7)
    
    -- Nariz
    love.graphics.setColor(noseColor)
    love.graphics.polygon("fill", 16, 0, 14, -1.5, 14, 1.5)
    
    -- Bigotes
    love.graphics.setColor(whiskerColor)
    love.graphics.setLineWidth(1)
    -- Bigotes superiores
    love.graphics.line(14, -2, 20, -4)
    love.graphics.line(14, -2, 20, -2)
    -- Bigotes inferiores
    love.graphics.line(14, 2, 20, 2)
    love.graphics.line(14, 2, 20, 4)
    
    love.graphics.pop()
    
    -- Reset
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(1)
end

--[[
    Dibujar hitbox (para debug)
]]
function Player:drawDebug()
    if not self.alive then
        return
    end
    
    local x, y, w, h = self:getBounds()
    
    love.graphics.setColor(0, 1, 0, 0.5)
    love.graphics.rectangle("line", x, y, w, h)
    
    -- Centro
    love.graphics.setColor(0, 1, 0, 1)
    love.graphics.circle("fill", self.x, self.y, 2)
    
    -- Dirección
    local dirX = math.cos(self.angle)
    local dirY = math.sin(self.angle)
    love.graphics.line(
        self.x, self.y,
        self.x + dirX * 30, self.y + dirY * 30
    )
    
    love.graphics.setColor(1, 1, 1, 1)
end

return Player
