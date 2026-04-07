--[[
    ui_components.lua - Reusable UI Components
    
    Componentes de interfaz para menús:
    - Button: Botón clickeable con hover state
    - Slider: Control deslizante para valores 0-1
    
    Uso:
        local UI = require("src.ui.ui_components")
        
        local btn = UI.Button:new(100, 200, 200, 50, "INICIAR", function()
            startGame()
        end)
        
        btn:update(mx, my)
        btn:draw()
        
        if btn:click(mx, my) then
            -- Button was clicked
        end
]]

local Constants = require("src.core.constants")

local UI = {}

-- =============================================================================
-- BUTTON
-- =============================================================================

UI.Button = {}
UI.Button.__index = UI.Button

--[[
    Constructor de botón
    
    @param x, y         - Posición
    @param width, height - Dimensiones
    @param text         - Texto del botón
    @param onClick      - Callback al hacer click
    @param color        - Color opcional {r, g, b}
    
    @return Button instance
]]
function UI.Button:new(x, y, width, height, text, onClick, color)
    local button = setmetatable({}, UI.Button)
    
    button.x = x
    button.y = y
    button.width = width
    button.height = height
    button.text = text
    button.onClick = onClick or function() end
    button.color = color or Constants.COLOR_UI_PRIMARY
    
    button.hovered = false
    button.pressed = false
    
    return button
end

--[[
    Actualizar estado de hover
    
    @param mx, my - Posición del mouse
]]
function UI.Button:update(mx, my)
    self.hovered = self:containsPoint(mx, my)
end

--[[
    Verificar si un punto está dentro del botón
    
    @param px, py - Coordenadas
    @return boolean
]]
function UI.Button:containsPoint(px, py)
    return px >= self.x and px <= self.x + self.width and
           py >= self.y and py <= self.y + self.height
end

--[[
    Procesar click
    
    @param mx, my   - Posición del mouse
    @param button   - Botón del mouse (1 = izquierdo)
    @return boolean - true si se clickeó este botón
]]
function UI.Button:click(mx, my, button)
    if button == 1 and self:containsPoint(mx, my) then
        self.onClick()
        return true
    end
    return false
end

--[[
    Dibujar el botón
]]
function UI.Button:draw()
    -- Determinar color según estado
    local r, g, b = self.color[1], self.color[2], self.color[3]
    
    if self.hovered then
        -- Más brillante al hover
        r = math.min(1, r + 0.2)
        g = math.min(1, g + 0.2)
        b = math.min(1, b + 0.2)
    end
    
    -- Sombra
    love.graphics.setColor(0, 0, 0, 0.3)
    love.graphics.rectangle("fill", 
        self.x + 3, self.y + 3, 
        self.width, self.height, 
        6, 6)
    
    -- Fondo
    love.graphics.setColor(r, g, b, 1)
    love.graphics.rectangle("fill", 
        self.x, self.y, 
        self.width, self.height, 
        6, 6)
    
    -- Borde
    love.graphics.setColor(1, 1, 1, 0.3)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", 
        self.x, self.y, 
        self.width, self.height, 
        6, 6)
    love.graphics.setLineWidth(1)
    
    -- Highlight superior
    love.graphics.setColor(1, 1, 1, 0.2)
    love.graphics.rectangle("fill",
        self.x + 4, self.y + 4,
        self.width - 8, self.height / 3,
        4, 4)
    
    -- Texto
    love.graphics.setColor(1, 1, 1, 1)
    local font = love.graphics.getFont()
    local textWidth = font:getWidth(self.text)
    local textHeight = font:getHeight()
    love.graphics.print(
        self.text,
        self.x + (self.width - textWidth) / 2,
        self.y + (self.height - textHeight) / 2
    )
    
    love.graphics.setColor(1, 1, 1, 1)
end


-- =============================================================================
-- SLIDER
-- =============================================================================

UI.Slider = {}
UI.Slider.__index = UI.Slider

