-- Startup file for Inventory Management Computer
-- Automatically runs the inventory server when computer boots
--
-- To install on your inventory computer:
--   1. Copy inventory_server.lua to the computer
--   2. Rename this file to "startup" (no extension)
--   3. Computer will auto-run on boot

-- Wait for peripherals to initialize
sleep(2)

-- Check if inventory server exists
if fs.exists("inventory_server") or fs.exists("inventory_server.lua") then
    print("Starting Inventory Management System...")
    shell.run("inventory_server")
else
    print("Inventory server not found!")
    print("Please install 'inventory_server.lua'")
end
