--- This module provides functions for working with minecraft world absolute or relative positions, working with maps of knwown areas, and calculating distances and paths between positions.
--- 
--- For direction conventions, the positive x direction is east (direction 0), the positive y direction is up, and the positive z direction is south (direction 1). The negative x direction is west (direction 2), the negative y direction is down, and the negative z direction is north (direction 3).

local class = import "class"
local heap = import "turtle_explorer_api.heap"
import "os"

local maps = {}

---@enum DIRECTION
maps.DIRECTION = {          --- The four cardinal directions.
    EAST = 0,               --- Towards east
    SOUTH = 1,              --- Towards south
    WEST = 2,               --- Towards west
    NORTH = 3               --- Towards north
}





---@class Position A position in the minecraft world, with x, y, and z coordinates.
---@field x number The x coordinate of the position.
---@field y number The y coordinate of the position.
---@field z number The z coordinate of the position.
local Position = class.classify("Position", {})
maps.Position = Position

--- Creates a new Position object.
---@param x number? The x coordinate of the position.
---@param y number? The y coordinate of the position.
---@param z number? The z coordinate of the position.
---@return Position pos The new Position object.
function Position:__init(x, y, z)
    if x == nil then x = 0 end
    if y == nil then y = 0 end
    if z == nil then z = 0 end
    if type(x) ~= "number" then error("x must be a number, not '" .. type(x) .. "'", 2) end
    if type(y) ~= "number" then error("y must be a number, not '" .. type(y) .. "'", 2) end
    if type(z) ~= "number" then error("z must be a number, not '" .. type(z) .. "'", 2) end
    self.x = x
    self.y = y
    self.z = z
    return self
end

--- Returns a string representation of the Position object.
---@return string str The string representation of the Position object.
function Position:__tostring()
    return "Position(" .. self.x .. ", " .. self.y .. ", " .. self.z .. ")"
end

--- Returns whether two positions are equal.
---@param pos2 Position The position to compare to.
---@return boolean equals If the two positions are equal.
function Position:__eq(pos2)
    if not class.isinstance(pos2, Position) then
        return rawequal(self, pos2)
    end
    return self.x == pos2.x and self.y == pos2.y and self.z == pos2.z
end

--- Returns a new Position object that represents the same point using absolute coordinates, given the coordinates and direction of the corresponding original position.
---@param origin Position The original position with absolute coordinates.
---@param east_direction DIRECTION The direction of the original east direction (0 if it was actually east, 1 if it was actually south, 2 if it was actually west, and 3 if it was actually north).
---@return Position pos The new Position object with absolute coordinates.
function Position:to_absolute(origin, east_direction)
    if not class.isinstance(origin, Position) then
        error("expected position as argument #1, got '"..type(origin).."'", 2)
    end
    if type(east_direction) ~= "number" then
        error("expected number as direction, got '"..type(east_direction).."'", 2)
    end
    local newX, newY, newZ
    if east_direction == maps.DIRECTION.EAST then
        newX = origin.x + self.x
        newY = origin.y + self.y
        newZ = origin.z + self.z
    elseif east_direction == maps.DIRECTION.SOUTH then
        newX = origin.x - self.z
        newY = origin.y + self.y
        newZ = origin.z + self.x
    elseif east_direction == maps.DIRECTION.WEST then
        newX = origin.x - self.x
        newY = origin.y + self.y
        newZ = origin.z - self.z
    elseif east_direction == maps.DIRECTION.NORTH then
        newX = origin.x + self.z
        newY = origin.y + self.y
        newZ = origin.z - self.x
    else
        error("invalid direction value", 2)
    end
    return Position(newX, newY, newZ)
end

--- Returns the next position above.
---@return Position above The above position.
function Position:above()
    return Position(self.x, self.y + 1, self.z)
end

--- Returns the next position below.
---@return Position below The below position.
function Position:below()
    return Position(self.x, self.y - 1, self.z)
end

--- Returns the next eastern position (positive x).
---@return Position east The eastern position.
function Position:east()
    return Position(self.x + 1, self.y, self.z)
end

--- Returns the next southern position (positive z).
---@return Position south The southern position.
function Position:south()
    return Position(self.x, self.y, self.z + 1)
end

--- Returns the next western position (negative x).
---@return Position west The west position.
function Position:west()
    return Position(self.x - 1, self.y, self.z)
end

--- Returns the next northern position (negative x).
---@return Position north The north position.
function Position:north()
    return Position(self.x, self.y, self.z - 1)
end

--- Returns the next block in the given cardinal direction.
---@param dir DIRECTION The direction (a constant like maps.DIRECTION.EAST).
---@return Position next_block The next position in the given direction.
function Position:in_direction(dir)
    if dir == maps.DIRECTION.EAST then
        return self:east()
    elseif dir == maps.DIRECTION.SOUTH then
        return self:south()
    elseif dir == maps.DIRECTION.WEST then
        return self:west()
    elseif dir == maps.DIRECTION.NORTH then
        return self:north()
    end
    error("position should be one of the four cardinal direction constants, got "..tostring(dir), 2)
