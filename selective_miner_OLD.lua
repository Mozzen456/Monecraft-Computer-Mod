-- Selective Ore Miner for ComputerCraft / CC:Tweaked
-- Mines all ores, drops junk
-- Auto-deposits to chest, wireless status updates
-- Optimized for Advanced Mining Turtle
-- by Claude

-- ============== CONFIGURATION ==============
local TUNNEL_LENGTH = 64   -- How far to mine (matches wireless range)
local BRANCH_SPACING = 5   -- Blocks between branches (left/right)
local FUEL_SLOT = 16       -- Slot for fuel (coal)
local MIN_FUEL = 100       -- Minimum fuel before refueling
local MIN_COAL = 10        -- Return to chest when coal drops below this

-- Give your turtle a unique name (1-9)
local TURTLE_NAME = "Miner " .. os.getComputerID()
local CHANNEL = 100        -- Wireless channel (must match monitor)

-- ============== DETECT ADVANCED TURTLE ==============
local isAdvanced = term.isColor and term.isColor()
local MAX_FUEL = isAdvanced and 100000 or 20000

-- ============== ALL VARIABLES (must be before functions) ==============
-- Position tracking
local posX, posY, posZ = 0, 0, 0
local facing = 0  -- 0=forward, 1=right, 2=back, 3=left

-- Status tracking
local status = "Starting"
local oresFound = 0
local currentProgress = 0
local recallRequested = false
local tripCount = 0
local branchCount = 0
local miningDirection = 1  -- 1 = forward, -1 = returning

-- ============== WIRELESS SETUP ==============
local modem = peripheral.find("modem")
local hasWireless = modem and modem.isWireless and modem.isWireless()

if hasWireless then
    modem.open(CHANNEL)
    print("Wireless enabled on channel " .. CHANNEL)
else
    print("No wireless modem - running without status updates")
end

-- ============== KEYWORDS/TABLES ==============
-- Keywords that indicate a block is an ore (works with ANY mod)
local ORE_KEYWORDS = {
    "ore",
    "debris",    -- ancient debris
    "cluster",   -- amethyst clusters, mod clusters
}

-- Junk items to DROP (everything else is kept)
local JUNK_ITEMS = {
    -- Stone types
    ["minecraft:cobblestone"] = true,
    ["minecraft:stone"] = true,
    ["minecraft:deepslate"] = true,
    ["minecraft:cobbled_deepslate"] = true,
    ["minecraft:andesite"] = true,
    ["minecraft:diorite"] = true,
    ["minecraft:granite"] = true,
    ["minecraft:tuff"] = true,
    ["minecraft:calcite"] = true,
    ["minecraft:smooth_basalt"] = true,
    ["minecraft:basalt"] = true,
    ["minecraft:blackstone"] = true,
    -- Dirt types
    ["minecraft:dirt"] = true,
    ["minecraft:gravel"] = true,
    ["minecraft:sand"] = true,
    ["minecraft:red_sand"] = true,
    ["minecraft:clay"] = true,
    ["minecraft:soul_sand"] = true,
    ["minecraft:soul_soil"] = true,
    ["minecraft:netherrack"] = true,
    -- Other common junk
    ["minecraft:flint"] = true,
    ["minecraft:mossy_cobblestone"] = true,
}

-- Keywords that indicate junk (for mod support)
local JUNK_KEYWORDS = {
    "cobblestone",
    "cobbled",
    "stone",
    "deepslate",
    "dirt",
    "gravel",
    "sand",
    "netherrack",
    "andesite",
    "diorite",
    "granite",
    "tuff",
    "basalt",
    "blackstone",
    "slate",
}

-- ============== HELPER FUNCTIONS ==============
-- Count total coal/charcoal in inventory
local function countCoal()
    local count = 0
    for i = 1, 16 do
        local item = turtle.getItemDetail(i)
        if item and (item.name == "minecraft:coal" or item.name == "minecraft:charcoal") then
            count = count + item.count
        end
    end
    return count
end

-- ============== COLORED DISPLAY (Advanced Turtle) ==============
local function setColor(textColor, bgColor)
    if isAdvanced then
        if textColor then term.setTextColor(textColor) end
        if bgColor then term.setBackgroundColor(bgColor) end
    end
end

local function resetColors()
    if isAdvanced then
        term.setTextColor(colors.white)
        term.setBackgroundColor(colors.black)
    end
end

local function colorPrint(text, textColor)
    setColor(textColor)
    print(text)
    resetColors()
end

