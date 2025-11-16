-- Roulette v1.0.15
-- init.lua v1.1.0
--===================
--CODE BY Boe6
--DO NOT DISTRIBUTE
--DO NOT COPY/REUSE WITHOUT EXPRESS PERMISSION
--DO NOT REUPLOAD TO OTHER SITES
--Feel free to ask via nexus/discord, I just dont want my stuff stolen :)
--===================
-- MAJOR CREDITS:
-- These people have helped me with significant roadblocks multiple times, and I am very grateful for their help and work in CP2077.
-- Additional details on how they've helped is further listed below because they are awesome
-- 
-- psiberx         for codeware, TweakDB, & ArchiveXL, documentation and various help using them & CET lua
-- keanuwheeze     for various scripts, advanced CET lua / scripting knowledge, & more various help
--
--===================
--Great Code Help Credits:
--anygoodname for original spawnWithCodeware() and despawn() code by on discord: https://discord.com/channels/717692382849663036/795037494106128434/1220335839448404008
--manavortex for seemlying endless wikipedia articles
--Gullii, Mozz3d, manavortex, psiberx, & anygoodname for help with solving some Vector4 issues
--psiberx for Cron.lua, & keanuwheeze for sharing an example using async/waiting
--keanuwheeze for interactionUI.lua & working example
--psiberx for codeware's awesome features and his help/support of it in discord
--keanuwheeze for worldInteraction.lua, which basically replaces native workspots with something scriptable.
--keanuwheeze for their init.lua from the sitAnywhere mod. Marked in comments where used.
--psiberx for GameUI.lua, a Reactive Game UI State Observer
--keanuwheeze for helping with variable scope issues [ This one took an age, ty again keanuwheeze <3 ]
--keanuwheeze for workspotUtils.lua, used for audio, effects, & HUD toggle.
--cyswip from Roblox dev forums for AddValueCommas() function
--psiberx for GameLocale.lua, which is used for translations
--psiberx for GameSession.lua, which detects game load/save events
--===================
--REQUIREMENTS:
--Cyber Engine Tweaks
--Codeware
--RED4ext
--TweakXL
--ArchiveXL
--===================

--Imports
--=======
local Cron = require('External/Cron.lua')
local interactionUI = require("External/interactionUI.lua")
local world = require("External/worldInteraction.lua")
local GameUI = require("External/GameUI.lua")
local utils = require("External/workspotUtils.lua")
local GameLocale = require("External/GameLocale.lua")
local GameSession = require('External/GameSession.lua')
local HolographicValueDisplay = require("HolographicValueDisplay.lua")
local RouletteMainMenu = require("RouletteMainMenu.lua")


--Modules
--=======
--local spinning = require("spinning.lua")

-- yeah NVM I'll teach myself modularization for my next project lol

--'global' variables (uncategorized)
--==================
MyMod = {
    loaded = true,
    ready = false
}
local areaInitialized = false --defines if a roulette table is currently loaded
local cronCount = 0
local chipRotation = 315 -- defines how the player stack hex grid is aligned
inRouletteTable = false --enables and disabled joinUI prompting
local inMenu = true --libaries requirement
local inGame = false
local entRecords = {} -- global live entity record
-- { name = devName, id = id }  --table format
-- entRecords[1].id             --reference format
local historicalEntRecords = {} --never deleted entRecords copy, used for despawn error correction.
local gameLoadDelayCount = 0
local tableLoadDistance = 20
local tableUnloadDistance = 100
local chipHeight = 0.0035
local userState = { --used by GameSession.lua
    consoleUses = 0 -- Initial state
}

-- placing bets variables
currentBets = {} --record of bets placed currently waiting for wheel spin
previousBet = {} --last currentBets table, used for repeat bets UI option
queueUIBet = {cat="Red/Black",bet="Red"} --current bet option choices during bet UI selection
local betsPileQueue = {}
local betsPiles = {}
local betsPilesToRemove = {}
previousBetAvailable = false
previousBetsCost = 0
local currentlyRepeatingBets = false

-- multi-table support variables
tableCenterPoint = {x=-1033.34668, y=1340.00183, z=6.21331358} --default value (hoohbarold)
local playerPlayingPosition = {x=-1034.435, y=1340.8057, z=5.278}
local tableBoardOrigin = {x=-1033.7970, y=1342.182833333, z=6.310} --default value (hoohbarold)
local allTables = {
    {
        id = 'hoohbar',
        initialized = false,
        loaded = false,
        SpinnerCenterPoint = {x=-1045.09375, y=1345.21069, z=6.21331358},
        tableRotation = -179.7887985,
        presetTable = false
    },
    {
        id = 'tygerclawscasino',
        initialized = false,
        loaded = false,
        SpinnerCenterPoint = {x=-65.6290207, y=-282.153259, z=-1.57608986},
        tableRotation = -170.8390799,
        presetTable = false
    }
}
local optionalTables = {
    {
        id = 'gunrunnersclub',
        initialized = false,
        loaded = false,
        SpinnerCenterPoint = {x=-2228.825, y=-2550.422, z=81.209},
        tableRotation = -43.068,
        presetTable = true,
        enabled = false,
        dependancyCheck = 'Gambling System - Compatability - Gunrunnersclub'
    }--[[,
    {
        id = 'northoakcasino',
        initialized = false,
        loaded = false,
        SpinnerCenterPoint = {x=997.970703, y=1476.80933, z=246.949997},
        tableRotation = -71.958,
        presetTable = true
        enabled = false
        dependancyCheck = 'Gambling System - Compatability - Northoakcasino'
    }]]--
}
activeTable = allTables[1]

-- ent files used to create entities
local chip_broken = "base\\gameplay\\items\\misc\\appearances\\broken_poker_chip_junk.ent"
local chips_allin = "ep1\\quest\\main_quests\\q303\\entities\\q303_chips_all_in.ent"
local chips_table = "ep1\\quest\\main_quests\\q303\\entities\\q303_chips_table.ent"
local roulette_ball = "boe6\\gambling_system_roulette\\q303_roulette_ball.ent" --PL .ent, object duplicated into project custom path to remove PL dependancy
local chip_stacks = "boe6\\gambling_system_roulette\\q303_chips_stacks_edit.ent"
local poker_chip = "boe6\\gambling_props\\boe6_poker_chip.ent"
local roulette_spinner = "boe6\\gambling_system_roulette\\casino_table_roulette_spin_spinner.ent"
local roulette_spinner_frame = "boe6\\gambling_system_roulette\\casino_table_roulette_spin_spinner_frame.ent"
local number_digit = "boe6\\gambling_system_roulette\\boe6_number_digit.ent"
local high_school_usa_font = "boe6\\gambling_system_roulette\\high-school-usa-font.ent"
local playing_card = "boe6\\gambling_props\\boe6_playing_card.ent"

--roulette spinner global variables
roulette_spinning = false
local roulette_spinning_count = 0
local roulette_spinning_speed = 0
local roulette_angle_count = 0
local roulette_angle = 0
local roulette_speed_adjusted = 0

--roulette ball global variables
local ball_center = {x=tableCenterPoint.x, y=tableCenterPoint.y, z=tableCenterPoint.z+0.08668642} --set 0,0 center point of roulette wheel
local ball_phase = 0
ball_spinning = false
local ball_spinning_count = 0
local ballX = 0
local ballY = 0
local ball_distance = 0.35 --0.35 = max distance, 0.23 = contact, 0.2 = resting
local ball_speed = 0.2
local ball_bounces = 0
local ball_bounce1 = 0
local bounce_randomness = 30
local ball_angle = 0
local ball_height = 0
local bounce_height = 60
local max_ball_bounces = 4 --how many bounces before the ball is force stopped

