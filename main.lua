--[[
    main.lua - Game Entry Point
    
    Sushi Survivors
    Un survivors-like donde un gatito sobrevive oleadas de cubos rojos.
    
    Arquitectura:
    - State Machine para flujo de juego
    - Object Pooling para entidades
    - Spatial Hashing para colisiones
    
    Controles:
    - WASD/Flechas: Mover
    - Mouse: Apuntar
    - Disparo automático
    - R: Reiniciar (en game over)
    - ESC: Menú/Salir
    - M: Toggle música
    - F6: Toggle shader CRT
]]

-- =============================================================================
-- REQUIRES
-- =============================================================================
local Constants = require("src.core.constants")
local GameState = require("src.core.game_state")
local Input = require("src.core.input")
local Pool = require("src.core.pool")

local Player = require("src.entities.player")
local Bullet = require("src.entities.bullet")
local Enemy = require("src.entities.enemy")
local ErraticEnemy = require("src.entities.erratic_enemy")
local Particle = require("src.entities.particle")
local PowerUp = require("src.entities.powerup")
local Boss = require("src.entities.boss")
local BossBullet = require("src.entities.boss_bullet")

local Spawner = require("src.systems.spawner")
local Collision = require("src.systems.collision")
local Audio = require("src.core.audio")
local Config = require("src.core.config")
local UI = require("src.ui.ui_components")
local CRTShader = require("src.rendering.crt_shader")

-- =============================================================================
-- GAME VARIABLES
-- =============================================================================
local player
local bulletPool
local enemyPool
local erraticEnemyPool
local particlePool
local powerupPool
local boss
local bossBulletPool
local spawner
local collision
local crtShader

local nextBossScore = 0   -- Umbral de puntos para el siguiente jefe

-- Explosión gradual del jefe tras su muerte
local bossDeathX         = 0
local bossDeathY         = 0
local bossExplosionTimer = 0   -- Tiempo restante de explosión
local bossExplosionTick  = 0   -- Timer entre ráfagas de partículas
local BOSS_EXPLOSION_INTERVAL = 0.18

-- Video de victoria
local victoryVideo = nil

local score = 0
local gameTime = 0

-- UI Elements
local menuButtons = {}
local settingsSliders = {}
local settingsButtons = {}

-- Debug
local debugFlags = {
    showFPS = false,
    showEntities = false,
    showHitboxes = false,
    showGrid = false,
    showSpawns = false,
}

-- Fuentes
local fonts = {}

-- =============================================================================
-- HELPER FUNCTIONS
-- =============================================================================

local function spawnParticles(x, y, count, color, speedMin, speedMax)
    for i = 1, count do
        local particle = particlePool:get()
        if particle then
            local angle = love.math.random() * math.pi * 2
            local speed = love.math.random(speedMin, speedMax)
            local vx = math.cos(angle) * speed
            local vy = math.sin(angle) * speed
            local lifetime = love.math.random() * 
                (Constants.PARTICLE_LIFETIME_MAX - Constants.PARTICLE_LIFETIME_MIN) + 
                Constants.PARTICLE_LIFETIME_MIN
            
            particle:activate(x, y, vx, vy, color, lifetime)
        end
    end
end

local function resetGame()
    -- Reset player
    player:reset()

    -- Liberar todas las entidades
    bulletPool:releaseAll()
    enemyPool:releaseAll()
    erraticEnemyPool:releaseAll()
    particlePool:releaseAll()
    powerupPool:releaseAll()
    bossBulletPool:releaseAll()

    -- Desactivar jefe
    boss.active = false

    -- Reset spawner
    spawner:reset()

    -- Reset score, tiempo y umbral del jefe
    score         = 0
    gameTime      = 0
    nextBossScore = Constants.BOSS_SCORE_INTERVAL

    -- Volver a la música principal
    Audio:playMusic("main")
end

-- =============================================================================
-- LÖVE CALLBACKS
-- =============================================================================

function love.load()
    -- Seed random
    love.math.setRandomSeed(os.time())
    
    -- Configuración de gráficos
    love.graphics.setBackgroundColor(Constants.COLOR_BACKGROUND)
    love.graphics.setDefaultFilter("nearest", "nearest")  -- Pixel art crisp

    -- Crear fuentes
    fonts.small = love.graphics.newFont(14)
    fonts.medium = love.graphics.newFont(20)
    fonts.large = love.graphics.newFont(32)
    fonts.title = love.graphics.newFont(48)
    
    -- Crear entidades
    player = Player:new()
    
    -- Crear pools
    bulletPool       = Pool:new(Bullet, Constants.BULLET_POOL_SIZE)
    enemyPool        = Pool:new(Enemy, Constants.ENEMY_POOL_SIZE)
    erraticEnemyPool = Pool:new(ErraticEnemy, Constants.ERRATIC_ENEMY_POOL_SIZE)
    particlePool     = Pool:new(Particle, Constants.PARTICLE_POOL_SIZE)
    powerupPool      = Pool:new(PowerUp, Constants.POWERUP_POOL_SIZE)
    bossBulletPool   = Pool:new(BossBullet, Constants.BOSS_BULLET_POOL_SIZE)

    -- Crear jefe (singleton, inactivo al inicio)
    boss = Boss:new()

    -- Crear sistemas
    spawner = Spawner:new(enemyPool, erraticEnemyPool)
    collision = Collision:new()
    
    -- Configurar callbacks de colisión
    collision.onEnemyHit = function(enemy, bullet)
        -- Partículas de impacto
        local cx, cy = enemy:getCenter()
        spawnParticles(
            cx, cy,
            Constants.PARTICLE_HIT_COUNT,
            Constants.COLOR_PARTICLE_HIT,
            Constants.PARTICLE_SPEED_MIN / 2,
            Constants.PARTICLE_SPEED_MAX / 2
        )
    end
    
    collision.onEnemyKilled = function(enemy)
        -- Partículas de muerte
        local cx, cy = enemy:getCenter()
        spawnParticles(
            cx, cy,
            Constants.PARTICLE_DEATH_COUNT,
            Constants.COLOR_PARTICLE_DEATH,
            Constants.PARTICLE_SPEED_MIN,
            Constants.PARTICLE_SPEED_MAX
        )

        -- Drop de power-up (solo si el enemigo era portador)
        if enemy.hasPowerUp then
            local pu = powerupPool:get()
            if pu then
                pu:activate(cx, cy, "spread")
            end
        end

        -- Score
        score = score + Constants.SCORE_PER_KILL

        -- Sonido
        Audio:playSFX("explosion")
    end
    
    collision.onPlayerHit = function(enemy)
        player:die()
        GameState:switch("gameover")
    end
    
    -- Registrar estados
    registerStates()
    
    -- Cargar configuración guardada
    Config:load()

    -- Inicializar audio (aplica volúmenes guardados)
    Audio:init(Config.data)
    Audio:playMusic("main")
    
    -- Crear UI de menú
    createMenuUI()
    createSettingsUI()
    
    -- Crear shader CRT
    crtShader = CRTShader:new()

    -- Cargar video de victoria (requiere formato .ogv)
    local ok, vid = pcall(function()
        return love.graphics.newVideo("assets/video/FFVII-ChocoboDance.ogv")
    end)
    if ok then victoryVideo = vid end

    -- Iniciar en menú
    GameState:switch("menu")