local function drawStatusBar()
    if not isAdvanced then return end

    local w, h = term.getSize()
    term.setCursorPos(1, h)
    term.setBackgroundColor(colors.gray)
    term.clearLine()

    -- Fuel bar
    term.setCursorPos(1, h)
    term.setTextColor(colors.white)
    term.write("Fuel:")

    local barWidth = 10
    local filled = math.floor((turtle.getFuelLevel() / MAX_FUEL) * barWidth)

    term.setCursorPos(6, h)
    term.setBackgroundColor(colors.red)
    term.write(string.rep(" ", barWidth))
    term.setCursorPos(6, h)
    term.setBackgroundColor(colors.lime)
    term.write(string.rep(" ", filled))

    -- Stats
    term.setBackgroundColor(colors.gray)
    term.setTextColor(colors.yellow)
    term.setCursorPos(17, h)
    term.write(" Z:" .. posZ .. " ")

    term.setTextColor(colors.cyan)
    term.write("Ore:" .. oresFound .. " ")

    term.setTextColor(colors.orange)
    term.write("C:" .. countCoal())

    resetColors()
end

-- ============== RECALL LISTENER ==============
local function recallListener()
    while true do
        if hasWireless then
            local event, side, channel, replyChannel, message, distance = os.pullEvent("modem_message")

            if channel == CHANNEL and type(message) == "table" then
                if message.type == "recall" then
                    colorPrint(">>> RECALL RECEIVED <<<", colors.red)
                    recallRequested = true
                elseif message.type == "recall_id" and message.id == os.getComputerID() then
                    colorPrint(">>> RECALL (ID) RECEIVED <<<", colors.red)
                    recallRequested = true
                end
            end
        else
            sleep(1)
        end
    end
end

-- ============== MOVEMENT FUNCTIONS ==============
-- With retry logic to handle mobs, gravel, and lag

local function turnLeft()
    turtle.turnLeft()
    facing = (facing - 1) % 4
end

local function turnRight()
    turtle.turnRight()
    facing = (facing + 1) % 4
end

local function forward()
    local tries = 0
    while not turtle.forward() do
        tries = tries + 1
        if tries > 10 then
            print("Stuck! Cannot move forward after 10 tries")
            return false
        end

        -- Try to dig if blocked
        if turtle.detect() then
            turtle.dig()
            sleep(0.3)  -- Wait for gravel/sand
        end

        -- Try to attack if mob is blocking
        turtle.attack()
        sleep(0.2)
    end

    -- Update position
    if facing == 0 then posZ = posZ + 1
    elseif facing == 1 then posX = posX + 1
    elseif facing == 2 then posZ = posZ - 1
    elseif facing == 3 then posX = posX - 1
    end
    return true
end

local function back()
    local tries = 0
    while not turtle.back() do
        tries = tries + 1
        if tries > 10 then
            print("Stuck! Cannot move back after 10 tries")
            -- Turn around and try forward
            turnRight()
            turnRight()
            local result = forward()
            turnRight()
            turnRight()
            return result
        end
        sleep(0.2)
    end

    -- Update position
    if facing == 0 then posZ = posZ - 1
    elseif facing == 1 then posX = posX - 1
    elseif facing == 2 then posZ = posZ + 1
    elseif facing == 3 then posX = posX + 1
    end
    return true
end

local function up()
    local tries = 0
    while not turtle.up() do
        tries = tries + 1
        if tries > 10 then
            print("Stuck! Cannot move up after 10 tries")
            return false
        end

        -- Try to dig if blocked
        if turtle.detectUp() then
            turtle.digUp()
            sleep(0.3)  -- Wait for gravel/sand
        end

        -- Try to attack if mob is above
        turtle.attackUp()
        sleep(0.2)
    end

    posY = posY + 1
    return true
end

local function down()
    local tries = 0
    while not turtle.down() do
        tries = tries + 1
        if tries > 10 then
            print("Stuck! Cannot move down after 10 tries")
            return false
        end

        -- Try to dig if blocked
        if turtle.detectDown() then
            turtle.digDown()
        end

        -- Try to attack if mob is below
        turtle.attackDown()
        sleep(0.2)
    end

    posY = posY - 1
    return true
end

-- ============== ORE DETECTION ==============
local function isTargetOre(inspectFunc)
    local success, data = inspectFunc()
    if success and data and data.name then
        local name = string.lower(data.name)
        for _, keyword in ipairs(ORE_KEYWORDS) do
            if string.find(name, keyword) then
                return true
            end
        end
    end
    return false
end

