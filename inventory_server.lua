-- Inventory Management System for CC:Tweaked
-- Touchscreen interface with search, categories, and item retrieval

--============================================
-- CONFIGURATION
--============================================
local OUTPUT_CHEST = "minecraft:chest_20"  -- Set this to your output chest's peripheral name
local INPUT_CHEST = "minecraft:chest_8"   -- Set this to your input/dump chest's peripheral name
local ITEMS_PER_PAGE = 14                  -- Number of items shown per page (legacy, now auto-calculated)
local AUTO_SORT_INTERVAL = 2               -- Seconds between auto-sort checks
local MONITOR_SCALE = 1.0                  -- Text scale: 0.5 (smallest) to 5.0 (largest). For 3x5 monitor try 0.5-1.0
local SCALE_OPTIONS = {0.5, 1.0, 1.5, 2.0} -- Available scale options for the scale button
local currentScaleIndex = 2                -- Index into SCALE_OPTIONS (1.0 by default)

--============================================
-- CATEGORY DEFINITIONS
--============================================
local CATEGORIES = {
    {name = "Tools", keywords = {"pickaxe", "axe", "shovel", "hoe", "hammer", "wrench", "paxel", "drill", "saw", "cutter", "multitool", "excavator", "sickle", "scythe", "shears", "flint_and_steel", "fishing_rod", "tinker", "mattock"}},
    {name = "Weapons", keywords = {"sword", "bow", "crossbow", "trident", "shield", "dagger", "rapier", "katana", "staff", "wand", "gun", "rifle", "blade", "cleaver", "mace", "spear", "halberd", "battleaxe", "launcher"}},
    {name = "Armor", keywords = {"helmet", "chestplate", "leggings", "boots", "cap", "tunic", "pants", "armor", "cuirass", "greaves", "sabatons", "coif", "chainmail", "plate"}},
    {name = "Blocks", keywords = {"stone", "dirt", "grass", "wood", "plank", "log", "brick", "glass", "sand", "gravel", "concrete", "terracotta", "wool", "slab", "stairs", "fence", "wall", "door", "trapdoor", "tile", "panel", "beam", "column", "pillar", "frame", "casing", "hull"}},
    {name = "Food", keywords = {"beef", "pork", "chicken", "mutton", "rabbit", "cod", "salmon", "bread", "apple", "carrot", "potato", "beetroot", "melon", "cookie", "cake", "pie", "stew", "soup", "golden_apple", "cooked", "raw_", "food", "meal", "snack", "fruit", "vegetable", "meat", "fish", "berry", "cheese", "sandwich", "toast", "jerky", "sushi"}},
    {name = "Ores", keywords = {"ore", "raw_iron", "raw_gold", "raw_copper", "ingot", "nugget", "diamond", "emerald", "gold", "iron", "copper", "coal", "lapis", "redstone", "netherite", "amethyst", "tin", "lead", "silver", "nickel", "aluminum", "aluminium", "zinc", "uranium", "titanium", "tungsten", "platinum", "osmium", "iridium", "certus", "quartz", "ruby", "sapphire", "peridot"}},
    {name = "Materials", keywords = {"dust", "gear", "plate", "rod", "wire", "cable", "nugget", "chunk", "shard", "fragment", "essence", "crystal", "gem", "pearl", "alloy", "blend", "compound", "circuit", "chip", "processor", "component", "module", "coil", "casing"}},
    {name = "Machines", keywords = {"machine", "furnace", "generator", "engine", "crusher", "grinder", "pulverizer", "smelter", "centrifuge", "press", "compressor", "extractor", "fabricator", "assembler", "inscriber", "interface", "terminal", "controller", "core", "reactor", "turbine", "solar", "battery", "capacitor", "cell", "tank", "pump", "pipe", "conduit", "duct", "cable", "quarry", "miner", "laser"}},
    {name = "Redstone", keywords = {"repeater", "comparator", "piston", "lever", "button", "pressure_plate", "tripwire", "observer", "dropper", "dispenser", "hopper", "rail", "minecart", "detector", "daylight", "target", "sculk"}},
    {name = "Potions", keywords = {"potion", "splash", "lingering", "tipped_arrow", "bottle", "vial", "flask", "brew", "elixir", "tonic", "philter"}},
    {name = "Magic", keywords = {"enchant", "spell", "rune", "sigil", "scroll", "tome", "grimoire", "ritual", "altar", "mana", "aura", "vis", "thaumcraft", "botania", "ars", "blood_magic", "astral", "totem", "talisman", "amulet", "ring", "bauble", "curio", "charm"}},
    {name = "Plants", keywords = {"seed", "sapling", "flower", "plant", "crop", "wheat", "mushroom", "fungus", "spore", "root", "leaf", "leaves", "vine", "moss", "fern", "bamboo", "cactus", "kelp", "lily", "rose", "tulip", "orchid", "allium", "cornflower", "dandelion", "poppy", "azalea", "dripleaf"}},
    {name = "Mob Drops", keywords = {"bone", "string", "feather", "leather", "hide", "pelt", "fur", "scale", "slime", "ender_pearl", "blaze", "ghast", "phantom", "membrane", "shell", "horn", "tusk", "fang", "tooth", "claw", "skull", "head", "spawn_egg", "egg"}},
    {name = "Deco", keywords = {"banner", "painting", "item_frame", "armor_stand", "pot", "vase", "candle", "lantern", "lamp", "torch", "chandelier", "carpet", "rug", "curtain", "bed", "chair", "table", "shelf", "bookshelf", "sign", "bell", "chain", "lightning_rod", "flower_pot", "decorated"}},
    {name = "Storage", keywords = {"chest", "barrel", "shulker", "crate", "bag", "backpack", "pouch", "sack", "drawer", "cabinet", "locker", "vault", "safe", "strongbox", "bin", "silo"}},
    {name = "Misc", keywords = {}}  -- Catch-all category
}

