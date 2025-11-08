-- main.lua - Juego estilo Vampire Survivors con gatito

function love.load()
    love.window.setTitle("🍣 Sushi Survivors")
    love.mouse.setVisible(true)
    
    -- Fuentes
    catFont = love.graphics.newFont(40)
    uiFont = love.graphics.newFont(16)
    titleFont = love.graphics.newFont(64)
    subtitleFont = love.graphics.newFont(24)
    
    -- Cargar música
    music = nil
    local musicFiles = {"Sushi_Game_OST_Armageddon.mp3", "Sushi_Game_OST_Armageddon.ogg", "Sushi_Game_OST_Armageddon.wav"}
    
    for _, filename in ipairs(musicFiles) do
        local success, audio = pcall(love.audio.newSource, filename, "stream")
        if success then
            music = audio
            music:setLooping(true)
            music:setVolume(0.6)
            break
        end
    end
    
    -- Si no se encontró ningún archivo de audio compatible
    if not music then
        print("Advertencia: No se pudo cargar la música. Formatos soportados: .mp3, .ogg, .wav")
        print("Love2D no soporta archivos .mp4 para audio. Por favor convierte tu archivo a .mp3 u .ogg")
    end
    
    -- Efectos de sonido
    sounds = {}
    
    -- Cargar sonido de disparo
    local success, snd = pcall(love.audio.newSource, "pistol-shot.wav", "static")
    if success then
        sounds.shoot = snd
        sounds.shoot:setVolume(0.3)
        print("Sonido de disparo cargado")
    else
        print("No se pudo cargar pistol-shot.wav")
        sounds.shoot = nil
    end
    
    -- Cargar sonido de explosión
    success, snd = pcall(love.audio.newSource, "Synthetic-explosion.wav", "static")
    if success then
        sounds.explosion = snd
        sounds.explosion:setVolume(0.4)
        print("Sonido de explosión cargado")
    else
        print("No se pudo cargar Synthetic-explosion.wav")
        sounds.explosion = nil
    end
    
    -- Cargar sprites
    sprites = {}
    -- Intentar cargar el sprite del jugador
    local success, img = pcall(love.graphics.newImage, "cat.png")
    if success then
        sprites.player = img
    else
        -- Si no existe la imagen, usaremos un sprite dibujado
        sprites.player = nil
    end
    
    -- Cargar sprite del enemigo si existe
    success, img = pcall(love.graphics.newImage, "enemy.png")
    if success then
        sprites.enemy = img
    else
        sprites.enemy = nil
    end
    
    -- Estado del juego
    gameState = "menu" -- menu, playing, gameover, settings
    score = 0
    musicPlaying = false
    
    -- Iniciar música inmediatamente
    if music then
        music:play()
        musicPlaying = true
    end
    
    -- Inicializar jugador
    initPlayer()
    
    -- Enemigos
    enemies = {}
    enemySpawnTimer = 0
    enemySpawnRate = 1.0 -- segundos entre spawns
    
    -- Balas
    bullets = {}
    shootTimer = 0
    shootRate = 0.3 -- segundos entre disparos
    
    -- Partículas
    particles = {}
    
    -- Efecto CRT
    crtTime = 0
    local success, shader = pcall(function()
        return love.graphics.newShader([[
            extern number time;
            extern vec2 resolution;
            
            vec4 effect(vec4 color, Image texture, vec2 tc, vec2 pc) {
                vec2 uv = tc;
                
                float scanline = sin(uv.y * resolution.y * 1.5) * 0.04;
                
                vec2 curved = uv * 2.0 - 1.0;
                curved *= 1.0 + 0.05 * (curved.x * curved.x + curved.y * curved.y);
                curved = (curved + 1.0) * 0.5;
                
                float vignette = 1.0 - length(curved - 0.5) * 0.8;
                
                vec4 col = Texel(texture, curved);
                float distortion = 0.002;
                col.r = Texel(texture, curved + vec2(distortion, 0.0)).r;
                col.b = Texel(texture, curved - vec2(distortion, 0.0)).b;
                
                float flicker = 0.98 + 0.02 * sin(time * 20.0);
                
                col.rgb *= (1.0 - scanline) * vignette * flicker;
                
                if (curved.x < 0.0 || curved.x > 1.0 || curved.y < 0.0 || curved.y > 1.0) {
                    col = vec4(0.0, 0.0, 0.0, 1.0);
                }
                
                return col * color;
            }
        ]])
    end)
    
    if success then
        crtShader = shader
        crtShader:send("resolution", {love.graphics.getWidth(), love.graphics.getHeight()})
    end
    
    canvas = love.graphics.newCanvas()
    
    -- Botón de inicio
    startButton = {
        x = 0,
        y = 0,
        width = 200,
        height = 60,
        text = "INICIAR",
        hovered = false
    }
    
    -- Botón de configuración
    settingsButton = {
        x = 0,
        y = 0,
        width = 200,
        height = 60,
        text = "CONFIGURACIÓN",
        hovered = false
    }
    
    -- Centrar los botones
    startButton.x = love.graphics.getWidth()/2 - startButton.width/2
    startButton.y = love.graphics.getHeight()/2 + 30
    
    settingsButton.x = love.graphics.getWidth()/2 - settingsButton.width/2
    settingsButton.y = love.graphics.getHeight()/2 + 110
    
    -- Configuración de volumen
    volumeSlider = {
        x = 0,
        y = 0,
        width = 300,
        height = 20,
        value = 0.6, -- 60% volumen inicial
        dragging = false
    }
    
    volumeSlider.x = love.graphics.getWidth()/2 - volumeSlider.width/2
    volumeSlider.y = love.graphics.getHeight()/2 + 20
    
    -- Slider de efectos de sonido - Disparos
    shootSlider = {
        x = 0,
        y = 0,
        width = 300,
        height = 20,
        value = 0.15, -- 15% volumen inicial para disparos
        dragging = false
    }
    
    shootSlider.x = love.graphics.getWidth()/2 - shootSlider.width/2
    shootSlider.y = love.graphics.getHeight()/2 + 100
    
    -- Slider de efectos de sonido - Explosiones
    explosionSlider = {
        x = 0,
        y = 0,
        width = 300,
        height = 20,
        value = 0.15, -- 15% volumen inicial para explosiones
        dragging = false
    }
    
    explosionSlider.x = love.graphics.getWidth()/2 - explosionSlider.width/2
    explosionSlider.y = love.graphics.getHeight()/2 + 180
    
    -- Aplicar volumen inicial a los efectos
    if sounds.shoot then sounds.shoot:setVolume(shootSlider.value) end
    if sounds.explosion then sounds.explosion:setVolume(explosionSlider.value) end
    
    -- Botón de volver
    backButton = {
        x = 0,
        y = 0,
        width = 150,
        height = 50,
        text = "VOLVER",
        hovered = false
    }
    
    backButton.x = love.graphics.getWidth()/2 - backButton.width/2
    backButton.y = love.graphics.getHeight()/2 + 260
