--[[
    constants.lua - Game Constants
    
    Centraliza TODOS los valores numéricos del juego.
    
    Razón: Si quieres cambiar la velocidad del jugador, lo haces aquí,
    no buscando en 5 archivos diferentes. También facilita el balanceo.
    
    Convención: SCREAMING_SNAKE_CASE para constantes
]]

local Constants = {}

-- =============================================================================
-- WINDOW
-- =============================================================================
Constants.WINDOW_WIDTH = 1280
Constants.WINDOW_HEIGHT = 720

-- =============================================================================
-- PLAYER
-- =============================================================================
Constants.PLAYER_WIDTH = 32
Constants.PLAYER_HEIGHT = 32
Constants.PLAYER_SPEED = 200              -- Unidades por segundo
Constants.PLAYER_FIRE_RATE = 0.3          -- Segundos entre disparos
Constants.PLAYER_START_X = 640            -- Centro horizontal
Constants.PLAYER_START_Y = 360            -- Centro vertical

-- =============================================================================
-- BULLET
-- =============================================================================
Constants.BULLET_SPEED = 500
Constants.BULLET_RADIUS = 4
Constants.BULLET_DAMAGE = 1
Constants.BULLET_POOL_SIZE = 50

-- =============================================================================
-- ENEMY
-- =============================================================================
Constants.ENEMY_WIDTH = 24
Constants.ENEMY_HEIGHT = 24
Constants.ENEMY_HEALTH = 2
Constants.ENEMY_SPEED_MIN = 80
Constants.ENEMY_SPEED_MAX = 120
Constants.ENEMY_POOL_SIZE = 100
Constants.ENEMY_SPAWN_MARGIN = 50         -- Distancia fuera de pantalla para spawn

-- =============================================================================
-- SPAWNER
-- =============================================================================
Constants.SPAWN_RATE_INITIAL = 1.0        -- Segundos entre spawns al inicio
Constants.SPAWN_RATE_MIN = 0.2            -- Mínimo tiempo entre spawns
Constants.SPAWN_RATE_DECAY = 0.99         -- Multiplicador por spawn (más rápido gradualmente)

-- =============================================================================
-- PARTICLES
-- =============================================================================
Constants.PARTICLE_POOL_SIZE = 200
Constants.PARTICLE_DEATH_COUNT = 15       -- Partículas al morir enemigo
Constants.PARTICLE_HIT_COUNT = 5          -- Partículas al impactar bala
Constants.PARTICLE_LIFETIME_MIN = 0.5
Constants.PARTICLE_LIFETIME_MAX = 1.0
Constants.PARTICLE_SPEED_MIN = 50
Constants.PARTICLE_SPEED_MAX = 150
Constants.PARTICLE_GRAVITY = 100          -- Aceleración hacia abajo
Constants.PARTICLE_SIZE = 3

-- =============================================================================
-- SCORING
-- =============================================================================
Constants.SCORE_PER_KILL = 10

-- =============================================================================
-- AUDIO
-- =============================================================================
Constants.MUSIC_VOLUME_DEFAULT = 0.6
Constants.SFX_SHOOT_VOLUME_DEFAULT = 0.15
Constants.SFX_EXPLOSION_VOLUME_DEFAULT = 0.15

-- =============================================================================
-- COLLISION (Spatial Hash)
-- =============================================================================
Constants.SPATIAL_CELL_SIZE = 64          -- Tamaño de celda en pixels

-- =============================================================================
-- COLORS (RGBA 0-1)
-- =============================================================================
Constants.COLOR_BULLET = {1, 1, 0, 1}                 -- Amarillo
Constants.COLOR_ENEMY = {1, 0.2, 0.2, 1}              -- Rojo
Constants.COLOR_PARTICLE_DEATH = {1, 0.5, 0, 1}       -- Naranja
Constants.COLOR_PARTICLE_HIT = {1, 1, 0.5, 1}         -- Amarillo claro
Constants.COLOR_SCORE = {0, 1, 0.5, 1}                -- Verde fosforescente
Constants.COLOR_UI_PRIMARY = {1, 0.4, 0.7, 1}         -- Rosa/Fucsia
Constants.COLOR_UI_SECONDARY = {0.3, 0.5, 1, 1}       -- Azul
Constants.COLOR_BACKGROUND = {0.05, 0.05, 0.08, 1}    -- Casi negro

-- =============================================================================
-- DEBUG
-- =============================================================================
Constants.DEBUG_FONT_SIZE = 14
Constants.DEBUG_COLOR = {0, 1, 0, 0.8}    -- Verde semi-transparente

return Constants
