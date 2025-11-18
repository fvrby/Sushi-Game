--[[
    pool.lua - Generic Object Pool
    
    Patrón: Object Pool
    
    Problema que resuelve:
    En Lua, crear objetos con {} y descartarlos genera presión en el GC.
    Cuando muchas entidades mueren por frame (balas, partículas), el GC
    puede causar micro-stuttering.
    
    Solución:
    Pre-crear todos los objetos al inicio. Cuando necesitas uno, lo "activas"
    del pool. Cuando ya no lo necesitas, lo "devuelves" al pool.
    
    Uso:
        local Pool = require("src.core.pool")
        
        -- Crear pool de 100 enemigos
        local enemyPool = Pool:new(Enemy, 100)
        
        -- Obtener enemigo del pool
        local enemy = enemyPool:get()
        if enemy then
            enemy:activate(x, y)
        end
        
        -- Devolver al pool
        enemyPool:release(enemy)
    
    Complejidad: O(1) para get y release
]]

local Pool = {}
Pool.__index = Pool

--[[
    Constructor
    
    @param class    - La clase/tabla con método :new() para crear instancias
    @param size     - Cantidad de objetos a pre-crear
    @param ...      - Argumentos adicionales para pasar a class:new()
    
    @return Pool instance
]]
function Pool:new(class, size, ...)
    local pool = setmetatable({}, Pool)
    
    pool.class = class
    pool.size = size
    pool.objects = {}           -- Todos los objetos (activos e inactivos)
    pool.available = {}         -- Stack de índices disponibles
    pool.activeCount = 0        -- Contador de objetos activos
    
    -- Pre-crear todos los objetos
    for i = 1, size do
        local obj = class:new(...)
        obj.active = false
        obj.poolIndex = i       -- Referencia para release O(1)
        pool.objects[i] = obj
        pool.available[i] = i   -- Todos empiezan disponibles
    end
    
    return pool
end

--[[
    Obtener un objeto del pool
    
    @return object o nil si el pool está agotado
]]
function Pool:get()
    local count = #self.available
    
    if count == 0 then
        -- Pool agotado - esto es un problema de diseño, no debería pasar
        -- En producción podrías expandir el pool dinámicamente
        return nil
    end
    
    -- Pop del stack de disponibles (O(1))
    local index = self.available[count]
    self.available[count] = nil
    
    local obj = self.objects[index]
    obj.active = true
    self.activeCount = self.activeCount + 1
    
    return obj
end

--[[
    Devolver un objeto al pool
    
    @param obj - El objeto a devolver (debe tener poolIndex)
]]
function Pool:release(obj)
    if not obj.active then
        -- Ya está en el pool, evita duplicados
        return
    end
    
    obj.active = false
    self.activeCount = self.activeCount - 1
    
    -- Push al stack de disponibles (O(1))
    self.available[#self.available + 1] = obj.poolIndex
end

--[[
    Iterar sobre objetos activos
    
    Uso:
        for _, enemy in pool:iterateActive() do
            enemy:update(dt)
        end
    
    @return iterator function
]]
function Pool:iterateActive()
    local i = 0
    local objects = self.objects
    local n = self.size
    
    return function()
        while i < n do
            i = i + 1
            local obj = objects[i]
            if obj.active then
                return i, obj
            end
        end
        return nil
    end
end

--[[
    Ejecutar función en todos los objetos activos
    
    Más eficiente que iterateActive si solo necesitas llamar un método
    
    @param methodName - Nombre del método a llamar
    @param ...        - Argumentos a pasar
]]
function Pool:forEach(methodName, ...)
    for i = 1, self.size do
        local obj = self.objects[i]
        if obj.active and obj[methodName] then
            obj[methodName](obj, ...)
        end
    end
end

--[[
    Liberar todos los objetos activos
]]
function Pool:releaseAll()
    for i = 1, self.size do
        local obj = self.objects[i]
        if obj.active then
            self:release(obj)
        end
    end
end

--[[
    Obtener estadísticas del pool (para debug)
    
    @return activeCount, totalSize, utilizationPercent
]]
function Pool:getStats()
    local utilization = (self.activeCount / self.size) * 100
    return self.activeCount, self.size, utilization
end

return Pool