--chip stacks global variables
playerPile = { --initialize player pile
    value=0,
    singleStacks={0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    fullStacks={0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
    location = {x=0, y=0, z=0}, --need to account for rotation in the future, specifically when other tables are added, the rotation needs to be accounted for
    rotation = {x=0, y=0, z=0},
    stacksInfo = {},
    limits = {minX=-4, maxX=6, minY=-2, maxY=3, minZ=1, maxZ=6}
}
local maxStackSize = 10
local searchStepCount = 0
local stackSearchCurrent = {x=0, y=0, z=0}
local stackSearchPrevious = {x=0, y=0, z=0}
local stackSearchOld = {x=0, y=0, z=0}

-- Game Status Variables
local tableChips = 0 --amount of player money on the table. This needs to be saved between sessions somehow, otherwise loading a save mid-game will delete players money ¯\_(ツ)_/¯
local bettingStyle = 'basic' -- Betting styles = basic, simple, standard, advanced. Also should be saved between sessions somehow
local pileQueue = {} --stores a list of chips to be added to piles.
local pileSubtractionQueue = {}
local spin_results = '' --stores a record of every spin that occurs in the game. Stored by slot index 1-37

-- Game value references
local roulette_slots = {
    {index = 0, label = 32, color = 'Red'},
    {index = 1, label = 0, color = 'Green'},
    {index = 2, label = 26, color = 'Black'},
    {index = 3, label = 3, color = 'Red'},
    {index = 4, label = 35, color = 'Black'},
    {index = 5, label = 12, color = 'Red'},
    {index = 6, label = 28, color = 'Black'},
    {index = 7, label = 7, color = 'Red'},
    {index = 8, label = 29, color = 'Black'},
    {index = 9, label = 18, color = 'Red'},
    {index = 10, label = 22, color = 'Black'},
    {index = 11, label = 9, color = 'Red'},
    {index = 12, label = 31, color = 'Black'},
    {index = 13, label = 14, color = 'Red'},
    {index = 14, label = 20, color = 'Black'},
    {index = 15, label = 1, color = 'Red'},
    {index = 16, label = 33, color = 'Black'},
    {index = 17, label = 16, color = 'Red'},
    {index = 18, label = 24, color = 'Black'},
    {index = 19, label = 5, color = 'Red'},
    {index = 20, label = 10, color = 'Black'},
    {index = 21, label = 23, color = 'Red'},
    {index = 22, label = 8, color = 'Black'},
    {index = 23, label = 30, color = 'Red'},
    {index = 24, label = 11, color = 'Black'},
    {index = 25, label = 36, color = 'Red'},
    {index = 26, label = 13, color = 'Black'},
    {index = 27, label = 27, color = 'Red'},
    {index = 28, label = 6, color = 'Black'},
    {index = 29, label = 34, color = 'Red'},
    {index = 30, label = 17, color = 'Black'},
    {index = 31, label = 25, color = 'Red'},
    {index = 32, label = 2, color = 'Black'},
    {index = 33, label = 21, color = 'Red'},
    {index = 34, label = 4, color = 'Black'},
    {index = 35, label = 19, color = 'Red'},
    {index = 36, label = 15, color = 'Black'}
}
local chip_colors = {
    'white',
    'yellow',
    'red',
    'blue',
    'maroon',
    'black',
    'cyan',
    'orange',
    'lime',
    'pink',
    'purple',
    'green',
    'creamyYellow',
    'royalBlue',
    'forrestGreen',
    'steelPink'
}
chip_values = {
    1,
    5,
    10,
    25,
    50,
    100,
    250,
    500,
    1000,
    2500,
    5000,
    10000,
    25000,
    50000,
    250000,
    1000000
}
betCategories = {
    'Red/Black',
    'Odd/Even',
    'High/Low',
    'Column',
    'Dozen',
    'Straight-Up',
    'Split',
    'Street',
    'Corner',
    'Line'
}
betCategoryIndexes = {
    {'Red', 'Black'},
    {'Odd', 'Even'},
    {'High', 'Low'},
    {'1st Column', '2nd Column', '3rd Column'},
    {'1-12 Dozen', '13-24 Dozen', '25-36 Dozen'},
    {'0 Green', '1 Red', '2 Black', '3 Red', '4 Black', '5 Red', '6 Black', '7 Red', '8 Black', '9 Red', '10 Black', '11 Black', '12 Red', --straight up
        '13 Black', '14 Red', '15 Black', '16 Red', '17 Black', '18 Red', '19 Red', '20 Black', '21 Red', '22 Black', '23 Red', '24 Black',
        '25 Red', '26 Black', '27 Red', '28 Black', '29 Black', '30 Red', '31 Black', '32 Red', '33 Black', '34 Red', '35 Black', '36 Red'},
    {'1-2 Split', '2-3 Split', '1-4 Split', '2-5 Split', '3-6 Split', '4-5 Split', '5-6 Split', '4-7 Split', '5-8 Split', '6-9 Split',
        '7-8 Split', '8-9 Split', '7-10 Split', '8-11 Split', '9-12 Split', '10-11 Split', '11-12 Split', '10-13 Split', '11-14 Split', '12-15 Split', --split
        '13-14 Split', '14-15 Split', '13-16 Split', '14-17 Split', '15-18 Split', '16-17 Split', '17-18 Split', '16-19 Split', '17-20 Split', '18-21 Split',
        '19-20 Split', '20-21 Split', '19-22 Split', '20-23 Split', '21-24 Split', '22-23 Split', '23-24 Split', '22-25 Split', '23-26 Split', '24-27 Split',
        '25-26 Split', '26-27 Split', '25-28 Split', '26-29 Split', '27-30 Split', '28-29 Split', '29-30 Split', '28-31 Split', '29-32 Split', '30-33 Split',
        '31-32 Split', '32-33 Split', '31-34 Split', '32-35 Split', '33-36 Split', '34-35 Split', '35-36 Split'},
    {'1,2,3 Street', '4,5,6 Street', '7,8,9 Street', '10,11,12 Street', '13,14,15 Street', '16,17,18 Street', '19,20,21 Street', '22,23,24 Street', '25,26,27 Street', --street
        '28,29,30 Street', '31,32,33 Street', '34,35,36 Street'},
    {'1/5 Corner', '2/6 Corner', '4/8 Corner', '5/9 Corner', '7/11 Corner', '8/12 Corner', '10/14 Corner', '11/15 Corner', '13/17 Corner', '14/18 Corner', '16/20 Corner', --corner
        '17/21 Corner', '19/23 Corner', '20/24 Corner', '22/26 Corner', '23/27 Corner', '25/29 Corner', '26/30 Corner', '28/32 Corner', '29/33 Corner', '31/35 Corner', '32/36 Corner'},
    {'1-6 Line', '4-9 Line', '7-12 Line', '10-15 Line', '13-18 Line', '16-21 Line', '19-24 Line', '22-27 Line', '25-30 Line', '28-33 Line', '31-36 Line'},
}
betSizingSets = {
    {1,10,25,50,100},
    {10,50,100,500,1000},
    {100,500,1000,5000,10000},
    {1000,5000,10000,50000,100000},
    {10000,25000,100000,500000,1000000}
}
betsPlacesTaken = {
    {false, false}, -- red, black
    {false, false}, -- odd, even (outside)
    {false, false}, -- High, Low (outside)
    {false, false, false}, -- 1st column, 2nd column, 3rd column (outside)
    {false, false, false}, -- 1-12, 13-24, 25-36 (outside)
    {false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false}, -- straight up
    {false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false,
     false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false}, -- Splits (Inside)
    {false, false, false, false, false, false, false, false, false, false, false, false}, -- Streets (Inside)
    {false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false}, -- Corners (Inside)
    {false, false, false, false, false, false, false, false, false, false, false} -- Lines (Inside)
}

-- Holographic value display variables
holographicDisplayActive = false
local holographicDisplayPosition = nil
local subtractionValueLoopCount = 0

--winning result holo
local holoDisplayAngle = ( ( math.atan2(tableCenterPoint.y - playerPlayingPosition.y, tableCenterPoint.x - tableCenterPoint.x) ) * 180 / math.pi ) - 45
local holoDisplayAngleRad = holoDisplayAngle * math.pi / 180
local showingHoloResult = false
local doubleDigitHoloResult = false

-- Custom value input variables
local inputSelected
local inputText = ""
showCustomBuyChips = false
showCustomBetChips = false
local buttonCustomNumberPressed = false

--Callbacks
--=========

local callback40x = function()
    cronCount = cronCount + 1
    
    local gameLoadDelayTime = 20 --Some delay needed, unsure how much. may be system dependant, could lead to bug reports. Half a second seems *fine*
    if gameLoadDelayCount < gameLoadDelayTime then -- "loading" time
        interactionUI.hideHub()
        StatusEffectHelper.RemoveStatusEffect(GetPlayer(), "GameplayRestriction.NoMovement") -- Enable player movement
        StatusEffectHelper.RemoveStatusEffect(GetPlayer(), "GameplayRestriction.NoCombat")
        --idk if these need to be set but better safe than sorry. Loading bugs are hard to pinpoint.
        inRouletteTable = false
    end
    if not areaInitialized and gameLoadDelayCount >= gameLoadDelayTime then --checks if area is loaded, and if the game has been running.
        local playerPosition = GetPlayer():GetWorldPosition()
        local pX = playerPosition.x
        local pY = playerPosition.y
        for i, v in ipairs(allTables) do
            local distanceToTable = math.sqrt((pX - v.SpinnerCenterPoint.x)^2 + (pY - v.SpinnerCenterPoint.y)^2)
            if distanceToTable < tableLoadDistance then
                areaInitialized = true
                InitTable(allTables[i])
            end
        end
    end
    if areaInitialized then
        local playerPosition = GetPlayer():GetWorldPosition()
        local pX = playerPosition.x
        local pY = playerPosition.y

        local distanceToTable = math.sqrt((pX - activeTable.SpinnerCenterPoint.x)^2 + (pY - activeTable.SpinnerCenterPoint.y)^2)
        if distanceToTable > tableUnloadDistance then
            DespawnTable()
        end
    end

    --MoveEnt('chips1', {x=0, y=0.01, z=0})
    if ball_spinning then AdvanceRouletteBall() end --check if roulette ball should be spinning
    if roulette_spinning then AdvanceSpinner() end --check if roulette wheel should be spinning
    gameLoadDelayCount = gameLoadDelayCount + 1


    if showingHoloResult then
        MoveEnt('holo_result_firstDigit', {x=0, y=0, z=0.001}, {r=0, p=0, y=holoDisplayAngle})
        MoveEnt('holo_result_colorWord', {x=0, y=0, z=0.001}, {r=0, p=0, y=holoDisplayAngle})
        if doubleDigitHoloResult then
            MoveEnt('holo_result_secondDigit', {x=0, y=0, z=0.001}, {r=0, p=0, y=holoDisplayAngle})
        end
    end

    if (cronCount % 4 == 0) then --10x per second
        QueuedChipAddition()
        QueuedChipSubtraction()
        QueuedBetChipAddition()
        RemoveBetStack()
    end
    --[[
    if (cronCount % 10 == 0) then --4x per second
    end

    if (cronCount % 40 == 0) then --1x per second
    end
    ]]--

    if (cronCount == 40) then
        cronCount = 0
    end
end


--Register Events
--===============

registerForEvent( "onInit", function() --runs on file load
	GameLocale.Initialize()
    interactionUI.init()
    RegisterEntity('chips0', chip_broken, 'default') --insert index 1 dummy into entRecords to catch nil errors
    Cron.Every(0.025, callback40x)

    Observe('RadialWheelController', 'OnIsInMenuChanged', function(_, isInMenu) -- Setup observer and GameUI to detect inGame / inMenu, credit: keanuwheeze | init.lua from the sitAnywhere mod
        inMenu = isInMenu
    end)

    --Setup observer and GameUI to detect inGame / inMenu
    --credit: keanuwheeze | init.lua from the sitAnywhere mod
    inGame = false
    GameUI.OnSessionStart(function()
        inGame = true
        world.onSessionStart()
    end)
    GameUI.OnSessionEnd(function()
        inGame = false
    end)
    inGame = not GameUI.IsDetached() -- Required to check if ingame after reloading all mods

    world.init()

    GameSession.OnEnd(function() --GameSession init stuff, credit: psiberx code
        -- Triggered once the current game session has ended (when "Load Game" or "Exit to Main Menu" selected)
        DespawnTable()
    end)

    for i, v in ipairs(optionalTables) do --check option table requirements
        local dependancyEnabled = GetMod(v.dependancyCheck)
        if dependancyEnabled then
            v.enabled = true
            table.insert(allTables, v)
            DuelPrint('Table Enabled: '..v.id)
        end
    end

    for i, v in ipairs(allTables) do
        local xy = RotatePoint({x=v.SpinnerCenterPoint.x, y=v.SpinnerCenterPoint.y}, {x=v.SpinnerCenterPoint.x -0.6828427083, y=v.SpinnerCenterPoint.y -0.7238078523}, v.tableRotation)
        world.addInteraction(v.id, Vector4.new(xy.x, xy.y, v.SpinnerCenterPoint.z + 0.09368642, 1), 1.0, 80, "ChoiceIcons.SitIcon", 6.5, 0.5, nil, function(state)
            --Vector4.new(-1034.073, 1340.682, v.SpinnerCenterPoint.z + 0.09368642, 1)
            --  (id, position, interactionRange, angle, icon, iconRange, iconRangeMin, iconColor, callback)
            if state then -- Show
                UpdateJoinUI(true)
            else -- Hide
                UpdateJoinUI(false)
            end
        end)
    end

    MyMod.ready = true
end)

registerForEvent('onUpdate', function(dt) --runs every frame
    if  not inMenu and inGame then
        Cron.Update(dt) -- This is required for Cron to function
        interactionUI.update()
        world.update()
        
        -- Update holographic display every frame (like blackjack implementation)
        if holographicDisplayActive then
            HolographicValueDisplay.Update(playerPile.value or 0)
        end
    end
    if buttonCustomNumberPressed then
        local inputValue = tonumber(inputText)
        if showCustomBuyChips then
            showCustomBuyChips = false
            local playerMoney = Game.GetTransactionSystem():GetItemQuantity(GetPlayer(), MarketSystem.Money())
            if playerMoney >= inputValue and inputValue >= 0 and inputValue <= 10000000 then
                interactionUI.hideHub()
                ChangePlayerChipValue(inputValue)
                Game.AddToInventory("Items.money", -(inputValue) )
                Game.GetPlayer():PlaySoundEvent("q303_06a_roulette_chips_stack")
                RouletteMainMenu.MainMenuUI()
            end
        elseif showCustomBetChips then
            showCustomBetChips = false
            if playerPile.value >= inputValue and inputValue >= 0 and inputValue <= 10000000 then
                interactionUI.hideHub()
                PlaceBet(inputValue)
                RouletteMainMenu.MainMenuUI()
            end
        else
            DuelPrint('=t Error: button pressed, but no showCustomChips flag set. code 4509')
        end
        buttonCustomNumberPressed = false
    end
end)
registerForEvent('onDraw', function()
    if showCustomBuyChips or showCustomBetChips then
        ImGui.SetNextWindowPos(100, 500, ImGuiCond.FirstUseEver) -- set window position x, y
        ImGui.SetNextWindowSize(300, 600, ImGuiCond.Appearing) -- set window size w, h
        if ImGui.Begin('Input Value', ImGuiWindowFlags.AlwaysAutoResize) then
            ImGui.Text('Press Cyber Engine Tweaks Overlay Button to Interact')
            ImGui.Text('Only number characters')
            ImGui.Text('Maximum allowed value: 10000000')
            inputText, inputSelected = ImGui.InputTextWithHint("Amount", "value", inputText, 100)
            buttonCustomNumberPressed = ImGui.Button("Submit", 200, 25)
            ImGui.Text('(Submit 0 to go back / exit))')
        end
        ImGui.End()
    end
end)
--dev hotkeys
--[[
registerHotkey('DevHotkey1', 'Dev Hotkey 1', function()
    DuelPrint('||=1  Dev hotkey 1 Pressed =')

    Game.GetPlayer():PlaySoundEvent("ono_v_effort_short")
end)
registerHotkey('DevHotkey2', 'Dev Hotkey 2', function()
    DuelPrint('||=2  Dev hotkey 2 Pressed =')

    DespawnTable()
end)
registerHotkey('DevHotkey3', 'Dev Hotkey 3', function()
    DuelPrint('||=3  Dev hotkey 3 Pressed =')

    -- Clear/delete all entities
    local devNameTable = {}
    for i,v in ipairs(entRecords) do
        DuelPrint('=3 LIST i: '..i..' devName: '..v.name)
        table.insert(devNameTable, v.name)
    end
    for i,v in ipairs(devNameTable) do
        DuelPrint('=3 REAL i: '..i..' devName: '..v)
        DeRegisterEntity(v)
    end
    --reset player pile
    playerPile.value=0
    playerPile.singleStacks={0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0}
    playerPile.fullStacks={0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0}
    playerPile.stacksInfo = {}
end)
registerHotkey('DevHotkey4', 'Dev Hotkey 4', function()
    DuelPrint('||=4  Dev hotkey 4 Pressed =')

    DebugPlayerPile()
end)
registerHotkey('DevHotkey5', 'Dev Hotkey 5', function()
    DuelPrint('||=5  Dev hotkey 5 Pressed =')

    ForceClearAllEnts()
end)
registerHotkey('DevHotkey6', 'Dev Hotkey 6', function()
    DuelPrint('||=6  Dev hotkey 6 Pressed =')

end)
registerHotkey('DevHotkey7', 'Dev Hotkey 7', function()
    DuelPrint('||=7  Dev hotkey 7 Pressed =')

end)
registerHotkey('DevHotkey8', 'Dev Hotkey 8', function()
    DuelPrint('||=8  Dev hotkey 8 Pressed =')

end)
registerHotkey('DevHotkey9', 'Dev Hotkey 9', function()
    DuelPrint('||=9  Dev hotkey 9 Pressed =')

end)
]]--


--Functions
--=========

function InitTable(table)

    --Game.GetWorldStateSystem():DeactivateCommunity(CreateNodeRef("#kab_07_com_ground_floor_crowd"), "Clients_male") --"deactivate"/despawn guy in roulette seat, uses codeware
    -- found in RedHotTools, node ref final /xyz/    --found in community file, match Record ID = CharacterRecordID in community file, use entryName value
    -- removing this in the future and using a phycial table that doesn't need NPCs removed.

    activeTable = table
    tableCenterPoint = table.SpinnerCenterPoint
    ball_center = {x=tableCenterPoint.x, y=tableCenterPoint.y, z=tableCenterPoint.z+0.08668642}

    RegisterEntity('roulette_spinner', roulette_spinner, 'default')
    RegisterEntity('roulette_ball', roulette_ball, 'default')
    if table.presetTable then
        RegisterEntity('roulette_spinner_frame', roulette_spinner_frame, 'default')
    end

    local pilexy = RotatePoint({x=table.SpinnerCenterPoint.x, y=table.SpinnerCenterPoint.y}, {x=table.SpinnerCenterPoint.x -0.3892143661, y=table.SpinnerCenterPoint.y -0.5538890579}, table.tableRotation)
    playerPile.location = {x=pilexy.x, y=pilexy.y, z=table.SpinnerCenterPoint.z + 0.09668642}


    local playerPositionxy = RotatePoint({x=table.SpinnerCenterPoint.x, y=table.SpinnerCenterPoint.y}, {x=table.SpinnerCenterPoint.x -0.80787625665175, y=table.SpinnerCenterPoint.y -1.085349415275}, table.tableRotation)
    playerPlayingPosition = {x=playerPositionxy.x, y=playerPositionxy.y, z=table.SpinnerCenterPoint.z -0.93531358}

    -- Holographic display position (same location as old chip_stacks stand, HolographicValueDisplay will spawn its own stand)
    local holoPositionxy = RotatePoint({x=table.SpinnerCenterPoint.x, y=table.SpinnerCenterPoint.y}, {x=table.SpinnerCenterPoint.x +0.17977070965503, y=table.SpinnerCenterPoint.y -0.55898646070364}, table.tableRotation)
    holographicDisplayPosition = {x=holoPositionxy.x, y=holoPositionxy.y, z=table.SpinnerCenterPoint.z+0.08668642}

    holoDisplayAngle = ( ( math.atan2(tableCenterPoint.y - playerPlayingPosition.y, tableCenterPoint.x - tableCenterPoint.x) ) * 180 / math.pi ) + 225
    holoDisplayAngleRad = holoDisplayAngle * math.pi / 180

    local boardOriginxy = RotatePoint({x=tableCenterPoint.x, y=tableCenterPoint.y}, {x=tableCenterPoint.x -2.182648465571, y=tableCenterPoint.y -0.44227742051612}, table.tableRotation)
    tableBoardOrigin = {x=boardOriginxy.x, y=boardOriginxy.y, z=tableCenterPoint.z +0.09668642}


end

function DespawnTable() --despawns ents and resets script variables
    --despawn all known custom ents
    DeRegisterEntity('roulette_spinner')
    DeRegisterEntity('roulette_spinner_frame')
    DeRegisterEntity('roulette_ball')
    
    -- Stop holographic display if active (this will despawn the stand entity)
    if holographicDisplayActive then
        HolographicValueDisplay.stopDisplay()
        holographicDisplayActive = false
    end

    for i, v in ipairs(currentBets) do
        local localPile = betsPiles[v.id]
        for j, k in ipairs(localPile.stacksInfo) do
            DeRegisterEntity(k.stackDevName)
        end
    end

    StatusEffectHelper.RemoveStatusEffect(GetPlayer(), "GameplayRestriction.NoMovement") -- Enable player movement
    StatusEffectHelper.RemoveStatusEffect(GetPlayer(), "GameplayRestriction.NoCombat") -- Enable weapon draw
    interactionUI.hideHub()

    local callbackResetVariables = function() --force reset almost every variable. save/load bugs are a PITA.
        areaInitialized = false
        gameLoadDelayCount = 0
        playerPile.value = 0
        previousBetAvailable = false
        inRouletteTable = false
        ball_speed = 0
        ball_spinning = false
        ball_phase = 0
        roulette_spinning = false
        gameLoadDelayCount = 0
        cronCount = 0
        currentBets = {}
        previousBet = {}
        betsPileQueue = {}
        betsPiles = {}
        betsPilesToRemove = {}
        previousBetsCost = 0
        currentlyRepeatingBets = false
        roulette_spinning_count = 0
        roulette_spinning_speed = 0
        roulette_angle_count = 0
        roulette_angle = 0
        roulette_speed_adjusted = 0
        ball_spinning_count = 0
        ballX = 0
        ballY = 0
        ball_distance = 0.35
        ball_bounces = 0
        ball_bounce1 = 0
        ball_angle = 0
        ball_height = 0
        searchStepCount = 0
        stackSearchCurrent = {x=0, y=0, z=0}
        stackSearchPrevious = {x=0, y=0, z=0}
        stackSearchOld = {x=0, y=0, z=0}
        tableChips = 0
        pileQueue = {}
        pileSubtractionQueue = {}
        spin_results = ''
        betsPlacesTaken = {
            {false, false},
            {false},
            {false},
            {false},
            {false},
            {false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false},
            {false},
            {false},
            {false},
            {false}
        }
        holographicDisplayActive = false
        holographicDisplayPosition = nil
        showCustomBuyChips = false
        showCustomBetChips = false
        buttonCustomNumberPressed = false
    end
    Cron.After(0.2, callbackResetVariables)

    ForceClearAllEnts() --force clear all entities via historicalEntRecords table, in case of despawn bets error/bug
end

function RegisterEntity(devName, entSrc, appName, location, orientation, tags) -- create entity and add to local system, pass location as table = {x=0,y=0,z=0}
    for i,v in ipairs(entRecords) do --check if entity already exists
        if v.name == devName then --if exists, exit function
            do return end
        end
    end
    local newTags = {"[Boe6]","[Gambling System]","[Roulette]"}
    if tags then
        for i,v in ipairs(tags) do
            table.insert(newTags, v)
        end
    end
    local id = SpawnWithCodeware(entSrc, appName, location, orientation, newTags) --create entity
    table.insert(entRecords, { name = devName, id = id }) -- save entity id to entRecords w/ a devName
    table.insert(historicalEntRecords, { name = devName, id = id }) --save copy to historicalEntRecords, for error handling
end

function DeRegisterEntity(devName) -- delete and remove entity from local system
    --DuelPrint('[==q Ran DeRegisterEntity(), devName: '..devName)

    local entity = Game.FindEntityByID(FindEntIdByName(devName))
    if entity == nil then
        --DuelPrint('=q entity is nil')
        -- Remove from entRecords even if entity is nil
        local foundMatch = 1
        while foundMatch > 0 do
            foundMatch = 1
            for i,v in ipairs(entRecords) do
                if v.name == devName then
                    table.remove(entRecords, i)
                    foundMatch = 2
                    break
                end
            end
            if foundMatch == 1 then
                foundMatch = 0
            end
        end
        return
    end
    local currentPos = entity:GetWorldPosition()
    --DuelPrint('=q entity pos pre  x: '..currentPos.x..' y: '..currentPos.y..' z: '..currentPos.z)
    Despawn(FindEntIdByName(devName))

    local foundMatch = 1
    while foundMatch > 0 do
        foundMatch = 1
        for i,v in ipairs(entRecords) do --find matching devName in entRecords & add index to 'indicesToRemove' table
            if v.name == devName then
                table.remove(entRecords, i)
                --DuelPrint('=q Removed devName: '..devName..' from entRecords')
                foundMatch = 2
                break
            end
        end
        if foundMatch == 1 then
            foundMatch = 0
        end
    end
end

function FindEntIdByName(devName, entList) -- find devName in entRecords and return id
    local indicies = {}
    for i,v in ipairs(entRecords) do --find all matches
        if v.name == devName then
            table.insert(indicies, i)
        end
    end
    for i,v in ipairs(indicies) do
        return entRecords[v].id --returns first match
    end
    --in case no matches, return chips0
    for i,v in ipairs(entRecords) do
        if v.name == 'chips0' then
            -- DuelPrint('=G FindEntityByID() minor error, code 3098')
                --suppressed due to user confusion.
                --TODO: print v.name to look into cause
            return v.id
        end
    end
end

function MoveEnt(idName, xyz, rpy) --move entity by xyz realative to current position
    if not xyz then xyz = {x=0, y=0, z=0} return end --set default value

    local entity = Game.FindEntityByID(FindEntIdByName(idName))
    if entity == nil then return end
    local currentRot = entity:GetWorldOrientation()
    local currentPos = entity:GetWorldPosition()
    local newPos = Vector4.new(currentPos.x + xyz.x, currentPos.y + xyz.y, currentPos.z + xyz.z, currentPos.w)
    local localRPY = {r=0, p=0, y=0}
    if rpy then
        localRPY = {r=rpy.r, p=rpy.p, y=rpy.y}
    end
    Game.GetTeleportationFacility():Teleport(entity, newPos, EulerAngles.new(localRPY.r, localRPY.p, localRPY.y))
end

function SetRotateEnt(idName, rpy) --teleport an entity to specified rotation at the same location
    if not rpy then rpy = {r=0, p=0, y=0} return end --set default value

    local entity = Game.FindEntityByID(FindEntIdByName(idName))
    if entity == nil then return end
    local currentPos = entity:GetWorldPosition()
    local newRot = EulerAngles.new(rpy.r, rpy.p, rpy.y)
    Game.GetTeleportationFacility():Teleport(entity, currentPos, newRot)
end

function DualPrint(string) --prints to both CET console and local .log file
    if not string then return end
    print('[Gambling System] ' .. string)
    spdlog.error('[Gambling System] ' .. string)
end

function DuelPrint(string) --prints to both CET console and local .log file
    DualPrint(string)
end

function DebugPlayerPile()
    DuelPrint('=  DebugPlayerPile() = DEBUG PLAYER PILE =')
    DuelPrint('=  value: '..playerPile.value)
    DuelPrint('=  singleStacks: {'..playerPile.singleStacks[1]..','..playerPile.singleStacks[2]..','..playerPile.singleStacks[3]..','..playerPile.singleStacks[4]..','..playerPile.singleStacks[5]..','..playerPile.singleStacks[6]..','
                                ..playerPile.singleStacks[7]..','..playerPile.singleStacks[8]..','..playerPile.singleStacks[9]..','..playerPile.singleStacks[10]..','..playerPile.singleStacks[11]..','..playerPile.singleStacks[12]..','
                                ..playerPile.singleStacks[13]..','..playerPile.singleStacks[14]..','..playerPile.singleStacks[15]..','..playerPile.singleStacks[16]..'}')
    DuelPrint('=  fullStacks: {'..playerPile.fullStacks[1]..','..playerPile.fullStacks[2]..','..playerPile.fullStacks[3]..','..playerPile.fullStacks[4]..','..playerPile.fullStacks[5]..','..playerPile.fullStacks[6]..','
                                ..playerPile.fullStacks[7]..','..playerPile.fullStacks[8]..','..playerPile.fullStacks[9]..','..playerPile.fullStacks[10]..','..playerPile.fullStacks[11]..','..playerPile.fullStacks[12]..','
                                ..playerPile.fullStacks[13]..','..playerPile.fullStacks[14]..','..playerPile.fullStacks[15]..','..playerPile.fullStacks[16]..'}')
    DuelPrint('=  location x: '..playerPile.location.x..' y: '..playerPile.location.y..' z: '..playerPile.location.z)
    DuelPrint('=  stacksInfo = {} :')
    for i,v in ipairs(playerPile.stacksInfo) do
        DuelPrint('=  i: '..i..' stackDevName: '..v.stackDevName..' cIndex: '..v.cIndex..' hexCoords: '..v.hexCoords.x..','..v.hexCoords.y..','..v.hexCoords.z)
    end
    DuelPrint('=  limits x: '..playerPile.limits.minX..','..playerPile.limits.maxX..' y: '..playerPile.limits.minY..','..playerPile.limits.maxY..' z: '..playerPile.limits.minZ..','..playerPile.limits.maxZ)
end

function AddValueCommas(amount) --converts integer into string with commas
    --function by cyswip
	local formatted = amount
	while true do
		formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)","%1,%2")
		if (k==0) then
			break
		end
	end
	return formatted
end

function ForceClearAllEnts()
    for i,v in ipairs(historicalEntRecords) do
        -- i = { name = devName, id = id }
        if v.name ~= 'chips0' then
            Despawn(v.id)
        end
    end
end

function ChangePlayerChipValue(valueModifier) --add or subtract valueModifier to player chips. Updates visual chips, pile stack, and holographic display
    if valueModifier == 0 then
        return
    elseif valueModifier > 0 then
        ValueToPileQueueSimple(playerPile, pileQueue, valueModifier)
        playerPile.value = playerPile.value + valueModifier
    elseif valueModifier < 0 then
        local valueInverted = valueModifier * -1
        ValueToQueueSubtraction(playerPile, valueInverted)
        playerPile.value = playerPile.value - valueInverted
    end
    
    -- Note: HolographicValueDisplay.Update() is now called every frame in onUpdate
    -- No need to call it here since the frame-based update will handle it
end


function ShowHoloResult(number, color)
    showingHoloResult = true
    local kerning = 0.013845
    local doubleSpace = 0.03
    local numberWidth = 0.0758
    local greenWidth = 0.404
    local redWidth = 0.239
    local blackWidth = 0.411
    local colorWordWidth = 0
    local stringPhysicalWidth = numberWidth + kerning + doubleSpace
    if number >= 10 then
        doubleDigitHoloResult = true
        stringPhysicalWidth = stringPhysicalWidth + numberWidth + kerning
    else
        doubleDigitHoloResult = false
    end
    if color == 'Black' then
        stringPhysicalWidth = stringPhysicalWidth + blackWidth
        colorWordWidth = blackWidth
    elseif color == 'Red' then
        stringPhysicalWidth = stringPhysicalWidth + redWidth
        colorWordWidth = redWidth
    elseif color == 'Green' then
        stringPhysicalWidth = stringPhysicalWidth + greenWidth
        colorWordWidth = greenWidth
    else
        DuelPrint('=C FATAL ERROR: color ~= Green|Red|Black, CODE 0954')
    end
    local widthMiddle =  stringPhysicalWidth / 2

    local firstDigitLinePos = numberWidth / 2
    local secondDigitLinePos = numberWidth + kerning + (numberWidth / 2)
    local colorWordLinePos = numberWidth + kerning + doubleSpace + (colorWordWidth / 2)
    if doubleDigitHoloResult then
        colorWordLinePos = colorWordLinePos + numberWidth + kerning
    end


    local firstDigitRelativeX = ( firstDigitLinePos - widthMiddle ) * math.cos(holoDisplayAngleRad)
    local firstDigitRelativeY = ( firstDigitLinePos - widthMiddle ) * math.sin(holoDisplayAngleRad)
    local secondDigitRelativeX = ( secondDigitLinePos - widthMiddle ) * math.cos(holoDisplayAngleRad)
    local secondDigitRelativeY = ( secondDigitLinePos - widthMiddle ) * math.sin(holoDisplayAngleRad)
    local colorWordRelativeX = ( colorWordLinePos - widthMiddle ) * math.cos(holoDisplayAngleRad)
    local colorWordRelativeY = ( colorWordLinePos - widthMiddle ) * math.sin(holoDisplayAngleRad)

    local firstDigitPos = {
        x=tableCenterPoint.x + firstDigitRelativeX,
        y=tableCenterPoint.y + firstDigitRelativeY,
        z=tableCenterPoint.z + 0.3
    }
    local secondDigitPos = {
        x=tableCenterPoint.x + secondDigitRelativeX,
        y=tableCenterPoint.y + secondDigitRelativeY,
        z=tableCenterPoint.z + 0.3
    }
    local colorWordPos = {
        x=tableCenterPoint.x + colorWordRelativeX,
        y=tableCenterPoint.y + colorWordRelativeY,
        z=tableCenterPoint.z + 0.3
    }

    local numberString = tostring(number)
    local firstDigit = string.sub(numberString, 1, 1)
    local secondDigit = ""
    if doubleDigitHoloResult then
        secondDigit = string.sub(numberString, 2, 2)
    end

    RegisterEntity('holo_result_firstDigit', high_school_usa_font, firstDigit, {x=firstDigitPos.x, y=firstDigitPos.y, z=firstDigitPos.z})
    RegisterEntity('holo_result_colorWord', high_school_usa_font, color, {x=colorWordPos.x, y=colorWordPos.y, z=colorWordPos.z})
    if doubleDigitHoloResult then
        RegisterEntity('holo_result_secondDigit', high_school_usa_font, secondDigit, {x=secondDigitPos.x, y=secondDigitPos.y, z=secondDigitPos.z})
    end


    local callback = function()
        showingHoloResult = false
        DeRegisterEntity('holo_result_firstDigit')
        DeRegisterEntity('holo_result_colorWord')
        if doubleDigitHoloResult then
            DeRegisterEntity('holo_result_secondDigit')
        end
    end
    Cron.After(5, callback)

end

function ValueToPileQueueSimple(localPile, queue, value) -- add value to pileQueue table, converts into chip denominations
    local valueRemaining = value
    local colorsSoFar = 0
    local piles = {}
    local splitSizing = 0.4
    local minChips = 6 -- minimum number of chips required to give a particular chip denomination
    local minColors = 3 -- minimum number of chip denominations required to force color variety
    local queuedChips = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0}
    local maxChipsPerColor = 10
    if queue == betsPileQueue then
        if value >= 1000000 then
            minChips = 3
            minColors = 3
        elseif value >= 100000 then
            minChips = 3
            minColors = 2
        elseif value >= 10000 then
            minChips = 2
            minColors = 1
        else
            minChips = 1
            minColors = 1
        end
    else
        if value > 1000000 then
            minChips = 1
        elseif value > 100000 then
            minChips = 3
        end
    end
    for i, j in ipairs(chip_values) do
        local tableIndex = -i + 17
        local denomination = chip_values[tableIndex]
        if denomination * minChips <= valueRemaining or tableIndex <= 3 then
            local chipCount = 0
            Game.GetPlayer():PlaySoundEvent("q303_06a_roulette_chips_bet")

            if colorsSoFar < minColors then
                chipCount = math.floor(valueRemaining * splitSizing / denomination)
            else
                chipCount = math.floor(valueRemaining / denomination)
            end
            if chipCount > 0 then
                colorsSoFar = colorsSoFar + 1
                valueRemaining = valueRemaining - chipCount * denomination

                queuedChips[tableIndex] = queuedChips[tableIndex] + chipCount
            end
        end
    end

    if queue == betsPileQueue then
        local loopCount = 0
        local noValuesOverMax = false
        while noValuesOverMax == false do
            noValuesOverMax = true
            loopCount = loopCount + 1
            for i, j in ipairs(queuedChips) do
                if i == 16 then
                    break
                end
                if j > maxChipsPerColor then
                    noValuesOverMax = false
                    local chipExtras = j - maxChipsPerColor
                    local extraValue = chip_values[i] * chipExtras
                    local higherChipFitCountRaw = extraValue /chip_values[i+1]
                    --potentially check if I can do 1 more chip in future, since I have 10 chips of 'padding' 'left over'
                    local higherChipFitCount = math.floor(higherChipFitCountRaw)
                    local lowerChipValue = 0
                    local lowerChipFitCount = 0
                    --check if i is divisible by i-1
                    local lowerChipIndex = 1
                    if (chip_values[i] % chip_values[i-1]) ~= 0 then
                        lowerChipIndex = 2
                    end
                    if (higherChipFitCountRaw - higherChipFitCount) > 0 then -- if there's a remainder, pay lower chip difference
                        lowerChipValue = (higherChipFitCountRaw - higherChipFitCount) * chip_values[i+1]
                        lowerChipFitCount = math.floor(lowerChipValue / chip_values[i-lowerChipIndex])
                    end
                    local higherValue = higherChipFitCount * chip_values[i+1]
                    local lowerValue = lowerChipFitCount * chip_values[i-lowerChipIndex]
                    local targetChipRemoveCount = (higherValue + lowerValue) / chip_values[i]

                    queuedChips[i] = queuedChips[i] - targetChipRemoveCount
                    queuedChips[i+1] = queuedChips[i+1] + higherChipFitCount
                    queuedChips[i-lowerChipIndex] = queuedChips[i-lowerChipIndex] + lowerChipFitCount
                end
            end
            if loopCount > 15 then
                DuelPrint('=M ERROR noValuesOverMax loop stuck, code 5489')
                noValuesOverMax = true
            end
        end
    end

    if valueRemaining > 0 then --catch any extra value. Should be unnecessary, but just a safeguard
        --DuelPrint('=M ERROR: valueRemaining > 0, CODE 3389')
                --supressed until I look into it. idk, its spamming my console but the game works. #TODO
                        --prints on wheel press UI trigger, and when main menu UI returns after chip payout.
        queuedChips[1] = queuedChips[1] + valueRemaining
    end

    for i, j in ipairs(queuedChips) do
        local tableIndex = -i + 17
        if queuedChips[tableIndex] > 0 then
            table.insert(queue, {pile=localPile,cIndex=tableIndex,amount=queuedChips[tableIndex]})
        end
    end