end

function love.update(dt)
    crtTime = crtTime + dt
    
    if gameState == "menu" then
        -- Verificar hover del botón de inicio
        local mx, my = love.mouse.getPosition()
        startButton.hovered = mx >= startButton.x and mx <= startButton.x + startButton.width and
                              my >= startButton.y and my <= startButton.y + startButton.height
        
        -- Verificar hover del botón de configuración
        settingsButton.hovered = mx >= settingsButton.x and mx <= settingsButton.x + settingsButton.width and
                                 my >= settingsButton.y and my <= settingsButton.y + settingsButton.height
    
    elseif gameState == "settings" then
        -- Verificar hover del slider y botón de volver
        local mx, my = love.mouse.getPosition()
        
        -- Arrastrar slider de música
        if volumeSlider.dragging then
            local newValue = (mx - volumeSlider.x) / volumeSlider.width
            volumeSlider.value = math.max(0, math.min(1, newValue))
            if music then
                music:setVolume(volumeSlider.value)
            end
        end
        
        -- Arrastrar slider de disparos
        if shootSlider.dragging then
            local newValue = (mx - shootSlider.x) / shootSlider.width
            shootSlider.value = math.max(0, math.min(1, newValue))
            if sounds.shoot then sounds.shoot:setVolume(shootSlider.value) end
        end
        
        -- Arrastrar slider de explosiones
        if explosionSlider.dragging then
            local newValue = (mx - explosionSlider.x) / explosionSlider.width
            explosionSlider.value = math.max(0, math.min(1, newValue))
            if sounds.explosion then sounds.explosion:setVolume(explosionSlider.value) end
        end
        
        -- Hover del botón volver
        backButton.hovered = mx >= backButton.x and mx <= backButton.x + backButton.width and
                            my >= backButton.y and my <= backButton.y + backButton.height
    
    elseif gameState == "playing" then
        
        -- Actualizar jugador
        updatePlayer(dt)
        
        -- Spawn enemigos
        enemySpawnTimer = enemySpawnTimer + dt
        if enemySpawnTimer >= enemySpawnRate then
            enemySpawnTimer = 0
            spawnEnemy()
            -- Aumentar dificultad gradualmente
            enemySpawnRate = math.max(0.2, enemySpawnRate - 0.01)
        end
        
        -- Actualizar enemigos
        for i = #enemies, 1, -1 do
            updateEnemy(enemies[i], dt)
            
            -- Colisión con jugador
            if checkCollision(player, enemies[i]) then
                gameState = "gameover"
            end
            
            -- Eliminar enemigos muertos
            if enemies[i].dead then
                table.remove(enemies, i)
            end
        end
        
        -- Disparar automáticamente
        shootTimer = shootTimer + dt
        if shootTimer >= shootRate then
            shootTimer = 0
            local mouseX, mouseY = love.mouse.getPosition()
            shootBullet(player.x + player.size/2, player.y + player.size/2, mouseX, mouseY)
            
            -- Reproducir sonido de disparo
            if sounds.shoot then
                sounds.shoot:stop() -- Detener si ya está sonando
                sounds.shoot:play()
            end
        end
        
        -- Actualizar balas
        for i = #bullets, 1, -1 do
            updateBullet(bullets[i], dt)
            
            -- Colisión con enemigos
            for j = #enemies, 1, -1 do
                if not enemies[j].dead and checkCollision(bullets[i], enemies[j]) then
                    enemies[j].health = enemies[j].health - 1
                    bullets[i].dead = true
                    
                    if enemies[j].health <= 0 then
                        enemies[j].dead = true
                        score = score + 10
                        createExplosion(enemies[j].x + enemies[j].size/2, 
                                      enemies[j].y + enemies[j].size/2, 15)
                        
                        -- Reproducir sonido de explosión
                        if sounds.explosion then
                            -- Clonar el sonido para que múltiples explosiones suenen simultáneamente
                            sounds.explosion:clone():play()
                        end
                    else
                        createExplosion(bullets[i].x, bullets[i].y, 5)
                    end
                    break
                end
            end
            
            if bullets[i].dead then
                table.remove(bullets, i)
            end
        end
        
        -- Actualizar partículas
        updateParticles(dt)
    end
