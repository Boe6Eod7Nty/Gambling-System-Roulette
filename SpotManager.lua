SpotManager = {
    version = '1.1.8',
    spots = {},
    activeCam = nil,
    forcedCam = false
}
--===================
--CODE BY Boe6
--DO NOT DISTRIBUTE
--DO NOT COPY/REUSE WITHOUT EXPRESS PERMISSION
--DO NOT REUPLOAD TO OTHER SITES
--Feel free to ask via nexus/discord, I just dont want my stuff stolen :)
--===================

--local BlackjackMainMenu = require("BlackjackMainMenu.lua")
local Cron = require('External/Cron.lua')
local GameUI = require("External/GameUI.lua")
local interactionUI = require("External/interactionUI.lua")-- by keanuwheeze

local inMenu = true --libaries requirement
local inGame = false

--Functions
--=========
--- Display Basic UI interaction prompt
---@param hubText string "hub" text, left side
---@param choiceText string option text, right side
---@param icon string UI icon tweak record
---@param choiceType string gameinteractionsChoiceType
---@param callback function callback when UI is selected
---@param reShowHub? boolean/string Optional hide hub after selection
local function basicInteractionUIPrompt(spotTable) --Display interactionUI menu
    
    --setup UI
    local callback = function()
        if spotTable.spotObject.spot_useWorkSpot then --if using workspot or only UI prompt
            TriggeredSpot(spotTable.spotObject)
        else
            spotTable.spotObject.callback_UIwithoutWorkspotTriggered()
        end
    end
    local choiceText = (type(spotTable.spotObject.mappin_choiceText) == 'function') and spotTable.spotObject.mappin_choiceText() or spotTable.spotObject.mappin_choiceText
    local reShowHub = spotTable.spotObject.mappin_reShowHub
    local choice = interactionUI.createChoice(choiceText, TweakDBInterface.GetChoiceCaptionIconPartRecord(spotTable.spotObject.mappin_choiceIcon), spotTable.spotObject.mappin_choiceFont)
    local hub = interactionUI.createHub(spotTable.spotObject.mappin_hubText, {choice})
    --show UI
    interactionUI.setupHub(hub)
    interactionUI.showHub()
    interactionUI.callbacks[1] = function()
        if reShowHub == 'hide' or reShowHub == nil or not reShowHub then
            interactionUI.hideHub()
        elseif reShowHub or reShowHub == 'instantReshow' then
            interactionUI.hideHub()
            basicInteractionUIPrompt(spotTable)
        elseif reShowHub == 'keep' then
            --pass
        end
        callback()
    end
end
--- Animate player entering spot
---@param spotObject table spots information object
local function animateEnteringSpot(spotObject) --Triggers workspot animation
    local player = Game.GetPlayer()
    local dynamicEntitySystem = Game.GetDynamicEntitySystem()
    local workspotSystem = Game.GetWorkspotSystem()
    local spec = DynamicEntitySpec.new()
    spec.templatePath = spotObject.spot_entWorkspotPath
    spec.position = spotObject.spot_worldPosition
    spec.orientation = spotObject.spot_orientation:ToQuat()
    spec.tags = {"SpotManager"}
    -- Spawn entity
    local entID = dynamicEntitySystem:CreateEntity(spec)
    spotObject.entID = entID

    Cron.After(1, function()
        local entity = Game.FindEntityByID(entID)
        workspotSystem:PlayInDevice(entity, player) --Play workspot
    end)
end

