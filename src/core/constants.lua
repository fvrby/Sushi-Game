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
-- ERRATIC ENEMY
-- =============================================================================
Constants.ERRATIC_ENEMY_WIDTH = 20
Constants.ERRATIC_ENEMY_HEIGHT = 20
Constants.ERRATIC_ENEMY_HEALTH = 1
Constants.ERRATIC_SPEED_MIN = 130
Constants.ERRATIC_SPEED_MAX = 220
Constants.ERRATIC_ENEMY_POOL_SIZE = 50
Constants.ERRATIC_WANDER_STRENGTH = 1.4    -- Max random deviation (rad) from player direction
Constants.ERRATIC_WANDER_INTERVAL_MIN = 0.2
Constants.ERRATIC_WANDER_INTERVAL_MAX = 0.6
Constants.ERRATIC_SPAWN_CHANCE = 0.3       -- 30% de spawns serán erráticos
Constants.COLOR_ERRATIC_ENEMY = {0.7, 0.2, 1, 1}   -- Morado

-- =============================================================================
-- BOSS
-- =============================================================================
Constants.BOSS_HEALTH          = 100
Constants.BOSS_RADIUS          = 45
Constants.BOSS_SPEED           = 55       -- Velocidad fases 1-3
Constants.BOSS_SPEED_P4        = 30       -- Velocidad fase 4 (más lento)
Constants.BOSS_SCORE_INTERVAL  = 150      -- Puntos entre apariciones
Constants.BOSS_BULLET_DAMAGE   = 1
Constants.BOSS_BULLET_POOL_SIZE = 40

-- Umbrales de fase (HP restante)
Constants.BOSS_PHASE2_HP = 80
Constants.BOSS_PHASE3_HP = 60
Constants.BOSS_PHASE4_HP = 40
Constants.BOSS_PHASE5_HP = 20

-- Tasas de disparo por fase
Constants.BOSS_FIRE_RATE_P1 = 2.5   -- Fase 1: un disparo cada 2.5s
Constants.BOSS_FIRE_RATE_P2 = 1.0   -- Fase 2: más rápido
Constants.BOSS_FIRE_RATE_P4 = 1.5   -- Fase 4: arcos
Constants.BOSS_FIRE_RATE_P5 = 3.2   -- Fase 5: bombas lentas

-- Fase 3: teletransporte + ráfaga
Constants.BOSS_TELEPORT_INTERVAL       = 1.0   -- Segundos entre teletransportes
Constants.BOSS_TELEPORT_FLASH_DURATION = 0.35  -- Duración del flash blanco
Constants.BOSS_BURST_DURATION          = 2.8   -- Segundos de ráfaga tras teleporte
Constants.BOSS_BURST_FIRE_RATE         = 0.13  -- Segundos entre cada bala de ráfaga

-- Fase 4: disparo en arco
Constants.BOSS_ARC_BULLETS = 8
Constants.BOSS_ARC_ANGLE   = math.pi * (2/3)  -- 120° total

-- Fase 5: bombas explosivas
Constants.BOSS_BULLET_RADIUS       = 9
Constants.BOSS_BULLET_SPEED        = 210   -- +50%
Constants.BOSS_BOMB_RADIUS         = 15
Constants.BOSS_BOMB_SPEED          = 128   -- +50%
Constants.BOSS_BOMB_EXPLODE_DIST   = 240   -- Distancia a la que explota
Constants.BOSS_PELLET_COUNT        = 8
Constants.BOSS_PELLET_RADIUS       = 5
Constants.BOSS_PELLET_SPEED        = 323   -- +50%

-- Secuencia de muerte
Constants.BOSS_DEATH_SHAKE_DURATION = 2.0   -- Segundos temblando antes de explotar
Constants.BOSS_DEATH_WAIT_DURATION  = 3.0   -- Segundos de explosión lenta antes de victoria

Constants.COLOR_BOSS            = {0.2, 0.5, 1, 1}      -- Azul
Constants.COLOR_BOSS_BULLET     = {0.5, 0.8, 1, 1}      -- Azul claro
Constants.COLOR_BOSS_HEALTHBAR  = {0.9, 0.1, 0.1, 1}    -- Rojo

-- =============================================================================
-- POWER-UPS
-- =============================================================================
Constants.POWERUP_DROP_CHANCE = 0.12       -- 12% de enemigos spawneados serán portadores
Constants.POWERUP_RADIUS = 10
Constants.POWERUP_COLLECT_RADIUS = 22      -- Rango para recoger
Constants.POWERUP_POOL_SIZE = 10
Constants.POWERUP_LIFETIME = 8.0           -- Segundos antes de desaparecer
Constants.COLOR_POWERUP_SPREAD = {0.2, 1, 0.9, 1}  -- Cyan

-- Spread shot
Constants.SPREAD_SHOT_BULLETS = 5
Constants.SPREAD_SHOT_ANGLE = math.pi / 3  -- 60 grados total
Constants.SPREAD_SHOT_DURATION = 10.0

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
