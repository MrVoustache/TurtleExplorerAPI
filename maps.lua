--- This module provides functions for working with minecraft world absolute or relative positions, working with maps of knwown areas, and calculating distances and paths between positions.
--- 
--- For direction conventions, the positive x direction is east (direction 0), the positive y direction is up, and the positive z direction is south (direction 1). The negative x direction is west (direction 2), the negative y direction is down, and the negative z direction is north (direction 3).


_G.maps = {}

maps.EAST = 0
maps.SOUTH = 1
maps.WEST = 2
maps.NORTH = 3





---@class Position A position in the minecraft world, with x, y, and z coordinates.
---@field x number The x coordinate of the position.
---@field y number The y coordinate of the position.
---@field z number The z coordinate of the position.
local Position = {}
maps.Position = Position

Position.__index = Position
Position.__name = "Position"

--- Creates a new Position object.
---@param x number? The x coordinate of the position.
---@param y number? The y coordinate of the position.
---@param z number? The z coordinate of the position.
---@return Position pos The new Position object.
function Position:new(x, y, z)
    local pos = setmetatable({}, Position)
    if x == nil then x = 0 end
    if y == nil then y = 0 end
    if z == nil then z = 0 end
    if type(x) ~= "number" then error("x must be a number, not '" .. type(x) .. "'", 2) end
    if type(y) ~= "number" then error("y must be a number, not '" .. type(y) .. "'", 2) end
    if type(z) ~= "number" then error("z must be a number, not '" .. type(z) .. "'", 2) end
    pos.x = x
    pos.y = y
    pos.z = z
    return pos
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
    if type(pos2) ~= "table" or getmetatable(pos2) ~= Position then
        return rawequal(self, pos2)
    end
    return self.x == pos2.x and self.y == pos2.y and self.z == pos2.z
end

--- Returns a new Position object that represents the same point using absolute coordinates, given the coordinates and orientation of the corresponding original position.
---@param origin Position The original position with absolute coordinates.
---@param orientation number The orientation of the original east direction (0 if it was actually east, 1 if it was actually south, 2 if it was actually west, and 3 if it was actually north).
---@return Position pos The new Position object with absolute coordinates.
function Position:to_absolute(origin, orientation)
    if type(origin) ~= "table" or getmetatable(origin) ~= Position then
        error("expected position as argument #1, got '"..type(origin).."'", 2)
    end
    if type(orientation) ~= "number" then
        error("expected number as orientation, got '"..type(orientation).."'", 2)
    end
    local newX, newY, newZ
    if orientation == maps.EAST then
        newX = origin.x + self.x
        newY = origin.y + self.y
        newZ = origin.z + self.z
    elseif orientation == maps.SOUTH then
        newX = origin.x - self.z
        newY = origin.y + self.y
        newZ = origin.z + self.x
    elseif orientation == maps.WEST then
        newX = origin.x - self.x
        newY = origin.y + self.y
        newZ = origin.z - self.z
    elseif orientation == maps.NORTH then
        newX = origin.x + self.z
        newY = origin.y + self.y
        newZ = origin.z - self.x
    else
        error("invalid orientation value", 2)
    end
    return Position:new(newX, newY, newZ)
end

--- Returns the next position above.
---@return Position above The above position.
function Position:above()
    return Position:new(self.x, self.y + 1, self.z)
end

--- Returns the next position below.
---@return Position below The below position.
function Position:below()
    return Position:new(self.x, self.y - 1, self.z)
end

--- Returns the next eastern position (positive x).
---@return Position east The eastern position.
function Position:east()
    return Position:new(self.x + 1, self.y, self.z)
end

--- Returns the next southern position (positive z).
---@return Position south The southern position.
function Position:south()
    return Position:new(self.x, self.y, self.z + 1)
end

--- Returns the next western position (negative x).
---@return Position west The west position.
function Position:west()
    return Position:new(self.x - 1, self.y, self.z)
end

--- Returns the next northern position (negative x).
---@return Position north The north position.
function Position:north()
    return Position:new(self.x, self.y, self.z - 1)