end

--- Returns an iterator of the six direct neighbor positions of this block.
---@return fun(): Position? neighbors The iterator of neighbors (to use in a for loop).
function Position:neighbors()
    local x, y, z = self.x, self.y, self.z
    local i = 0
    return function ()
        i = i + 1
        if i == 1 then
            return Position(x + 1, y, z)
        elseif i == 2 then
            return Position(x - 1, y, z)
        elseif i == 3 then
            return Position(x, y + 1, z)
        elseif i == 4 then
            return Position(x, y - 1, z)
        elseif i == 5 then
            return Position(x, y, z + 1)
        elseif i == 6 then
            return Position(x, y, z - 1)
        end
    end
end

--- Returns the direction from the position towards an adjacent position.
---@param pos Position The position we are facing towards.
---@return DIRECTION direction_towards The direction from the current position towards the given one.
function Position:direction_to(pos)
    if not class.isinstance(pos, Position) then
        error("expected position as argument #1, got '"..type(pos).."'", 2)
    end
    if self:manhattan_distance_to(pos) ~= 1 then
        error("to compute a direction, the two blocks must be at a Manhattan distance of exactly 1", 2)
    end
    if pos.x > self.x then
        return maps.DIRECTION.EAST
    elseif pos.z > self.z then
        return maps.DIRECTION.SOUTH
    elseif self.x > pos.x then
        return maps.DIRECTION.WEST
    elseif self.z > pos.z then
        return maps.DIRECTION.NORTH
    else
        error("a cardinal direction only exists for horizontal directions, not above or below", 2)
    end
end

--- Calculates the Euclidean distance between two positions.
---@param pos1 Position The first position.
---@param pos2 Position The second position.
---@return number distance The Euclidean distance between the two positions.
function maps.euclidean_distance(pos1, pos2)
    if not class.isinstance(pos1, Position) then
        error("expected position as argument #1, got '"..type(pos1).."'", 2)
    end
    if not class.isinstance(pos2, Position) then
        error("expected position as argument #2, got '"..type(pos2).."'", 2)
    end
    local dx = pos1.x - pos2.x
    local dy = pos1.y - pos2.y
    local dz = pos1.z - pos2.z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

--- Calculates the Manhattan distance between two positions.
---@param pos1 Position The first position.
---@param pos2 Position The second position.
---@return number distance The Manhattan distance between the two positions.
function maps.manhattan_distance(pos1, pos2)
    if not class.isinstance(pos1, Position) then
        error("expected position as argument #1, got '"..type(pos1).."'", 2)
    end
    if not class.isinstance(pos2, Position) then
        error("expected position as argument #2, got '"..type(pos2).."'", 2)
    end
    local dx = math.abs(pos1.x - pos2.x)
    local dy = math.abs(pos1.y - pos2.y)
    local dz = math.abs(pos1.z - pos2.z)
    return dx + dy + dz
end

maps.distance = maps.euclidean_distance

--- Returns the absolute direction of the east direction given two pairs of absolute and relative positions.
---@param relative1 Position The first relative position corresponding to the first absolute position.
---@param absolute1 Position The first absolute position.
---@param relative2 Position The second relative position corresponding to the second absolute position.
---@param absolute2 Position The second absolute position.
---@return DIRECTION east_direction The absolute direction of the east direction (0 if it is actually east, 1 if it is actually south, 2 if it is actually west, and 3 if it is actually north).
function maps.get_absolute_direction(relative1, absolute1, relative2, absolute2)
    if not class.isinstance(relative1, Position) then
        error("expected position as argument #1, got '"..type(relative1).."'", 2)
    end
    if not class.isinstance(absolute1, Position) then
        error("expected position as argument #2, got '"..type(absolute1).."'", 2)
    end
    if not class.isinstance(relative2, Position) then
        error("expected position as argument #3, got '"..type(relative2).."'", 2)
    end
    if not class.isinstance(absolute2, Position) then
        error("expected position as argument #4, got '"..type(absolute2).."'", 2)
    end
    local dxa = absolute2.x - absolute1.x
    local dza = absolute2.z - absolute1.z
    local dxr = relative2.x - relative1.x
    local dzr = relative2.z - relative1.z
    if dxr == 0 and dzr == 0 then
        error("the two relative positions cannot be the same", 2)
    end
    if dxr == dxa and dzr == dza then
        return maps.DIRECTION.EAST
    elseif dxr == -dza and dzr == dxa then
        return maps.DIRECTION.SOUTH
    elseif dxr == -dxa and dzr == -dza then
        return maps.DIRECTION.WEST
    elseif dxr == dza and dzr == -dxa then
        return maps.DIRECTION.NORTH
    else
        error("the four positions belong to more than two directions", 2)
    end
end

