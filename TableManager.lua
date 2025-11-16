TableManager = {
    version = '1.0.0',
    activeTableID = nil,
    dealerEntIDs = {}, -- Track dealer entity IDs per table: dealerEntIDs[tableID] = entID
    dealerSpawned = {} -- Track spawn state per table: dealerSpawned[tableID] = true/false
}
--===================
--CODE BY Boe6
--DO NOT DISTRIBUTE
--DO NOT COPY/REUSE WITHOUT EXPRESS PERMISSION
--DO NOT REUPLOAD TO OTHER SITES
--Feel free to ask via nexus/discord, I just dont want my stuff stolen :)
--===================

local GameLocale = require("External/GameLocale.lua")

---Initializes the TableManager
function TableManager.init()
    -- TODO: Initialize table management system
end

---Loads tables from BlackjackCoordinates and creates spots for each
---@param forcedCameraOption table table containing forced camera option: {[1] = boolean}
function TableManager.LoadTables(forcedCameraOption)
    for tableID, _ in pairs(RelativeCoordinateCalulator.registeredTables) do
        TableManager.createSpotForTable(tableID, forcedCameraOption)
    end
end

---Sets the active table
---@param tableID string tableID to set as active
function TableManager.SetActiveTable(tableID)
    TableManager.activeTableID = tableID
end

---Clears the active table
function TableManager.ClearActiveTable()
    TableManager.activeTableID = nil
end

---Gets the currently active table ID
---@return string|nil active table ID or nil if no table is active
function TableManager.GetActiveTable()
    return TableManager.activeTableID
end

--- Spawns NPC dealer behind the blackjack table.
---@param tableID string table ID to spawn dealer at
function TableManager.spawnDealer(tableID)
    if TableManager.dealerSpawned[tableID] then
        return -- Dealer already spawned for this table
    end
    
    local dealerPosition, dealerOrientation = RelativeCoordinateCalulator.calculateRelativeCoordinate(tableID, 'dealer_spawn_position')
    
    -- Check if coordinate calculation failed (returns nil or invalid position)
    if not dealerPosition or not dealerOrientation then
        DualPrint("Error: Failed to calculate dealer spawn position for table " .. tostring(tableID))
        return
    end
    
    -- Additional safety check: ensure position is not at origin (0,0,0) which likely indicates failure
    if dealerPosition.x == 0 and dealerPosition.y == 0 and dealerPosition.z == 0 then
        DualPrint("Error: Dealer spawn position is at origin (0,0,0) for table " .. tostring(tableID) .. ", aborting spawn")
        return
    end
    
    local dynamicEntitySystem = Game.GetDynamicEntitySystem()
    local spec = DynamicEntitySpec.new()
    spec.recordID = "Character.sts_wat_kab_07_croupiers"
    spec.appearanceName = "Random"
    spec.position = dealerPosition
    spec.orientation = dealerOrientation
    spec.tags = {"Blackjack","dealer"};
    local entID = dynamicEntitySystem:CreateEntity(spec)
    
    TableManager.dealerEntIDs[tableID] = entID
    TableManager.dealerSpawned[tableID] = true
end

--- Despawns the dealer for a specific table
---@param tableID string table ID to despawn dealer for
function TableManager.despawnDealer(tableID)
    if not TableManager.dealerSpawned[tableID] then
        return -- No dealer spawned for this table
    end
    
    local entID = TableManager.dealerEntIDs[tableID]
    if entID ~= nil then
        Game.GetDynamicEntitySystem():DeleteEntity(entID)
        TableManager.dealerEntIDs[tableID] = nil
    end
    TableManager.dealerSpawned[tableID] = false
end

--- Cleans up all dealers across all tables
function TableManager.cleanupAllDealers()
    for tableID, _ in pairs(TableManager.dealerSpawned) do
        TableManager.despawnDealer(tableID)
    end
end

--- Checks if a dealer is spawned for a specific table
---@param tableID string table ID to check
---@return boolean true if dealer is spawned for this table
function TableManager.isDealerSpawned(tableID)
    return TableManager.dealerSpawned[tableID] == true
end

--- Gets the dealer entity ID for a specific table
---@param tableID string table ID
---@return EntityID|nil dealer entity ID or nil if not spawned
function TableManager.getDealerEntID(tableID)
    return TableManager.dealerEntIDs[tableID]
end

