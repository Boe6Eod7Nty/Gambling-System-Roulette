RouletteMainMenu = {
    version = '1.0.0'
}
--===================
--CODE BY Boe6
--DO NOT DISTRIBUTE
--DO NOT COPY/REUSE WITHOUT EXPRESS PERMISSION
--DO NOT REUPLOAD TO OTHER SITES
--Feel free to ask via nexus/discord, I just dont want my stuff stolen :)
--===================

local interactionUI = require("External/interactionUI.lua")
local GameLocale = require("External/GameLocale.lua")

-- Note: This module depends on variables and functions from init.lua:
-- playerPile, currentBets, previousBet, previousBetAvailable, previousBetsCost
-- betsPlacesTaken, queueUIBet, betCategories, betCategoryIndexes
-- chip_values, betSizingSets, PlaceBet(), RepeatBets(), ChangePlayerChipValue()
-- AddValueCommas(), roulette_spinning, ball_spinning, holographicDisplayActive
-- HolographicValueDisplay, tableCenterPoint, activeTable, RotatePoint()
-- showCustomBuyChips, showCustomBetChips

---interactionUI wrapper function
---@param choiceCount number
---@param hubName string
---@param choicesStrings table
---@param choicesIcons table
---@param choicesFonts table
---@param choiceActions table
function CommitUI(choiceCount, hubName, choicesStrings, choicesIcons, choicesFonts, choiceActions)
    local hubQueue = {}
    for i = 1, choiceCount do
        hubQueue[i] = interactionUI.createChoice(choicesStrings[i], TweakDBInterface.GetChoiceCaptionIconPartRecord(choicesIcons[i]), choicesFonts[i])
    end
    --Setup, set and show hub
    local hub = interactionUI.createHub(hubName, hubQueue) -- Create hub and give it the list of choices
    interactionUI.setupHub(hub) -- Set the hub
    interactionUI.showHub() -- Show the previously set hub
    for i = 1, choiceCount do
        interactionUI.callbacks[i] = choiceActions[i]
    end
end

---Main menu UI
function RouletteMainMenu.MainMenuUI() -- original function code by keanuwheeze

    -- setup choice availability
    local repeatFont = gameinteractionsChoiceType.AlreadyRead
    local repeatFontBool = false
    local placeFont = gameinteractionsChoiceType.AlreadyRead
    local placeFontBool = false
    local buyFont = gameinteractionsChoiceType.AlreadyRead
    local buyFontBool = false
    local cashOutFont = gameinteractionsChoiceType.AlreadyRead
    local cashOutFontBool = false

    if previousBetAvailable and previousBetsCost <= playerPile.value then
        repeatFont = gameinteractionsChoiceType.Selected
        repeatFontBool = true
    end
    if playerPile.value > 0 then
        placeFont = gameinteractionsChoiceType.Selected
        placeFontBool = true
    end
    local playerMoney = Game.GetTransactionSystem():GetItemQuantity(GetPlayer(), MarketSystem.Money())
    if playerMoney > 0 then
        buyFont = gameinteractionsChoiceType.Selected
        buyFontBool = true
    end
    if next(currentBets) == nil then
        cashOutFont = gameinteractionsChoiceType.Selected
        cashOutFontBool = true
    end

    -- setup UI
    local choiceCount = 6
    local hubName = GameLocale.Text("Roulette")
    local choicesStrings = {GameLocale.Text("Repeat Previous Bets"), GameLocale.Text("Place Bets"), GameLocale.Text("Spin Roulette Wheel"), GameLocale.Text("Buy Chips"), GameLocale.Text("Settings"), GameLocale.Text("Cash Out")}
    local choicesIcons = {"ChoiceCaptionParts.DistractIcon","ChoiceCaptionParts.DistractIcon","ChoiceCaptionParts.TakeControlIcon","ChoiceCaptionParts.OpenVendorIcon","ChoiceCaptionParts.ControlPanelIcon","ChoiceCaptionParts.GetUpIcon"}
    local choicesFonts = {repeatFont,placeFont,gameinteractionsChoiceType.Selected,buyFont,gameinteractionsChoiceType.AlreadyRead,cashOutFont}
    local choiceActions = {
        function() --"Repeat Bets"
            --DuelPrint("Choice 1 used")
            if repeatFontBool then
                interactionUI.hideHub()
                RepeatBets()
            end
        end,
        function() --"Place Bets"
            --DuelPrint("Choice 2 used")
            if placeFontBool then
                interactionUI.hideHub()
                RouletteMainMenu.PlaceBetsUI()
            end
        end,
        function() --"Spin Roulette Wheel"
            --DuelPrint("Choice 3 used")
            interactionUI.hideHub()
            roulette_spinning = true
            ball_spinning = true
        
            Game.GetPlayer():PlaySoundEvent("q303_hotel_casino_roulette_ball_start")
        end,
        function() --"Buy Chips"
            --DuelPrint("Choice 4 used")
            if buyFontBool then
                interactionUI.hideHub()
                RouletteMainMenu.BuyChipsUI()
            end
        end,
        function() --"Settings"
            --DuelPrint("Choice 5 used")
        end,
        function() --"Cash Out"
            --DuelPrint("Choice 6 used")
            if cashOutFontBool then
                interactionUI.hideHub()
                Game.AddToInventory("Items.money", playerPile.value)
                ChangePlayerChipValue(-(playerPile.value))
                
                -- Stop holographic display when player leaves table
                if holographicDisplayActive then
                    HolographicValueDisplay.stopDisplay()
                    holographicDisplayActive = false
                end
                
                local leavePositionxy = RotatePoint({x=tableCenterPoint.x, y=tableCenterPoint.y}, {x=tableCenterPoint.x-0.86706985804199, y=tableCenterPoint.y-1.3005326803182}, activeTable.tableRotation)
                Game.GetTeleportationFacility():Teleport(GetPlayer(), Vector4.new(leavePositionxy.x, leavePositionxy.y, tableCenterPoint.z-0.93531358, 1), EulerAngles.new(0, 0, 340+activeTable.tableRotation)) --Vector4.new(-1034.6504, 1340.8641, 5.278, 1)
                StatusEffectHelper.RemoveStatusEffect(GetPlayer(), "GameplayRestriction.NoMovement") -- Enable player movement
                StatusEffectHelper.RemoveStatusEffect(GetPlayer(), "GameplayRestriction.NoCombat")
                previousBetAvailable = false
                inRouletteTable = false
                
                -- Note: The world.addInteraction callback will automatically show the join UI again
                -- when the player enters the interaction range, since inRouletteTable is now false
            end
        end
    }

    --send UI
    CommitUI(choiceCount, hubName, choicesStrings, choicesIcons, choicesFonts, choiceActions)
