-- Roulette Alt Testing File
-- init-alt.lua
--===================
--CODE BY Boe6
--DO NOT DISTRIBUTE
--DO NOT COPY/REUSE WITHOUT EXPRESS PERMISSION
--DO NOT REUPLOAD TO OTHER SITES
--Feel free to ask via nexus/discord, I just dont want my stuff stolen :)
--===================

--Imports
--=======
local Cron = require('External/Cron.lua')
local GameUI = require("External/GameUI.lua")
local RouletteSpinner = require("RouletteSpinner.lua")

--'global' variables
--==================
MyMod = {
    loaded = true,
    ready = false
}
local inMenu = true --libaries requirement
local inGame = false
local spinner = nil -- Will be created when manually loaded

registerForEvent("onInit", function() --runs on file load
    -- Setup observer and GameUI to detect inGame / inMenu
    --credit: keanuwheeze | init.lua from the sitAnywhere mod
    Observe('RadialWheelController', 'OnIsInMenuChanged', function(_, isInMenu) -- Setup observer and GameUI to detect inGame / inMenu, credit: keanuwheeze | init.lua from the sitAnywhere mod
        inMenu = isInMenu
    end)

    inGame = false
    GameUI.OnSessionStart(function()
        inGame = true
    end)
    GameUI.OnSessionEnd(function()
        inGame = false
    end)
    inGame = not GameUI.IsDetached() -- Required to check if ingame after reloading all mods

    RouletteSpinner.init()
    
    MyMod.ready = true
end)

registerForEvent('onUpdate', function(dt) --runs every frame
    if not inMenu and inGame then
        Cron.Update(dt) -- This is required for Cron to function
        
        -- Update the spinner if it exists
        if spinner then
            spinner:update(dt)
        end
    end
end)

-- Dev hotkeys
registerHotkey('DevHotkey1', 'Dev Hotkey 1', function()
    DualPrint('||=1  Dev hotkey 1 Pressed =')
    
    -- Create and load the roulette spinner
    spinner = RouletteSpinner:new()
    local testCenter = {x=-1045.09375, y=1345.21069, z=6.21331358} --hoohbar
    local testRotation = -179.7887985
    
    if spinner:load(testCenter, testRotation) then
        DualPrint('Spinner loaded successfully')
    else
        DualPrint('Failed to load spinner')
    end
    
    Game.GetPlayer():PlaySoundEvent("ono_v_effort_short")
end)

registerHotkey('DevHotkey2', 'Dev Hotkey 2', function()
    DualPrint('||=2  Dev hotkey 2 Pressed =')
    
    -- Start the roulette simulation
    if spinner then
        if spinner:startSimulation() then
            DualPrint('Simulation started')
        else
            DualPrint('Failed to start simulation')
        end
    else
        DualPrint('No spinner loaded. Press DevHotkey1 first.')
    end
    
    Game.GetPlayer():PlaySoundEvent("ono_v_effort_short")
end)

registerHotkey('DevHotkey3', 'Dev Hotkey 3', function()
    DualPrint('||=3  Dev hotkey 3 Pressed =')
    
    -- Stop and unload the roulette spinner
    if spinner then
        if spinner:stopSimulation() then
            DualPrint('Simulation stopped')
        else
            DualPrint('Failed to stop simulation')
        end
        
        if spinner:unload() then
            DualPrint('Spinner unloaded successfully')
        else
            DualPrint('Failed to unload spinner')
        end
        
        spinner = nil
    else
        DualPrint('No spinner loaded. Press DevHotkey1 first.')
    end
    
    Game.GetPlayer():PlaySoundEvent("ono_v_effort_short")
end)

registerHotkey('DevHotkey4', 'Dev Hotkey 4', function()
    DualPrint('||=4  Dev hotkey 4 Pressed =')
    
    -- Spawn debug grid to visualize coordinate transformation
    if spinner then
        if spinner:spawnDebugGrid() then
            DualPrint('Debug grid spawned successfully')
        else
            DualPrint('Failed to spawn debug grid')
        end
    else
        DualPrint('No spinner loaded. Press DevHotkey1 first.')
    end
    
    Game.GetPlayer():PlaySoundEvent("ono_v_effort_short")
end)

registerHotkey('DevHotkey5', 'Dev Hotkey 5', function()
    DualPrint('||=5  Dev hotkey 5 Pressed =')
    
    -- Test different rotation smoothing factors
    if spinner then
        local currentSmoothing = spinner:getRotationSmoothing()
        DualPrint('Current rotation smoothing: ' .. currentSmoothing)
        
        -- Cycle through different smoothing values
        local smoothingValues = {0.05, 0.1, 0.2, 0.5, 1.0}
        local nextIndex = 1
        for i, value in ipairs(smoothingValues) do
            if math.abs(value - currentSmoothing) < 0.01 then
                nextIndex = (i % #smoothingValues) + 1
                break
            end
        end
        
        local newSmoothing = smoothingValues[nextIndex]
        if spinner:setRotationSmoothing(newSmoothing) then
            DualPrint('Rotation smoothing changed to: ' .. newSmoothing)
        end
    else
        DualPrint('No spinner loaded. Press DevHotkey1 first.')
    end
    
    Game.GetPlayer():PlaySoundEvent("ono_v_effort_short")
end)

function DualPrint(string) --prints to both CET console and local .log file
    if not string then return end
    print('[Gambling System] ' .. string)
    spdlog.error('[Gambling System] ' .. string)
end