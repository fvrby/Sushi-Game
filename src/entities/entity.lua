--[[
    entity.lua - Base Entity Class
    
    Patrón: Template Method
    
    Clase base que define la interfaz común para todas las entidades.
    Las subclases implementan los métodos específicos.
    
    Proporciona:
    - Propiedades comunes (posición, tamaño, active)
    - Métodos stub para override
    - Helpers para colisión básica
]]

local Entity = {}
Entity.__index = Entity

--[[
    Constructor base
    
    @return Entity instance
]]
function Entity:new()
    local entity = setmetatable({}, self)
    
    -- Estado del pool
    entity.active = false
    entity.poolIndex = nil
    
    -- Posición
    entity.x = 0
    entity.y = 0
    
    -- Dimensiones (para colisión)
    entity.width = 0
    entity.height = 0
    
    return entity
end

--[[
    Activar la entidad (llamado al sacar del pool)
    Subclases deben override esto para inicializar estado
    
    @param x, y - Posición inicial
]]
function Entity:activate(x, y)
    self.active = true
    self.x = x or 0
    self.y = y or 0
end

--[[
    Desactivar la entidad (antes de devolver al pool)
    Subclases pueden override para cleanup
]]
function Entity:deactivate()
    self.active = false
end

--[[
    Update loop - Override en subclases
    
    @param dt - Delta time
]]
function Entity:update(dt)
    -- Implementar en subclase
end

--[[
    Draw - Override en subclases
]]
function Entity:draw()
    -- Implementar en subclase
end

--[[
    Obtener bounding box para colisión AABB
    
    @return x, y, width, height
]]
function Entity:getBounds()
    return self.x, self.y, self.width, self.height
end

--[[
    Obtener centro de la entidad
    
    @return centerX, centerY
]]
function Entity:getCenter()
    return self.x + self.width / 2, self.y + self.height / 2
end

--[[
    Verificar colisión AABB con otra entidad
    
    @param other - Otra entidad con getBounds()
    @return boolean
]]
function Entity:collidesWith(other)
    local ax, ay, aw, ah = self:getBounds()
    local bx, by, bw, bh = other:getBounds()
    
    return ax < bx + bw and
           ax + aw > bx and
           ay < by + bh and
           ay + ah > by
end

--[[
    Verificar si un punto está dentro de la entidad
    
    @param px, py - Coordenadas del punto
    @return boolean
]]
function Entity:containsPoint(px, py)
    return px >= self.x and
           px <= self.x + self.width and
           py >= self.y and
           py <= self.y + self.height
end

--[[
    Calcular distancia al cuadrado hacia otro punto
    (Más eficiente que distancia real si solo comparas)
    
    @param x, y - Punto destino
    @return distanceSquared
]]
function Entity:distanceSquaredTo(x, y)
    local cx, cy = self:getCenter()
    local dx = x - cx
    local dy = y - cy
    return dx * dx + dy * dy
end

--[[
    Calcular distancia hacia otro punto
    
    @param x, y - Punto destino
    @return distance
]]
function Entity:distanceTo(x, y)
    return math.sqrt(self:distanceSquaredTo(x, y))
end

return Entity