end

---Place bets UI
function RouletteMainMenu.PlaceBetsUI()
    local showRedBlack = false
    local fontRedBlack = gameinteractionsChoiceType.AlreadyRead
    for i,v in ipairs(betsPlacesTaken[1]) do
        if v == false then
            showRedBlack = true
            fontRedBlack = gameinteractionsChoiceType.Selected
        end
    end
    local showStraightUp = false
    local fontStraightUp = gameinteractionsChoiceType.AlreadyRead
    for i,v in ipairs(betsPlacesTaken[6]) do
        if v == false then
            showStraightUp = true
            fontStraightUp = gameinteractionsChoiceType.Selected
        end
    end
    local showOutside = false
    local fontOutside = gameinteractionsChoiceType.AlreadyRead
    local outsideTables = {betsPlacesTaken[2], betsPlacesTaken[3], betsPlacesTaken[4], betsPlacesTaken[5]}
    for i,v in ipairs(outsideTables) do
        if showOutside then break end
        for j,k in ipairs(v) do
            if k == false then
                showOutside = true
                fontOutside = gameinteractionsChoiceType.Selected
                break
            end
        end
    end
    local showInside = false
    local fontInside = gameinteractionsChoiceType.AlreadyRead
    local insideTables = {betsPlacesTaken[7], betsPlacesTaken[8], betsPlacesTaken[9], betsPlacesTaken[10]}
    --[[  DISABLED UNTIL DEVELOPER FIX - sry
    for i,v in ipairs(insideTables) do
        if showInside then break end
        for j,k in ipairs(v) do
            if k == false then
                showInside = true
                fontInside = gameinteractionsChoiceType.Selected
                break
            end
        end
    end
    ]]--

    local choiceCount = 5
    local hubName = GameLocale.Text("Roulette")
    local choiceStrings = {GameLocale.Text("Bet Red/Black"), GameLocale.Text("Bet Straight-Up"), GameLocale.Text("Bet Outside"), GameLocale.Text("Bet Inside"), GameLocale.Text("Return")}
    local choiceIcons = {"ChoiceCaptionParts.DistractIcon", "ChoiceCaptionParts.DistractIcon", "ChoiceCaptionParts.DistractIcon", "ChoiceCaptionParts.DistractIcon", "ChoiceCaptionParts.GetInIcon"}
    local choiceFonts = {fontRedBlack, fontStraightUp, fontOutside, fontInside, gameinteractionsChoiceType.Selected}
    local choiceActions = {
        function()
            --print("Choice 1 used")
            if showRedBlack then
                interactionUI.hideHub()
                queueUIBet.cat = "Red/Black"
                RouletteMainMenu.BetRedBlackUI()
            end
        end,
        function()
            --print("Choice 2 used")
            if showStraightUp then
                interactionUI.hideHub()
                queueUIBet.cat = "Straight-Up"
                RouletteMainMenu.BetStraightUpUI(1)
            end
        end,
        function()
            --print("Choice 3 used")
            if showOutside then
                interactionUI.hideHub()
                RouletteMainMenu.BetOutsideUI()
            end
        end,
        function()
            --print("Choice 4 used")
            if showInside then
                interactionUI.hideHub()
                RouletteMainMenu.BetInsideUI()
            end
        end,
        function()
            --print("Choice 5 used")
            interactionUI.hideHub()
            RouletteMainMenu.MainMenuUI()
        end
    }
    CommitUI(choiceCount, hubName, choiceStrings, choiceIcons, choiceFonts, choiceActions)
end

---Bet Red/Black UI
function RouletteMainMenu.BetRedBlackUI()
    local showRed = false
    local fontRed = gameinteractionsChoiceType.AlreadyRead
    if betsPlacesTaken[1][1] == false then
        showRed = true
        fontRed = gameinteractionsChoiceType.Selected
    end
    local showBlack = false
    local fontBlack = gameinteractionsChoiceType.AlreadyRead
    if betsPlacesTaken[1][2] == false then
        showBlack = true
        fontBlack = gameinteractionsChoiceType.Selected
    end

    local choiceCount = 3
    local hubName = GameLocale.Text("Roulette")
    local choicesStrings = {GameLocale.Text("Bet Red"), GameLocale.Text("Bet Black"), GameLocale.Text("Return")}
    local choicesIcons = {"ChoiceCaptionParts.DistractIcon", "ChoiceCaptionParts.DistractIcon", "ChoiceCaptionParts.GetIpIcon"}
    local choicesFonts = {fontRed, fontBlack, gameinteractionsChoiceType.Selected}
    local choiceActions = {
        function()
            --print("Choice 1 used")
            if showRed then
                queueUIBet.bet = "Red"
                interactionUI.hideHub()
                RouletteMainMenu.BetValueUI()
            end
        end,
        function()
            --print("Choice 2 used")
            if showBlack then
                queueUIBet.bet = "Black"
                interactionUI.hideHub()
                RouletteMainMenu.BetValueUI()
            end
        end,
        function()
            --print("Choice 3 used")
            interactionUI.hideHub()
            RouletteMainMenu.PlaceBetsUI()
        end
    }
    CommitUI(choiceCount, hubName, choicesStrings, choicesIcons, choicesFonts, choiceActions)
end

