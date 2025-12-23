-- Mining Monitor for ComputerCraft / CC:Tweaked
-- Displays status of up to 9 mining turtles
-- With RECALL functionality
-- by Claude

-- ============== CONFIGURATION ==============
local CHANNEL = 100           -- Must match turtle channel
local TIMEOUT = 30            -- Seconds before marking miner as offline

-- ============== SETUP ==============
-- Find modem
local modem = peripheral.find("modem")
if not modem then
    error("No modem found! Attach a wireless modem.")
end

if not modem.isWireless() then
    error("Need a wireless modem, not wired!")
end

modem.open(CHANNEL)

-- Find monitor
local monitor = peripheral.find("monitor")
if not monitor then
    print("No monitor found - using terminal")
    monitor = term
end

-- Set up monitor
monitor.setTextScale(0.5)
monitor.clear()

local width, height = monitor.getSize()
print("Monitor size: " .. width .. "x" .. height)
print("Listening on channel " .. CHANNEL)

-- ============== MINER DATA ==============
local miners = {}  -- Stores data for each miner

-- ============== RECALL FUNCTIONS ==============
local function recallAll()
    print(">>> RECALLING ALL TURTLES <<<")
    modem.transmit(CHANNEL, CHANNEL, {type = "recall"})
end

local function recallOne(id)
    print(">>> RECALLING TURTLE ID: " .. id .. " <<<")
    modem.transmit(CHANNEL, CHANNEL, {type = "recall_id", id = id})
end

-- ============== COLORS ==============
local function setColors(bg, fg)
    if monitor.isColor and monitor.isColor() then
        monitor.setBackgroundColor(bg)
        monitor.setTextColor(fg)
    end
end

local function getStatusColor(status)
    if not monitor.isColor or not monitor.isColor() then
        return colors.white
    end

    if status == "Mining" then
        return colors.lime
    elseif status == "Depositing" or status == "Returning" then
        return colors.yellow
    elseif status == "Complete" or status == "Recalled" then
        return colors.cyan
    elseif status == "Getting coal" or status == "Need coal!" or status == "Low fuel" or status == "Out of fuel" then
        return colors.orange
    elseif status == "Blocked!" or status == "Chest full!" then
        return colors.red
    elseif status == "Offline" then
        return colors.gray
    else
        return colors.white
    end
end

-- ============== DRAWING ==============
local function drawBox(x, y, w, h, title)
    setColors(colors.gray, colors.white)

    -- Top border
    monitor.setCursorPos(x, y)
    monitor.write("+" .. string.rep("-", w - 2) .. "+")

    -- Title
    if title then
        monitor.setCursorPos(x + 2, y)
        setColors(colors.gray, colors.yellow)
        monitor.write(" " .. title .. " ")
    end

    -- Sides
    for i = 1, h - 2 do
        monitor.setCursorPos(x, y + i)
        setColors(colors.gray, colors.white)
        monitor.write("|")
        monitor.setCursorPos(x + w - 1, y + i)
        monitor.write("|")
    end

    -- Bottom border
    monitor.setCursorPos(x, y + h - 1)
    monitor.write("+" .. string.rep("-", w - 2) .. "+")

    -- Clear inside
    setColors(colors.black, colors.white)
    for i = 1, h - 2 do
        monitor.setCursorPos(x + 1, y + i)
        monitor.write(string.rep(" ", w - 2))
    end
end

local function drawMiner(index, x, y, w, h)
    local miner = miners[index]

    -- Draw box
    local title = miner and miner.name or ("Miner " .. index)
    drawBox(x, y, w, h, title)

    -- Content area starts at x+2, y+1
    local cx = x + 2
    local cy = y + 1

    if not miner then
        setColors(colors.black, colors.gray)
        monitor.setCursorPos(cx, cy + 1)
        monitor.write("Waiting...")
        return
    end

    -- Check if offline
    local age = os.clock() - (miner.lastSeen or 0)
    if age > TIMEOUT then
        miner.status = "Offline"
    end

    -- Status
    setColors(colors.black, getStatusColor(miner.status))
    monitor.setCursorPos(cx, cy)
    monitor.write(miner.status or "Unknown")

    -- Progress bar
    setColors(colors.black, colors.white)
    monitor.setCursorPos(cx, cy + 1)
    local progress = miner.progress or 0
    local maxProgress = miner.maxProgress or 100
    local pct = math.floor((progress / maxProgress) * 100)
    local barWidth = w - 6
    local filled = math.floor((progress / maxProgress) * barWidth)

    if monitor.isColor and monitor.isColor() then
        monitor.setBackgroundColor(colors.gray)
        monitor.write(string.rep(" ", barWidth))
        monitor.setCursorPos(cx, cy + 1)
        monitor.setBackgroundColor(colors.green)
        monitor.write(string.rep(" ", filled))
        monitor.setBackgroundColor(colors.black)
    end
    monitor.setCursorPos(cx + barWidth + 1, cy + 1)
    monitor.write(pct .. "%")

    -- Trip info
    setColors(colors.black, colors.white)
    monitor.setCursorPos(cx, cy + 2)
    monitor.write("Trip: " .. (miner.trip or 0))

    -- Fuel
    monitor.setCursorPos(cx, cy + 3)
    local fuel = miner.fuel or 0
    if fuel < 200 then
        setColors(colors.black, colors.red)
    elseif fuel < 500 then
        setColors(colors.black, colors.orange)
    else
        setColors(colors.black, colors.lime)
    end
    monitor.write("Fuel: " .. fuel)

    -- Coal
    setColors(colors.black, colors.white)
    monitor.setCursorPos(cx, cy + 4)
    local coal = miner.coal or 0
    if coal < 10 then
        setColors(colors.black, colors.red)
    elseif coal < 32 then
        setColors(colors.black, colors.orange)
    else
        setColors(colors.black, colors.white)
    end
    monitor.write("Coal: " .. coal)

    -- Ores found
    setColors(colors.black, colors.cyan)
    monitor.setCursorPos(cx, cy + 5)
    monitor.write("Ores: " .. (miner.ores or 0))

    -- Position (if room)
    if h > 8 then
        setColors(colors.black, colors.lightGray)
        monitor.setCursorPos(cx, cy + 6)
        monitor.write("Z:" .. (miner.posZ or 0))
    end
