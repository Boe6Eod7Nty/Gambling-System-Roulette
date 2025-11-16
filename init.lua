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
local ChipUtils = require("chipUtils.lua")
local ChipBetPiles = require("chipBetPiles.lua")
local ChipPlayerPile = require("chipPlayerPile.lua")
local RouletteAnimations = require("RouletteAnimations.lua")


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

-- Animation variables moved to RouletteAnimations.lua module
-- Access via: RouletteAnimations.roulette_spinning, RouletteAnimations.ball_spinning

--chip stacks global variables (now managed by ChipPlayerPile and ChipBetPiles modules)

-- Game Status Variables
local tableChips = 0 --amount of player money on the table. This needs to be saved between sessions somehow, otherwise loading a save mid-game will delete players money ¯\_(ツ)_/¯
local bettingStyle = 'basic' -- Betting styles = basic, simple, standard, advanced. Also should be saved between sessions somehow
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
    if RouletteAnimations.ball_spinning then RouletteAnimations.AdvanceRouletteBall() end --check if roulette ball should be spinning
    if RouletteAnimations.roulette_spinning then RouletteAnimations.AdvanceSpinner() end --check if roulette wheel should be spinning
    gameLoadDelayCount = gameLoadDelayCount + 1


    if showingHoloResult then
        MoveEnt('holo_result_firstDigit', {x=0, y=0, z=0.001}, {r=0, p=0, y=holoDisplayAngle})
        MoveEnt('holo_result_colorWord', {x=0, y=0, z=0.001}, {r=0, p=0, y=holoDisplayAngle})
        if doubleDigitHoloResult then
            MoveEnt('holo_result_secondDigit', {x=0, y=0, z=0.001}, {r=0, p=0, y=holoDisplayAngle})
        end
    end

    if (cronCount % 4 == 0) then --10x per second
        ChipPlayerPile.QueuedChipAddition()
        ChipPlayerPile.QueuedChipSubtraction()
        currentlyRepeatingBets = ChipBetPiles.QueuedBetChipAddition(currentlyRepeatingBets)
        ChipBetPiles.RemoveBetStack()
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
    
    -- Initialize chip modules
    ChipUtils.Initialize({
        Cron = Cron,
        activeTable = activeTable,
        tableBoardOrigin = tableBoardOrigin,
        chipRotation = chipRotation,
        chipHeight = chipHeight,
        chip_values = chip_values,
        chip_colors = chip_colors,
        RegisterEntity = RegisterEntity,
        DeRegisterEntity = DeRegisterEntity,
        FindEntIdByName = FindEntIdByName,
        SetRotateEnt = SetRotateEnt,
        MapVar = MapVar,
        DuelPrint = DuelPrint
    })
    
    ChipBetPiles.Initialize({
        ChipUtils = ChipUtils,
        Cron = Cron,
        chip_colors = chip_colors,
        chipHeight = chipHeight,
        tableBoardOrigin = tableBoardOrigin,
        RegisterEntity = RegisterEntity,
        DeRegisterEntity = DeRegisterEntity,
        FindEntIdByName = FindEntIdByName,
        SetRotateEnt = SetRotateEnt,
        DuelPrint = DuelPrint,
        RouletteMainMenu = RouletteMainMenu,
        poker_chip = poker_chip
    })
    
    ChipPlayerPile.Initialize({
        ChipUtils = ChipUtils,
        Cron = Cron,
        chip_colors = chip_colors,
        chipHeight = chipHeight,
        activeTable = activeTable,
        chipRotation = chipRotation,
        RegisterEntity = RegisterEntity,
        DeRegisterEntity = DeRegisterEntity,
        FindEntIdByName = FindEntIdByName,
        SetRotateEnt = SetRotateEnt,
        DuelPrint = DuelPrint,
        poker_chip = poker_chip
    })
    
    -- Initialize RouletteAnimations module
    -- Note: spin_results is updated via a callback function
    -- tableCenterPoint will be updated via UpdateBallCenter() when InitTable() is called
    RouletteAnimations.Initialize({
        SetRotateEnt = SetRotateEnt,
        FindEntIdByName = FindEntIdByName,
        ProcessSpinResult = ProcessSpinResult,
        GetPlayer = GetPlayer,
        DuelPrint = DuelPrint,
        UpdateSpinResults = function(result)
            spin_results = spin_results .. result .. ','
        end
    })

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
            local playerPile = ChipPlayerPile.GetPlayerPile()
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
                ChipPlayerPile.ChangePlayerChipValue(inputValue)
                Game.AddToInventory("Items.money", -(inputValue) )
                Game.GetPlayer():PlaySoundEvent("q303_06a_roulette_chips_stack")
                RouletteMainMenu.MainMenuUI()
            end
        elseif showCustomBetChips then
            showCustomBetChips = false
            local playerPile = ChipPlayerPile.GetPlayerPile()
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
    ChipPlayerPile.Clear()
