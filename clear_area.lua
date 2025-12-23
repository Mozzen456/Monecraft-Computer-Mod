-- Clear Area Script
-- Clears a 10 (length) x 3 (height) x 11 (width) block area
-- Turtle starts at bottom-left corner, facing the direction to dig

local LENGTH = 10  -- x direction (forward)
local HEIGHT = 3   -- y direction (up)
local WIDTH = 11   -- z direction (right)

-- Movement tracking
local posX, posY, posZ = 0, 0, 0
local facing = 0  -- 0=forward, 1=right, 2=back, 3=left

-- Movement wrappers
local function forward()
    while not turtle.forward() do
        turtle.dig()
        sleep(0.3)
    end
    if facing == 0 then posX = posX + 1
    elseif facing == 1 then posZ = posZ + 1
    elseif facing == 2 then posX = posX - 1
    elseif facing == 3 then posZ = posZ - 1
    end
end

local function up()
    while not turtle.up() do
        turtle.digUp()
        sleep(0.3)
    end
    posY = posY + 1
end

local function down()
    while not turtle.down() do
        turtle.digDown()
        sleep(0.3)
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

-- Dig forward, up, and down to clear current column
local function digColumn()
    turtle.dig()
    turtle.digUp()
    turtle.digDown()
end

-- Clear one row (LENGTH blocks forward)
local function clearRow()
    for x = 1, LENGTH do
        digColumn()
        if x < LENGTH then
            forward()
        end
    end
end

-- Main clearing function
local function clearArea()
    print("Clearing " .. LENGTH .. "x" .. HEIGHT .. "x" .. WIDTH .. " area...")
    print("Fuel: " .. turtle.getFuelLevel())

    -- Check fuel
    local neededFuel = LENGTH * WIDTH * 2 + WIDTH * 2 + 10
    if turtle.getFuelLevel() < neededFuel then
        print("Warning: Low fuel! Need ~" .. neededFuel)
    end

    -- Start at y=1 (middle of 3-high area)
    up()

    for z = 1, WIDTH do
        clearRow()

        if z < WIDTH then
            -- Move to next row
            if z % 2 == 1 then
                -- At end of forward row, turn right
                turnRight()
                digColumn()
                forward()
                turnRight()
            else
                -- At end of backward row, turn left
                turnLeft()
                digColumn()
                forward()
                turnLeft()
            end
        end
    end

    print("Clearing complete!")
    print("Final position: " .. posX .. ", " .. posY .. ", " .. posZ)
end

-- Return to start position
local function returnHome()
    print("Returning home...")

    -- Face backward
    if facing == 0 then
        turnLeft()
        turnLeft()
    elseif facing == 1 then
        turnLeft()
    elseif facing == 3 then
        turnRight()
    end

    -- Move back to x=0
    while posX > 0 do
        forward()
    end

    -- Face left (toward z=0)
    turnRight()

    -- Move back to z=0
    while posZ > 0 do
        forward()
    end

    -- Go down to y=0
    while posY > 0 do
        down()
    end

    -- Face original direction
    turnRight()

    print("Home!")
end

-- Run
clearArea()
returnHome()
