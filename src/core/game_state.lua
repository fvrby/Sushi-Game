--[[
    game_state.lua - Game State Machine
    
    Patrón: Finite State Machine (FSM)
    
    Controla el flujo del juego entre estados discretos.
    Cada estado tiene sus propios callbacks de update, draw, y input.
    
    Estados:
    - menu: Pantalla principal
    - settings: Configuración de audio
    - playing: Juego activo
    - paused: Juego pausado
    - gameover: Pantalla de muerte
    
    Uso:
        local GameState = require("src.core.game_state")
        
        GameState:register("playing", {
            enter = function(self) ... end,
            exit = function(self) ... end,
            update = function(self, dt) ... end,
            draw = function(self) ... end,
            keypressed = function(self, key) ... end,
        })
        
        GameState:switch("playing")
]]

local GameState = {
    current = nil,          -- Estado actual (string)
    states = {},            -- Tabla de estados registrados
    previous = nil,         -- Estado anterior (para volver atrás)
}

--[[
    Registrar un nuevo estado
    
    @param name     - Identificador único del estado
    @param state    - Tabla con callbacks (enter, exit, update, draw, etc.)
]]
function GameState:register(name, state)
    if self.states[name] then
        error("GameState: Estado '" .. name .. "' ya existe")
    end
    
    -- Asegurar que todos los callbacks existan (evita nil checks)
    state.enter = state.enter or function() end
    state.exit = state.exit or function() end
    state.update = state.update or function() end
    state.draw = state.draw or function() end
    state.keypressed = state.keypressed or function() end
    state.keyreleased = state.keyreleased or function() end
    state.mousepressed = state.mousepressed or function() end
    state.mousereleased = state.mousereleased or function() end
    state.mousemoved = state.mousemoved or function() end
    
    self.states[name] = state
end

--[[
    Cambiar al estado especificado
    
    @param name - Nombre del estado destino
    @param ...  - Argumentos opcionales para pasar a enter()
]]
function GameState:switch(name, ...)
    local newState = self.states[name]
    
    if not newState then
        error("GameState: Estado '" .. name .. "' no existe")
    end
    
    -- Salir del estado actual
    if self.current then
        local currentState = self.states[self.current]
        currentState:exit()
    end
    
    -- Guardar estado anterior
    self.previous = self.current
    self.current = name
    
    -- Entrar al nuevo estado
    newState:enter(...)
end

--[[
    Volver al estado anterior
]]
function GameState:back()
    if self.previous then
        self:switch(self.previous)
    end
end

--[[
    Obtener el estado actual
    
    @return string - Nombre del estado actual
]]
function GameState:getCurrent()
    return self.current
end

--[[
    Verificar si estamos en un estado específico
    
    @param name - Nombre del estado a verificar
    @return boolean
]]
function GameState:is(name)
    return self.current == name
end

-- =============================================================================
-- CALLBACKS - Delegan al estado actual
-- =============================================================================

function GameState:update(dt)
    if self.current then
        self.states[self.current]:update(dt)
    end
end

function GameState:draw()
    if self.current then
        self.states[self.current]:draw()
    end
end

function GameState:keypressed(key, scancode, isrepeat)
    if self.current then
        self.states[self.current]:keypressed(key, scancode, isrepeat)
    end
end

function GameState:keyreleased(key, scancode)
    if self.current then
        self.states[self.current]:keyreleased(key, scancode)
    end
end

function GameState:mousepressed(x, y, button, istouch, presses)
    if self.current then
        self.states[self.current]:mousepressed(x, y, button, istouch, presses)
    end
end

function GameState:mousereleased(x, y, button, istouch, presses)
    if self.current then
        self.states[self.current]:mousereleased(x, y, button, istouch, presses)
    end
end

function GameState:mousemoved(x, y, dx, dy, istouch)
    if self.current then
        self.states[self.current]:mousemoved(x, y, dx, dy, istouch)
    end
end

return GameState
