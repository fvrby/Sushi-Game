--[[
    collision.lua - Collision Detection System
    
    Maneja todas las colisiones del juego:
    - Balas vs Enemigos
    - Jugador vs Enemigos
    
    Usa spatial hashing para optimizar detección.
    Genera callbacks para efectos (partículas, sonido, score).
]]

local SpatialHash = require("src.core.spatial_hash")
local Constants = require("src.core.constants")

local Collision = {}
Collision.__index = Collision

--[[
    Constructor
    
    @return Collision instance
]]
function Collision:new()
    local collision = setmetatable({}, Collision)
    
    collision.spatialHash = SpatialHash:new(Constants.SPATIAL_CELL_SIZE)
    
    -- Callbacks para eventos de colisión
    collision.onEnemyHit = nil      -- function(enemy, bullet)
    collision.onEnemyKilled = nil   -- function(enemy)
    collision.onPlayerHit = nil     -- function(enemy)
    
    return collision
end

--[[
    Procesar todas las colisiones del frame
    
    @param player       - Player entity
    @param bulletPool   - Pool de balas
    @param enemyPool    - Pool de enemigos
    
    @return hits, kills - Cantidad de impactos y muertes
]]
function Collision:update(player, bulletPool, enemyPool)
    local hits = 0
    local kills = 0
    
    -- Limpiar y poblar spatial hash con enemigos
    self.spatialHash:clear()
    
    for _, enemy in enemyPool:iterateActive() do
        self.spatialHash:insert(enemy)
    end
    
    -- Checkear balas vs enemigos
    local bulletsToRelease = {}
    local enemiesToRelease = {}
    
    for _, bullet in bulletPool:iterateActive() do
        local nearby = self.spatialHash:query(bullet)
        
        for _, enemy in ipairs(nearby) do
            if enemy.active and bullet:collidesWithAABB(enemy) then
                -- Impacto!
                local killed = enemy:takeDamage(bullet.damage)
                hits = hits + 1
                
                -- Marcar bala para release
                bulletsToRelease[bullet] = true
                
                -- Callback de hit
                if self.onEnemyHit then
                    self.onEnemyHit(enemy, bullet)
                end
                
                if killed then
                    kills = kills + 1
                    enemiesToRelease[enemy] = true
                    
                    -- Callback de kill
                    if self.onEnemyKilled then
                        self.onEnemyKilled(enemy)
                    end
                end
                
                -- Una bala solo impacta un enemigo
                break
            end
        end
    end
    
    -- Checkear jugador vs enemigos
    if player.alive then
        local playerBounds = {player:getBounds()}
        
        for _, enemy in enemyPool:iterateActive() do
            if enemy.active and self:checkAABB(playerBounds, {enemy:getBounds()}) then
                -- Jugador golpeado!
                if self.onPlayerHit then
                    self.onPlayerHit(enemy)
                end
                break   -- Solo procesar un hit
            end
        end
    end
    
    -- Liberar entidades marcadas
    for bullet in pairs(bulletsToRelease) do
        bulletPool:release(bullet)
    end
    
    for enemy in pairs(enemiesToRelease) do
        enemyPool:release(enemy)
    end
    
    return hits, kills
end

--[[
    Check AABB collision entre dos bounds
    
    @param a - {x, y, w, h}
    @param b - {x, y, w, h}
    @return boolean
]]
function Collision:checkAABB(a, b)
    return a[1] < b[1] + b[3] and
           a[1] + a[3] > b[1] and
           a[2] < b[2] + b[4] and
           a[2] + a[4] > b[2]
end

--[[
    Dibujar debug del spatial hash
]]
function Collision:drawDebug()
    self.spatialHash:drawDebug()
end

--[[
    Obtener estadísticas
    
    @return cellCount, maxEntitiesPerCell
]]
function Collision:getStats()
    return self.spatialHash:getStats()
end

return Collision
