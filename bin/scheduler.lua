--- This script runs the explorer scheduler and allows the turtle to perform all the necessary actions.

if _G.scheduler ~= nil then
    printError("A scheduler is already running.")
    return
end
_G.scheduler = {}

local MAP_FILE = ".map"
local LOG_FILE = ".scheduler.log"
local LOG_TO_PRINT = {
    ["debug"] = false,
    ["info"] = false,
    ["warning"] = true,
    ["error"] = true,
    ["critical"] = true
}

FORGET_DELAY = 5.0

local active_tasks = heap.Heap:new(function (task) return tostring(task.identifier) end)        ---@type Heap<Task> The tasks to run.
local idle_tasks = {}                                                                           ---@type {integer: Task} The sleeping tasks.
local task_threads = {}                                                                         ---@type {integer: thread} The background threads of all the tasks.
local map_updated = false
local current_priority = math.mininteger or -math.huge
local current_task = nil            ---@type Task?

local blocks_to_forget = {}     ---@type {number: Position} Timer indentifiers corresponding to blocks to forget.

local moving_locked = false
local turting_locked = false
local lock_position = nil           ---@type Position?

local log_file = fs.open(LOG_FILE, "w")
log_file.writeLine("Started scheduler at "..textutils.formatTime(os.time()))





local function printColor(message, color)
    local old_color = term.getTextColor()
    term.setTextColor(color)
    print(message)
    term.setTextColor(old_color)
end

--- Logs a message from the scheduler.
---@param level "debug" | "info" | "warning" | "error" | "critical" The level of the log (debug, info, warning, error).bit
---@param message string The message itself.
local function log(level, message)
    if level == "debug" then
        if LOG_TO_PRINT["debug"] then
            printColor(message, colors.gray)
        end
        log_file.writeLine("[DEBUG]:"..textutils.formatTime(os.time())..":"..message)
        log_file.flush()
    elseif level == "info" then
        if LOG_TO_PRINT["debug"] then
            printColor(message, colors.white)
        end
        log_file.writeLine("[INFO]:"..textutils.formatTime(os.time())..":"..message)
        log_file.flush()
    elseif level == "warning" then
        if LOG_TO_PRINT["debug"] then
            printColor(message, colors.yellow)
        end
        log_file.writeLine("[WARNING]:"..textutils.formatTime(os.time())..":"..message)
        log_file.flush()
    elseif level == "error" then
        if LOG_TO_PRINT["debug"] then
            printColor(message, colors.orange)
        end
        log_file.writeLine("[ERROR]:"..textutils.formatTime(os.time())..":"..message)
        log_file.flush()
    elseif level == "critical" then
        if LOG_TO_PRINT["debug"] then
            printColor(message, colors.red)
        end
        log_file.writeLine("[CRITICAL]:"..textutils.formatTime(os.time())..":"..message)
        log_file.flush()
    else
        error("level should be one of 'debug', 'info', 'warning', 'error' or 'critical', got '"..tostring(level).."'", 2)
    end
end

--- Signals tasks that the map has changed at a specific position.
---@param pos Position The position of the update
local function signal_map_update(pos)
    for identifier, task in pairs(idle_tasks) do
        local ok, err = pcall(task.on_map_update, task, pos)
        if not ok then
            log("error", "task failed to execute its map update code: "..tostring(task))
        end
    end
    if active_tasks:acquire() then
        for task in active_tasks:iter() do
            local ok, err = pcall(task.on_map_update, task, pos)
            if not ok then
                log("error", "task failed to execute its map update code: "..tostring(task))
            end
        end
        active_tasks:release()
    end
end

local function signal_move()
    local pos, dir = tracker.get_position(), tracker.get_direction()
    for identifier, task in pairs(idle_tasks) do
        local ok, err = pcall(task.on_move, task, pos, dir)
        if not ok then
            log("error", "task failed to execute its move code: "..tostring(task))
        end
    end
    if active_tasks:acquire() then
        for task in active_tasks:iter() do
            local ok, err = pcall(task.on_move, task, pos, dir)
            if not ok then
                log("error", "task failed to execute its move code: "..tostring(task))
            end
        end
        active_tasks:release()
    end
end

--- Returns the list of active tasks that the scheduler is trying to accomplish.
---@return Task[] tasks The active tasks.
function scheduler.active_tasks()
    local tasks = {}
    while not active_tasks:acquire() do
        sleep(0.01)
    end
    for task in active_tasks:iter() do
        table.insert(tasks, task)
    end
    active_tasks:release()
    return tasks