--============================================
-- COLOR SCHEME
--============================================
local COLORS = {
    bg = colors.black,
    header = colors.blue,
    headerText = colors.white,
    categoryBg = colors.gray,
    categoryActive = colors.lime,
    categoryText = colors.white,
    listBg = colors.black,
    listItem = colors.white,
    listItemAlt = colors.lightGray,
    listHighlight = colors.yellow,
    scrollbar = colors.gray,
    footer = colors.gray,
    footerText = colors.white,
    searchBg = colors.white,
    searchText = colors.black,
    button = colors.cyan,
    buttonText = colors.white,
    success = colors.lime,
    error = colors.red
}

--============================================
-- GLOBAL STATE
--============================================
local monitor = nil
local modem = nil
local storageChests = {}   -- {name -> peripheral}
local outputChest = nil
local inputChest = nil
local itemIndex = {}       -- {itemName -> {displayName, total, locations=[{chest, slot, count}]}}
local filteredItems = {}   -- Current filtered list for display
local currentCategory = "All"
local searchTerm = ""
local currentPage = 1
local totalPages = 1
local monitorWidth, monitorHeight = 0, 0
local isSearching = false
local statusMessage = ""
local statusColor = COLORS.success

-- Forward declaration for functions called before definition
local drawUI

local function cycleScale()
    currentScaleIndex = currentScaleIndex + 1
    if currentScaleIndex > #SCALE_OPTIONS then
        currentScaleIndex = 1
    end
    MONITOR_SCALE = SCALE_OPTIONS[currentScaleIndex]
    monitor.setTextScale(MONITOR_SCALE)
    monitorWidth, monitorHeight = monitor.getSize()
end