end

function love.draw()
    love.graphics.setCanvas(canvas)
    love.graphics.clear()
    
    if gameState == "menu" then
        drawMenu()
    elseif gameState == "settings" then
        drawSettings()
    elseif gameState == "playing" then
        drawGame()
    elseif gameState == "gameover" then
        drawGameOver()
    end
    
    love.graphics.setCanvas()
    
    -- Aplicar shader CRT
    if crtShader then
        crtShader:send("time", crtTime)
        love.graphics.setShader(crtShader)
    end
    
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(canvas, 0, 0)
    love.graphics.setShader()
end

function drawMenu()
    local width = love.graphics.getWidth()
    local height = love.graphics.getHeight()
    
    -- Fondo oscuro con grid
    love.graphics.setColor(0.05, 0.05, 0.1)
    love.graphics.rectangle("fill", 0, 0, width, height)
    
    -- Grid animado
    love.graphics.setColor(0.1, 0.1, 0.15, 0.3)
    local offset = (crtTime * 20) % 50
    for x = -50 + offset, width, 50 do
        love.graphics.line(x, 0, x, height)
    end
    for y = -50 + offset, height, 50 do
        love.graphics.line(0, y, width, y)
    end
    
    -- Título principal
    love.graphics.setFont(titleFont)
    love.graphics.setColor(1, 0.3, 0.5)
    local title = "SUSHI SURVIVORS"
    local titleWidth = titleFont:getWidth(title)
    
    -- Sombra del título
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.print(title, width/2 - titleWidth/2 + 3, height/2 - 120 + 3)
    
    -- Título con efecto de parpadeo
    local flicker = 0.9 + 0.1 * math.sin(crtTime * 3)
    love.graphics.setColor(1 * flicker, 0.3 * flicker, 0.5 * flicker)
    love.graphics.print(title, width/2 - titleWidth/2, height/2 - 120)
    
    -- Emoji de sushi
    love.graphics.setFont(catFont)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("🍣", width/2 - 60, height/2 - 60)
    love.graphics.print("🐱", width/2 + 20, height/2 - 60)
    
    -- Subtítulo
    love.graphics.setFont(subtitleFont)
    love.graphics.setColor(0.7, 0.7, 0.7)
    local subtitle = "Sobrevive a la invasión de cubos rojos"
    local subtitleWidth = subtitleFont:getWidth(subtitle)
    love.graphics.print(subtitle, width/2 - subtitleWidth/2, height/2 - 10)
    
    -- Botón de inicio
    if startButton.hovered then
        love.graphics.setColor(1, 0.4, 0.6, 0.9)
    else
        love.graphics.setColor(0.8, 0.2, 0.4, 0.7)
    end
    love.graphics.rectangle("fill", startButton.x, startButton.y, startButton.width, startButton.height)
    
    -- Borde del botón inicio
    if startButton.hovered then
        love.graphics.setColor(1, 0.6, 0.8)
        love.graphics.setLineWidth(3)
    else
        love.graphics.setColor(1, 0.3, 0.5)
        love.graphics.setLineWidth(2)
    end
    love.graphics.rectangle("line", startButton.x, startButton.y, startButton.width, startButton.height)
    love.graphics.setLineWidth(1)
    
    -- Texto del botón inicio
    love.graphics.setFont(subtitleFont)
    love.graphics.setColor(1, 1, 1)
    local btnTextWidth = subtitleFont:getWidth(startButton.text)
    love.graphics.print(startButton.text, 
                       startButton.x + startButton.width/2 - btnTextWidth/2, 
                       startButton.y + startButton.height/2 - subtitleFont:getHeight()/2)
    
    -- Botón de configuración
    if settingsButton.hovered then
        love.graphics.setColor(0.4, 0.6, 1, 0.9)
    else
        love.graphics.setColor(0.2, 0.4, 0.8, 0.7)
    end
    love.graphics.rectangle("fill", settingsButton.x, settingsButton.y, settingsButton.width, settingsButton.height)
    
    -- Borde del botón configuración
    if settingsButton.hovered then
        love.graphics.setColor(0.6, 0.8, 1)
        love.graphics.setLineWidth(3)
    else
        love.graphics.setColor(0.3, 0.5, 1)
        love.graphics.setLineWidth(2)
    end
    love.graphics.rectangle("line", settingsButton.x, settingsButton.y, settingsButton.width, settingsButton.height)
    love.graphics.setLineWidth(1)
    
    -- Texto del botón configuración
    love.graphics.setFont(uiFont)
    love.graphics.setColor(1, 1, 1)
    btnTextWidth = uiFont:getWidth(settingsButton.text)
    love.graphics.print(settingsButton.text, 
                       settingsButton.x + settingsButton.width/2 - btnTextWidth/2, 
                       settingsButton.y + settingsButton.height/2 - uiFont:getHeight()/2)
    
    -- Instrucciones
    love.graphics.setFont(uiFont)
    love.graphics.setColor(0.5, 0.5, 0.5)
    local instructions = "Click para comenzar tu aventura"
    local instWidth = uiFont:getWidth(instructions)
    love.graphics.print(instructions, width/2 - instWidth/2, height - 50)
