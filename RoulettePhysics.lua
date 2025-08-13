local RoulettePhysics = {
    version = "1.0.0"
}

-- Physics constants
local PHYSICS_CONSTANTS = {
    -- Physics constants
    HORIZONTAL_DECELERATION = 20, -- units per second squared
    GRAVITY = 50,                 -- units per second squared
    GRAVITY_THRESHOLD = 200,       -- Start gravity when horizontal speed is below this
    GRAVITY_MODIFIER = 1.0,       -- Overall gravity modifier (1.0 = normal gravity)
    
    -- Initial ball speed constants
    INITIAL_BALL_SPEED_MIN = 400, -- Minimum initial horizontal velocity (units/sec)
    INITIAL_BALL_SPEED_MAX = 600, -- Maximum initial horizontal velocity (units/sec)
    INITIAL_BALL_VERTICAL_SPEED = 0, -- Initial vertical velocity (units/sec)
    
    -- Moving block constants
    BLOCK_SPEED = 150, -- Block movement speed (units/sec) - opposite direction to ball
    BLOCK_WIDTH = 1,   -- Block width in simulator units
    BLOCK_HEIGHT = 10, -- Block height in simulator units
    NUM_BLOCKS = 37,   -- Total number of blocks (0-36 for roulette)
    BLOCK_SPACING = 360 / 37, -- Distance between blocks (360 degrees / 37 blocks)
    
    -- Fixed timestep constants
    FIXED_TIMESTEP = 1.0 / 60.0, -- 60 FPS fixed timestep (0.016667 seconds)
    MAX_ACCUMULATOR = 0.1, -- Maximum accumulated time to prevent spiral of death
    ENTITY_UPDATE_INTERVAL = 3, -- Update entity positions every N frames (reduces jitter)
    ROTATION_SMOOTHING_FACTOR = 0.1 -- Smoothing factor for rotation interpolation (0.1 = smooth, 1.0 = instant)
}

local CollisionCtR = require("CollisionCtR.lua")

-- Initialize the RoulettePhysics object
function RoulettePhysics:new()
    local obj = {
        -- Ball properties
        ballX = 0,                  -- Ball x coordinate
        ballY = 0,                  -- Ball y coordinate
        ballVx = 0,                 -- Ball x velocity
        ballVy = 0,                 -- Ball y velocity
        ballRadius = 5,             -- Ball radius size
        
        -- Direct ball properties
        directBallX = 0,            -- Direct ball x coordinate (no wrapping)
        directBallY = 0,            -- Direct ball y coordinate
        directBallVx = 0,           -- Direct ball x velocity
        directBallVy = 0,           -- Direct ball y velocity
        
        -- Moving block properties
        blocks = {},                -- Array of block objects with x, y, vx properties
        
        -- Physics properties
        gravityModifier = PHYSICS_CONSTANTS.GRAVITY_MODIFIER,
        
        -- State properties
        isSimulationRunning = false, -- Flag to track if simulation is active
        frameCounter = 0,           -- Counter for simulation frames
        onBallLanded = nil, -- Simple callback function for ball landing
        
        -- Collision properties
        lastCollisionFrame = 0,     -- Frame counter when last collision occurred
        collisionCooldown = 10,     -- Minimum frames between collisions to prevent sticking
        debugCollisions = false,     -- Enable/disable collision debug output
        
        -- Fixed timestep properties
        timeAccumulator = 0,        -- Accumulated time for fixed timestep
        lastEntityUpdateFrame = 0,  -- Last frame when entities were updated
        targetSpinnerRotation = 0,  -- Target rotation for smooth interpolation
        spinnerRotation = 0,        -- Current rotation angle in radians
    }
    setmetatable(obj, self)
    self.__index = self
    return obj
end