--============================================
-- INITIALIZATION
--============================================
local function findPeripherals()
    -- Find monitor
    monitor = peripheral.find("monitor")
    if not monitor then
        error("No monitor found! Please attach an Advanced Monitor.")
    end

    -- Check if monitor supports color (Advanced Monitor)
    if not monitor.isColor() then
        error("Please use an Advanced Monitor for touchscreen support.")
    end

    monitor.setTextScale(MONITOR_SCALE)
    monitorWidth, monitorHeight = monitor.getSize()
    print("Monitor size: " .. monitorWidth .. "x" .. monitorHeight .. " (scale " .. MONITOR_SCALE .. ")")

    -- Find wired modem for network access
    local modemName = nil
    modem = peripheral.find("modem", function(name, wrapped)
        if not wrapped.isWireless() then
            modemName = name
            return true
        end
        return false
    end)

    if not modem then
        print("WARNING: No wired modem found! Only local peripherals will be used.")
    end

    -- Get all inventories (both local and networked)
    local allPeripherals = {}

    -- Add all peripherals (peripheral.getNames includes networked ones in CC:Tweaked)
    for _, name in ipairs(peripheral.getNames()) do
        allPeripherals[name] = true
    end

    -- Also try modem.getNamesRemote if available
    if modem and modem.getNamesRemote then
        local ok, remotes = pcall(function() return modem.getNamesRemote() end)
        if ok and remotes then
            for _, name in ipairs(remotes) do
                allPeripherals[name] = true
            end
        end
    end

    -- Count and list all peripherals found
    local peripheralCount = 0
    print("All peripherals found:")
    for name, _ in pairs(allPeripherals) do
        peripheralCount = peripheralCount + 1
        print("  " .. name)
    end
    print("Total peripherals: " .. peripheralCount)

    print("")
    print("Detecting inventories...")
    for name, _ in pairs(allPeripherals) do
        local hasInventory = false

        -- Try peripheral.hasType first
        local typeOk, typeResult = pcall(function()
            return peripheral.hasType(name, "inventory")
        end)
        if typeOk and typeResult then
            hasInventory = true
        end

        -- Fallback: try to wrap and check for list() method
        if not hasInventory then
            local p = peripheral.wrap(name)
            if p and type(p.list) == "function" then
                hasInventory = true
            end
        end

        if hasInventory then
            if name == OUTPUT_CHEST then
                outputChest = peripheral.wrap(name)
                print("  Output: " .. name)
            elseif name == INPUT_CHEST then
                inputChest = peripheral.wrap(name)
                print("  Input: " .. name)
            else
                storageChests[name] = peripheral.wrap(name)
                print("  Storage: " .. name)
            end
        end
    end

    if not outputChest then
        print("WARNING: Output chest '" .. OUTPUT_CHEST .. "' not found!")
        print("Please check the OUTPUT_CHEST config at the top of the script.")
        print("Available inventories:")
        for name, _ in pairs(storageChests) do
            print("  - " .. name)
        end
    end

    if not inputChest then
        print("WARNING: Input chest '" .. INPUT_CHEST .. "' not found!")
        print("Please check the INPUT_CHEST config at the top of the script.")
    end

    local chestCount = 0
    for _ in pairs(storageChests) do chestCount = chestCount + 1 end
    print("Found " .. chestCount .. " storage chests")
end

--============================================
-- INVENTORY SCANNING
--============================================
local function getCategory(itemName)
    local lowerName = string.lower(itemName)
    for _, cat in ipairs(CATEGORIES) do
        if cat.name ~= "Misc" then
            for _, keyword in ipairs(cat.keywords) do
                if string.find(lowerName, keyword, 1, true) then
                    return cat.name
                end
            end
        end
    end
    return "Misc"
end

