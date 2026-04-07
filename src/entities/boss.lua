--[[
    boss.lua - Multi-Phase Boss

    Fases (basadas en HP restante):
    ┌──────────────────────────────────────────────────────────────────────┐
    │ Fase 1 (100-81): Un disparo cada 2.5s directo al jugador            │
    │ Fase 2 ( 80-61): Dispara más rápido (cada 1.0s)                     │
    │ Fase 3 ( 60-41): Igual que fase 2 + teletransporte cada 5s;         │
    │                  tras teleportar: ráfaga en N/S/E/O durante 2.8s    │
    │ Fase 4 ( 40-21): Color arcoiris, más lento, dispara arcos de balas  │
    │ Fase 5 ( 20- 0): Teleporta al tope, quieto, dispara bombas          │
    │                  que estallan en perdigones al viajar cierta dist.  │
    └──────────────────────────────────────────────────────────────────────┘

    Secuencia de muerte:
    → HP llega a 0 → "dying_shake" (3s, tiembla, no dispara)
    → devuelve "death_explode" → partículas de explosión en main.lua
    → "dying_wait" (2s, invisible)
    → devuelve "death_complete" → main.lua cambia a pantalla de victoria

    Valores de retorno de update():
    nil                         – nada
    {mode="normal",  tx, ty}    – disparo normal al jugador
    {mode="burst",   angle}     – una bala de ráfaga en dirección `angle`
    {mode="arc",     tx, ty}    – arco de balas hacia el jugador
    {mode="bomb",    tx, ty}    – bomba explosiva hacia el jugador
    "death_explode"             – señal: crear partículas de explosión
    "death_complete"            – señal: mostrar pantalla de victoria
]]

local Constants = require("src.core.constants")

local Boss = {}
Boss.__index = Boss

-- Ángulos para la ráfaga: Norte, Sur, Este, Oeste
local BURST_ANGLES = { -math.pi/2, math.pi/2, 0, math.pi }

-- ─────────────────────────────────────────────
--  Constructor
-- ─────────────────────────────────────────────
function Boss:new()
    local boss = setmetatable({}, Boss)

    boss.active = false
    boss.x      = 0
    boss.y      = 0
    boss.radius = Constants.BOSS_RADIUS
    boss.width  = boss.radius * 2
    boss.height = boss.radius * 2

    -- Health
    boss.health    = Constants.BOSS_HEALTH
    boss.maxHealth = Constants.BOSS_HEALTH

    -- Estado: "moving" | "teleport_flash" | "burst" | "dying_shake" | "dying_wait"
    boss.state = "moving"

    -- Disparo
    boss.fireTimer = 0

    -- Teletransporte (fases 3 y 5)
    boss.teleportTimer = 0
    boss.flashTimer    = 0
    boss.flashAlpha    = 0

    -- Ráfaga (fase 3)
    boss.burstTimer     = 0
    boss.burstFireTimer = 0
    boss.burstAngleIdx  = 1

    -- Flags de fase
    boss.phase5Done = false   -- Ya se teletransportó al tope

    -- Visual
    boss.hitFlash   = 0
    boss.pulseTimer = 0

    -- Muerte
    boss.deathTimer = 0
    boss.shakeX     = 0
    boss.shakeY     = 0

    return boss
end

-- ─────────────────────────────────────────────
--  Spawn (siempre desde el tope, centro)
-- ─────────────────────────────────────────────
function Boss:spawn()
    self.x      = Constants.WINDOW_WIDTH / 2
    self.y      = -self.radius - 20
    self.active = true
    self.health = self.maxHealth
    self.state  = "moving"

    self.fireTimer     = Constants.BOSS_FIRE_RATE_P1
    self.teleportTimer = Constants.BOSS_TELEPORT_INTERVAL
    self.flashTimer    = 0
    self.flashAlpha    = 0

    self.burstTimer     = 0
    self.burstFireTimer = 0
    self.burstAngleIdx  = 1

    self.phase5Done = false
    self.hitFlash   = 0
    self.pulseTimer = 0
    self.deathTimer = 0
    self.shakeX     = 0
    self.shakeY     = 0
end

-- ─────────────────────────────────────────────
--  Fase actual basada en HP
-- ─────────────────────────────────────────────
function Boss:getPhase()
    if     self.health > Constants.BOSS_PHASE2_HP then return 1
    elseif self.health > Constants.BOSS_PHASE3_HP then return 2
    elseif self.health > Constants.BOSS_PHASE4_HP then return 3
    elseif self.health > Constants.BOSS_PHASE5_HP then return 4
    else   return 5
    end
end