end

-- =============================================================================
-- UI CREATION
-- =============================================================================

function createMenuUI()
    local centerX = Constants.WINDOW_WIDTH / 2
    local buttonW = 200
    local buttonH = 50
    
    menuButtons = {
        UI.Button:new(
            centerX - buttonW / 2, 350,
            buttonW, buttonH,
            "INICIAR",
            function()
                Audio:playSFX("menu")
                resetGame()
                GameState:switch("playing")
            end,
            Constants.COLOR_UI_PRIMARY
        ),
        UI.Button:new(
            centerX - buttonW / 2, 420,
            buttonW, buttonH,
            "CONFIGURACION",
            function()
                Audio:playSFX("menu")
                GameState:switch("settings")
            end,
            Constants.COLOR_UI_SECONDARY
        ),
        UI.Button:new(
            centerX - buttonW / 2, 490,
            buttonW, buttonH,
            "SALIR",
            function()
                Audio:playSFX("menu")
                love.event.quit()
            end,
            {0.5, 0.5, 0.5}
        )
    }
end

function createSettingsUI()
    local centerX = Constants.WINDOW_WIDTH / 2
    local sliderW = 300
    local startY = 280
    local spacing = 80
    
    local musicVol, shootVol, explosionVol = Audio:getVolumes()
    
    settingsSliders = {
        UI.Slider:new(
            centerX - sliderW / 2, startY,
            sliderW,
            "Volumen de Musica",
            musicVol,
            function(value)
                Audio:setMusicVolume(value)
                Config:set("musicVolume", value)
            end,
            Constants.COLOR_UI_SECONDARY
        ),
        UI.Slider:new(
            centerX - sliderW / 2, startY + spacing,
            sliderW,
            "Volumen de Disparos",
            shootVol,
            function(value)
                Audio:setShootVolume(value)
                Config:set("sfxShootVolume", value)
                Audio:playTestSound("shoot")
            end,
            {1, 0.8, 0.2}  -- Amarillo
        ),
        UI.Slider:new(
            centerX - sliderW / 2, startY + spacing * 2,
            sliderW,
            "Volumen de Explosiones",
            explosionVol,
            function(value)
                Audio:setExplosionVolume(value)
                Config:set("sfxExplosionVolume", value)
                Audio:playTestSound("explosion")
            end,
            {1, 0.3, 0.3}  -- Rojo
        )
    }
    
    settingsButtons = {
        UI.Button:new(
            centerX - 100, startY + spacing * 3 + 20,
            200, 50,
            "VOLVER",
            function()
                Audio:playSFX("menu")
                GameState:switch("menu")
            end,
            {0.5, 0.5, 0.5}
        )
    }
end

function love.update(dt)
    -- Cap delta time para evitar saltos grandes
    dt = math.min(dt, 1/30)
    
    GameState:update(dt)
end

function love.draw()
    -- Comenzar render al canvas del shader
    if crtShader then
        crtShader:beginDraw()
    end
    
    -- Dibujar estado actual
    GameState:draw()
    
    -- Debug overlay
    drawDebugOverlay()
    
    -- Aplicar shader CRT
    if crtShader then
        crtShader:endDraw()
    end
end

function love.keypressed(key, scancode, isrepeat)
    -- Debug toggles (siempre activos)
    if Input:isAction(key, "debugFPS") then
        debugFlags.showFPS = not debugFlags.showFPS
    elseif Input:isAction(key, "debugEntities") then
        debugFlags.showEntities = not debugFlags.showEntities
    elseif Input:isAction(key, "debugHitboxes") then
        debugFlags.showHitboxes = not debugFlags.showHitboxes
    elseif Input:isAction(key, "debugGrid") then
        debugFlags.showGrid = not debugFlags.showGrid
    elseif Input:isAction(key, "debugSpawns") then
        debugFlags.showSpawns = not debugFlags.showSpawns
    elseif Input:isAction(key, "toggleCRT") then
        if crtShader then
            crtShader:toggle()
        end
    end
    
    GameState:keypressed(key, scancode, isrepeat)
