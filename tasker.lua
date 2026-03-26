--- This module defines tasks that can be accomplished by turtles in different locations of the world, with different priorities.

local maps = require "maps"
local blocks = require "blocks"
local tasker = {}

---@enum TIMING_COST
tasker.TIMING_COST = {        --- Defines how urgent the task is and how the turtle may move to the location to accomplish the task.
    LIFE_OR_DEATH = -1,       --- The task cannot wait, it is a life or death matter. The turtle may go through liquids or unexplored regions.
    URGENT = 0,               --- The task must be performed as quickly as possible. The turtle cannot stop to perform any other task along the journey to the actual matter.
    QUICK = 1,                --- The task is to important but the turtle can stop to handle other tasks along the way as long as they do not imply that the turtle moves.
    AROUND = 2,               --- The task is not urgent and the turtle can turn around (but not move up/down/forward/backward) to perform another task along the way.
    NEAR = 3                  --- The task can wait and the turtle may move at most 2 blocks away to perform other tasks along the way.
}




---@class Task A task to perform somewhere with a priority and a status.
---@field active_map Map? The map the holds the knowledge required to perform the task. Will be given by the scheduler.
---@field check_on_move boolean If checking if the task can be accomplished is useful on turtle unrelated move. (Useful for tasks that may be done in many positions, but don't require to move.)
---@field enabled boolean If the task is currently enabled or not. Note that an enabled task must return at least one position when asked.
---@field identifier integer A unique identifier for the task.
---@field timing_cost TIMING_COST A value indicating if the turtle has time to perform other tasks along the way when getting to the location of the task. Can be one of tasker.TIMING_COST.URGENT, tasker.TIMING_COST.QUICK, tasker.TIMING_COST.AROUND, tasker.TIMING_COST.NEAR or tasker.TIMING_COST.LIFE_OR_DEATH.
---@field priority integer A value used to sort the different tasks. A task with lower priority will be executed before others.
---@field path_costs {turning: number, up: number, down: number, forward: number}? A table indicating the costs for building a path to a target destination od the task.
local Task = {}
Task.__name = "Task"
Task.__index = Task
setmetatable(Task, Task)
tasker.Task = Task
local identifier = 0

--- Creates a new task
function Task:new()
    local task = {}
    setmetatable(task, self or Task)
    task.check_on_move = false
    identifier = identifier + 1
    task.identifier = identifier
    task.enabled = false
    task.timing_cost = tasker.TIMING_COST.NEAR
    task.priority = 0
    return task
end

--- Tries to perform the task at the given position. If the position is not right, simply return false. If check_on_move is true, everytime the turtle moves, this function will be called.
---@param pos Position The current turtle position.
---@param direction DIRECTION The current turtle direction.
---@param freedom TIMING_COST? One of the three secondary objective limitation constants (tasker.TIMING_COST.QUICK, tasker.TIMING_COST.AROUND, tasker.TIMING_COST.NEAR) if the task was is being run as a secondary objective, or nil if the turtle went to the current position specifically for this task.
---@return boolean success If the entire task succeeded and is finished.
function Task:perform(pos, direction, freedom)
    error("subclasses of task must override this method", 2)
end

--- A function to call as a background coroutine, listening for events that should run while the task exists. Note that this thread will continue to run even if the task finishes, and is responsible for stopping on its own when the task finishes.
---@param map Map The map that this task is running on.
function Task:background_handler(map)
end

--- Returns an array of positions in which the task should lead the turtle to.
---@param current_position Position The current position of the turtle at the time of the request.
---@param current_direction DIRECTION The current orientation of the turtle at the time of the request.
---@return Position[] positions The positions that the turtle needs to go to to complete the task. It need to be a new table as it may get modified by the scheduler.
---@return DIRECTION[]? directions If necessary, the directions in which the turtle should look at when reaching any of the corresponding positions. It can be a table with number indexes only on the position indexes that require a specific orientation.
function Task:positions(current_position, current_direction)
    error("subclasses of task must override this method", 2)
end

--- Disables the task. It is removed from the scheduler's queue and put in its idle list.
function Task:disable()
    os.queueEvent("task_disabled", self)
end

--- Enables the task. It will be moved from the scheduler's idle list to its queue.
function Task:enable()
    os.queueEvent("task_enabled", self)
end

--- Changes a tasks's priority.
---@param new_priority integer The new task's priority.
function Task:change_priority(new_priority)
    if type(new_priority) ~= "number" then
        error("expected number, got '"..type(new_priority).."'", 2)
    end
    os.queueEvent("task_priority", self, new_priority)
end

--- Registers the task to be run by the scheduler. It is disabled at first.
function Task:register()
    os.queueEvent("task_register", self)
end

--- Called by the scheduler when the map knowledge changes on a given position. This function is only called when a map is or gets linked to the task.
---@param position Position? The position on which the map has changed. Is nil when the map is affected to the task.
function Task:on_map_update(position)
end

--- Called by the scheduler when the position or direction of the turtle changes.
---@param new_position Position The new position the turtle is at.
---@param new_direction DIRECTION The new direction the turtle is facing.
function Task:on_move(new_position, new_direction)
end

--- Called by the scheduler when the turtle was trying to move to a given target position and direction to accomplish this task, when the path was obstructed.
---@param target_pos Position The position that the task asked to reach.
---@param target_dir DIRECTION? The corresponding direction the task asked to reach.
---@param current_pos Position The current position where the turtle got stuck.
---@param current_dir DIRECTION The current direction.
---@return boolean? cancel If this function returns true, the ongoing scheduler will interrupt the process of reaching this position and will choose again a task to run.
function Task:on_path_obstructed(target_pos, target_dir, current_pos, current_dir)
end





--- Tells if the turtle can move safely through the block at the given coordinates according to the map, only going through known empty positions.
---@param m Map
---@param p Position
function tasker.walkable_safe(m, p)
    return m[p] ~= nil and m[p][1] == maps.STATUS.EMPTY
end

--- Tells if the turtle can possibly move through the block at the given coordinates according to the map, going through liquids and barriers.
---@param m Map
---@param p Position
function tasker.walkable_life_or_death(m, p)
    return m[p] == nil or m[p][1] == maps.STATUS.EMPTY or blocks.is_liquid(m[p][2])
end





return tasker