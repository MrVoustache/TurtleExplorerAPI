--- This module allows a turtle to move around, all while updating its relative position, as well as to register callbacks in case of moves.

local maps = import "turtle_explorer_api.maps"

local tracker = {}





local position = maps.Position(0, 0, 0)
local direction = maps.DIRECTION.EAST
local POSITION_FILE = ".pos"
local dictionary = {}       ---@type {[string]: {[1]: number, [2]: number, [3]: number, [4]: number?}}
local DICTIONARY_FILE = ".pos_dict"
local position_changed = false
local safe_loaded = false

local old_turn_left = turtle.turnLeft
local old_turn_right = turtle.turnRight
local old_forward = turtle.forward
local old_up = turtle.up
local old_down = turtle.down
local old_back = turtle.back





local function load_position()
    if os.getComputerLabel() == nil then
        local file = fs.open(POSITION_FILE, "r")
        local x, y, z, d = tonumber(file.readLine()), tonumber(file.readLine()), tonumber(file.readLine()), tonumber(file.readLine())
        if x == nil or y == nil or z == nil or d == nil then
            error("corrupted position file", 1)
        end
        local remaining = file.readAll()
        assert(remaining == "", "remaining content in position file: '"..remaining.."'")
        position = maps.Position(x, y, z)
        direction = d
        safe_loaded = true
        file.close()
    end
end

if fs.exists(POSITION_FILE) then
    local ok, err = pcall(load_position)
    if not ok then
        printError("Failed to load position file: "..err)
    end
    fs.delete(POSITION_FILE)
end

local function save_position()
    local file = fs.open(POSITION_FILE, "w")
    file.writeLine(tostring(position.x))
    file.writeLine(tostring(position.y))
    file.writeLine(tostring(position.z))
    file.write(tostring(direction))
    file.close()
end

if not safe_loaded then
    local x, y, z = gps.locate()
    if x ~= nil then
        local p1 = maps.Position(x, y, z)
        -- 1. Try moving Forward
        if old_forward() then
            local x2, y2, z2 = gps.locate()
            if x2 ~= nil then
                local p2 = maps.Position(x2, y2, z2)
                direction = p1:direction_to(p2)
                position = p2
                safe_loaded = true
            end
            if old_back() then
                position = p1
            end
        -- 2. Try moving Back
        elseif old_back() then
            local x2, y2, z2 = gps.locate()
            if x2 ~= nil then
                local p2 = maps.Position(x2, y2, z2)
                -- If we moved back, the direction we are FACING is p2 -> p1
                direction = p2:direction_to(p1)
                position = p2
                safe_loaded = true
            end
            if old_forward() then
                position = p1
            end
        else
            old_turn_left()
            if old_forward() then
                local x2, y2, z2 = gps.locate()
                if x2 ~= nil then
                    local p2 = maps.Position(x2, y2, z2)
                    direction = p1:direction_to(p2)
                    position = p2
                    safe_loaded = true
                end
                if old_back() then
                    position = p1
                    old_turn_right()
                    direction = (direction + 1) % 4
                end
            elseif old_back() then
                local x2, y2, z2 = gps.locate()
                if x2 ~= nil then
                    local p2 = maps.Position(x2, y2, z2)
                    direction = p2:direction_to(p1)
                    position = p2
                    safe_loaded = true
                end
                if old_forward() then
                    position = p1
                    old_turn_right()
                    direction = (direction + 1) % 4
                end
            end
        end
    end
end





local function load_dictionary()
    local file = fs.open(DICTIONARY_FILE, "r")
    local new_dictionary, err = textutils.unserialiseJSON(file.readAll())
    if new_dictionary == nil then
        error("corrupted dictionary file: "..err, 1)
    end
    if type(new_dictionary) ~= "table" then
        error("dictionary file did not contain a table but a '"..type(new_dictionary).."'", 1)
    end
    for k, v in pairs(new_dictionary) do
        if type(k) ~= "string" then
            error("a dictionary key was not a string, but a '"..type(k).."'", 1)
        end
        if type(v) ~= "table" then
            error("a dictionary value was not a table, but a '"..type(v).."'", 1)
        end
        local n = 0
        for k2, v2 in pairs(v) do
            n = n + 1
        end
        if n < 3 or n > 4 then
            error("a dictionary entry did not contain three or four elements, but "..n, 1)
        end
        if type(v[1]) ~= "number" or type(v[2]) ~= "number" or type(v[3]) ~= "number" then
            error("elements one to three were not all numbers.", 1)
        end
        if v[4] ~= nil and (type(v[4]) ~= "number" or v[4] < 0 or v[4] > 3 or v[4] ~= math.floor(v[4])) then
            error("second element of entry is not a DIRECTION", 1)
        end
    end
    dictionary = new_dictionary