-- ============== FUEL MANAGEMENT ==============
local function checkFuel()
    local refuelThreshold = isAdvanced and 1000 or MIN_FUEL
    local refuelAmount = isAdvanced and 16 or 1

    if turtle.getFuelLevel() < refuelThreshold then
        local currentSlot = turtle.getSelectedSlot()
        turtle.select(FUEL_SLOT)
        if turtle.getItemCount(FUEL_SLOT) > 0 then
            turtle.refuel(refuelAmount)
            colorPrint("Refueled! Fuel: " .. turtle.getFuelLevel(), colors.lime)
        else
            for i = 1, 15 do
                turtle.select(i)
                local item = turtle.getItemDetail()
                if item and (item.name == "minecraft:coal" or item.name == "minecraft:charcoal") then
                    turtle.refuel(refuelAmount)
                    colorPrint("Refueled from slot " .. i .. "! Fuel: " .. turtle.getFuelLevel(), colors.lime)
                    break
                end
            end
        end
        turtle.select(currentSlot)
    end
    return turtle.getFuelLevel() > 0
end

-- ============== INVENTORY MANAGEMENT ==============
local function isInventoryFull()
    for i = 1, 15 do
        if turtle.getItemCount(i) == 0 then
            return false
        end
    end
    return true
end

local function isCoalLow()
    return countCoal() < MIN_COAL
end

local function isJunk(itemName)
    if JUNK_ITEMS[itemName] then
        return true
    end
    local name = string.lower(itemName)
    for _, keyword in ipairs(ORE_KEYWORDS) do
        if string.find(name, keyword) then
            return false
        end
    end
    for _, keyword in ipairs(JUNK_KEYWORDS) do
        if string.find(name, keyword) then
            return true
        end
    end
    return false
end

local function dropJunk()
    local currentSlot = turtle.getSelectedSlot()
    local droppedCount = 0

    for i = 1, 15 do
        turtle.select(i)
        local item = turtle.getItemDetail()
        if item and isJunk(item.name) then
            turtle.drop()
            droppedCount = droppedCount + 1
        end
    end

    turtle.select(currentSlot)
    if droppedCount > 0 then
        print("Dropped junk from " .. droppedCount .. " slots")
    end
end

-- ============== WIRELESS STATUS ==============
local function sendStatus()
    if not hasWireless then return end

    local data = {
        type = "miner_status",
        id = os.getComputerID(),
        name = TURTLE_NAME,
        status = status,
        posX = posX,
        posY = posY,
        posZ = posZ,
        fuel = turtle.getFuelLevel(),
        coal = countCoal(),
        ores = oresFound,
        trip = tripCount,
        progress = currentProgress,
        maxProgress = TUNNEL_LENGTH,
        time = os.clock()
    }

    modem.transmit(CHANNEL, CHANNEL, data)
end

-- ============== CHEST DEPOSIT ==============
local function depositToChest()
    print("Depositing to chest...")
    local currentSlot = turtle.getSelectedSlot()
    local depositedCount = 0

    turtle.turnLeft()
    turtle.turnLeft()

    local success, data = turtle.inspect()
    if success and data.name and string.find(data.name, "chest") then
        for i = 1, 15 do
            turtle.select(i)
            local item = turtle.getItemDetail()
            if item then
                if item.name == "minecraft:coal" or item.name == "minecraft:charcoal" then
                    if item.count > 64 then
                        turtle.drop(item.count - 64)
                        depositedCount = depositedCount + 1
                    end
                else
                    turtle.drop()
                    depositedCount = depositedCount + 1
                end
            end
        end
        print("Deposited " .. depositedCount .. " stacks to chest")

        if isCoalLow() then
            print("Grabbing coal from chest...")
            for i = 1, 15 do
                turtle.select(i)
                local item = turtle.getItemDetail()
                if not item or item.name == "minecraft:coal" or item.name == "minecraft:charcoal" then
                    turtle.suck(64)
                    break
                end
            end
            print("Coal count: " .. countCoal())
        end
    else
        print("No chest found! Place a chest behind the turtle's start position.")
    end

    turtle.turnLeft()
    turtle.turnLeft()
    turtle.select(currentSlot)
end

-- ============== DIGGING ==============
local function digForward()
    while turtle.detect() do
        turtle.dig()
        sleep(0.3)
    end
end