--- Returns a transformation function to convert relative positions to absolute positions given the coordinates and directions of the corresponding original position or the relative and absolute positions of two points.
---@param origin Position The original position with absolute coordinates.
---@param direction_or_relative_position DIRECTION|Position The direction of the original east direction (0 if it is actually east, 1 if it is actually south, 2 if it is actually west, and 3 if it is actually north) or the relative position corresponding to the original position.
---@param absolute_position Position? The absolute position corresponding to the second relative position, required if the second argument is a relative position.
---@return fun(relative_position : Position): Position transform A function that takes a relative position and returns the corresponding absolute position.
function maps.get_relative_to_absolute_transform(origin, direction_or_relative_position, absolute_position)
    if type(origin) ~= "table" or getmetatable(origin) ~= Position then
        error("expected position as argument #1, got '"..type(origin).."'", 2)
    end
    local direction
    if type(direction_or_relative_position) == "number" then
        direction = direction_or_relative_position
    elseif class.isinstance(direction_or_relative_position, Position) then
        if absolute_position == nil then
            error("absolute_position is required when the second argument is a relative position", 2)
        end
        direction = maps.get_absolute_direction(direction_or_relative_position, origin, Position(), absolute_position)
    else
        error("direction_or_relative_position must be either a number or a Position object", 2)
    end
    return function(relative_position)
        return relative_position:to_absolute(origin, direction)
    end
end

--- Returns the Manhattan distance to another position
---@param other Position The other position.
---@return number distance The distance between the calling Position and the other Position.
function Position:manhattan_distance_to(other)
    if not class.isinstance(other, Position) then
        error("expected position as argument #1, got '"..type(other).."'", 2)
    end
    return maps.manhattan_distance(self, other)
end

--- Returns the Euclidean distance to another position
---@param other Position The other position.
---@return number distance The distance between the calling Position and the other Position.
function Position:euclidian_distance_to(other)
    if not class.isinstance(other, Position) then
        error("expected position as argument #1, got '"..type(other).."'", 2)
    end
    return maps.euclidean_distance(self, other)
end

Position.distance_to = Position.euclidian_distance_to

--- Returns whether this position is inside the box bounded by two opposite corners.
---@param pos1 Position The first corner of the bounding box.
---@param pos2 Position The second corner of the bounding box.
---@return boolean inside Whether this position is inside the box.
function Position:inside_box(pos1, pos2)
    if not class.isinstance(pos1, Position) then
        error("expected position as argument #1, got '"..type(pos1).."'", 2)
    end
    if not class.isinstance(pos2, Position) then
        error("expected position as argument #2, got '"..type(pos2).."'", 2)
    end
    local minX, maxX = math.min(pos1.x, pos2.x), math.max(pos1.x, pos2.x)
    local minY, maxY = math.min(pos1.y, pos2.y), math.max(pos1.y, pos2.y)
    local minZ, maxZ = math.min(pos1.z, pos2.z), math.max(pos1.z, pos2.z)
    return self.x >= minX and self.x <= maxX and self.y >= minY and self.y <= maxY and self.z >= minZ and self.z <= maxZ
end

--- Returns an iterator of Positions that are in the cubic area bounded by the two given positions.
---@param pos1 Position The first bounding position (the first to be yielded).
---@param pos2 Position The second bounding position (the last to be yielded).
---@return fun(): Position? iterator An iterator function that yields all positions in the box bounded by the two given positions.
function maps.bounded_positions(pos1, pos2)
    if not class.isinstance(pos1, Position) then
        error("expected position as argument #1, got '"..type(pos1).."'", 2)
    end
    if not class.isinstance(pos2, Position) then
        error("expected position as argument #2, got '"..type(pos2).."'", 2)
    end
    local dx, dy, dz
    if pos1.x <= pos2.x then
        dx = 1
    else
        dx = -1
    end
    if pos1.y <= pos2.y then
        dy = 1
    else
        dy = -1
    end
    if pos1.z <= pos2.z then
        dz = 1
    else
        dz = -1
    end
    local function iterator(x1, x2, dx, y1, y2, dy, z1, z2, dz)
        for x = x1, x2, dx do
            for y = y1, y2, dy do
                for z = z1, z2, dz do
                    coroutine.yield(Position(x, y, z))
                end
            end
        end
    end
    return coroutine.wrap(function() return iterator(pos1.x, pos2.x, dx, pos1.y, pos2.y, dy, pos1.z, pos2.z, dz) end)
end

--- Returns an iterator of all the blocks at a Manhattan distance of at most range blocks.
---@param range number The maximum distance to the yielded blocks.
---@return fun(): Position? iterator The iterator function.
function Position:at_range(range)
    if type(range) ~= "number" then
        error("expected number, got '"..type(range).."'", 2)
    end
    if range < 0 then
        error("expected positive or null integer, got "..range, 2)
    end
    range = math.floor(range)
    local function iterator()
        for x = self.x - range, self.x + range do
            for y = self.y - range, self.y + range do
                for z = self.z - range, self.z + range do
                    coroutine.yield(Position(x, y, z))
                end
            end
        end
    end
    return coroutine.wrap(function() return iterator() end)