end

--- Returns the next block in the given cardinal direction.
---@param dir number The direction (a constant like maps.EAST).
---@return Position next_block The next position in the given direction.
function Position:in_direction(dir)
    if dir == maps.EAST then
        return self:east()
    elseif dir == maps.SOUTH then
        return self:south()
    elseif dir == maps.WEST then
        return self:west()
    elseif dir == maps.NORTH then
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
            return Position:new(x + 1, y, z)
        elseif i == 2 then
            return Position:new(x - 1, y, z)
        elseif i == 3 then
            return Position:new(x, y + 1, z)
        elseif i == 4 then
            return Position:new(x, y - 1, z)
        elseif i == 5 then
            return Position:new(x, y, z + 1)
        elseif i == 6 then
            return Position:new(x, y, z - 1)
        end
    end
end

function Position:direction_to(pos)
    if type(pos) ~= "table" or getmetatable(pos) ~= Position then
        error("expected position as argument #1, got '"..type(pos).."'", 2)
    end
    if self:manhattan_distance_to(pos) ~= 1 then
        error("to compute a direction, the two blocks must be at a Manhattan distance of exactly 1", 2)
    end
    if pos.x > self.x then
        return maps.EAST
    elseif pos.z > self.z then
        return maps.SOUTH
    elseif self.x > pos.x then
        return maps.WEST
    elseif self.z > pos.z then
        return maps.NORTH
    else
        error("a cardinal direction only exists for horizontal directions, not above or below", 2)
    end
end

--- Calculates the Euclidean distance between two positions.
---@param pos1 Position The first position.
---@param pos2 Position The second position.
---@return number distance The Euclidean distance between the two positions.
function maps.euclidean_distance(pos1, pos2)
    if type(pos1) ~= "table" or getmetatable(pos1) ~= Position then
        error("expected position as argument #1, got '"..type(pos1).."'", 2)
    end
    if type(pos2) ~= "table" or getmetatable(pos2) ~= Position then
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
    if type(pos1) ~= "table" or getmetatable(pos1) ~= Position then
        error("expected position as argument #1, got '"..type(pos1).."'", 2)
    end
    if type(pos2) ~= "table" or getmetatable(pos2) ~= Position then
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
---@return number orientation The absolute direction of the east direction (0 if it is actually east, 1 if it is actually south, 2 if it is actually west, and 3 if it is actually north).
function maps.get_absolute_orientation(relative1, absolute1, relative2, absolute2)
    if type(relative1) ~= "table" or getmetatable(relative1) ~= Position then
        error("expected position as argument #1, got '"..type(relative1).."'", 2)
    end
    if type(absolute1) ~= "table" or getmetatable(absolute1) ~= Position then
        error("expected position as argument #2, got '"..type(absolute1).."'", 2)
    end
    if type(relative2) ~= "table" or getmetatable(relative2) ~= Position then
        error("expected position as argument #3, got '"..type(relative2).."'", 2)
    end
    if type(absolute2) ~= "table" or getmetatable(absolute2) ~= Position then
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
        return maps.EAST
    elseif dxr == -dza and dzr == dxa then
        return maps.SOUTH
    elseif dxr == -dxa and dzr == -dza then
        return maps.WEST
    elseif dxr == dza and dzr == -dxa then
        return maps.NORTH
    else
        error("the four positions belong to more than two orientations", 2)
    end
end

