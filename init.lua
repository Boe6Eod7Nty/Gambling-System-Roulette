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
    local testCenter = {x = 0, y = 0, z = 0}
    if spinner:load(testCenter) then
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

function DualPrint(string) --prints to both CET console and local .log file
    if not string then return end
    print('[Gambling System] ' .. string)
    spdlog.error('[Gambling System] ' .. string)
end