end

--- Returns a short string representation of a position for hashing.
---@return string hash The string to hash to represent the position in a table.
function Position:hash()
    return self.x ..";"..self.y..";"..self.z
end





---@enum STATUS
maps.STATUS = {         --- The possibles statuses of blocks at a given location on a Map object.
    EMPTY = 0,          --- There is nothing (air) in this position.
    SOLID = 1,          --- There is a block in this position.
    BARRIER = 2         --- This position is forbidden.
}

---@class Map A map of a known area in the minecraft world, with information about blocks and properties of the area.
---@field status {Position: number} A table mapping positions to their status, which can be "empty", "solid", or "barrier".
---@field blocks {Position: string} A table mapping positions to the type of block at that position, which can be any string representing a block type.
---@field size number The size of the map, which is the number of positions with known status or block type.
---@field generate_events boolean If events should be generated in case of map update.
---@field sync_agents table<fun(pos: Position, status: STATUS?, block: string?), boolean> A list of agents to inform of any map update.
---@field change_callback fun(position: Position, old_status: STATUS?, old_block: string?, new_status: STATUS?, new_block: string?)? A function called by set_position and del_position.
local Map = class.classify("Map", {})
maps.Map = Map

--- Creates a new Map object.
---@param change_callback fun(position: Position, old_status: STATUS?, old_block: string?, new_status: STATUS?, new_block: string?)? An optional function that will be called when the map is updated.
function Map:__init(change_callback)
    self.status = {}
    self.blocks = {}
    self.size = 0
    self.generate_events = false
    self.sync_agents = {}
    self.change_callback = change_callback
end

--- Returns a string representation of the Map object.
---@return string str The string representation of the Map object.
function Map:__tostring()
    -- Get memory address using the superclass tostring(self)
    return class.Object.__tostring(self).."["..tostring(self.size).."]"
end

--- Sets the information of a position in the map.
---@param pos Position The position to set the information of.
---@param status number The status to set, which can be EMPTY, SOLID or BARRIER.
---@param block_type string? The type of block at the position, if applicable.
function Map:set_position(pos, status, block_type)
    if not class.isinstance(pos, Position) then
        error("pos must be a Position object", 2)
    end
    if type(status) ~= "number" then
        error("status must be a number, not '" .. type(status) .. "'", 2)
    end
    if block_type ~= nil and type(block_type) ~= "string" then
        error("block_type must be a string, not '" .. type(block_type) .. "'", 2)
    end
    if status == maps.STATUS.SOLID and block_type == nil then
        error("block_type cannot be nil if status is SOLID", 2)
    end
    if status == maps.STATUS.EMPTY and block_type ~= nil then
        error("block type must be nil when status is EMPTY", 2)
    end
    if status ~= maps.STATUS.EMPTY and status ~= maps.STATUS.SOLID and status ~= maps.STATUS.BARRIER then
        error("status must be either EMPTY(" .. maps.STATUS.EMPTY .. "), SOLID(" .. maps.STATUS.SOLID .. "), or BARRIER(" .. maps.STATUS.BARRIER .. ")", 2)
    end
    local h = pos:hash()
    if self.status[h] == nil then
        self.size = self.size + 1
    end
    local old_status, old_block = self.status[h], self.blocks[h]
    self.status[h] = status
    if block_type ~= nil then
        self.blocks[h] = block_type
    else
        self.blocks[h] = nil
    end
    if self.change_callback ~= nil then
        self.change_callback(pos, old_status, old_block, status, block_type)
    end
    for sync_agent, enabled in pairs(self.sync_agents) do
        sync_agent(pos, status, block_type)
    end
end

--- Deletes the information of a position in the map, making it unknown again.
---@param pos Position The position to delete the information of.
---@return number? old_status The status of the deleted position.
---@return string? old_block The block type at the deleted position.
function Map:del_position(pos)
    if not class.isinstance(pos, Position) then
        error("pos must be a Position object", 2)
    end
    local h = pos:hash()
    local old_status, old_block = nil, nil
    if self.status[h] ~= nil then
        old_status = self.status[h]
        old_block = self.blocks[h]
        self.status[h] = nil
        self.blocks[h] = nil
        self.size = self.size - 1
    end
    if self.change_callback ~= nil then
        self.change_callback(pos, old_status, old_block, nil, nil)
    end
    for sync_agent, enabled in pairs(self.sync_agents) do
        sync_agent(pos)
    end
    return old_status, old_block
end

--- Returns the information of a position in the map.
---@param pos Position The position to retrieve the information of.
---@return number? status The status of the position.
---@return string? block The block type at the position.
function Map:get_position(pos)
    if not class.isinstance(pos, Position) then
        error("pos must be a Position object", 2)
    end
    local h = pos:hash()
    return self.status[h], self.blocks[h]
