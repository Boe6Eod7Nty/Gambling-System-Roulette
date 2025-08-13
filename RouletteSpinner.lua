local RouletteSpinner = {
    version = "1.0.0"
}

-- Moving block feature: 37 blocks that move opposite to the ball direction
-- Blocks are equidistantly spread across the x dimension (0-360)
-- Each block moves at the same speed and wraps from left to right edge
-- Creates slots for the roulette ball to land in

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
    
    -- Moving block constants
    NUM_BLOCKS = 37,   -- Total number of blocks (0-36 for roulette)
    BLOCK_SPACING = 360 / 37, -- Distance between blocks (360 degrees / 37 blocks)
    
    -- 2D Plane Visualization constants (NEW!)
    DIRECT_BALL_X_SCALE = 0.005,    -- Scale factor for X coordinate mapping (adjustable)
    DIRECT_BALL_Y_SCALE = 0.01,    -- Scale factor for Y coordinate mapping (adjustable)
    DIRECT_BALL_BASE_HEIGHT = 0.65, -- Base height offset for 2D plane visualization
    DIRECT_BALL_HEIGHT_RANGE = 0.4, -- Total height range in meters for 2D plane
    DIRECT_BALL_OFFSET = {x = 0.5, y = 0, z = 0.15}, -- Offset from spinner center for 2D plane
}

local Cron = require('External/Cron.lua')
local GameUI = require("External/GameUI.lua")
local RoulettePhysics = require("RoulettePhysics.lua")

local inMenu = true --libaries requirement
local inGame = false

