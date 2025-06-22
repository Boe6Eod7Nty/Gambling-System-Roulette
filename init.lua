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
    
    -- Spawn the ball entity
    local ballSpec = StaticEntitySpec.new()
    ballSpec.templatePath = "boe6\\gambling_system_roulette\\q303_roulette_ball.ent"
    ballSpec.position = Vector4.new(testCenter.x, testCenter.y, testCenter.z+1, 1.0)
    ballSpec.orientation = EulerAngles.ToQuat(EulerAngles.new(0, 0, 0))
    ballSpec.tags = {"rouletteBall"}
    
    local ballEntityID = Game.GetStaticEntitySystem():SpawnEntity(ballSpec)
    DualPrint('Ball entity spawned with ID: ' .. tostring(ballEntityID))
    
    -- Spawn the spinner entity
    local spinnerSpec = StaticEntitySpec.new()
    spinnerSpec.templatePath = "boe6\\gambling_system_roulette\\casino_table_roulette_spin_spinner.ent"
    spinnerSpec.position = Vector4.new(testCenter.x, testCenter.y, testCenter.z, 1.0)
    spinnerSpec.orientation = EulerAngles.ToQuat(EulerAngles.new(0, 0, 0))
    spinnerSpec.tags = {"rouletteSpinner"}
    
    local spinnerEntityID = Game.GetStaticEntitySystem():SpawnEntity(spinnerSpec)
    DualPrint('Spinner entity spawned with ID: ' .. tostring(spinnerEntityID))
    
    if spinner:load(testCenter, ballEntityID, spinnerEntityID) then
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