--- Returns a transformation function to convert relative positions to absolute positions given the coordinates and orientation of the corresponding original position or the relative and absolute positions of two points.
---@param origin Position The original position with absolute coordinates.
---@param orientation_or_relative_position number|Position The orientation of the original east direction (0 if it is actually east, 1 if it is actually south, 2 if it is actually west, and 3 if it is actually north) or the relative position corresponding to the original position.
---@param absolute_position Position? The absolute position corresponding to the second relative position, required if the second argument is a relative position.
---@return fun(relative_position : Position): Position transform A function that takes a relative position and returns the corresponding absolute position.
function maps.get_relative_to_absolute_transform(origin, orientation_or_relative_position, absolute_position)
    if type(origin) ~= "table" or getmetatable(origin) ~= Position then
        error("expected position as argument #1, got '"..type(origin).."'", 2)
    end
    local orientation
    if type(orientation_or_relative_position) == "number" then
        orientation = orientation_or_relative_position
    elseif type(orientation_or_relative_position) == "table" and getmetatable(orientation_or_relative_position) == Position then
        if absolute_position == nil then
            error("absolute_position is required when the second argument is a relative position", 2)
        end
        orientation = maps.get_absolute_orientation(orientation_or_relative_position, origin, Position:new(), absolute_position)
    else
        error("orientation_or_relative_position must be either a number or a Position object", 2)
    end
    return function(relative_position)
        return relative_position:to_absolute(origin, orientation)
    end
end

--- Returns the Manhattan distance to another position
---@param other Position The other position.
---@return number distance The distance between the calling Position and the other Position.
function Position:manhattan_distance_to(other)
    if type(other) ~= "table" or getmetatable(other) ~= Position then
        error("expected position as argument #1, got '"..type(other).."'", 2)
    end
    return maps.manhattan_distance(self, other)
end

--- Returns the Euclidean distance to another position
---@param other Position The other position.
---@return number distance The distance between the calling Position and the other Position.
function Position:euclidian_distance_to(other)
    if type(other) ~= "table" or getmetatable(other) ~= Position then
        error("expected position as argument #1, got '"..type(other).."'", 2)
    end
    return maps.euclidean_distance(self, other)
end

Position.distance_to = Position.euclidian_distance_to

--- Returns an iterator of Positions that are in the cubic area bounded by the two given positions.
---@param pos1 Position The first bounding position (the first to be yielded).
---@param pos2 Position The second bounding position (the last to be yielded).
---@return fun(): Position? iterator An iterator function that yields all positions in the box bounded by the two given positions.
function maps.bounded_positions(pos1, pos2)
    if type(pos1) ~= "table" or getmetatable(pos1) ~= Position then
        error("expected position as argument #1, got '"..type(pos1).."'", 2)
    end
    if type(pos2) ~= "table" or getmetatable(pos2) ~= Position then
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
                    coroutine.yield(Position:new(x, y, z))
                end
            end
        end
    end
    return coroutine.wrap(function() return iterator(pos1.x, pos2.x, dx, pos1.y, pos2.y, dy, pos1.z, pos2.z, dz) end)
end

--- Returns a short string representation of a position for hashing.
---@return string hash The string to hash to represent the position in a table.
function Position:hash()
    return self.x ..";"..self.y..";"..self.z
end





maps.EMPTY = 0
maps.SOLID = 1
maps.LIQUID = 2
maps.BARRIER = 3
maps.UNKNOWN_BLOCK_TYPE = "<unknown>"
---@class Map A map of a known area in the minecraft world, with information about blocks and properties of the area.
---@field status {Position: number} A table mapping positions to their status, which can be "empty", "solid", "liquid", or "barrier".
---@field blocks {Position: string} A table mapping positions to the type of block at that position, which can be any string representing a block type.
---@field size number The size of the map, which is the number of positions with known status or block type.
---@field generate_events boolean If events should be generated in case of map update.
---@field change_callback fun(position: Position, old_status: number?, old_block: string?, new_status: number?, new_block: string?)? A function called by set_position and del_position.
local Map = {}
maps.Map = Map

Map.__index = Map
Map.__name = "Map"

--- Creates a new Map object.
---@param change_callback fun(position: Position, old_status: number?, old_block: string?, new_status: number?, new_block: string?)? An optional function that will be called when the map is updated.
function Map:new(change_callback)
    local map = setmetatable({}, Map)
    map.status = {}
    map.blocks = {}
    map.size = 0
    map.generate_events = false
    map.change_callback = change_callback
    return map
end