end

function love.keyreleased(key, scancode)
    GameState:keyreleased(key, scancode)
end

function love.mousepressed(x, y, button, istouch, presses)
    GameState:mousepressed(x, y, button, istouch, presses)
end

function love.mousereleased(x, y, button, istouch, presses)
    GameState:mousereleased(x, y, button, istouch, presses)
end

function love.mousemoved(x, y, dx, dy, istouch)
    GameState:mousemoved(x, y, dx, dy, istouch)
end

-- =============================================================================
-- STATE DEFINITIONS
-- =============================================================================

function registerStates()
    -- =========================================================================
    -- MENU STATE
    -- =========================================================================
    GameState:register("menu", {
        enter = function(self)
            love.mouse.setVisible(true)
        end,
        
        update = function(self, dt)
            local mx, my = love.mouse.getPosition()
            for _, button in ipairs(menuButtons) do
                button:update(mx, my)
            end
        end,
        
        draw = function(self)
            -- Fondo con grid
            drawBackgroundGrid()
            
            -- Título con efecto
            local time = love.timer.getTime()
            local pulse = 0.8 + 0.2 * math.sin(time * 3)
            
            love.graphics.setFont(fonts.title)
            love.graphics.setColor(
                Constants.COLOR_UI_PRIMARY[1] * pulse,
                Constants.COLOR_UI_PRIMARY[2] * pulse,
                Constants.COLOR_UI_PRIMARY[3] * pulse,
                1
            )
            
            local title = "SUSHI SURVIVORS"
            local titleWidth = fonts.title:getWidth(title)
            love.graphics.print(
                title,
                Constants.WINDOW_WIDTH / 2 - titleWidth / 2,
                120
            )
            
            -- Subtítulo
            love.graphics.setFont(fonts.medium)
            love.graphics.setColor(1, 1, 1, 0.7)
            local subtitle = "Sobrevive a la invasion de cubos rojos"
            local subWidth = fonts.medium:getWidth(subtitle)
            love.graphics.print(
                subtitle,
                Constants.WINDOW_WIDTH / 2 - subWidth / 2,
                185
            )
            
            -- Botones
            for _, button in ipairs(menuButtons) do
                button:draw()
            end
            
            -- Controles
            love.graphics.setFont(fonts.small)
            love.graphics.setColor(1, 1, 1, 0.4)
            local controls = "WASD: Mover | Mouse: Apuntar | M: Musica | F6: CRT"
            local ctrlWidth = fonts.small:getWidth(controls)
            love.graphics.print(
                controls,
                Constants.WINDOW_WIDTH / 2 - ctrlWidth / 2,
                Constants.WINDOW_HEIGHT - 50
            )
            
            -- Estado de música
            local musicStatus = Audio:isMusicPlaying() and "Music ON" or "Music OFF"
            love.graphics.setColor(Audio:isMusicPlaying() and {0.5, 1, 0.5, 0.7} or {1, 0.5, 0.5, 0.7})
            love.graphics.print(musicStatus, 10, Constants.WINDOW_HEIGHT - 30)
            
            love.graphics.setColor(1, 1, 1, 1)
        end,
        
        keypressed = function(self, key)
            if Input:isAction(key, "confirm") then
                resetGame()
                GameState:switch("playing")
            elseif Input:isAction(key, "cancel") then
                love.event.quit()
            elseif Input:isAction(key, "toggleMusic") then
                Audio:toggleMusic()
            end
        end,
        
        mousepressed = function(self, x, y, button)
            for _, btn in ipairs(menuButtons) do
                btn:click(x, y, button)
            end
        end,
    })
    
    -- =========================================================================
    -- SETTINGS STATE
    -- =========================================================================
    GameState:register("settings", {
        enter = function(self)
            love.mouse.setVisible(true)
            -- Actualizar valores de sliders por si cambiaron
            local musicVol, shootVol, explosionVol = Audio:getVolumes()
            settingsSliders[1]:setValue(musicVol)
            settingsSliders[2]:setValue(shootVol)
            settingsSliders[3]:setValue(explosionVol)
        end,
        
        update = function(self, dt)
            local mx, my = love.mouse.getPosition()
            
            for _, slider in ipairs(settingsSliders) do
                slider:update(mx, my)
            end
            
            for _, button in ipairs(settingsButtons) do
                button:update(mx, my)
            end
        end,
        
        draw = function(self)
            -- Fondo
            drawBackgroundGrid()
            
            -- Panel
            local panelW = 500
            local panelH = 400
            local panelX = (Constants.WINDOW_WIDTH - panelW) / 2
            local panelY = (Constants.WINDOW_HEIGHT - panelH) / 2
            
            -- Fondo del panel
            love.graphics.setColor(0.1, 0.1, 0.15, 0.95)
            love.graphics.rectangle("fill", panelX, panelY, panelW, panelH, 8, 8)
            
            -- Borde
            love.graphics.setColor(Constants.COLOR_UI_SECONDARY)
            love.graphics.setLineWidth(3)
            love.graphics.rectangle("line", panelX, panelY, panelW, panelH, 8, 8)
            love.graphics.setLineWidth(1)
            
            -- Título
            love.graphics.setColor(1, 1, 1, 1)
            local font = love.graphics.getFont()
            local title = "CONFIGURACION"
            local titleWidth = font:getWidth(title)
            love.graphics.print(title, 
                Constants.WINDOW_WIDTH / 2 - titleWidth / 2, 
                panelY + 30)
            
            -- Estado de música
            local musicStatus = Audio:isMusicPlaying() and "Musica: Reproduciendo" or "Musica: Pausada"
            love.graphics.setColor(Audio:isMusicPlaying() and {0.5, 1, 0.5, 0.8} or {1, 0.5, 0.5, 0.8})
            local statusWidth = font:getWidth(musicStatus)
            love.graphics.print(musicStatus,
                Constants.WINDOW_WIDTH / 2 - statusWidth / 2,
                panelY + 60)
            
            -- Sliders
            for _, slider in ipairs(settingsSliders) do
                slider:draw()
            end
            
            -- Botones
            for _, button in ipairs(settingsButtons) do
                button:draw()
            end
            
            -- Instrucción
            love.graphics.setColor(1, 1, 1, 0.4)
            local hint = "Presiona M para pausar/reanudar musica"
            local hintWidth = font:getWidth(hint)
            love.graphics.print(hint,
                Constants.WINDOW_WIDTH / 2 - hintWidth / 2,
                panelY + panelH - 40)
            
            love.graphics.setColor(1, 1, 1, 1)
        end,
        
        keypressed = function(self, key)
            if Input:isAction(key, "cancel") then
                GameState:switch("menu")
            elseif Input:isAction(key, "toggleMusic") then
                Audio:toggleMusic()
            end
        end,
        
        mousepressed = function(self, x, y, button)
            for _, slider in ipairs(settingsSliders) do
                slider:mousePressed(x, y, button)
            end
            
            for _, btn in ipairs(settingsButtons) do
                btn:click(x, y, button)
            end
        end,
        
        mousereleased = function(self, x, y, button)
            for _, slider in ipairs(settingsSliders) do
                slider:mouseReleased()
            end
        end,
    })
    
    -- =========================================================================
    -- PLAYING STATE
    -- =========================================================================
    GameState:register("playing", {
        enter = function(self)
            love.mouse.setVisible(false)
        end,
        
        update = function(self, dt)
            gameTime = gameTime + dt
            
            -- Update player
            local shouldFire = player:update(dt)
            
            -- Disparar
            if shouldFire then
                local x, y, dx, dy = player:getFireData()
                local baseAngle   = math.atan2(dy, dx)
                local bulletCount = player.spreadActive and Constants.SPREAD_SHOT_BULLETS or 1
                local totalArc    = player.spreadActive and Constants.SPREAD_SHOT_ANGLE or 0

                for i = 1, bulletCount do
                    local angle
                    if bulletCount == 1 then
                        angle = baseAngle
                    else
                        local t = (i - 1) / (bulletCount - 1)   -- 0..1
                        angle = baseAngle - totalArc / 2 + t * totalArc
                    end
                    local bullet = bulletPool:get()
                    if bullet then
                        bullet:activate(x, y, math.cos(angle), math.sin(angle))
                    end
                end
                Audio:playSFX("shoot")
            end

            -- Spawn enemies (pausado mientras el jefe esté activo)
            if not boss.active then
                spawner:update(dt)
            end

            -- Update enemies normales
            for _, enemy in enemyPool:iterateActive() do
                enemy:update(dt, player.x, player.y)
            end

            -- Update enemies erráticos
            for _, enemy in erraticEnemyPool:iterateActive() do
                enemy:update(dt, player.x, player.y)
            end

            -- Update power-ups y colisión con jugador
            for _, pu in powerupPool:iterateActive() do
                if not pu:update(dt) then
                    powerupPool:release(pu)
                elseif pu:isCollectedBy(player.x, player.y) then
                    player:activateSpread(Constants.SPREAD_SHOT_DURATION)
                    local cx, cy = pu:getCenter()
                    spawnParticles(cx, cy, 12, Constants.COLOR_POWERUP_SPREAD, 80, 200)
                    powerupPool:release(pu)
                end
            end
            
            -- Spawn del jefe al llegar al umbral de puntos
            if not boss.active and score >= nextBossScore then
                -- Eliminar todos los enemigos y power-ups antes de spawnear al jefe
                for _, enemy in enemyPool:iterateActive() do
                    local cx, cy = enemy:getCenter()
                    spawnParticles(cx, cy, 8, Constants.COLOR_PARTICLE_DEATH, 40, 120)
                    enemyPool:release(enemy)
                end
                for _, enemy in erraticEnemyPool:iterateActive() do
                    local cx, cy = enemy:getCenter()
                    spawnParticles(cx, cy, 8, Constants.COLOR_ERRATIC_ENEMY, 40, 120)
                    erraticEnemyPool:release(enemy)
                end
                powerupPool:releaseAll()

                boss:spawn()
                nextBossScore = nextBossScore + Constants.BOSS_SCORE_INTERVAL
                Audio:playMusic("boss")
            end

            -- Update jefe (incluyendo estados de muerte)
            if boss.active then
                local bossAction = boss:update(dt, player.x, player.y)

                if bossAction == "death_explode" then
                    -- Ráfaga inicial de la explosión
                    spawnParticles(boss.x, boss.y, 40, Constants.COLOR_BOSS, 150, 420)
                    spawnParticles(boss.x, boss.y, 20, {1, 0.85, 0.2, 1}, 80, 250)
                    bossBulletPool:releaseAll()
                    Audio:playSFX("explosion")
                    -- Arrancar explosión gradual durante BOSS_DEATH_WAIT_DURATION segundos
                    bossDeathX         = boss.x
                    bossDeathY         = boss.y
                    bossExplosionTimer = Constants.BOSS_DEATH_WAIT_DURATION
                    bossExplosionTick  = 0

                elseif bossAction == "death_complete" then
                    GameState:switch("victory")

                elseif type(bossAction) == "table" then

                    if bossAction.mode == "normal" then
                        local bx, by, bdx, bdy = boss:getFireData(bossAction.tx, bossAction.ty)
                        local bb = bossBulletPool:get()
                        if bb then bb:activate(bx, by, bdx, bdy) end
                        Audio:playSFX("shoot")

                    elseif bossAction.mode == "burst" then
                        local ang = bossAction.angle
                        local bx  = boss.x + math.cos(ang) * (boss.radius + 5)
                        local by  = boss.y + math.sin(ang) * (boss.radius + 5)
                        local bb  = bossBulletPool:get()
                        if bb then bb:activate(bx, by, math.cos(ang), math.sin(ang)) end

                    elseif bossAction.mode == "arc" then
                        local _, _, bdx, bdy = boss:getFireData(bossAction.tx, bossAction.ty)
                        local baseAngle = math.atan2(bdy, bdx)
                        local bsx = boss.x + bdx * (boss.radius + 5)
                        local bsy = boss.y + bdy * (boss.radius + 5)
                        local n   = Constants.BOSS_ARC_BULLETS
                        local arc = Constants.BOSS_ARC_ANGLE
                        for i = 1, n do
                            local t   = (i - 1) / (n - 1)
                            local ang = baseAngle - arc / 2 + t * arc
                            local bb  = bossBulletPool:get()
                            if bb then bb:activate(bsx, bsy, math.cos(ang), math.sin(ang)) end
                        end
                        Audio:playSFX("shoot")

                    elseif bossAction.mode == "bomb" then
                        local bx, by, bdx, bdy = boss:getFireData(bossAction.tx, bossAction.ty)
                        local bb = bossBulletPool:get()
                        if bb then
                            bb:activate(bx, by, bdx, bdy)
                            bb.radius    = Constants.BOSS_BOMB_RADIUS
                            bb.width     = bb.radius * 2
                            bb.height    = bb.radius * 2
                            bb.speed     = Constants.BOSS_BOMB_SPEED
                            bb.isBomb    = true
                            bb.explodeAt = Constants.BOSS_BOMB_EXPLODE_DIST
                        end
                        Audio:playSFX("shoot")
                    end
                end

                -- Colisión jefe ↔ jugador
                if boss:collidesWithPlayer(player) then
                    player:die()
                    GameState:switch("gameover")
                end

                -- Explosión gradual (durante dying_wait)
                if bossExplosionTimer > 0 then
                    bossExplosionTimer = bossExplosionTimer - dt
                    bossExplosionTick  = bossExplosionTick  - dt
                    if bossExplosionTick <= 0 then
                        bossExplosionTick = BOSS_EXPLOSION_INTERVAL
                        spawnParticles(bossDeathX, bossDeathY, 10, Constants.COLOR_BOSS, 100, 320)
                        spawnParticles(bossDeathX, bossDeathY,  5, {1, 0.85, 0.2, 1}, 60, 180)
                        Audio:playSFX("explosion")
                    end
                end
            end

            -- Update balas del jugador (+ colisión con jefe)
            for _, bullet in bulletPool:iterateActive() do
                if not bullet:update(dt) then
                    bulletPool:release(bullet)
                elseif boss.active and boss:collidesWithBullet(bullet) then
                    bulletPool:release(bullet)
                    if boss:takeDamage(bullet.damage) then
                        boss:startDying()
                        Audio:playMusic("winsound")
                    end
                end
            end

            -- Update balas del jefe (normal + bomba + perdigones)
            for _, bb in bossBulletPool:iterateActive() do
                local result = bb:update(dt)
                if result == "explode" then
                    -- La bomba detona: crear perdigones en 8 direcciones
                    local bx, by = bb.x, bb.y
                    spawnParticles(bx, by, 16, Constants.COLOR_BOSS_BULLET, 80, 220)
                    for i = 1, Constants.BOSS_PELLET_COUNT do
                        local ang    = (i - 1) / Constants.BOSS_PELLET_COUNT * math.pi * 2
                        local pellet = bossBulletPool:get()
                        if pellet then
                            pellet:activate(bx, by, math.cos(ang), math.sin(ang))
                            pellet.radius = Constants.BOSS_PELLET_RADIUS
                            pellet.width  = pellet.radius * 2
                            pellet.height = pellet.radius * 2
                            pellet.speed  = Constants.BOSS_PELLET_SPEED
                        end
                    end
                    bossBulletPool:release(bb)
                elseif result == false then
                    bossBulletPool:release(bb)
                elseif bb:collidesWithPlayer(player) then
                    bossBulletPool:release(bb)
                    player:die()
                    GameState:switch("gameover")
                end
            end
            
            -- Update particles
            for _, particle in particlePool:iterateActive() do
                if not particle:update(dt) then
                    particlePool:release(particle)
                end
            end
            
            -- Collision detection (normales + erráticos)
            collision:update(player, bulletPool, enemyPool)
            collision:update(player, bulletPool, erraticEnemyPool)
        end,
        
        draw = function(self)
            -- Background grid
            drawBackgroundGrid()
            
            -- Particles (behind everything)
            for _, particle in particlePool:iterateActive() do
                particle:draw()
            end
            
            -- Power-ups (debajo de los enemigos)
            for _, pu in powerupPool:iterateActive() do
                pu:draw()
            end

            -- Enemies normales
            for _, enemy in enemyPool:iterateActive() do
                enemy:draw()
                if debugFlags.showHitboxes then
                    enemy:drawDebug()
                end
            end

            -- Enemies erráticos
            for _, enemy in erraticEnemyPool:iterateActive() do
                enemy:draw()
                if debugFlags.showHitboxes then
                    enemy:drawDebug()
                end
            end
            
            -- Balas del jugador
            for _, bullet in bulletPool:iterateActive() do
                bullet:draw()
                if debugFlags.showHitboxes then
                    bullet:drawDebug()
                end
            end

            -- Jefe
            if boss.active then
                boss:draw()
            end

            -- Balas del jefe
            for _, bb in bossBulletPool:iterateActive() do
                bb:draw()
                if debugFlags.showHitboxes then
                    bb:drawDebug()
                end
            end

            -- Player
            player:draw()
            if debugFlags.showHitboxes then
                player:drawDebug()
            end
            
            -- Debug visuals
            if debugFlags.showGrid then
                collision:drawDebug()
            end
            
            if debugFlags.showSpawns then
                spawner:drawDebug()
            end
            
            -- HUD
            drawHUD()
            
            -- Crosshair cursor
            drawCrosshair()
        end,
        
        keypressed = function(self, key)
            if Input:isAction(key, "cancel") then
                GameState:switch("menu")
            elseif Input:isAction(key, "toggleMusic") then
                Audio:toggleMusic()
            end
        end,
    })
    
    -- =========================================================================
    -- GAME OVER STATE
    -- =========================================================================
    GameState:register("gameover", {
        enter = function(self)
            love.mouse.setVisible(true)
        end,
        
        draw = function(self)
            -- Dibujar el juego de fondo (congelado)
            drawBackgroundGrid()
            
            for _, particle in particlePool:iterateActive() do
                particle:draw()
            end
            
            for _, enemy in enemyPool:iterateActive() do
                enemy:draw()
            end

            for _, enemy in erraticEnemyPool:iterateActive() do
                enemy:draw()
            end

            for _, bullet in bulletPool:iterateActive() do
                bullet:draw()
            end

            if boss.active then boss:draw() end
            for _, bb in bossBulletPool:iterateActive() do bb:draw() end

            -- Overlay oscuro
            love.graphics.setColor(0, 0, 0, 0.75)
            love.graphics.rectangle("fill", 0, 0, 
                Constants.WINDOW_WIDTH, Constants.WINDOW_HEIGHT)
            
            -- Panel de game over
            local panelW = 450
            local panelH = 220
            local panelX = (Constants.WINDOW_WIDTH - panelW) / 2
            local panelY = (Constants.WINDOW_HEIGHT - panelH) / 2
            
            -- Fondo del panel
            love.graphics.setColor(0.08, 0.08, 0.1, 0.95)
            love.graphics.rectangle("fill", panelX, panelY, panelW, panelH, 8, 8)
            
            -- Borde
            love.graphics.setColor(1, 0.2, 0.2, 0.8)
            love.graphics.setLineWidth(3)
            love.graphics.rectangle("line", panelX, panelY, panelW, panelH, 8, 8)
            love.graphics.setLineWidth(1)
            
            -- GAME OVER
            love.graphics.setFont(fonts.title)
            love.graphics.setColor(0, 0, 0, 0.5)
            local goText = "GAME OVER"
            local goWidth = fonts.title:getWidth(goText)
            love.graphics.print(goText, 
                Constants.WINDOW_WIDTH / 2 - goWidth / 2 + 2, 
                panelY + 25 + 2)
            love.graphics.setColor(1, 0.2, 0.2, 1)
            love.graphics.print(goText, 
                Constants.WINDOW_WIDTH / 2 - goWidth / 2, 
                panelY + 25)
            
            -- Score
            love.graphics.setFont(fonts.large)
            love.graphics.setColor(0, 0, 0, 0.5)
            local scoreText = "PUNTUACION FINAL: " .. score
            local scoreWidth = fonts.large:getWidth(scoreText)
            love.graphics.print(scoreText, 
                Constants.WINDOW_WIDTH / 2 - scoreWidth / 2 + 2, 
                panelY + 85 + 2)
            love.graphics.setColor(Constants.COLOR_SCORE)
            love.graphics.print(scoreText, 
                Constants.WINDOW_WIDTH / 2 - scoreWidth / 2, 
                panelY + 85)
            
            -- Instrucciones
            love.graphics.setFont(fonts.medium)
            love.graphics.setColor(1, 1, 1, 0.8)
            local restart = "Presiona R para reiniciar"
            local restartWidth = fonts.medium:getWidth(restart)
            love.graphics.print(restart, 
                Constants.WINDOW_WIDTH / 2 - restartWidth / 2, 
                panelY + 140)
            
            love.graphics.setColor(1, 1, 1, 0.5)
            local quit = "Presiona ESC para volver al menu"
            local quitWidth = fonts.medium:getWidth(quit)
            love.graphics.print(quit, 
                Constants.WINDOW_WIDTH / 2 - quitWidth / 2, 
                panelY + 170)
            
            love.graphics.setColor(1, 1, 1, 1)
        end,
        
        keypressed = function(self, key)
            if Input:isAction(key, "restart") then
                resetGame()
                GameState:switch("playing")
            elseif Input:isAction(key, "cancel") then
                GameState:switch("menu")
            end
        end,
    })

    -- =========================================================================
    -- VICTORY STATE
    -- =========================================================================
    GameState:register("victory", {
        enter = function(self)
            love.mouse.setVisible(true)
            if victoryVideo then
                victoryVideo:rewind()
                victoryVideo:play()
            end
        end,

        draw = function(self)
            -- Fondo: video si está disponible, sino grid
            if victoryVideo then
                local vw = victoryVideo:getWidth()
                local vh = victoryVideo:getHeight()
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.draw(
                    victoryVideo, 0, 0, 0,
                    Constants.WINDOW_WIDTH  / vw,
                    Constants.WINDOW_HEIGHT / vh
                )
            else
                drawBackgroundGrid()
                for _, particle in particlePool:iterateActive() do particle:draw() end
                for _, enemy   in enemyPool:iterateActive()    do enemy:draw()    end
                for _, enemy   in erraticEnemyPool:iterateActive() do enemy:draw() end
                for _, bullet  in bulletPool:iterateActive()   do bullet:draw()   end
                player:draw()
            end

            -- Overlay oscuro dorado
            love.graphics.setColor(0.05, 0.05, 0, 0.72)
            love.graphics.rectangle("fill", 0, 0,
                Constants.WINDOW_WIDTH, Constants.WINDOW_HEIGHT)

            -- Panel
            local panelW = 520
            local panelH = 250
            local panelX = (Constants.WINDOW_WIDTH  - panelW) / 2
            local panelY = (Constants.WINDOW_HEIGHT - panelH) / 2

            love.graphics.setColor(0.06, 0.06, 0.05, 0.96)
            love.graphics.rectangle("fill", panelX, panelY, panelW, panelH, 8, 8)

            love.graphics.setColor(1, 0.8, 0.1, 1)
            love.graphics.setLineWidth(3)
            love.graphics.rectangle("line", panelX, panelY, panelW, panelH, 8, 8)
            love.graphics.setLineWidth(1)

            -- Título "VICTORIA" pulsante en dorado
            local time  = love.timer.getTime()
            local pulse = 0.85 + 0.15 * math.sin(time * 3)
            love.graphics.setFont(fonts.title)
            love.graphics.setColor(1 * pulse, 0.8 * pulse, 0.1 * pulse, 1)
            local vText  = "VICTORIA"
            local vWidth = fonts.title:getWidth(vText)
            love.graphics.print(vText,
                Constants.WINDOW_WIDTH / 2 - vWidth / 2,
                panelY + 22)

            -- Subtítulo
            love.graphics.setFont(fonts.medium)
            love.graphics.setColor(1, 1, 1, 0.9)
            local sub      = "Sushiminis ha ganado..."
            local subWidth = fonts.medium:getWidth(sub)
            love.graphics.print(sub,
                Constants.WINDOW_WIDTH / 2 - subWidth / 2,
                panelY + 92)

            -- Score
            love.graphics.setFont(fonts.large)
            love.graphics.setColor(Constants.COLOR_SCORE)
            local st    = "PUNTUACION: " .. score
            local stW   = fonts.large:getWidth(st)
            love.graphics.print(st,
                Constants.WINDOW_WIDTH / 2 - stW / 2,
                panelY + 130)

            -- Instrucciones
            love.graphics.setFont(fonts.small)
            love.graphics.setColor(1, 1, 1, 0.7)
            local r1   = "R: Jugar de nuevo    ESC: Menu"
            local r1W  = fonts.small:getWidth(r1)
            love.graphics.print(r1,
                Constants.WINDOW_WIDTH / 2 - r1W / 2,
                panelY + 210)

            love.graphics.setColor(1, 1, 1, 1)
        end,

        keypressed = function(self, key)
            if Input:isAction(key, "restart") then
                resetGame()
                GameState:switch("playing")
            elseif Input:isAction(key, "cancel") then
                GameState:switch("menu")
            end
        end,
    })
