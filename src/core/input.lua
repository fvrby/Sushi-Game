--[[
    input.lua - Input Abstraction Layer
    
    Patrón: Input Mapper
    
    Desacopla la lógica del juego de las teclas físicas.
    Permite:
    - Múltiples teclas para la misma acción (WASD + flechas)
    - Cambiar bindings sin tocar código de gameplay
    - Queries semánticas ("is moving left?") en lugar de físicas ("is A pressed?")
    
    Uso:
        local Input = require("src.core.input")
        
        -- En update
        if Input:isDown("left") then
            player.x = player.x - speed * dt
        end
        
        -- En keypressed
        if Input:isAction(key, "confirm") then
            startGame()
        end
]]

local Input = {
    -- Mapa de acciones a teclas
    -- Cada acción puede tener múltiples teclas
    bindings = {
        -- Movimiento
        up = {"w", "up"},
        down = {"s", "down"},
        left = {"a", "left"},
        right = {"d", "right"},
        
        -- Acciones
        confirm = {"return", "space"},
        cancel = {"escape"},
        pause = {"escape", "p"},
        restart = {"r"},
        
        -- Audio
        toggleMusic = {"m"},
        
        -- Debug (F-keys)
        debugFPS = {"f1"},
        debugEntities = {"f2"},
        debugHitboxes = {"f3"},
        debugGrid = {"f4"},
        debugSpawns = {"f5"},
        debugConsole = {"`"},

        -- Shader
        toggleCRT = {"f6"},
    },
    
    -- Cache de teclas presionadas este frame
    justPressed = {},
    justReleased = {},
}

--[[
    Verificar si una acción está siendo presionada (held)
    
    @param action - Nombre de la acción (ej: "left", "confirm")
    @return boolean
]]
function Input:isDown(action)
    local keys = self.bindings[action]
    
    if not keys then
        return false
    end
    
    for _, key in ipairs(keys) do
        if love.keyboard.isDown(key) then
            return true
        end
    end
    
    return false
end

--[[
    Verificar si una tecla corresponde a una acción (para keypressed)
    
    @param key      - Tecla física presionada
    @param action   - Acción a verificar
    @return boolean
]]
function Input:isAction(key, action)
    local keys = self.bindings[action]
    
    if not keys then
        return false
    end
    
    for _, k in ipairs(keys) do
        if k == key then
            return true
        end
    end
    
    return false
end

--[[
    Obtener vector de movimiento normalizado
    
    @return dx, dy (valores entre -1 y 1, normalizados para diagonal)
]]
function Input:getMovementVector()
    local dx, dy = 0, 0
    
    if self:isDown("left") then dx = dx - 1 end
    if self:isDown("right") then dx = dx + 1 end
    if self:isDown("up") then dy = dy - 1 end
    if self:isDown("down") then dy = dy + 1 end
    
    -- Normalizar diagonal (evita movimiento más rápido en diagonal)
    if dx ~= 0 and dy ~= 0 then
        local len = math.sqrt(dx * dx + dy * dy)
        dx = dx / len
        dy = dy / len
    end
    
    return dx, dy
end

--[[
    Obtener posición del mouse
    
    @return x, y
]]
function Input:getMousePosition()
    return love.mouse.getPosition()
end

--[[
    Verificar si un botón del mouse está presionado
    
    @param button - 1 = izquierdo, 2 = derecho, 3 = medio
    @return boolean
]]
function Input:isMouseDown(button)
    return love.mouse.isDown(button)
end

--[[
    Calcular ángulo desde un punto hacia el mouse
    
    @param x, y - Posición de origen
    @return angle en radianes
]]
function Input:getAngleToMouse(x, y)
    local mx, my = self:getMousePosition()
    return math.atan2(my - y, mx - x)
end

--[[
    Rebind una acción a nuevas teclas
    
    @param action   - Nombre de la acción
    @param keys     - Tabla de teclas (ej: {"w", "up"})
]]
function Input:rebind(action, keys)
    self.bindings[action] = keys
end

--[[
    Obtener teclas asignadas a una acción (para mostrar en UI)
    
    @param action - Nombre de la acción
    @return string con teclas separadas por " / "
]]
function Input:getBindingDisplay(action)
    local keys = self.bindings[action]
    
    if not keys then
        return "???"
    end
    
    local display = {}
    for _, key in ipairs(keys) do
        -- Capitalizar nombres de teclas
        local name = key:upper()
        if name == "RETURN" then name = "ENTER" end
        if name == "ESCAPE" then name = "ESC" end
        table.insert(display, name)
    end
    
    return table.concat(display, " / ")
end

return Input