---Bet Straight-Up UI
---@param page number
function RouletteMainMenu.BetStraightUpUI(page)
    local rawBets = {
        "0 Green","1 Red","2 Black","3 Red","4 Black","5 Red","6 Black","7 Red","8 Black","9 Red","10 Black","11 Black","12 Red",
        "13 Black","14 Red","15 Black","16 Red","17 Black","18 Red","19 Red","20 Black","21 Red","22 Black","23 Red","24 Black",
        "25 Red","26 Black","27 Red","28 Black","29 Black","30 Red","31 Black","32 Red","33 Black","34 Red","35 Black","36 Red"
        }
    local bets = {
        " 0 "..GameLocale.Text('Green')," 1 "..GameLocale.Text('Red')," 2 "..GameLocale.Text('Black')," 3 "..GameLocale.Text('Red')," 4 "..GameLocale.Text('Black'),
        " 5 "..GameLocale.Text('Red')," 6 "..GameLocale.Text('Black')," 7 "..GameLocale.Text('Red')," 8 "..GameLocale.Text('Black')," 9 "..GameLocale.Text('Red'),
        " 10 "..GameLocale.Text('Black')," 11 "..GameLocale.Text('Black')," 12 "..GameLocale.Text('Red')," 13 "..GameLocale.Text('Black')," 14 "..GameLocale.Text('Red'),
        " 15 "..GameLocale.Text('Black')," 16 "..GameLocale.Text('Red')," 17 "..GameLocale.Text('Black')," 18 "..GameLocale.Text('Red')," 19 "..GameLocale.Text('Red'),
        " 20 "..GameLocale.Text('Black')," 21 "..GameLocale.Text('Red')," 22 "..GameLocale.Text('Black')," 23 "..GameLocale.Text('Red')," 24 "..GameLocale.Text('Black'),
        " 25 "..GameLocale.Text('Red')," 26 "..GameLocale.Text('Black')," 27 "..GameLocale.Text('Red')," 28 "..GameLocale.Text('Black')," 29 "..GameLocale.Text('Black'),
        " 30 "..GameLocale.Text('Red')," 31 "..GameLocale.Text('Black')," 32 "..GameLocale.Text('Red')," 33 "..GameLocale.Text('Black')," 34 "..GameLocale.Text('Red'),
        " 35 "..GameLocale.Text('Black')," 36 "..GameLocale.Text('Red')
        }
    for i=1, 37 do
        bets[i] = GameLocale.Text('Bet')..bets[i]
    end
    local sixBetsUsed = {}
    for i = 1, 6 do --for each bet page
        local pageIncrement = ( 6 * page ) - 5
        sixBetsUsed[i] = pageIncrement + i - 1
    end

    local showSixBets = {}
    local fontSixBets = {}
    for i = 1, 6 do
        showSixBets[i] = false
        fontSixBets[i] = gameinteractionsChoiceType.AlreadyRead
        local betIndex = -1
        for j,v in ipairs(betCategoryIndexes[6]) do
            --if bets[sixBetsUsed[1]] == v then --i thought this was the right way to check the if with 1 line, but it dont work so Im using the old/other way instead vvvv
            local stringNumber = tonumber(string.sub(v, 1, 2))
            if sixBetsUsed[i] -1 == stringNumber then
                betIndex = j
                break
            end
        end
        if betsPlacesTaken[6][betIndex] == false then
            showSixBets[i] = true
            fontSixBets[i] = gameinteractionsChoiceType.Selected
        end
    end
    local show7Bets = false
    local font7Bets = gameinteractionsChoiceType.AlreadyRead
    if betsPlacesTaken[6][37] == false then
        show7Bets = true
        font7Bets = gameinteractionsChoiceType.Selected
    end

    local choicesStrings = {}
    local choicesIcons ={}
    local choicesFonts = {fontSixBets[1], fontSixBets[2], fontSixBets[3], fontSixBets[4], fontSixBets[5], fontSixBets[6]}
    if page < 6 then
        choicesStrings = {bets[sixBetsUsed[1]], bets[sixBetsUsed[2]], bets[sixBetsUsed[3]], bets[sixBetsUsed[4]], bets[sixBetsUsed[5]], bets[sixBetsUsed[6]], GameLocale.Text("Next Page")}
        choicesIcons = {"ChoiceCaptionParts.DistractIcon","ChoiceCaptionParts.DistractIcon","ChoiceCaptionParts.DistractIcon","ChoiceCaptionParts.DistractIcon",
                    "ChoiceCaptionParts.DistractIcon","ChoiceCaptionParts.DistractIcon","ChoiceCaptionParts.TalkIcon"}
    else
        choicesStrings = {bets[sixBetsUsed[1]], bets[sixBetsUsed[2]], bets[sixBetsUsed[3]], bets[sixBetsUsed[4]], bets[sixBetsUsed[5]], bets[sixBetsUsed[6]], bets[37], GameLocale.Text("Next Page"), GameLocale.Text("Return")}
        choicesIcons = {"ChoiceCaptionParts.DistractIcon","ChoiceCaptionParts.DistractIcon","ChoiceCaptionParts.DistractIcon","ChoiceCaptionParts.DistractIcon",
                    "ChoiceCaptionParts.DistractIcon","ChoiceCaptionParts.DistractIcon","ChoiceCaptionParts.DistractIcon","ChoiceCaptionParts.TalkIcon","ChoiceCaptionParts.GetInIcon"}
    end
    local choiceCount = 7
    if page == 6 then
        choiceCount = 9
        table.insert(choicesFonts, font7Bets)
        table.insert(choicesFonts, gameinteractionsChoiceType.Selected)
        table.insert(choicesFonts, gameinteractionsChoiceType.Selected)
    else
        table.insert(choicesFonts, gameinteractionsChoiceType.Selected)
    end
    local choiceActions = {
        function()
            --print("Choice 1 used")
            if showSixBets[1] == true then
                queueUIBet.bet = rawBets[sixBetsUsed[1]]
                interactionUI.hideHub()
                RouletteMainMenu.BetValueUI()
            end
        end,
        function()
            --print("Choice 2 used")
            if showSixBets[2] == true then
                queueUIBet.bet = rawBets[sixBetsUsed[2]]
                interactionUI.hideHub()
                RouletteMainMenu.BetValueUI()
            end
        end,
        function()
            --print("Choice 3 used")
            if showSixBets[3] == true then
                queueUIBet.bet = rawBets[sixBetsUsed[3]]
                interactionUI.hideHub()
                RouletteMainMenu.BetValueUI()
            end
        end,
        function()
            --print("Choice 4 used")
            if showSixBets[4] == true then
                queueUIBet.bet = rawBets[sixBetsUsed[4]]
                interactionUI.hideHub()
                RouletteMainMenu.BetValueUI()
            end
        end,
        function()
            --print("Choice 5 used")
            if showSixBets[5] == true then
                queueUIBet.bet = rawBets[sixBetsUsed[5]]
                interactionUI.hideHub()
                RouletteMainMenu.BetValueUI()
            end
        end,
        function()
            --print("Choice 6 used")
            if showSixBets[6] == true then
                queueUIBet.bet = rawBets[sixBetsUsed[6]]
                interactionUI.hideHub()
                RouletteMainMenu.BetValueUI()
            end
        end
    }
    if page < 6 then
        choiceActions[7] = function()
            --print("Choice 7 used")
            interactionUI.hideHub()
            RouletteMainMenu.BetStraightUpUI(page + 1) --display next page
        end
    else
        choiceActions[7] = function()
            --print("Choice 7 used")
            if show7Bets == true then
                queueUIBet.bet = rawBets[37]
                interactionUI.hideHub()
                RouletteMainMenu.BetValueUI()
            end
        end
        choiceActions[8] = function()
            --print("Choice 8 used")
            interactionUI.hideHub()
            RouletteMainMenu.BetStraightUpUI(1) --loop back to page 1
        end
        choiceActions[9] = function()
            --print("Choice 9 used")
            interactionUI.hideHub()
            RouletteMainMenu.PlaceBetsUI() --goes back
        end
    end
    CommitUI(choiceCount, GameLocale.Text("Roulette"), choicesStrings, choicesIcons, choicesFonts, choiceActions)