end

-- Recall button position
local recallButtonX = 1
local recallButtonY = 2
local recallButtonW = 14
local recallButtonH = 1

local function drawRecallButton()
    -- Draw RECALL ALL button
    setColors(colors.red, colors.white)
    monitor.setCursorPos(recallButtonX, recallButtonY)
    monitor.write(" RECALL ALL  ")

    setColors(colors.black, colors.white)
end

local function drawScreen()
    monitor.clear()

    -- Title
    setColors(colors.black, colors.yellow)
    monitor.setCursorPos(1, 1)
    monitor.write("=== MINING CONTROL CENTER ===")

    -- Draw recall button
    drawRecallButton()

    -- Calculate grid layout for 9 miners (3x3)
    local boxWidth = math.floor((width - 4) / 3)
    local boxHeight = math.floor((height - 4) / 3)

    -- Draw each miner slot
    local minerIndex = 1
    for row = 0, 2 do
        for col = 0, 2 do
            local x = 2 + col * (boxWidth + 1)
            local y = 4 + row * (boxHeight)
            drawMiner(minerIndex, x, y, boxWidth, boxHeight)
            minerIndex = minerIndex + 1
        end
    end

    -- Footer
    setColors(colors.black, colors.gray)
    monitor.setCursorPos(1, height)
    monitor.write("Channel: " .. CHANNEL .. " | Miners: " .. countMiners() .. " | Click miner to recall")
end

function countMiners()
    local count = 0
    for _, miner in pairs(miners) do
        local age = os.clock() - (miner.lastSeen or 0)
        if age <= TIMEOUT then
            count = count + 1
        end
    end
    return count
end

-- Get miner index from touch coordinates
local function getMinerAtPos(touchX, touchY)
    local boxWidth = math.floor((width - 4) / 3)
    local boxHeight = math.floor((height - 4) / 3)

    for index = 1, 9 do
        local row = math.floor((index - 1) / 3)
        local col = (index - 1) % 3
        local x = 2 + col * (boxWidth + 1)
        local y = 4 + row * (boxHeight)

        if touchX >= x and touchX < x + boxWidth and
           touchY >= y and touchY < y + boxHeight then
            return index
        end
    end
    return nil
end

-- ============== MAIN LOOPS ==============
local function receiverLoop()
    while true do
        local event, side, channel, replyChannel, message, distance = os.pullEvent("modem_message")

        if channel == CHANNEL and type(message) == "table" and message.type == "miner_status" then
            -- Find slot for this miner (by ID)
            local slot = nil
            local emptySlot = nil

            -- First, look for existing slot with this ID
            for i = 1, 9 do
                if miners[i] and miners[i].id == message.id then
                    slot = i
                    break
                elseif not miners[i] and not emptySlot then
                    emptySlot = i
                end
            end

            -- If not found, use empty slot
            if not slot then
                slot = emptySlot
            end

            if slot then
                message.lastSeen = os.clock()
                miners[slot] = message
                print("Updated: " .. message.name .. " (slot " .. slot .. ")")
            else
                print("No slot available for " .. message.name)
            end
        end
    end
end

local function drawLoop()
    while true do
        drawScreen()
        sleep(1)
    end
end

local function touchLoop()
    while true do
        local event, side, x, y = os.pullEvent("monitor_touch")

        -- Check if RECALL ALL button pressed
        if x >= recallButtonX and x < recallButtonX + recallButtonW and
           y == recallButtonY then
            print("RECALL ALL button pressed!")
            recallAll()

            -- Flash button
            setColors(colors.lime, colors.black)
            monitor.setCursorPos(recallButtonX, recallButtonY)
            monitor.write(" RECALLING!  ")
            sleep(0.5)
        else
            -- Check if a miner box was clicked
            local minerIndex = getMinerAtPos(x, y)
            if minerIndex and miners[minerIndex] then
                local miner = miners[minerIndex]
                print("Recalling miner: " .. miner.name .. " (ID: " .. miner.id .. ")")
                recallOne(miner.id)
            end
        end
    end
end

local function keyboardLoop()
    while true do
        local event, key = os.pullEvent("key")

        -- R key = Recall all
        if key == keys.r then
            print("R pressed - RECALL ALL!")
            recallAll()
        -- 1-9 = Recall specific miner
        elseif key >= keys.one and key <= keys.nine then
            local slot = key - keys.one + 1
            if miners[slot] then
                print("Recalling miner slot " .. slot)
                recallOne(miners[slot].id)
            end
        end
    end
end

-- ============== RUN ==============
print("Starting Mining Monitor...")
print("Waiting for miner updates...")
print("")
print("Controls:")
print("  - Click 'RECALL ALL' on monitor")
print("  - Click a miner box to recall that one")
print("  - Press R key to recall all")
print("  - Press 1-9 to recall specific miner")
print("")

parallel.waitForAny(receiverLoop, drawLoop, touchLoop, keyboardLoop)
