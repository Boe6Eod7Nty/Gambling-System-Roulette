RelativeCoordinateCalulator = {
    version = '1.0.0',
    registeredTables = {},
    registeredOffsets = {},
}
--===================
--CODE BY Boe6
--DO NOT DISTRIBUTE
--DO NOT COPY/REUSE WITHOUT EXPRESS PERMISSION
--DO NOT REUPLOAD TO OTHER SITES
--Feel free to ask via nexus/discord, I just dont want my stuff stolen :)
--===================

---Registers a table with the RelativeCoordinateCalulator
---@param tableID string tableID
---@param tablePosition Vector4 table position
---@param tableOrientation Quaternion table orientation
function RelativeCoordinateCalulator.registerTable(tableID, tablePosition, tableOrientation)
    RelativeCoordinateCalulator.registeredTables[tableID] = {
        position = tablePosition,
        orientation = tableOrientation,
    }
end

---Registers an offset with the RelativeCoordinateCalulator
---@param offsetID string offsetID
---@param offsetPosition Vector4 offset position
---@param offsetOrientation Quaternion offset orientation
function RelativeCoordinateCalulator.registerOffset(offsetID, offsetPosition, offsetOrientation)
    RelativeCoordinateCalulator.registeredOffsets[offsetID] = {
        position = offsetPosition,
        orientation = offsetOrientation,
    }
end

---Calculates position relative to a base position, using table orientation for direction
---Use this for chaining cards: "right" always means table-right, not card-right
---@param basePosition Vector4 world position of the base entity (e.g., previous card)
---@param tableID string tableID to use for orientation reference
---@param relativeOffset Vector4|string offset position (Vector4) or registered offsetID (string) in table's local space
---@param relativeOrientation? Quaternion offset orientation (defaults to identity or offset's orientation if using offsetID)
---@return Vector4 worldPosition resulting world position
---@return Quaternion worldOrientation resulting world orientation
function RelativeCoordinateCalulator.calculateFromPositionWithTable(basePosition, tableID, relativeOffset, relativeOrientation)
    local table = RelativeCoordinateCalulator.registeredTables[tableID]
    if not table then
        DualPrint("Table '" .. tableID .. "' not found")
        return basePosition, Quaternion.new(0, 0, 0, 1)
    end
    
    -- Resolve offset: can be Vector4 or offsetID string
    local offsetPos, offsetOri
    if type(relativeOffset) == "string" then
        local offset = RelativeCoordinateCalulator.registeredOffsets[relativeOffset]
        if not offset then
            DualPrint("Offset '" .. relativeOffset .. "' not found")
            return basePosition, Quaternion.new(0, 0, 0, 1)
        end
        offsetPos = offset.position
        offsetOri = relativeOrientation or offset.orientation
    else
        offsetPos = relativeOffset
        offsetOri = relativeOrientation or Quaternion.new(0, 0, 0, 1)
    end
    
    -- Transform the relative offset by the TABLE's rotation
    local offsetPositionVector = Vector4.new(offsetPos.x, offsetPos.y, offsetPos.z, 0)
    local transformedOffsetPosition = table.orientation:Transform(offsetPositionVector)
    
    -- Add transformed offset to base position
    local worldPosition = Vector4.new(
        basePosition.x + transformedOffsetPosition.x,
        basePosition.y + transformedOffsetPosition.y,
        basePosition.z + transformedOffsetPosition.z,
        basePosition.w
    )
    
    -- Compose rotations: get basis vectors from relative orientation, transform by TABLE rotation
    local relativeForward = offsetOri:GetForward()
    local relativeUp = offsetOri:GetUp()
    
    -- Transform relative basis vectors by TABLE rotation
    local transformedForward = table.orientation:Transform(relativeForward)
    local transformedUp = table.orientation:Transform(relativeUp)
    
    -- Build the composed quaternion
    local worldOrientation = Quaternion.BuildFromDirectionVector(transformedForward, transformedUp)
    
    return worldPosition, worldOrientation
end

---Calculates position relative to a base position/orientation
---Use this when directions should be relative to the base entity itself
---@param basePosition Vector4 world position of the base entity
---@param baseOrientation Quaternion world orientation of the base entity
---@param relativeOffset Vector4 offset position in base's local space
---@param relativeOrientation? Quaternion offset orientation (defaults to identity)
---@return Vector4 worldPosition resulting world position
---@return Quaternion worldOrientation resulting world orientation
function RelativeCoordinateCalulator.calculateFromPosition(basePosition, baseOrientation, relativeOffset, relativeOrientation)
    local offsetOri = relativeOrientation or Quaternion.new(0, 0, 0, 1)
    
    -- Transform the relative offset by the base's rotation
    local offsetPositionVector = Vector4.new(relativeOffset.x, relativeOffset.y, relativeOffset.z, 0)
    local transformedOffsetPosition = baseOrientation:Transform(offsetPositionVector)
    
    -- Add transformed offset to base position
    local worldPosition = Vector4.new(
        basePosition.x + transformedOffsetPosition.x,
        basePosition.y + transformedOffsetPosition.y,
        basePosition.z + transformedOffsetPosition.z,
        basePosition.w
    )
    
    -- Compose rotations: get basis vectors from relative orientation, transform by base rotation
    local relativeForward = offsetOri:GetForward()
    local relativeUp = offsetOri:GetUp()
    
    -- Transform relative basis vectors by base rotation
    local transformedForward = baseOrientation:Transform(relativeForward)
    local transformedUp = baseOrientation:Transform(relativeUp)
    
    -- Build the composed quaternion
    local worldOrientation = Quaternion.BuildFromDirectionVector(transformedForward, transformedUp)
    
    return worldPosition, worldOrientation
end

---Calculates the relative coordinate and rotation of an entity relative to a table
---@param tableID string tableID
---@param offsetID string offsetID
---@return Vector4 relativePosition world position
---@return Quaternion relativeOrientation world orientation
function RelativeCoordinateCalulator.calculateRelativeCoordinate(tableID, offsetID)
    local table = RelativeCoordinateCalulator.registeredTables[tableID]
    local offset = RelativeCoordinateCalulator.registeredOffsets[offsetID]
    -- Transform the offset position by the table's rotation before adding to table position
    -- This ensures the offset rotates around the table center when the table rotates
    local offsetPositionVector = Vector4.new(offset.position.x, offset.position.y, offset.position.z, 0)
    local transformedOffsetPosition = table.orientation:Transform(offsetPositionVector)
    local relativePosition = Vector4.new(
        table.position.x + transformedOffsetPosition.x,
        table.position.y + transformedOffsetPosition.y,
        table.position.z + transformedOffsetPosition.z,
        table.position.w
    )
    -- Compose rotations properly: get basis vectors from offset, transform by table rotation
    -- This applies offset rotation first, then table rotation (equivalent to table * offset)
    local offsetForward = offset.orientation:GetForward()
    local offsetUp = offset.orientation:GetUp()
    
    -- Transform the offset's basis vectors by the table's rotation
    local transformedForward = table.orientation:Transform(offsetForward)
    local transformedUp = table.orientation:Transform(offsetUp)
    
    -- Build the composed quaternion from the transformed vectors
    local relativeOrientation = Quaternion.BuildFromDirectionVector(transformedForward, transformedUp)
    
    return relativePosition, relativeOrientation
end

return RelativeCoordinateCalulator