end

---Bet Outside UI
function RouletteMainMenu.BetOutsideUI()
    local showOddEven = false
    local fontOddEven = gameinteractionsChoiceType.AlreadyRead
    for i,v in ipairs(betsPlacesTaken[2]) do
        if v == false then
            showOddEven = true
            fontOddEven = gameinteractionsChoiceType.Selected
            break
        end
    end
    local showHighLow = false
    local fontHighLow = gameinteractionsChoiceType.AlreadyRead
    for i,v in ipairs(betsPlacesTaken[3]) do
        if v == false then
            showHighLow = true
            fontHighLow = gameinteractionsChoiceType.Selected
            break
        end
    end
    local showColumns = false
    local fontColumns = gameinteractionsChoiceType.AlreadyRead
    for i,v in ipairs(betsPlacesTaken[4]) do
        if v == false then
            showColumns = true
            fontColumns = gameinteractionsChoiceType.Selected
            break
        end
    end
    local showDozen = false
    local fontDozen = gameinteractionsChoiceType.AlreadyRead
    for i,v in ipairs(betsPlacesTaken[5]) do
        if v == false then
            showDozen = true
            fontDozen = gameinteractionsChoiceType.Selected
            break
        end
    end
    local choiceCount = 5
    local hubName = GameLocale.Text("Roulette")
    local choicesStrings = {GameLocale.Text("Bet Odd/Even"), GameLocale.Text("Bet High/Low"), GameLocale.Text("Bet Columns"), GameLocale.Text("Bet Dozen"), GameLocale.Text("Return")}
    local choicesIcons = {"ChoiceCaptionParts.DistractIcon","ChoiceCaptionParts.DistractIcon","ChoiceCaptionParts.DistractIcon","ChoiceCaptionParts.DistractIcon","ChoiceCaptionParts.GetInIcon"}
    local choicesFonts = {fontOddEven, fontHighLow, fontColumns, fontDozen, gameinteractionsChoiceType.Selected}
    local choiceActions = {
        function()
            --print("Choice 1 used")
            if showOddEven then
                interactionUI.hideHub()
                queueUIBet.cat = "Odd/Even"
                RouletteMainMenu.BetOddEvenUI()
            end
        end,
        function()
            --print("Choice 2 used")
            if showHighLow then
                interactionUI.hideHub()
                queueUIBet.cat = "High/Low"
                RouletteMainMenu.BetHighLowUI()
            end
        end,
        function()
            --print("Choice 3 used")
            if showColumns then
                interactionUI.hideHub()
                queueUIBet.cat = "Column"
                RouletteMainMenu.BetColumnsUI()
            end
        end,
        function()
            --print("Choice 4 used")
            if showDozen then
                interactionUI.hideHub()
                queueUIBet.cat = "Dozen"
                RouletteMainMenu.BetDozenUI()
            end
        end,
        function()
            --print("Choice 5 used")
            interactionUI.hideHub()
            RouletteMainMenu.PlaceBetsUI()
        end
    }
    CommitUI(choiceCount, hubName, choicesStrings, choicesIcons, choicesFonts, choiceActions)
end

---Bet Odd/Even UI
function RouletteMainMenu.BetOddEvenUI()
    local showOdd = false
    local fontOdd = gameinteractionsChoiceType.AlreadyRead
    if betsPlacesTaken[2][1] == false then
        showOdd = true
        fontOdd = gameinteractionsChoiceType.Selected
    end
    local showEven = false
    local fontEven = gameinteractionsChoiceType.AlreadyRead
    if betsPlacesTaken[2][2] == false then
        showEven = true
        fontEven = gameinteractionsChoiceType.Selected
    end
    local choiceCount = 3
    local hubName = GameLocale.Text("Roulette")
    local choicesStrings = {GameLocale.Text("Bet Odd"), GameLocale.Text("Bet Even"), GameLocale.Text("Return")}
    local choicesIcons = {"ChoiceCaptionParts.DistractIcon","ChoiceCaptionParts.DistractIcon","ChoiceCaptionParts.GetInIcon"}
    local choicesFonts = {fontOdd, fontEven, gameinteractionsChoiceType.Selected}
    local choiceActions = {
        function()
            --print("Choice 1 used")
            if showOdd then
                interactionUI.hideHub()
                queueUIBet.bet = "Odd"
                RouletteMainMenu.BetValueUI()
            end
        end,
        function()
            --print("Choice 2 used")
            if showEven then
                interactionUI.hideHub()
                queueUIBet.bet = "Even"
                RouletteMainMenu.BetValueUI()
            end
        end,
        function()
            --print("Choice 3 used")
            interactionUI.hideHub()
            RouletteMainMenu.PlaceBetsUI()
        end
    }
    CommitUI(choiceCount, hubName, choicesStrings, choicesIcons, choicesFonts, choiceActions)
end