--- Returns a string representation of the Map object.
---@return string str The string representation of the Map object.
function Map:__tostring()
    -- Get memory address using the superclass tostring(self)
    local ts = Map.__tostring
    Map.__tostring = nil
    local addr = tostring(self):match("table: (0x%x+)") or tostring(self)
    Map.__tostring = ts
    return string.format("%s[%d]", addr, self.size)
end

--- Sets the information of a position in the map.
---@param pos Position The position to set the information of.
---@param status number The status to set, which can be EMPTY, SOLID, LIQUID, or BARRIER.
---@param block_type string? The type of block at the position, if applicable.
function Map:set_position(pos, status, block_type)
    if type(pos) ~= "table" or getmetatable(pos) ~= Position then
        error("pos must be a Position object", 2)
    end
    if type(status) ~= "number" then
        error("status must be a number, not '" .. type(status) .. "'", 2)
    end
    if block_type ~= nil and type(block_type) ~= "string" then
        error("block_type must be a string, not '" .. type(block_type) .. "'", 2)
    end
    if (status == maps.EMPTY) ~= (block_type == nil) then
        error("block_type must be nil if status is EMPTY, and must be non-nil if status is not EMPTY", 2)
    end
    if status ~= maps.EMPTY and status ~= maps.SOLID and status ~= maps.LIQUID and status ~= maps.BARRIER then
        error("status must be either EMPTY(" .. maps.EMPTY .. "), SOLID(" .. maps.SOLID .. "), LIQUID(" .. maps.LIQUID .. "), or BARRIER(" .. maps.BARRIER .. ")", 2)
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
end

--- Deletes the information of a position in the map, making it unknown again.
---@param pos Position The position to delete the information of.
---@return number? old_status The status of the deleted position.
---@return string? old_block The block type at the deleted position.
function Map:del_position(pos)
    if type(pos) ~= "table" or getmetatable(pos) ~= Position then
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
    return old_status, old_block
end

--- Returns the information of a position in the map.
---@param pos Position The position to retrieve the information of.
---@return number? status The status of the position.
---@return string? block The block type at the position.
function Map:get_position(pos)
    if type(pos) ~= "table" or getmetatable(pos) ~= Position then
        error("pos must be a Position object", 2)
    end
    local h = pos:hash()
    return self.status[h], self.blocks[h]
end

--- Implements map[position]. Equivalent to map:getPosition(position).
---@param pos Position The position to retrieve the information of.
---@return [number, string?]? status_and_block_type The status and block type as a tuple. One or the whole may be nil.
function Map:__index(pos)
    if type(pos) == "table" and getmetatable(pos) == Position then
        local status, block = self:get_position(pos)
        if status == nil then
            return nil
        end
        return {status, block}
    end
    return rawget(maps.Map, pos)
end

--- Implements map[position] = value. Value can be nil (deleting information), a single number (an EMPTY status), a tuple of number and string (a status an a block type).
---@param pos Position The position to set the information of.
---@param info nil|number|[number, string] The new information (unknown, empty or a new block state).
function Map:__newindex(pos, info)
    if type(pos) == "table" and getmetatable(pos) == Position then
        if info == nil then
            return self:del_position(pos)
        end
        if type(info) == "number" then
            if info ~= maps.EMPTY then
                error("cannot set a non-EMPTY status without block type information", 2)
            end
            return self:set_position(pos, maps.EMPTY)
        end
        if type(info) == "table" and #info == 2 and type(info[1]) == "number" and type(info[2]) == "string" then
            local status, block = info[1], info[2]
            if status ~= maps.SOLID and status ~= maps.LIQUID and status ~= maps.BARRIER then
                error("cannot set position with block info on a status other than SOLID, LIQUID or BARRIER", 2)
            end
            return self:set_position(pos, status, block)
        end
        error("invalid parameters for setting position: "..tostring(info), 2)
    end
    return rawset(maps.Map, pos, info)
end