end

function ValueToQueueSubtraction(localPile, value) -- find chips in pile that add up to value, set chips to subtractionQueue
    if localPile.value < value then --catch in case of value higher then total chips
        DuelPrint('=p FATAL ERROR: localPile.value < value, CODE 4781')
        return
    end

    local valueRemaining = value
    local pileQueueChips = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0} --record of chip moves to send to queues

    --create table of all pile chips
    local pileChips = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0} --record of current pile chips, updates internally
    for i, j in ipairs(pileChips) do --set pileChips[i] equal to total chips of that color
        pileChips[i] = localPile.singleStacks[i]
        pileChips[i] = pileChips[i] + ( localPile.fullStacks[i] * 10 )
    end

    while valueRemaining > 0 do
        subtractionValueLoopCount = subtractionValueLoopCount + 1
        --for every chip color used in localPile, from highest to lowest, check max chip count that can be removed towards value
        for i, j in ipairs(pileChips) do
            local ri = -i + 17 --reverse index to start from higher value chips
            local chipValue = chip_values[ri]
            if pileChips[ri] > 0 then
                if valueRemaining >= chipValue then
                    local fitChipCount = math.floor(valueRemaining / chipValue)
                    local chipsToUse = 0
                    if fitChipCount > pileChips[ri] then
                        chipsToUse = pileChips[ri]
                    else
                        chipsToUse = fitChipCount
                    end
                    valueRemaining = valueRemaining - (chipsToUse * chipValue)
                    pileQueueChips[ri] = pileQueueChips[ri] - chipsToUse
                    pileChips[ri] = pileChips[ri] - chipsToUse

                    subtractionValueLoopCount = 0 --?? is this the right spot? --left off here 5/20 2AM
                end
            end
        end
        if valueRemaining == 0 then
            break
        end
        --logic to split pile chips / make change
        for i, j in ipairs(pileChips) do
            local chipValue = chip_values[i] --cash value of current indexed chip
            local pastChipValue = chip_values[i-1]
            if
                i > 1  and --can't make change for 1 cent
                valueRemaining < chipValue and
                pileChips[i] > 0 --check if the pile can give a chip for change
            then
                pileQueueChips[i] = pileQueueChips[i] - 1 --remove 1 chip from pile
                pileChips[i] = pileChips[i] - 1 --remove chip to update pileChips record, used in while loop
                --new chips:
                local firstChangeChipsRaw = chipValue / pastChipValue-- how many new chips can be made, float
                local firstChangeChipsRounded = math.floor(firstChangeChipsRaw)
                local firstChangeRemainder = firstChangeChipsRaw - firstChangeChipsRounded --find what change is left, if half chip then repeat for next lower chip
                pileQueueChips[i-1] = pileQueueChips[i-1] + firstChangeChipsRounded --insert change into pile
                pileChips[i-1] = pileChips[i-1] + firstChangeChipsRounded --update pile reference
                if firstChangeRemainder > 0 and chip_values[i-2] then --if there is change and there is a chip color 2 lower
                    --new 2nd chips: (kinda a repeat of above)
                    local rawRemainderValue = firstChangeRemainder * pastChipValue
                    local oldChipValue = chip_values[i-2]
                    local secondChangeChipsRaw = rawRemainderValue / oldChipValue
                    local secondChangeChipsRounded = math.floor(secondChangeChipsRaw)
                    local secondChangeRemainder = secondChangeChipsRaw - secondChangeChipsRounded
                    pileQueueChips[i-2] = pileQueueChips[i-2] + secondChangeChipsRounded
                    pileChips[i-2] = pileChips[i-2] + secondChangeChipsRounded
                    if secondChangeRemainder > 0 then
                        DuelPrint('=p FATAL ERROR: secondChangeRemainder > 0, CODE 3876, secondChangeRemainder = '..secondChangeRemainder) --remaining change after 2 colors lower? weird. try logging
                        return
                    end
                end
                break
            else
                --DuelPrint('=p skipped chip, i: '..i..' valueRemaining: '..valueRemaining..' chipValue: '..chipValue..' pileChips[i]: '..pileChips[i])
            end
        end
        if subtractionValueLoopCount > 20 then
            DuelPrint('=p FATAL ERROR: subtractionValueLoopCount > 20, CODE 2642') --major loop issue. log away.  I know I'll be here again...-5/20/24-1:58AM. Occur tally: 2
            return
        end
    end --end while loop

    --DuelPrint('=p pileQueueChips: {'..pileQueueChips[1]..','..pileQueueChips[2]..','..pileQueueChips[3]..','..pileQueueChips[4]..','..pileQueueChips[5]..','..pileQueueChips[6]..','..pileQueueChips[7]..','..pileQueueChips[8]..','
    --                                ..pileQueueChips[9]..','..pileQueueChips[10]..','..pileQueueChips[11]..','..pileQueueChips[12]..','..pileQueueChips[13]..','..pileQueueChips[14]..','..pileQueueChips[15]..','..pileQueueChips[16]..'}')
    for i, j in ipairs(pileQueueChips) do --for every non-zero, add to pileQueue or pileSubtractionQueue
        if j > 0 then
            table.insert(pileQueue, {pile=localPile,cIndex=i,amount=j})
        elseif j < 0 then
            local valueJ = -j --invert negative for subtraction queue
            table.insert(pileSubtractionQueue, {pile=localPile,cIndex=i,amount=valueJ})
        end
    end
