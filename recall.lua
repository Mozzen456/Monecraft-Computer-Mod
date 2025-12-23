-- Simple Recall Script for ComputerCraft / CC:Tweaked
-- Recalls all mining turtles or a specific one
-- by Claude
--
-- Usage:
--   recall        - Recalls ALL turtles
--   recall 5      - Recalls turtle with ID 5

local CHANNEL = 100

-- Find modem
local modem = peripheral.find("modem")
if not modem then
    error("No modem found! Attach a wireless modem.")
end

if not modem.isWireless() then
    error("Need a wireless modem, not wired!")
end

modem.open(CHANNEL)

-- Get command line argument
local args = {...}
local targetId = tonumber(args[1])

if targetId then
    -- Recall specific turtle
    print("Recalling turtle ID: " .. targetId)
    modem.transmit(CHANNEL, CHANNEL, {type = "recall_id", id = targetId})
    print("Recall command sent!")
else
    -- Recall all turtles
    print("Recalling ALL turtles!")
    modem.transmit(CHANNEL, CHANNEL, {type = "recall"})
    print("Recall command sent to all turtles!")
end

print("")
print("Turtles will return to their home positions.")
