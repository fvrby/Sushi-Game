--[[
    spatial_hash.lua - Spatial Hash Grid
    
    Patrón: Spatial Partitioning
    
    Problema que resuelve:
    Checkear colisión de cada bala contra cada enemigo es O(n²).
    Con 50 balas y 100 enemigos = 5000 checks por frame.
    
    Solución:
    Dividir el mundo en celdas. Insertar entidades en sus celdas.
    Solo checkear colisiones entre entidades en la misma celda o adyacentes.
    
    Resultado: O(n) en promedio para distribuciones uniformes.
    
    Uso:
        local SpatialHash = require("src.core.spatial_hash")
        
        local grid = SpatialHash:new(64)  -- Celdas de 64px
        
        -- Cada frame:
        grid:clear()
        
        for _, enemy in enemyPool:iterateActive() do
            grid:insert(enemy)
        end
        
        for _, bullet in bulletPool:iterateActive() do
            local nearby = grid:query(bullet)
            for _, enemy in ipairs(nearby) do
                if bullet:collidesWithAABB(enemy) then
                    -- Colisión!
                end
            end
        end
]]

local SpatialHash = {}
SpatialHash.__index = SpatialHash

--[[
    Constructor
    
    @param cellSize - Tamaño de cada celda en pixels
    @return SpatialHash instance
]]
function SpatialHash:new(cellSize)
    local hash = setmetatable({}, SpatialHash)
    
    hash.cellSize = cellSize or 64
    hash.cells = {}     -- Tabla de celdas, key = "x,y"
    
    return hash
end

--[[
    Limpiar todas las celdas
    
    Llamar al inicio de cada frame antes de insertar
]]
function SpatialHash:clear()
    -- Reusar tabla en lugar de crear nueva (evita GC)
    for key in pairs(self.cells) do
        self.cells[key] = nil
    end
end

--[[
    Obtener key de celda para una posición
    
    @param x, y - Posición en mundo
    @return string key "cellX,cellY"
]]
function SpatialHash:getKey(x, y)
    local cellX = math.floor(x / self.cellSize)
    local cellY = math.floor(y / self.cellSize)
    return cellX .. "," .. cellY
end

--[[
    Obtener coordenadas de celda
    
    @param x, y - Posición en mundo
    @return cellX, cellY
]]
function SpatialHash:getCellCoords(x, y)
    return math.floor(x / self.cellSize), math.floor(y / self.cellSize)
end

--[[
    Insertar entidad en el grid
    
    La entidad se inserta en todas las celdas que ocupa su bounding box.
    
    @param entity - Entidad con getBounds() o x, y, width, height
]]
function SpatialHash:insert(entity)
    local x, y, w, h
    
    if entity.getBounds then
        x, y, w, h = entity:getBounds()
    else
        x = entity.x
        y = entity.y
        w = entity.width or 0
        h = entity.height or 0
    end
    
    -- Calcular rango de celdas que ocupa
    local minCellX, minCellY = self:getCellCoords(x, y)
    local maxCellX, maxCellY = self:getCellCoords(x + w, y + h)
    
    -- Insertar en todas las celdas que toca
    for cellX = minCellX, maxCellX do
        for cellY = minCellY, maxCellY do
            local key = cellX .. "," .. cellY
            
            if not self.cells[key] then
                self.cells[key] = {}
            end
            
            table.insert(self.cells[key], entity)
        end
    end
end

--[[
    Query entidades cercanas a una posición/área
    
    @param entity - Entidad con getBounds() o x, y, width, height
    @return tabla de entidades en las mismas celdas (puede tener duplicados)
]]
function SpatialHash:query(entity)
    local results = {}
    local seen = {}     -- Para evitar duplicados
    
    local x, y, w, h
    
    if entity.getBounds then
        x, y, w, h = entity:getBounds()
    else
        x = entity.x
        y = entity.y
        w = entity.width or 0
        h = entity.height or 0
    end
    
    -- Calcular rango de celdas
    local minCellX, minCellY = self:getCellCoords(x, y)
    local maxCellX, maxCellY = self:getCellCoords(x + w, y + h)
    
    -- Recolectar entidades de todas las celdas
    for cellX = minCellX, maxCellX do
        for cellY = minCellY, maxCellY do
            local key = cellX .. "," .. cellY
            local cell = self.cells[key]
            
            if cell then
                for _, other in ipairs(cell) do
                    -- Evitar duplicados y auto-colisión
                    if other ~= entity and not seen[other] then
                        seen[other] = true
                        table.insert(results, other)
                    end
                end
            end
        end
    end
    
    return results
end

--[[
    Dibujar el grid (debug)
]]
function SpatialHash:drawDebug()
    love.graphics.setColor(0.3, 0.3, 0.3, 0.3)
    
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    
    -- Líneas verticales
    for x = 0, screenWidth, self.cellSize do
        love.graphics.line(x, 0, x, screenHeight)
    end
    
    -- Líneas horizontales
    for y = 0, screenHeight, self.cellSize do
        love.graphics.line(0, y, screenWidth, y)
    end
    
    -- Mostrar ocupación de celdas
    love.graphics.setColor(0, 1, 0, 0.2)
    for key, cell in pairs(self.cells) do
        local cellX, cellY = key:match("(-?%d+),(-?%d+)")
        cellX = tonumber(cellX)
        cellY = tonumber(cellY)
        
        local count = #cell
        if count > 0 then
            -- Más verde = más entidades
            love.graphics.setColor(0, 1, 0, math.min(0.1 * count, 0.5))
            love.graphics.rectangle(
                "fill",
                cellX * self.cellSize,
                cellY * self.cellSize,
                self.cellSize,
                self.cellSize
            )
        end
    end
    
    love.graphics.setColor(1, 1, 1, 1)
end

--[[
    Obtener estadísticas (debug)
    
    @return cellCount, maxEntitiesPerCell
]]
function SpatialHash:getStats()
    local cellCount = 0
    local maxEntities = 0
    
    for _, cell in pairs(self.cells) do
        cellCount = cellCount + 1
        maxEntities = math.max(maxEntities, #cell)
    end
    
    return cellCount, maxEntities
end

return SpatialHash