end

function QueuedChipSubtraction() -- each tick, subtract a chip from a pile, based on pileSubtractionQueue table
    --[[    --attempted bug fix
    if next(betsPileQueue) ~= nil then --exit if any chip additions are currently queued up
        return
    end
    ]]--
    if next(pileSubtractionQueue) == nil then --exit function if no actions needed.
        return
    end

    --get pile, color, amount
    local localPile = pileSubtractionQueue[1].pile
    local localIndex = pileSubtractionQueue[1].cIndex
    local localAmount = pileSubtractionQueue[1].amount
    local locDevName = ('c' --"color"
                        ..tostring(localIndex)
                        ..'_s' --"stack#"
                        ..tostring(localPile.fullStacks[localIndex] + 1)
                        ..'_chips'
                    ) --eg "c1_s1_chips"
    local curentSingleAmount = localPile.singleStacks[localIndex]
    local newApp = curentSingleAmount - 1
    if newApp < 0 then
        DuelPrint('=o ERROR: newApp < 0, CODE 2374')
        table.remove(pileSubtractionQueue, 1)
        return
    end
    if newApp == 0 then
        if localPile.fullStacks[localIndex] > 0 then
            localPile.fullStacks[localIndex] = localPile.fullStacks[localIndex] - 1
            localPile.singleStacks[localIndex] = 10
        else
            localPile.singleStacks[localIndex] = 0
        end
        DeRegisterEntity(locDevName)
        for i, j in ipairs(localPile.stacksInfo) do
            if j.stackDevName == locDevName then
                table.remove(localPile.stacksInfo, i)
                break
            end
        end
    else
        localPile.singleStacks[localIndex] = newApp
        local entity = Game.FindEntityByID(FindEntIdByName(locDevName))
        local appearanceString = (tostring(newApp)..'_'..chip_colors[localIndex])
        entity:ScheduleAppearanceChange(appearanceString) --updates entity's appearance
    end

    pileSubtractionQueue[1].amount = pileSubtractionQueue[1].amount - 1

    if pileSubtractionQueue[1].amount == 0 then --if queue object amount is 0, remove it
        table.remove(pileSubtractionQueue, 1)
    end
end

function QueuedBetChipAddition() -- each tick, add a chip to a pile, based on pileQueue table
    if next(betsPileQueue) == nil then --exit function if no actions needed.
        return
    end
    local queueCount = 0
    for i, j in ipairs(betsPileQueue) do
        queueCount = queueCount + 1
    end
    local localPile = betsPileQueue[1].pile
    local localIndex = betsPileQueue[1].cIndex
    local betID = localPile.id
    local locDevName = (betID
                        ..'_c' --"color"
                        ..tostring(localIndex)
                        ..'_s'
                        ..localPile.fullStacks[localIndex]
                        ..'_chips'
                    ) --eg "c1_s1_chips"
    local chipCount = localPile.chipCount
    local pileLocation = localPile.location
    if localPile.singleStacks[localIndex] == 0 then --if there is no 1-9 chip stack currently
        local newAmount = localPile.singleStacks[localIndex] + 1
        localPile.singleStacks[localIndex] = newAmount --increase stack amount in pile data

        local spawnHeight = pileLocation.z + chipHeight*chipCount
        local locAppearance = (tostring(newAmount)..'_'..chip_colors[localIndex])
        RegisterEntity(locDevName, poker_chip, locAppearance, {x=pileLocation.x, y=pileLocation.y, z=spawnHeight}) --add random rotation after spawn w/ cron delay, similar to hologram rotation logic. (could apply to regular chip stacks too actually)
        table.insert(
            localPile.stacksInfo,
            {
                stackDevName = locDevName,
                cIndex = localIndex
            }
        )
        local callback = function()
            SetRotateEnt(locDevName, {r=0, p=0, y=math.random(1,360)})
        end
        Cron.After(0.1, callback)
    elseif localPile.singleStacks[localIndex] < 10 then
        local newAmount = localPile.singleStacks[localIndex] + 1
        localPile.singleStacks[localIndex] = newAmount --increase stack amount in pile data
        local newApperance = (tostring(newAmount)..'_'..chip_colors[localIndex])

        --update entity appearance +1
        local entity = Game.FindEntityByID(FindEntIdByName(locDevName))
        entity:ScheduleAppearanceChange(newApperance) --updates entity's appearance
    end
    if localPile.singleStacks[localIndex] == 10 then
        localPile.fullStacks[localIndex] = localPile.fullStacks[localIndex] + 1 --increase stack count in pile data
        localPile.singleStacks[localIndex] = 0
    end

    localPile.chipCount = localPile.chipCount + 1
    betsPileQueue[1].amount = betsPileQueue[1].amount - 1
    if betsPileQueue[1].amount == 0 then
        table.remove(betsPileQueue, 1)
    end
    if currentlyRepeatingBets == true then
        if next(betsPileQueue) == nil then --if used repeat bet function & reached end of queue, display main menu UI
            currentlyRepeatingBets = false
            local callback = function()
                RouletteMainMenu.MainMenuUI()
            end
            Cron.After(0.2, callback)
        end
    end
end

function QueuedChipAddition() -- each tick, add a chip to a pile, based on pileQueue table
    if next(pileQueue) == nil then --exit function if no actions needed.
        return
    end

    local localPile = pileQueue[1].pile
    local localIndex = pileQueue[1].cIndex
    local locDevName = ('c' --"color"
                        ..tostring(localIndex)
                        ..'_s' --"stack#"
                        ..tostring(localPile.fullStacks[localIndex] + 1)
                        ..'_chips'
                    ) --eg "c1_s1_chips"


    if localPile.singleStacks[localIndex] == 0 then --if there is no 1-9 chip stack currently
        local newAmount = localPile.singleStacks[localIndex] + 1
        localPile.singleStacks[localIndex] = newAmount --increase stack amount in pile data

        FindAndSpawnStack(localPile, localIndex, 1)

    elseif localPile.singleStacks[localIndex] == maxStackSize then
        --update pile info for maxed single stack to move to full stacks table
        localPile.fullStacks[localIndex] = localPile.fullStacks[localIndex] + 1 --increase full stacks count by 1
        localPile.singleStacks[localIndex] = 1 --reset single stacks count. (0 +1, since we are adding a new single stack)

        FindAndSpawnStack(localPile, localIndex, 1)
    else --if there is an existing 1-9 chip stack
        local newAmount = localPile.singleStacks[localIndex] + 1
        localPile.singleStacks[localIndex] = newAmount

        local entity = Game.FindEntityByID(FindEntIdByName(locDevName))
        entity:ScheduleAppearanceChange((tostring(newAmount)..'_'..chip_colors[localIndex])) --updates entity's appearance
    end

    pileQueue[1].amount = pileQueue[1].amount - 1

    if pileQueue[1].amount == 0 then
        table.remove(pileQueue, 1)
    end
end

function FindAndSpawnStack(localPile, localIndex, value) --create/spawn additional stack in a pile
    local nextHexLocation = FindNextStackLayoutLocation(localPile, localIndex)
    local xOffsetIfEven = -0.02 * nextHexLocation.y + 0.02
    local locAppearance = (value..'_' .. chip_colors[localIndex])
    local nextLocationOffset = {
                            x=nextHexLocation.x * 0.04 + xOffsetIfEven,
                            y=nextHexLocation.y * 0.035,
                            z=(nextHexLocation.z-1) * 0.035
                        }
    local stackRotation = (activeTable.tableRotation + chipRotation) * math.pi / 180
    local nextLocationRotated = {
                            x=( nextLocationOffset.x * math.cos(stackRotation) ) - ( nextLocationOffset.y * math.sin(stackRotation) ),
                            y=( nextLocationOffset.y * math.cos(stackRotation) ) + ( nextLocationOffset.x * math.sin(stackRotation) ),
                            z=nextLocationOffset.z
                        }
    local nextLocation = {
                            x=localPile.location.x + nextLocationRotated.x,
                            y=localPile.location.y + nextLocationRotated.y,
                            z=localPile.location.z + nextLocationRotated.z
                        }
    local devName = ('c' --"color"
                        ..tostring(localIndex)
                        ..'_s' --"stack#"
                        ..tostring(localPile.fullStacks[localIndex] + 1)
                        ..'_chips'
                    ) --eg "c1_s1_chips"
    --n/a

    RegisterEntity(devName, poker_chip, locAppearance, nextLocation)
    table.insert(
        localPile.stacksInfo,
        {
            stackDevName = devName,
            cIndex = localIndex,
            hexCoords = nextHexLocation
        }
    )
    local callback = function()
        SetRotateEnt(devName, {r=0, p=0, y=math.random(1,360)})
    end
    Cron.After(0.1, callback)
    stackSearchOld = {x=234, y=543, z=345} --reset stack search stuck checking info
    stackSearchPrevious = {x=753, y=653, z=856}
    stackSearchCurrent = {x=427, y=148, z=993}
end

function FindNextStackLayoutLocation(localPile, cIndex) --output {x=i,y=i,z=i} based on cIndex and current pile layout

    if not CheckStackLayoutCoords(localPile, {x=1, y=1, z=1}) then --if search coordinates are empty
        return {x=1, y=1, z=1}
    end
    local localcIndex = CheckStackLayoutCoords(localPile, {x=1, y=1, z=1})
    searchStepCount = 0
    local stepInfo = StackLocationSearchStep(localPile, {x=1, y=1, z=1}, cIndex, searchStepCount)

    while stepInfo[2] == false do
        searchStepCount = searchStepCount + 1
        if stepInfo[1].x ~= stepInfo[1].x then
            stepInfo = {{x=1, y=1, z=2}, true}
        else
            stepInfo = StackLocationSearchStep(localPile, stepInfo[1], cIndex, searchStepCount)
        end
        local shouldStep = stepInfo[2]
        if stepInfo[1].x < localPile.limits.minX then
            stepInfo[1].x = localPile.limits.minX
            shouldStep = false
        end
        if stepInfo[1].x > localPile.limits.maxX then
            stepInfo[1].x = localPile.limits.maxX
            shouldStep = false
        end
        if stepInfo[1].y < localPile.limits.minY then
            stepInfo[1].y = localPile.limits.minY
            shouldStep = false
        end
        if stepInfo[1].y > localPile.limits.maxY then
            stepInfo[1].y = localPile.limits.maxY
            shouldStep = false
        end
        if stepInfo[1].z < localPile.limits.minZ then
            stepInfo[1].z = localPile.limits.minZ
            shouldStep = false
        end
        if stepInfo[1].z > localPile.limits.maxZ then
            stepInfo[1].z = localPile.limits.maxZ
            shouldStep = false
        end
        stepInfo[2] = shouldStep
    end
    if stepInfo[2] == true then
        return stepInfo[1]
    end

    DuelPrint('=c error end function return {x=1, y=3, z=2}, code 0925')
    return {x=1, y=3, z=2}
end