end

function drawSettings()
    local width = love.graphics.getWidth()
    local height = love.graphics.getHeight()
    
    -- Fondo oscuro con grid
    love.graphics.setColor(0.05, 0.05, 0.1)
    love.graphics.rectangle("fill", 0, 0, width, height)
    
    -- Grid
    love.graphics.setColor(0.1, 0.1, 0.15, 0.3)
    local offset = (crtTime * 20) % 50
    for x = -50 + offset, width, 50 do
        love.graphics.line(x, 0, x, height)
    end
    for y = -50 + offset, height, 50 do
        love.graphics.line(0, y, width, y)
    end
    
    -- Panel central (más grande)
    love.graphics.setColor(0.1, 0.1, 0.15, 0.9)
    love.graphics.rectangle("fill", width/2 - 300, height/2 - 250, 600, 550)
    love.graphics.setColor(0.4, 0.6, 1)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", width/2 - 300, height/2 - 250, 600, 550)
    love.graphics.setLineWidth(1)
    
    -- Título
    love.graphics.setFont(titleFont)
    love.graphics.setColor(0.6, 0.8, 1)
    local title = "CONFIGURACIÓN"
    local titleWidth = titleFont:getWidth(title)
    love.graphics.print(title, width/2 - titleWidth/2, height/2 - 200, 0, 0.7, 0.7)
    
    -- Sección de volumen
    love.graphics.setFont(subtitleFont)
    love.graphics.setColor(1, 1, 1)
    local volumeText = "VOLUMEN DE MÚSICA"
    local volumeTextWidth = subtitleFont:getWidth(volumeText)
    love.graphics.print(volumeText, width/2 - volumeTextWidth/2, height/2 - 50)
    
    -- Slider de volumen - Fondo
    love.graphics.setColor(0.2, 0.2, 0.25)
    love.graphics.rectangle("fill", volumeSlider.x, volumeSlider.y, volumeSlider.width, volumeSlider.height)
    
    -- Slider - Barra llena
    love.graphics.setColor(0.4, 0.6, 1)
    love.graphics.rectangle("fill", volumeSlider.x, volumeSlider.y, 
                           volumeSlider.width * volumeSlider.value, volumeSlider.height)
    
    -- Slider - Borde
    love.graphics.setColor(0.6, 0.8, 1)
    love.graphics.rectangle("line", volumeSlider.x, volumeSlider.y, volumeSlider.width, volumeSlider.height)
    
    -- Slider - Handle (círculo)
    local handleX = volumeSlider.x + volumeSlider.width * volumeSlider.value
    love.graphics.setColor(1, 1, 1)
    love.graphics.circle("fill", handleX, volumeSlider.y + volumeSlider.height/2, 12)
    love.graphics.setColor(0.6, 0.8, 1)
    love.graphics.circle("line", handleX, volumeSlider.y + volumeSlider.height/2, 12)
    
    -- Porcentaje de volumen
    love.graphics.setFont(uiFont)
    love.graphics.setColor(0.2, 1, 0.3)
    local percentText = math.floor(volumeSlider.value * 100) .. "%"
    local percentWidth = uiFont:getWidth(percentText)
    love.graphics.print(percentText, width/2 - percentWidth/2, volumeSlider.y + 35)
    
    -- Sección de disparos
    love.graphics.setFont(subtitleFont)
    love.graphics.setColor(1, 1, 1)
    local shootText = "VOLUMEN DISPAROS"
    local shootTextWidth = subtitleFont:getWidth(shootText)
    love.graphics.print(shootText, width/2 - shootTextWidth/2, shootSlider.y - 35)
    
    -- Slider de disparos - Fondo
    love.graphics.setColor(0.2, 0.2, 0.25)
    love.graphics.rectangle("fill", shootSlider.x, shootSlider.y, shootSlider.width, shootSlider.height)
    
    -- Slider - Barra llena
    love.graphics.setColor(1, 0.8, 0.2)
    love.graphics.rectangle("fill", shootSlider.x, shootSlider.y, 
                           shootSlider.width * shootSlider.value, shootSlider.height)
    
    -- Slider - Borde
    love.graphics.setColor(1, 0.9, 0.4)
    love.graphics.rectangle("line", shootSlider.x, shootSlider.y, shootSlider.width, shootSlider.height)
    
    -- Slider - Handle (círculo)
    local handleX2 = shootSlider.x + shootSlider.width * shootSlider.value
    love.graphics.setColor(1, 1, 1)
    love.graphics.circle("fill", handleX2, shootSlider.y + shootSlider.height/2, 12)
    love.graphics.setColor(1, 0.9, 0.4)
    love.graphics.circle("line", handleX2, shootSlider.y + shootSlider.height/2, 12)
    
    -- Porcentaje de volumen disparos
    love.graphics.setFont(uiFont)
    love.graphics.setColor(1, 0.8, 0.2)
    percentText = math.floor(shootSlider.value * 100) .. "%"
    percentWidth = uiFont:getWidth(percentText)
    love.graphics.print(percentText, width/2 - percentWidth/2, shootSlider.y + 35)
    
    -- Sección de explosiones
    love.graphics.setFont(subtitleFont)
    love.graphics.setColor(1, 1, 1)
    local explosionText = "VOLUMEN EXPLOSIONES"
    local explosionTextWidth = subtitleFont:getWidth(explosionText)
    love.graphics.print(explosionText, width/2 - explosionTextWidth/2, explosionSlider.y - 35)
    
    -- Slider de explosiones - Fondo
    love.graphics.setColor(0.2, 0.2, 0.25)
    love.graphics.rectangle("fill", explosionSlider.x, explosionSlider.y, explosionSlider.width, explosionSlider.height)
    
    -- Slider - Barra llena
    love.graphics.setColor(1, 0.3, 0.2)
    love.graphics.rectangle("fill", explosionSlider.x, explosionSlider.y, 
                           explosionSlider.width * explosionSlider.value, explosionSlider.height)
    
    -- Slider - Borde
    love.graphics.setColor(1, 0.5, 0.4)
    love.graphics.rectangle("line", explosionSlider.x, explosionSlider.y, explosionSlider.width, explosionSlider.height)
    
    -- Slider - Handle (círculo)
    local handleX3 = explosionSlider.x + explosionSlider.width * explosionSlider.value
    love.graphics.setColor(1, 1, 1)
    love.graphics.circle("fill", handleX3, explosionSlider.y + explosionSlider.height/2, 12)
    love.graphics.setColor(1, 0.5, 0.4)
    love.graphics.circle("line", handleX3, explosionSlider.y + explosionSlider.height/2, 12)
    
    -- Porcentaje de volumen explosiones
    love.graphics.setFont(uiFont)
    love.graphics.setColor(1, 0.3, 0.2)
    percentText = math.floor(explosionSlider.value * 100) .. "%"
    percentWidth = uiFont:getWidth(percentText)
    love.graphics.print(percentText, width/2 - percentWidth/2, explosionSlider.y + 35)
    
    -- Estado de la música
    if music and musicPlaying then
        love.graphics.setColor(0.3, 1, 0.3)
        love.graphics.print("♪ Música reproduciéndose", width/2 - 90, height/2 - 130)
    elseif music then
        love.graphics.setColor(1, 0.5, 0.3)
        love.graphics.print("♪ Música en pausa", width/2 - 70, height/2 - 130)
    else
        love.graphics.setColor(1, 0.3, 0.3)
        love.graphics.print("⚠ No se pudo cargar la música", width/2 - 110, height/2 - 130)
    end
    
    -- Botón de volver
    if backButton.hovered then
        love.graphics.setColor(1, 0.4, 0.6, 0.9)
    else
        love.graphics.setColor(0.8, 0.2, 0.4, 0.7)
    end
    love.graphics.rectangle("fill", backButton.x, backButton.y, backButton.width, backButton.height)
    
    if backButton.hovered then
        love.graphics.setColor(1, 0.6, 0.8)
        love.graphics.setLineWidth(3)
    else
        love.graphics.setColor(1, 0.3, 0.5)
        love.graphics.setLineWidth(2)
    end
    love.graphics.rectangle("line", backButton.x, backButton.y, backButton.width, backButton.height)
    love.graphics.setLineWidth(1)
    
    love.graphics.setFont(subtitleFont)
    love.graphics.setColor(1, 1, 1)
    local backTextWidth = subtitleFont:getWidth(backButton.text)
    love.graphics.print(backButton.text, 
                       backButton.x + backButton.width/2 - backTextWidth/2, 
                       backButton.y + backButton.height/2 - subtitleFont:getHeight()/2)