---Bet High/Low UI
function RouletteMainMenu.BetHighLowUI()
    local showHigh = false
    local fontHigh = gameinteractionsChoiceType.AlreadyRead
    if betsPlacesTaken[3][1] == false then
        showHigh = true
        fontHigh = gameinteractionsChoiceType.Selected
    end
    local showLow = false
    local fontLow = gameinteractionsChoiceType.AlreadyRead
    if betsPlacesTaken[3][2] == false then
        showLow = true
        fontLow = gameinteractionsChoiceType.Selected
    end
    local choiceCount = 3
    local hubName = GameLocale.Text("Roulette")
    local choicesStrings = {GameLocale.Text("Bet High"), GameLocale.Text("Bet Low"), GameLocale.Text("Return")}
    local choicesIcons = {"ChoiceCaptionParts.DistractIcon","ChoiceCaptionParts.DistractIcon","ChoiceCaptionParts.GetInIcon"}
    local choicesFonts = {fontHigh, fontLow, gameinteractionsChoiceType.Selected}
    local choiceActions = {
        function()
            --print("Choice 1 used")
            if showHigh then
                interactionUI.hideHub()
                queueUIBet.bet = "High"
                RouletteMainMenu.BetValueUI()
            end
        end,
        function()
            --print("Choice 2 used")
            if showLow then
                interactionUI.hideHub()
                queueUIBet.bet = "Low"
                RouletteMainMenu.BetValueUI()
            end
        end,
        function()
            --print("Choice 3 used")
            interactionUI.hideHub()
            RouletteMainMenu.PlaceBetsUI()
        end
    }
    CommitUI(choiceCount, hubName, choicesStrings, choicesIcons, choicesFonts, choiceActions)
end

---Bet Columns UI
function RouletteMainMenu.BetColumnsUI()
    local showColumn1 = false
    local fontColumn1 = gameinteractionsChoiceType.AlreadyRead
    if betsPlacesTaken[4][1] == false then
        showColumn1 = true
        fontColumn1 = gameinteractionsChoiceType.Selected
    end
    local showColumn2 = false
    local fontColumn2 = gameinteractionsChoiceType.AlreadyRead
    if betsPlacesTaken[4][2] == false then
        showColumn2 = true
        fontColumn2 = gameinteractionsChoiceType.Selected
    end
    local showColumn3 = false
    local fontColumn3 = gameinteractionsChoiceType.AlreadyRead
    if betsPlacesTaken[4][3] == false then
        showColumn3 = true
        fontColumn3 = gameinteractionsChoiceType.Selected
    end
    local choiceCount = 4
    local hubName = GameLocale.Text("Roulette")
    local choicesStrings = {GameLocale.Text("Bet 1st Column"), GameLocale.Text("Bet 2nd Column"), GameLocale.Text("Bet 3rd Column"), GameLocale.Text("Return")}
    local choicesIcons = {"ChoiceCaptionParts.DistractIcon","ChoiceCaptionParts.DistractIcon","ChoiceCaptionParts.DistractIcon","ChoiceCaptionParts.GetInIcon"}
    local choicesFonts = {fontColumn1, fontColumn2, fontColumn3, gameinteractionsChoiceType.Selected}
    local choiceActions = {
        function()
            --print("Choice 1 used")
            if showColumn1 then
                interactionUI.hideHub()
                queueUIBet.bet = "1st Column"
                RouletteMainMenu.BetValueUI()
            end
        end,
        function()
            --print("Choice 2 used")
            if showColumn2 then
                interactionUI.hideHub()
                queueUIBet.bet = "2nd Column"
                RouletteMainMenu.BetValueUI()
            end
        end,
        function()
            --print("Choice 3 used")
            if showColumn3 then
                interactionUI.hideHub()
                queueUIBet.bet = "3rd Column"
                RouletteMainMenu.BetValueUI()
            end
        end,
        function()
            --print("Choice 4 used")
            interactionUI.hideHub()
            RouletteMainMenu.PlaceBetsUI()
        end
    }
    CommitUI(choiceCount, hubName, choicesStrings, choicesIcons, choicesFonts, choiceActions)
end

---Bet Dozen UI
function RouletteMainMenu.BetDozenUI()
    local showDozen1 = false
    local fontDozen1 = gameinteractionsChoiceType.AlreadyRead
    if betsPlacesTaken[5][1] == false then
        showDozen1 = true
        fontDozen1 = gameinteractionsChoiceType.Selected
    end
    local showDozen2 = false
    local fontDozen2 = gameinteractionsChoiceType.AlreadyRead
    if betsPlacesTaken[5][2] == false then
        showDozen2 = true
        fontDozen2 = gameinteractionsChoiceType.Selected
    end
    local showDozen3 = false
    local fontDozen3 = gameinteractionsChoiceType.AlreadyRead
    if betsPlacesTaken[5][3] == false then
        showDozen3 = true
        fontDozen3 = gameinteractionsChoiceType.Selected
    end
    local choiceCount = 4
    local hubName = GameLocale.Text("Roulette")
    local choicesStrings = {GameLocale.Text("Bet 1-12 Dozen"), GameLocale.Text("Bet 13-24 Dozen"), GameLocale.Text("Bet 25-36 Dozen"), GameLocale.Text("Return")}
    local choicesIcons = {"ChoiceCaptionParts.DistractIcon","ChoiceCaptionParts.DistractIcon","ChoiceCaptionParts.DistractIcon","ChoiceCaptionParts.GetInIcon"}
    local choicesFonts = {fontDozen1, fontDozen2, fontDozen3, gameinteractionsChoiceType.Selected}
    local choiceActions = {
        function()
            --print("Choice 1 used")
            if showDozen1 then
                interactionUI.hideHub()
                queueUIBet.bet = "1-12 Dozen"
                RouletteMainMenu.BetValueUI()
            end
        end,
        function()
            --print("Choice 2 used")
            if showDozen2 then
                interactionUI.hideHub()
                queueUIBet.bet = "13-24 Dozen"
                RouletteMainMenu.BetValueUI()
            end
        end,
        function()
            --print("Choice 3 used")
            if showDozen3 then
                interactionUI.hideHub()
                queueUIBet.bet = "25-36 Dozen"
                RouletteMainMenu.BetValueUI()
            end
        end,
        function()
            --print("Choice 4 used")
            interactionUI.hideHub()
            RouletteMainMenu.PlaceBetsUI()
        end
    }
    CommitUI(choiceCount, hubName, choicesStrings, choicesIcons, choicesFonts, choiceActions)