function StackLocationSearchStep(localPile, hexCoords, cIndex, stepCount) --returns {hexCoords, false} or {hexCoords, true} boolean indicates end of search

    --search stuck loop detection
    stackSearchOld = {x=stackSearchPrevious.x, y=stackSearchPrevious.y, z=stackSearchPrevious.z}
    stackSearchPrevious = {x=stackSearchCurrent.x, y=stackSearchCurrent.y, z=stackSearchCurrent.z}
    stackSearchCurrent = {x=hexCoords.x, y=hexCoords.y, z=hexCoords.z}
    if stackSearchOld.y == stackSearchCurrent.y
        and stackSearchOld.y == stackSearchCurrent.y
        and stackSearchOld.z == stackSearchCurrent.z
    then
        return SearchStuckExit(localPile, stackSearchCurrent, stackSearchPrevious, stackSearchOld)
    end
    if stepCount == 25 then
        return WideHexSearch(localPile, {x=hexCoords.x, y=hexCoords.y, z=hexCoords.z}, cIndex)
    elseif stepCount >= 50 then
        return {x=stackSearchCurrent.x, y=stackSearchCurrent.y+2, z=stackSearchCurrent.z+1}, true
    end
    --end stuck search code lol

    local onLeft = CheckStackLayoutCoords(localPile, {x=hexCoords.x-1, y=hexCoords.y, z=hexCoords.z})
    local onRight = CheckStackLayoutCoords(localPile, {x=hexCoords.x+1, y=hexCoords.y, z=hexCoords.z})
    local topLeft = CheckStackLayoutCoords(localPile, {x=hexCoords.x, y=hexCoords.y+1, z=hexCoords.z})
    local topRight = CheckStackLayoutCoords(localPile, {x=hexCoords.x+1, y=hexCoords.y+1, z=hexCoords.z})
    local bottomLeft = CheckStackLayoutCoords(localPile, {x=hexCoords.x-1, y=hexCoords.y-1, z=hexCoords.z})
    local bottomRight = CheckStackLayoutCoords(localPile, {x=hexCoords.x, y=hexCoords.y-1, z=hexCoords.z})
    local center = CheckStackLayoutCoords(localPile, {x=hexCoords.x, y=hexCoords.y, z=hexCoords.z})

    local localStackCount = CountSevenHex(localPile, {x=hexCoords.x, y=hexCoords.y, z=hexCoords.z})

    if not center then --if center empty
        return CheckEmptyAndShift(localPile, hexCoords, localStackCount)
    end

    if cIndex == center then --if center stack is the same color
        if not onRight then
            return {{x=hexCoords.x+1, y=hexCoords.y, z=hexCoords.z}, false}
        elseif not onLeft then
            return {{x=hexCoords.x-1, y=hexCoords.y, z=hexCoords.z}, false}
        elseif not topRight then
            return {{x=hexCoords.x+1, y=hexCoords.y+1, z=hexCoords.z}, false}
        elseif not topLeft then
            return {{x=hexCoords.x, y=hexCoords.y+1, z=hexCoords.z}, false}
        elseif not bottomRight then
            return {{x=hexCoords.x, y=hexCoords.y-1, z=hexCoords.z}, false}
        elseif not bottomLeft then
            return {{x=hexCoords.x-1, y=hexCoords.y-1, z=hexCoords.z}, false}
        end
        local left2 = CountSevenHex(localPile, {x=hexCoords.x-2, y=hexCoords.y, z=hexCoords.z})
        local right2 = CountSevenHex(localPile, {x=hexCoords.x+2, y=hexCoords.y, z=hexCoords.z})

        --"near touching" stacks check
        local nearSpotsNeighbors = {
            { {x=hexCoords.x-1, y=hexCoords.y, z=hexCoords.z}, {x=hexCoords.x-2, y=hexCoords.y, z=hexCoords.z}, {x=hexCoords.x-1, y=hexCoords.y+1, z=hexCoords.z}, {x=hexCoords.x-2, y=hexCoords.y-1, z=hexCoords.z} }, --touchingLeft
            { {x=hexCoords.x+1, y=hexCoords.y, z=hexCoords.z}, {x=hexCoords.x+2, y=hexCoords.y, z=hexCoords.z}, {x=hexCoords.x+2, y=hexCoords.y+1, z=hexCoords.z}, {x=hexCoords.x+1, y=hexCoords.y-1, z=hexCoords.z} }, --touchingRight
            { {x=hexCoords.x, y=hexCoords.y+1, z=hexCoords.z}, {x=hexCoords.x-1, y=hexCoords.y+1, z=hexCoords.z}, {x=hexCoords.x, y=hexCoords.y+2, z=hexCoords.z}, {x=hexCoords.x+1, y=hexCoords.y+2, z=hexCoords.z} }, --touchingTopLeft
            { {x=hexCoords.x+1, y=hexCoords.y+1, z=hexCoords.z}, {x=hexCoords.x+2, y=hexCoords.y+1, z=hexCoords.z}, {x=hexCoords.x+2, y=hexCoords.y+2, z=hexCoords.z}, {x=hexCoords.x+1, y=hexCoords.y+2, z=hexCoords.z} }, --touchingTopRight
            { {x=hexCoords.x-1, y=hexCoords.y-1, z=hexCoords.z}, {x=hexCoords.x-2, y=hexCoords.y-1, z=hexCoords.z}, {x=hexCoords.x-2, y=hexCoords.y-2, z=hexCoords.z}, {x=hexCoords.x-1, y=hexCoords.y-2, z=hexCoords.z} }, --touchingBottomLeft
            { {x=hexCoords.x, y=hexCoords.y-1, z=hexCoords.z}, {x=hexCoords.x+1, y=hexCoords.y-1, z=hexCoords.z}, {x=hexCoords.x, y=hexCoords.y-2, z=hexCoords.z}, {x=hexCoords.x-1, y=hexCoords.y-2, z=hexCoords.z} } --touchingBottomRight
        }
        for i,v in pairs(nearSpotsNeighbors) do
            local touchingColor = CheckStackLayoutCoords(localPile, v[1])
            if touchingColor == cIndex then
                for j=1,3 do
                    local spot = v[j+1]
                    if not CheckStackLayoutCoords(localPile, spot) then return {spot, true} end
                end
            end
        end

        return WideHexSearch(localPile, {x=hexCoords.x, y=hexCoords.y, z=hexCoords.z}, cIndex)
    elseif cIndex > center then
        if localStackCount <= 7 then
            if not onRight then
                return {{x=hexCoords.x+1, y=hexCoords.y, z=hexCoords.z}, true}
            elseif not topRight then
                return {{x=hexCoords.x+1, y=hexCoords.y+1, z=hexCoords.z}, true}
            elseif not bottomRight then
                return {{x=hexCoords.x, y=hexCoords.y-1, z=hexCoords.z}, true}
            elseif not CheckStackLayoutCoords(localPile, {x=hexCoords.x+2, y=hexCoords.y, z=hexCoords.z}) then
                return {{x=hexCoords.x+2, y=hexCoords.y, z=hexCoords.z}, true}
            end
        end
        return WideHexSearch(localPile, {x=hexCoords.x, y=hexCoords.y, z=hexCoords.z}, cIndex)
    else -- cIndex < center
        if localStackCount <= 7 then
            if not onLeft then
                return {{x=hexCoords.x-1, y=hexCoords.y, z=hexCoords.z}, true}
            elseif not topLeft then
                return {{x=hexCoords.x, y=hexCoords.y+1, z=hexCoords.z}, true}
            elseif not bottomLeft then
                return {{x=hexCoords.x-1, y=hexCoords.y-1, z=hexCoords.z}, true}
            elseif not CheckStackLayoutCoords(localPile, {x=hexCoords.x-2, y=hexCoords.y, z=hexCoords.z}) then
                return {{x=hexCoords.x-2, y=hexCoords.y, z=hexCoords.z}, true}
            end
        end
        return WideHexSearch(localPile, {x=hexCoords.x, y=hexCoords.y, z=hexCoords.z}, cIndex)
    end
end

function CheckEmptyAndShift(localPile, hexCoords, stackCount) --from an empty coordinate, check if touching neighbors and/or move towards pile center, return new search coords & true/false "{x,y,z}, true"
    if stackCount >= 2 then
        return {{x=hexCoords.x, y=hexCoords.y, z=hexCoords.z}, true}
    elseif stackCount == 1 then
        local emptyNeighborsTable = {
            {{x=hexCoords.x-1, y=hexCoords.y, z=hexCoords.z},{x=hexCoords.x, y=hexCoords.y+1, z=hexCoords.z},{x=hexCoords.x-1, y=hexCoords.y-1, z=hexCoords.z}},--left
            {{x=hexCoords.x+1, y=hexCoords.y, z=hexCoords.z},{x=hexCoords.x+1, y=hexCoords.y+1, z=hexCoords.z},{x=hexCoords.x, y=hexCoords.y-1, z=hexCoords.z}},--right
            --WIP here, convert below if code into a pretty for loop.
        }
        if CheckStackLayoutCoords(localPile, {x=hexCoords.x-1, y=hexCoords.y, z=hexCoords.z}) then --left
            local upper = CountSevenHex(localPile, {x=hexCoords.x, y=hexCoords.y+1, z=hexCoords.z})
            local lower = CountSevenHex(localPile, {x=hexCoords.x-1, y=hexCoords.y-1, z=hexCoords.z})
            if upper >= 2 then
                return {{x=hexCoords.x, y=hexCoords.y+1, z=hexCoords.z}, true}
            elseif lower >= 2 then
                return {{x=hexCoords.x-1, y=hexCoords.y-1, z=hexCoords.z}, true}
            end
        elseif CheckStackLayoutCoords(localPile, {x=hexCoords.x+1, y=hexCoords.y, z=hexCoords.z}) then --right
            local upper = CountSevenHex(localPile, {x=hexCoords.x+1, y=hexCoords.y+1, z=hexCoords.z})
            local lower = CountSevenHex(localPile, {x=hexCoords.x, y=hexCoords.y-1, z=hexCoords.z})
            if upper >= 2 then
                return {{x=hexCoords.x+1, y=hexCoords.y+1, z=hexCoords.z}, true}
            elseif lower >= 2 then
                return {{x=hexCoords.x, y=hexCoords.y-1, z=hexCoords.z}, true}
            end
        elseif CheckStackLayoutCoords(localPile, {x=hexCoords.x, y=hexCoords.y+1, z=hexCoords.z}) then --top left
            local right = CountSevenHex(localPile, {x=hexCoords.x+1, y=hexCoords.y+1, z=hexCoords.z})
            local left = CountSevenHex(localPile, {x=hexCoords.x-1, y=hexCoords.y, z=hexCoords.z})
            if right >= 2 then
                return {{x=hexCoords.x+1, y=hexCoords.y+1, z=hexCoords.z}, true}
            elseif left >= 2 then
                return {{x=hexCoords.x-1, y=hexCoords.y, z=hexCoords.z}, true}
            end
        elseif CheckStackLayoutCoords(localPile, {x=hexCoords.x+1, y=hexCoords.y+1, z=hexCoords.z}) then --top right
            local left = CountSevenHex(localPile, {x=hexCoords.x, y=hexCoords.y+1, z=hexCoords.z})
            local right = CountSevenHex(localPile, {x=hexCoords.x+1, y=hexCoords.y, z=hexCoords.z})
            if left >= 2 then
                return {{x=hexCoords.x, y=hexCoords.y+1, z=hexCoords.z}, true}
            elseif right >= 2 then
                return {{x=hexCoords.x+1, y=hexCoords.y, z=hexCoords.z}, true}
            end
        elseif CheckStackLayoutCoords(localPile, {x=hexCoords.x-1, y=hexCoords.y-1, z=hexCoords.z}) then --bottom left
            local right = CountSevenHex(localPile, {x=hexCoords.x, y=hexCoords.y-1, z=hexCoords.z})
            local left = CountSevenHex(localPile, {x=hexCoords.x-1, y=hexCoords.y, z=hexCoords.z})
            if right >= 2 then
                return {{x=hexCoords.x, y=hexCoords.y-1, z=hexCoords.z}, true}
            elseif left >= 2 then
                return {{x=hexCoords.x-1, y=hexCoords.y, z=hexCoords.z}, true}
            end
        elseif CheckStackLayoutCoords(localPile, {x=hexCoords.x, y=hexCoords.y-1, z=hexCoords.z}) then --bottom right
            local left = CountSevenHex(localPile, {x=hexCoords.x-1, y=hexCoords.y-1, z=hexCoords.z})
            local right = CountSevenHex(localPile, {x=hexCoords.x+1, y=hexCoords.y, z=hexCoords.z})
            if left >= 2 then
                return {{x=hexCoords.x-1, y=hexCoords.y-1, z=hexCoords.z}, true}
            elseif right >= 2 then
                return {{x=hexCoords.x+1, y=hexCoords.y, z=hexCoords.z}, true}
            end
        end
        return {{x=hexCoords.x, y=hexCoords.y, z=hexCoords.z}, false}
    else --stackCount == 0
        if localPile.stacksInfo == {} then
            return {{x=hexCoords.x, y=hexCoords.y, z=hexCoords.z}, true}
        end
        --find average position of all stacks
        local averagePileLocation = AveragePileLocationFloat(localPile)

        local neighborsTable = {
            {x=hexCoords.x-1, y=hexCoords.y, z=hexCoords.z},
            {x=hexCoords.x+1, y=hexCoords.y, z=hexCoords.z},
            {x=hexCoords.x, y=hexCoords.y+1, z=hexCoords.z},
            {x=hexCoords.x+1, y=hexCoords.y+1, z=hexCoords.z},
            {x=hexCoords.x-1, y=hexCoords.y-1, z=hexCoords.z},
            {x=hexCoords.x, y=hexCoords.y-1, z=hexCoords.z}
        }
        local nearestNeighbor = 999
        for i,v in pairs(neighborsTable) do --find shortest distance
            local distance = math.sqrt(math.pow(averagePileLocation.x - v.x, 2) + math.pow(averagePileLocation.y - v.y, 2) + math.pow(averagePileLocation.z - v.z, 2))
            if nearestNeighbor > distance then
                nearestNeighbor = distance
            end
        end
        for i,v in pairs(neighborsTable) do --return shortest distance
            local distance = math.sqrt(math.pow(averagePileLocation.x - v.x, 2) + math.pow(averagePileLocation.y - v.y, 2) + math.pow(averagePileLocation.z - v.z, 2))
            if distance == nearestNeighbor then
                return {{x=v.x, y=v.y, z=v.z}, false}
            end
        end
        return {{x=hexCoords.x+2, y=hexCoords.y, z=hexCoords.z+1}, true}
    end
end

function SearchStuckExit(localPile, localstackSearchCurrent, localstackSearchPrevious, localstackSearchOld) --last case, try medium search, or spit out error coordinates (z=+1)

    local mediumSearched = MediumSearchAggressive(localPile, {x=localstackSearchCurrent.x, y=localstackSearchCurrent.y, z=localstackSearchCurrent.z})
    if mediumSearched[2] == true then return mediumSearched end

    local currentStackColor = CheckStackLayoutCoords(localPile, {x=localstackSearchCurrent.x, y=localstackSearchCurrent.y, z=localstackSearchCurrent.z})
    local previousStackColor = CheckStackLayoutCoords(localPile, {x=localstackSearchPrevious.x, y=localstackSearchPrevious.y, z=localstackSearchPrevious.z})
    local oldStackColor = CheckStackLayoutCoords(localPile, {x=localstackSearchOld.x, y=localstackSearchOld.y, z=localstackSearchOld.z})

    if currentStackColor ~= oldStackColor then
        if currentStackColor == previousStackColor then
            return {x=localstackSearchCurrent.x, y=localstackSearchCurrent.y, z=localstackSearchCurrent.z+1}, true
        end
        if currentStackColor > previousStackColor then
            return {x=localstackSearchCurrent.x, y=localstackSearchCurrent.y-1, z=localstackSearchCurrent.z+1}, true
        elseif currentStackColor < previousStackColor then
            return {x=localstackSearchPrevious.x, y=localstackSearchPrevious.y+1, z=localstackSearchPrevious.z+1}, true
        end
    else
        return {x=localstackSearchCurrent.x, y=localstackSearchCurrent.y+1, z=localstackSearchCurrent.z+1}, true
    end
end

function AveragePileLocationFloat(localPile) --returns the {x,y,z} of the average location of all stacks in the pile
    local averageX = 0
    local averageY = 0
    local averageZ = 0
    local stackCount = 0
    for k,v in pairs(localPile.stacksInfo) do
        averageX = averageX + v.hexCoords.x
        averageY = averageY + v.hexCoords.y
        averageZ = averageZ + v.hexCoords.z
        stackCount = stackCount + 1
    end
    averageX = averageX / stackCount
    averageY = averageY / stackCount
    averageZ = averageZ / stackCount
    return {x=averageX, y=averageY, z=averageZ}
end