--- Default function to check that a turtle can go through a given position in the given map.
---@param map Map The map to get the information from.
---@param position Position The position to check.
---@return boolean walkable If the position can be traversed by the turtle.attack
function maps.DEFAULT_PATH_CONDITION_CHECK(map, position)
    if type(map) ~= "table" or getmetatable(map) ~= Map then
        error("expected map as argument #1, got '"..type(map).."'", 2)
    end
    if type(position) ~= "table" or getmetatable(position) ~= Position then
        error("expected position as argument #2, got '"..type(position).."'", 2)
    end
    if map[position][1] == nil then
        return false
    end
    return map[position][1] == maps.EMPTY
end

--- Returns a path as a list of positions to go from position 1 to position 2. Uses an A* algorithm.
---@param start_pos Position The starting position.
---@param start_direction number The starting orientation.
---@param destination_pos Position The destination position.
---@param destination_direction number? The optional destination orientation. Set to nil to just reach the destination position no matter the destination orientation.
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
        error("cannot reach destination position as it is rejected by the condition", 2)
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

    --- A heuristic for A* to evaluate the distance to the objective.
    ---@param pos Position
    ---@return number distance
    local function distance_to_destination_heuristic(pos)
        return destination_pos:manhattan_distance_to(pos) * 4 -- distances time 4!
    end

    --- A function hash a (Position, direction) pair.
    ---@param pos Position
    ---@param dir number
    ---@return string hash
    local function hash_pair(pos, dir)
        return pos:hash()..";"..dir
    end

    local start_hash = hash_pair(start_pos, start_direction)

    local to_do_heap = heap.Heap:new(function(h) return h end) ---@type Heap<string> The binary heap for fast queue operations.
    to_do_heap:push(start_hash, distance_to_destination_heuristic(start_pos))
    local to_do_pos = {[start_hash] = start_pos} ---@type {string: Position} The positions to look at.
    local to_do_dir = {[start_hash] = start_direction} ---@type {string: number} The directions to look at.
    local parents_pos = {} ---@type {string: Position} The previous positions to rebuild the path.
    local parents_dir = {} ---@type {string: number} The previous directions to rebuild the path.
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

    while current_hash ~= nil do

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

--- Saves the map using the given writer function.
---@param writer fun(data: string) A function to call to stream the content of the serialized map.
function Map:save(writer)
    if type(writer) ~= "function" then
        error("writer must be a function", 2)
    end
    
    -- Write header with size
    writer(tostring(self.size) .. "\n")
    
    -- Iterate through all positions and write them
    for pos_hash, status in pairs(self.status) do
        local block_type = self.blocks[pos_hash] or ""
        writer(pos_hash .. "|" .. tostring(status) .. "|" .. block_type .. "\n")
    end
end

--- Loads a map from an output stream.
---@param reader fun(): string? A function that returns strings from the stream (returns nil when empty).
function Map:load(reader)
    if type(reader) ~= "function" then
        error("reader must be a function", 2)
    end
    
    local buffer = ""
    local function get_line()
        while true do
            local newline_pos = buffer:find("\n")
            if newline_pos then
                local line = buffer:sub(1, newline_pos - 1)
                buffer = buffer:sub(newline_pos + 1)
                return line
            end
            local chunk = reader()
            if chunk == nil then
                if buffer ~= "" then
                    local line = buffer
                    buffer = ""
                    return line
                end
                return nil
            end
            buffer = buffer .. chunk
        end
    end
    
    -- Read header with size
    local header_line = get_line()
    if header_line == nil then
        return
    end
    local expected_size = tonumber(header_line)
    if expected_size == nil then
        error("invalid map header, expected size as first line", 2)
    end
    
    -- Read all position entries
    local line = get_line()
    while line ~= nil do
        local pos_hash, status_str, block_type = line:match("^([^|]*)|([^|]*)|(.*)$")
        if pos_hash and status_str then
            local status = tonumber(status_str)
            if status then
                if block_type == "" then
                    block_type = nil
                end
                self.status[pos_hash] = status
                if block_type then
                    self.blocks[pos_hash] = block_type
                end
            end
        end
        line = get_line()
    end
    
    -- Update size
    self.size = 0
    for _ in pairs(self.status) do
        self.size = self.size + 1
    end
end







return maps