end

-- =============================================================================
-- DRAWING HELPERS
-- =============================================================================

function drawBackgroundGrid()
    love.graphics.setColor(0.1, 0.1, 0.15, 0.5)
    
    local gridSize = 40
    
    for x = 0, Constants.WINDOW_WIDTH, gridSize do
        love.graphics.line(x, 0, x, Constants.WINDOW_HEIGHT)
    end
    
    for y = 0, Constants.WINDOW_HEIGHT, gridSize do
        love.graphics.line(0, y, Constants.WINDOW_WIDTH, y)
    end
    
    love.graphics.setColor(1, 1, 1, 1)
end

function drawHUD()
    love.graphics.setFont(fonts.medium)
    
    -- Score con sombra
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.print("SCORE: " .. score, 12, 12)
    love.graphics.setColor(Constants.COLOR_SCORE)
    love.graphics.print("SCORE: " .. score, 10, 10)
    
    -- Tiempo con sombra
    local minutes = math.floor(gameTime / 60)
    local seconds = math.floor(gameTime % 60)
    local timeText = string.format("TIME: %02d:%02d", minutes, seconds)
    
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.print(timeText, 12, 37)
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.print(timeText, 10, 35)
    
    -- Enemigos activos con sombra
    local activeEnemies, _, _ = enemyPool:getStats()
    local enemyText = "ENEMIES: " .. activeEnemies
    local enemyColor = activeEnemies > 80 and {1, 0.3, 0.3, 1} or {1, 0.8, 0.2, 1}
    
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.print(enemyText, 12, 62)
    love.graphics.setColor(enemyColor)
    love.graphics.print(enemyText, 10, 60)
    
    -- Indicador de música (esquina inferior izquierda)
    love.graphics.setFont(fonts.small)
    if Audio:isMusicPlaying() then
        love.graphics.setColor(0.5, 1, 0.5, 0.6)
        love.graphics.print("[M] Music ON", 10, Constants.WINDOW_HEIGHT - 25)
    else
        love.graphics.setColor(1, 0.5, 0.5, 0.6)
        love.graphics.print("[M] Music OFF", 10, Constants.WINDOW_HEIGHT - 25)
    end
    
    -- Barra de vida del jefe (centro superior)
    if boss and boss.active then
        local barW  = 500
        local barH  = 18
        local barX  = (Constants.WINDOW_WIDTH - barW) / 2
        local barY  = 8
        local pct   = boss.health / boss.maxHealth

        -- Fondo oscuro
        love.graphics.setColor(0.1, 0.1, 0.15, 0.9)
        love.graphics.rectangle("fill", barX, barY, barW, barH, 4, 4)

        -- Relleno rojo
        love.graphics.setColor(Constants.COLOR_BOSS_HEALTHBAR)
        love.graphics.rectangle("fill", barX, barY, barW * pct, barH, 4, 4)

        -- Borde
        love.graphics.setColor(1, 0.3, 0.3, 1)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", barX, barY, barW, barH, 4, 4)
        love.graphics.setLineWidth(1)

        -- Marcadores de fase (líneas blancas en los umbrales 80/60/40/20%)
        love.graphics.setColor(1, 1, 1, 0.65)
        love.graphics.setLineWidth(2)
        local phaseThresholds = {
            Constants.BOSS_PHASE2_HP / Constants.BOSS_HEALTH,
            Constants.BOSS_PHASE3_HP / Constants.BOSS_HEALTH,
            Constants.BOSS_PHASE4_HP / Constants.BOSS_HEALTH,
            Constants.BOSS_PHASE5_HP / Constants.BOSS_HEALTH,
        }
        for _, t in ipairs(phaseThresholds) do
            local mx = barX + barW * t
            love.graphics.line(mx, barY + 2, mx, barY + barH - 2)
        end
        love.graphics.setLineWidth(1)

        -- Etiqueta centrada dentro de la barra
        love.graphics.setFont(fonts.small)
        love.graphics.setColor(1, 1, 1, 1)
        local bPhase   = boss:getPhase()
        local label    = string.format("JEFE  %d / %d   [Fase %d]", boss.health, boss.maxHealth, bPhase)
        local labelW   = fonts.small:getWidth(label)
        love.graphics.print(label, Constants.WINDOW_WIDTH / 2 - labelW / 2, barY + 2)
    end

    -- Spread shot activo (centro superior, debajo de la barra del jefe si aplica)
    if player.spreadActive then
        local c    = Constants.COLOR_POWERUP_SPREAD
        local pulse = 0.7 + 0.3 * math.sin(love.timer.getTime() * 6)
        love.graphics.setFont(fonts.small)
        love.graphics.setColor(c[1] * pulse, c[2] * pulse, c[3] * pulse, 1)
        local spreadText = string.format("[ SPREAD SHOT  %.1fs ]", player.spreadTimer)
        local sw   = fonts.small:getWidth(spreadText)
        local syOffset = (boss and boss.active) and 34 or 10
        love.graphics.print(spreadText, Constants.WINDOW_WIDTH / 2 - sw / 2, syOffset)
    end

    -- Spawn rate (esquina inferior derecha)
    love.graphics.setColor(1, 1, 1, 0.3)
    local rate = string.format("Spawn: %.2fs", spawner:getCurrentRate())
    love.graphics.print(rate, Constants.WINDOW_WIDTH - fonts.small:getWidth(rate) - 10, Constants.WINDOW_HEIGHT - 25)

    love.graphics.setColor(1, 1, 1, 1)
