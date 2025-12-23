-- Startup file for Mining Turtle
-- Automatically runs the miner when turtle boots
-- Put this file on the turtle as "startup" (no .lua)
--
-- To install:
--   1. Save miner as "selective_miner"
--   2. Save this as "startup"
--   3. Turtle will auto-run on boot/chunk load

-- Wait a moment for the world to load
sleep(2)

-- Check if miner exists
if fs.exists("selective_miner") then
    print("Auto-starting miner...")
    shell.run("selective_miner")
else
    print("Miner not found!")
    print("Please install 'selective_miner'")
end