end

---Bet Inside UI
function RouletteMainMenu.BetInsideUI()
    local showSplit = false
    local fontSplit = gameinteractionsChoiceType.AlreadyRead
    for i,v in ipairs(betsPlacesTaken[7]) do
        if v == false then
            showSplit = true
            fontSplit = gameinteractionsChoiceType.Selected
            break
        end
    end
    local showStreet = false
    local fontStreet = gameinteractionsChoiceType.AlreadyRead
    for i,v in ipairs(betsPlacesTaken[8]) do
        if v == false then
            showStreet = true
            fontStreet = gameinteractionsChoiceType.Selected
            break
        end
    end
    local showCorner = false
    local fontCorner = gameinteractionsChoiceType.AlreadyRead
    for i,v in ipairs(betsPlacesTaken[9]) do
        if v == false then
            showCorner = true
            fontCorner = gameinteractionsChoiceType.Selected
            break
        end
    end
    local showLine = false
    local fontLine = gameinteractionsChoiceType.AlreadyRead
    for i,v in ipairs(betsPlacesTaken[10]) do
        if v == false then
            showLine = true
            fontLine = gameinteractionsChoiceType.Selected
            break
        end
    end
    local choiceCount = 5
    local hubName = GameLocale.Text("Roulette")
    local choicesStrings = {GameLocale.Text("Bet Split"), GameLocale.Text("Bet Street"), GameLocale.Text("Bet Corner"), GameLocale.Text("Bet Line"), GameLocale.Text("Return")}
    local choicesIcons = {"ChoiceCaptionParts.DistractIcon","ChoiceCaptionParts.DistractIcon","ChoiceCaptionParts.DistractIcon","ChoiceCaptionParts.DistractIcon","ChoiceCaptionParts.GetInIcon"}
    local choicesFonts = {fontSplit, fontStreet, fontCorner, fontLine, gameinteractionsChoiceType.Selected}
    local choiceActions = {
        function()
            --print("Choice 1 used")
            if showSplit then
                interactionUI.hideHub()
                queueUIBet.bet = "Split"
                RouletteMainMenu.BetSplitUI(1)
            end
        end,
        function()
            --print("Choice 2 used")
            if showStreet then
                interactionUI.hideHub()
                queueUIBet.bet = "Street"
                RouletteMainMenu.BetStreetUI()
            end
        end,
        function()
            --print("Choice 3 used")
            if showCorner then
                interactionUI.hideHub()
                queueUIBet.bet = "Corner"
                RouletteMainMenu.BetCornerUI()
            end
        end,
        function()
            --print("Choice 4 used")
            if showLine then
                interactionUI.hideHub()
                queueUIBet.bet = "Line"
                RouletteMainMenu.BetLineUI()
            end
        end,
        function()
            --print("Choice 5 used")
            interactionUI.hideHub()
            RouletteMainMenu.PlaceBetsUI()
        end
    }
    CommitUI(choiceCount, hubName, choicesStrings, choicesIcons, choicesFonts, choiceActions)
end