-- ============== VEIN MINING ==============
-- SAFE version: only mines adjacent ores without moving
-- This prevents the turtle from getting lost
local function mineVein()
    -- Just dig ores in all 6 directions WITHOUT moving
    -- This is safe - turtle stays in place

    -- Dig up if ore
    if isTargetOre(turtle.inspectUp) then
        turtle.digUp()
        oresFound = oresFound + 1
        sleep(0.3)
    end

    -- Dig down if ore
    if isTargetOre(turtle.inspectDown) then
        turtle.digDown()
        oresFound = oresFound + 1
        sleep(0.3)
    end

    -- Dig front if ore
    if isTargetOre(turtle.inspect) then
        turtle.dig()
        oresFound = oresFound + 1
        sleep(0.3)
    end

    -- Dig right if ore
    turnRight()
    if isTargetOre(turtle.inspect) then
        turtle.dig()
        oresFound = oresFound + 1
        sleep(0.3)
    end

    -- Dig back if ore
    turnRight()
    if isTargetOre(turtle.inspect) then
        turtle.dig()
        oresFound = oresFound + 1
        sleep(0.3)
    end

    -- Dig left if ore
    turnRight()
    if isTargetOre(turtle.inspect) then
        turtle.dig()
        oresFound = oresFound + 1
        sleep(0.3)
    end

    -- Face original direction
    turnRight()
end

-- ============== MOVE TO NEXT BRANCH ==============
local function moveToNextBranch()
    print("Moving to next branch...")

    -- At home position, turn left
    turnLeft()

    -- Move 5 blocks to the side
    for i = 1, BRANCH_SPACING do
        digForward()
        if not forward() then
            print("Cannot move to next branch!")
            return false
        end
        turtle.digUp()  -- 2-high tunnel
    end

    -- Turn right to face mining direction again
    turnRight()

    print("Ready for branch #" .. (branchCount + 1))
    return true
end

-- ============== RETURN HOME ==============
local function returnHome()
    print("Returning home...")

    while posY > 0 do
        down()
    end
    while posY < 0 do
        turtle.digUp()
        up()
    end

    while facing ~= 2 do
        turnRight()
    end

    while posZ > 0 do
        digForward()
        forward()
    end

    if posX > 0 then
        turnRight()
        while posX > 0 do
            digForward()
            forward()
        end
    elseif posX < 0 then
        turnLeft()
        while posX < 0 do
            digForward()
            forward()
        end
    end

    while facing ~= 0 do
        turnRight()
    end

    print("Home!")
end

-- ============== MINE ONE TUNNEL ==============
local function mineTunnel()
    for i = 1, TUNNEL_LENGTH do
        currentProgress = i
        status = "Mining"

        -- Check for recall command
        if recallRequested then
            colorPrint("RECALLING - Returning home!", colors.red)
            status = "Recalled"
            sendStatus()
            returnHome()
            depositToChest()
            colorPrint("Recall complete. Turtle at home.", colors.yellow)
            status = "Recalled"
            sendStatus()
            return false
        end

        -- Send status every 5 blocks
        if i % 5 == 0 then
            sendStatus()
        end

        -- Check fuel
        if not checkFuel() then
            print("Out of fuel! Returning home.")
            status = "Out of fuel"
            sendStatus()
            returnHome()
            depositToChest()
            return false
        end

        -- Check if coal is running low
        if isCoalLow() then
            print("Low on coal (" .. countCoal() .. ")! Returning for more...")
            status = "Getting coal"
            sendStatus()
            returnHome()
            depositToChest()

            if isCoalLow() then
                print("Still low on coal! Add coal to chest.")
                status = "Need coal!"
                sendStatus()
                return false
            end

            -- Return to where we were (approximately - go to start of current branch)
            print("Got coal, continuing...")
            status = "Returning"
            sendStatus()
        end

        -- Drop junk every 5 blocks
        if i % 5 == 0 then
            dropJunk()
        end

        -- Check inventory
        if isInventoryFull() then
            print("Inventory full! Returning to deposit...")
            status = "Depositing"
            sendStatus()
            returnHome()
            depositToChest()
            dropJunk()

            if isInventoryFull() then
                print("Chest might be full! Stopping.")
                status = "Chest full!"
                sendStatus()
                return false
            end

            print("Continuing mining...")
            status = "Returning"
            sendStatus()
        end

        -- Dig forward (main tunnel)
        digForward()
        if not forward() then
            print("Cannot move forward! Obstacle?")
            status = "Blocked!"
            sendStatus()
            returnHome()
            depositToChest()
            return false
        end

        -- Dig up for 2-high tunnel
        turtle.digUp()

        -- SAFE ore checking - just dig, don't move into veins
        -- This prevents turtle from getting lost

        -- Check and dig at BOTTOM level
        if isTargetOre(turtle.inspectDown) then
            colorPrint("+ Ore below!", colors.cyan)
            turtle.digDown()
            oresFound = oresFound + 1
        end

        turnLeft()
        if isTargetOre(turtle.inspect) then
            colorPrint("+ Ore left!", colors.cyan)
            turtle.dig()
            oresFound = oresFound + 1
        end

        turnRight()
        turnRight()
        if isTargetOre(turtle.inspect) then
            colorPrint("+ Ore right!", colors.cyan)
            turtle.dig()
            oresFound = oresFound + 1
        end
        turnLeft()

        -- Go UP to check TOP level
        if up() then
            -- Check ceiling
            if isTargetOre(turtle.inspectUp) then
                colorPrint("+ Ore ceiling!", colors.cyan)
                turtle.digUp()
                oresFound = oresFound + 1
            end

            -- Check left at top
            turnLeft()
            if isTargetOre(turtle.inspect) then
                colorPrint("+ Ore left (top)!", colors.cyan)
                turtle.dig()
                oresFound = oresFound + 1
            end

            -- Check right at top
            turnRight()
            turnRight()
            if isTargetOre(turtle.inspect) then
                colorPrint("+ Ore right (top)!", colors.cyan)
                turtle.dig()
                oresFound = oresFound + 1
            end
            turnLeft()

            -- Go back down
            down()
        end

        -- Progress update every 10 blocks
        if i % 10 == 0 then
            if isAdvanced then
                setColor(colors.white)
                term.write("Branch " .. branchCount .. " | ")
                setColor(colors.yellow)
                term.write(i .. "/" .. TUNNEL_LENGTH)
                setColor(colors.white)
                term.write(" | Fuel: ")
                setColor(colors.lime)
                print(turtle.getFuelLevel())
                resetColors()
            else
                print("Branch " .. branchCount .. " | " .. i .. "/" .. TUNNEL_LENGTH .. " | Fuel: " .. turtle.getFuelLevel())
            end
        end

        -- Update status bar
        drawStatusBar()
    end

    return true