end

--- Returns the list of idle (sleeping) tasks that the scheduler may have to run at some point.
---@return Task[] tasks The idle tasks.
function scheduler.idle_tasks()
    local tasks = {}
    for index, task in pairs(idle_tasks) do
        table.insert(tasks, task)
    end
    return tasks
end

--- Returns the task that the scheduler has selected as main task and is moving to perform or already performing.
---@return Task? current_task The current task if any.
function scheduler.current_task()
    return current_task
end





local old_forward = turtle.forward
function turtle.forward()
    if moving_locked then
        return false, "movement is locked for now"
    end
    if lock_position ~= nil and lock_position:manhattan_distance_to(tracker.get_position():in_direction(tracker.get_direction())) > 2 then
        return false, "this would get the turtle too far from its path"
    end
    local ok, err = old_forward()
    if ok then
        signal_move()
    end
    return ok, err
end

local old_back = turtle.back
function turtle.back()
    if moving_locked then
        return false, "movement is locked for now"
    end
    if lock_position ~= nil and lock_position:manhattan_distance_to(tracker.get_position():in_direction(-tracker.get_direction() % 4)) > 2 then
        return false, "this would get the turtle too far from its path"
    end
    local ok, err = old_back()
    if ok then
        signal_move()
    end
    return ok, err
end

local old_up = turtle.up
function turtle.up()
    if moving_locked then
        return false, "movement is locked for now"
    end
    if lock_position ~= nil and lock_position:manhattan_distance_to(tracker.get_position():above()) > 2 then
        return false, "this would get the turtle too far from its path"
    end
    local ok, err = old_up()
    if ok then
        signal_move()
    end
    return ok, err
end

local old_down = turtle.down
function turtle.down()
    if moving_locked then
        return false, "movement is locked for now"
    end
    if lock_position ~= nil and lock_position:manhattan_distance_to(tracker.get_position():below()) > 2 then
        return false, "this would get the turtle too far from its path"
    end
    local ok, err = old_down()
    if ok then
        signal_move()
    end
    return ok, err
end

local old_turn_left = turtle.turnLeft
function turtle.turnLeft()
    if turting_locked then
        return false, "turning is locked for now"
    end
    local ok, err = old_turn_left()
    if ok then
        signal_move()
    end
    return ok, err
end

local old_turn_right = turtle.turnRight
function turtle.turnRight()
    if turting_locked then
        return false, "turning is locked for now"
    end
    local ok, err = old_turn_right()
    if ok then
        signal_move()
    end
    return ok, err
end





--- Marks a position as empty after a certain amount of time.
---@param pos Position The position to mark empty.
local function forget_block(pos)
    blocks_to_forget[os.startTimer(FORGET_DELAY)] = pos
end

local function on_map_update(position, old_status, old_block, new_status, new_block)
    if type(new_block) == "string" and blocks.is_temporary(new_block) then
        log("debug", "Map temporarily updated.")
        forget_block(position)
    else
        log("debug", "Map updated.")
        map_updated = true
    end
end

local map = maps.Map:new(on_map_update)
if fs.exists(MAP_FILE) then
    local file = fs.open(MAP_FILE, "r")
    local function readline()
        local line = file.readLine()
        if line then
            return line.."\n"
        end
        return ""
    end
    local ok, err = pcall(maps.Map.load, map, readline)
    file.close()
    if not ok then
        log("warning", "Could load map file: "..err)
    else
        for pos, data in pairs(map) do
            if data[2] ~= nil and blocks.is_temporary(data[2]) then
                forget_block(pos)
            end
        end
    end
    if map == nil then
        error("could not load map for an unknown reason", 2)
    end
end

local function save_map()
    local file = fs.open(MAP_FILE, "w")
    map:save(file.write)
    file.close()
end





--- Adds a single block to become forbidden for the turtle.
---@param pos Position The block to forbid access to.
---@return boolean new If the block was added to the barrier or false if it was already one.
function scheduler.add_barrier_block(pos)
    if type(pos) ~= "table" or getmetatable(pos) ~= maps.Position then
        error("expected Position for argument, got '"..type(pos).."'", 2)
    end
    if map[pos] == nil or maps[pos][1] ~= maps.STATUS.BARRIER then
        map[pos] = {maps.STATUS.BARRIER, map[pos] ~= nil and map[pos][2] or nil}
        map_updated = true
        return true
    else
        return false
    end
end

