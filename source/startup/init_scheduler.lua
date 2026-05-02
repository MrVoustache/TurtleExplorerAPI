local monitor = peripheral.wrap("right")
if monitor then
    monitor.setTextScale(0.5)
    monitor.clear()
    monitor.setCursorPos(1, 1)
    term.redirect(monitor)
else
    term.clear()
    term.setCursorPos(1, 1)
end

local loader = require ".lib.loader"

shell.setPath(shell.path() .. ":/lib/turtle_explorer_api/bin")
for index, file in ipairs(fs.list("/lib/turtle_explorer_api/autocomplete")) do
    shell.run("/lib/turtle_explorer_api/autocomplete/"..file)
end





local maps = import "turtle_explorer_api.maps"
_G.p = maps.Position(4130, 138, 1719)
local class = import "class"

local function run_craft_os()
    if not shell.run("shell") then
        sleep(10)
    end
    os.shutdown()
    while true do
        coroutine.yield()
    end
end

local function run_scheduler()
    shell.run("scheduler")
    while true do
        coroutine.yield()
    end
end

_G.MyClass = class.classify("MyClass", {})

function MyClass:method()
    return 1, 2
end

parallel.waitForAny(run_scheduler, run_craft_os)
