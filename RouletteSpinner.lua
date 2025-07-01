local RouletteSpinner = {
    version = "1.0.0"
}

-- Coordinate translation constants - easily adjustable
local COORDINATE_CONSTANTS = {
    -- Frustum shape thingies - now with middle radius for two frustum shapes
    BOTTOM_RADIUS = 0.21,   -- Radius at bottom part (y = -10) - small circle
    MIDDLE_RADIUS = 0.24,   -- Radius at middle part (y = 45) - middle circle (NEW!)
    TOP_RADIUS = 0.358,      -- Radius at top part (y = 100) - big circle
    
    -- Height map thing (2D simulator coords)
    MIN_HEIGHT = -10,      -- Simulator Y lowest point
    MIDDLE_HEIGHT = 15,    -- Simulator Y middle point (NEW!)
    MAX_HEIGHT = 100,      -- Simulator Y highest point
    HEIGHT_RANGE = 110,    -- Total height thing (MAX_HEIGHT - MIN_HEIGHT)
    
    -- 3D height map thing (real Z coords in world)
    BOTTOM_Z_OFFSET = 0.055,  -- Z offset at bottom of frustum (y = -10)
    MIDDLE_Z_OFFSET = 0.07, -- Z offset at middle of frustum (y = 45) (NEW!)
    TOP_Z_OFFSET = 0.08,     -- Z offset at top of frustum (y = 100)
    
    -- Base origin offset in 3D world coords (before spin)
    BASE_ORIGIN_OFFSET = {x=0, y=0.2, z=0.1},
    
    -- Physics constants
    HORIZONTAL_DECELERATION = 30, -- units per second squared
    GRAVITY = 50,                 -- units per second squared
    GRAVITY_THRESHOLD = 30,       -- Start gravity when horizontal speed is below this
    GRAVITY_MODIFIER = 1.0,       -- Overall gravity modifier (1.0 = normal gravity)
    
    -- Initial ball speed constants
    INITIAL_BALL_SPEED_MIN = 400, -- Minimum initial horizontal velocity (units/sec)
    INITIAL_BALL_SPEED_MAX = 600, -- Maximum initial horizontal velocity (units/sec)
    INITIAL_BALL_VERTICAL_SPEED = 0 -- Initial vertical velocity (units/sec)
}

local Cron = require('External/Cron.lua')
local GameUI = require("External/GameUI.lua")
local CollisionCtR = require("CollisionCtR.lua")

local inMenu = true --libaries requirement
local inGame = false

-- Initialize the RouletteSpinner object
function RouletteSpinner:new()
    local obj = {
        -- Spinner properties
        spinnerCenter = nil,
        spinnerRotation = 0,        -- Current rotation angle in radians
        spinnerVelocity = 0,        -- Angular velocity (rotation speed) in radians per second
        
        -- Ball properties
        ballX = 0,                  -- Ball x coordinate
        ballY = 0,                  -- Ball y coordinate
        ballVx = 0,                 -- Ball x velocity
        ballVy = 0,                 -- Ball y velocity
        ballRadius = 5,             -- Ball radius size
        
        -- Entity IDs
        ballEntityID = nil,         -- Entity ID for the roulette ball
        spinnerEntityID = nil,      -- Entity ID for the roulette spinner
        debugBallEntities = {},     -- Array to track debug ball entities
        
        -- Physics properties
        gravityModifier = COORDINATE_CONSTANTS.GRAVITY_MODIFIER,      -- Overall gravity modifier (1.0 = normal gravity)
        
        -- Coordinate translation properties
        simulatorOriginOffset = {x=0, y=0, z=0}, -- Origin offset in 3D world coordinates
        bottomRadius = COORDINATE_CONSTANTS.BOTTOM_RADIUS,
        middleRadius = COORDINATE_CONSTANTS.MIDDLE_RADIUS,
        topRadius = COORDINATE_CONSTANTS.TOP_RADIUS,
        minHeight = COORDINATE_CONSTANTS.MIN_HEIGHT,
        middleHeight = COORDINATE_CONSTANTS.MIDDLE_HEIGHT,
        maxHeight = COORDINATE_CONSTANTS.MAX_HEIGHT,
        heightRange = COORDINATE_CONSTANTS.HEIGHT_RANGE,
        bottomZOffset = COORDINATE_CONSTANTS.BOTTOM_Z_OFFSET,
        middleZOffset = COORDINATE_CONSTANTS.MIDDLE_Z_OFFSET,
        topZOffset = COORDINATE_CONSTANTS.TOP_Z_OFFSET,
        
        -- State properties
        isLoaded = false,
        isSimulationRunning = false, -- Flag to track if simulation is active
        frameCounter = 0,           -- Counter for simulation frames
        onBallLanded = nil -- Simple callback function for ball landing
    }
    setmetatable(obj, self)
    self.__index = self
    return obj