end

-- ============== MAIN MINING FUNCTION ==============
local function mine()
    term.clear()
    term.setCursorPos(1, 1)

    if isAdvanced then
        colorPrint("=== ADVANCED ORE MINER ===", colors.yellow)
        colorPrint("ID: " .. os.getComputerID() .. " | " .. TURTLE_NAME, colors.lime)
        colorPrint("Max fuel capacity: " .. MAX_FUEL, colors.cyan)
    else
        print("=== Selective Ore Miner ===")
        print("ID: " .. os.getComputerID() .. " | Name: " .. TURTLE_NAME)
    end

    print("Tunnel length: " .. TUNNEL_LENGTH)
    print("Branch spacing: " .. BRANCH_SPACING)
    print("Starting fuel: " .. turtle.getFuelLevel())

    if hasWireless then
        colorPrint("Wireless: ENABLED", colors.lime)
    else
        colorPrint("Wireless: DISABLED", colors.orange)
    end

    print("")
    print("TIP: Place a chest BEHIND the turtle")
    print("")

    status = "Starting"
    sendStatus()

    -- Simple pattern:
    -- 1. Mine 64 blocks forward
    -- 2. Return home
    -- 3. Deposit
    -- 4. Move left 5 blocks
    -- 5. Repeat

    while branchCount < 20 do  -- Max 20 branches
        branchCount = branchCount + 1
        colorPrint("=== Branch #" .. branchCount .. " ===", colors.yellow)

        -- Mine the tunnel
        if not mineTunnel() then
            break  -- Something went wrong, stop
        end

        -- Return home
        print("Returning to base...")
        status = "Returning"
        sendStatus()
        returnHome()

        -- Deposit items
        print("Depositing...")
        status = "Depositing"
        sendStatus()
        depositToChest()

        -- Check fuel
        if turtle.getFuelLevel() < MIN_FUEL * 2 then
            print("Low on fuel, stopping.")
            status = "Low fuel"
            sendStatus()
            break
        end

        -- Move to next branch (5 blocks left)
        if not moveToNextBranch() then
            print("Cannot start next branch!")
            break
        end

        print("")
    end

    if isAdvanced then
        colorPrint("=== MINING COMPLETE ===", colors.yellow)
        colorPrint("Total branches: " .. branchCount, colors.yellow)
        colorPrint("Total ores found: " .. oresFound, colors.cyan)
        colorPrint("Final fuel: " .. turtle.getFuelLevel() .. "/" .. MAX_FUEL, colors.lime)
    else
        print("=== Mining session complete! ===")
        print("Total branches: " .. branchCount)
        print("Total ores found: " .. oresFound)
    end

    status = "Complete"
    sendStatus()
    drawStatusBar()
end

-- ============== RUN ==============
if hasWireless then
    parallel.waitForAny(mine, recallListener)
else
    mine()
end