--- Adds a wall of forbidden blocks for the turtle given two opposite corner blocks.
---@param pos1 Position The first corner.
---@param pos2 Position The opposite corner.
---@return integer added_blocks The number of new barrier blocks.
function scheduler.add_barrier_wall(pos1, pos2)
    if type(pos1) ~= "table" or getmetatable(pos1) ~= maps.Position then
        error("expected Position for argument #1, got '"..type(pos1).."'", 2)
    end
    if type(pos2) ~= "table" or getmetatable(pos2) ~= maps.Position then
        error("expected Position for argument #2, got '"..type(pos2).."'", 2)
    end
    if pos1.x ~= pos2.x and pos1.y ~= pos2.y and pos1.z ~= pos2.z then
        error("at least one coordinate should be equal between the two blocks, the three are different", 2)
    end
    local total_added = 0
    if pos1.x == pos2.x then
        local x, y1, y2, z1, z2 = pos1.x, math.min(pos1.y, pos2.y), math.max(pos1.y, pos2.y), math.min(pos1.z, pos2.z), math.max(pos1.z, pos2.z)
        for y = y1, y2 do
            for z = z1, z2 do
                total_added = total_added + scheduler.add_barrier_block(maps.Position:new(x, y, z))
            end
        end
    elseif pos1.y == pos2.y then
        local y, x1, x2, z1, z2 = pos1.y, math.min(pos1.x, pos2.x), math.max(pos1.x, pos2.x), math.min(pos1.z, pos2.z), math.max(pos1.z, pos2.z)
        for x = x1, x2 do
            for z = z1, z2 do
                total_added = total_added + scheduler.add_barrier_block(maps.Position:new(x, y, z))
            end
        end
    elseif pos1.z == pos2.z then
        local z, x1, x2, y1, y2 = pos1.z, math.min(pos1.x, pos2.x), math.max(pos1.x, pos2.x), math.min(pos1.y, pos2.y), math.max(pos1.y, pos2.y)
        for x = x1, x2 do
            for y = y1, y2 do
                total_added = total_added + scheduler.add_barrier_block(maps.Position:new(x, y, z))
            end
        end
    end
    return total_added
end

--- Adds a box of forbidden blocks for the turtle given two opposite corner blocks.
---@param pos1 Position The first corner.
---@param pos2 Position The opposite corner.
---@return integer added_blocks The number of new barrier blocks.
function scheduler.add_barrier_box(pos1, pos2)
    if type(pos1) ~= "table" or getmetatable(pos1) ~= maps.Position then
        error("expected Position for argument #1, got '"..type(pos1).."'", 2)
    end
    if type(pos2) ~= "table" or getmetatable(pos2) ~= maps.Position then
        error("expected Position for argument #2, got '"..type(pos2).."'", 2)
    end
    local total_added = 0
    total_added = total_added + scheduler.add_barrier_wall(maps.Position:new(pos1.x, pos1.y, pos1.z), maps.Position:new(pos1.x, pos2.y, pos2.z))
    total_added = total_added + scheduler.add_barrier_wall(maps.Position:new(pos1.x, pos1.y, pos1.z), maps.Position:new(pos2.x, pos1.y, pos2.z))
    total_added = total_added + scheduler.add_barrier_wall(maps.Position:new(pos1.x, pos1.y, pos1.z), maps.Position:new(pos2.x, pos2.y, pos1.z))
    total_added = total_added + scheduler.add_barrier_wall(maps.Position:new(pos2.x, pos1.y, pos1.z), maps.Position:new(pos2.x, pos2.y, pos2.z))
    total_added = total_added + scheduler.add_barrier_wall(maps.Position:new(pos1.x, pos2.y, pos1.z), maps.Position:new(pos2.x, pos2.y, pos2.z))
    total_added = total_added + scheduler.add_barrier_wall(maps.Position:new(pos1.x, pos1.y, pos2.z), maps.Position:new(pos2.x, pos2.y, pos2.z))
    return total_added
end





local function run_background_threads()
    while true do
        local event = {coroutine.yield()}
        for task_id, thread in pairs(task_threads) do
            if thread and coroutine.status(thread) ~= "dead" then
                coroutine.resume(thread, table.unpack(event))
            end
        end
    end
end





--- Updates the knowledge of the map at the given position.
---@param pos Position
---@param data {["name"]: string}?
local function update_map_knowledge(pos, data)
    local old_status, old_block = table.unpack(map[pos])
    local new_status, new_block = nil, nil
    if data ~= nil then

        new_status, new_block = maps.STATUS.SOLID, data["name"]
    else
        new_status, new_block = maps.STATUS.EMPTY, nil
    end
    if new_status ~= old_status or new_block ~= old_block then
        map[pos] = {new_status, new_block}
        signal_map_update(pos)
    end