---Move player camera to forced position, typically above table
---@param enable boolean to enable, or disable the forced camera perspective
---@param spotObject? table spot's animation object
local function setForcedCamera(enable, spotObject)
    SpotManager.forcedCam = enable
    if enable then
        local camera = GetPlayer():GetFPPCameraComponent()
        local quatOri = spotObject.camera_OrientationOffset:ToQuat()
        if ImmersiveFirstPersonInstalled then
            --camera:SetLocalTransform(Vector4.new(0, 0.4, 0.9, 1), quatOri) --alt position for immersiveFirstPerson camera
            --GetMod("ImmersiveFirstPerson").api.Disable()
            StatusEffectHelper.ApplyStatusEffect(GetPlayer(), "GameplayRestriction.NoCameraControl")
        end
        camera:SetLocalTransform(spotObject.camera_worldPositionOffset, quatOri) --default settings
    else
        --reset to normal camera control
        local camera = GetPlayer():GetFPPCameraComponent()
        camera:SetLocalPosition(Vector4.new(0, 0, 0, 1))
        camera:SetLocalOrientation(EulerAngles.new(0, 0, 0):ToQuat())
        StatusEffectHelper.RemoveStatusEffect(GetPlayer(), "GameplayRestriction.NoCameraControl")
        --[[
        if ImmersiveFirstPersonInstalled then
            --GetMod("ImmersiveFirstPerson").api.Enable()
        end
        ]]--
    end
end

--- Modify existing spot data
---@param spotID string spotID unique; example 'hooh'
---@param changesObject table same as spotObject structure. only include values to change.
local function modifySpot(spotObject, changesObject)
    for k,v in pairs(changesObject) do
        spotObject[k] = v
    end
end

---Triggered on interactionUI choice to enter workspot
---@param spotObject table spots information object
function TriggeredSpot(spotObject)
    animateEnteringSpot(spotObject)
    spotObject.callback_OnSpotEnter()
    if ImmersiveFirstPersonInstalled then
        --disables camera control. User movement input + Immersive First Person causes visual bug
        StatusEffectHelper.ApplyStatusEffect(GetPlayer(), "GameplayRestriction.NoCameraControl")
        --GetMod("ImmersiveFirstPerson").api.Disable()
    end
    local enterCallback = function()
        StatusEffectHelper.ApplyStatusEffect(GetPlayer(), "BaseStatusEffect.FatalElectrocutedParticleStatus")
        SpotManager.activeCam = spotObject.spot_id
        setForcedCamera(true, spotObject)
    end
    Cron.After(spotObject.animation_defaultEnterTime, enterCallback)
    Cron.After(spotObject.callback_OnSpotEnterAfterAnimationDelayTime, spotObject.callback_OnSpotEnterAfterAnimation)
end

--Register Events (passed from parent)
--===============
function SpotManager.init() --runs on game launch

    Observe('RadialWheelController', 'OnIsInMenuChanged', function(_, isInMenu) -- Setup observer and GameUI to detect inGame / inMenu, credit: keanuwheeze | init.lua from the sitAnywhere mod
        inMenu = isInMenu
    end)

    ObserveAfter("BaseMappinBaseController", "UpdateRootState", function(this) -- Custom mappin texture
        local mappin = this:GetMappin()
        if not mappin then
            return
        end
        local worldPosition = mappin:GetWorldPosition()
        for i, spotTable in pairs(SpotManager.spots) do
            if Vector4.Distance(worldPosition, spotTable.spotObject.mappin_worldPosition) < 0.05 and spotTable.spotObject.spot_showingInteractUI then
                local record = TweakDBInterface.GetUIIconRecord(spotTable.spotObject.mappin_worldIcon)
                this.iconWidget:SetAtlasResource(record:AtlasResourcePath())
                this.iconWidget:SetTexturePart(record:AtlasPartName())
                this.iconWidget:SetTintColor(spotTable.spotObject.mappin_color or HDRColor.new({ Red = 0.15829999744892, Green = 1.3033000230789, Blue = 1.4141999483109, Alpha = 1.0 }))
            end
        end
    end)

    inGame = false          --Setup observer and GameUI to detect inGame / inMenu
    GameUI.OnSessionStart(function() --  credit: keanuwheeze | init.lua from the sitAnywhere mod
        inGame = true

        for i, spotTable in pairs(SpotManager.spots) do
            spotTable.spotObject.spot_showingInteractUI = false
            spotTable.spotObject.mappin_visible = false
            spotTable.spotObject.mappin_gameMappinID = nil
        end
    end)
    GameUI.OnSessionEnd(function()
        inGame = false
    end)
    inGame = not GameUI.IsDetached() -- Required to check if ingame after reloading all mods

