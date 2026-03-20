--- This module allows a turtle to move around, all while updating its relative position, as well as to register callbacks in case of moves.

local position = maps.Position:new(0, 0, 0)
local direction = maps.EAST
local POSITION_FILE = ".pos"

local function load_position()
    local file = fs.open(POSITION_FILE, "r")
    local x, y, z, d = tonumber(file.readLine()), tonumber(file.readLine()), tonumber(file.readLine()), tonumber(file.readLine())
    if x == nil or y == nil or z == nil or d == nil then
        error("corrupted position file", 1)
    end
    local remaining = file.readAll()
    assert(remaining == "", "remaining content in position file: '"..remaining.."'")
    position = maps.Position:new(x, y, z)
    direction = d
    file.close()
end

if fs.exists(".pos") then
    local ok, err = pcall(load_position)
    if not ok then
        printError("Failed to load position file: "..err)
    end
end

local function save_position()
    local file = fs.open(POSITION_FILE, "w")
    file.writeLine(tostring(position.x))
    file.writeLine(tostring(position.y))
    file.writeLine(tostring(position.z))
    file.write(tostring(direction))
    file.close()
end






local old_turn_left = turtle.turnLeft
function turtle.turnLeft()
    local ok = old_turn_left()
    if ok then
        direction = direction - 1
        if direction < 0 then
            direction = 3
        end
        save_position()
    end
    return ok
end

local old_turn_right = turtle.turnRight
function turtle.turnRight()
    local ok = old_turn_right()
    if ok then
        direction = direction + 1
        if direction > 3 then
            direction = 0
        end
        save_position()
    end
    return ok
end

local old_forward = turtle.forward
function turtle.forward()
    local ok, err = old_forward()
    if ok then
        position = position:in_direction(direction)
        save_position()
    end
    return ok, err
end

local old_up = turtle.up
function turtle.up()
    local ok, err = old_up()
    if ok then
        position = position:above()
        save_position()
    end
    return ok, err
end

local old_down = turtle.down
function turtle.down()
    local ok, err = old_down()
    if ok then
        position = position:below()
        save_position()
    end
    return ok, err
end

local old_back = turtle.back
function turtle.back()
    local ok, err = old_back()
    if ok then
        position = position:in_direction(-direction % 4)
        save_position()
    end
    return ok, err
end





_G.tracker = {}

--- Returns the current known position of the turtle
---@return Position current The current position
function tracker.get_position()
    return position:new(position.x, position.y, position.z)
end

--- Returns the current known direction of the turtle
---@return integer current The current orientation
function tracker.get_direction()
    return direction
end





return tracker