end

local function forget_blocks()
    while true do
        local event = {coroutine.yield()}
        if event[1] == "timer" and blocks_to_forget[event[2]] then
            local pos = table.remove(blocks_to_forget, event[2])
            update_map_knowledge(pos, {})
        end
    end
end





--- Ensures the turtle is looking in the given direction
---@param direction number
local function ensure_direction(direction)
    local current_direction = tracker.get_direction()
    local rotation_diff = (direction - current_direction) % 4
    if rotation_diff == 1 then
        turtle.turnRight()
    elseif rotation_diff == 2 then
        turtle.turnRight()
        turtle.turnRight()
    elseif rotation_diff == 3 then
        turtle.turnLeft()
    end
end

--- Moves to the given location without stopping to handle any task along the way, going through liquids and unknown areas.
---@param destination Position The position to reach to accomplish to task.
---@param direction number? The eventual direction in which to arrive at the direction.
---@return boolean success If the turtle succesfully reached the destination.
local function move_to_LIFE_OR_DEATH(destination, direction)
    while tracker.get_position() ~= destination and (direction == nil or tracker.get_direction() == direction) do
        local path = map:find_path(tracker.get_position(), tracker.get_direction(), destination, direction, tasker.walkable_life_or_death)
        if path == nil then
            return false
        end
        local current = path[1]
        for i = 2, #path, 1 do
            local next = path[i]
            local ok1, ok2, err, data
            if current_task == nil then
                return false
            end
            if next == current:above() then
                ok1, err = turtle.up()
                if not ok1 then
                    ok2, data = turtle.inspectUp()
                    update_map_knowledge(next, data)
                end
            elseif next == current:below() then
                ok1, err = turtle.down()
                if not ok1 then
                    ok2, data = turtle.inspectDown()
                    update_map_knowledge(next, data)
                end
            else
                ensure_direction(current:direction_to(next))
                ok1, err = turtle.forward()
                if not ok1 then
                    ok2, data = turtle.inspect()
                    update_map_knowledge(next, data)
                end
            end
            if not ok1 then
                if current_task ~= nil then
                    local ok3, cancel_task = pcall(current_task.on_path_obstructed, current_task, destination, direction, tracker.get_position(), tracker.get_direction())
                    if not ok3 then
                        log("error", "task failed to acknowledge obstructed path: "..tostring(current_task))
                    elseif cancel_task then
                        return false
                    end
                end
                break
            end
        end
        if tracker.get_position() == destination and direction ~= nil then
            ensure_direction(direction)
        end
    end
    return true
end

--- Moves to the given location without stopping to handle any task along the way.
---@param destination Position The position to reach to accomplish to task.
---@param direction number? The eventual direction in which to arrive at the direction.
---@return boolean success If the turtle succesfully reached the destination.
local function move_to_URGENT(destination, direction)
    while tracker.get_position() ~= destination and (direction == nil or tracker.get_direction() == direction) do
        local path = map:find_path(tracker.get_position(), tracker.get_direction(), destination, direction, tasker.walkable_safe)
        if path == nil then
            return false
        end
        local current = path[1]
        for i = 2, #path, 1 do
            local next = path[i]
            local ok1, ok2, err, data
            if current_task == nil then
                return false
            end
            if next == current:above() then
                ok1, err = turtle.up()
                if not ok1 then
                    ok2, data = turtle.inspectUp()
                    update_map_knowledge(next, data)
                end
            elseif next == current:below() then
                ok1, err = turtle.down()
                if not ok1 then
                    ok2, data = turtle.inspectDown()
                    update_map_knowledge(next, data)
                end
            else
                ensure_direction(current:direction_to(next))
                ok1, err = turtle.forward()
                if not ok1 then
                    ok2, data = turtle.inspect()
                    update_map_knowledge(next, data)
                end
            end
            if not ok1 then
                if current_task ~= nil then
                    local ok3, cancel_task = pcall(current_task.on_path_obstructed, current_task, destination, direction, tracker.get_position(), tracker.get_direction())
                    if not ok3 then
                        log("error", "task failed to acknowledge obstructed path: "..tostring(current_task))
                    elseif cancel_task then
                        return false
                    end
                end
                break
            end
        end
        if tracker.get_position() == destination and direction ~= nil then
            ensure_direction(direction)
        end
    end
    return true
