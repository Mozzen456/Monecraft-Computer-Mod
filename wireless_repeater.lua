-- Wireless Repeater for ComputerCraft / CC:Tweaked
-- Extends wireless range by relaying messages
-- Place computers with wireless modems every ~50 blocks
-- by Claude

local CHANNEL = 100  -- Must match miner/monitor channel

-- Find modem
local modem = peripheral.find("modem")
if not modem then
    error("No modem found! Attach a wireless modem.")
end

if not modem.isWireless() then
    error("Need a wireless modem, not wired!")
end

modem.open(CHANNEL)

-- Track recently forwarded messages to prevent loops
local recentMessages = {}
local MESSAGE_TIMEOUT = 2  -- Seconds before allowing same message again

-- Generate a simple hash of a message for deduplication
local function messageHash(msg)
    if type(msg) ~= "table" then
        return tostring(msg)
    end

    local parts = {}
    if msg.type then parts[#parts + 1] = msg.type end
    if msg.id then parts[#parts + 1] = tostring(msg.id) end
    if msg.time then parts[#parts + 1] = tostring(msg.time) end
    if msg.status then parts[#parts + 1] = msg.status end
    if msg.progress then parts[#parts + 1] = tostring(msg.progress) end

    return table.concat(parts, "|")
end

-- Check if message was recently forwarded
local function isRecent(hash)
    local now = os.clock()

    -- Clean old entries
    for h, t in pairs(recentMessages) do
        if now - t > MESSAGE_TIMEOUT then
            recentMessages[h] = nil
        end
    end

    return recentMessages[hash] ~= nil
end

-- Mark message as forwarded
local function markForwarded(hash)
    recentMessages[hash] = os.clock()
end

-- Stats
local relayedCount = 0
local startTime = os.clock()

-- Display
local function updateDisplay()
    term.clear()
    term.setCursorPos(1, 1)

    print("=== WIRELESS REPEATER ===")
    print("")
    print("Channel: " .. CHANNEL)
    print("Status: ACTIVE")
    print("")
    print("Messages relayed: " .. relayedCount)
    print("Uptime: " .. math.floor(os.clock() - startTime) .. "s")
    print("")
    print("Place repeaters every ~50 blocks")
    print("to extend wireless range.")
    print("")
    print("Press Q to quit")
end

-- Main relay loop
local function relayLoop()
    while true do
        local event, side, channel, replyChannel, message, distance = os.pullEvent("modem_message")

        if channel == CHANNEL and type(message) == "table" then
            local hash = messageHash(message)

            -- Only forward if not recently seen (prevents loops)
            if not isRecent(hash) then
                markForwarded(hash)

                -- Rebroadcast the message
                modem.transmit(CHANNEL, CHANNEL, message)

                relayedCount = relayedCount + 1

                -- Log what we relayed
                local msgType = message.type or "unknown"
                if message.name then
                    print("Relayed: " .. msgType .. " from " .. message.name)
                else
                    print("Relayed: " .. msgType)
                end
            end
        end
    end
end

-- Display update loop
local function displayLoop()
    while true do
        updateDisplay()
        sleep(5)
    end
end

-- Keyboard loop
local function keyboardLoop()
    while true do
        local event, key = os.pullEvent("key")
        if key == keys.q then
            print("Shutting down repeater...")
            return
        end
    end
end

-- Run
print("Starting Wireless Repeater...")
print("Channel: " .. CHANNEL)
print("")

parallel.waitForAny(relayLoop, displayLoop, keyboardLoop)

print("Repeater stopped.")