-- ─────────────────────────────────────────────
--  Update principal
-- ─────────────────────────────────────────────
function Boss:update(dt, targetX, targetY)
    if not self.active then return nil end

    self.pulseTimer = self.pulseTimer + dt

    -- ── ESTADOS DE MUERTE ──────────────────────────────────────────
    if self.state == "dying_shake" then
        self.deathTimer = self.deathTimer - dt
        self.shakeX = (love.math.random() - 0.5) * 14
        self.shakeY = (love.math.random() - 0.5) * 14
        if self.deathTimer <= 0 then
            self.state      = "dying_wait"
            self.deathTimer = Constants.BOSS_DEATH_WAIT_DURATION
            self.shakeX     = 0
            self.shakeY     = 0
            return "death_explode"
        end
        return nil
    end

    if self.state == "dying_wait" then
        self.deathTimer = self.deathTimer - dt
        if self.deathTimer <= 0 then
            self.active = false
            return "death_complete"
        end
        return nil
    end

    -- ── HIT FLASH ─────────────────────────────────────────────────
    if self.hitFlash > 0 then
        self.hitFlash = self.hitFlash - dt
    end

    -- ── FLASH PRE-TELETRANSPORTE ───────────────────────────────────
    if self.state == "teleport_flash" then
        self.flashTimer = self.flashTimer - dt
        self.flashAlpha = math.max(0, self.flashTimer / Constants.BOSS_TELEPORT_FLASH_DURATION)
        if self.flashTimer <= 0 then
            self.flashAlpha = 0
            self:doTeleport()
        end
        return nil
    end

    -- ── ESTADO DE RÁFAGA (fase 3) ──────────────────────────────────
    if self.state == "burst" then
        return self:updateBurst(dt)
    end

    -- ── ESTADO MOVING ──────────────────────────────────────────────
    local phase = self:getPhase()

    -- Fase 5: teletransporte único al tope
    if phase == 5 and not self.phase5Done then
        self.phase5Done = true
        self.state      = "teleport_flash"
        self.flashTimer = Constants.BOSS_TELEPORT_FLASH_DURATION
        self.flashAlpha = 1
        self.fireTimer  = Constants.BOSS_FIRE_RATE_P5
        return nil
    end

    -- Movimiento (no en fase 5, ya que se queda quieto arriba)
    if phase < 5 then
        local spd = (phase == 4) and Constants.BOSS_SPEED_P4 or Constants.BOSS_SPEED
        local dx = targetX - self.x
        local dy = targetY - self.y
        local dist = math.sqrt(dx * dx + dy * dy)
        if dist > 0 then
            self.x = self.x + (dx / dist) * spd * dt
            self.y = self.y + (dy / dist) * spd * dt
        end
    end

    -- Timer de teletransporte (solo fase 3)
    if phase == 3 then
        self.teleportTimer = self.teleportTimer - dt
        if self.teleportTimer <= 0 then
            self.state      = "teleport_flash"
            self.flashTimer = Constants.BOSS_TELEPORT_FLASH_DURATION
            self.flashAlpha = 1
        end
    end

    -- Timer de disparo
    self.fireTimer = self.fireTimer - dt
    if self.fireTimer <= 0 then
        if phase <= 3 then
            local rate = (phase == 1) and Constants.BOSS_FIRE_RATE_P1 or Constants.BOSS_FIRE_RATE_P2
            self.fireTimer = rate
            return {mode="normal", tx=targetX, ty=targetY}
        elseif phase == 4 then
            self.fireTimer = Constants.BOSS_FIRE_RATE_P4
            return {mode="arc", tx=targetX, ty=targetY}
        elseif phase == 5 then
            self.fireTimer = Constants.BOSS_FIRE_RATE_P5
            return {mode="bomb", tx=targetX, ty=targetY}
        end
    end

    return nil
end

-- ─────────────────────────────────────────────
--  Update de ráfaga (estado interno fase 3)
-- ─────────────────────────────────────────────
function Boss:updateBurst(dt)
    self.burstTimer = self.burstTimer - dt
    if self.burstTimer <= 0 then
        -- Ráfaga terminada: volver a mover
        self.state         = "moving"
        self.teleportTimer = Constants.BOSS_TELEPORT_INTERVAL
        local phase = self:getPhase()
        self.fireTimer = (phase >= 2) and Constants.BOSS_FIRE_RATE_P2 or Constants.BOSS_FIRE_RATE_P1
        return nil
    end

    self.burstFireTimer = self.burstFireTimer - dt
    if self.burstFireTimer <= 0 then
        self.burstFireTimer = Constants.BOSS_BURST_FIRE_RATE
        local angle = BURST_ANGLES[self.burstAngleIdx]
        self.burstAngleIdx = (self.burstAngleIdx % 4) + 1
        return {mode="burst", angle=angle}
    end

    return nil
end