end

--- Moves to the given location. The turtle can stop along the way to complete other tasks, but not move or turn around.
---@param destination Position The position to reach to accomplish to task.
---@param direction number? The eventual direction in which to arrive at the direction.
---@return boolean success If the turtle succesfully reached the destination.
local function move_to_QUICK(destination, direction)

    --- Performs another task along the way, without allowing the turtle to move or turn around.
    ---@param task Task
    local function do_sub_task(task)
        if not task.check_on_move then
            return
        end
        moving_locked = true
        turting_locked = true
        local ok, err_or_task_finished = pcall(task.perform, task, tracker.get_position(), tracker.get_direction(), tasker.TIMING_COST.QUICK)
        moving_locked = false
        turting_locked = false
        if not ok then
            log("error", "sub-task failed: "..err_or_task_finished)
            active_tasks:remove(task)
        else
            if err_or_task_finished then
                log("debug", "sub task finished: "..tostring(task))
                active_tasks:remove(task)
            end
        end
    end

    while tracker.get_position() ~= destination and (direction == nil or tracker.get_direction() == direction) do
        local path = map:find_path(tracker.get_position(), tracker.get_direction(), destination, direction, tasker.walkable_safe)
        if path == nil then
            return false
        end
        local current = path[1]
        if active_tasks:acquire() then
            for task in active_tasks:iter(current_priority) do
                do_sub_task(task)
            end
            active_tasks:release()
        end
        for i = 2, #path, 1 do
            local next = path[i]
            local ok1, ok2, err, data
            if current_task == nil then
                return false
            end
            if next == current:above() then
                ok1, err = turtle.up()
                if not ok1 then
                    ok2, data = turtle.inspectUp()
                    update_map_knowledge(next, data)
                end
            elseif next == current:below() then
                ok1, err = turtle.down()
                if not ok1 then
                    ok2, data = turtle.inspectDown()
                    update_map_knowledge(next, data)
                end
            else
                ensure_direction(current:direction_to(next))
                ok1, err = turtle.forward()
                if not ok1 then
                    ok2, data = turtle.inspect()
                    update_map_knowledge(next, data)
                end
            end
            if not ok1 then
                if current_task ~= nil then
                    local ok3, cancel_task = pcall(current_task.on_path_obstructed, current_task, destination, direction, tracker.get_position(), tracker.get_direction())
                    if not ok3 then
                        log("error", "task failed to acknowledge obstructed path: "..tostring(current_task))
                    elseif cancel_task then
                        return false
                    end
                end
                break
            else
                if active_tasks:acquire() then
                    for task in active_tasks:iter(current_priority) do
                        do_sub_task(task)
                    end
                    active_tasks:release()
                end
            end
        end
        if tracker.get_position() == destination and direction ~= nil then
            ensure_direction(direction)
        end
    end
    return true
end

--- Moves to the given location. The turtle can stop along the way to complete other tasks and turn around, but not move.
---@param destination Position The position to reach to accomplish to task.
---@param direction number? The eventual direction in which to arrive at the direction.
---@return boolean success If the turtle succesfully reached the destination.
local function move_to_AROUND(destination, direction)

    --- Performs another task along the way, without allowing the turtle to move.
    ---@param task Task
    local function do_sub_task(task)
        if not task.check_on_move then
            return
        end
        moving_locked = true
        local ok, err_or_task_finished = pcall(task.perform, task, tracker.get_position(), tracker.get_direction(), tasker.TIMING_COST.AROUND)
        moving_locked = false
        if not ok then
            log("error", "sub-task failed: "..err_or_task_finished)
            active_tasks:remove(task)
        else
            if err_or_task_finished then
                log("debug", "sub task finished: "..tostring(task))
                active_tasks:remove(task)
            end
        end
    end

    while tracker.get_position() ~= destination and (direction == nil or tracker.get_direction() == direction) do
        local path = map:find_path(tracker.get_position(), tracker.get_direction(), destination, direction, tasker.walkable_safe)
        if path == nil then
            return false
        end
        local current = path[1]
        if active_tasks:acquire() then
            for task in active_tasks:iter(current_priority) do
                do_sub_task(task)
            end
            active_tasks:release()
        end
        for i = 2, #path, 1 do
            local next = path[i]
            local ok1, ok2, err, data
            if current_task == nil then
                return false
            end
            if next == current:above() then
                ok1, err = turtle.up()
                if not ok1 then
                    ok2, data = turtle.inspectUp()
                    update_map_knowledge(next, data)
                end
            elseif next == current:below() then
                ok1, err = turtle.down()
                if not ok1 then
                    ok2, data = turtle.inspectDown()
                    update_map_knowledge(next, data)
                end
            else
                ensure_direction(current:direction_to(next))
                ok1, err = turtle.forward()
                if not ok1 then
                    ok2, data = turtle.inspect()
                    update_map_knowledge(next, data)
                end
            end
            if not ok1 then
                if current_task ~= nil then
                    local ok3, cancel_task = pcall(current_task.on_path_obstructed, current_task, destination, direction, tracker.get_position(), tracker.get_direction())
                    if not ok3 then
                        log("error", "task failed to acknowledge obstructed path: "..tostring(current_task))
                    elseif cancel_task then
                        return false
                    end
                end
                break
            else
                if active_tasks:acquire() then
                    for task in active_tasks:iter(current_priority) do
                        do_sub_task(task)
                    end
                    active_tasks:release()
                end
            end
        end
        if tracker.get_position() == destination and direction ~= nil then
            ensure_direction(direction)
        end
    end
    return true