function MediumSearchAggressive(localPile, hexCoords) --checks for ANY empty space within 2 hex of coordinates. returns "{xyz}, true" if found
    local center = CheckStackLayoutCoords(localPile, {x=hexCoords.x, y=hexCoords.y, z=hexCoords.z})
    local onLeft = CheckStackLayoutCoords(localPile, {x=hexCoords.x-1, y=hexCoords.y, z=hexCoords.z})
    local onRight = CheckStackLayoutCoords(localPile, {x=hexCoords.x+1, y=hexCoords.y, z=hexCoords.z})
    local topLeft = CheckStackLayoutCoords(localPile, {x=hexCoords.x, y=hexCoords.y+1, z=hexCoords.z})
    local topRight = CheckStackLayoutCoords(localPile, {x=hexCoords.x+1, y=hexCoords.y+1, z=hexCoords.z})
    local bottomLeft = CheckStackLayoutCoords(localPile, {x=hexCoords.x-1, y=hexCoords.y-1, z=hexCoords.z})
    local bottomRight = CheckStackLayoutCoords(localPile, {x=hexCoords.x, y=hexCoords.y-1, z=hexCoords.z})

    if not center then return {{x=hexCoords.x, y=hexCoords.y, z=hexCoords.z}, true} end
    if not onLeft then return {{x=hexCoords.x-1, y=hexCoords.y, z=hexCoords.z}, true} end
    if not onRight then return {{x=hexCoords.x+1, y=hexCoords.y, z=hexCoords.z}, true} end
    if not topLeft then return {{x=hexCoords.x, y=hexCoords.y+1, z=hexCoords.z}, true} end
    if not topRight then return {{x=hexCoords.x+1, y=hexCoords.y+1, z=hexCoords.z}, true} end
    if not bottomLeft then return {{x=hexCoords.x-1, y=hexCoords.y-1, z=hexCoords.z}, true} end
    if not bottomRight then return {{x=hexCoords.x, y=hexCoords.y-1, z=hexCoords.z}, true} end

    local farLeftCenter = CheckStackLayoutCoords(localPile, {x=hexCoords.x-2, y=hexCoords.y, z=hexCoords.z})
    local farRightCenter = CheckStackLayoutCoords(localPile, {x=hexCoords.x+2, y=hexCoords.y, z=hexCoords.z})
    local farLeftUpper = CheckStackLayoutCoords(localPile, {x=hexCoords.x-1, y=hexCoords.y+1, z=hexCoords.z})
    local farRightUpper = CheckStackLayoutCoords(localPile, {x=hexCoords.x+2, y=hexCoords.y+1, z=hexCoords.z})
    local farLeftUnder = CheckStackLayoutCoords(localPile, {x=hexCoords.x-2, y=hexCoords.y-1, z=hexCoords.z})
    local farRightUnder = CheckStackLayoutCoords(localPile, {x=hexCoords.x+1, y=hexCoords.y-1, z=hexCoords.z})
    local farLeftTopUpper = CheckStackLayoutCoords(localPile, {x=hexCoords.x, y=hexCoords.y+2, z=hexCoords.z})
    local farRightTopUpper = CheckStackLayoutCoords(localPile, {x=hexCoords.x+2, y=hexCoords.y+2, z=hexCoords.z})
    local farCenterUpper = CheckStackLayoutCoords(localPile, {x=hexCoords.x+1, y=hexCoords.y+2, z=hexCoords.z})
    local farLeftBottomUnder = CheckStackLayoutCoords(localPile, {x=hexCoords.x-2, y=hexCoords.y-2, z=hexCoords.z})
    local farRightBottomUnder = CheckStackLayoutCoords(localPile, {x=hexCoords.x, y=hexCoords.y-2, z=hexCoords.z})
    local farCenterUnder = CheckStackLayoutCoords(localPile, {x=hexCoords.x-1, y=hexCoords.y-2, z=hexCoords.z})

    if not farLeftCenter then return {{x=hexCoords.x-2, y=hexCoords.y, z=hexCoords.z}, true} end
    if not farRightCenter then return {{x=hexCoords.x+2, y=hexCoords.y, z=hexCoords.z}, true} end
    if not farLeftUpper then return {{x=hexCoords.x-1, y=hexCoords.y+1, z=hexCoords.z}, true} end
    if not farRightUpper then return {{x=hexCoords.x+2, y=hexCoords.y+1, z=hexCoords.z}, true} end
    if not farLeftUnder then return {{x=hexCoords.x-2, y=hexCoords.y-1, z=hexCoords.z}, true} end
    if not farRightUnder then return {{x=hexCoords.x+1, y=hexCoords.y-1, z=hexCoords.z}, true} end
    if not farLeftTopUpper then return {{x=hexCoords.x, y=hexCoords.y+2, z=hexCoords.z}, true} end
    if not farRightTopUpper then return {{x=hexCoords.x+2, y=hexCoords.y+2, z=hexCoords.z}, true} end
    if not farCenterUpper then return {{x=hexCoords.x+1, y=hexCoords.y+2, z=hexCoords.z}, true} end
    if not farLeftBottomUnder then return {{x=hexCoords.x-2, y=hexCoords.y-2, z=hexCoords.z}, true} end
    if not farRightBottomUnder then return {{x=hexCoords.x, y=hexCoords.y-2, z=hexCoords.z}, true} end
    if not farCenterUnder then return {{x=hexCoords.x-1, y=hexCoords.y-2, z=hexCoords.z}, true} end

    --else
    return {{x=hexCoords.x, y=hexCoords.y+1, z=hexCoords.z}, false}
end

function WideHexSearch(localPile, hexCoords, cIndex) --from a coordinate, check area within 3 hex distance. returns new search coords & true/false
    local center = CountSevenHex(localPile, {x=hexCoords.x, y=hexCoords.y, z=hexCoords.z})
    local right = CountSevenHex(localPile, {x=hexCoords.x+2, y=hexCoords.y, z=hexCoords.z})
    local left = CountSevenHex(localPile, {x=hexCoords.x-2, y=hexCoords.y, z=hexCoords.z})
    local topRight = CountSevenHex(localPile, {x=hexCoords.x+2, y=hexCoords.y+2, z=hexCoords.z})
    local topLeft = CountSevenHex(localPile, {x=hexCoords.x, y=hexCoords.y+2, z=hexCoords.z})
    local bottomRight = CountSevenHex(localPile, {x=hexCoords.x, y=hexCoords.y-2, z=hexCoords.z})
    local bottomLeft = CountSevenHex(localPile, {x=hexCoords.x-2, y=hexCoords.y-2, z=hexCoords.z})

    local center_color = CheckStackLayoutCoords(localPile, {x=hexCoords.x, y=hexCoords.y, z=hexCoords.z})
    local right_color = CheckStackLayoutCoords(localPile, {x=hexCoords.x+2, y=hexCoords.y, z=hexCoords.z})
    local left_color = CheckStackLayoutCoords(localPile, {x=hexCoords.x-2, y=hexCoords.y, z=hexCoords.z})
    local topRight_color = CheckStackLayoutCoords(localPile, {x=hexCoords.x+2, y=hexCoords.y+2, z=hexCoords.z})
    local topLeft_color = CheckStackLayoutCoords(localPile, {x=hexCoords.x, y=hexCoords.y+2, z=hexCoords.z})
    local bottomRight_color = CheckStackLayoutCoords(localPile, {x=hexCoords.x, y=hexCoords.y-2, z=hexCoords.z})
    local bottomLeft_color = CheckStackLayoutCoords(localPile, {x=hexCoords.x-2, y=hexCoords.y-2, z=hexCoords.z})

    if center + right + left + topRight + topLeft + bottomRight + bottomLeft >= 7*7 then
        return {{x=hexCoords.x, y=hexCoords.y+1, z=hexCoords.z}, false}
    end

    local valueShift = 0
    if center_color then
        valueShift = valueShift + ((cIndex - center_color)*1)
    end
    if right_color then
        if cIndex > right_color then
            valueShift = valueShift + ((cIndex - right_color)*1)
        elseif cIndex == right_color then
            valueShift = valueShift + 1
        end
    end
    if left_color then
        if cIndex < left_color then
            valueShift = valueShift + ((cIndex - left_color)*1)
        elseif cIndex == left_color then
            valueShift = valueShift - 1
        end
    end
    if topRight_color then
        if cIndex > topRight_color then
            valueShift = valueShift + ((cIndex - topRight_color)*1)
        elseif cIndex == topRight_color then
            valueShift = valueShift + 1
        end
    end
    if topLeft_color then
        if cIndex < topLeft_color then
            valueShift = valueShift + ((cIndex - topLeft_color)*1)
        elseif cIndex == topLeft_color then
            valueShift = valueShift - 1
        end
    end
    if bottomRight_color then
        if cIndex > bottomRight_color then
            valueShift = valueShift + ((cIndex - bottomRight_color)*1)
        elseif cIndex == bottomRight_color then
            valueShift = valueShift + 1
        end
    end
    if bottomLeft_color then
        if cIndex < bottomLeft_color then
            valueShift = valueShift + ((cIndex - bottomLeft_color)*1)
        elseif cIndex == bottomLeft_color then
            valueShift = valueShift - 1
        end
    end
    --valueShift = math.floor(valueShift+0.5) --round floats
    if valueShift < -3 then valueShift = -3 end
    if valueShift > 3 then valueShift = 3 end


    --average point calc
    local spotsTable = {}
    for i=1,center do table.insert(spotsTable, {x=0, y=0, z=0}) end
    for i=1,right do table.insert(spotsTable, {x=2, y=0, z=0}) end
    for i=1,left do table.insert(spotsTable, {x=-2, y=0, z=0}) end
    for i=1,topRight do table.insert(spotsTable, {x=1, y=2, z=0}) end
    for i=1,topLeft do table.insert(spotsTable, {x=-1, y=2, z=0}) end
    for i=1,bottomRight do table.insert(spotsTable, {x=1, y=-2, z=0}) end
    for i=1,bottomLeft do table.insert(spotsTable, {x=-1, y=-2, z=0}) end
    local runningX = 0
    local runningY = 0
    local runningZ = 0
    for i,v in ipairs(spotsTable) do
        runningX = runningX + v.x
        runningY = runningY + v.y
        runningZ = runningZ + v.z
    end
    runningX = runningX / #spotsTable
    runningY = runningY / #spotsTable
    runningZ = runningZ / #spotsTable

    local averageCoords = {x=runningX, y=runningY, z=runningZ}

    local totalStacks = center + right + left + topRight + topLeft + bottomRight + bottomLeft -- 37 spots in wide search, 7 overlap
    local shiftStackCountMiddle = totalStacks - 15
    local stackAverageShift = 2
    local stackShifted = 0
    if shiftStackCountMiddle >= 0 then
        stackShifted = MapVar(shiftStackCountMiddle, 0, 22, 0, -stackAverageShift)--just changed this, have to test if widehex still spits the chip 3 spaces away
    else
        stackShifted = MapVar(shiftStackCountMiddle, 0, -15, 0, stackAverageShift)
    end

    local shiftedAverageCoords = {x=averageCoords.x*stackShifted, y=averageCoords.y*stackShifted, z=averageCoords.z*stackShifted}
    shiftedAverageCoords.y = shiftedAverageCoords.y * 2 --shift in favor of y change.
    local relativeStandardCoords = {
                                    x = shiftedAverageCoords.x + 0.5 * shiftedAverageCoords.y,
                                    y = shiftedAverageCoords.y,
                                    z = shiftedAverageCoords.z
                                }


    local relativeOutCoords = {x=relativeStandardCoords.x, y=relativeStandardCoords.y, z=relativeStandardCoords.z}

    relativeOutCoords.x = relativeOutCoords.x + valueShift

    --check how much in center, right, & left. If yes, force a Y change of +-1
    if center >=4 and right >=7 and left >=4 then
        local topCount = topRight + topLeft
        local bottomCount = bottomRight + bottomLeft
        if topCount > bottomCount then
            relativeOutCoords.y = relativeOutCoords.y - 1
        else --topCount <= bottomCount then
            relativeOutCoords.y = relativeOutCoords.y + 1
        end
        if center >=5 or left >=5 then
            relativeOutCoords.y = relativeOutCoords.y * 2
        end
    end

    local roundedOutCoords = {x=0,y=0,z=0}
    roundedOutCoords.x = math.floor(relativeOutCoords.x+0.5)
    roundedOutCoords.y = math.floor(relativeOutCoords.y+0.5)
    roundedOutCoords.z = math.floor(relativeOutCoords.z+0.5)

    if roundedOutCoords.x == 0 and roundedOutCoords.y == 0 and roundedOutCoords.z == 0 then --force a spot change if search returns center 0,0,0
        local divisorN = 1
        if relativeOutCoords.x > relativeOutCoords.y and relativeOutCoords.x > relativeOutCoords.z then
            divisorN = 1 / relativeOutCoords.x
        elseif relativeOutCoords.y > relativeOutCoords.x and relativeOutCoords.y > relativeOutCoords.z then
            divisorN = 1 / relativeOutCoords.y
        else
            divisorN = 1 / relativeOutCoords.z
        end
        if roundedOutCoords.x ~= 0 then roundedOutCoords.x = math.floor((relativeOutCoords.x*divisorN)+0.5) end
        if roundedOutCoords.y ~= 0 then roundedOutCoords.y = math.floor((relativeOutCoords.y*divisorN)+0.5) end
        if roundedOutCoords.z ~= 0 then roundedOutCoords.z = math.floor((relativeOutCoords.z*divisorN)+0.5) end
        if roundedOutCoords.x == 0 and roundedOutCoords.y == 0 and roundedOutCoords.z == 0 then --full force! hopefully never triggers
            DuelPrint('=e FORCED ERROR! Code: 6578')
            roundedOutCoords.x = 1
        end
    end

    local outCoords = {x=hexCoords.x+roundedOutCoords.x, y=hexCoords.y+roundedOutCoords.y, z=hexCoords.z+roundedOutCoords.z}

    if outCoords.x < localPile.limits.minX then outCoords.x = localPile.limits.minX +1 end
    if outCoords.x > localPile.limits.maxX then outCoords.x = localPile.limits.maxX -1 end
    if outCoords.y < localPile.limits.minY then outCoords.y = localPile.limits.minY +1 end
    if outCoords.y > localPile.limits.maxY then outCoords.y = localPile.limits.maxY -1 end
    if outCoords.z < localPile.limits.minZ then outCoords.z = localPile.limits.minZ +1 end
    if outCoords.z > localPile.limits.maxZ then outCoords.z = localPile.limits.maxZ -1 end

    return {{x=outCoords.x, y=outCoords.y, z=outCoords.z}, false}
end

function CountSevenHex(localPile, hexCoords) --check each stack spot nearby, return number of stacks
    local center = CheckStackLayoutCoords(localPile, {x=hexCoords.x, y=hexCoords.y, z=hexCoords.z})
    local onLeft = CheckStackLayoutCoords(localPile, {x=hexCoords.x-1, y=hexCoords.y, z=hexCoords.z})
    local onRight = CheckStackLayoutCoords(localPile, {x=hexCoords.x+1, y=hexCoords.y, z=hexCoords.z})
    local topLeft = CheckStackLayoutCoords(localPile, {x=hexCoords.x, y=hexCoords.y+1, z=hexCoords.z})
    local topRight = CheckStackLayoutCoords(localPile, {x=hexCoords.x+1, y=hexCoords.y+1, z=hexCoords.z})
    local bottomLeft = CheckStackLayoutCoords(localPile, {x=hexCoords.x-1, y=hexCoords.y-1, z=hexCoords.z})
    local bottomRight = CheckStackLayoutCoords(localPile, {x=hexCoords.x, y=hexCoords.y-1, z=hexCoords.z})

    local count = 0
    if center then count = count + 1 end --count how many slots are occupied
    if onLeft then count = count + 1 end
    if onRight then count = count + 1 end
    if topLeft then count = count + 1 end
    if topRight then count = count + 1 end
    if bottomLeft then count = count + 1 end
    if bottomRight then count = count + 1 end

    return count
end

function CheckStackLayoutCoords(localPile, coords) --returns color index of stack if coords are occupied, false if empty
    --DuelPrint('[==g Ran CheckStackLayoutCoords()')
    if not (coords.x >= localPile.limits.minX and
        coords.x <= localPile.limits.maxX and
        coords.y >= localPile.limits.minY and
        coords.y <= localPile.limits.maxY and
        coords.z >= localPile.limits.minZ and
        coords.z <= localPile.limits.maxZ) then
            --DuelPrint('=g coords are not in bounds')
            return 16
    end
    for i,v in ipairs(localPile.stacksInfo) do
        if (v.hexCoords.x == coords.x and
            v.hexCoords.y == coords.y and
            v.hexCoords.z == coords.z) then
                return v.cIndex
        end
    end
    return false
end

