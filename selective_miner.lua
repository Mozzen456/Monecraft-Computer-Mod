-- Selective Area Miner for ComputerCraft / CC:Tweaked
-- Clears a 50x50x3 area, drops junk, keeps valuables
-- Reports status to monitor, returns home when done
-- Start at BOTTOM RIGHT corner, turtle mines forward and LEFT

-- ============== CONFIGURATION ==============
local LENGTH = 50      -- X direction (forward)
local WIDTH = 50       -- Z direction (left from start)
local HEIGHT = 3       -- Y direction (up)
local CHANNEL = 100    -- Wireless channel (must match monitor)

-- Keywords that indicate a block is an ore (NEVER drop these)
local ORE_KEYWORDS = {
    "ore",
    "debris",    -- ancient debris
    "cluster",   -- amethyst clusters, mod clusters
    "diamond",
    "emerald",
    "gold",
    "iron",
    "copper",
    "coal",
    "lapis",
    "redstone",
    "quartz",
}

-- Junk items to DROP (specific items)
local JUNK_ITEMS = {
    -- Stone types
    ["minecraft:cobblestone"] = true,
    ["minecraft:stone"] = true,
    ["minecraft:smooth_stone"] = true,
    ["minecraft:andesite"] = true,
    ["minecraft:diorite"] = true,
    ["minecraft:granite"] = true,
    ["minecraft:tuff"] = true,
    ["minecraft:calcite"] = true,
    ["minecraft:smooth_basalt"] = true,
    ["minecraft:basalt"] = true,
    ["minecraft:blackstone"] = true,
    -- Deepslate types (all variants)
    ["minecraft:deepslate"] = true,
    ["minecraft:cobbled_deepslate"] = true,
    ["minecraft:polished_deepslate"] = true,
    ["minecraft:deepslate_bricks"] = true,
    ["minecraft:cracked_deepslate_bricks"] = true,
    ["minecraft:deepslate_tiles"] = true,
    ["minecraft:cracked_deepslate_tiles"] = true,
    ["minecraft:chiseled_deepslate"] = true,
    ["minecraft:infested_deepslate"] = true,
    -- Dirt types
    ["minecraft:dirt"] = true,
    ["minecraft:coarse_dirt"] = true,
    ["minecraft:rooted_dirt"] = true,
    ["minecraft:gravel"] = true,
    ["minecraft:sand"] = true,
    ["minecraft:red_sand"] = true,
    ["minecraft:clay"] = true,
    ["minecraft:mud"] = true,
    ["minecraft:soul_sand"] = true,
    ["minecraft:soul_soil"] = true,
    ["minecraft:netherrack"] = true,
    -- Other common junk
    ["minecraft:flint"] = true,
    ["minecraft:mossy_cobblestone"] = true,
    ["minecraft:mossy_stone_bricks"] = true,
    ["minecraft:stone_bricks"] = true,
    ["minecraft:cracked_stone_bricks"] = true,
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

-- ============== STATE VARIABLES ==============
local posX, posY, posZ = 0, 0, 0
local facing = 0  -- 0=forward(+X), 1=right(+Z), 2=back(-X), 3=left(-Z)
local startFacing = 0

local status = "Starting"
local recalled = false
local itemsKept = 0
local blocksCleared = 0
local totalBlocks = LENGTH * WIDTH * HEIGHT

-- ============== FORWARD DECLARATIONS ==============
-- (Functions used before they're defined)
local returnHome
local depositItems
local goToPosition
local isInventoryFull
local depositAndReturn

-- ============== WIRELESS SETUP ==============
local modem = peripheral.find("modem")
if modem then
    modem.open(CHANNEL)
    print("Wireless modem found on channel " .. CHANNEL)
else
    print("No modem found - running without wireless")
end

local TURTLE_ID = os.getComputerID()
local TURTLE_NAME = os.getComputerLabel() or ("Miner-" .. TURTLE_ID)

-- ============== STATUS REPORTING ==============
local function sendStatus()
    if not modem then return end

    local progress = blocksCleared
    local maxProgress = totalBlocks

    local message = {
        type = "miner_status",
        id = TURTLE_ID,
        name = TURTLE_NAME,
        status = status,
        progress = progress,
        maxProgress = maxProgress,
        trip = 1,
        fuel = turtle.getFuelLevel(),
        coal = 0,
        ores = itemsKept,
        posX = posX,
        posY = posY,
        posZ = posZ
    }

    modem.transmit(CHANNEL, CHANNEL, message)
end

local function setStatus(newStatus)
    status = newStatus
    print(status .. " | Pos: " .. posX .. "," .. posY .. "," .. posZ .. " | Fuel: " .. turtle.getFuelLevel())
    sendStatus()
end

-- ============== INVENTORY MANAGEMENT ==============
local function isJunk(itemName)
    -- First check exact match in junk table
    if JUNK_ITEMS[itemName] then
        return true
    end

    local name = string.lower(itemName)

    -- Check if it's an ore (NEVER drop ores)
    for _, keyword in ipairs(ORE_KEYWORDS) do
        if string.find(name, keyword) then
            return false
        end
    end

    -- Check if it matches junk keywords (for mod support)
    for _, keyword in ipairs(JUNK_KEYWORDS) do
        if string.find(name, keyword) then
            return true
        end
    end

    -- If unsure, keep it
    return false
end

local function dropJunk()
    local droppedSlots = 0
    itemsKept = 0  -- Reset count

    for slot = 1, 16 do
        local item = turtle.getItemDetail(slot)
        if item then
            if isJunk(item.name) then
                turtle.select(slot)
                local dropped = turtle.dropDown()  -- Drop DOWN so items fall below
                if dropped then
                    droppedSlots = droppedSlots + 1
                end
            else
                itemsKept = itemsKept + item.count
            end
        end
    end

    turtle.select(1)

    if droppedSlots > 0 then
        print("Dropped junk from " .. droppedSlots .. " slots")
    end
end

-- ============== FUEL MANAGEMENT ==============
local function refuelIfNeeded()
    local MIN_FUEL = 500

    if turtle.getFuelLevel() == "unlimited" then
        return true
    end

    if turtle.getFuelLevel() < MIN_FUEL then
        -- Look for coal/charcoal in inventory
        for slot = 1, 16 do
            local item = turtle.getItemDetail(slot)
            if item and (item.name == "minecraft:coal" or item.name == "minecraft:charcoal") then
                turtle.select(slot)
                turtle.refuel(16)  -- Use up to 16 coal
                print("Refueled! Fuel: " .. turtle.getFuelLevel())
                turtle.select(1)
                return true
            end
        end
        print("WARNING: Low fuel and no coal!")
        return false
    end
    return true
end

local function getInventoryCount()
    local count = 0
    for slot = 1, 16 do
        if turtle.getItemCount(slot) > 0 then
            count = count + 1
        end
    end
    return count
end

-- ============== MOVEMENT FUNCTIONS ==============
local function forward()
    -- Keep trying until we move
    while not turtle.forward() do
        -- Dig and wait for falling gravel/sand
        while turtle.detect() do
            turtle.dig()
            sleep(0.15)
        end
        turtle.attack()
        sleep(0.05)
    end
    -- Clear any gravel that fell from above
    while turtle.detectUp() do
        turtle.digUp()
        sleep(0.15)
    end

    if facing == 0 then posX = posX + 1
    elseif facing == 1 then posZ = posZ + 1
    elseif facing == 2 then posX = posX - 1
    elseif facing == 3 then posZ = posZ - 1
    end
end

local function back()
    while not turtle.back() do
        -- Turn around to dig
        turtle.turnLeft()
        turtle.turnLeft()
        while turtle.detect() do
            turtle.dig()
            sleep(0.15)
        end
        turtle.attack()
        turtle.turnLeft()
        turtle.turnLeft()
        sleep(0.05)
    end

    if facing == 0 then posX = posX - 1
    elseif facing == 1 then posZ = posZ - 1
    elseif facing == 2 then posX = posX + 1
    elseif facing == 3 then posZ = posZ + 1
    end
end

local function up()
    while not turtle.up() do
        -- Dig and wait for falling gravel/sand
        while turtle.detectUp() do
            turtle.digUp()
            sleep(0.15)
        end
        turtle.attackUp()
        sleep(0.05)
    end
    posY = posY + 1
end

local function down()
    while not turtle.down() do
        while turtle.detectDown() do
            turtle.digDown()
            sleep(0.05)
        end
        turtle.attackDown()
        sleep(0.05)
    end
    posY = posY - 1
end

local function turnLeft()
    turtle.turnLeft()
    facing = (facing - 1) % 4
end

local function turnRight()
    turtle.turnRight()
    facing = (facing + 1) % 4
end

local function turnToFace(targetFacing)
    while facing ~= targetFacing do
        turnRight()
    end
end

-- ============== MINING FUNCTIONS ==============
local function digColumn()
    -- Dig all blocks in current column (3 high)
    -- Handle falling gravel/sand by digging until clear

    -- Dig forward
    while turtle.detect() do
        turtle.dig()
        sleep(0.15)
    end

    -- Dig up (keep digging while gravel falls)
    while turtle.detectUp() do
        turtle.digUp()
        sleep(0.15)
    end

    -- Dig down
    while turtle.detectDown() do
        turtle.digDown()
        sleep(0.05)
    end

    blocksCleared = blocksCleared + 3
end

local function clearRow()
    for x = 1, LENGTH do
        digColumn()
        if x < LENGTH and not recalled then
            forward()
            blocksCleared = blocksCleared + 1
        end

        -- Drop junk every 5 blocks to keep inventory clear
        if x % 5 == 0 then
            dropJunk()
            refuelIfNeeded()

            -- Check if inventory is still full after dropping junk
            if isInventoryFull() then
                depositAndReturn()
            end
        end

        -- Update status every 10 blocks
        if x % 10 == 0 then
            sendStatus()
        end

        if recalled then return end
    end

    -- Drop at end of each row
    dropJunk()

    -- Check again at end of row
    if isInventoryFull() then
        depositAndReturn()
    end
end

local function clearLayer()
    for z = 1, WIDTH do
        setStatus("Clearing row " .. z .. "/" .. WIDTH)
        clearRow()

        if recalled then return end

        if z < WIDTH then
            -- Move to next row (serpentine pattern - going LEFT from start)
            if z % 2 == 1 then
                -- At end of forward row, turn left
                turnLeft()
                digColumn()
                forward()
                blocksCleared = blocksCleared + 1
                turnLeft()
            else
                -- At end of backward row, turn right
                turnRight()
                digColumn()
                forward()
                blocksCleared = blocksCleared + 1
                turnRight()
            end
        end
    end
end

-- ============== RETURN HOME ==============
returnHome = function()
    setStatus("Returning home")

    -- First, go down to Y=0
    while posY > 0 do
        down()
    end
    while posY < 0 do
        up()
    end

    -- Face toward X=0 (facing 2 = back = -X direction)
    if posX > 0 then
        turnToFace(2)
        while posX > 0 do
            forward()
        end
    elseif posX < 0 then
        turnToFace(0)
        while posX < 0 do
            forward()
        end
    end

    -- Face toward Z=0 (facing 3 = left = -Z direction)
    if posZ > 0 then
        turnToFace(3)
        while posZ > 0 do
            forward()
        end
    elseif posZ < 0 then
        turnToFace(1)
        while posZ < 0 do
            forward()
        end
    end

    -- Face original direction
    turnToFace(startFacing)

    setStatus("Home")
end

depositItems = function()
    setStatus("Depositing items")

    -- Turn to face chest (behind starting position)
    turnLeft()
    turnLeft()

    -- Drop all items into chest (keep some coal for fuel)
    for slot = 1, 16 do
        local item = turtle.getItemDetail(slot)
        if item then
            -- Keep some coal for refueling
            if item.name == "minecraft:coal" or item.name == "minecraft:charcoal" then
                if item.count > 32 then
                    turtle.select(slot)
                    turtle.drop(item.count - 32)  -- Keep 32 coal
                end
            else
                turtle.select(slot)
                if not turtle.drop() then
                    print("Chest full or missing!")
                end
            end
        end
    end

    turtle.select(1)

    -- Turn back to face original direction
    turnLeft()
    turnLeft()
end

goToPosition = function(targetX, targetY, targetZ, targetFacing)
    -- Go to Y level first
    while posY < targetY do
        up()
    end
    while posY > targetY do
        down()
    end

    -- Go to X position
    if posX < targetX then
        turnToFace(0)  -- Face +X
        while posX < targetX do
            forward()
        end
    elseif posX > targetX then
        turnToFace(2)  -- Face -X
        while posX > targetX do
            forward()
        end
    end

    -- Go to Z position
    if posZ < targetZ then
        turnToFace(1)  -- Face +Z
        while posZ < targetZ do
            forward()
        end
    elseif posZ > targetZ then
        turnToFace(3)  -- Face -Z
        while posZ > targetZ do
            forward()
        end
    end

    -- Face the right direction
    turnToFace(targetFacing)
end

isInventoryFull = function()
    for slot = 1, 16 do
        if turtle.getItemCount(slot) == 0 then
            return false
        end
    end
    return true
end

depositAndReturn = function()
    -- Save current position
    local savedX = posX
    local savedY = posY
    local savedZ = posZ
    local savedFacing = facing

    print("Inventory full! Returning to deposit...")
    setStatus("Depositing")

    -- Return home
    returnHome()

    -- Deposit items
    depositItems()

    -- Return to saved position
    print("Returning to mining position...")
    setStatus("Returning to mine")
    goToPosition(savedX, savedY, savedZ, savedFacing)

    print("Resuming mining!")
    setStatus("Mining")
end

-- ============== RECALL LISTENER ==============
local function listenForRecall()
    if not modem then return end

    while true do
        local event, side, channel, replyChannel, message = os.pullEvent("modem_message")

        if channel == CHANNEL and type(message) == "table" then
            if message.type == "recall" then
                print(">>> RECALL ALL RECEIVED <<<")
                recalled = true
                return
            elseif message.type == "recall_id" and message.id == TURTLE_ID then
                print(">>> RECALL FOR ME RECEIVED <<<")
                recalled = true
                return
            end
        end
    end
end

-- ============== BACKGROUND STATUS SENDER ==============
local function statusLoop()
    while true do
        sendStatus()
        sleep(5)  -- Send status every 5 seconds
    end
end

-- ============== MAIN PROGRAM ==============
local function mainMining()
    -- ALWAYS reset position to 0,0,0 at start
    posX, posY, posZ = 0, 0, 0
    facing = 0
    blocksCleared = 0
    itemsKept = 0
    recalled = false

    print("=================================")
    print("  SELECTIVE AREA MINER")
    print("  Area: " .. LENGTH .. "x" .. WIDTH .. "x" .. HEIGHT)
    print("  Total blocks: " .. totalBlocks)
    print("  Turtle ID: " .. TURTLE_ID)
    print("  Name: " .. TURTLE_NAME)
    print("=================================")
    print("")
    print("POSITION CHECK:")
    print("  - Turtle at BOTTOM RIGHT corner?")
    print("  - Chest BEHIND turtle?")
    print("  - Turtle facing INTO the area?")
    print("")

    -- Check fuel
    local neededFuel = LENGTH * WIDTH * HEIGHT * 2
    local currentFuel = turtle.getFuelLevel()
    print("Fuel: " .. currentFuel .. " (need ~" .. neededFuel .. ")")

    if currentFuel < neededFuel then
        print("WARNING: Low fuel! May not complete job.")
    end

    print("")
    print("Press ENTER to start...")
    print("(CTRL+T to cancel)")
    read()

    print("GO!")

    -- Go up 1 to be in middle of 3-high area (dig up/down from there)
    setStatus("Moving to start height")
    up()

    -- Clear the area
    setStatus("Mining started")
    clearLayer()

    -- Final junk drop before heading home
    dropJunk()

    if recalled then
        setStatus("Recalled")
    else
        setStatus("Excavation complete")
    end

    -- Return home
    returnHome()

    -- Deposit items in chest
    depositItems()

    if recalled then
        setStatus("Recalled - Parked")
    else
        setStatus("Complete")
    end

    print("=================================")
    print("  JOB COMPLETE!")
    print("  Blocks cleared: " .. blocksCleared)
    print("  Items kept: " .. itemsKept)
    print("  Fuel remaining: " .. turtle.getFuelLevel())
    print("=================================")

    -- Keep sending status so monitor knows we're done
    while true do
        sendStatus()
        sleep(10)
    end
end

-- ============== RUN ==============
if modem then
    parallel.waitForAny(mainMining, listenForRecall, statusLoop)
else
    mainMining()
end