end

--- Moves to the given location. The turtle can stop along the way to complete other tasks and move at most 2 blocks away from the path.
---@param destination Position The position to reach to accomplish to task.
---@param direction number? The eventual direction in which to arrive at the direction.
---@return boolean success If the turtle succesfully reached the destination.
local function move_to_NEAR(destination, direction)

    local last_position = tracker.get_position()
    --- Performs another task along the way, allowing the turtle.
    ---@param task Task
    local function do_sub_task(task)
        if not task.check_on_move then
            return
        end
        lock_position = last_position
        local ok, err_or_task_finished = pcall(task.perform, task, tracker.get_position(), tracker.get_direction(), tasker.TIMING_COST.NEAR)
        lock_position = nil
        if not ok then
            log("error", "sub-task failed: "..err_or_task_finished)
            active_tasks:remove(task)
        else
            if err_or_task_finished then
                log("debug", "sub task finished: "..tostring(task))
                active_tasks:remove(task)
            end
        end
    end

    while tracker.get_position() ~= destination and (direction == nil or tracker.get_direction() == direction) do
        local path = map:find_path(tracker.get_position(), tracker.get_direction(), destination, direction, tasker.walkable_safe)
        if path == nil then
            return false
        end
        local current = path[1]
        last_position = current
        if active_tasks:acquire() then
            for task in active_tasks:iter(current_priority) do
                do_sub_task(task)
            end
            active_tasks:release()
        end
        for i = 2, #path, 1 do
            local next = path[i]
            local ok1, ok2, err, data
            if current_task == nil then
                return false
            end
            if next == current:above() then
                ok1, err = turtle.up()
                if not ok1 then
                    ok2, data = turtle.inspectUp()
                    update_map_knowledge(next, data)
                end
            elseif next == current:below() then
                ok1, err = turtle.down()
                if not ok1 then
                    ok2, data = turtle.inspectDown()
                    update_map_knowledge(next, data)
                end
            else
                ensure_direction(current:direction_to(next))
                ok1, err = turtle.forward()
                if not ok1 then
                    ok2, data = turtle.inspect()
                    update_map_knowledge(next, data)
                end
            end
            if not ok1 then
                if current_task ~= nil then
                    local ok3, cancel_task = pcall(current_task.on_path_obstructed, current_task, destination, direction, tracker.get_position(), tracker.get_direction())
                    if not ok3 then
                        log("error", "task failed to acknowledge obstructed path: "..tostring(current_task))
                    elseif cancel_task then
                        return false
                    end
                end
                break
            else
                if active_tasks:acquire() then
                    last_position = tracker.get_position()
                    for task in active_tasks:iter(current_priority) do
                        do_sub_task(task)
                    end
                    active_tasks:release()
                end
            end
        end
        if tracker.get_position() == destination and direction ~= nil then
            ensure_direction(direction)
        end
    end
    return true
end





