--- This module defines a subclass of Task that helps the turtle explore its environment.

local tracker = require "tracker"
local tasker = require "tasker"
local maps   = require "maps"
local explorer = {}





---@class ExplorationTask: Task A subclass of Task that enables the turtle to explore its environment if possible. Should be run with low priority (10 by default).
---@field boundaries {[string]: Position} The positions that are in the borders of the map.
local ExplorationTask = {}
ExplorationTask.__name = "ExplorationTask"
ExplorationTask.__index = ExplorationTask
setmetatable(ExplorationTask, {__index = tasker.Task})
explorer.ExplorationTask = ExplorationTask





--- Creates a new exploration task with the given priority.
---@param priority number? The priority of exploration. Defaults to 10.
function ExplorationTask:new(priority)
    tasker.Task.new(self)
    if priority == nil then
        priority = 10
    end
    if type(priority) ~= "number" then
        error("expected number or nil for argument, got '"..type(priority).."'", 2)
    end
    self.priority = priority
    self.boundaries = {}
end





--- Internal function that expands the map boundaries by looking at the positions around the given one.
---@param task ExplorationTask
---@param pos Position
---@return Position[] added_blocks
local function update_map_boundaries(task, pos)
    local map = task.active_map
    if map == nil then
        return {}
    end
    if map[pos] ~= maps.STATUS.EMPTY then
        task.boundaries[pos:hash()] = nil
    end
    local added_blocks = {}
    local is_surrounded = true
    for neighbor_pos in pos:neighbors() do
        if map[neighbor_pos] == nil then
            is_surrounded = false
            break
        else
            if map[neighbor_pos] == maps.STATUS.EMPTY then
                local is_neighbor_surrounded = true
                for neighbor_neighbor_pos in neighbor_pos:neighbors() do
                    if map[neighbor_neighbor_pos] == nil then
                        is_neighbor_surrounded = false
                        break
                    end
                end
                if is_neighbor_surrounded then
                    task.boundaries[neighbor_pos:hash()] = nil
                else
                    task.boundaries[neighbor_pos:hash()] = neighbor_pos
                    table.insert(added_blocks, neighbor_pos)
                end
            end
        end
    end
    if is_surrounded then
        task.boundaries[pos:hash()] = nil
    end
    return added_blocks
end

--- Internal function to detect the positions to go to in order to explore the map more.
---@param task ExplorationTask
local function find_map_boundaries(task)
    local map = task.active_map
    if map == nil then
        return
    end
    local starting_pos = tracker.get_position()
    map[starting_pos] = maps.STATUS.EMPTY
    task.boundaries[starting_pos:hash()] = starting_pos
    local to_do = {starting_pos}        ---@type Position[]
    while #to_do > 0 do
        local next_pos = table.remove(to_do)
        local to_add = update_map_boundaries(task, next_pos)
        for index, pos_to_add in ipairs(to_add) do
            table.insert(to_do, pos_to_add)
        end
    end
end





--- Returns an array of positions in which the task should lead the turtle to.
---@param current_position Position The current position of the turtle at the time of the request.
---@param current_direction DIRECTION The current orientation of the turtle at the time of the request.
---@return Position[] positions The positions that the turtle needs to go to to complete the task. It need to be a new table as it may get modified by the scheduler.
---@return DIRECTION[]? directions If necessary, the directions in which the turtle should look at when reaching any of the corresponding positions. It can be a table with number indexes only on the position indexes that require a specific orientation.
function ExplorationTask:positions(current_position, current_direction)
    local map = self.active_map
    if map == nil then
        return {}
    end
    local positions, directions = {}, {}
    for h, pos in pairs(self.boundaries) do
        local pos_dir = {}
        if map[pos:east()] == nil then
            table.insert(pos_dir, maps.DIRECTION.EAST)
        end
        if map[pos:south()] == nil then
            table.insert(pos_dir, maps.DIRECTION.SOUTH)
        end
        if map[pos:west()] == nil then
            table.insert(pos_dir, maps.DIRECTION.WEST)
        end
        if map[pos:north()] == nil then
            table.insert(pos_dir, maps.DIRECTION.NORTH)
        end
        if #pos_dir > 0 then
            for index, dir in ipairs(pos_dir) do
                table.insert(positions, pos)
                directions[#positions] = dir
            end
        else
            table.insert(positions, pos)
        end
    end
    return positions, directions
end

--- Called by the scheduler when the map knowledge changes on a given position. This function is only called when a map is or gets linked to the task.
---@param position Position? The position on which the map has changed. Is nil when the map is affected to the task.
function ExplorationTask:on_map_update(position)
    if position == nil then
        find_map_boundaries(self)
    else
        update_map_boundaries(self, position)
    end
end

---@param pos Position The current turtle position.
---@param direction number The current turtle direction.
---@param freedom integer? One of the three secondary objective limitation constants (tasker.TIMING_COST.QUICK, tasker.TIMING_COST.AROUND, tasker.TIMING_COST.NEAR) if the task was is being run as a secondary objective, or nil if the turtle went to the current position specifically for this task.
---@return boolean success If the entire task succeeded and is finished.
function ExplorationTask:perform(pos, direction, freedom)
    if self.active_map == nil then
        return false
    end

    local above_status, above_block = table.unpack(self.active_map[pos:above()])
    if above_status == nil or (above_status == maps.STATUS.BARRIER and above_block == nil) then
        local ok, above_data = turtle.inspectUp()
        local new_status, new_block_data = nil, nil
        if ok then
            new_status = above_status == maps.STATUS.BARRIER and maps.STATUS.BARRIER or maps.STATUS.SOLID
            new_block_data = above_data.name
        else
            new_status = above_status == maps.STATUS.BARRIER and maps.STATUS.BARRIER or maps.STATUS.EMPTY
            new_block_data = nil
        end
        self.active_map[pos:above()] = {new_status, new_block_data}
    end

    local below_status, below_block = table.unpack(self.active_map[pos:below()])
    if below_status == nil or (below_status == maps.STATUS.BARRIER and below_block == nil) then
        local ok, below_data = turtle.inspectDown()
        local new_status, new_block_data = nil, nil
        if ok then
            new_status = below_status == maps.STATUS.BARRIER and maps.STATUS.BARRIER or maps.STATUS.SOLID
            new_block_data = below_data.name
        else
            new_status = below_status == maps.STATUS.BARRIER and maps.STATUS.BARRIER or maps.STATUS.EMPTY
            new_block_data = nil
        end
        self.active_map[pos:below()] = {new_status, new_block_data}
    end

    local function check_forward()
        local forward_status, forward_block = table.unpack(self.active_map[pos:forward(direction)])
        if forward_status == nil or (forward_status == maps.STATUS.BARRIER and forward_block == nil) then
            local ok, forward_data = turtle.inspect()
            local new_status, new_block_data = nil, nil
            if ok then
                new_status = forward_status == maps.STATUS.BARRIER and maps.STATUS.BARRIER or maps.STATUS.SOLID
                new_block_data = forward_data.name
            else
                new_status = forward_status == maps.STATUS.BARRIER and maps.STATUS.BARRIER or maps.STATUS.EMPTY
                new_block_data = nil
            end
            self.active_map[pos:forward(direction)] = {new_status, new_block_data}
        end
    end
    
    check_forward()
    if freedom == tasker.TIMING_COST.AROUND or freedom == tasker.TIMING_COST.NEAR then
        for i = 1, 3 do
            local ok, err = turtle.turnRight()
            if ok then
                check_forward()
            else
                break
            end
        end
    end

    return next(self.boundaries) == nil
end





return explorer