function CreateBetStack(betObject)
    --xyz
    local betCategory = betObject.cat
    local betChoice = betObject.bet
    local betValue = betObject.value
    local betID = betObject.id
    local betWorldLocation = {x=0,y=0}
    --DuelPrint('[==w Ran CreateBetStack(); betCategory: '..betCategory..' betChoice: '..betChoice..' betValue: '..betValue..' betID: '..betID)
    if betCategory == "Red/Black" then
        if betChoice == "Red" then
            betWorldLocation = HexToBoardCoords({x=9, y=1.5})
        elseif betChoice == "Black" then
            betWorldLocation = HexToBoardCoords({x=7, y=1.5})
        end
    elseif betCategory == "Straight-Up" then
        local digit1 = string.sub(betChoice, 1, 1)
        local digit2 = string.sub(betChoice, 2, 2)
        local betNum = 0
        if digit2 == " " then
            betNum = betNum + tonumber(digit1)
        else
            betNum = betNum + tonumber(digit1..digit2)
        end
        if betNum ~= 0 then
            local xOffset = math.floor(betNum/3 - 1/3)
            local yOffset = (betNum-1) %3
            betWorldLocation = HexToBoardCoords({x=13.5-xOffset, y=5.5-yOffset})
        else
            betWorldLocation = HexToBoardCoords({x=14.5, y=4.5})
        end
    elseif betCategory == "Odd/Even" then
        if betChoice == "Odd" then
            betWorldLocation = HexToBoardCoords({x=11, y=1.5})
        elseif betChoice == "Even" then
            betWorldLocation = HexToBoardCoords({x=5, y=1.5})
        end
    elseif betCategory == "High/Low" then
        if betChoice == "High" then
            betWorldLocation = HexToBoardCoords({x=13, y=1.5})
        elseif betChoice == "Low" then
            betWorldLocation = HexToBoardCoords({x=3, y=1.5})
        end
    elseif betCategory == "Column" then
        if betChoice == "1st Column" then
            betWorldLocation = HexToBoardCoords({x=1.5, y=5.5})
        elseif betChoice == "2nd Column" then
            betWorldLocation = HexToBoardCoords({x=1.5, y=4.5})
        elseif betChoice == "3rd Column" then
            betWorldLocation = HexToBoardCoords({x=1.5, y=3.5})
        end
    elseif betCategory == "Dozen" then
        if betChoice == "1-12 Dozen" then
            betWorldLocation = HexToBoardCoords({x=12, y=2.5})
        elseif betChoice == "13-24 Dozen" then
            betWorldLocation = HexToBoardCoords({x=8, y=2.5})
        elseif betChoice == "25-36 Dozen" then
            betWorldLocation = HexToBoardCoords({x=4, y=2.5})
        end
    elseif betCategory == "Split" then
        local digit1 = string.sub(betChoice, 1, 1)
        local digit2 = string.sub(betChoice, 2, 2)
        local digit3 = string.sub(betChoice, 3, 3)
        local digit4 = string.sub(betChoice, 4, 4)
        local digit5 = string.sub(betChoice, 5, 5)
        local doubleDigitFirstNumber = false
        if digit3 == "-" then
            doubleDigitFirstNumber = true
        end
        local firstNumber = 0
        local secondNumber = 0
        if doubleDigitFirstNumber == true then
            firstNumber = tonumber(digit1..digit2)
            secondNumber = tonumber(digit4..digit5)
        else
            firstNumber = tonumber(digit1)
            secondNumber = tonumber(digit3..digit4)
        end
        local coords = {x=0, y=0}
        local mod3 = firstNumber % 3
        local row = 0
        local column = 0
        if mod3 == 0 then
            row = firstNumber / 3
            column = 3
        elseif mod3 == 1 then
            row = (firstNumber+2) / 3
            column = 1
        else
            row = (firstNumber+1) / 3
            column = 2
        end
        if secondNumber - firstNumber == 1 then --Row Split
            if mod3 == 1 then
                coords.y = 5
            else
                coords.y = 4
            end
            coords.x = (-row + 13) + 1.5
        else --Column Split
            coords.y = (-column + 4) + 2.5
            coords.x = (-row + 13) + 1
        end
        betWorldLocation = HexToBoardCoords({x=coords.x, y=coords.y})
    elseif betCategory == "Street" then
        local row = 0
        if string.sub(betChoice, 2, 2) == "," then
            row = tonumber(string.sub(betChoice, 5, 5))/3
        else
            row = tonumber(string.sub(betChoice, 7, 8))/3
        end
        betWorldLocation = HexToBoardCoords({x=(-row+13)+1.5, y=3})
    elseif betCategory == "Corner" then
        local firstNumber = 0
        if string.sub(betChoice, 2, 2) == "/" then
            firstNumber = tonumber(string.sub(betChoice, 1, 1))
        else
            firstNumber = tonumber(string.sub(betChoice, 1, 2))
        end
        local mod3 = firstNumber % 3
        local coords = {x=0, y=0}
        local column = 0
        if mod3 == 1 then
            coords.y = 5
            column = (firstNumber+2) / 3
        else
            coords.y = 4
            column = (firstNumber+1) / 3
        end
        coords.x = (-column + 13) + 1.5
        betWorldLocation = HexToBoardCoords({x=coords.x, y=coords.y})
    elseif betCategory == "Line" then
        local firstNumber = 0
        if string.sub(betChoice, 2, 2) == "-" then
            firstNumber = tonumber(string.sub(betChoice, 1, 1))
        else
            firstNumber = tonumber(string.sub(betChoice, 1, 2))
        end
        local row = (firstNumber+3)/3
        betWorldLocation = HexToBoardCoords({x=(-row + 13) + 1, y=3})
    end

    betsPiles[betID] = {
        value=0,
        chipCount=0,
        id = betID,
        singleStacks={0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
        fullStacks={0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
        location = {x=betWorldLocation.x, y=betWorldLocation.y, z=tableBoardOrigin.z},
        rotation = {x=0, y=0, z=0},
        stacksInfo = {}
    }

    ValueToPileQueueSimple(betsPiles[betID], betsPileQueue, betValue)
end

function HexToBoardCoords(hexCoords)
    local boardOriginXw = tableBoardOrigin.x
    local boardOriginYw = tableBoardOrigin.y
    local wGapY = 0.1186428571
    local localYw = boardOriginYw-wGapY*(hexCoords.x-1)
    local wXPartial3 = tableBoardOrigin.x + 0.237
    local localXw = 0
    if hexCoords.y < 3 then --<3
        localXw = boardOriginXw + 0.1185*(hexCoords.y-1)
    else
        localXw = wXPartial3 + 0.2200*(hexCoords.y-3)
    end
    local rotationAngle = (activeTable.tableRotation + 89.7887983)
    local localPositionxy = RotatePoint({x=tableBoardOrigin.x, y=tableBoardOrigin.y}, {x=localXw, y=localYw}, rotationAngle )
    localXw = localPositionxy.x
    localYw = localPositionxy.y
    return {x=localXw, y=localYw}
end

function ProcessSpinResult(resultIndex) --takes resultIndex for roulette_slots (from wheel being spun) and processes bets/winners
    local resultLabel = roulette_slots[resultIndex].label
    local resultColor = roulette_slots[resultIndex].color
    local winnerIDs = {}
    local loserIDs = {}
    local wonValue = 0
    ShowHoloResult(resultLabel, resultColor)

    for i, v in ipairs(currentBets) do
        if v.cat == "Red/Black" then
            if resultColor == v.bet then
                DuelPrint('Winner! Bet on '..v.cat..'; '..v.bet..'! Payout: '..v.value*2)
                wonValue = wonValue + v.value*2
                table.insert(winnerIDs, v.id)
            else
                DuelPrint('Loser! Bet on '..v.cat..'; '..v.bet)
                table.insert(loserIDs, v.id)
            end
        elseif v.cat == "Straight-Up" then
            local bet = v.bet
            local digit1 = string.sub(bet, 1, 1)
            local digit2 = string.sub(bet, 2, 2)
            local betNum = 0
            if digit2 == " " then
                betNum = tonumber(digit1)
            else
                betNum = tonumber(digit1..digit2)
            end
            if resultLabel == betNum then
                DuelPrint('Winner! Bet on '..v.cat..'; '..v.bet..'! Payout: '..v.value*36)
                wonValue = wonValue + v.value*36
                table.insert(winnerIDs, v.id)
            else
                DuelPrint('Loser! Bet on '..v.cat..'; '..v.bet)
                table.insert(loserIDs, v.id)
            end
        elseif v.cat == "Odd/Even" then
            local betOdd = true
            local resultOdd = true
            if resultLabel%2 == 0 then
                resultOdd = false
            end
            if v.bet == "Even" then
                betOdd = false
            end
            if betOdd ~= resultOdd or resultLabel == 0 then
                DuelPrint('Loser! Bet on '..v.cat..'; '..v.bet)
                table.insert(loserIDs, v.id)
            else
                DuelPrint('Winner! Bet on '..v.cat..'; '..v.bet..'! Payout: '..v.value*2)
                wonValue = wonValue + v.value*2
                table.insert(winnerIDs, v.id)
            end
        elseif v.cat == "High/Low" then
            local betHigh = ( resultLabel >= 19 )
            local resultHigh = ( v.bet == "High" )
            if betHigh ~= resultHigh or resultLabel == 0 then
                DuelPrint('Loser! Bet on '..v.cat..'; '..v.bet)
                table.insert(loserIDs, v.id)
            else
                DuelPrint('Winner! Bet on '..v.cat..'; '..v.bet..'! Payout: '..v.value*2)
                wonValue = wonValue + v.value*2
                table.insert(winnerIDs, v.id)
            end
        elseif v.cat == "Column" then
            local mod3 = resultLabel % 3
            local winner = false
            if mod3 == 0 and v.bet == "3rd Column" then
                winner = true
            elseif mod3 == 1 and v.bet == "1st Column" then
                winner = true
            elseif mod3 == 2 and v.bet == "2nd Column" then
                winner = true
            end
            if resultLabel == 0 then
                winner = false
            end
            if winner then
                DuelPrint('Winner! Bet on '..v.cat..'; '..v.bet..'! Payout: '..v.value*3)
                wonValue = wonValue + v.value*3
                table.insert(winnerIDs, v.id)
            else
                DuelPrint('Loser! Bet on '..v.cat..'; '..v.bet)
                table.insert(loserIDs, v.id)
            end
        elseif v.cat == "Dozen" then
            local dozen = math.floor((resultLabel-1) / 12)+1
            local winner = false
            if dozen == 1 and v.bet == "1-12 Dozen" then
                winner = true
            elseif dozen == 2 and v.bet == "13-24 Dozen" then
                winner = true
            elseif dozen == 3 and v.bet == "25-36 Dozen" then
                winner = true
            end
            if resultLabel == 0 then
                winner = false
            end
            if winner then
                DuelPrint('Winner! Bet on '..v.cat..'; '..v.bet..'! Payout: '..v.value*3)
                wonValue = wonValue + v.value*3
                table.insert(winnerIDs, v.id)
            else
                DuelPrint('Loser! Bet on '..v.cat..'; '..v.bet)
                table.insert(loserIDs, v.id)
            end
        elseif v.cat == "Split" then
            local firstNumber = 0
            local secondNumber = 0
            if string.sub(v.bet, 2, 2) == "-" then
                firstNumber = tonumber(string.sub(v.bet, 1, 1))
                secondNumber = tonumber(string.sub(v.bet, 3, 4))
            else
                firstNumber = tonumber(string.sub(v.bet, 1, 2))
                secondNumber = tonumber(string.sub(v.bet, 4, 5))
            end
            if resultLabel == firstNumber or resultLabel == secondNumber then
                DuelPrint('Winner! Bet on '..v.cat..'; '..v.bet..'! Payout: '..v.value*18)
                wonValue = wonValue + v.value*18
                table.insert(winnerIDs, v.id)
            else
                DuelPrint('Loser! Bet on '..v.cat..'; '..v.bet)
                table.insert(loserIDs, v.id)
            end
        elseif v.cat == "Street" then
            local firstNumber = 0
            local secondNumber = 0
            local thirdNumber = 0
            if string.sub(v.bet, 2, 2) == "," then
                firstNumber = tonumber(string.sub(v.bet, 1, 1))
                secondNumber = tonumber(string.sub(v.bet, 3, 3))
                thirdNumber = tonumber(string.sub(v.bet, 5, 5))
            else
                firstNumber = tonumber(string.sub(v.bet, 1, 2))
                secondNumber = tonumber(string.sub(v.bet, 4, 5))
                thirdNumber = tonumber(string.sub(v.bet, 7, 8))
            end
            if resultLabel == firstNumber or resultLabel == secondNumber or resultLabel == thirdNumber then
                DuelPrint('Winner! Bet on '..v.cat..'; '..v.bet..'! Payout: '..v.value*12)
                wonValue = wonValue + v.value*12
                table.insert(winnerIDs, v.id)
            else
                DuelPrint('Loser! Bet on '..v.cat..'; '..v.bet)
                table.insert(loserIDs, v.id)
            end
        elseif v.cat == "Corner" then
            local firstNumber = 0
            local secondNumber = 0
            if string.sub(v.bet, 2, 2) == "/" then
                firstNumber = tonumber(string.sub(v.bet, 1, 1))
                secondNumber = tonumber(string.sub(v.bet, 3, 4))
            else
                firstNumber = tonumber(string.sub(v.bet, 1, 2))
                secondNumber = tonumber(string.sub(v.bet, 4, 5))
            end
            local thirdNumber = firstNumber+1
            local fourthNumber = secondNumber-1
            if resultLabel == firstNumber or resultLabel == secondNumber or resultLabel == thirdNumber or resultLabel == fourthNumber then
                DuelPrint('Winner! Bet on '..v.cat..'; '..v.bet..'! Payout: '..v.value*9)
                wonValue = wonValue + v.value*9
                table.insert(winnerIDs, v.id)
            else
                DuelPrint('Loser! Bet on '..v.cat..'; '..v.bet)
                table.insert(loserIDs, v.id)
            end
        elseif v.cat == "Line" then
            local firstNumber = 0
            local secondNumber = 0
            if string.sub(v.bet, 2, 2) == "-" then
                firstNumber = tonumber(string.sub(v.bet, 1, 1))
                secondNumber = tonumber(string.sub(v.bet, 3, 4))
            else
                firstNumber = tonumber(string.sub(v.bet, 1, 2))
                secondNumber = tonumber(string.sub(v.bet, 4, 5))
            end
            if resultLabel >= firstNumber and resultLabel <= secondNumber then
                DuelPrint('Winner! Bet on '..v.cat..'; '..v.bet..'! Payout: '..v.value*6)
                wonValue = wonValue + v.value*6
                table.insert(winnerIDs, v.id)
            else
                DuelPrint('Loser! Bet on '..v.cat..'; '..v.bet)
                table.insert(loserIDs, v.id)
            end
        else
            DuelPrint('ERROR: Unknown bet category: '..v.cat..' CODE 2640')
        end
    end

    for i, v in ipairs(loserIDs) do
        local callback = function()
            table.insert(betsPilesToRemove, v)
        end
        Cron.After(2, callback)
    end
    local holoEnts = {}
    for i, v in ipairs(winnerIDs) do
        local betsPile = betsPiles[v]
        local entDevName = betsPile.stacksInfo[1].stackDevName
        --get ent location position
        local entity = Game.FindEntityByID(FindEntIdByName(entDevName))
        local pos = entity:GetWorldPosition()
        local holoDevName = entDevName..'_holo'
        table.insert(holoEnts, holoDevName)
        RegisterEntity(holoDevName, chip_stacks, 'default', {x=pos.x,y=pos.y,z=pos.z-0.02})

        local callback = function()
            table.insert(betsPilesToRemove, v)
        end
        Cron.After(4, callback)
    end

    for i,v in ipairs(betsPlacesTaken) do --reset betsPlacesTaken table
        for j,k in ipairs(v) do
            betsPlacesTaken[i][j] = false
        end
    end

    local callback5 = function()
        ChangePlayerChipValue(wonValue)
        if currentBets[1] then
            previousBetsCost = 0
            for i, v in ipairs(currentBets) do
                previousBetsCost = previousBetsCost + v.value
            end
            previousBet = currentBets
            currentBets = {}
            previousBetAvailable = true
        end
        RouletteMainMenu.MainMenuUI()
    end
    Cron.After(5, callback5)
    local callback6 = function()
        for i, v in ipairs(holoEnts) do
            DeRegisterEntity(v)
        end
    end
    Cron.After(6, callback6)
end

function RemoveBetStack()
    if next(betsPilesToRemove) == nil then --exit function if no actions needed.
        return
    end

    local idToRemove = {}
    local indexCount = 0
    for i, v in ipairs(betsPilesToRemove) do
        if v == nil then
            --uhh why is it nil   --its not, below line is
            DuelPrint('=w ERROR! v is nil, index: '..i..' v: '..v..' indexCount: '..indexCount..', error code: 0046')
        end
        local localPile = betsPiles[v]
        if next(localPile.stacksInfo) == nil then --if pile is empty
            betsPiles[v] = nil
            table.insert(idToRemove, v)
            indexCount = indexCount + 1
        else
            local stackCount = 0
            for i, v in ipairs(localPile.stacksInfo) do
                stackCount = stackCount + 1
            end
            local localChips = localPile.stacksInfo[stackCount]
            local entDevName = localChips.stackDevName
            local entColor = localChips.cIndex
            local chipsInEnt = localPile.singleStacks[entColor]
            localPile.singleStacks[entColor] = chipsInEnt - 1
            if localPile.singleStacks[entColor] == 0 then
                DeRegisterEntity(entDevName)
                table.remove(localPile.stacksInfo, stackCount)
            else
                local appearance = (tostring(chipsInEnt - 1)..'_'..chip_colors[entColor])
                local entity = Game.FindEntityByID(FindEntIdByName(entDevName))
                entity:ScheduleAppearanceChange(appearance) --updates entity's appearance
            end
        end
    end
    for i, v in ipairs(idToRemove) do
        local matchIndex = nil
        for j, k in ipairs(betsPilesToRemove) do
            if v == k then
                matchIndex = j
                break
            end
        end
        --local flipIndex = -i+indexCount+1 --nice code to flip index in a loop, I'll use it a lot, likely
        table.remove(betsPilesToRemove, matchIndex)
    end
end

function PlaceBet(betValue,category,bet,addition) --from UI confirmation, add bet to currentBets, subtract from playerPile chips & holo, create single stack pile of chips
    local betCategory = queueUIBet.cat
    local betChoice = queueUIBet.bet
    local localAddition = 0
    if addition ~= nil then
        localAddition = addition
    end
    if category ~= nil then
        betCategory = category
    end
    if bet ~= nil then
        betChoice = bet
    end
    local betID = 'bet_'..(os.time()+localAddition)
    local betObject = {value=betValue,cat=betCategory,bet=betChoice,id=betID}
    table.insert(currentBets, {value=betValue,cat=betCategory,bet=betChoice,id=betID})
    ChangePlayerChipValue(-betValue)
    CreateBetStack(betObject)
    previousBetAvailable = false

    local catIndex = -1
    local betIndex = -1
    for i,v in ipairs(betCategories) do
        if v == betCategory then
            catIndex = i
            break
        end
    end
    for i,v in ipairs(betCategoryIndexes[catIndex]) do
        if v == betChoice then
            betIndex = i
            break
        end
    end
    betsPlacesTaken[catIndex][betIndex] = true
end

function AdvanceSpinner()
    if roulette_spinning_count == 0 then
        roulette_spinning_speed = (math.random() * 1) + 3 --wheel spin randomness, math.random() generates random float between 0 and 1, eg. 0.387643
    end

    roulette_spinning_count = roulette_spinning_count + 1 --increase count, linear, used to tell how many times AdvanceSpinner() has been called / how long the spin has elapsed
    roulette_angle_count = roulette_angle_count + roulette_spinning_speed --advance the wheel by the current speed
    roulette_spinning_speed = roulette_spinning_speed - 0.0025 --decrease wheel speed
    
    roulette_speed_adjusted = -(MapVar(roulette_spinning_speed, 0, 360, 0, math.pi*2))

    roulette_angle = math.fmod(roulette_angle_count, 360) --divide by 360 and get remainder, eg. set 725 degrees to 5 degrees
    if roulette_spinning_speed <= 0 then --end spin when count reaches max
        roulette_spinning = false
        roulette_spinning_count = 0
        roulette_angle_count = 0
        roulette_speed_adjusted = 0
    end
    SetRotateEnt('roulette_spinner', {r=0, p=0, y=roulette_angle})
end

function AdvanceRouletteBall()
    if ball_spinning_count == 0 then
        ball_speed = (math.random() / 10) + 0.3 --math.random() generates random float between 0 and 1, eg. 0.387643 --maybe move into phase 1
        ball_phase = 1
    end

    ball_spinning_count = ball_spinning_count + 1 --increase count, linear

    ballX = ballX + ball_speed --advances the ball by the current speed. increase in ballX = increase over x axis in sin() graph. 6.28/pi*2 = 360 degrees
    ballY = ballY + ball_speed
    local sinX = math.sin(ballX) --convert ballX var through sin() and cos() to get -1 to 1 range
    local cosY = math.cos(ballY)
    local bigX = sinX * ball_distance --multiply sin() and cos() result to spread ball out from center
    local bigY = cosY * ball_distance
    local movedX = bigX + ball_center.x --adjust ball's XY position to CP2077 world coordinates
    local movedY = bigY + ball_center.y

    if ball_phase == 1 then

        if ball_speed > 0 then --slows ball, "friction"
            ball_speed = ball_speed - 0.001
        else
            if ball_speed < 0 then
                ball_speed = ball_speed + 0.001
            end
        end

        if ball_speed < 0.15 then --when the ball has decelerated enough, this sets when the ball falls off the outer wall circle
            LowerBallDistance()
        end

        if (ball_bounces == 0 and ball_distance <= 0.23) then
            ball_bounces = 1 --first bounce, triggers below if statement
            Game.GetPlayer():StopSoundEvent("q303_hotel_casino_roulette_ball_start")
            Game.GetPlayer():PlaySoundEvent("q303_hotel_casino_roulette__ball_stop")
            BounceRandomizer() --pre-load randomness
        end
        if ball_bounces >= 1 then
            BallBounce(max_ball_bounces) --calculate and process bounce, (max) = bounce number limit
        end

    end

    if ball_phase == 2 then

        roulette_spinning_speed = roulette_spinning_speed - 0.010 --decrease wheel speed, helps speed play up once ball is decided.

        ball_speed = roulette_speed_adjusted --always match ball speed to wheel, keeps them in sync.

        local angle_diff = 0    --find ball's angle relative to the wheel
        if ball_angle >= roulette_angle then
            angle_diff = ball_angle - roulette_angle
        else
            angle_diff = ( ball_angle - roulette_angle ) + 360 --corrects for negative angles
        end

        local mapped_angle = MapVar(angle_diff, 0, 360, 0, 37) --maps 360 value to 1-37 for roulette slots
        local roulette_slot_float = mapped_angle - math.floor(mapped_angle)  --grabs decimal places of mapped_angle

        -- settle ball into roulette wheel slot
        --if not ( roulette_slot_float <= 0.001 or roulette_slot_float >= 0.999 ) then
        --end
        if ( roulette_slot_float < 0.5 ) then
            ball_speed = ball_speed - ( 0.001 * (roulette_slot_float * 10) )
        elseif ( roulette_slot_float > 0.5 )then
            ball_speed = ball_speed + 0.001 * ( -10 * roulette_slot_float + 10 )
        end
        LowerBallDistance()

        if not roulette_spinning then
            ball_phase = 3
            local ball_result = math.floor(mapped_angle)
            spin_results = spin_results .. tostring(ball_result) .. ','
            ProcessSpinResult(ball_result+1)
            --DuelPrint('result: '..roulette_slots[ball_result+1].label..' '..roulette_slots[ball_result+1].color)
        end

    end

    if ball_phase == 3 then

        ball_speed = 0
        ball_spinning = false

    end

    -- update ball height to stay on "ground" based on ball_distance
    if ball_distance <= 0.25 then
        ball_height = 0.41 * ball_distance + tableCenterPoint.z -0.02331358
    else
        ball_height = 0.07 * ball_distance + tableCenterPoint.z +0.06268642
    end

    local entity = Game.FindEntityByID(FindEntIdByName('roulette_ball')) --grab entity from entRecords table
    local newPos = Vector4.new(movedX, movedY, ball_height, 0) --set XYZ of latest position
    Game.GetTeleportationFacility():Teleport(entity, newPos, EulerAngles.new(0, 0, 0)) --update ball to latest position

    ball_angle = math.deg(math.atan2( (newPos.y - ball_center.y), (newPos.x - ball_center.x) )) + 180 --calculate ball's angle relative to center in degrees
            --atan2() is depreciated after lua 5.3, CET currently uses 5.1 (2024-04-18),(2025-04-10)

    if not ball_spinning then
        --reset all ball variables for next spin
        ball_spinning_count = 0
        ballX = 0
        ballY = 0
        ball_distance = 0.35
        ball_bounces = 0
        --ball_falling = false
        ball_speed = 0.2
        ball_bounce1 = 0
        ball_spinning_check = 0
    end

end

function BallBounce(max)
    if ( (ball_speed - roulette_spinning_speed) < 1 and (ball_speed - roulette_spinning_speed) > -1 ) then --check if ball speed matches wheel speed
        ball_phase = 2 --end bounces and allow ball to settle
        return
    end
    ball_bounce1 = ball_bounce1 + 1 --tick counter up
    local bounce_height_new = bounce_height + (ball_bounces * 5)
    local bounce_progress = MapVar(ball_bounce1, 0, bounce_randomness, 0, math.pi*2) --convert tick count to a value in the first wave of sin()
    ball_distance = ball_distance + ( math.sin(bounce_progress) / bounce_height_new ) --Add current sin(count) to current distance

    if (ball_distance <= 0.23 and ball_bounce1 >= 10) then --check for collision, >=10 ensures the ball has moved
        if ball_bounces >= max then --check if max number of bounces has been reached
            ball_phase = 2
        else
            --Following code only runs if processing a collision:
            ball_bounces = ball_bounces + 1 --count total bounces
            ball_bounce1 = 0 --reset count for next bounce
            BounceRandomizer()
        end
    end
end

function BounceRandomizer()
    local ball_bounce_speed_max_range = 0.04
    local ball_bounce_speed_top = 0.015
    local ball_bounce_speed_target = roulette_speed_adjusted

    local ball_bounces_sofar = ball_bounces / max_ball_bounces --percentage of how "aggressivly" to sync ball with wheel. higher values (0.98) shoudl equal more sync
    if ball_bounces_sofar == 1 then ball_bounces_sofar = 0.9999 end --prevent divide by 0 after below conversion
    ball_bounces_sofar = ( -ball_bounces_sofar + 1 ) --invert 0 to 1 to go from 1 to 0
    local ball_bounce_speed_used_range = ball_bounce_speed_max_range * ball_bounces_sofar --changes ball_bounce_speed_max_range to a smaller range, smaller as the ball bounce count increases

    local ball_bounce_adjusted_top_speed = MapVar(ball_bounces, 0, max_ball_bounces, roulette_speed_adjusted, ball_bounce_speed_top)

    local ball_bounce_speed_range_top = ball_bounce_adjusted_top_speed
    local ball_bounce_speed_range_bottom = ball_bounce_adjusted_top_speed - ball_bounce_speed_used_range

    local randomized = ( MapVar(math.random(), 0, 1, ball_bounce_speed_range_bottom, ball_bounce_speed_range_top) / ball_bounces ) --randomize ball speed for after contact

    ball_speed = ball_speed + randomized

    bounce_randomness = ( math.random() * 20 ) + ( 20 - (ball_bounces*2) ) --tick length for bounce sin wave to complete 2pi (1 full wave)
end

function LowerBallDistance()
    if ball_distance > 0.2 then --dont flip the < to a > on accident or you'll be debugging why the ball disappears for a few hours             >:(
        ball_distance = ball_distance - ( 0.3*ball_speed^2 - 0.06*ball_speed + 0.0035 ) --math to make the ball fall faster as it gets closer to the center
    elseif ball_distance < 0.2 then
        ball_distance = 0.2 --cap to prevent exponential runaway into spinner wheel and past it
    end
end

function MapVar(var, in_min, in_max, out_min, out_max) --maps a value from one range to another
    return ( (var - in_min) / (in_max - in_min) ) * (out_max - out_min) + out_min
end

function RotatePoint(center, point, angle) --rotates {x,y} point around {x,y} center by angle in degrees counterclockwise. returns {x=x,y=y}
    local rad = angle * math.pi / 180
    local x = center.x + math.cos(rad) * (point.x - center.x) - math.sin(rad) * (point.y - center.y)
    local y = center.y + math.sin(rad) * (point.x - center.x) + math.cos(rad) * (point.y - center.y)
    return {x=x,y=y}
end

function RepeatBets() --for each in previous bets, place bet into current bets
    previousBetAvailable = false
    currentlyRepeatingBets = true
    for i, v in pairs(previousBet) do
        PlaceBet(v.value,v.cat,v.bet,i)
    end
end

function UpdateJoinUI(showUI) --show or hide join UI depending on.. something, idk it changed since I wrote this comment
    if not inRouletteTable  then
        if showUI == true then
            local choice_JoinTable = interactionUI.createChoice(GameLocale.Text("Join Table"), TweakDBInterface.GetChoiceCaptionIconPartRecord("ChoiceCaptionParts.SitIcon"), gameinteractionsChoiceType.QuestImportant)
            local hub_JoinTable = interactionUI.createHub(GameLocale.Text("Roulette"), {choice_JoinTable})
            interactionUI.setupHub(hub_JoinTable)
            interactionUI.showHub()
            interactionUI.callbacks[1] = function()
                interactionUI.hideHub()
                StatusEffectHelper.ApplyStatusEffect(Game.GetPlayer(), "GameplayRestriction.NoMovement") -- Disable player movement
                StatusEffectHelper.ApplyStatusEffect(Game.GetPlayer(), "GameplayRestriction.NoCombat")
                --local playerTransform = Game.GetPlayer():GetWorldTransform()
                --local orientation = playerTransform:GetOrientation()
                local joinLocationxy = RotatePoint({x=tableCenterPoint.x, y=tableCenterPoint.y}, {x=tableCenterPoint.x-0.80787625665175, y=tableCenterPoint.y-1.085349415275}, activeTable.tableRotation)
                Game.GetTeleportationFacility():Teleport(GetPlayer(), Vector4.new(joinLocationxy.x, joinLocationxy.y, tableCenterPoint.z-0.93531358, 1), EulerAngles.new(0, 0, 340+activeTable.tableRotation)) -- Vector4.new(-1034.435, 1340.8057, 5.278, 1)
                
                -- Start holographic display when player joins table
                if holographicDisplayPosition and not holographicDisplayActive then
                    local holoPos = Vector4.new(holographicDisplayPosition.x, holographicDisplayPosition.y, holographicDisplayPosition.z, 1)
                    -- Calculate facing direction quaternion
                    -- Original formula: atan2(holo.y - player.y, holo.x - player.x) * 180/pi - 90
                    -- Module adds 180 degrees internally, so we subtract 180 to compensate
                    local holoDisplayAngle = ((math.atan2(holographicDisplayPosition.y - playerPlayingPosition.y, holographicDisplayPosition.x - playerPlayingPosition.x)) * 180 / math.pi) - 90 - 180
                    local facingQuaternion = EulerAngles.new(0, 0, holoDisplayAngle):ToQuat()
                    HolographicValueDisplay.startDisplay(holoPos, facingQuaternion)
                    holographicDisplayActive = true
                end
                
                RouletteMainMenu.MainMenuUI()
                inRouletteTable = true
            end
        else
            interactionUI.hideHub()
        end
    end
end

-- UI functions moved to RouletteMainMenu.lua

function SpawnWithCodeware(pathOrID, appName, locationTable, orientationTable, tags) --spawns an entity with codeware
    -- original function code by anygoodname
    --todo: update this to codeware's newer static entity system (I probably wont until my next(c) project lol)
    if not Codeware then return end
    local entitySystem = Game.GetDynamicEntitySystem()
    if not entitySystem then return end
    if type(pathOrID) ~= 'string' then return end
    if not IsStringValid(pathOrID) then return end
    local isRecord, isValid = false, false
    if TweakDB:GetRecord(pathOrID) then isRecord = true isValid = true end
    if (not isRecord) and string.match(pathOrID, '%.ent$') then isValid = true end
    if not isValid then return end
    local entSpec = DynamicEntitySpec.new()
    if isRecord then entSpec.recordID = pathOrID else entSpec.templatePath = pathOrID end
    if type(appName) == 'string' then entSpec.appearanceName = appName end
    local playerTransform = Game.GetPlayer():GetWorldTransform()
    local newLocation = {}
    if locationTable then
        newLocation = {x=locationTable.x, y=locationTable.y, z=locationTable.z}
    else
        newLocation = {x=tableCenterPoint.x, y=tableCenterPoint.y, z=tableCenterPoint.z}
    end
    entSpec.position = Vector4.new(newLocation.x, newLocation.y, newLocation.z, 1)
    entSpec.orientation = playerTransform:GetOrientation()
    entSpec.alwaysSpawned = true
    entSpec.spawnInView = true
    entSpec.active = true
    if type(tags) == 'table' then entSpec.tags = tags end
    --DuelPrint('[-- Spawning with Codeware; ent: '..string.sub(pathOrID,31,string.len(pathOrID))..', appearance: '..appName..', x: '..entSpec.position.x..', y: '..entSpec.position.y..', z: '..entSpec.position.z)
    return entitySystem:CreateEntity(entSpec)
end

function Despawn(id) --despawns a codeware entity from id
    --original function code by anygoodname
    if not id then return end
    if Codeware then Game.GetDynamicEntitySystem():DeleteEntity(id) return end
end

--Script Initialized
--==================

--DuelPrint('[log] init.lua loaded, Time: '..tostring(os.time()))
--DuelPrint('-=- Welcome to Roulette by Boe6! -=- Current Unix Time: '..os.time())
return MyMod