---Bet Split UI
---@param page number
function RouletteMainMenu.BetSplitUI(page)
    local firstIndex = 6*page-6
    local showFirstSplit = false
    local fontFirstSplit = gameinteractionsChoiceType.AlreadyRead
    local showSecondSplit = false
    local fontSecondSplit = gameinteractionsChoiceType.AlreadyRead
    local showThirdSplit = false
    local fontThirdSplit = gameinteractionsChoiceType.AlreadyRead
    local showFourthSplit = false
    local fontFourthSplit = gameinteractionsChoiceType.AlreadyRead
    local showFifthSplit = false
    local fontFifthSplit = gameinteractionsChoiceType.AlreadyRead
    local showSixthSplit = false
    local fontSixthSplit = gameinteractionsChoiceType.AlreadyRead

    if betsPlacesTaken[7][firstIndex+1] == false then
        showFirstSplit = true
        fontFirstSplit = gameinteractionsChoiceType.Selected
    end
    if betsPlacesTaken[7][firstIndex+2] == false then
        showSecondSplit = true
        fontSecondSplit = gameinteractionsChoiceType.Selected
    end
    if betsPlacesTaken[7][firstIndex+3] == false then
        showThirdSplit = true
        fontThirdSplit = gameinteractionsChoiceType.Selected
    end
    if page < 10 then
        if betsPlacesTaken[7][firstIndex+4] == false then
            showFourthSplit = true
            fontFourthSplit = gameinteractionsChoiceType.Selected
        end
        if betsPlacesTaken[7][firstIndex+5] == false then
            showFifthSplit = true
            fontFifthSplit = gameinteractionsChoiceType.Selected
        end
        if betsPlacesTaken[7][firstIndex+6] == false then
            showSixthSplit = true
            fontSixthSplit = gameinteractionsChoiceType.Selected
        end
    end

    local choiceCount = 9
    if page == 10 then
        choiceCount = 6
    end
    local hubName = GameLocale.Text("Roulette")
    local choicesStrings = {}
    for i=1,6 do
        if page < 10 or i <= 3 then
            local splitBet = ''
            local betDefinition = betCategoryIndexes[7][firstIndex+i]
            local stringIndex6 = string.sub(betDefinition, 6, 6)
            if stringIndex6 == 'p' then
                splitBet = string.sub(betDefinition, 1, 3)
            elseif stringIndex6 == 'S' then
                splitBet = string.sub(betDefinition, 1, 4)
            else
                splitBet = string.sub(betDefinition, 1, 5)
            end
            table.insert(choicesStrings, GameLocale.Text("Bet")..' '..splitBet..' '..GameLocale.Text("Split"))
        end
    end
    table.insert(choicesStrings, GameLocale.Text("Previous Page"))
    table.insert(choicesStrings, GameLocale.Text("Return"))
    table.insert(choicesStrings, GameLocale.Text("Next Page"))
    local choicesIcons = {"ChoiceCaptionParts.DistractIcon","ChoiceCaptionParts.DistractIcon","ChoiceCaptionParts.DistractIcon"}
    if page < 10 then
        table.insert(choicesIcons, "ChoiceCaptionParts.DistractIcon")
        table.insert(choicesIcons, "ChoiceCaptionParts.DistractIcon")
        table.insert(choicesIcons, "ChoiceCaptionParts.DistractIcon")
    end
    table.insert(choicesIcons, "ChoiceCaptionParts.TalkIcon")
    table.insert(choicesIcons, "ChoiceCaptionParts.GetInIcon")
    table.insert(choicesIcons, "ChoiceCaptionParts.TalkIcon")
    local choicesFonts = {fontFirstSplit, fontSecondSplit, fontThirdSplit}
    if page < 10 then
        table.insert(choicesFonts, fontFourthSplit)
        table.insert(choicesFonts, fontFifthSplit)
        table.insert(choicesFonts, fontSixthSplit)
    end
    table.insert(choicesFonts, gameinteractionsChoiceType.AlreadyRead)
    table.insert(choicesFonts, gameinteractionsChoiceType.AlreadyRead)
    table.insert(choicesFonts, gameinteractionsChoiceType.AlreadyRead)
    local choicesActions = {
        function()
            --print("Choice 1 used")
            if showFirstSplit then
                interactionUI.hideHub()
                queueUIBet.bet = betCategoryIndexes[7][firstIndex+1]
                RouletteMainMenu.BetValueUI()
            end
        end,
        function()
            --print("Choice 2 used")
            if showSecondSplit then
                interactionUI.hideHub()
                queueUIBet.bet = betCategoryIndexes[7][firstIndex+2]
                RouletteMainMenu.BetValueUI()
            end
        end,
        function()
            --print("Choice 3 used")
            if showThirdSplit then
                interactionUI.hideHub()
                queueUIBet.bet = betCategoryIndexes[7][firstIndex+3]
                RouletteMainMenu.BetValueUI()
            end
        end
    }
    if page < 10 then
        table.insert(choicesActions,
        function()
            --print("Choice 4 used")
            if showFourthSplit then
                interactionUI.hideHub()
                queueUIBet.bet = betCategoryIndexes[7][firstIndex+4]
                RouletteMainMenu.BetValueUI()
            end
        end)
        table.insert(choicesActions,
        function()
            --print("Choice 5 used")
            if showFifthSplit then
                interactionUI.hideHub()
                queueUIBet.bet = betCategoryIndexes[7][firstIndex+5]
                RouletteMainMenu.BetValueUI()
            end
        end)
        table.insert(choicesActions,
        function()
            --print("Choice 6 used")
            if showSixthSplit then
                interactionUI.hideHub()
                queueUIBet.bet = betCategoryIndexes[7][firstIndex+6]
                RouletteMainMenu.BetValueUI()
            end
        end)
    end
    table.insert(choicesActions,
    function()
        --print("Choice 7 used")
        interactionUI.hideHub()
        if page > 1 then
            RouletteMainMenu.BetSplitUI(page + 9) --display previous page
        else
            RouletteMainMenu.BetSplitUI(page + 1) --display next page
        end
    end)
    table.insert(choicesActions,
    function()
        --print("Choice 8 used")
        interactionUI.hideHub()
        RouletteMainMenu.PlaceBetsUI()
    end)
    table.insert(choicesActions,
    function()
        --print("Choice 9 used")
        interactionUI.hideHub()
        if page < 10 then
            RouletteMainMenu.BetSplitUI(page+1)
        else
            RouletteMainMenu.BetSplitUI(1)
        end
    end)
    CommitUI(choiceCount, hubName, choicesStrings, choicesIcons, choicesFonts, choicesActions)
end

---Bet Street UI (placeholder - needs implementation)
function RouletteMainMenu.BetStreetUI()
    -- TODO: Implement BetStreetUI
    DuelPrint('BetStreetUI not yet implemented')
    interactionUI.hideHub()
    RouletteMainMenu.PlaceBetsUI()
end

---Bet Corner UI (placeholder - needs implementation)
function RouletteMainMenu.BetCornerUI()
    -- TODO: Implement BetCornerUI
    DuelPrint('BetCornerUI not yet implemented')
    interactionUI.hideHub()
    RouletteMainMenu.PlaceBetsUI()
end

---Bet Line UI (placeholder - needs implementation)
function RouletteMainMenu.BetLineUI()
    -- TODO: Implement BetLineUI
    DuelPrint('BetLineUI not yet implemented')
    interactionUI.hideHub()
    RouletteMainMenu.PlaceBetsUI()
end

---Bet Value UI
function RouletteMainMenu.BetValueUI()
    --should be updated to relative to player value, see notes. values worked out already
    local playerMoney = playerPile.value
    local betSizing = {1, 50, 1000, 50000, 1000000}
    if playerMoney <= 1000 then
        betSizing = betSizingSets[1]
    elseif playerMoney <= 10000 then
        betSizing = betSizingSets[2]
    elseif playerMoney <= 100000 then
        betSizing = betSizingSets[3]
    elseif playerMoney <= 1000000 then
        betSizing = betSizingSets[4]
    else
        betSizing = betSizingSets[5]
    end
    local fontsQueue = {}
    for i = 1, 5 do
        if playerMoney >= betSizing[i] then
            fontsQueue[i] = gameinteractionsChoiceType.Selected
        else
            fontsQueue[i] = gameinteractionsChoiceType.AlreadyRead
        end
    end
    local choiceCount = 7
    local hubName = GameLocale.Text("Roulette")
    local choiceStrings = {GameLocale.Text("Bet $")..AddValueCommas(betSizing[1]), GameLocale.Text("Bet $")..AddValueCommas(betSizing[2]), GameLocale.Text("Bet $")..AddValueCommas(betSizing[3]),
                            GameLocale.Text("Bet $")..AddValueCommas(betSizing[4]), GameLocale.Text("Bet $")..AddValueCommas(betSizing[5]), GameLocale.Text("Bet Custom Amount"), GameLocale.Text("Return")}
    local choiceIcons = {"ChoiceCaptionParts.DistractIcon", "ChoiceCaptionParts.DistractIcon", "ChoiceCaptionParts.DistractIcon", "ChoiceCaptionParts.DistractIcon", "ChoiceCaptionParts.DistractIcon", "ChoiceCaptionParts.DistractIcon", "ChoiceCaptionParts.GetInIcon"}
    local chocieFonts = {fontsQueue[1], fontsQueue[2], fontsQueue[3], fontsQueue[4], fontsQueue[5], gameinteractionsChoiceType.Selected, gameinteractionsChoiceType.Selected}
    local choiceActions = {
        function()
            --print("Choice 1 used")
            interactionUI.hideHub()
            PlaceBet(betSizing[1])
            RouletteMainMenu.MainMenuUI()
        end,
        function()
            --print("Choice 2 used")
            interactionUI.hideHub()
            PlaceBet(betSizing[2])
            RouletteMainMenu.MainMenuUI()
        end,
        function()
            --print("Choice 3 used")
            interactionUI.hideHub()
            PlaceBet(betSizing[3])
            RouletteMainMenu.MainMenuUI()
        end,
        function()
            --print("Choice 4 used")
            interactionUI.hideHub()
            PlaceBet(betSizing[4])
            RouletteMainMenu.MainMenuUI()
        end,
        function()
            --print("Choice 5 used")
            interactionUI.hideHub()
            PlaceBet(betSizing[5])
            RouletteMainMenu.MainMenuUI()
        end,
        function()
            --print("Choice 6 used")
            showCustomBetChips = true
        end,
        function()
            --print("Choice 7 used")
            interactionUI.hideHub()
            RouletteMainMenu.PlaceBetsUI()
        end
    }
    CommitUI(choiceCount, hubName, choiceStrings, choiceIcons, chocieFonts, choiceActions)
