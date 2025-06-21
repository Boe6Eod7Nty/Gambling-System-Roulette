local RouletteSpinner = {
    version = "1.0.0"
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
        
        -- Physics properties
        gravityModifier = 1.0,      -- Overall gravity modifier (1.0 = normal gravity)
        
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
function RouletteSpinner:init()
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
function RouletteSpinner:load(spinnerCenter)
    if not spinnerCenter then
        print("Error: spinnerCenter parameter is required")
        return false
    end
    
    if self.isLoaded then
        print("Warning: Spinner is already loaded. Unload first to reload.")
        return false
    end
    
    self.spinnerCenter = spinnerCenter
    self.isLoaded = true
    -- Load implementation here
    return true
end

-- Unload the roulette spinner
function RouletteSpinner:unload()
    if not self.isLoaded then
        print("Warning: Spinner is not loaded. Nothing to unload.")
        return false
    end
    
    self.spinnerCenter = nil
    self.isLoaded = false
    -- Unload implementation here
    return true
end

-- Start the roulette simulation
function RouletteSpinner:startSimulation()
    if not self.isLoaded then
        print("Error: Cannot start simulation - spinner is not loaded")
        return false
    end
    
    if self.isSimulationRunning then
        print("Warning: Simulation is already running")
        return false
    end
    
    -- Initialize ball position
    self.ballX = 0  -- Start at left edge
    self.ballY = 90 -- Start near top
    -- Random horizontal velocity (positive x direction)
    self.ballVx = math.random(50, 150) -- Random velocity between 50-150 units/sec
    self.ballVy = 0 -- Start with no vertical velocity
    
    -- Reset frame counter
    self.frameCounter = 0
    
    self.isSimulationRunning = true
    print("Simulation started")
    return true
end

-- Stop the roulette simulation
function RouletteSpinner:stopSimulation()
    if not self.isSimulationRunning then
        print("Warning: Simulation is not running")
        return false
    end
    
    self.isSimulationRunning = false
    print("Simulation stopped")
    return true
end

-- Process a single simulation frame
function RouletteSpinner:processSimulationFrame(dt)
    if not self.isLoaded then
        return
    end
    
    -- Increment frame counter
    self.frameCounter = self.frameCounter + 1
    
    -- Print ball position each frame
    print("Frame " .. self.frameCounter .. ": Ball at x=" .. string.format("%.2f", self.ballX) .. ", y=" .. string.format("%.2f", self.ballY))
    
    -- Check if we've reached 1000 frames
    if self.frameCounter >= 1000 then
        print("Simulation ended after 1000 frames")
        self.isSimulationRunning = false
        return
    end
    
    -- Apply horizontal deceleration (slowly reduce horizontal velocity towards 0)
    local horizontalDeceleration = 20 -- units per second squared
    if self.ballVx > 0 then
        self.ballVx = math.max(0, self.ballVx - horizontalDeceleration * dt)
    elseif self.ballVx < 0 then
        self.ballVx = math.min(0, self.ballVx + horizontalDeceleration * dt)
    end
    
    -- Apply gravity when horizontal velocity is low enough
    local gravityThreshold = 30 -- Start gravity when horizontal speed is below this
    if math.abs(self.ballVx) < gravityThreshold then
        local gravity = 50 * self.gravityModifier -- units per second squared
        self.ballVy = self.ballVy - gravity * dt
    end
    
    -- Update ball position
    self.ballX = self.ballX + self.ballVx * dt
    self.ballY = self.ballY + self.ballVy * dt
    
    -- Handle wall wrapping (right edge)
    if self.ballX >= 360 then
        local overflow = self.ballX - 360
        self.ballX = overflow -- Wrap to left side with preserved overflow
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
    --[[ ballLanded() example for init.lua:

        local spinner = RouletteSpinner:new()

        -- Set the callback
        spinner.onBallLanded = function(result)
            print("Ball landed on: " .. tostring(result))
            -- Handle the result
        end

        -- When the ball lands, call this:
        spinner:ballLanded("red 7")
        
    ]]--

return RouletteSpinner 