--- Creates a spot for a specific table
---@param tableID string table ID to create spot for
---@param forcedCameraOption table table containing forced camera option: {[1] = boolean}
function TableManager.createSpotForTable(tableID, forcedCameraOption)
    local spotID = tableID  -- Capture spot_id in local variable for use in closures
    local spotObj = {
        spot_id = spotID,
        spot_worldPosition = nil,  -- Will be calculated below
        spot_orientation = nil,    -- Will be calculated below
        spot_entWorkspotPath = "boe6\\gamblingsystemblackjack\\sit_workspot.ent",
        spot_useWorkSpot = true,
        spot_showingInteractUI = false,
        animation_defaultName = "sit_chair_table_lean0__2h_on_table__01",
        animation_defaultEnterTime = 2,
        callback_UIwithoutWorkspotTriggered = function()
            --pass
        end,
        callback_OnSpotEnter = function ()
            TableManager.SetActiveTable(spotID)
            -- Note: DualPrint is not available here, would need to be passed or required
            if forcedCameraOption[1] then
                -- Top-down camera enabled - use original position
                local adjustedPosition, adjustedOrientation = RelativeCoordinateCalulator.calculateRelativeCoordinate(spotID, 'top_down_holo_display')
                HolographicValueDisplay.startDisplay(adjustedPosition, adjustedOrientation)
            else
                -- Top-down camera disabled - use adjusted position
                local adjustedPosition, adjustedOrientation = RelativeCoordinateCalulator.calculateRelativeCoordinate(spotID, 'standard_holo_display')
                HolographicValueDisplay.startDisplay(adjustedPosition, adjustedOrientation)
            end
            local deckPosition, deckOrientation = RelativeCoordinateCalulator.calculateRelativeCoordinate(spotID, 'deck_position')
            CardEngine.BuildVisualDeck(deckPosition, deckOrientation)
        end,
        callback_OnSpotEnterAfterAnimationDelayTime = 3.5,        callback_OnSpotEnterAfterAnimation = function ()
            BlackjackMainMenu.playerChipsMoney = 0        --Reset vars b4 game, safe check
            BlackjackMainMenu.playerChipsHalfDollar = false
            BlackjackMainMenu.previousBet = nil
            BlackjackMainMenu.currentBet = nil
            BlackjackMainMenu.StartMainMenu()
        end,
        callback_OnSpotExitAfterAnimationDelayTime = 2.5, --found via trial and error. Aproximate time to finish animation.
        callback_OnSpotExit = function()
            TableManager.ClearActiveTable()
            -- Note: DualPrint is not available here, would need to be passed or required
            HolographicValueDisplay.stopDisplay()
            -- Clean up game state on mid-game exit
            SingleRoundLogic.cleanupRound()
        end,
        callback_OnSpotExitAfterAnimation = function()
            CardEngine.RemoveVisualDeck()
            -- Clear entity cache when exiting table to prevent stale entries
            CardEngine.clearEntityCache()
        end,
        exit_orientationCorrection = {r=0,p=0,y=150},-- I *think* this corrects for the 180 turn that the exit animation causes.
        exit_worldPositionOffset = {x=0.5,y=0,z=0},
        exit_animationName = "sit_chair_table_lean0__2h_on_table__01__to__stand__2h_on_sides__01__turn0l__01",
        mappin_worldPosition = nil,  -- Will be calculated below
        mappin_interactionRange = 1.4,
        mappin_interactionAngle = 80,
        mappin_rangeMax = 6.5,
        mappin_rangeMin = 0.5,
        mappin_color = nil,
        mappin_worldIcon = "ChoiceIcons.SitIcon",
        mappin_hubText = GameLocale.Text("Blackjack"),
        mappin_choiceText = GameLocale.Text("Join Table"),
        mappin_choiceIcon = "ChoiceCaptionParts.SitIcon",
        mappin_choiceFont = gameinteractionsChoiceType.QuestImportant,
        mappin_gameMappinID = nil,
        mappin_visible = false,
        mappin_variant = gamedataMappinVariant.SitVariant,
        camera_worldPositionOffset = nil,  -- Will be calculated below
        camera_OrientationOffset = EulerAngles.new(0, -60, 0),
        camera_showElectroshockEffect = true,
        camera_useForcedCamInWorkspot = forcedCameraOption[1]
    }
    -- Calculate all positions using relative coordinate system
    local spotPosition, spotOrientation = RelativeCoordinateCalulator.calculateRelativeCoordinate(spotID, 'spot_position')
    spotObj.spot_worldPosition = spotPosition
    spotObj.spot_orientation = spotOrientation:ToEulerAngles()
    
    local mappinPosition, _ = RelativeCoordinateCalulator.calculateRelativeCoordinate(spotID, 'mappin_position')
    spotObj.mappin_worldPosition = mappinPosition
    
    -- Calculate camera offset relative to spot position
    local cameraOffset = RelativeCoordinateCalulator.registeredOffsets['camera_position_offset']
    local cameraOffsetVector = Vector4.new(cameraOffset.position.x, cameraOffset.position.y, cameraOffset.position.z, 0)
    local cameraWorldPosition, _ = RelativeCoordinateCalulator.calculateFromPosition(spotPosition, spotOrientation, cameraOffsetVector)
    spotObj.camera_worldPositionOffset = Vector4.new(
        cameraWorldPosition.x - spotPosition.x,
        cameraWorldPosition.y - spotPosition.y,
        cameraWorldPosition.z - spotPosition.z,
        1
    )
    
    SpotManager.AddSpot(spotObj)
end

return TableManager