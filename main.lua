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
local Particle = require("src.entities.particle")

local Spawner = require("src.systems.spawner")
local Collision = require("src.systems.collision")
local Audio = require("src.core.audio")
local UI = require("src.ui.ui_components")
local CRTShader = require("src.rendering.crt_shader")

-- =============================================================================
-- GAME VARIABLES
-- =============================================================================
local player
local bulletPool
local enemyPool
local particlePool
local spawner
local collision
local crtShader

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
    particlePool:releaseAll()
    
    -- Reset spawner
    spawner:reset()
    
    -- Reset score y tiempo
    score = 0
    gameTime = 0
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
    bulletPool = Pool:new(Bullet, Constants.BULLET_POOL_SIZE)
    enemyPool = Pool:new(Enemy, Constants.ENEMY_POOL_SIZE)
    particlePool = Pool:new(Particle, Constants.PARTICLE_POOL_SIZE)
    
    -- Crear sistemas
    spawner = Spawner:new(enemyPool)
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
    
    -- Inicializar audio
    Audio:init()
    Audio:playMusic("main")
    
    -- Crear UI de menú
    createMenuUI()
    createSettingsUI()
    
    -- Crear shader CRT
    crtShader = CRTShader:new()
    
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
                GameState:switch("settings")
            end,
            Constants.COLOR_UI_SECONDARY
        ),
        UI.Button:new(
            centerX - buttonW / 2, 490,
            buttonW, buttonH,
            "SALIR",
            function()
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
                local bullet = bulletPool:get()
                if bullet then
                    local x, y, dx, dy = player:getFireData()
                    bullet:activate(x, y, dx, dy)
                    Audio:playSFX("shoot")
                end
            end
            
            -- Spawn enemies
            spawner:update(dt)
            
            -- Update enemies
            for _, enemy in enemyPool:iterateActive() do
                enemy:update(dt, player.x, player.y)
            end
            
            -- Update bullets
            for _, bullet in bulletPool:iterateActive() do
                if not bullet:update(dt) then
                    bulletPool:release(bullet)
                end
            end
            
            -- Update particles
            for _, particle in particlePool:iterateActive() do
                if not particle:update(dt) then
                    particlePool:release(particle)
                end
            end
            
            -- Collision detection
            collision:update(player, bulletPool, enemyPool)
        end,
        
        draw = function(self)
            -- Background grid
            drawBackgroundGrid()
            
            -- Particles (behind everything)
            for _, particle in particlePool:iterateActive() do
                particle:draw()
            end
            
            -- Enemies
            for _, enemy in enemyPool:iterateActive() do
                enemy:draw()
                if debugFlags.showHitboxes then
                    enemy:drawDebug()
                end
            end
            
            -- Bullets
            for _, bullet in bulletPool:iterateActive() do
                bullet:draw()
                if debugFlags.showHitboxes then
                    bullet:drawDebug()
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
            
            for _, bullet in bulletPool:iterateActive() do
                bullet:draw()
            end
            
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