end)
registerHotkey('DevHotkey4', 'Dev Hotkey 4', function()
    DuelPrint('||=4  Dev hotkey 4 Pressed =')

    ChipPlayerPile.DebugPlayerPile()
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
    RouletteAnimations.UpdateBallCenter(tableCenterPoint)

    RegisterEntity('roulette_spinner', roulette_spinner, 'default')
    RegisterEntity('roulette_ball', roulette_ball, 'default')
    if table.presetTable then
        RegisterEntity('roulette_spinner_frame', roulette_spinner_frame, 'default')
    end

    local pilexy = RotatePoint({x=table.SpinnerCenterPoint.x, y=table.SpinnerCenterPoint.y}, {x=table.SpinnerCenterPoint.x -0.3892143661, y=table.SpinnerCenterPoint.y -0.5538890579}, table.tableRotation)
    local playerPile = ChipPlayerPile.GetPlayerPile()
    playerPile.location = {x=pilexy.x, y=pilexy.y, z=table.SpinnerCenterPoint.z + 0.09668642}


    local playerPositionxy = RotatePoint({x=table.SpinnerCenterPoint.x, y=table.SpinnerCenterPoint.y}, {x=table.SpinnerCenterPoint.x -0.80787625665175, y=table.SpinnerCenterPoint.y -1.085349415275}, table.tableRotation)
    playerPlayingPosition = {x=playerPositionxy.x, y=playerPositionxy.y, z=table.SpinnerCenterPoint.z -0.93531358}

    -- Holographic display position (same location as old chip_stacks stand, HolographicValueDisplay will spawn its own stand)
    local holoPositionxy = RotatePoint({x=table.SpinnerCenterPoint.x, y=table.SpinnerCenterPoint.y}, {x=table.SpinnerCenterPoint.x +0.17977070965503, y=table.SpinnerCenterPoint.y -0.55898646070364}, table.tableRotation)
    holographicDisplayPosition = {x=holoPositionxy.x, y=holoPositionxy.y, z=table.SpinnerCenterPoint.z+0.08668642}

    holoDisplayAngle = ( ( math.atan2(tableCenterPoint.y - playerPlayingPosition.y, tableCenterPoint.x - tableCenterPoint.x) ) * 180 / math.pi ) + 225
    holoDisplayAngleRad = holoDisplayAngle * math.pi / 180

    local boardOriginxy = RotatePoint({x=tableCenterPoint.x, y=tableCenterPoint.y}, {x=tableCenterPoint.x -2.182648465571, y=tableCenterPoint.y -0.44227742051612}, table.tableRotation)
    -- Update tableBoardOrigin fields directly so ChipUtils reference stays valid
    tableBoardOrigin.x = boardOriginxy.x
    tableBoardOrigin.y = boardOriginxy.y
    tableBoardOrigin.z = tableCenterPoint.z +0.09668642
    
    -- Also update ChipUtils with the new values
    ChipUtils.UpdateTableBoardOrigin(tableBoardOrigin)


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

    local betsPiles = ChipBetPiles.GetBetsPiles()
    for i, v in ipairs(currentBets) do
        local localPile = betsPiles[v.id]
        if localPile then
            for j, k in ipairs(localPile.stacksInfo) do
                DeRegisterEntity(k.stackDevName)
            end
        end
    end

    StatusEffectHelper.RemoveStatusEffect(GetPlayer(), "GameplayRestriction.NoMovement") -- Enable player movement
    StatusEffectHelper.RemoveStatusEffect(GetPlayer(), "GameplayRestriction.NoCombat") -- Enable weapon draw
    interactionUI.hideHub()

    local callbackResetVariables = function() --force reset almost every variable. save/load bugs are a PITA.
        areaInitialized = false
        gameLoadDelayCount = 0
        ChipPlayerPile.Clear()
        ChipBetPiles.Clear()
        previousBetAvailable = false
        inRouletteTable = false
        RouletteAnimations.Reset()
        gameLoadDelayCount = 0
        cronCount = 0
        currentBets = {}
        previousBet = {}
        previousBetsCost = 0
        currentlyRepeatingBets = false
        -- Animation variables are now managed by RouletteAnimations.Reset()
        -- searchStepCount, stackSearchCurrent, stackSearchPrevious, stackSearchOld are now managed by ChipPlayerPile
        -- pileQueue and pileSubtractionQueue are now managed by ChipPlayerPile.Clear()
        tableChips = 0
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

-- ValueToPileQueueSimple moved to ChipUtils
-- ValueToQueueSubtraction moved to ChipUtils
-- QueuedChipSubtraction moved to ChipPlayerPile
-- QueuedBetChipAddition moved to ChipBetPiles
-- QueuedChipAddition moved to ChipPlayerPile
-- FindAndSpawnStack moved to ChipUtils
-- FindNextStackLayoutLocation moved to ChipUtils
-- StackLocationSearchStep moved to ChipUtils
-- CheckEmptyAndShift moved to ChipUtils
-- SearchStuckExit moved to ChipUtils
-- AveragePileLocationFloat moved to ChipUtils
-- MediumSearchAggressive moved to ChipUtils
-- WideHexSearch moved to ChipUtils
-- CountSevenHex moved to ChipUtils
-- CheckStackLayoutCoords moved to ChipUtils
-- CreateBetStack moved to ChipBetPiles
-- HexToBoardCoords moved to ChipUtils
-- RemoveBetStack moved to ChipBetPiles

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

    local betsPilesToRemove = ChipBetPiles.GetBetsPilesToRemove()
    for i, v in ipairs(loserIDs) do
        local callback = function()
            table.insert(betsPilesToRemove, v)
        end
        Cron.After(2, callback)
    end
    local holoEnts = {}
    local betsPiles = ChipBetPiles.GetBetsPiles()
    for i, v in ipairs(winnerIDs) do
        local betsPile = betsPiles[v]
        if betsPile and betsPile.stacksInfo and betsPile.stacksInfo[1] then
            local entDevName = betsPile.stacksInfo[1].stackDevName
            --get ent location position
            local entity = Game.FindEntityByID(FindEntIdByName(entDevName))
            if entity then
                local pos = entity:GetWorldPosition()
                local holoDevName = entDevName..'_holo'
                table.insert(holoEnts, holoDevName)
                RegisterEntity(holoDevName, chip_stacks, 'default', {x=pos.x,y=pos.y,z=pos.z-0.02})
            else
                DuelPrint('[==e ERROR: Could not find entity '..entDevName..' for winner bet '..v)
            end
        else
            DuelPrint('[==e ERROR: betsPile or stacksInfo missing for winner bet '..v)
        end

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
        ChipPlayerPile.ChangePlayerChipValue(wonValue)
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
    ChipPlayerPile.ChangePlayerChipValue(-betValue)
    ChipBetPiles.CreateBetStack(betObject)
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

-- Animation functions moved to RouletteAnimations.lua module
-- Functions: AdvanceSpinner, AdvanceRouletteBall, BallBounce, BounceRandomizer, LowerBallDistance

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