-- ─────────────────────────────────────────────
--  Lógica del teletransporte
-- ─────────────────────────────────────────────
function Boss:doTeleport()
    if self.phase5Done then
        -- Fase 5: posición fija en el tope centro
        self.x     = Constants.WINDOW_WIDTH / 2
        self.y     = self.radius + 35
        self.state = "moving"
    else
        -- Fase 3: posición aleatoria + ráfaga
        local margin = self.radius + 70
        self.x = love.math.random(margin, Constants.WINDOW_WIDTH - margin)
        self.y = love.math.random(margin + 50, Constants.WINDOW_HEIGHT - margin)
        self.state         = "burst"
        self.burstTimer     = Constants.BOSS_BURST_DURATION
        self.burstFireTimer = 0.4
        self.burstAngleIdx  = 1
    end
end

-- ─────────────────────────────────────────────
--  Recibir daño
-- ─────────────────────────────────────────────
function Boss:takeDamage(amount)
    if self.state == "dying_shake" or self.state == "dying_wait" then
        return false   -- Invulnerable durante la muerte
    end
    self.health   = self.health - amount
    self.hitFlash = 0.1
    if self.health <= 0 then
        self.health = 0
        return true   -- Señal: iniciar secuencia de muerte
    end
    return false
end

function Boss:startDying()
    self.state      = "dying_shake"
    self.deathTimer = Constants.BOSS_DEATH_SHAKE_DURATION
    self.hitFlash   = 0
end

-- ─────────────────────────────────────────────
--  Colisiones
-- ─────────────────────────────────────────────
function Boss:collidesWithPlayer(player)
    if self.state == "dying_shake" or self.state == "dying_wait" then
        return false
    end
    local px, py, pw, ph = player:getBounds()
    local cx = math.max(px, math.min(self.x, px + pw))
    local cy = math.max(py, math.min(self.y, py + ph))
    local dx = self.x - cx
    local dy = self.y - cy
    return (dx * dx + dy * dy) < (self.radius * self.radius)
end

function Boss:collidesWithBullet(bullet)
    if self.state == "dying_shake" or self.state == "dying_wait" then
        return false
    end
    local dx = bullet.x - self.x
    local dy = bullet.y - self.y
    local rSum = self.radius + bullet.radius
    return (dx * dx + dy * dy) < (rSum * rSum)
end

-- ─────────────────────────────────────────────
--  Datos de disparo (posición + dirección)
-- ─────────────────────────────────────────────
function Boss:getFireData(tx, ty)
    local dx = tx - self.x
    local dy = ty - self.y
    local dist = math.sqrt(dx * dx + dy * dy)
    if dist > 0 then
        dx = dx / dist
        dy = dy / dist
    else
        dx, dy = 1, 0
    end
    return self.x + dx * (self.radius + 5),
           self.y + dy * (self.radius + 5),
           dx, dy
end

-- ─────────────────────────────────────────────
--  Dibujar
-- ─────────────────────────────────────────────
function Boss:draw()
    if not self.active then return end
    if self.state == "dying_wait" then return end   -- Invisible tras la explosión

    local drawX = self.x + self.shakeX
    local drawY = self.y + self.shakeY
    local phase = self:getPhase()
    local pulse = 1 + 0.06 * math.sin(self.pulseTimer * 3)

    -- Determinar color
    local color
    if self.state == "dying_shake" then
        -- Parpadeo rápido rojo/blanco
        color = (math.sin(self.pulseTimer * 30) > 0) and {1, 0.15, 0.15, 1} or {1, 1, 1, 1}
    elseif self.hitFlash > 0 then
        color = {1, 1, 1, 1}
    elseif phase == 4 then
        -- Arcoiris
        local t = love.timer.getTime() * 2
        color = {
            0.5 + 0.5 * math.sin(t),
            0.5 + 0.5 * math.sin(t + 2.094),
            0.5 + 0.5 * math.sin(t + 4.189),
            1
        }
    else
        color = Constants.COLOR_BOSS
    end

    -- Flash de teletransporte
    if self.flashAlpha > 0 then
        love.graphics.setColor(1, 1, 1, self.flashAlpha * 0.9)
        love.graphics.circle("fill", drawX, drawY, (self.radius + 28) * pulse)
    end

    -- Glow exterior
    love.graphics.setColor(color[1], color[2], color[3], 0.14)
    love.graphics.circle("fill", drawX, drawY, self.radius * pulse + 22)

    love.graphics.setColor(color[1], color[2], color[3], 0.28)
    love.graphics.circle("fill", drawX, drawY, self.radius * pulse + 10)

    -- Cuerpo principal
    love.graphics.setColor(color)
    love.graphics.circle("fill", drawX, drawY, self.radius * pulse)

    -- Highlight
    love.graphics.setColor(1, 1, 1, 0.22)
    love.graphics.circle("fill",
        drawX - self.radius * 0.28,
        drawY - self.radius * 0.28,
        self.radius * 0.38)

    love.graphics.setColor(1, 1, 1, 1)
end

return Boss
