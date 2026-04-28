--- This module defines a simple task that orders the turtle to go to a specific location.

local tasker = require "tasker"
local maps   = require "maps"

local go_to = {}

---@class GoToTask: Task A subclass of Task that enables the turtle to travel to a specific location.
---@field target_position Position The position that the turtle should reach to complete the task.
---@field target_direction DIRECTION? The direction to face when arriving to the target position.
---@field arrived_callback fun()? A function to call once the turtle reaches the destination of the task.
---@field unreachable_callback fun()? A function to call if the scheduler cannot find a path to the destination.
local GoToTask = {}
GoToTask.__name = "GoToTask"
GoToTask.__index = GoToTask
setmetatable(GoToTask, {__index = tasker.Task})
go_to.GoToTask = GoToTask





--- Creates a new go_to task for the given target position.
---@param target_position Position The position to reach.
---@param target_direction DIRECTION? An optional direction to face when arriving at position.
---@param arrived_callback fun()? A function to call when the turtle reaches its destination. Can be nil.
---@param unreachable_callback fun()? A function to call if the scheduler cannot find a path to the destination. Can be nil.
function GoToTask:new(target_position, target_direction, arrived_callback, unreachable_callback)
    if type(target_position) ~= "table" or getmetatable(target_position) ~= maps.Position then
        error("expected Position for argument #1, got '"..type(target_position).."'", 2)
    end
    if target_direction ~= nil and type(target_direction) ~= "number" then
        error("expected number or nil for argument #2, got '"..type(target_direction).."'", 2)
    end
    if target_direction ~= nil and (math.floor(target_direction) ~= target_direction or target_direction < 0 or target_direction > 3) then
        error("expected maps.DIRECTION for argument #2, got "..tostring(target_direction))
    end
    if arrived_callback ~= nil and type(arrived_callback) ~= "function" then
        error("expected function or nil for argument #3, got '"..type(arrived_callback).."'", 2)
    end
    if unreachable_callback ~= nil and type(unreachable_callback) ~= "function" then
        error("expected function or nil for argument #4, got '"..type(unreachable_callback).."'", 2)
    end
    self = tasker.Task(self)
    setmetatable(self, GoToTask)
    self.target_position = target_position
    self.target_direction = target_direction
    self.arrived_callback = arrived_callback
    self.unreachable_callback = unreachable_callback
    return self
end

--- A simple function that prompts the user once the turtle has reached its destination.
function go_to.prompt_on_arrival()
    print("Arrived at position. Press any key to continue.")
    while true do
        local event = {os.pullEvent()}
        if event[1] == "key" then
            break
        end
    end
end





--- Tries to perform the task at the given position. If the position is not right, simply return false. If check_on_move is true, everytime the turtle moves, this function will be called.
---@param pos Position The current turtle position.
---@param direction DIRECTION The current turtle direction.
---@param freedom TIMING_COST? One of the three secondary objective limitation constants (tasker.TIMING_COST.QUICK, tasker.TIMING_COST.AROUND, tasker.TIMING_COST.NEAR) if the task was is being run as a secondary objective, or nil if the turtle went to the current position specifically for this task.
---@return boolean success If the entire task succeeded and is finished.
function GoToTask:perform(pos, direction, freedom)
    if self.arrived_callback ~= nil then
        pcall(self.arrived_callback)
    end
    return true
end

--- Called by the scheduler when it could not find a path to any of the positions returned by Task:positions and thus, the task cannot be accomplished for now.
---@param current_pos Position The current turtle position.
---@param current_dir DIRECTION The current turtle direction.
---@return boolean? disable If this function returns true, the scheduler disables the task.
function GoToTask:on_no_reacheable_positions(current_pos, current_dir)
    if self.unreachable_callback ~= nil then
        pcall(self.unreachable_callback)
    end
    return false
end

--- Returns an array of positions in which the task should lead the turtle to.
---@param current_position Position The current position of the turtle at the time of the request.
---@param current_direction DIRECTION The current orientation of the turtle at the time of the request.
---@return Position[] positions The positions that the turtle needs to go to to complete the task. It need to be a new table as it may get modified by the scheduler.
---@return DIRECTION[]? directions If necessary, the directions in which the turtle should look at when reaching any of the corresponding positions. It can be a table with number indexes only on the position indexes that require a specific orientation.
function GoToTask:positions(current_position, current_direction)
    return {self.target_position}, self.target_direction == nil and {} or {self.target_direction}
end





return go_to