<!-- c5ac21c7-7317-4ea1-bb9f-0a5c309b273c 5b77a57b-de8f-4610-931e-41c837f4c5a8 -->
# Migration Plan: Roulette Table Management to TableManager

## Overview

Migrate roulette from hardcoded `allTables`/`optionalTables` arrays to the `TableManager.lua` and `RelativeCoordinateCalulator` system used by blackjack. Create `RouletteCoordinates.lua` for roulette-specific coordinate registration.

## Phase 1: Create RouletteCoordinates.lua

### 1.1 Create RouletteCoordinates.lua

- Similar structure to `BlackjackCoordinates.lua`
- Register roulette tables using `RelativeCoordinateCalulator.registerTable()`
- Convert existing `allTables` entries:
- `hoohbar`: SpinnerCenterPoint → table position, tableRotation → Quaternion
- `tygerclawscasino`: Same conversion
- Handle `optionalTables` with dependency checks (similar to blackjack's JSON loading)
- Register roulette-specific offsets:
- `spinner_center_point` (table center for ball/spinner)
- `player_pile_position` (chip stack location)
- `player_playing_position` (where player stands/sits)
- `holographic_display_position` (holo display location)
- `table_board_origin` (betting board origin)
- `spot_position` (interaction spot location)
- `mappin_position` (world mappin location)
- `camera_position_offset` (camera offset)
- Any other roulette-specific positions currently calculated via `RotatePoint()`

### 1.2 Convert tableRotation to Quaternion

- Current: `tableRotation` is a float (degrees)
- Target: Convert to `Quaternion` for `RelativeCoordinateCalulator`
- Use `EulerAngles.new(0, 0, tableRotation):ToQuat()` or extract from `tableOrientation` if available

## Phase 2: Enhance TableManager.lua for Generic Use

### 2.1 Add Generic Entity Management

- Current: Only handles dealer spawning (`spawnDealer`, `despawnDealer`)
- Add: Generic entity tracking per table:
- `tableEntities[tableID] = {entityName = entID, ...}`
- Functions: `spawnTableEntity(tableID, entityName, entPath, position, orientation, tags)`
- Functions: `despawnTableEntity(tableID, entityName)`
- Functions: `cleanupTableEntities(tableID)`

### 2.2 Add Game-Specific Callbacks

- Modify `createSpotForTable()` to accept game-specific callbacks
- Add parameter: `gameType` ('blackjack' | 'roulette')
- Roulette callbacks:
- Spawn roulette_spinner, roulette_ball, roulette_spinner_frame
- Initialize chip pile positions
- Update RouletteAnimations ball center
- Handle holographic display positioning

### 2.3 Add Table Loading/Unloading

- Current: Tables loaded via `LoadTables()` on init
- Add: Distance-based loading/unloading (roulette currently has this in `callback40x`)
- `loadTableIfNearby(tableID, distance)` 
- `unloadTableIfFar(tableID, distance)`
- Track loaded state per table: `tableLoaded[tableID] = true/false`

### 2.4 Add Optional Table Support

- Handle dependency checks for optional tables
- Function: `registerOptionalTable(tableData, dependencyCheck)`
- Only register if dependency mod is enabled

## Phase 3: Migrate init.lua

### 3.1 Replace Table Arrays

- Remove `allTables` and `optionalTables` arrays
- Initialize `RouletteCoordinates.init()` in `onInit`
- Tables now come from `RelativeCoordinateCalulator.registeredTables`

### 3.2 Replace RotatePoint() Calls

- Find all `RotatePoint()` calls in `init.lua`
- Replace with `RelativeCoordinateCalulator.calculateRelativeCoordinate(tableID, offsetID)`
- Update: `InitTable()`, `UpdateJoinUI()`, position calculations

### 3.3 Migrate InitTable() Function

- Current: `InitTable(table)` takes table object from array
- New: `InitTable(tableID)` uses `TableManager` and `RelativeCoordinateCalulator`
- Use `TableManager.spawnTableEntity()` for roulette entities
- Use `RelativeCoordinateCalulator.calculateRelativeCoordinate()` for positions

### 3.4 Update Table Loading Logic

- Current: `callback40x` checks distance to `allTables[i].SpinnerCenterPoint`
- New: Iterate `RelativeCoordinateCalulator.registeredTables` and use `TableManager.loadTableIfNearby()`
- Use `RelativeCoordinateCalulator.calculateRelativeCoordinate(tableID, 'spinner_center_point')` for distance checks

### 3.5 Update Active Table References

- Replace `activeTable` object with `TableManager.GetActiveTable()` (returns tableID)
- Create helper: `GetActiveTableData()` that returns full table data from `RelativeCoordinateCalulator.registeredTables[tableID]`
- Update all references: `activeTable.SpinnerCenterPoint` → calculated coordinate
- Update: `activeTable.tableRotation` → get from table orientation

## Phase 4: Update Dependent Modules

### 4.1 Update ChipPlayerPile

- Currently receives `activeTable` object
- Update to use `TableManager.GetActiveTable()` and calculate positions via `RelativeCoordinateCalulator`

### 4.2 Update ChipBetPiles

- Similar updates for table position references

### 4.3 Update ChipUtils

- Update `tableBoardOrigin` references to use calculated coordinates

### 4.4 Update RouletteMainMenu

- Replace `activeTable` and `tableCenterPoint` references
- Use `TableManager.GetActiveTable()` and calculated coordinates

## Phase 5: Integration Points

### 5.1 SpotManager Integration (if switching from worldInteraction)

- Option A: Keep `worldInteraction.lua` for roulette (current approach)
- Option B: Migrate to `SpotManager` like blackjack
- **Decision needed**: Should roulette use SpotManager or keep worldInteraction?

### 5.2 TableManager.createSpotForTable() Adaptation

- If using SpotManager: Create roulette-specific spot configuration
- If keeping worldInteraction: Skip spot creation, handle separately

## Phase 6: Blackjack-Specific Cleanup

### 6.1 Identify Blackjack-Only Code in TableManager

- `spawnDealer()` - blackjack-specific, keep as-is
- `createSpotForTable()` - has blackjack callbacks (CardEngine, BlackjackMainMenu)
- Make callbacks configurable per game type

### 6.2 Document Game-Specific Features

- Blackjack: dealer spawning, card positions, hand count displays
- Roulette: spinner/ball entities, chip pile positions, betting board

## Files to Modify

1. **Create**: `RouletteCoordinates.lua`
2. **Modify**: `TableManager.lua` (rename spawnDealer→spawnNPC, add loading functions, state tracking)
3. **Modify**: `init.lua` (remove arrays, replace RotatePoint, update InitTable, new loading timer)
4. **Modify**: `ChipPlayerPile.lua`, `ChipBetPiles.lua`, `ChipUtils.lua` (update table references)
5. **Modify**: `RouletteMainMenu.lua` (update table references)

## Considerations

- **Quaternion Math**: All coordinate calculations must use Quaternion transforms (`:Transform()`, proper rotation composition)
- **Coordinate System**: All `RotatePoint()` calculations need offset registration in RouletteCoordinates
- **Entity Management**: Roulette entities (spinner, ball, frame) handled by existing scripts, not TableManager
- **Active Table**: Migration from object to tableID string requires helper functions (`GetActiveTableData()`)
- **Distance Loading**: Use configurable interval timer (not callback40x), 10x per second default
- **Optional NPCs**: Make dealer/NPC spawning optional per table via configuration
- **worldInteraction.lua**: Keep as-is, no SpotManager migration in this project
- **Testable Phases**: Each phase marked (TESTABLE) should be fully functional before proceeding

### To-dos

- [ ] Create RouletteCoordinates.lua file with table registration and offset definitions, converting allTables/optionalTables data
- [ ] Add generic entity management functions to TableManager (spawnTableEntity, despawnTableEntity, cleanupTableEntities)
- [ ] Add distance-based table loading/unloading functions to TableManager (loadTableIfNearby, unloadTableIfFar)
- [ ] Modify createSpotForTable to accept gameType parameter and game-specific callbacks for roulette vs blackjack
- [ ] Remove allTables/optionalTables arrays from init.lua and initialize RouletteCoordinates instead
- [ ] Replace all RotatePoint() calls in init.lua with RelativeCoordinateCalulator.calculateRelativeCoordinate()
- [ ] Refactor InitTable() to use TableManager and RelativeCoordinateCalulator instead of table object parameter
- [ ] Update callback40x distance checking to use TableManager and RelativeCoordinateCalulator instead of allTables array
- [ ] Update ChipPlayerPile, ChipBetPiles, and ChipUtils to use TableManager.GetActiveTable() and calculated coordinates
- [ ] Update RouletteMainMenu.lua to use TableManager.GetActiveTable() instead of activeTable object