end

--- Implements map[position]. Equivalent to map:getPosition(position).
---@param pos Position The position to retrieve the information of.
---@return [number, string?]? status_and_block_type The status and block type as a tuple. One or the whole may be nil.
function Map:__getindex(pos)
    if class.isinstance(pos, Position) then
        local status, block = self:get_position(pos)
        if status == nil then
            return nil
        end
        return {status, block}
    end
    return class.Object.__getindex(self, pos)
end

--- Implements map[position] = value. Value can be nil (deleting information), a single number (an EMPTY status), a tuple of number and string (a status an a block type).
---@param pos Position The position to set the information of.
---@param info nil|number|[number, string] The new information (unknown, empty or a new block state).
function Map:__setindex(pos, info)
    if class.isinstance(pos, Position) then
        if info == nil then
            return self:del_position(pos)
        end
        if type(info) == "number" then
            if info ~= maps.STATUS.EMPTY then
                error("cannot set a non-EMPTY status without block type information", 2)
            end
            return self:set_position(pos, maps.STATUS.EMPTY)
        end
        if type(info) == "table" and #info == 2 and type(info[1]) == "number" and type(info[2]) == "string" then
            local status, block = info[1], info[2]
            if status ~= maps.STATUS.SOLID and status ~= maps.STATUS.BARRIER then
                error("cannot set position with block info on a status other than SOLID or BARRIER", 2)
            end
            return self:set_position(pos, status, block)
        end
        error("invalid parameters for setting position: "..tostring(info), 2)
    end
    return class.Object.__setindex(self, pos, info)
end


---@alias next_return {[1]: number, [2]: string}
--- Returns a position-information iterator over the map.
---@return fun(map: Map, pos: Position?): Position?, next_return? next The next function.
---@return Map self The map itself.
---@return nil first_index The first nil index.
function Map:positions()
    ---@param map Map
    ---@param pos Position?
    local function map_next(map, pos)
        local next_pos, status = next(map.status, pos)
        if next_pos then
            return next_pos, {status, map.blocks[pos]}
        end
    end
    return map_next, self, nil
end

--- Default function to check that a turtle can go through a given position in the given map.
---@param map Map The map to get the information from.
---@param position Position The position to check.
---@return boolean walkable If the position can be traversed by the turtle.attack
function maps.DEFAULT_PATH_CONDITION_CHECK(map, position)
    if not class.isinstance(map, Map) then
        error("expected map as argument #1, got '"..type(map).."'", 2)
    end
    if not class.isinstance(position, Position) then
        error("expected position as argument #2, got '"..type(position).."'", 2)
    end
    if map[position][1] == nil then
        return false
    end
    return map[position][1] == maps.STATUS.EMPTY
end

local MAX_PATH_SEARCH_OPERATIONS = 250

