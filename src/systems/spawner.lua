--[[
    spawner.lua - Enemy Spawner System
    
    Controla la generación de enemigos:
    - Spawn desde los 4 bordes de la pantalla
    - Rate que aumenta gradualmente
    - Respeta el máximo de enemigos activos
]]

local Constants = require("src.core.constants")

local Spawner = {}
Spawner.__index = Spawner

--[[
    Constructor
    
    @param enemyPool - Pool de enemigos
    @return Spawner instance
]]
function Spawner:new(enemyPool)
    local spawner = setmetatable({}, Spawner)
    
    spawner.enemyPool = enemyPool
    spawner.spawnRate = Constants.SPAWN_RATE_INITIAL
    spawner.spawnTimer = 0
    
    return spawner
end

--[[
    Resetear al estado inicial
]]
function Spawner:reset()
    self.spawnRate = Constants.SPAWN_RATE_INITIAL
    self.spawnTimer = 0
end

--[[
    Update loop
    
    @param dt - Delta time
    @return number - Cantidad de enemigos spawneados este frame
]]
function Spawner:update(dt)
    self.spawnTimer = self.spawnTimer + dt
    
    local spawned = 0
    
    while self.spawnTimer >= self.spawnRate do
        self.spawnTimer = self.spawnTimer - self.spawnRate
        
        if self:spawnEnemy() then
            spawned = spawned + 1
        end
        
        -- Reducir rate gradualmente
        self.spawnRate = math.max(
            Constants.SPAWN_RATE_MIN,
            self.spawnRate * Constants.SPAWN_RATE_DECAY
        )
    end
    
    return spawned
end

--[[
    Spawn un enemigo desde un borde aleatorio
    
    @return boolean - true si se spawneó, false si pool lleno
]]
function Spawner:spawnEnemy()
    local enemy = self.enemyPool:get()
    
    if not enemy then
        return false    -- Pool agotado
    end
    
    local x, y = self:getSpawnPosition()
    enemy:activate(x, y)
    
    return true
end

--[[
    Calcular posición de spawn desde un borde aleatorio
    
    @return x, y
]]
function Spawner:getSpawnPosition()
    local margin = Constants.ENEMY_SPAWN_MARGIN
    local width = Constants.WINDOW_WIDTH
    local height = Constants.WINDOW_HEIGHT
    
    -- Elegir borde: 1=arriba, 2=abajo, 3=izquierda, 4=derecha
    local edge = love.math.random(1, 4)
    
    local x, y
    
    if edge == 1 then
        -- Arriba
        x = love.math.random(0, width)
        y = -margin
    elseif edge == 2 then
        -- Abajo
        x = love.math.random(0, width)
        y = height + margin
    elseif edge == 3 then
        -- Izquierda
        x = -margin
        y = love.math.random(0, height)
    else
        -- Derecha
        x = width + margin
        y = love.math.random(0, height)
    end
    
    return x, y
end

--[[
    Obtener rate actual (para debug/UI)
    
    @return number - Segundos entre spawns
]]
function Spawner:getCurrentRate()
    return self.spawnRate
end

--[[
    Forzar spawn inmediato (para debug)
    
    @param count - Cantidad a spawnear
    @return number - Cantidad efectivamente spawneada
]]
function Spawner:forceSpawn(count)
    local spawned = 0
    
    for i = 1, count do
        if self:spawnEnemy() then
            spawned = spawned + 1
        end
    end
    
    return spawned
end

--[[
    Dibujar puntos de spawn (debug)
]]
function Spawner:drawDebug()
    local margin = Constants.ENEMY_SPAWN_MARGIN
    local width = Constants.WINDOW_WIDTH
    local height = Constants.WINDOW_HEIGHT
    
    love.graphics.setColor(1, 0, 1, 0.5)
    
    -- Líneas de spawn zones
    -- Arriba
    love.graphics.line(0, -margin, width, -margin)
    -- Abajo
    love.graphics.line(0, height + margin, width, height + margin)
    -- Izquierda
    love.graphics.line(-margin, 0, -margin, height)
    -- Derecha
    love.graphics.line(width + margin, 0, width + margin, height)
    
    -- Indicadores en bordes de pantalla
    love.graphics.setColor(1, 0, 1, 0.3)
    
    -- Arriba
    love.graphics.rectangle("fill", 0, 0, width, 5)
    -- Abajo
    love.graphics.rectangle("fill", 0, height - 5, width, 5)
    -- Izquierda
    love.graphics.rectangle("fill", 0, 0, 5, height)
    -- Derecha
    love.graphics.rectangle("fill", width - 5, 0, 5, height)
    
    love.graphics.setColor(1, 1, 1, 1)
end

return Spawner
