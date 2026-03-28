--- A script that makes a turtle move to a desired location.

local maps = require "maps"
local tracker = require "tracker"
local go_to = require "go_to"

local args = {...}

local function print_color(message, color, newline)
    local old_color = term.isColor() and term.getTextColor() or nil
    if term.isColor() and color ~= nil then
        term.setTextColor(color)
    end
    if newline == nil then
        newline = true
    end
    if newline then
        print(message)
    else
        term.write(message)
    end
    if old_color ~= nil and color ~= nil then
        term.setTextColor(old_color)
    end
end

local function print_usage()
    print_color("Usage:", colors.yellow)
    print_color("Going to a named location (see program 'locations'):", colors.yellow)
    print_color("travel <name>")
    print_color("Going to a specific location:", colors.yellow)
    print_color("travel <x> <y> <z>")
    print_color("travel <x> <y> <z> <d>")
    print_color("Any coordinate can be repaced with '~' to specify the current location. Specifying the direction is optional.", colors.lightGray)
    return
end

local function require_scheduler()
    if _G.scheduler == nil then
        local id = multishell.launch({}, shell.resolveProgram("scheduler"))
        multishell.setTitle(id, "scheduler")
    end
end

local pos, dir = nil, nil
local current_pos, current_dir = tracker.get_position(), tracker.get_direction()
if #args == 1 then
    pos, dir = tracker.get_dict_entry(args[2])
    if pos == nil then
        print_color("Unknown location: '"..args[2].."'", colors.orange)
    end
elseif #args == 3 then
    local x, y, z = args[1], args[2], args[3]
    x = x == "~" and current_pos.x or tonumber(x)
    y = y == "~" and current_pos.y or tonumber(y)
    z = z == "~" and current_pos.z or tonumber(z)
    if x == nil or math.floor(x) ~= x or y == nil or math.floor(y) ~= y or z == nil or math.floor(z) ~= z then
        print_usage()
    end
    pos = maps.Position:new(x, y, z)
elseif #args == 4 then
    local x, y, z, d = args[1], args[2], args[3], args[4]
    x = x == "~" and current_pos.x or tonumber(x)
    y = y == "~" and current_pos.y or tonumber(y)
    z = z == "~" and current_pos.z or tonumber(z)
    d = d == "~" and current_dir or tonumber(d)
    if x == nil or math.floor(x) ~= x or y == nil or math.floor(y) ~= y or z == nil or math.floor(z) ~= z or d == nil or math.floor(d) ~= d or d < 0 or d > 3 then
        print_usage()
    end
    pos = maps.Position:new(x, y, z)
    dir = d
else
    print_usage()
end

require_scheduler()

local done = false
local released = false
local function signal_and_wait()
    done = true
    while not released do
        coroutine.yield()
    end
end

local unreachable = false
local function give_up()
    unreachable = true
    os.queueEvent("tick")       --- To be sure this script will resume to handle the unreachable state.
end

local task = go_to.GoToTask:new(pos, dir, signal_and_wait)

task:register()
task:enable()

local previous_state = nil
local state = nil

while not done do
    if unreachable then
        print_color("Cannot reach destination.", colors.red)
        released = true
        os.queueEvent("tick")       --- To be sure the scheduler will resume the task to release it.
        task:unregister()
        return
    end
    if scheduler.current_task() == task then
        state = "moving"
    else
        state = "waiting"
    end
    if state ~= previous_state then
        if state == "moving" then
            print_color("Moving to destination...", colors.lime)
        elseif state == "waiting" then
            print_color("Waiting for other tasks to finish...", colors.yellow)
        end
        previous_state = state
    end
end

print_color("Destination reached. Press any key to release the turtle.", colors.lime)
while true do
    local event = {coroutine.yield()}
    if event[1] == "key" or event[1] == "terminate" then
        released = true
        os.queueEvent("tick")       --- To be sure the scheduler will resume the task to release it.
        break
    end
end