local function answer_requests()
    local event
    local task
    while true do
        event = {coroutine.yield()}
        if event[1] == "task_disabled" then
            task = event[2]
            if active_tasks:priority(task) ~= nil then
                log("debug", "disabling task: "..tostring(task))
                active_tasks:remove(task)
            end
            idle_tasks[task.identifier] = task
            task.enabled = false
        elseif event[1] == "task_enabled" then
            task = event[2]
            if idle_tasks[task.identifier] ~= nil then
                log("debug", "enabling task: "..tostring(task))
                idle_tasks[task.identifier] = nil
            end
            active_tasks:push(task, task.priority)
            task.enabled = true
        elseif event[1] == "task_priority" then
            task = event[2]
            task.priority = event[3]
            if active_tasks:priority(task) ~= nil then
                log("debug", "changed task priority to "..task.priority..": "..tostring(task))
                active_tasks:push(task, task.priority)
            end
        elseif event[1] == "task_register" then
            task = event[2]
            task.active_map = map
            idle_tasks[task.identifier] = task
            log("debug", "registering new task: "..tostring(task))
            local ok, err = pcall(task.on_map_update, task)
            if not ok then
                log("error", "Task's 'on_map_update' method failed: "..err)
            end
            if type(task.background_handler) == "function" then
                local coro = coroutine.create(task.background_handler)
                local ok, err = coroutine.resume(coro, task, map)
                if not ok then
                    log("error", "Task's background_handler failed on start: "..err)
                end
                if coroutine.status(coro) ~= "dead" then
                    task_threads[task.identifier] = coro
                end
            end
        elseif event[1] == "task_unregister" then
            task = event[2]
            if idle_tasks[task.identifier] then
                log("debug", "deleting idle task: "..tostring(task))
                idle_tasks[task.identifier] = nil
            else
                log("debug", "deleting active task: "..tostring(task))
                if current_task == task then
                    current_task = nil
                end
                active_tasks:remove(task)
            end
        end
        if map_updated then
            map_updated = false
            log("debug", "saving map.")
            save_map()
        end
    end
end

local function do_tasks()
    while true do
        log("debug", "about to select a task to run")
        local current_pos, current_dir = tracker.get_position(), tracker.get_direction()
        local all_tasks = {}        ---@type {[integer]: Task}
        local ran_task = false

        while #active_tasks > 0 do
            local first_task = active_tasks:pop()

            if first_task then
                local first_positions, first_directions = first_task:positions(current_pos, current_dir)
                local task_positions = {[first_task] = first_positions}     ---@type {[Task]: Position[]}
                local task_directions = first_directions ~= nil and {[first_task] = first_directions} or {}     ---@type {[Task]: DIRECTION[]}
                all_tasks[first_task.identifier] = first_task
                current_priority = first_task.priority
                log("debug", "enumerating tasks of priority "..current_priority..".")
                local total_positions = 0
                local total_tasks = 0

                while active_tasks:next_priority() == current_priority do
                    total_tasks = total_tasks + 1
                    local next_task = active_tasks:pop()
                    local next_positions, next_directions = next_task:positions(current_pos, current_dir)
                    total_positions = total_positions + #next_positions
                    all_tasks[next_task.identifier] = next_task
                    task_positions[next_task] = next_positions
                    if next_directions ~= nil then
                        task_directions[next_task] = task_directions
                    end
                end
                log("debug", "got "..total_tasks.." possible tasks with "..total_positions.." positions to select from.")

                local seen = {}
                local best_task = nil
                local best_position = nil
                local best_direction = nil
                local best_distance = math.huge

                while next(task_positions) ~= nil do

                    for task, positions in pairs(task_positions) do
                        local directions = task_directions[task]
                        local closest_position = nil
                        local closest_index = nil
                        local distance = math.huge

                        for index, pos in pairs(positions) do
                            if current_pos:manhattan_distance_to(pos) < distance then
                                distance = current_pos:manhattan_distance_to(pos)
                                closest_position = pos
                                closest_index = index
                            end
                        end

                        if distance >= best_distance then
                            total_positions = total_positions - #positions
                            total_tasks = total_tasks - 1
                            log("debug", "task unsatisfactory for now: "..total_tasks.." tasks remaining with "..total_positions.." positions.")
                            task_positions[task] = nil
                            task_directions[task] = nil
                        else
                            if closest_index == nil or closest_position == nil then
                                error("should not have ended up there", 1)
                            end
                            local closest_direction = directions ~= nil and directions[closest_index] or nil
                            positions[closest_index] = nil
                            total_positions = total_positions - 1
                            log("debug", "searching a path to "..tostring(closest_position)..".")

                            if seen[closest_position:hash()..closest_direction..tostring(task.timing_cost)] == nil then
                                local path = map:find_path(current_pos, current_dir, closest_position, closest_direction, task.timing_cost == tasker.TIMING_COST.LIFE_OR_DEATH and tasker.walkable_life_or_death or tasker.walkable_safe, task.path_costs)
                                if path ~= nil and #path - 1 < best_distance then
                                    best_distance = #path - 1
                                    best_direction = closest_direction
                                    best_position = closest_position
                                    best_task = task
                                    log("debug", "found a new best path with distance "..best_distance..".")
                                end
                                seen[closest_position:hash()..closest_direction..tostring(task.timing_cost)] = true
                            end
                        end
                    end
                end

                if best_task == nil then
                    log("warning", "could not find a best path among the tasks to run of priority "..current_priority..".")
                    log("info", "warning tasks of their unreachability.")
                    for identifier, task in pairs(all_tasks) do
                        local ok, err_or_disable = pcall(tasker.Task.on_no_reacheable_positions, task, current_pos, current_dir)
                        if not ok then
                            log("error", "a task failed to answer the call to 'on_no_reachable_positions': "..tostring(task)..": "..err_or_disable)
                        else
                            if err_or_disable then
                                task:disable()
                            end
                        end
                    end
                else
                    ran_task = true
                    all_tasks[best_task.identifier] = nil
                    if best_position ~= nil then
                        log("info", "selected a task and path to its destination.")
                        local arrived = false
                        current_task = best_task
                        if best_task.timing_cost == tasker.TIMING_COST.NEAR then
                            arrived = move_to_NEAR(best_position, best_direction)
                        elseif best_task.timing_cost == tasker.TIMING_COST.AROUND then
                            arrived = move_to_AROUND(best_position, best_direction)
                        elseif best_task.timing_cost == tasker.TIMING_COST.QUICK then
                            arrived = move_to_QUICK(best_position, best_direction)
                        elseif best_task.timing_cost == tasker.TIMING_COST.URGENT then
                            arrived = move_to_URGENT(best_position, best_direction)
                        elseif best_task.timing_cost == tasker.TIMING_COST.LIFE_OR_DEATH then
                            arrived = move_to_LIFE_OR_DEATH(best_position, best_direction)
                        end
                        if arrived then
                            log("debug", "arrived at task destination.")
                            local ok, err_or_done = pcall(best_task.perform, best_task, tracker.get_position(), tracker.get_direction())
                            if not ok then
                                log("error", "main task failed to perform: "..err_or_done)
                            elseif err_or_done then
                                log("debug", "main task finished: "..tostring(best_task))
                            elseif not err_or_done and best_task.enabled then
                                active_tasks:push(best_task, best_task.priority)
                            end
                        end
                    end
                    break
                end
            end
        end
        for identifier, task in pairs(all_tasks) do
            active_tasks:push(task, task.priority)
        end
        if not ran_task then
            coroutine.yield()
        end
        current_task = nil
        current_priority = math.huge
    end