end

function drawGame()
    love.mouse.setVisible(false)
    -- Fondo con grid
    love.graphics.setColor(0.05, 0.05, 0.1)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
    
    -- Grid
    love.graphics.setColor(0.1, 0.1, 0.15, 0.5)
    for x = 0, love.graphics.getWidth(), 50 do
        love.graphics.line(x, 0, x, love.graphics.getHeight())
    end
    for y = 0, love.graphics.getHeight(), 50 do
        love.graphics.line(0, y, love.graphics.getWidth(), y)
    end
    
    -- Partículas (fondo)
    drawParticles()
    
    -- Enemigos
    for _, enemy in ipairs(enemies) do
        drawEnemy(enemy)
    end
    
    -- Balas
    for _, bullet in ipairs(bullets) do
        drawBullet(bullet)
    end
    
    -- Jugador
    drawPlayer()
    
    -- Cursor personalizado
    local mx, my = love.mouse.getPosition()
    love.graphics.setColor(1, 0, 0)
    love.graphics.circle("line", mx, my, 8, 16)
    love.graphics.line(mx - 12, my, mx - 5, my)
    love.graphics.line(mx + 12, my, mx + 5, my)
    love.graphics.line(mx, my - 12, mx, my - 5)
    love.graphics.line(mx, my + 12, mx, my + 5)
    
    -- UI
    love.graphics.setFont(uiFont)
    love.graphics.setColor(0.2, 1, 0.3)
    love.graphics.print("PUNTOS: " .. score, 10, 10, 0, 1.5, 1.5)
    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.print("WASD: Mover | Mouse: Apuntar", 10, 40)
    love.graphics.setColor(1, 0.3, 0.3)
    love.graphics.print("Enemigos: " .. #enemies, 10, 60)
end

function drawGameOver()
    -- Fondo oscuro
    love.graphics.setColor(0.05, 0.05, 0.1)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
    
    local width = love.graphics.getWidth()
    local height = love.graphics.getHeight()
    
    -- Panel central
    love.graphics.setColor(0.1, 0.1, 0.15, 0.9)
    love.graphics.rectangle("fill", width/2 - 250, height/2 - 150, 500, 300)
    love.graphics.setColor(1, 0.2, 0.2)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", width/2 - 250, height/2 - 150, 500, 300)
    love.graphics.setLineWidth(1)
    
    -- Texto GAME OVER
    love.graphics.setFont(titleFont)
    love.graphics.setColor(1, 0.2, 0.2)
    local text = "GAME OVER"
    local textWidth = titleFont:getWidth(text)
    love.graphics.print(text, width/2 - textWidth/2, height/2 - 100)
    
    -- Puntuación
    love.graphics.setFont(subtitleFont)
    love.graphics.setColor(0.2, 1, 0.3)
    text = "PUNTUACIÓN FINAL: " .. score
    textWidth = subtitleFont:getWidth(text)
    love.graphics.print(text, width/2 - textWidth/2, height/2 - 20)
    
    -- Instrucciones
    love.graphics.setFont(uiFont)
    love.graphics.setColor(0.7, 0.7, 0.7)
    text = "Presiona R para reiniciar"
    textWidth = uiFont:getWidth(text)
    love.graphics.print(text, width/2 - textWidth/2, height/2 + 50)
    
    text = "Presiona ESC para salir"
    textWidth = uiFont:getWidth(text)
    love.graphics.print(text, width/2 - textWidth/2, height/2 + 75)
end

function love.keypressed(key)
    if key == "escape" then
        if gameState == "menu" then
            love.event.quit()
        else
            gameState = "menu"
            love.mouse.setVisible(true)
        end
    end
    
    if key == "r" then
        if gameState == "gameover" then
            startGame()
        end
    end
    
    -- Toggle música con M
    if key == "m" and music then
        if musicPlaying then
            music:pause()
            musicPlaying = false
        else
            music:play()
            musicPlaying = true
        end
    end
end

function love.mousepressed(x, y, button)
    if button == 1 then -- Click izquierdo
        if gameState == "menu" then
            -- Verificar click directo en los botones (sin depender de hover)
            if x >= startButton.x and x <= startButton.x + startButton.width and
               y >= startButton.y and y <= startButton.y + startButton.height then
                startGame()
            end
            
            if x >= settingsButton.x and x <= settingsButton.x + settingsButton.width and
               y >= settingsButton.y and y <= settingsButton.y + settingsButton.height then
                gameState = "settings"
            end
            
        elseif gameState == "settings" then
            -- Verificar click en slider de música
            if y >= volumeSlider.y and y <= volumeSlider.y + volumeSlider.height and
               x >= volumeSlider.x and x <= volumeSlider.x + volumeSlider.width then
                volumeSlider.dragging = true
                local newValue = (x - volumeSlider.x) / volumeSlider.width
                volumeSlider.value = math.max(0, math.min(1, newValue))
                if music then
                    music:setVolume(volumeSlider.value)
                end
            end
            
            -- Verificar click en slider de disparos
            if y >= shootSlider.y and y <= shootSlider.y + shootSlider.height and
               x >= shootSlider.x and x <= shootSlider.x + shootSlider.width then
                shootSlider.dragging = true
                local newValue = (x - shootSlider.x) / shootSlider.width
                shootSlider.value = math.max(0, math.min(1, newValue))
                if sounds.shoot then 
                    sounds.shoot:setVolume(shootSlider.value)
                    -- Reproducir sonido de prueba
                    sounds.shoot:clone():play()
                end
            end
            
            -- Verificar click en slider de explosiones
            if y >= explosionSlider.y and y <= explosionSlider.y + explosionSlider.height and
               x >= explosionSlider.x and x <= explosionSlider.x + explosionSlider.width then
                explosionSlider.dragging = true
                local newValue = (x - explosionSlider.x) / explosionSlider.width
                explosionSlider.value = math.max(0, math.min(1, newValue))
                if sounds.explosion then 
                    sounds.explosion:setVolume(explosionSlider.value)
                    -- Reproducir sonido de prueba
                    sounds.explosion:clone():play()
                end
            end
            
            -- Click en botón volver (verificación directa)
            if x >= backButton.x and x <= backButton.x + backButton.width and
               y >= backButton.y and y <= backButton.y + backButton.height then
                gameState = "menu"
            end
        end
    end
end

function love.mousereleased(x, y, button)
    if button == 1 then
        volumeSlider.dragging = false
        shootSlider.dragging = false
        explosionSlider.dragging = false
    end
end

function startGame()
    gameState = "playing"
    score = 0
    enemies = {}
    bullets = {}
    particles = {}
    enemySpawnTimer = 0
    enemySpawnRate = 1.0
    shootTimer = 0
    initPlayer()
    love.mouse.setVisible(false)
end

-- ========================================
-- player.lua (integrado)
-- ========================================

function initPlayer()
    player = {
        x = love.graphics.getWidth() / 2,
        y = love.graphics.getHeight() / 2,
        size = 40,
        speed = 250
    }
end

function updatePlayer(dt)
    local dx, dy = 0, 0
    
    if love.keyboard.isDown("w") or love.keyboard.isDown("up") then
        dy = dy - 1
    end
    if love.keyboard.isDown("s") or love.keyboard.isDown("down") then
        dy = dy + 1
    end
    if love.keyboard.isDown("a") or love.keyboard.isDown("left") then
        dx = dx - 1
    end
    if love.keyboard.isDown("d") or love.keyboard.isDown("right") then
        dx = dx + 1
    end
    
    -- Normalizar diagonal
    local length = math.sqrt(dx * dx + dy * dy)
    if length > 0 then
        dx = dx / length
        dy = dy / length
    end
    
    player.x = player.x + dx * player.speed * dt
    player.y = player.y + dy * player.speed * dt
    
    -- Límites del mapa
    player.x = math.max(0, math.min(player.x, love.graphics.getWidth() - player.size))
    player.y = math.max(0, math.min(player.y, love.graphics.getHeight() - player.size))
end

function drawPlayer()
    love.graphics.setColor(1, 1, 1)
    
    local mouseX = love.mouse.getX()
    local facingLeft = mouseX < player.x + player.size/2
    
    if sprites.player then
        -- Si tenemos sprite, dibujarlo
        local scaleX = player.size / sprites.player:getWidth()
        local scaleY = player.size / sprites.player:getHeight()
        
        if facingLeft then
            -- Voltear horizontalmente
            love.graphics.draw(sprites.player, 
                player.x + player.size/2, 
                player.y + player.size/2, 
                0, -scaleX, scaleY, 
                sprites.player:getWidth()/2, 
                sprites.player:getHeight()/2)
        else
            love.graphics.draw(sprites.player, 
                player.x + player.size/2, 
                player.y + player.size/2, 
                0, scaleX, scaleY, 
                sprites.player:getWidth()/2, 
                sprites.player:getHeight()/2)
        end
    else
        -- Si no hay sprite, dibujar un gatito con formas geométricas
        love.graphics.push()
        love.graphics.translate(player.x + player.size/2, player.y + player.size/2)
        
        -- Voltear si mira a la izquierda
        if facingLeft then
            love.graphics.scale(-1, 1)
        end
        
        -- Cuerpo (naranja)
        love.graphics.setColor(1, 0.6, 0.2)
        love.graphics.ellipse("fill", 0, 0, player.size/2.5, player.size/2.5)
        
        -- Cabeza
        love.graphics.circle("fill", -5, -8, player.size/4)
        
        -- Orejas
        love.graphics.setColor(1, 0.5, 0.1)
        love.graphics.polygon("fill", -10, -15, -5, -10, -8, -18)
        love.graphics.polygon("fill", 0, -15, -5, -10, -2, -18)
        
        -- Ojos
        love.graphics.setColor(0, 0, 0)
        love.graphics.circle("fill", -8, -10, 2)
        love.graphics.circle("fill", -2, -10, 2)
        
        -- Brillo en los ojos
        love.graphics.setColor(1, 1, 1)
        love.graphics.circle("fill", -7.5, -10.5, 1)
        love.graphics.circle("fill", -1.5, -10.5, 1)
        
        -- Nariz
        love.graphics.setColor(1, 0.4, 0.4)
        love.graphics.circle("fill", -5, -7, 1.5)
        
        -- Bigotes
        love.graphics.setColor(0, 0, 0)
        love.graphics.setLineWidth(1)
        love.graphics.line(-12, -8, -18, -9)
        love.graphics.line(-12, -6, -18, -6)
        love.graphics.line(2, -8, 8, -9)
        love.graphics.line(2, -6, 8, -6)
        
        -- Cola
        love.graphics.setColor(1, 0.6, 0.2)
        love.graphics.setLineWidth(3)
        love.graphics.arc("line", "open", 10, 5, 8, -math.pi/4, math.pi/4)
        
        love.graphics.pop()
    end
end

-- ========================================
-- enemy.lua (integrado)
-- ========================================

function spawnEnemy()
    local enemy = {
        x = 0,
        y = 0,
        size = 30,
        speed = 80 + math.random(40),
        health = 2,
        dead = false
    }
    
    -- Spawn desde un lado aleatorio
    local side = math.random(4)
    if side == 1 then -- Arriba
        enemy.x = math.random(0, love.graphics.getWidth())
        enemy.y = -enemy.size
    elseif side == 2 then -- Derecha
        enemy.x = love.graphics.getWidth()
        enemy.y = math.random(0, love.graphics.getHeight())
    elseif side == 3 then -- Abajo
        enemy.x = math.random(0, love.graphics.getWidth())
        enemy.y = love.graphics.getHeight()
    else -- Izquierda
        enemy.x = -enemy.size
        enemy.y = math.random(0, love.graphics.getHeight())
    end
    
    table.insert(enemies, enemy)
end

function updateEnemy(enemy, dt)
    -- Perseguir al jugador
    local dx = (player.x + player.size/2) - (enemy.x + enemy.size/2)
    local dy = (player.y + player.size/2) - (enemy.y + enemy.size/2)
    local length = math.sqrt(dx * dx + dy * dy)
    
    if length > 0 then
        dx = dx / length
        dy = dy / length
    end
    
    enemy.x = enemy.x + dx * enemy.speed * dt
    enemy.y = enemy.y + dy * enemy.speed * dt
end

function drawEnemy(enemy)
    if sprites.enemy then
        -- Si tenemos sprite de enemigo
        love.graphics.setColor(1, 1, 1)
        local scaleX = enemy.size / sprites.enemy:getWidth()
        local scaleY = enemy.size / sprites.enemy:getHeight()
        
        love.graphics.draw(sprites.enemy, 
            enemy.x + enemy.size/2, 
            enemy.y + enemy.size/2, 
            0, scaleX, scaleY, 
            sprites.enemy:getWidth()/2, 
            sprites.enemy:getHeight()/2)
    else
        -- Dibujar enemigo con formas
        love.graphics.setColor(0.8, 0.1, 0.1)
        love.graphics.rectangle("fill", enemy.x, enemy.y, enemy.size, enemy.size)
        
        love.graphics.setColor(1, 0.3, 0.3, 0.5)
        love.graphics.rectangle("fill", enemy.x + 3, enemy.y + 3, enemy.size - 6, enemy.size - 6)
        
        love.graphics.setColor(1, 0.2, 0.2)
        love.graphics.rectangle("line", enemy.x, enemy.y, enemy.size, enemy.size)
    end
end

-- ========================================
-- bullet.lua (integrado)
-- ========================================

function shootBullet(x, y, targetX, targetY)
    local dx = targetX - x
    local dy = targetY - y
    local length = math.sqrt(dx * dx + dy * dy)
    
    if length > 0 then
        dx = dx / length
        dy = dy / length
    end
    
    table.insert(bullets, {
        x = x,
        y = y,
        vx = dx * 500,
        vy = dy * 500,
        size = 8,
        dead = false
    })
end

function updateBullet(bullet, dt)
    bullet.x = bullet.x + bullet.vx * dt
    bullet.y = bullet.y + bullet.vy * dt
    
    -- Eliminar si sale de la pantalla
    if bullet.x < -50 or bullet.x > love.graphics.getWidth() + 50 or
       bullet.y < -50 or bullet.y > love.graphics.getHeight() + 50 then
        bullet.dead = true
    end
end

function drawBullet(bullet)
    love.graphics.setColor(1, 1, 0)
    love.graphics.circle("fill", bullet.x, bullet.y, bullet.size)
    love.graphics.setColor(1, 1, 0.5, 0.5)
    love.graphics.circle("fill", bullet.x, bullet.y, bullet.size - 2)
end

-- ========================================
-- particle.lua (integrado)
-- ========================================

function createExplosion(x, y, count)
    for i = 1, count do
        local angle = math.random() * math.pi * 2
        local speed = 50 + math.random() * 150
        table.insert(particles, {
            x = x,
            y = y,
            vx = math.cos(angle) * speed,
            vy = math.sin(angle) * speed,
            size = 2 + math.random() * 4,
            life = 0.5 + math.random() * 0.5,
            maxLife = 1.0,
            alpha = 1.0,
            r = 0.8 + math.random() * 0.2,
            g = 0.2 + math.random() * 0.3,
            b = 0.1
        })
    end
end

function updateParticles(dt)
    for i = #particles, 1, -1 do
        local p = particles[i]
        p.x = p.x + p.vx * dt
        p.y = p.y + p.vy * dt
        p.vy = p.vy + 200 * dt -- Gravedad leve
        p.life = p.life - dt
        p.alpha = p.life / p.maxLife
        
        if p.life <= 0 then
            table.remove(particles, i)
        end
    end
end

function drawParticles()
    for _, p in ipairs(particles) do
        love.graphics.setColor(p.r, p.g, p.b, p.alpha)
        love.graphics.rectangle("fill", p.x, p.y, p.size, p.size)
    end
end

-- ========================================
-- utils.lua (integrado)
-- ========================================

function checkCollision(a, b)
    local aSize = a.size or a.width or 0
    local bSize = b.size or b.width or 0
    
    return a.x < b.x + bSize and
           a.x + aSize > b.x and
           a.y < b.y + bSize and
           a.y + aSize > b.y
end