end
function SpotManager.update(dt) --runs every frame
    if  not inMenu and inGame then
        Cron.Update(dt) -- This is required for Cron to function
    end
    if SpotManager.forcedCam and SpotManager.activeCam ~= nil then --fixes the camera being reset by workspot animation
        local camera = GetPlayer():GetFPPCameraComponent()
        local o = camera:GetLocalOrientation():ToEulerAngles()
        local spot = SpotManager.spots[SpotManager.activeCam]
        local camRotation = spot.spotObject.camera_OrientationOffset
        local isInPitch = (o.pitch < camRotation.pitch+0.0001 and o.pitch > camRotation.pitch-0.0001)
        local isInYaw = (o.yaw < camRotation.yaw+0.0001 and o.yaw > camRotation.yaw-0.0001)
        if (not isInPitch) or (not isInYaw) then
            setForcedCamera(true, spot.spotObject)
        end
    else
        StatusEffectHelper.RemoveStatusEffect(GetPlayer(), "GameplayRestriction.NoCameraControl") --insurance
        --[[
        if ImmersiveFirstPersonInstalled then
            --GetMod("ImmersiveFirstPerson").api.Enable()
        end
        ]]--
    end

    for i, spotTable in pairs(SpotManager.spots) do --mappin updating and UI interaction. credit to keanuwheeze for working code references
        local shouldShowUI = true
        local shouldShowIcon = true
        local player = GetPlayer()
        local position = player:GetWorldPosition()
        local forwardVector = player:GetWorldForward()
        local mapping_pos = spotTable.spotObject.mappin_worldPosition
        -- check interaction range
        if not ( Vector4.Distance(position, mapping_pos) < spotTable.spotObject.mappin_interactionRange ) then
            shouldShowUI = false
        end
        -- check interaction angle
        local vector4difference = Vector4.new(position.x - mapping_pos.x, position.y - mapping_pos.y, position.z - mapping_pos.z, 0)
        local angleBetween = Vector4.GetAngleBetween(forwardVector, vector4difference)
        if not ( 180 - angleBetween < spotTable.spotObject.mappin_interactionAngle ) then
            shouldShowUI = false
        end
        -- check looking pitch_angle, if looking too far up or down
        local pitch = Game.GetCameraSystem():GetActiveCameraData().rotation:ToEulerAngles().pitch
        local min, max = -75, -10
        if not (min < pitch and pitch < max) then
            shouldShowUI = false
        end
        if Vector4.Distance(position, mapping_pos) > spotTable.spotObject.mappin_rangeMax then
            shouldShowIcon = false
        end
        if Vector4.Distance(position, mapping_pos) < spotTable.spotObject.mappin_rangeMin then
            shouldShowIcon = false
        end

        if shouldShowUI ~= spotTable.spotObject.spot_showingInteractUI then --show or hide the "join" dialog UI
            if shouldShowUI then
                -- currently off, turning on UI
                spotTable.spotObject.spot_showingInteractUI = true
                basicInteractionUIPrompt(spotTable)

                --TODO: below maybe not needed, sit anywhere doesnt use it.
                local blackboardDefs = Game.GetAllBlackboardDefs();
                local blackboardPSM = Game.GetBlackboardSystem():GetLocalInstanced(GetPlayer():GetEntityID(), blackboardDefs.PlayerStateMachine);
                blackboardPSM:SetInt(blackboardDefs.PlayerStateMachine.SceneTier, 1, true);
            else
                -- currently on, hide UI.
                spotTable.spotObject.spot_showingInteractUI = false
                interactionUI.hideHub()
            end
        end

        local shouldShowMappinSetting = true --set visibility setting in case not declared
        if spotTable.spotObject.mappin_showWorldMappinIcon == false then
            shouldShowMappinSetting = false
        end
        if shouldShowIcon ~= spotTable.spotObject.mappin_visible then --shows or hides the mappin
            if shouldShowIcon and shouldShowMappinSetting then
                spotTable.spotObject.mappin_visible = true
                if spotTable.spotObject.mappin_gameMappinID == nil then
                    local mappinVariant = gamedataMappinVariant.SitVariant
                    if spotTable.spotObject.mappin_variant ~= nil then
                        mappinVariant = spotTable.spotObject.mappin_variant
                    end
                    local mappin_data = MappinData.new({ mappinType = 'Mappins.DefaultStaticMappin', variant = mappinVariant, visibleThroughWalls = spotTable.spotObject.mappin_visibleThroughWalls })
                    spotTable.spotObject.mappin_gameMappinID = Game.GetMappinSystem():RegisterMappin(mappin_data, spotTable.spotObject.mappin_worldPosition)
                else
                    --DualPrint('SM | Extra mappin left in memory: '..tostring(spotTable.spotObject.mappin_gameMappinID)..', Error #8833')
                end
            else
                spotTable.spotObject.mappin_visible = false
                if spotTable.spotObject.mappin_gameMappinID ~= nil then
                    Game.GetMappinSystem():UnregisterMappin(spotTable.spotObject.mappin_gameMappinID)
                    spotTable.spotObject.mappin_gameMappinID = nil
                end
            end
        end
    end