end

local is_mandatory = {
    [run_background_threads] = true,
    [answer_requests] = false,
    [forget_blocks] = false,
    [do_tasks] = true
}
local functions = {
    run_background_threads = run_background_threads,
    answer_requests = answer_requests,
    forget_blocks = forget_blocks,
    do_tasks = do_tasks
}
local order = {
    "run_background_threads",
    "answer_requests",
    "forget_blocks",
    "do_tasks"
}
local threads = {}

for index, func_name in ipairs(order) do
    local coro = coroutine.create(functions[func_name])
    log("info", "initializing coroutine for "..tostring(func_name))
    local ok, err = coroutine.resume(coro)
    if not ok then
        error((is_mandatory[func_name] and "mandatory" or "secondary").." routine exited before entering the event loop: "..tostring(err))
    end
    if coroutine.status(coro) ~= "suspended" then
        error((is_mandatory[func_name] and "mandatory" or "secondary").." routine exited before entering the event loop without error")
    end
    table.insert(threads, coro)
end

local is_mandatory_living = true
while true do
    local event = {coroutine.yield()}
    for index, thread in ipairs(threads) do
        local ok, err = coroutine.resume(thread, table.unpack(event))
        if not ok then
            error("error in coroutine "..order[index]..": "..tostring(err))
        end
    end

    is_mandatory_living = false
    for i = #threads, 1, -1 do
        local thread = threads[i]
        if coroutine.status(thread) ~= "suspended" then
            log("info", (is_mandatory[order[i]] and "mandatory" or "secondary").." coroutine "..order[i].." ended.")
            table.remove(threads, i)
        else
            if is_mandatory[order[i]] then
                is_mandatory_living = true
            end
        end
    end
end

_G.scheduler = nil
log_file.close()