-- Initialize the RouletteSpinner object
function RouletteSpinner:new()
    local obj = {
        -- Spinner properties
        spinnerCenter = nil,
        spinnerRotation = 0,        -- Current rotation angle in radians
        spinnerVelocity = 0,        -- Angular velocity (rotation speed) in radians per second
        
        -- Entity IDs
        ballEntityID = nil,         -- Entity ID for the roulette ball
        directBallEntityID = nil,   -- Entity ID for the direct ball (NEW!)
        cornerBallEntityIDs = {},   -- Array to track corner ball entities (NEW!)
        spinnerEntityID = nil,      -- Entity ID for the roulette spinner
        debugBallEntities = {},     -- Array to track debug ball entities
        
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
        
        -- 2D Plane visualization properties (NEW!)
        directBallXScale = COORDINATE_CONSTANTS.DIRECT_BALL_X_SCALE,
        directBallYScale = COORDINATE_CONSTANTS.DIRECT_BALL_Y_SCALE,
        directBallBaseHeight = COORDINATE_CONSTANTS.DIRECT_BALL_BASE_HEIGHT,
        directBallHeightRange = COORDINATE_CONSTANTS.DIRECT_BALL_HEIGHT_RANGE,
        directBallOffset = COORDINATE_CONSTANTS.DIRECT_BALL_OFFSET,
        
        -- State properties
        isLoaded = false,
        onBallLanded = nil, -- Simple callback function for ball landing
        
        -- Physics module
        physics = nil,              -- RoulettePhysics instance
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
    
    -- Spawn the direct ball entity (NEW!)
    local directBallSpec = StaticEntitySpec.new()
    directBallSpec.templatePath = "boe6\\gambling_system_roulette\\q303_roulette_ball.ent"
    -- Position the direct ball higher up and further away from the spinner for visibility
    local directBallOffset = self.directBallOffset -- Use configurable offset
    directBallSpec.position = Vector4.new(spinnerCenter.x + directBallOffset.x, spinnerCenter.y + directBallOffset.y, spinnerCenter.z + directBallOffset.z, 1.0)
    directBallSpec.orientation = EulerAngles.ToQuat(EulerAngles.new(0, 0, 0))
    directBallSpec.tags = {"rouletteDirectBall"}
    
    self.directBallEntityID = Game.GetStaticEntitySystem():SpawnEntity(directBallSpec)
    DualPrint('Direct ball entity spawned with ID: ' .. tostring(self.directBallEntityID))
    
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
    
    -- Spawn 4 corner balls to visualize the 2D plane boundaries (NEW!)
    -- Moved here after spinnerCenter is set and isLoaded is true
    self:spawnCornerBalls()
    
    -- Initialize physics module
    self.physics = RoulettePhysics:new()
    
    -- Initialize all 37 moving blocks (no visual entities)
    local blocks = {}
    
    for i = 0, COORDINATE_CONSTANTS.NUM_BLOCKS - 1 do
        local blockX = i * COORDINATE_CONSTANTS.BLOCK_SPACING
        table.insert(blocks, {x = blockX, y = -10, vx = 0}) -- Initialize with 0 velocity, will be set in startSimulation
        
        DualPrint('Block ' .. i .. ' initialized at position X=' .. blockX .. ', Y=-10')
    end
    
    -- Set blocks in physics module
    self.physics:setBlocks(blocks)
    
    DualPrint('All ' .. COORDINATE_CONSTANTS.NUM_BLOCKS .. ' blocks initialized successfully')
    
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
    -- (base angle for simulator's 0,0) + (simulator's X position as an angle)
    -- Ball moves independently of spinner rotation
    local currentBallAngleRad = baseOriginAngle + math.rad(simX)

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

-- Translate direct simulator coordinates to 3D world coordinates (FIXED!)
function RouletteSpinner:translateDirectToWorldCoords(simX, simY)
    if not self.isLoaded then
        DualPrint("Error: Cannot translate coordinates - spinner is not loaded")
        return nil
    end

    -- For a vertical wall: simX maps to worldX, simY maps to worldZ (height), worldY is fixed
    local centerX = self.spinnerCenter.x
    local centerY = self.spinnerCenter.y
    local centerZ = self.spinnerCenter.z
    
    -- Use configurable scale factors
    local xScale = self.directBallXScale
    
    -- Map simulator Y (-10 to 100) to real-world Z height using configurable range
    -- This creates a vertical wall where top corners are above bottom corners
    local baseHeight = self.directBallBaseHeight
    local heightRange = self.directBallHeightRange
    local simYRange = 110 -- Simulator Y range (100 - (-10))
    
    -- Calculate height mapping: simY of -10 maps to baseHeight, simY of 100 maps to baseHeight + heightRange
    local heightProgress = (simY - (-10)) / simYRange -- 0 to 1
    local dynamicHeight = baseHeight + (heightProgress * heightRange)
    
    -- Vertical wall mapping:
    -- simX → worldX (horizontal position)
    -- simY → worldZ (vertical height, since Z is up)
    -- worldY is fixed (depth into screen)
    local finalX = centerX + (simX * xScale)
    local finalY = centerY + self.directBallOffset.y -- Fixed Y position (depth)
    local finalZ = centerZ + dynamicHeight

    return {
        x = finalX,
        y = finalY,
        z = finalZ
    }
end

-- Spawn 4 corner balls to visualize the 2D plane boundaries (NEW!)
function RouletteSpinner:spawnCornerBalls()
    -- Clear any existing corner balls
    self:clearCornerBalls()
    
    DualPrint("Debug: Starting corner ball spawning...")
    DualPrint("Debug: spinnerCenter = " .. tostring(self.spinnerCenter and "set" or "nil"))
    DualPrint("Debug: isLoaded = " .. tostring(self.isLoaded))
    
    -- Define the 4 corners of the 2D simulator plane
    local corners = {
        {x = 0, y = -10, name = "Bottom-Left"},      -- Bottom-left corner
        {x = 360, y = -10, name = "Bottom-Right"},   -- Bottom-right corner  
        {x = 0, y = 100, name = "Top-Left"},         -- Top-left corner
        {x = 360, y = 100, name = "Top-Right"}       -- Top-right corner
    }
    
    for i, corner in ipairs(corners) do
        DualPrint(string.format("Debug: Processing corner %s at sim(%.1f, %.1f)", corner.name, corner.x, corner.y))
        
        -- Translate corner coordinates to world coordinates
        local worldCoords = self:translateDirectToWorldCoords(corner.x, corner.y)
        
        if worldCoords then
            DualPrint(string.format("Debug: Translation successful for %s: world(%.3f, %.3f, %.3f)", 
                corner.name, worldCoords.x, worldCoords.y, worldCoords.z))
            
            -- Spawn a corner ball at the calculated world position
            local cornerBallSpec = StaticEntitySpec.new()
            cornerBallSpec.templatePath = "boe6\\gambling_system_roulette\\q303_roulette_ball.ent"
            cornerBallSpec.position = Vector4.new(worldCoords.x, worldCoords.y, worldCoords.z, 1.0)
            cornerBallSpec.orientation = EulerAngles.ToQuat(EulerAngles.new(0, 0, 0))
            cornerBallSpec.tags = {"rouletteCornerBall"}
            
            local cornerBallID = Game.GetStaticEntitySystem():SpawnEntity(cornerBallSpec)
            table.insert(self.cornerBallEntityIDs, cornerBallID)
            
            DualPrint(string.format("Corner ball %s spawned at sim(%.1f, %.1f) -> world(%.3f, %.3f, %.3f)", 
                corner.name, corner.x, corner.y, worldCoords.x, worldCoords.y, worldCoords.z))
        else
            DualPrint(string.format("Failed to translate coordinates for corner %s at sim(%.1f, %.1f)", 
                corner.name, corner.x, corner.y))
        end
    end
    
    DualPrint(string.format("Corner balls spawned: %d balls total", #self.cornerBallEntityIDs))
end

-- Clear all corner balls (NEW!)
function RouletteSpinner:clearCornerBalls()
    if self.cornerBallEntityIDs then
        for _, ballID in ipairs(self.cornerBallEntityIDs) do
            if ballID then
                Game.GetStaticEntitySystem():DespawnEntity(ballID)
            end
        end
        self.cornerBallEntityIDs = {}
        DualPrint("Corner balls cleared")
    end
end

-- Unload the roulette spinner
function RouletteSpinner:unload()
    if not self.isLoaded then
        DualPrint("Warning: Spinner is not loaded. Nothing to unload.")
        return false
    end
    
    -- Stop simulation if it's running
    if self.physics and self.physics.isSimulationRunning then
        self.physics:stopSimulation()
    end
    
    -- Clear debug grid
    self:clearDebugGrid()
    
    -- Delete the ball entity if it exists
    if self.ballEntityID then
        Game.GetStaticEntitySystem():DespawnEntity(self.ballEntityID)
        DualPrint('Ball entity deleted with ID: ' .. tostring(self.ballEntityID))
        self.ballEntityID = nil
    end
    
    -- Delete the direct ball entity if it exists (NEW!)
    if self.directBallEntityID then
        Game.GetStaticEntitySystem():DespawnEntity(self.directBallEntityID)
        DualPrint('Direct ball entity deleted with ID: ' .. tostring(self.directBallEntityID))
        self.directBallEntityID = nil
    end
    
    -- Clear corner balls (NEW!)
    self:clearCornerBalls()
    
    -- Delete the spinner entity if it exists
    if self.spinnerEntityID then
        Game.GetStaticEntitySystem():DespawnEntity(self.spinnerEntityID)
        DualPrint('Spinner entity deleted with ID: ' .. tostring(self.spinnerEntityID))
        self.spinnerEntityID = nil
    end
    
    -- Clear physics module
    self.physics = nil
    
    -- Reset all properties to initial state
    self.spinnerCenter = nil
    self.spinnerRotation = 0
    self.spinnerVelocity = 0
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
    
    -- Reset 2D plane visualization properties (NEW!)
    self.directBallXScale = COORDINATE_CONSTANTS.DIRECT_BALL_X_SCALE
    self.directBallYScale = COORDINATE_CONSTANTS.DIRECT_BALL_Y_SCALE
    self.directBallBaseHeight = COORDINATE_CONSTANTS.DIRECT_BALL_BASE_HEIGHT
    self.directBallHeightRange = COORDINATE_CONSTANTS.DIRECT_BALL_HEIGHT_RANGE
    self.directBallOffset = COORDINATE_CONSTANTS.DIRECT_BALL_OFFSET
    
    self.isLoaded = false
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
    
    -- Set up callbacks for physics module
    self.physics:setBallLandedCallback(function(result)
        if self.onBallLanded then
            self.onBallLanded(result)
        end
    end)
    
    self.physics:setEntityUpdateCallback(function(ballX, ballY, directBallX, directBallY, spinnerRotation)
        self:updateEntityPositions(ballX, ballY, directBallX, directBallY, spinnerRotation)
    end)
    
    -- Start physics simulation
    return self.physics:startSimulation()
end

-- Stop the roulette simulation
function RouletteSpinner:stopSimulation()
    if not self.physics then
        DualPrint("Warning: Physics module not initialized")
        return false
    end
    
    return self.physics:stopSimulation()
end

-- Update the roulette spinner
function RouletteSpinner:update(dt)
    Cron.Update(dt) -- This is required for Cron to function
    
    -- Safety check: ensure object is properly initialized
    if not self or not self.isLoaded then
        return -- Exit early if not loaded or self is nil
    end
    
    -- Process simulation if running
    if self.physics and self.physics.isSimulationRunning then
        self.physics:processSimulationFrame(dt)
    end
end



-- Update entity positions (separated from physics to reduce jitter)
function RouletteSpinner:updateEntityPositions(ballX, ballY, directBallX, directBallY, spinnerRotation)
    -- Translate simulator coordinates to world coordinates and teleport the ball
    local worldCoords = self:translateToWorldCoords(ballX, ballY)
    if worldCoords and self.ballEntityID then
        -- Teleport the ball to the new world position
        local ballEntity = Game.FindEntityByID(self.ballEntityID)
        if ballEntity then
            local newPosition = Vector4.new(worldCoords.x, worldCoords.y, worldCoords.z, 1.0)
            Game.GetTeleportationFacility():Teleport(ballEntity, newPosition, EulerAngles.new(0, 0, 0))
        end
    end
    
    -- Update direct ball position
    local directWorldCoords = self:translateDirectToWorldCoords(directBallX, directBallY)
    if directWorldCoords and self.directBallEntityID then
        local directBallEntity = Game.FindEntityByID(self.directBallEntityID)
        if directBallEntity then
            local newDirectPosition = Vector4.new(directWorldCoords.x, directWorldCoords.y, directWorldCoords.z, 1.0)
            Game.GetTeleportationFacility():Teleport(directBallEntity, newDirectPosition, EulerAngles.new(0, 0, 0))
        end
    end
    
    -- Update spinner entity rotation
    if self.spinnerEntityID then
        local spinnerEntity = Game.FindEntityByID(self.spinnerEntityID)
        if spinnerEntity then
            -- Apply rotation around Z-axis (spinner spins horizontally)
            local newOrientation = EulerAngles.new(0, 0, math.deg(spinnerRotation))
            Game.GetTeleportationFacility():Teleport(spinnerEntity, spinnerEntity:GetWorldPosition(), newOrientation)
        end
    end
end



-- Enable collision debugging
function RouletteSpinner:enableCollisionDebug()
    if self.physics then
        self.physics:enableCollisionDebug()
    end
end

-- Disable collision debugging
function RouletteSpinner:disableCollisionDebug()
    if self.physics then
        self.physics:disableCollisionDebug()
    end
end

-- Set rotation smoothing factor
function RouletteSpinner:setRotationSmoothing(factor)
    if self.physics then
        return self.physics:setRotationSmoothing(factor)
    end
    return false
end

-- Get current rotation smoothing factor
function RouletteSpinner:getRotationSmoothing()
    if self.physics then
        return self.physics:getRotationSmoothing()
    end
    return 0.1
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

-- Set 2D plane visualization scale (NEW!)
function RouletteSpinner:setDirectBallScale(xScale, yScale)
    if not self.isLoaded then
        DualPrint("Error: Cannot set scale - spinner is not loaded")
        return false
    end
    
    self.directBallXScale = xScale or self.directBallXScale
    self.directBallYScale = yScale or self.directBallYScale
    
    DualPrint(string.format("Direct ball scale set to X=%.4f, Y=%.4f", self.directBallXScale, self.directBallYScale))
    
    -- Respawn corner balls with new scale
    self:spawnCornerBalls()
    
    return true
end

-- Set 2D plane visualization height range (NEW!)
function RouletteSpinner:setDirectBallHeightRange(baseHeight, heightRange)
    if not self.isLoaded then
        DualPrint("Error: Cannot set height range - spinner is not loaded")
        return false
    end
    
    self.directBallBaseHeight = baseHeight or self.directBallBaseHeight
    self.directBallHeightRange = heightRange or self.directBallHeightRange
    
    DualPrint(string.format("Direct ball height range set to base=%.3f, range=%.3f", self.directBallBaseHeight, self.directBallHeightRange))
    
    -- Respawn corner balls with new height range
    self:spawnCornerBalls()
    
    return true
end

-- Get current 2D plane visualization settings (NEW!)
function RouletteSpinner:getDirectBallSettings()
    return {
        xScale = self.directBallXScale,
        yScale = self.directBallYScale,
        baseHeight = self.directBallBaseHeight,
        heightRange = self.directBallHeightRange,
        offset = self.directBallOffset
    }
end

-- Debug function to manually spawn corner balls (NEW!)
function RouletteSpinner:debugSpawnCornerBalls()
    if not self.isLoaded then
        DualPrint("Error: Cannot spawn corner balls - spinner is not loaded")
        return false
    end
    
    DualPrint("Debug: Manually spawning corner balls...")
    DualPrint("Debug: spinnerCenter = " .. tostring(self.spinnerCenter and "set" or "nil"))
    DualPrint("Debug: isLoaded = " .. tostring(self.isLoaded))
    
    self:spawnCornerBalls()
    return true
end

return RouletteSpinner 