end

function drawCrosshair()
    local mx, my = love.mouse.getPosition()
    local size = 12
    local innerSize = 4
    local time = love.timer.getTime()
    
    -- Rotación sutil
    love.graphics.push()
    love.graphics.translate(mx, my)
    love.graphics.rotate(time * 0.5)
    
    -- Cruz exterior
    love.graphics.setColor(1, 0.2, 0.2, 0.6)
    love.graphics.setLineWidth(2)
    love.graphics.line(-size, 0, -innerSize, 0)
    love.graphics.line(innerSize, 0, size, 0)
    love.graphics.line(0, -size, 0, -innerSize)
    love.graphics.line(0, innerSize, 0, size)
    
    love.graphics.pop()
    
    -- Círculo central
    love.graphics.setColor(1, 0.2, 0.2, 0.8)
    love.graphics.circle("line", mx, my, innerSize)
    
    -- Punto central
    love.graphics.setColor(1, 0.4, 0.4, 1)
    love.graphics.circle("fill", mx, my, 2)
    
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

function drawDebugOverlay()
    if not (debugFlags.showFPS or debugFlags.showEntities) then
        return
    end
    
    local y = 10
    local x = Constants.WINDOW_WIDTH - 150
    
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", x - 5, y - 5, 150, 
        (debugFlags.showFPS and debugFlags.showEntities) and 120 or 60)
    
    love.graphics.setColor(Constants.DEBUG_COLOR)
    
    if debugFlags.showFPS then
        love.graphics.print("FPS: " .. love.timer.getFPS(), x, y)
        y = y + 15
        
        local stats = love.graphics.getStats()
        love.graphics.print("Draw calls: " .. stats.drawcalls, x, y)
        y = y + 15
        
        if crtShader then
            love.graphics.print("CRT: " .. crtShader:getStatus(), x, y)
            y = y + 15
        end
    end
    
    if debugFlags.showEntities then
        local bullets, bulletTotal, _ = bulletPool:getStats()
        local enemies, enemyTotal, _ = enemyPool:getStats()
        local particles, particleTotal, _ = particlePool:getStats()
        
        love.graphics.print(string.format("Bullets: %d/%d", bullets, bulletTotal), x, y)
        y = y + 15
        love.graphics.print(string.format("Enemies: %d/%d", enemies, enemyTotal), x, y)
        y = y + 15
        love.graphics.print(string.format("Particles: %d/%d", particles, particleTotal), x, y)
    end
    
    love.graphics.setColor(1, 1, 1, 1)
end