end

if fs.exists(DICTIONARY_FILE) and not fs.isDir(DICTIONARY_FILE) then
    local ok, err = pcall(load_dictionary)
    if not ok then
        printError("Failed to load dictionary file: "..err)
    end
end

local function save_dictionary()
    local file = fs.open(DICTIONARY_FILE, "w")
    file.write(textutils.serialiseJSON(dictionary))
    file.close()
end





function turtle.turnLeft()
    local ok = old_turn_left()
    if ok then
        direction = direction - 1
        if direction < 0 then
            direction = 3
        end
        position_changed = true
    end
    return ok
end

function turtle.turnRight()
    local ok = old_turn_right()
    if ok then
        direction = direction + 1
        if direction > 3 then
            direction = 0
        end
        position_changed = true
    end
    return ok
end

function turtle.forward()
    local ok, err = old_forward()
    if ok then
        position = position:in_direction(direction)
        position_changed = true
    end
    return ok, err
end

function turtle.up()
    local ok, err = old_up()
    if ok then
        position = position:above()
        position_changed = true
    end
    return ok, err
end

function turtle.down()
    local ok, err = old_down()
    if ok then
        position = position:below()
        position_changed = true
    end
    return ok, err
end

function turtle.back()
    local ok, err = old_back()
    if ok then
        position = position:in_direction((direction + 2) % 4)
        position_changed = true
    end
    return ok, err
end





local old_reboot = os.reboot
function os.reboot()
    if position_changed then
        save_position()
    end
    old_reboot()
end

local old_shutdown = os.shutdown
function os.shutdown()
    if position_changed then
        save_position()
    end
    old_shutdown()
end





--- Returns the current known position of the turtle
---@return Position current The current position
function tracker.get_position()
    return maps.Position(position.x, position.y, position.z)
end

--- Returns the current known direction of the turtle
---@return DIRECTION current The current orientation
function tracker.get_direction()
    return direction
end

--- Returns the array of the existing position names in the position dictionary.
---@return string[] names The existing names.
function tracker.get_dict_names()
    local names = {}
    for name, entry in pairs(dictionary) do
        table.insert(names, name)
    end
    return names
end

--- Returns the position anv eventual direction associated with this name in the dictionary.
---@param name string The name to look for.
---@return Position? position The corresponding position if the name is in the dictionary.
---@return DIRECTION? direction The eventual direction associated with the position.
function tracker.get_dict_entry(name)
    if type(name) ~= "string" then
        error("expected string for argument, got '"..type(name).."'", 2)
    end
    local entry = dictionary[name]
    if entry ~= nil then
        return maps.Position(dictionary[name][1], dictionary[name][2], dictionary[name][3]), dictionary[name][4]
    end
end

--- Sets or deletes the entry in the dictionary with the associated name.
---@param name string The name of the entry.
---@param position Position? The position to set or nil to delete.
---@param direction DIRECTION? The eventual associated direction, or nil to delete.
function tracker.set_dict_entry(name, position, direction)
    if type(name) ~= "string" then
        error("expected string for argument, got '"..type(name).."'", 2)
    end
    if position == nil and direction ~= nil then
        error("if position (argument #2) is nil, then direction (argument #3) should also be nil", 2)
    end
    if position ~= nil and (type(position) ~= "table" or getmetatable(position) ~= maps.Position) then
        error("expected Position or nil for second argument, got '"..type(position).."'", 2)
    end
    if direction ~= nil and type(direction) ~= "number" then
        error("expected number or nil for third argument, got '"..type(direction).."'", 2)
    end
    if direction ~= nil and (direction < 0 or direction > 3 or direction ~= math.floor(direction)) then
        error("expected integer between 0 and 3 inclusive for direction, got "..tostring(direction), 2)
    end
    if position == nil then
        dictionary[name] = nil
    else
        dictionary[name] = {position.x, position.y, position.z, direction}
    end
    save_dictionary()
end





return tracker