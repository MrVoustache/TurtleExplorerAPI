--- Adds a some functions to the os module that are quite helpful!





local next_tick = 0
local last_tick = 0

function os.tick()
    if next_tick == last_tick then
        next_tick = next_tick + 1
        os.queueEvent("tick")
    end
    local tick = next_tick
    coroutine.yield()
    last_tick = math.max(last_tick, tick)
end





return os