local function scanInventory()
    itemIndex = {}
    local totalStacks = 0
    local chestCount = 0
    local uniqueItems = 0

    for chestName, chest in pairs(storageChests) do
        chestCount = chestCount + 1
        local chestStacks = 0
        local success, items = pcall(function() return chest.list() end)
        if success and items then
            for slot, item in pairs(items) do
                totalStacks = totalStacks + 1
                chestStacks = chestStacks + 1
                local detail = nil
                local ok, res = pcall(function() return chest.getItemDetail(slot) end)
                if ok then detail = res end

                local displayName = detail and detail.displayName or item.name
                local key = item.name

                if not itemIndex[key] then
                    itemIndex[key] = {
                        name = item.name,
                        displayName = displayName,
                        total = 0,
                        category = getCategory(item.name),
                        locations = {}
                    }
                    uniqueItems = uniqueItems + 1
                end

                itemIndex[key].total = itemIndex[key].total + item.count
                table.insert(itemIndex[key].locations, {
                    chest = chestName,
                    slot = slot,
                    count = item.count
                })
            end
        end
        if chestStacks > 0 then
            print("  " .. chestName .. ": " .. chestStacks .. " stacks")
        end
    end

    print("Scanned " .. chestCount .. " chests")
    print("Found " .. totalStacks .. " stacks, " .. uniqueItems .. " unique items")
end

