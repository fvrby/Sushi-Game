--[[
    crt_shader.lua - CRT Shader Wrapper
    
    Maneja:
    - Carga segura del shader
    - Canvas para post-processing
    - Toggle on/off
    - Actualización de uniforms
]]

local Constants = require("src.core.constants")

local CRTShader = {}
CRTShader.__index = CRTShader

--[[
    Constructor
    
    @return CRTShader instance
]]
function CRTShader:new()
    local crt = setmetatable({}, CRTShader)
    
    crt.shader = nil
    crt.canvas = nil
    crt.enabled = true
    crt.supported = false
    crt.time = 0
    
    -- Intentar cargar shader
    crt:load()
    
    return crt
end

--[[
    Cargar shader y crear canvas
]]
function CRTShader:load()
    -- Cargar shader
    local success, result = pcall(function()
        return love.graphics.newShader("assets/shaders/crt.glsl")
    end)
    
    if not success then
        print("Warning: No se pudo cargar shader CRT: " .. tostring(result))
        return
    end
    
    self.shader = result
    self.supported = true
    
    -- Crear canvas
    self.canvas = love.graphics.newCanvas(
        Constants.WINDOW_WIDTH,
        Constants.WINDOW_HEIGHT
    )
    
    -- Enviar resolución al shader
    self.shader:send("resolution", {Constants.WINDOW_WIDTH, Constants.WINDOW_HEIGHT})
    
    print("Shader CRT cargado correctamente")
end

--[[
    Toggle shader on/off
]]
function CRTShader:toggle()
    self.enabled = not self.enabled
end

--[[
    Verificar si está activo
    
    @return boolean
]]
function CRTShader:isActive()
    return self.supported and self.enabled
end

--[[
    Comenzar a dibujar al canvas
    
    Llamar antes de dibujar la escena
]]
function CRTShader:beginDraw()
    if not self:isActive() then
        return
    end
    
    love.graphics.setCanvas(self.canvas)
    love.graphics.clear()
end

--[[
    Finalizar y aplicar shader
    
    Llamar después de dibujar la escena
]]
function CRTShader:endDraw()
    if not self:isActive() then
        return
    end
    
    love.graphics.setCanvas()
    
    -- Actualizar tiempo para efectos animados
    self.shader:send("time", love.timer.getTime())
    
    -- Dibujar canvas con shader
    love.graphics.setShader(self.shader)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(self.canvas, 0, 0)
    love.graphics.setShader()
end

--[[
    Obtener estado para debug
    
    @return string
]]
function CRTShader:getStatus()
    if not self.supported then
        return "No soportado"
    elseif self.enabled then
        return "Activado"
    else
        return "Desactivado"
    end
end

return CRTShader