end

-- Initialize this lua file
function RouletteSpinner.init()
    -- Initialization code her
    Observe('RadialWheelController', 'OnIsInMenuChanged', function(_, isInMenu) -- Setup observer and GameUI to detect inGame / inMenu, credit: keanuwheeze | init.lua from the sitAnywhere mod
        inMenu = isInMenu
    end)

    inGame = false          --Setup observer and GameUI to detect inGame / inMenu
    GameUI.OnSessionStart(function() --  credit: keanuwheeze | init.lua from the sitAnywhere mod
        inGame = true
    end)
    GameUI.OnSessionEnd(function()
        inGame = false
    end)
    inGame = not GameUI.IsDetached() -- Required to check if ingame after reloading all mods
end

-- Load the roulette spinner at the specified center position
function RouletteSpinner:load(spinnerCenter, rotationOffset)
    if not spinnerCenter then
        DualPrint("Error: spinnerCenter parameter is required")
        return false
    end
    
    if self.isLoaded then
        DualPrint("Warning: Spinner is already loaded. Unload first to reload.")
        return false
    end
    
    -- Default rotation offset to 0 if not provided
    rotationOffset = rotationOffset or 0
    
    -- Convert degrees to radians for the orientation
    local rotationRadians = math.rad(rotationOffset)
    
    -- This is the start offset of the ball from the spinner center
    local simulatorOriginOffsetBase = COORDINATE_CONSTANTS.BASE_ORIGIN_OFFSET
    
    -- Apply rotation to the offset
    local cosRot = math.cos(rotationRadians)
    local sinRot = math.sin(rotationRadians)
    self.simulatorOriginOffset = {
        x = simulatorOriginOffsetBase.x * cosRot - simulatorOriginOffsetBase.y * sinRot,
        y = simulatorOriginOffsetBase.x * sinRot + simulatorOriginOffsetBase.y * cosRot,
        z = simulatorOriginOffsetBase.z
    }

    -- Spawn the ball entity
    local ballSpec = StaticEntitySpec.new()
    ballSpec.templatePath = "boe6\\gambling_system_roulette\\q303_roulette_ball.ent"
    ballSpec.position = Vector4.new(spinnerCenter.x+self.simulatorOriginOffset.x, spinnerCenter.y+self.simulatorOriginOffset.y, spinnerCenter.z+self.simulatorOriginOffset.z, 1.0)
    ballSpec.orientation = EulerAngles.ToQuat(EulerAngles.new(0, 0, 0))
    ballSpec.tags = {"rouletteBall"}
    
    self.ballEntityID = Game.GetStaticEntitySystem():SpawnEntity(ballSpec)
    DualPrint('Ball entity spawned with ID: ' .. tostring(self.ballEntityID))
    
    -- Spawn the spinner entity
    local spinnerSpec = StaticEntitySpec.new()
    spinnerSpec.templatePath = "boe6\\gambling_system_roulette\\casino_table_roulette_spin_spinner.ent"
    spinnerSpec.position = Vector4.new(spinnerCenter.x, spinnerCenter.y, spinnerCenter.z, 1.0)
    spinnerSpec.orientation = EulerAngles.ToQuat(EulerAngles.new(0, 0, rotationRadians))
    spinnerSpec.tags = {"rouletteSpinner"}
    
    self.spinnerEntityID = Game.GetStaticEntitySystem():SpawnEntity(spinnerSpec)
    DualPrint('Spinner entity spawned with ID: ' .. tostring(self.spinnerEntityID) .. ' with rotation offset: ' .. tostring(self.simulatorOriginOffset) .. ' degrees')
    
    self.spinnerCenter = spinnerCenter
    self.spinnerRotation = rotationRadians -- Store the rotation in radians
    self.isLoaded = true
    -- Load implementation here
    return true
end