end

--Methods
--=======
--- Animate player leaving spot
--- @param id any identification id
function SpotManager.ExitSpot(id) --Exit spot
    setForcedCamera(false) --disable forced camera perspective
    SpotManager.activeCam = nil
    local spot = SpotManager.spots[id]
    SpotManager.ChangeAnimation(spot.spotObject.exit_animationName, spot.spotObject.callback_OnSpotExitAfterAnimationDelayTime + 3, spot.spotObject.animation_defaultName)

    spot.spotObject.callback_OnSpotExit()
    Cron.After(spot.spotObject.callback_OnSpotExitAfterAnimationDelayTime, function() -- Wait for animation to finish
        local player = GetPlayer()
        local playerTransform = player:GetWorldTransform()
        local position = playerTransform:GetWorldPosition()
        local teleportPosition = Vector4.new(
            position:GetX() + spot.spotObject.exit_worldPositionOffset.x,
            position:GetY() + spot.spotObject.exit_worldPositionOffset.y,
            position:GetZ() + spot.spotObject.exit_worldPositionOffset.z,1)
        local baseOri = spot.spotObject.spot_orientation
        local offOri = spot.spotObject.exit_orientationCorrection
        local localEuler = EulerAngles.new( baseOri.roll+offOri.r, baseOri.pitch+offOri.p, baseOri.yaw+offOri.y )
        Game.GetTeleportationFacility():Teleport(player, teleportPosition, localEuler)--150 hardcoded..?
        Game.GetWorkspotSystem():SendFastExitSignal(player)

        spot.spotObject.callback_OnSpotExitAfterAnimation()
    end)
end

--- Add spot to SpotManager's managed list of spots
---@param spotObject table spot information object
function SpotManager.AddSpot(spotObject) --Create spot
    SpotManager.spots[spotObject.spot_id] = {spotObject = spotObject}
end

--- Change Animation for set time, then return to 'default' animation position
---@param animName string Animation to trigger
---@param duration number Duration of animation
---@param returnAnimName string Animation to reset to as default
function SpotManager.ChangeAnimation(animName, duration, returnAnimName)
    local player = Game.GetPlayer()
    local workspotSystem = Game.GetWorkspotSystem()
    workspotSystem:SendJumpToAnimEnt(player, animName, true)
    Cron.After(duration, function()
        workspotSystem:SendJumpToAnimEnt(player, returnAnimName, true)
    end)
end

--- Change 1 or all spot's values
---@param isAllSpots boolean 
---@param changesObject table same as spotObject structure. only include values to change.
---@param spotID? string Optional if not isAllSpots, required to provide a single spotID
function SpotManager.changeSpotData(isAllSpots, changesObject, spotID)
    if isAllSpots then
        for _, spotTable in pairs(SpotManager.spots) do
            modifySpot(spotTable.spotObject, changesObject)
        end
    else
        modifySpot(SpotManager.spots[spotID].spotObject, changesObject)
    end
end


return SpotManager