--- Returns a path as a list of positions to go from position 1 to position 2. Uses an A* algorithm.
---@param start_pos Position The starting position.
---@param start_direction DIRECTION The starting direction.
---@param destination_pos Position The destination position.
---@param destination_direction DIRECTION? The optional destination direction. Set to nil to just reach the destination position no matter the destination direction.
---@param condition (fun(map: Map, position: Position) : boolean)? A function to check that a given position can be traversed. Defaults to checking that that position is empty and known.
---@param costs {turning: number, forward: number, up: number, down: number}? A table with values for "turning", "forward", "up" and "down" indicating the costs of these movements for computing the path. Defaults to 4 for moving and 3 for turning
---@return Position[]? path A shortest path from the starting point to the destination if a valid one exists (nil otherwise).
function Map:find_path(start_pos, start_direction, destination_pos, destination_direction, condition, costs)
    if condition == nil then
        condition = maps.DEFAULT_PATH_CONDITION_CHECK
    end
    if costs == nil then
        costs = {}
    end
    local turning_cost = costs.turning ~= nil and costs.turning or 3
    local up_cost = costs.up ~= nil and costs.up or 4
    local down_cost = costs.down ~= nil and costs.down or 4
    local forward_cost = costs.forward ~= nil and costs.forward or 4

    if not condition(self, destination_pos) then
        return
    end

    local cache = {}
    --- A cached wrapped of the condition function
    ---@param pos Position
    ---@return boolean
    local function check_pos(pos)
        local h = pos:hash()
        if cache[h] ~= nil then
            return cache[h]
        end
        local ok = condition(self, pos)
        cache[h] = ok
        return ok
    end

    -- NOTE: distances are counted times 4! a single move (above, below, forward) counts for 4. A turn left or right counts for 3!


    local NO_RUSH_DISTANCE = 10
    --- A heuristic for A* to evaluate the distance to the objective.
    ---@param pos Position
    ---@return number distance
    local function distance_to_destination_heuristic(pos)
        local d = destination_pos:manhattan_distance_to(pos)
        if d < NO_RUSH_DISTANCE then
            return d * 4
        else
            return d * (4 + math.log(1 + (d - NO_RUSH_DISTANCE) ^ 2) * 0.15)
        end
    end

    --- A function hash a (Position, direction) pair.
    ---@param pos Position
    ---@param dir DIRECTION
    ---@return string hash
    local function hash_pair(pos, dir)
        return pos:hash()..";"..dir
    end

    local start_hash = hash_pair(start_pos, start_direction)

    local to_do_heap = heap.Heap(function(h) return h end) ---@type Heap<string> The binary heap for fast queue operations.
    to_do_heap:push(start_hash, distance_to_destination_heuristic(start_pos))
    local to_do_pos = {[start_hash] = start_pos} ---@type {string: Position} The positions to look at.
    local to_do_dir = {[start_hash] = start_direction} ---@type {string: DIRECTION} The directions to look at.
    local parents_pos = {} ---@type {string: Position} The previous positions to rebuild the path.
    local parents_dir = {} ---@type {string: DIRECTION} The previous directions to rebuild the path.
    local cost = {[start_hash] = 0} ---@type {string: number} The score of the shortest path to each (position, direction) pair.
    local heuristic = {[start_hash] = distance_to_destination_heuristic(destination_pos)} ---@type {string: number} The heuristic score for reaching the destination by passing by this position.

    --- Evaluates the cost of comming to this next position and direction and updates it if it is better.
    ---@param current_pos Position
    ---@param current_dir number
    ---@param next_pos Position
    ---@param next_dir number
    ---@param next_hash string
    ---@param next_cost number
    local function evaluate_and_update_tentative(current_pos, current_dir, next_pos, next_dir, next_hash, next_cost)
        if next_cost < (cost[next_hash] or math.huge) then
            parents_pos[next_hash] = current_pos
            parents_dir[next_hash] = current_dir
            cost[next_hash] = next_cost
            heuristic[next_hash] = next_cost + distance_to_destination_heuristic(next_pos)
            to_do_heap:push(next_hash, heuristic[next_hash])
            to_do_pos[next_hash] = next_pos
            to_do_dir[next_hash] = next_dir
        end
    end

    local current_hash = to_do_heap:pop()
    local n_op = 0

    while current_hash ~= nil do

        n_op = n_op + 1
        if n_op > MAX_PATH_SEARCH_OPERATIONS then
            os.tick()
            n_op = 0
        end

        -- Find the next point
        local current_pos = to_do_pos[current_hash]
        to_do_pos[current_hash] = nil
        local current_dir = to_do_dir[current_hash]
        to_do_dir[current_hash] = nil

        -- We reached the destination. Build the path.
        if current_pos == destination_pos and (destination_direction == nil or destination_direction == current_dir) then
            local reversed_path = {}
            local temp_pos = current_pos
            local temp_dir = current_dir
            local last = nil
            while temp_pos and temp_dir do
                if last ~= temp_pos then
                    table.insert(reversed_path, temp_pos)
                end
                last = temp_pos
                local parent_hash = hash_pair(temp_pos, temp_dir)
                temp_pos = parents_pos[parent_hash]
                temp_dir = parents_dir[parent_hash]
            end
            local path = {}
            for i = 1, #reversed_path do
                path[i] = reversed_path[#reversed_path - i + 1]
            end
            return path
        end

        to_do_pos[current_hash] = nil
        to_do_dir[current_hash] = nil

        -- Explore neighbors (which are forward, below and above and turning left or right)
        -- Above
        local next_pos = current_pos:above()
        if check_pos(next_pos) then
            local next_hash = hash_pair(next_pos, current_dir)
            evaluate_and_update_tentative(current_pos, current_dir, next_pos, current_dir, next_hash, cost[current_hash] + up_cost)
        end

        -- Below
        local next_pos = current_pos:below()
        if check_pos(next_pos) then
            local next_hash = hash_pair(next_pos, current_dir)
            evaluate_and_update_tentative(current_pos, current_dir, next_pos, current_dir, next_hash, cost[current_hash] + down_cost)
        end

        -- Forward
        local next_pos = current_pos:in_direction(current_dir)
        if check_pos(next_pos) then
            local next_hash = hash_pair(next_pos, current_dir)
            evaluate_and_update_tentative(current_pos, current_dir, next_pos, current_dir, next_hash, cost[current_hash] + forward_cost)
        end

        -- Right
        local next_dir = current_dir + 1
        if next_dir == 4 then
            next_dir = 0
        end
        local next_hash = hash_pair(current_pos, next_dir)
        evaluate_and_update_tentative(current_pos, current_dir, current_pos, next_dir, next_hash, cost[current_hash] + turning_cost)

        -- Left
        local next_dir = current_dir - 1
        if next_dir == -1 then
            next_dir = 3
        end
        local next_hash = hash_pair(current_pos, next_dir)
        evaluate_and_update_tentative(current_pos, current_dir, current_pos, next_dir, next_hash, cost[current_hash] + turning_cost)

        current_hash = to_do_heap:pop()
    end

    return nil

end

--- Synchronizes all map updates through the given sync agent.
---@param sync_agent fun(pos: Position, status: STATUS?, block: string?): boolean A function called at each map update. It will stop being called when it returns false.
---@return fun(): boolean, string? status A function to get the status of the agent. Returns true if the agent is still active, false if it stopped, plus an error message if there was an error.
function Map:sync(sync_agent)
    if type(sync_agent) ~= "function" then
        error("expected function for first argument, got '"..type(sync_agent).."'", 2)
    end
    local running, err = true, nil

    --- A wrapped agent that unregisters itself.
    ---@param pos Position
    ---@param status STATUS?
    ---@param block string?
    local function wrapped_agent(pos, status, block)
        local ok, keep = pcall(sync_agent, pos, status, block)
        if not ok then
            running = false
            err = keep
        end
        if not keep then
            running = false
        end
        if not running then
            self.sync_agents[wrapped_agent] = nil
        end
    end
    self.sync_agents[wrapped_agent] = true

    return function ()
        return running, err
    end
end

local MAX_LINES_READ_OPERATION = 20

--- Synchronizes this map with the given file. Loads the file content at first, then writes efficiently any map update to it.
---@param path string The file path.
---@param loading_finished_callback fun(new: boolean)? A function that will get called when the loading of the map is finished. If the map is new (map file did not exist), passes true to this function, otherwise, passes false.
---@return fun() close A function to close the file and stop the synchronization.
function Map:file_sync(path, loading_finished_callback)
    if type(path) ~= "string" then
        error("expected string for first argument, got '"..type(path).."'", 2)
    end
    if loading_finished_callback ~= nil and type(loading_finished_callback) ~= "function" then
        error("expected function or nil for second argument, got '"..type(loading_finished_callback).."'", 2)
    end
    local file
    if fs.exists(path) and fs.isDir(path) then
        error("file exists and is a directory", 2)
    end
    local map_is_new = false
    if fs.exists(path) then
        file = fs.open(path, "r+b")
    else
        file = fs.open(path, "w+b")
        map_is_new = true
    end

    local pending_updates = {}
    local loading_updates = {}
    local loading_complete = false
    --- A temporary agent for the time when we are still loading the map from an existing file.
    ---@param pos Position
    ---@param status STATUS?
    ---@param block string?
    local function temporary_agent(pos, status, block)
        local h = pos:hash()
        if loading_updates[h] == nil or loading_updates[h][1] ~= status or loading_updates[h][2] ~= block then
            table.insert(pending_updates, {pos, status, block})
        end
        return not loading_complete
    end
    self:sync(temporary_agent)

    -- File position caching for remembering where known positions are written, and if they can be updated
    local file_position_start_cache = {}    ---@type table<string, number> Associates to each position hash a position in the file to seek for starting reading/rewriting the map information for this position.
    local file_position_size_cache = {}     ---@type table<string, number> Associates to each position hash a byte size in the file for the length of the line containing the map information for this position.
    local file_end = 0

    -- Load the existing map information from the file
    local n_op = 0
    local fpos = 0
    local needs_rewriting = false
    for line in file.readLine do
        local new_fpos = file.seek()
        n_op = n_op + 1
        if n_op > MAX_LINES_READ_OPERATION then
            os.tick()
            n_op = 0
        end
        local parts = {}
        for part in string.gmatch(line, "([^;]+)") do
            table.insert(parts, part)
        end
        if #parts >= 4 then
            local x = tonumber(parts[1])
            local y = tonumber(parts[2])
            local z = tonumber(parts[3])
            local status = tonumber(parts[4])
            local block = (#parts >= 5 and parts[5] ~= "") and parts[5] or nil
            if x and y and z and status then
                local pos = Position(x, y, z)
                local h = pos:hash()
                loading_updates[h] = {status, block}
                self:set_position(pos, status, block)
                file_position_size_cache[h] = fpos
                file_position_size_cache[h] = new_fpos - fpos
            else
                needs_rewriting = true
            end
        else
            needs_rewriting = true
        end
        fpos = new_fpos
        file_end = new_fpos
    end

    if needs_rewriting then
        file.close()
        local temp_path = path .. ".tmp"
        if fs.exists(temp_path) then
            fs.delete(temp_path)
        end

        local temp_file = fs.open(temp_path, "w+b")
        local file_pos = 0
        local keys = {}
        for h in pairs(self.status) do
            table.insert(keys, h)
        end
        table.sort(keys)
        for _, h in ipairs(keys) do
            n_op = n_op + 1
            if n_op > MAX_LINES_READ_OPERATION then
                os.tick()
                n_op = 0
            end
            local x, y, z = h:match("^(%-?%d+);(%-?%d+);(%-?%d+)$")
            if x then
                local status = self.status[h]
                local block = self.blocks[h]
                local line = x .. ";" .. y .. ";" .. z .. ";" .. status
                if block ~= nil then
                    line = line .. ";" .. block
                end
                line = line .. "\n"
                temp_file.write(line)
                file_position_start_cache[h] = file_pos
                file_position_size_cache[h] = #line
                file_pos = file_pos + #line
            end
        end
        temp_file.close()

        if fs.exists(path) then
            fs.delete(path)
        end
        fs.move(temp_path, path)
        file = fs.open(path, "r+b")
        file_end = file_pos
    end

    loading_complete = true
    local active = true
    --- An updating agent for writing map updates to the file.
    --- If a position is already in the file (cache, tries to replace it in place). If it the new information is too long for the line, writes blank spaces in the line and writes the new info at the end of the file.
    --- If there is enough space to rewrite, the remaining space will also be convertes to a new line with blank spaces.
    --- If status is nil (forgetting) then, if the file contains information about the position, it should be erased.
    --- A new position is always added at the end of the file.
    --- Each operation updates the file positions, sizes caches and file size.
    ---@param pos Position
    ---@param status STATUS?
    ---@param block string?
    local function file_updating_sync_agent(pos, status, block)
        if not active then
            return false
        end

        local h = pos:hash()
        local start_pos = file_position_start_cache[h]
        local size = file_position_size_cache[h]

        if status == nil then
            if start_pos ~= nil and size ~= nil then
                file.seek("set", start_pos)
                if size > 1 then
                    file.write(string.rep(" ", size - 1))
                end
                file.write("\n")
                file_position_start_cache[h] = nil
                file_position_size_cache[h] = nil
            end
            return true
        end

        local line_data = h .. ";" .. status
        if block ~= nil then
            line_data = line_data .. ";" .. block
        end
        line_data = line_data .. "\n"
        local line_len = #line_data

        if start_pos ~= nil and size ~= nil then
            if line_len <= size then
                local fill = line_len < size and string.rep(" ", size - line_len - 1) .. "\n" or ""
                local line = line_data .. fill
                file.seek("set", start_pos)
                file.write(line)
                file_position_size_cache[h] = size
            else
                file.seek("set", start_pos)
                if size > 1 then
                    file.write(string.rep(" ", size - 1))
                end
                file.write("\n")
                file.seek("set", file_end)
                file.write(line_data)
                file_position_start_cache[h] = file_end
                file_position_size_cache[h] = line_len
                file_end = file_end + line_len
            end
        else
            file.seek("set", file_end)
            file.write(line_data)
            file_position_start_cache[h] = file_end
            file_position_size_cache[h] = line_len
            file_end = file_end + line_len
        end
        file.flush()

        return true
    end

    _G.status = self:sync(file_updating_sync_agent)

    for _, update in ipairs(pending_updates) do
        file_updating_sync_agent(update[1], update[2], update[3])
    end

    if loading_finished_callback ~= nil then
        loading_finished_callback(map_is_new)
    end

    return function ()
        active = false
        if file then
            file.close()
        end
    end
end

--- Dumps the map to a string.
---@return string serialized_map The serialized map.
function Map:dump()
    local keys = {}
    for h in pairs(self.status) do
        table.insert(keys, h)
    end
    table.sort(keys)

    local lines = {}
    for _, h in ipairs(keys) do
        local x, y, z = h:match("^(%%-?%%d+);(%%-?%%d+);(%%-?%%d+)$")
        if x then
            local status = self.status[h]
            local block = self.blocks[h]
            local line = x .. ";" .. y .. ";" .. z .. ";" .. status
            if block ~= nil then
                line = line .. ";" .. block
            end
            table.insert(lines, line)
        end
    end

    if #lines == 0 then
        return ""
    end
    return table.concat(lines, "\n") .. "\n"
end

--- Loads a map from a serialized map. Works in place in the current Map object.
---@param serialized_map string The serialized map in a string.
function Map:load(serialized_map)
    if type(serialized_map) ~= "string" then
        error("serialized_map must be a string", 2)
    end

    self.status = {}
    self.blocks = {}
    self.size = 0

    for line in serialized_map:gmatch("([^\r\n]+)") do
        if line ~= "" then
            local parts = {}
            for part in string.gmatch(line, "([^;]+)") do
                table.insert(parts, part)
            end
            if #parts < 4 then
                error("invalid serialized map format", 2)
            end

            local x = tonumber(parts[1])
            local y = tonumber(parts[2])
            local z = tonumber(parts[3])
            local status = tonumber(parts[4])
            local block = (#parts >= 5 and parts[5] ~= "") and parts[5] or nil
            if x == nil or y == nil or z == nil or status == nil then
                error("invalid serialized map format", 2)
            end

            local pos = Position(x, y, z)
            self:set_position(pos, status, block)
        end
    end
end





return maps