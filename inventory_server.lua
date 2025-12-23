-- Inventory Management System for CC:Tweaked
-- Touchscreen interface with search, categories, and item retrieval

--============================================
-- CONFIGURATION
--============================================
local OUTPUT_CHEST = "minecraft:chest_0"  -- Set this to your output chest's peripheral name
local INPUT_CHEST = "minecraft:chest_1"   -- Set this to your input/dump chest's peripheral name
local ITEMS_PER_PAGE = 14                  -- Number of items shown per page
local AUTO_SORT_INTERVAL = 2               -- Seconds between auto-sort checks

--============================================
-- CATEGORY DEFINITIONS
--============================================
local CATEGORIES = {
    {name = "Tools", keywords = {"pickaxe", "axe", "shovel", "hoe", "sword", "bow", "crossbow", "trident", "shield", "fishing_rod", "shears", "flint_and_steel"}},
    {name = "Blocks", keywords = {"stone", "dirt", "grass", "wood", "plank", "log", "brick", "glass", "sand", "gravel", "concrete", "terracotta", "wool", "slab", "stairs", "fence", "wall", "door"}},
    {name = "Food", keywords = {"beef", "pork", "chicken", "mutton", "rabbit", "cod", "salmon", "bread", "apple", "carrot", "potato", "beetroot", "melon", "cookie", "cake", "pie", "stew", "soup", "golden_apple"}},
    {name = "Ores", keywords = {"ore", "raw_", "ingot", "nugget", "diamond", "emerald", "gold", "iron", "copper", "coal", "lapis", "redite", "netherite", "amethyst"}},
    {name = "Redstone", keywords = {"redstone", "repeater", "comparator", "piston", "lever", "button", "pressure_plate", "tripwire", "observer", "dropper", "dispenser", "hopper", "rail"}},
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

    monitorWidth, monitorHeight = monitor.getSize()
    monitor.setTextScale(0.5)
    monitorWidth, monitorHeight = monitor.getSize()

    -- Find modem for network access
    modem = peripheral.find("modem", function(name, wrapped)
        return not wrapped.isWireless()
    end)

    if not modem then
        error("No wired modem found! Please attach a wired modem.")
    end

    -- Get all inventories on the network
    local allPeripherals = peripheral.getNames()

    for _, name in ipairs(allPeripherals) do
        if peripheral.hasType(name, "inventory") then
            if name == OUTPUT_CHEST then
                outputChest = peripheral.wrap(name)
                print("Output chest: " .. name)
            elseif name == INPUT_CHEST then
                inputChest = peripheral.wrap(name)
                print("Input chest: " .. name)
            else
                storageChests[name] = peripheral.wrap(name)
                print("Storage chest: " .. name)
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

    for chestName, chest in pairs(storageChests) do
        local items = chest.list()
        if items then
            for slot, item in pairs(items) do
                local detail = chest.getItemDetail(slot)
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
                end

                itemIndex[key].total = itemIndex[key].total + item.count
                table.insert(itemIndex[key].locations, {
                    chest = chestName,
                    slot = slot,
                    count = item.count
                })
            end
        end
    end
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
local function retrieveItem(item, requestedCount)
    if not outputChest then
        statusMessage = "No output chest configured!"
        statusColor = COLORS.error
        return false
    end

    local remaining = math.min(requestedCount, 64)
    local transferred = 0

    for _, loc in ipairs(item.locations) do
        if remaining <= 0 then break end

        local chest = storageChests[loc.chest]
        if chest then
            local moved = chest.pushItems(OUTPUT_CHEST, loc.slot, remaining)
            if moved and moved > 0 then
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
        local items = chest.list()
        if items then
            for slot, item in pairs(items) do
                if item.name == itemName then
                    local limit = chest.getItemLimit(slot)
                    if item.count < limit then
                        return chestName, slot, limit - item.count
                    end
                end
            end
        end
    end

    -- If no existing stack, find an empty slot
    for chestName, chest in pairs(storageChests) do
        local size = chest.size()
        local items = chest.list()
        for slot = 1, size do
            if not items[slot] then
                return chestName, slot, 64
            end
        end
    end

    return nil, nil, 0
end

local function sortInputChest()
    if not inputChest then return false end

    local items = inputChest.list()
    if not items then return false end

    local movedAny = false

    for slot, item in pairs(items) do
        local targetChest, targetSlot, space = findStorageSlot(item.name)

        if targetChest and space > 0 then
            local moved = inputChest.pushItems(targetChest, slot, space, targetSlot)
            if moved and moved > 0 then
                movedAny = true
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

    -- Search box
    monitor.setCursorPos(1, 2)
    monitor.clearLine()
    monitor.setCursorPos(2, 2)
    monitor.write("Search: ")

    monitor.setBackgroundColor(COLORS.searchBg)
    monitor.setTextColor(COLORS.searchText)
    local searchBoxWidth = 25
    local displaySearch = searchTerm
    if #displaySearch > searchBoxWidth - 2 then
        displaySearch = string.sub(displaySearch, 1, searchBoxWidth - 2)
    end
    monitor.write("[" .. displaySearch .. string.rep(" ", searchBoxWidth - 2 - #displaySearch) .. "]")

    -- Refresh button
    monitor.setBackgroundColor(COLORS.button)
    monitor.setTextColor(COLORS.buttonText)
    monitor.setCursorPos(monitorWidth - 10, 2)
    monitor.write(" REFRESH ")
end

local function drawCategories()
    monitor.setCursorPos(1, 4)
    monitor.setBackgroundColor(COLORS.categoryBg)
    monitor.clearLine()

    local categories = {"All", "Tools", "Blocks", "Food", "Ores", "Redstone", "Misc"}
    local x = 2

    for _, cat in ipairs(categories) do
        if currentCategory == cat then
            monitor.setBackgroundColor(COLORS.categoryActive)
        else
            monitor.setBackgroundColor(COLORS.categoryBg)
        end
        monitor.setTextColor(COLORS.categoryText)
        monitor.setCursorPos(x, 4)
        monitor.write(" " .. cat .. " ")
        x = x + #cat + 3
    end

    -- Fill rest of line
    monitor.setBackgroundColor(COLORS.categoryBg)
    monitor.setCursorPos(x, 4)
    monitor.write(string.rep(" ", monitorWidth - x + 1))
end

local function drawItemList()
    monitor.setBackgroundColor(COLORS.listBg)

    -- Header row
    monitor.setTextColor(COLORS.listHighlight)
    monitor.setCursorPos(1, 6)
    monitor.clearLine()
    monitor.setCursorPos(3, 6)
    monitor.write("Item Name")
    monitor.setCursorPos(monitorWidth - 12, 6)
    monitor.write("Count")

    -- Separator
    monitor.setCursorPos(1, 7)
    monitor.setTextColor(COLORS.listItemAlt)
    monitor.write(string.rep("-", monitorWidth))

    -- Items
    local startIdx = (currentPage - 1) * ITEMS_PER_PAGE + 1
    local endIdx = math.min(startIdx + ITEMS_PER_PAGE - 1, #filteredItems)

    for i = 8, 7 + ITEMS_PER_PAGE do
        monitor.setCursorPos(1, i)
        monitor.setBackgroundColor(COLORS.listBg)
        monitor.clearLine()
    end

    local row = 8
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
end

local function drawFooter()
    local footerY = monitorHeight - 1

    -- Status message
    monitor.setBackgroundColor(COLORS.bg)
    monitor.setCursorPos(1, footerY - 1)
    monitor.clearLine()
    if statusMessage ~= "" then
        monitor.setTextColor(statusColor)
        monitor.setCursorPos(3, footerY - 1)
        monitor.write(statusMessage)
    end

    -- Footer bar
    monitor.setBackgroundColor(COLORS.footer)
    monitor.setTextColor(COLORS.footerText)
    monitor.setCursorPos(1, footerY)
    monitor.clearLine()

    -- Page info
    monitor.setCursorPos(3, footerY)
    monitor.write("Page " .. currentPage .. "/" .. totalPages)

    -- Item count
    monitor.setCursorPos(20, footerY)
    monitor.write("Items: " .. #filteredItems)

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

local function drawUI()
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
local function getCategoryAtPos(x)
    local categories = {"All", "Tools", "Blocks", "Food", "Ores", "Redstone", "Misc"}
    local pos = 2

    for _, cat in ipairs(categories) do
        local catWidth = #cat + 2
        if x >= pos and x < pos + catWidth then
            return cat
        end
        pos = pos + catWidth + 1
    end
    return nil
end

local function getItemAtPos(y)
    if y < 8 or y > 7 + ITEMS_PER_PAGE then
        return nil
    end

    local idx = (currentPage - 1) * ITEMS_PER_PAGE + (y - 7)
    if idx <= #filteredItems then
        return filteredItems[idx]
    end
    return nil
end

local function handleTouch(x, y)
    -- Search box click (row 2, x 10-35)
    if y == 2 and x >= 10 and x <= 35 then
        isSearching = true
        statusMessage = "Type to search, Enter to confirm, Esc to cancel"
        statusColor = COLORS.listHighlight
        drawUI()
        return
    end

    -- Refresh button (row 2, right side)
    if y == 2 and x >= monitorWidth - 10 then
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

    -- Category buttons (row 4)
    if y == 4 then
        local cat = getCategoryAtPos(x)
        if cat then
            currentCategory = cat
            currentPage = 1
            filterItems()
            drawUI()
        end
        return
    end

    -- Item list (rows 8+)
    local item = getItemAtPos(y)
    if item then
        statusMessage = "Retrieving " .. item.displayName .. "..."
        statusColor = COLORS.listHighlight
        drawUI()
        retrieveItem(item, 64)
        drawUI()
        return
    end

    -- Previous page
    local footerY = monitorHeight - 1
    if y == footerY and x >= monitorWidth - 20 and x < monitorWidth - 10 and currentPage > 1 then
        currentPage = currentPage - 1
        drawUI()
        return
    end

    -- Next page
    if y == footerY and x >= monitorWidth - 10 and currentPage < totalPages then
        currentPage = currentPage + 1
        drawUI()
        return
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