-- Translate simulator coordinates to 3D world coordinates
function RouletteSpinner:translateToWorldCoords(simX, simY)
    if not self.isLoaded then
        DualPrint("Error: Cannot translate coordinates - spinner is not loaded")
        return nil
    end

    -- The spinnerCenter is the true center of the roulette table/spinner.
    -- The frustum should be built around this point in X and Y.
    local centerX = self.spinnerCenter.x
    local centerY = self.spinnerCenter.y
    local centerZ = self.spinnerCenter.z

    -- Map simY to height progress and calculate radius and zOffset
    local clampedY = math.max(self.minHeight, math.min(self.maxHeight, simY))
    local radius, zOffset
    
    -- Determine which frustum shape to use based on height
    if clampedY <= self.middleHeight then
        -- Bottom frustum: from MIN_HEIGHT to MIDDLE_HEIGHT
        local heightProgress = (clampedY - self.minHeight) / (self.middleHeight - self.minHeight)
        radius = self.bottomRadius + (self.middleRadius - self.bottomRadius) * heightProgress
        zOffset = self.bottomZOffset + (self.middleZOffset - self.bottomZOffset) * heightProgress
    else
        -- Top frustum: from MIDDLE_HEIGHT to MAX_HEIGHT
        local heightProgress = (clampedY - self.middleHeight) / (self.maxHeight - self.middleHeight)
        radius = self.middleRadius + (self.topRadius - self.middleRadius) * heightProgress
        zOffset = self.middleZOffset + (self.topZOffset - self.middleZOffset) * heightProgress
    end

    -- Calculate the angle of the BASE_ORIGIN_OFFSET relative to the spinner's center.
    -- This defines the "zero" point on the frustum's circumference.
    -- This angle is for BASE_ORIGIN_OFFSET itself, before spinner rotation.
    local baseOriginAngle = math.atan2(COORDINATE_CONSTANTS.BASE_ORIGIN_OFFSET.y, COORDINATE_CONSTANTS.BASE_ORIGIN_OFFSET.x)

    -- The current angular position of the ball on the frustum's circumference is:
    -- (base angle for simulator's 0,0) + (simulator's X position as an angle) + (spinner's current rotation)
    local currentBallAngleRad = baseOriginAngle + math.rad(simX) + self.spinnerRotation

    -- Calculate the X and Y offsets from the frustum's central axis (spinnerCenter)
    -- based on the calculated radius and the combined angle.
    local offsetX = radius * math.cos(currentBallAngleRad)
    local offsetY = radius * math.sin(currentBallAngleRad)

    -- The final position is the spinnerCenter plus these calculated offsets.
    -- The Z position also uses the spinner's Z and the height-based zOffset.
    local finalX = centerX + offsetX
    local finalY = centerY + offsetY
    local finalZ = centerZ + zOffset

    return {
        x = finalX,
        y = finalY,
        z = finalZ
    }
end

-- Unload the roulette spinner
function RouletteSpinner:unload()
    if not self.isLoaded then
        DualPrint("Warning: Spinner is not loaded. Nothing to unload.")
        return false
    end
    
    -- Stop simulation if it's running
    if self.isSimulationRunning then
        self:stopSimulation()
    end
    
    -- Clear debug grid
    self:clearDebugGrid()
    
    -- Delete the ball entity if it exists
    if self.ballEntityID then
        Game.GetStaticEntitySystem():DespawnEntity(self.ballEntityID)
        DualPrint('Ball entity deleted with ID: ' .. tostring(self.ballEntityID))
        self.ballEntityID = nil
    end
    
    -- Delete the spinner entity if it exists
    if self.spinnerEntityID then
        Game.GetStaticEntitySystem():DespawnEntity(self.spinnerEntityID)
        DualPrint('Spinner entity deleted with ID: ' .. tostring(self.spinnerEntityID))
        self.spinnerEntityID = nil
    end
    
    -- Reset all properties to initial state
    self.spinnerCenter = nil
    self.spinnerRotation = 0
    self.spinnerVelocity = 0
    self.ballX = 0
    self.ballY = 0
    self.ballVx = 0
    self.ballVy = 0
    self.ballRadius = 5
    self.gravityModifier = COORDINATE_CONSTANTS.GRAVITY_MODIFIER
    self.simulatorOriginOffset = {x=0, y=0, z=0}
    self.bottomRadius = COORDINATE_CONSTANTS.BOTTOM_RADIUS
    self.middleRadius = COORDINATE_CONSTANTS.MIDDLE_RADIUS
    self.topRadius = COORDINATE_CONSTANTS.TOP_RADIUS
    self.minHeight = COORDINATE_CONSTANTS.MIN_HEIGHT
    self.middleHeight = COORDINATE_CONSTANTS.MIDDLE_HEIGHT
    self.maxHeight = COORDINATE_CONSTANTS.MAX_HEIGHT
    self.heightRange = COORDINATE_CONSTANTS.HEIGHT_RANGE
    self.bottomZOffset = COORDINATE_CONSTANTS.BOTTOM_Z_OFFSET
    self.middleZOffset = COORDINATE_CONSTANTS.MIDDLE_Z_OFFSET
    self.topZOffset = COORDINATE_CONSTANTS.TOP_Z_OFFSET
    self.isLoaded = false
    self.isSimulationRunning = false
    self.frameCounter = 0
    self.onBallLanded = nil
    
    DualPrint("Roulette spinner unloaded successfully")
    return true
end

-- Start the roulette simulation
function RouletteSpinner:startSimulation()
    if not self.isLoaded then
        DualPrint("Error: Cannot start simulation - spinner is not loaded")
        return false
    end
    
    if self.isSimulationRunning then
        DualPrint("Warning: Simulation is already running")
        return false
    end
    
    -- Initialize ball position
    self.ballX = 0  -- Start at left edge
    self.ballY = 90 -- Start near top
    -- Random horizontal velocity (positive x direction) - much faster now
    self.ballVx = math.random(COORDINATE_CONSTANTS.INITIAL_BALL_SPEED_MIN, COORDINATE_CONSTANTS.INITIAL_BALL_SPEED_MAX) -- Random velocity between 300-600 units/sec
    self.ballVy = COORDINATE_CONSTANTS.INITIAL_BALL_VERTICAL_SPEED -- Start with small downward velocity so ball falls immediately
    
    -- Reset frame counter
    self.frameCounter = 0
    
    self.isSimulationRunning = true
    DualPrint("Simulation started")
    return true
end

-- Stop the roulette simulation
function RouletteSpinner:stopSimulation()
    if not self.isSimulationRunning then
        DualPrint("Warning: Simulation is not running")
        return false
    end
    
    self.isSimulationRunning = false
    DualPrint("Simulation stopped")
    return true
end

-- Process a single simulation frame
function RouletteSpinner:processSimulationFrame(dt)
    if not self.isLoaded then
        return
    end
    
    -- Increment frame counter
    self.frameCounter = self.frameCounter + 1
    
    -- Translate simulator coordinates to world coordinates and teleport the ball
    local worldCoords = self:translateToWorldCoords(self.ballX, self.ballY)
    if worldCoords and self.ballEntityID then
        -- Teleport the ball to the new world position
        local ballEntity = Game.FindEntityByID(self.ballEntityID)
        if ballEntity then
            local newPosition = Vector4.new(worldCoords.x, worldCoords.y, worldCoords.z, 1.0)
            Game.GetTeleportationFacility():Teleport(ballEntity, newPosition, EulerAngles.new(0, 0, 0))
        end
    end
    
    -- Check if we've reached 3000 frames (increased from 1000)
    if self.frameCounter >= 3000 then
        DualPrint("Simulation ended after 3000 frames")
        self.isSimulationRunning = false
        return
    end
    
    -- Apply horizontal deceleration (faster deceleration)
    local horizontalDeceleration = COORDINATE_CONSTANTS.HORIZONTAL_DECELERATION -- units per second squared (increased from 20)
    if self.ballVx > 0 then
        self.ballVx = math.max(0, self.ballVx - horizontalDeceleration * dt)
    elseif self.ballVx < 0 then
        self.ballVx = math.min(0, self.ballVx + horizontalDeceleration * dt)
    end
    
    -- Apply gravity when horizontal velocity is low enough
    local gravityThreshold = COORDINATE_CONSTANTS.GRAVITY_THRESHOLD -- Start gravity when horizontal speed is below this
    if math.abs(self.ballVx) < gravityThreshold then
        local gravity = COORDINATE_CONSTANTS.GRAVITY * self.gravityModifier -- units per second squared
        self.ballVy = self.ballVy - gravity * dt
    end
    
    -- Update ball position
    self.ballX = self.ballX + self.ballVx * dt
    self.ballY = self.ballY + self.ballVy * dt
    
    -- Handle wall wrapping (right edge) - Fixed logic
    if self.ballX >= 360 then
        self.ballX = self.ballX - 360 -- Wrap to left side properly
    end
    
    -- Handle ceiling collision (top edge)
    if self.ballY >= 100 then
        self.ballY = 100
        self.ballVy = 0 -- Stop vertical movement
    end
    
    -- Handle floor collision (bottom edge)
    if self.ballY <= -10 + self.ballRadius then
        self.ballY = -10 + self.ballRadius
        -- Bounce with energy loss
        local bounceFactor = 0.7 -- Retain 70% of velocity on bounce
        self.ballVy = math.abs(self.ballVy) * bounceFactor
        
        -- If ball is moving very slowly vertically, stop it
        if math.abs(self.ballVy) < 5 then
            self.ballVy = 0
        end
    end
    
    -- Check if ball has landed (stopped moving)
    if math.abs(self.ballVx) < 1 and math.abs(self.ballVy) < 1 and self.ballY <= -10 + self.ballRadius + 2 then
        -- Ball has landed, determine result based on x position
        local result = self:determineLandingResult(self.ballX)
        self:ballLanded(result)
        self.isSimulationRunning = false
    end
end

-- Determine the landing result based on x position
function RouletteSpinner:determineLandingResult(x)
    -- Simple result determination based on x position
    -- This can be expanded to match actual roulette wheel layout
    local result = math.floor(x / 10) % 37 -- 0-36 for roulette numbers
    return tostring(result)
end

-- Update the roulette spinner
function RouletteSpinner:update(dt)
    if  not inMenu and inGame then
        Cron.Update(dt) -- This is required for Cron to function
        
        -- Safety check: ensure object is properly initialized
        if not self or not self.isLoaded then
            return -- Exit early if not loaded or self is nil
        end
        
        -- Process simulation if running
        if self.isSimulationRunning then
            self:processSimulationFrame(dt)
        end
    end
end

-- Trigger the ball landed callback
function RouletteSpinner:ballLanded(result)
    if self.onBallLanded then
        self.onBallLanded(result)
    end
end

-- Debug function to spawn a 10x10 grid of balls to visualize the coordinate transformation
function RouletteSpinner:spawnDebugGrid()
    if not self.isLoaded then
        DualPrint("Error: Cannot spawn debug grid - spinner is not loaded")
        return false
    end
    
    -- Clear any existing debug balls
    self:clearDebugGrid()
    
    DualPrint("Spawning 10x10 debug grid of balls...")
    
    -- Create 10x10 grid spanning x=0-360, y=-10-100
    local gridSize = 10
    local xStep = 360 / (gridSize - 1)  -- 0 to 360 in 10 steps
    local yStep = 110 / (gridSize - 1)  -- -10 to 100 in 10 steps
    
    for i = 0, gridSize - 1 do
        for j = 0, gridSize - 1 do
            local simX = i * xStep
            local simY = -10 + (j * yStep)
            
            -- Translate simulator coordinates to world coordinates
            local worldCoords = self:translateToWorldCoords(simX, simY)
            
            if worldCoords then
                -- Spawn a debug ball at the calculated world position
                local ballSpec = StaticEntitySpec.new()
                ballSpec.templatePath = "boe6\\gambling_system_roulette\\q303_roulette_ball.ent"
                ballSpec.position = Vector4.new(worldCoords.x, worldCoords.y, worldCoords.z, 1.0)
                ballSpec.orientation = EulerAngles.ToQuat(EulerAngles.new(0, 0, 0))
                ballSpec.tags = {"rouletteDebugBall"}
                
                local debugBallID = Game.GetStaticEntitySystem():SpawnEntity(ballSpec)
                table.insert(self.debugBallEntities, debugBallID)
                
                DualPrint(string.format("Debug ball %d spawned at sim(%.1f, %.1f) -> world(%.3f, %.3f, %.3f)", 
                    #self.debugBallEntities, simX, simY, worldCoords.x, worldCoords.y, worldCoords.z))
            else
                DualPrint(string.format("Failed to translate coordinates for sim(%.1f, %.1f)", simX, simY))
            end
        end
    end
    
    DualPrint(string.format("Debug grid spawned: %d balls total", #self.debugBallEntities))
    return true
end

-- Clear all debug balls
function RouletteSpinner:clearDebugGrid()
    if self.debugBallEntities then
        for _, ballID in ipairs(self.debugBallEntities) do
            if ballID then
                Game.GetStaticEntitySystem():DespawnEntity(ballID)
            end
        end
        self.debugBallEntities = {}
        DualPrint("Debug grid cleared")
    end
end

return RouletteSpinner 