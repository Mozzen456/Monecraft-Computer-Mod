-- Startup file for Mining Turtle
-- Automatically runs selective_miner when turtle boots

-- Wait for peripherals to initialize
sleep(2)

-- Check if miner script exists
if fs.exists("selective_miner") or fs.exists("selective_miner.lua") then
    print("Starting Selective Area Miner...")
    shell.run("selective_miner")
else
    print("selective_miner not found!")
    print("Please install 'selective_miner.lua'")
end