local function filterItems()
    filteredItems = {}
    local lowerSearch = string.lower(searchTerm)

    for key, item in pairs(itemIndex) do
        local matchesCategory = (currentCategory == "All") or (item.category == currentCategory)
        local matchesSearch = (searchTerm == "") or
            string.find(string.lower(item.displayName), lowerSearch, 1, true) or
            string.find(string.lower(item.name), lowerSearch, 1, true)

        if matchesCategory and matchesSearch then
            table.insert(filteredItems, item)
        end
    end

    -- Sort by display name
    table.sort(filteredItems, function(a, b)
        return a.displayName < b.displayName
    end)

    -- Calculate pages
    totalPages = math.max(1, math.ceil(#filteredItems / ITEMS_PER_PAGE))
    if currentPage > totalPages then
        currentPage = totalPages
    end
end

--============================================
-- ITEM RETRIEVAL
--============================================
local selectedItem = nil  -- Currently selected item for quantity selection

local function retrieveItem(item, requestedCount)
    if not outputChest then
        statusMessage = "No output chest configured!"
        statusColor = COLORS.error
        return false
    end

    -- No cap - transfer as many as requested (output chest slots will fill naturally)
    local remaining = requestedCount
    local transferred = 0

    for _, loc in ipairs(item.locations) do
        if remaining <= 0 then break end

        local chest = storageChests[loc.chest]
        if chest then
            local moveOk, moved = pcall(function()
                return chest.pushItems(OUTPUT_CHEST, loc.slot, remaining)
            end)
            if moveOk and moved and moved > 0 then
                transferred = transferred + moved
                remaining = remaining - moved
            end
        end
    end

    if transferred > 0 then
        statusMessage = "Sent " .. transferred .. "x " .. item.displayName
        statusColor = COLORS.success
        -- Re-scan to update counts
        scanInventory()
        filterItems()
        return true
    else
        statusMessage = "Failed to transfer items!"
        statusColor = COLORS.error
        return false
    end
end

--============================================
-- AUTO-SORT FROM INPUT CHEST
--============================================
local function findStorageSlot(itemName)
    -- First, try to find existing stacks of the same item
    for chestName, chest in pairs(storageChests) do
        local ok, items = pcall(function() return chest.list() end)
        if ok and items then
            for slot, item in pairs(items) do
                if item.name == itemName then
                    local limitOk, limit = pcall(function() return chest.getItemLimit(slot) end)
                    if not limitOk or not limit then limit = 64 end
                    if item.count < limit then
                        return chestName, slot, limit - item.count
                    end
                end
            end
        end
    end

    -- If no existing stack, find an empty slot
    for chestName, chest in pairs(storageChests) do
        local ok, size = pcall(function() return chest.size() end)
        if ok and size then
            local items = chest.list() or {}
            for slot = 1, size do
                if not items[slot] then
                    return chestName, slot, 64
                end
            end
        end
    end

    return nil, nil, 0
end

local function sortInputChest()
    if not inputChest then return false end

    local ok, items = pcall(function() return inputChest.list() end)
    if not ok or not items then return false end

    local movedAny = false

    for slot, item in pairs(items) do
        -- Try to push to any storage chest - let CC:Tweaked find a valid slot
        local moved = 0
        for chestName, chest in pairs(storageChests) do
            if moved == 0 or moved < item.count then
                local moveOk, result = pcall(function()
                    -- Don't specify target slot - let it find available space automatically
                    return inputChest.pushItems(chestName, slot)
                end)
                if moveOk and result and result > 0 then
                    moved = moved + result
                    movedAny = true
                end
            end
        end
    end

    return movedAny
end

local function autoSortLoop()
    while true do
        sleep(AUTO_SORT_INTERVAL)
        local moved = sortInputChest()
        if moved then
            -- Refresh inventory display
            scanInventory()
            filterItems()
            drawUI()
        end
    end
end

--============================================
-- UI DRAWING
--============================================
local function drawHeader()
    monitor.setBackgroundColor(COLORS.header)
    monitor.setTextColor(COLORS.headerText)

    -- Header bar
    monitor.setCursorPos(1, 1)
    monitor.clearLine()
    monitor.setCursorPos(2, 1)
    monitor.write("INVENTORY SYSTEM")

    -- Scale button
    monitor.setBackgroundColor(COLORS.button)
    monitor.setTextColor(COLORS.buttonText)
    monitor.setCursorPos(monitorWidth - 22, 1)
    monitor.write(" " .. MONITOR_SCALE .. "x ")

    -- Item count on header
    monitor.setBackgroundColor(COLORS.header)
    monitor.setTextColor(COLORS.headerText)
    monitor.setCursorPos(monitorWidth - 14, 1)
    monitor.write("Items: " .. #filteredItems)
end

local function getCategoryList()
    local cats = {"All"}
    for _, cat in ipairs(CATEGORIES) do
        table.insert(cats, cat.name)
    end
    return cats
end

local function drawCategories()
    -- Use two rows for categories at the bottom
    local catRow1 = monitorHeight - 4
    local catRow2 = monitorHeight - 3

    monitor.setBackgroundColor(COLORS.categoryBg)
    monitor.setCursorPos(1, catRow1)
    monitor.clearLine()
    monitor.setCursorPos(1, catRow2)
    monitor.clearLine()

    local categories = getCategoryList()
    local x = 2
    local row = catRow1

    for _, cat in ipairs(categories) do
        local catWidth = #cat + 2
        -- Wrap to next row if needed
        if x + catWidth > monitorWidth - 1 and row == catRow1 then
            x = 2
            row = catRow2
        end

        if currentCategory == cat then
            monitor.setBackgroundColor(COLORS.categoryActive)
        else
            monitor.setBackgroundColor(COLORS.categoryBg)
        end
        monitor.setTextColor(COLORS.categoryText)
        monitor.setCursorPos(x, row)
        monitor.write(" " .. cat .. " ")
        x = x + catWidth + 1
    end

    -- Fill rest of lines
    monitor.setBackgroundColor(COLORS.categoryBg)
    if row == catRow1 then
        monitor.setCursorPos(x, catRow1)
        monitor.write(string.rep(" ", monitorWidth - x + 1))
        monitor.setCursorPos(1, catRow2)
        monitor.write(string.rep(" ", monitorWidth))
    else
        monitor.setCursorPos(x, catRow2)
        monitor.write(string.rep(" ", monitorWidth - x + 1))
    end
end

local function drawItemList()
    monitor.setBackgroundColor(COLORS.listBg)

    -- Header row (row 2)
    monitor.setTextColor(COLORS.listHighlight)
    monitor.setCursorPos(1, 2)
    monitor.clearLine()
    monitor.setCursorPos(3, 2)
    monitor.write("Item Name")
    monitor.setCursorPos(monitorWidth - 12, 2)
    monitor.write("Count")

    -- Separator (row 3)
    monitor.setCursorPos(1, 3)
    monitor.setTextColor(COLORS.listItemAlt)
    monitor.write(string.rep("-", monitorWidth))

    -- Calculate available rows for items (row 4 to monitorHeight - 5)
    local itemStartRow = 4
    local itemEndRow = monitorHeight - 5
    local visibleItems = itemEndRow - itemStartRow + 1

    -- Items
    local startIdx = (currentPage - 1) * visibleItems + 1
    local endIdx = math.min(startIdx + visibleItems - 1, #filteredItems)

    -- Clear item area
    for i = itemStartRow, itemEndRow do
        monitor.setCursorPos(1, i)
        monitor.setBackgroundColor(COLORS.listBg)
        monitor.clearLine()
    end

    local row = itemStartRow
    for i = startIdx, endIdx do
        local item = filteredItems[i]
        if item then
            if (i - startIdx) % 2 == 0 then
                monitor.setTextColor(COLORS.listItem)
            else
                monitor.setTextColor(COLORS.listItemAlt)
            end

            monitor.setCursorPos(3, row)
            local displayName = item.displayName
            local maxNameLen = monitorWidth - 18
            if #displayName > maxNameLen then
                displayName = string.sub(displayName, 1, maxNameLen - 2) .. ".."
            end
            monitor.write(displayName)

            monitor.setCursorPos(monitorWidth - 12, row)
            monitor.write(tostring(item.total))

            row = row + 1
        end
    end

    -- Update total pages based on visible items
    totalPages = math.max(1, math.ceil(#filteredItems / visibleItems))
    if currentPage > totalPages then
        currentPage = totalPages
    end
end

local function drawFooter()
    local searchY = monitorHeight - 2
    local footerY = monitorHeight - 1
    local statusY = monitorHeight

    -- Search box row with Refresh button
    monitor.setBackgroundColor(COLORS.header)
    monitor.setTextColor(COLORS.headerText)
    monitor.setCursorPos(1, searchY)
    monitor.clearLine()
    monitor.setCursorPos(2, searchY)
    monitor.write("Search: ")

    monitor.setBackgroundColor(COLORS.searchBg)
    monitor.setTextColor(COLORS.searchText)
    local searchBoxWidth = 25
    local displaySearch = searchTerm
    if #displaySearch > searchBoxWidth - 2 then
        displaySearch = string.sub(displaySearch, 1, searchBoxWidth - 2)
    end
    monitor.write("[" .. displaySearch .. string.rep(" ", searchBoxWidth - 2 - #displaySearch) .. "]")

    -- Refresh button on search row
    monitor.setBackgroundColor(COLORS.button)
    monitor.setTextColor(COLORS.buttonText)
    monitor.setCursorPos(monitorWidth - 10, searchY)
    monitor.write(" REFRESH ")

    -- Footer bar with page info and nav OR quantity selection
    monitor.setBackgroundColor(COLORS.footer)
    monitor.setTextColor(COLORS.footerText)
    monitor.setCursorPos(1, footerY)
    monitor.clearLine()

    if selectedItem then
        -- Show quantity selection buttons
        monitor.setCursorPos(2, footerY)
        monitor.write("Get: ")

        monitor.setBackgroundColor(COLORS.button)
        monitor.setTextColor(COLORS.buttonText)
        monitor.setCursorPos(8, footerY)
        monitor.write(" 1 ")
        monitor.setCursorPos(13, footerY)
        monitor.write(" 16 ")
        monitor.setCursorPos(19, footerY)
        monitor.write(" 64 ")
        monitor.setCursorPos(25, footerY)
        monitor.write(" ALL ")

        monitor.setBackgroundColor(COLORS.error)
        monitor.setCursorPos(monitorWidth - 10, footerY)
        monitor.write(" CANCEL ")
    else
        -- Page info
        monitor.setCursorPos(3, footerY)
        monitor.write("Page " .. currentPage .. "/" .. totalPages)

        -- Navigation buttons
        if currentPage > 1 then
            monitor.setBackgroundColor(COLORS.button)
            monitor.setCursorPos(monitorWidth - 20, footerY)
            monitor.write(" < PREV ")
        end

        if currentPage < totalPages then
            monitor.setBackgroundColor(COLORS.button)
            monitor.setCursorPos(monitorWidth - 10, footerY)
            monitor.write(" NEXT > ")
        end
    end

    -- Status message row (bottom)
    monitor.setBackgroundColor(COLORS.bg)
    monitor.setCursorPos(1, statusY)
    monitor.clearLine()
    if selectedItem then
        monitor.setTextColor(COLORS.listHighlight)
        monitor.setCursorPos(3, statusY)
        local name = selectedItem.displayName
        if #name > monitorWidth - 20 then
            name = string.sub(name, 1, monitorWidth - 23) .. "..."
        end
        monitor.write("Selected: " .. name .. " (" .. selectedItem.total .. ")")
    elseif statusMessage ~= "" then
        monitor.setTextColor(statusColor)
        monitor.setCursorPos(3, statusY)
        monitor.write(statusMessage)
    end
end

drawUI = function()
    monitor.setBackgroundColor(COLORS.bg)
    monitor.clear()

    drawHeader()
    drawCategories()
    drawItemList()
    drawFooter()
end

--============================================
-- TOUCH HANDLING
--============================================
local function getCategoryAtPos(x, y)
    local catRow1 = monitorHeight - 4
    local catRow2 = monitorHeight - 3

    local categories = getCategoryList()
    local posX = 2
    local row = catRow1

    for _, cat in ipairs(categories) do
        local catWidth = #cat + 2
        -- Wrap to next row if needed
        if posX + catWidth > monitorWidth - 1 and row == catRow1 then
            posX = 2
            row = catRow2
        end

        if y == row and x >= posX and x < posX + catWidth then
            return cat
        end
        posX = posX + catWidth + 1
    end
    return nil
end

local function getItemAtPos(y)
    local itemStartRow = 4
    local itemEndRow = monitorHeight - 5
    local visibleItems = itemEndRow - itemStartRow + 1

    if y < itemStartRow or y > itemEndRow then
        return nil
    end

    local idx = (currentPage - 1) * visibleItems + (y - itemStartRow + 1)
    if idx <= #filteredItems then
        return filteredItems[idx]
    end
    return nil
end

local function handleTouch(x, y)
    local catRow1 = monitorHeight - 4
    local catRow2 = monitorHeight - 3
    local searchY = monitorHeight - 2
    local footerY = monitorHeight - 1

    -- Handle quantity selection if item is selected
    if selectedItem and y == footerY then
        -- Quantity buttons: [1] at 8-10, [16] at 13-16, [64] at 19-22, [ALL] at 25-29
        if x >= 8 and x <= 10 then
            retrieveItem(selectedItem, 1)
            selectedItem = nil
            drawUI()
            return
        elseif x >= 13 and x <= 16 then
            retrieveItem(selectedItem, 16)
            selectedItem = nil
            drawUI()
            return
        elseif x >= 19 and x <= 22 then
            retrieveItem(selectedItem, 64)
            selectedItem = nil
            drawUI()
            return
        elseif x >= 25 and x <= 29 then
            retrieveItem(selectedItem, selectedItem.total)
            selectedItem = nil
            drawUI()
            return
        elseif x >= monitorWidth - 10 then
            -- Cancel button
            selectedItem = nil
            statusMessage = "Cancelled"
            statusColor = COLORS.listItemAlt
            drawUI()
            return
        end
    end

    -- Scale button (row 1, near right side)
    if y == 1 and x >= monitorWidth - 22 and x <= monitorWidth - 17 then
        selectedItem = nil
        cycleScale()
        statusMessage = "Scale: " .. MONITOR_SCALE .. "x"
        statusColor = COLORS.success
        drawUI()
        return
    end

    -- Search box click (bottom area, x 10-35)
    if y == searchY and x >= 10 and x <= 35 then
        selectedItem = nil
        isSearching = true
        statusMessage = "Type to search, Enter to confirm, Esc to cancel"
        statusColor = COLORS.listHighlight
        drawUI()
        return
    end

    -- Refresh button (on search row, right side)
    if y == searchY and x >= monitorWidth - 10 then
        selectedItem = nil
        statusMessage = "Refreshing inventory..."
        statusColor = COLORS.listHighlight
        drawUI()
        scanInventory()
        filterItems()
        statusMessage = "Inventory refreshed!"
        statusColor = COLORS.success
        drawUI()
        return
    end

    -- Category buttons (bottom rows)
    if y == catRow1 or y == catRow2 then
        local cat = getCategoryAtPos(x, y)
        if cat then
            selectedItem = nil
            currentCategory = cat
            currentPage = 1
            filterItems()
            drawUI()
        end
        return
    end

    -- Item list (rows 4 to monitorHeight - 5)
    local item = getItemAtPos(y)
    if item then
        -- Select the item and show quantity options
        selectedItem = item
        statusMessage = ""
        drawUI()
        return
    end

    -- Previous page (only when no item selected)
    if not selectedItem and y == footerY and x >= monitorWidth - 20 and x < monitorWidth - 10 and currentPage > 1 then
        currentPage = currentPage - 1
        drawUI()
        return
    end

    -- Next page (only when no item selected)
    if not selectedItem and y == footerY and x >= monitorWidth - 10 and currentPage < totalPages then
        currentPage = currentPage + 1
        drawUI()
        return
    end

    -- Clicking elsewhere clears selection
    if selectedItem then
        selectedItem = nil
        drawUI()
    end
end

local function handleKey(key)
    if not isSearching then return end

    if key == keys.enter then
        isSearching = false
        filterItems()
        currentPage = 1
        statusMessage = ""
        drawUI()
    elseif key == keys.escape then
        isSearching = false
        searchTerm = ""
        filterItems()
        currentPage = 1
        statusMessage = ""
        drawUI()
    elseif key == keys.backspace then
        if #searchTerm > 0 then
            searchTerm = string.sub(searchTerm, 1, -2)
            drawUI()
        end
    end
end

local function handleChar(char)
    if not isSearching then return end

    if #searchTerm < 23 then
        searchTerm = searchTerm .. char
        drawUI()
    end
end

--============================================
-- MAIN LOOP
--============================================
local function eventLoop()
    while true do
        local event, p1, p2, p3 = os.pullEvent()

        if event == "monitor_touch" then
            handleTouch(p2, p3)
        elseif event == "key" then
            if p1 == keys.q and not isSearching then
                monitor.setBackgroundColor(colors.black)
                monitor.clear()
                print("Goodbye!")
                return
            end
            handleKey(p1)
        elseif event == "char" then
            handleChar(p1)
        end
    end
end

local function main()
    print("Starting Inventory Management System...")
    print("Finding peripherals...")
    findPeripherals()

    print("Scanning inventory...")
    scanInventory()
    filterItems()

    print("Drawing UI...")
    drawUI()

    print("System ready! Use the monitor to interact.")
    print("Press Q to quit.")
    if inputChest then
        print("Auto-sort from input chest is ACTIVE")
    end

    -- Run event loop and auto-sort in parallel
    parallel.waitForAny(eventLoop, autoSortLoop)
end

-- Run the program
main()