-- Start the roulette simulation
function RoulettePhysics:startSimulation()
    if self.isSimulationRunning then
        DualPrint("Warning: Simulation is already running")
        return false
    end
    
    DualPrint("Starting simulation - blocks array size: " .. #self.blocks)
    
    -- Initialize ball position
    self.ballX = 0  -- Start at left edge
    self.ballY = 100 -- Start at top
    -- Random horizontal velocity (positive x direction) - much faster now
    self.ballVx = math.random(PHYSICS_CONSTANTS.INITIAL_BALL_SPEED_MIN, PHYSICS_CONSTANTS.INITIAL_BALL_SPEED_MAX) -- Random velocity between 300-600 units/sec
    self.ballVy = PHYSICS_CONSTANTS.INITIAL_BALL_VERTICAL_SPEED -- Start with small downward velocity so ball falls immediately
    
    -- Initialize direct ball position
    self.directBallX = 0  -- Start at left edge (no wrapping)
    self.directBallY = 100 -- Start at top
    self.directBallVx = self.ballVx -- Same velocity as main ball
    self.directBallVy = self.ballVy -- Same velocity as main ball
    
    DualPrint("Ball initialized: X=" .. self.ballX .. ", Y=" .. self.ballY .. ", VX=" .. self.ballVx .. ", VY=" .. self.ballVy)
    DualPrint("Direct ball initialized: X=" .. self.directBallX .. ", Y=" .. self.directBallY .. ", VX=" .. self.directBallVx .. ", VY=" .. self.directBallVy)
    
    -- Initialize all blocks with positions and velocities (opposite direction to ball)
    for i = 1, #self.blocks do
        local blockX = (i - 1) * PHYSICS_CONSTANTS.BLOCK_SPACING
        local blockY = -10 -- Start at bottom (10 units tall, so covers -10 to 0)
        local blockVx = -PHYSICS_CONSTANTS.BLOCK_SPEED -- Move opposite to ball direction
        
        self.blocks[i].x = blockX
        self.blocks[i].y = blockY
        self.blocks[i].vx = blockVx
        
        DualPrint('Block ' .. (i-1) .. ' initialized: X=' .. blockX .. ', Y=' .. blockY .. ', VX=' .. blockVx)
    end
    
    -- Reset frame counter
    self.frameCounter = 0
    
    self.isSimulationRunning = true
    DualPrint("Simulation started successfully")
    return true
end

-- Stop the roulette simulation
function RoulettePhysics:stopSimulation()
    if not self.isSimulationRunning then
        DualPrint("Warning: Simulation is not running")
        return false
    end
    
    self.isSimulationRunning = false
    DualPrint("Simulation stopped")
    return true
end

-- Process a single simulation frame
function RoulettePhysics:processSimulationFrame(dt)
    -- Increment frame counter
    self.frameCounter = self.frameCounter + 1
    
    -- Fixed timestep physics
    self.timeAccumulator = self.timeAccumulator + dt
    
    -- Clamp accumulator to prevent spiral of death
    if self.timeAccumulator > PHYSICS_CONSTANTS.MAX_ACCUMULATOR then
        self.timeAccumulator = PHYSICS_CONSTANTS.MAX_ACCUMULATOR
    end
    
    -- Process physics with fixed timestep
    while self.timeAccumulator >= PHYSICS_CONSTANTS.FIXED_TIMESTEP do
        self:processFixedTimestep(PHYSICS_CONSTANTS.FIXED_TIMESTEP)
        self.timeAccumulator = self.timeAccumulator - PHYSICS_CONSTANTS.FIXED_TIMESTEP
    end
    
    -- Update entity positions less frequently to reduce jitter
    if self.frameCounter - self.lastEntityUpdateFrame >= PHYSICS_CONSTANTS.ENTITY_UPDATE_INTERVAL then
        self:updateEntityPositions()
        self.lastEntityUpdateFrame = self.frameCounter
    end
    
    -- Check if we've reached 3000 frames (increased from 1000)
    if self.frameCounter >= 3000 then
        DualPrint("Simulation ended after 3000 frames")
        self.isSimulationRunning = false
        return
    end
end

-- Process physics with fixed timestep
function RoulettePhysics:processFixedTimestep(fixedDt)
    -- Debug output every 300 frames to track movement (reduced frequency)
    if self.frameCounter % 300 == 0 then
        DualPrint("Frame " .. self.frameCounter .. ": Ball at (" .. self.ballX .. ", " .. self.ballY .. ") vel(" .. self.ballVx .. ", " .. self.ballVy .. ")")
        DualPrint("Direct ball at (" .. self.directBallX .. ", " .. self.directBallY .. ") vel(" .. self.directBallVx .. ", " .. self.directBallVy .. ")")
        
        -- Check block spacing every 300 frames
        DualPrint("=== Block Spacing Check ===")
        local simulationTime = self.frameCounter * PHYSICS_CONSTANTS.FIXED_TIMESTEP
        DualPrint("Simulation time: " .. simulationTime .. " seconds")
        for i = 1, math.min(3, #self.blocks) do -- Check first 3 blocks only
            local expectedX = (i - 1) * PHYSICS_CONSTANTS.BLOCK_SPACING
            local actualX = self.blocks[i].x
            local spacingError = math.abs(actualX - expectedX)
            DualPrint(string.format("Block %d: Expected X=%.3f, Actual X=%.3f, Error=%.3f", 
                i-1, expectedX, actualX, spacingError))
        end
        DualPrint("=== End Spacing Check ===")
    end
    
    -- Apply horizontal deceleration (faster deceleration)
    local horizontalDeceleration = PHYSICS_CONSTANTS.HORIZONTAL_DECELERATION -- units per second squared (increased from 20)
    if self.ballVx > 0 then
        self.ballVx = math.max(0, self.ballVx - horizontalDeceleration * fixedDt)
    elseif self.ballVx < 0 then
        self.ballVx = math.min(0, self.ballVx + horizontalDeceleration * fixedDt)
    end
    
    -- Apply gravity when horizontal velocity is low enough
    local gravityThreshold = PHYSICS_CONSTANTS.GRAVITY_THRESHOLD -- Start gravity when horizontal speed is below this
    if math.abs(self.ballVx) < gravityThreshold then
        local gravity = PHYSICS_CONSTANTS.GRAVITY * self.gravityModifier -- units per second squared
        self.ballVy = self.ballVy - gravity * fixedDt
    end
    
    -- Store previous positions for collision detection
    local prevBallX = self.ballX
    local prevBallY = self.ballY
    
    -- Update ball position
    self.ballX = self.ballX + self.ballVx * fixedDt
    self.ballY = self.ballY + self.ballVy * fixedDt
    
    -- Handle wall wrapping (both edges) - Fixed logic
    if self.ballX >= 360 then
        self.ballX = self.ballX - 360 -- Wrap to left side properly
    elseif self.ballX < 0 then
        self.ballX = self.ballX + 360 -- Wrap to right side properly
    end
    
    -- Update direct ball position to match main ball exactly
    self.directBallX = self.ballX  -- Use same X position as main ball (already wrapped)
    self.directBallY = self.ballY  -- Use same Y position as main ball
    self.directBallVx = self.ballVx  -- Use same X velocity as main ball
    self.directBallVy = self.ballVy  -- Use same Y velocity as main ball
    
    -- Update block position using fixed timestep calculation to maintain perfect spacing
    local simulationTime = self.frameCounter * PHYSICS_CONSTANTS.FIXED_TIMESTEP
    for i = 1, #self.blocks do
        -- Calculate position based on initial position and time
        local initialX = (i - 1) * PHYSICS_CONSTANTS.BLOCK_SPACING
        local currentX = initialX + (self.blocks[i].vx * simulationTime)
        
        -- Handle wrapping to maintain position in 0-360 range
        while currentX < 0 do
            currentX = currentX + 360
        end
        while currentX >= 360 do
            currentX = currentX - 360
        end
        
        self.blocks[i].x = currentX
    end
    
    -- Check for collision between ball and moving blocks
    self:checkBallBlockCollision(prevBallX, prevBallY, fixedDt)
    
    -- Debug output for collision detection (every 60 frames)
    if self.debugCollisions and self.frameCounter % 60 == 0 then
        self:debugCollisionInfo()
    end
    
    -- Update target spinner rotation (smooth interpolation)
    self.targetSpinnerRotation = math.rad(self.blocks[1].x) -- Convert block X position directly to radians
    
    -- Smooth interpolation of spinner rotation to prevent jerky movement
    local rotationDiff = self.targetSpinnerRotation - self.spinnerRotation
    
    -- Handle angle wrapping for smooth interpolation
    if rotationDiff > math.pi then
        rotationDiff = rotationDiff - 2 * math.pi
    elseif rotationDiff < -math.pi then
        rotationDiff = rotationDiff + 2 * math.pi
    end
    
    -- Smooth interpolation towards target rotation
    self.spinnerRotation = self.spinnerRotation + rotationDiff * PHYSICS_CONSTANTS.ROTATION_SMOOTHING_FACTOR
    
    -- Normalize rotation to 0-2π range
    while self.spinnerRotation < 0 do
        self.spinnerRotation = self.spinnerRotation + 2 * math.pi
    end
    while self.spinnerRotation >= 2 * math.pi do
        self.spinnerRotation = self.spinnerRotation - 2 * math.pi
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

-- Update entity positions (separated from physics to reduce jitter)
function RoulettePhysics:updateEntityPositions()
    -- This function will be called by the main RouletteSpinner to update visual entities
    -- The physics module only handles the simulation, not the visual representation
    if self.onEntityUpdate then
        self.onEntityUpdate(self.ballX, self.ballY, self.directBallX, self.directBallY, self.spinnerRotation)
    end
end

-- Check for collision between ball and moving blocks
function RoulettePhysics:checkBallBlockCollision(prevBallX, prevBallY, dt)
    -- Check collision cooldown to prevent sticking
    if self.frameCounter - self.lastCollisionFrame < self.collisionCooldown then
        return
    end
    
    -- Define the ball as a circle
    local ball = {
        x = self.ballX,
        y = self.ballY,
        radius = self.ballRadius
    }
    
    -- Check for collision with any block
    local collision = false
    for i = 1, #self.blocks do
        local block = {
            x = self.blocks[i].x,
            y = self.blocks[i].y,
            width = PHYSICS_CONSTANTS.BLOCK_WIDTH,
            height = PHYSICS_CONSTANTS.BLOCK_HEIGHT
        }
        
        collision = CollisionCtR:checkCollision(ball, block)
        if collision then
            break
        end
    end
    
    if collision then
        -- Handle collision response
        self:handleBallBlockCollision(prevBallX, prevBallY, dt)
    else
        -- Check for tunneling (high-speed collision that might be missed)
        local prevBall = {
            x = prevBallX,
            y = prevBallY,
            radius = self.ballRadius
        }
        
        local tunneling = false
        for i = 1, #self.blocks do
            local block = {
                x = self.blocks[i].x,
                y = self.blocks[i].y,
                width = PHYSICS_CONSTANTS.BLOCK_WIDTH,
                height = PHYSICS_CONSTANTS.BLOCK_HEIGHT
            }
            
            tunneling = CollisionCtR:checkTunneling(prevBall, ball, block)
            if tunneling then
                break
            end
        end
        
        if tunneling then
            -- Handle tunneling collision
            self:handleBallBlockCollision(prevBallX, prevBallY, dt)
        end
    end
end

-- Handle collision response between ball and block
function RoulettePhysics:handleBallBlockCollision(prevBallX, prevBallY, dt)
    DualPrint("Ball collided with moving block!")
    
    -- Find the first colliding block
    local collidingBlockIndex = nil
    for i = 1, #self.blocks do
        local block = {
            x = self.blocks[i].x,
            y = self.blocks[i].y,
            width = PHYSICS_CONSTANTS.BLOCK_WIDTH,
            height = PHYSICS_CONSTANTS.BLOCK_HEIGHT
        }
        
        if CollisionCtR:checkCollision({x = self.ballX, y = self.ballY, radius = self.ballRadius}, block) then
            collidingBlockIndex = i
            break
        end
    end
    
    if not collidingBlockIndex then
        DualPrint("Warning: No colliding block found!")
        return
    end
    
    local collidingBlock = self.blocks[collidingBlockIndex]
    
    -- Define the ball with velocity for collision response
    local ball = {
        x = self.ballX,
        y = self.ballY,
        radius = self.ballRadius,
        vx = self.ballVx,
        vy = self.ballVy
    }
    
    -- Define the block edges for collision response
    local leftEdge = {
        x = collidingBlock.x,
        vx = collidingBlock.vx,
        isRight = false
    }
    
    local rightEdge = {
        x = collidingBlock.x + PHYSICS_CONSTANTS.BLOCK_WIDTH,
        vx = collidingBlock.vx,
        isRight = true
    }
    
    local topEdge = {
        y = collidingBlock.y + PHYSICS_CONSTANTS.BLOCK_HEIGHT,
        vx = collidingBlock.vx
    }
    
    -- Determine which edge the ball collided with and calculate response
    local newVelocity = {vx = self.ballVx, vy = self.ballVy}
    
    -- Check horizontal edge collisions
    if ball.x - ball.radius <= leftEdge.x then
        -- Collision with left edge
        newVelocity = CollisionCtR:calculateHorizontalEdgeCollisionVelocity(ball, leftEdge)
        DualPrint("Ball collided with left edge of block " .. (collidingBlockIndex - 1))
    elseif ball.x + ball.radius >= rightEdge.x then
        -- Collision with right edge
        newVelocity = CollisionCtR:calculateHorizontalEdgeCollisionVelocity(ball, rightEdge)
        DualPrint("Ball collided with right edge of block " .. (collidingBlockIndex - 1))
    end
    
    -- Check top edge collision
    if ball.y + ball.radius >= topEdge.y then
        local topCollisionVelocity = CollisionCtR:calculateTopEdgeCollisionVelocity(ball, topEdge)
        -- Use the more significant collision response
        if math.abs(topCollisionVelocity.vy) > math.abs(newVelocity.vy) then
            newVelocity = topCollisionVelocity
            DualPrint("Ball collided with top edge of block " .. (collidingBlockIndex - 1))
        end
    end
    
    -- Apply the new velocity with some energy loss
    local energyLoss = 0.6 -- Retain 60% of velocity after collision (reduced from 80% to be more conservative)
    self.ballVx = newVelocity.vx * energyLoss
    self.ballVy = newVelocity.vy * energyLoss
    
    -- Clamp velocities to prevent extreme values
    local maxVelocity = 1000 -- Maximum allowed velocity
    if math.abs(self.ballVx) > maxVelocity then
        self.ballVx = (self.ballVx > 0 and 1 or -1) * maxVelocity
    end
    if math.abs(self.ballVy) > maxVelocity then
        self.ballVy = (self.ballVy > 0 and 1 or -1) * maxVelocity
    end
    
    -- Move ball slightly away from block to prevent sticking
    local separationDistance = 0.5
    if ball.x < collidingBlock.x + PHYSICS_CONSTANTS.BLOCK_WIDTH / 2 then
        self.ballX = collidingBlock.x - self.ballRadius - separationDistance
    else
        self.ballX = collidingBlock.x + PHYSICS_CONSTANTS.BLOCK_WIDTH + self.ballRadius + separationDistance
    end
    
    -- Safety check: if position adjustment pushed ball too far, clamp it
    if self.ballX < -100 or self.ballX > 460 then
        if self.ballX < 0 then
            self.ballX = 0
        elseif self.ballX >= 360 then
            self.ballX = 359
        end
    end
    
    -- Handle wrapping for ball position after collision (ensure it stays in 0-360 range)
    while self.ballX < 0 do
        self.ballX = self.ballX + 360
    end
    while self.ballX >= 360 do
        self.ballX = self.ballX - 360
    end
    
    -- Set collision cooldown
    self.lastCollisionFrame = self.frameCounter
end

-- Debug function to show collision information
function RoulettePhysics:debugCollisionInfo()
    local ball = {
        x = self.ballX,
        y = self.ballY,
        radius = self.ballRadius
    }
    
    local collisionFound = false
    for i = 1, #self.blocks do
        local block = {
            x = self.blocks[i].x,
            y = self.blocks[i].y,
            width = PHYSICS_CONSTANTS.BLOCK_WIDTH,
            height = PHYSICS_CONSTANTS.BLOCK_HEIGHT
        }
        
        local collision = CollisionCtR:checkCollision(ball, block)
        if collision then
            DualPrint(string.format("Debug - Ball: (%.1f, %.1f) r=%.1f, Block %d: (%.1f, %.1f) w=%.1f h=%.1f, Collision: YES", 
                ball.x, ball.y, ball.radius, 
                i-1, block.x, block.y, block.width, block.height))
            collisionFound = true
            break
        end
    end
    
    if not collisionFound then
        DualPrint(string.format("Debug - Ball: (%.1f, %.1f) r=%.1f, No collision with any block", 
            ball.x, ball.y, ball.radius))
    end
end

-- Enable collision debugging
function RoulettePhysics:enableCollisionDebug()
    self.debugCollisions = true
    DualPrint("Collision debugging enabled")
end

-- Disable collision debugging
function RoulettePhysics:disableCollisionDebug()
    self.debugCollisions = false
    DualPrint("Collision debugging disabled")
end

-- Set rotation smoothing factor
function RoulettePhysics:setRotationSmoothing(factor)
    if factor < 0.01 or factor > 1.0 then
        DualPrint("Error: Rotation smoothing factor must be between 0.01 and 1.0")
        return false
    end
    
    PHYSICS_CONSTANTS.ROTATION_SMOOTHING_FACTOR = factor
    DualPrint("Rotation smoothing factor set to: " .. factor)
    return true
end

-- Get current rotation smoothing factor
function RoulettePhysics:getRotationSmoothing()
    return PHYSICS_CONSTANTS.ROTATION_SMOOTHING_FACTOR
end

-- Determine the landing result based on x position
function RoulettePhysics:determineLandingResult(x)
    -- Simple result determination based on x position
    -- This can be expanded to match actual roulette wheel layout
    local result = math.floor(x / 10) % 37 -- 0-36 for roulette numbers
    return tostring(result)
end

-- Trigger the ball landed callback
function RoulettePhysics:ballLanded(result)
    if self.onBallLanded then
        self.onBallLanded(result)
    end
end

-- Set callback for entity updates
function RoulettePhysics:setEntityUpdateCallback(callback)
    self.onEntityUpdate = callback
end

-- Get current ball position
function RoulettePhysics:getBallPosition()
    return self.ballX, self.ballY
end

-- Get current direct ball position
function RoulettePhysics:getDirectBallPosition()
    return self.directBallX, self.directBallY
end

-- Get current spinner rotation
function RoulettePhysics:getSpinnerRotation()
    return self.spinnerRotation
end

-- Get current blocks
function RoulettePhysics:getBlocks()
    return self.blocks
end

-- Set blocks (called by main RouletteSpinner)
function RoulettePhysics:setBlocks(blocks)
    self.blocks = blocks
end

-- Set ball landed callback
function RoulettePhysics:setBallLandedCallback(callback)
    self.onBallLanded = callback
end

return RoulettePhysics 