--- A script add, remove or list named locations in the world.

local maps = require "maps"
local tracker = require "tracker"

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
    print_color("Listing existing locations:", colors.yellow)
    print_color("locations list|ls")
    print_color("Removing an existing location:", colors.yellow)
    print_color("locations remove|rm|delete|del <name>")
    print_color("Adding a new location:", colors.yellow)
    print_color("locations add|save")
    print_color("locations add|save <x> <y> <z>")
    print_color("locations add|save <x> <y> <z> <d>")
    print_color("Any coordinate can be repaced with '~' to specify the current location. Saving the direction is optional.", colors.lightGray)
    return
end

if #args == 0 then
    print_usage()
end

local mode = args[1]

if mode == "list" or mode == "ls" then

    if #args > 1 then
        print_usage()
    end

    local NAME_COLOR = colors.yellow
    local POS_COLOR = colors.cyan
    local DIR_COLOR = colors.lime

    local names = tracker.get_dict_names()      ---@type string[]
    table.sort(names)
    local positions = {}                        ---@type {[string]: Position}
    local directions = {}                        ---@type {[string]: DIRECTION?}
    for index, name in ipairs(names) do
        local pos, dir = tracker.get_dict_entry(name)
        positions[name] = pos
        if dir ~= nil then
            directions[name] = dir
        end
    end
    local function format_direction(dir)
        if dir == maps.DIRECTION.NORTH then return "north"
        elseif dir == maps.DIRECTION.SOUTH then return "south"
        elseif dir == maps.DIRECTION.EAST then return "east"
        elseif dir == maps.DIRECTION.WEST then return "west"
        end
        return ""
    end

    local y = 1
    local page_height = term.getSize() - 1
    for i = 1, #names do
        if y > page_height then
            print("Press any key for more...")
            os.pullEvent("key")
            term.clear()
            y = 1
        end
        local name = names[i]
        local pos = positions[name]
        local dir = directions[name]
        print_color(name .. ": ", NAME_COLOR, false)
        print_color(string.format("(%d, %d, %d)", pos.x, pos.y, pos.z), POS_COLOR, false)
        if dir ~= nil then
            print_color(" " .. format_direction(dir), DIR_COLOR, true)
        else
            print()
        end
        y = y + 1
    end

elseif mode == "remove" or mode == "rm" or mode == "delete" or mode == "del" then
    if #args ~= 2 then
        print_usage()
    end

    local name = args[2]
    tracker.set_dict_entry(name)
    print_color("Deleted location named '"..name.."'", colors.yellow)

elseif mode == "add" or mode == "save" then

    local pos, dir = nil, nil
    local current_position = tracker.get_position()
    local current_direction = tracker.get_direction()

    if #args == 2 then
        pos = current_position
        dir = current_direction
    elseif #args == 5 then
        local x, y, z = args[3], args[4], args[5]
        x = x == "~" and current_position.x or tonumber(x)
        y = y == "~" and current_position.y or tonumber(y)
        z = z == "~" and current_position.z or tonumber(z)
        if x == nil or math.floor(x) ~= x or y == nil or math.floor(y) ~= y or z == nil or math.floor(z) ~= z then
            print_usage()
        end
        pos = maps.Position:new(x, y, z)
    elseif #args == 6 then
        local x, y, z, d = args[3], args[4], args[5], args[6]
        x = x == "~" and current_position.x or tonumber(x)
        y = y == "~" and current_position.y or tonumber(y)
        z = z == "~" and current_position.z or tonumber(z)
        d = d == "~" and current_direction or tonumber(d)
        if x == nil or math.floor(x) ~= x or y == nil or math.floor(y) ~= y or z == nil or math.floor(z) ~= z or d == nil or math.floor(d) ~= d or d < 0 or d > 3 then
            print_usage()
        end
        pos = maps.Position:new(x, y, z)
        dir = d
    else
        print_usage()
    end
    tracker.set_dict_entry(args[2], pos, dir)
    print_color("Saved location '"..args[2].."'", colors.yellow)

else
    print_usage()
end