end

---Buy Chips UI
function RouletteMainMenu.BuyChipsUI()
    --set variable for player money
    local playerMoney = Game.GetTransactionSystem():GetItemQuantity(GetPlayer(), MarketSystem.Money())
    local buyValues = {10, 100, 1000, 10000, 100000, 1000000}
    local availableValues = {false, false, false, false, false, false}
    local UIcolors = {}
    for i=1, 6 do
        if playerMoney >= buyValues[i] then
            availableValues[i] = true
            UIcolors[i] = gameinteractionsChoiceType.Selected
        else
            UIcolors[i] = gameinteractionsChoiceType.AlreadyRead
        end
    end

    local choiceCount = 8
    local hubName = GameLocale.Text("Roulette")
    local choicesStrings = {GameLocale.Text("Buy $")..AddValueCommas(buyValues[1]), GameLocale.Text("Buy $")..AddValueCommas(buyValues[2]), GameLocale.Text("Buy $")..AddValueCommas(buyValues[3]),
                            GameLocale.Text("Buy $")..AddValueCommas(buyValues[4]), GameLocale.Text("Buy $")..AddValueCommas(buyValues[5]), GameLocale.Text("Buy $")..AddValueCommas(buyValues[6]),
                            GameLocale.Text("Buy Custom Amount"), GameLocale.Text("Return")}
    local choicesIcons = {"ChoiceCaptionParts.OpenVendorIcon","ChoiceCaptionParts.OpenVendorIcon","ChoiceCaptionParts.OpenVendorIcon","ChoiceCaptionParts.OpenVendorIcon","ChoiceCaptionParts.OpenVendorIcon","ChoiceCaptionParts.OpenVendorIcon","ChoiceCaptionParts.OpenVendorIcon","ChoiceCaptionParts.GetInIcon"}
    local choicesFonts = {UIcolors[1],UIcolors[2],UIcolors[3],UIcolors[4],UIcolors[5],UIcolors[6],gameinteractionsChoiceType.Selected,gameinteractionsChoiceType.Selected}
    local choicesActions = {
        function()
            --print("Choice 1 used")
            local index = 1
            if availableValues[index] == true then
                interactionUI.hideHub()
                ChangePlayerChipValue(buyValues[index])
                Game.AddToInventory("Items.money", -(buyValues[index]) )
                Game.GetPlayer():PlaySoundEvent("q303_06a_roulette_chips_stack")
                RouletteMainMenu.MainMenuUI()
            end
        end,
        function()
            --print("Choice 2 used")
            local index = 2
            if availableValues[index] == true then
                interactionUI.hideHub()
                ChangePlayerChipValue(buyValues[index])
                Game.AddToInventory("Items.money", -(buyValues[index]) )
                Game.GetPlayer():PlaySoundEvent("q303_06a_roulette_chips_stack")
                RouletteMainMenu.MainMenuUI()
            end
        end,
        function()
            --print("Choice 3 used")
            local index = 3
            if availableValues[index] == true then
                interactionUI.hideHub()
                ChangePlayerChipValue(buyValues[index])
                Game.AddToInventory("Items.money", -(buyValues[index]) )
                Game.GetPlayer():PlaySoundEvent("q303_06a_roulette_chips_stack")
                RouletteMainMenu.MainMenuUI()
            end
        end,
        function()
            --print("Choice 4 used")
            local index = 4
            if availableValues[index] == true then
                interactionUI.hideHub()
                ChangePlayerChipValue(buyValues[index])
                Game.AddToInventory("Items.money", -(buyValues[index]) )
                Game.GetPlayer():PlaySoundEvent("q303_06a_roulette_chips_stack")
                RouletteMainMenu.MainMenuUI()
            end
        end,
        function()
            --print("Choice 5 used")
            local index = 5
            if availableValues[index] == true then
                interactionUI.hideHub()
                ChangePlayerChipValue(buyValues[index])
                Game.AddToInventory("Items.money", -(buyValues[index]) )
                Game.GetPlayer():PlaySoundEvent("q303_06a_roulette_chips_stack")
                RouletteMainMenu.MainMenuUI()
            end
        end,
        function()
            --print("Choice 6 used")
            local index = 6
            if availableValues[index] == true then
                interactionUI.hideHub()
                ChangePlayerChipValue(buyValues[index])
                Game.AddToInventory("Items.money", -(buyValues[index]) )
                Game.GetPlayer():PlaySoundEvent("q303_06a_roulette_chips_stack")
                RouletteMainMenu.MainMenuUI()
            end
        end,
        function()
            --print("Choice 7 used")
            showCustomBuyChips = true
        end,
        function()
            --print("Choice 8 used")
            interactionUI.hideHub()
            RouletteMainMenu.MainMenuUI()
        end
    }
    CommitUI(choiceCount, hubName, choicesStrings, choicesIcons, choicesFonts, choicesActions)
end

return RouletteMainMenu