--[[
    Constructor de slider
    
    @param x, y         - Posición
    @param width        - Ancho total
    @param label        - Etiqueta
    @param value        - Valor inicial (0-1)
    @param onChange     - Callback al cambiar valor
    @param color        - Color opcional
    
    @return Slider instance
]]
function UI.Slider:new(x, y, width, label, value, onChange, color)
    local slider = setmetatable({}, UI.Slider)
    
    slider.x = x
    slider.y = y
    slider.width = width
    slider.height = 20
    slider.label = label
    slider.value = value or 0.5
    slider.onChange = onChange or function() end
    slider.color = color or Constants.COLOR_UI_SECONDARY
    
    slider.dragging = false
    slider.hovered = false
    
    return slider
end

--[[
    Actualizar estado
    
    @param mx, my - Posición del mouse
]]
function UI.Slider:update(mx, my)
    -- Check hover sobre la barra
    self.hovered = mx >= self.x and mx <= self.x + self.width and
                   my >= self.y and my <= self.y + self.height
    
    -- Si está arrastrando, actualizar valor
    if self.dragging then
        local newValue = (mx - self.x) / self.width
        newValue = math.max(0, math.min(1, newValue))
        
        if newValue ~= self.value then
            self.value = newValue
            self.onChange(self.value)
        end
    end
end

--[[
    Procesar mouse pressed
    
    @param mx, my   - Posición
    @param button   - Botón del mouse
    @return boolean - true si se empezó a arrastrar
]]
function UI.Slider:mousePressed(mx, my, button)
    if button == 1 and self.hovered then
        self.dragging = true
        -- Actualizar valor inmediatamente
        local newValue = (mx - self.x) / self.width
        self.value = math.max(0, math.min(1, newValue))
        self.onChange(self.value)
        return true
    end
    return false
end

--[[
    Procesar mouse released
]]
function UI.Slider:mouseReleased()
    self.dragging = false
end

--[[
    Establecer valor programáticamente
    
    @param value - 0 a 1
]]
function UI.Slider:setValue(value)
    self.value = math.max(0, math.min(1, value))
end

--[[
    Dibujar el slider
]]
function UI.Slider:draw()
    local r, g, b = self.color[1], self.color[2], self.color[3]
    
    -- Label
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.print(self.label, self.x, self.y - 20)
    
    -- Porcentaje
    local percent = math.floor(self.value * 100) .. "%"
    local font = love.graphics.getFont()
    local percentWidth = font:getWidth(percent)
    love.graphics.print(percent, self.x + self.width - percentWidth, self.y - 20)
    
    -- Fondo de la barra
    love.graphics.setColor(0.2, 0.2, 0.2, 1)
    love.graphics.rectangle("fill", 
        self.x, self.y, 
        self.width, self.height, 
        4, 4)
    
    -- Barra de progreso
    local fillWidth = self.width * self.value
    if fillWidth > 0 then
        love.graphics.setColor(r, g, b, 1)
        love.graphics.rectangle("fill", 
            self.x, self.y, 
            fillWidth, self.height, 
            4, 4)
    end
    
    -- Handle (círculo)
    local handleX = self.x + fillWidth
    local handleY = self.y + self.height / 2
    local handleRadius = self.height * 0.7
    
    -- Sombra del handle
    love.graphics.setColor(0, 0, 0, 0.3)
    love.graphics.circle("fill", handleX + 2, handleY + 2, handleRadius)
    
    -- Handle
    if self.dragging then
        love.graphics.setColor(1, 1, 1, 1)
    elseif self.hovered then
        love.graphics.setColor(r + 0.2, g + 0.2, b + 0.2, 1)
    else
        love.graphics.setColor(r, g, b, 1)
    end
    love.graphics.circle("fill", handleX, handleY, handleRadius)
    
    -- Borde del handle
    love.graphics.setColor(1, 1, 1, 0.5)
    love.graphics.circle("line", handleX, handleY, handleRadius)
    
    love.graphics.setColor(1, 1, 1, 1)
end

return UI
