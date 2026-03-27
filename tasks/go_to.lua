--- This module defines a simple task that orders the turtle to go to a specific location.

local tracker = require "tracker"
local tasker = require "tasker"
local maps   = require "maps"
local go_to = {}

---@class GoToTask: Task A subclass of Task that enables the turtle to travel to a specific location.
---@field target_position Position The position that the turtle should reach to complete the task.
---@field target_direction DIRECTION? The direction to face when arriving to the target position.
---@field prompt boolean If the turtle should display a prompt before moving on.
local GoToTask = {}
GoToTask.__name = "GoToTask"
GoToTask.__index = GoToTask
setmetatable(GoToTask, {__index = tasker.Task})
go_to.GoToTask = GoToTask





--- Creates a new go_to task for the given target position.
---@param target_position Position The position to reach.
---@param target_direction DIRECTION? An optional direction to face when arriving at position.
---@param prompt boolean? Whether or not to display a prompt one the destination has been reached. Defaults to true.
function GoToTask:new(target_position, target_direction, prompt)
    if type(target_position) ~= "table" or getmetatable(target_position) ~= maps.Position then
        error("expected Position for argument #1, got '"..type(target_position).."'", 2)
    end
    if target_direction ~= nil and type(target_direction) ~= "number" then
        error("expected number or nil for argument #2, got '"..type(target_direction).."'", 2)
    end
    if target_direction ~= nil and (math.floor(target_direction) ~= target_direction or target_direction < 0 or target_direction > 3) then
        error("expected maps.DIRECTION for argument #2, got "..tostring(target_direction))
    end
    if prompt == nil then
        prompt = true
    end
    if type(prompt) ~= "boolean" then
        error("expected boolean or nil for argument #3, got '"..type(prompt).."'", 2)
    end
    tasker.Task.new(self)
    self.target_position = target_position
    self.target_direction = target_direction
    self.prompt = prompt
end





--- Tries to perform the task at the given position. If the position is not right, simply return false. If check_on_move is true, everytime the turtle moves, this function will be called.
---@param pos Position The current turtle position.
---@param direction DIRECTION The current turtle direction.
---@param freedom TIMING_COST? One of the three secondary objective limitation constants (tasker.TIMING_COST.QUICK, tasker.TIMING_COST.AROUND, tasker.TIMING_COST.NEAR) if the task was is being run as a secondary objective, or nil if the turtle went to the current position specifically for this task.
---@return boolean success If the entire task succeeded and is finished.
function GoToTask:perform(pos, direction, freedom)
    if self.prompt then
        print("Arrived at position. Press any key to continue.")
        while true do
            local event = {os.pullEvent()}
            if event[1] == "key" then
                break
            end
        end
    end
    return true
end

--- Returns an array of positions in which the task should lead the turtle to.
---@param current_position Position The current position of the turtle at the time of the request.
---@param current_direction DIRECTION The current orientation of the turtle at the time of the request.
---@return Position[] positions The positions that the turtle needs to go to to complete the task. It need to be a new table as it may get modified by the scheduler.
---@return DIRECTION[]? directions If necessary, the directions in which the turtle should look at when reaching any of the corresponding positions. It can be a table with number indexes only on the position indexes that require a specific orientation.
function GoToTask:positions(current_position, current_direction)
    return {self.target_position}, self.target_direction == nil and {} or {self.target_direction}
end