type_system = {}
local globals_enabled = true
local loaded = false





-- Log system for debugging.

local LOGFILE = "TS.log"
_G.LOG_LEVEL = 0
local INFO_LEVEL = 4
local logging = false

---@param source string
local function file_stem(source)
    source = source or ""
    source = source:gsub("^@", "")
    source = source:gsub("\\", "/")
    local name = source:match("([^/]+)$") or source
    return name:gsub("%.lua$", "")
end

if fs.exists(LOGFILE) then
    fs.delete(LOGFILE)
end

local file = fs.open(LOGFILE, "a")
function _G.log(message)
    if not logging then
        return
    end
    local stack = get_stack_info()
    local depth = math.min(INFO_LEVEL, #stack)
    local parts = {}
    for i = depth, 2, -1 do
        local frame = stack[i]
        if frame then
            parts[#parts + 1] = file_stem(frame.source) .. "-" .. tostring(frame.current_line or "?")
        end
    end
    local stack_line = table.concat(parts, " : ")
    file.write(string.rep("\t", _G.LOG_LEVEL) .. stack_line .. " : " .. message)
    if message:sub(-1) ~= "\n" then
        file.write("\n")
    end
    file.flush()
end

function _G._log_wrap(f)
    return function (...)
        _G.LOG_LEVEL = _G.LOG_LEVEL + 1
        local res = {pcall(f, ...)}
        _G.LOG_LEVEL = _G.LOG_LEVEL - 1
        if res[1] then
            return table.unpack(res, 2)
        else
            error(res[2], 0)
        end
    end
end

function debug.enable_logs()
    logging = true
end

function debug.disable_logs()
    logging = false
end





-- A general class cache with callback methods to clear it for a given class.

local cache_invalidation_callbacks = {}

---@generic T
--- Registers a callback to be called when the cache for a class is invalidated.
---@param callback fun(class: Type<T>) The callback function, which takes the class whose cache is being cleared as an argument.
function type_system.register_cache_invalidation_callback(callback)
    table.insert(cache_invalidation_callbacks, callback)
end

---@generic T
--- Clears the cache for a given class, calling all registered callbacks.
---@param class Type<T> The class whose cache is being cleared.
function type_system.invalidate_cache(class)
    for _, callback in ipairs(cache_invalidation_callbacks) do
        callback(class)
    end
end





-- Load the various parts of the type system in order, passing the type_system table to each one so they can add to it as needed.

type_system.method_resolution_loop_breakers = {} -- For certain classes, this avoids circular references when resolving metamethods.

local function make_env(to_add)
    local env = {}
    for key, value in pairs(_G) do
        env[key] = value
    end
    for key, value in pairs(to_add) do
        env[key] = value
    end
    return env
end

loadfile("/lib/class/builtins.lua", "t", make_env{type_system = type_system})()
loadfile("/lib/class/object.lua", "t", make_env{type_system = type_system})()
loadfile("/lib/class/type.lua", "t", make_env{type_system = type_system})()
loadfile("/lib/class/overloading.lua", "t", make_env{type_system = type_system})()
for _, file in ipairs(fs.list("/lib/class/functional")) do
    loadfile("/lib/class/functional/"..file, "t", make_env{type_system = type_system})()
end
loadfile("/lib/class/link.lua", "t", make_env{type_system = type_system})()





local function add_to_G()
    for key, value in pairs(type_system.globals) do
        _G[key] = value
    end
end

local function del_from_G()
    for key, value in pairs(type_system.globals) do
        if rawequal(_G[key], value) then
            _G[key] = nil
        end
    end
end

type_system.old_setmetatable(type_system.builtins, {
    __index = function(_, key)
        if key == "global" then
            return globals_enabled
        else
            return rawget(type_system.builtins, key)
        end
    end,
    __newindex = function(_, key, value)
        if key == "global" then
            if type_system.type(value) ~= "boolean" then
                error("expected boolean for builtins.global, got '"..tostring(type_system.type(value)).."'", 2)
            end
            if value then
                add_to_G()
                globals_enabled = true
            else
                del_from_G()
                globals_enabled = false
            end
        else
            if loaded then
                error("cannot assign to builtins."..key..": only builtins.global can be assigned to", 2)
            else
                rawset(type_system.builtins, key, value)
            end
        end
    end,
    __pairs = function (_)
        local keys = {}
        local key_order = {}
        local key, value = nil, nil
        local i = 1
        while true do
            key, value = next(type_system.builtins, key)
            if key == nil then
                break
            end
            keys[key] = i
            table.insert(key_order, key)
            i = i + 1
        end
        keys["global"] = i
        table.insert(key_order, "global")
        local function new_next(_, key)
            if key == nil then
                i = 1
            else
                i = keys[key] + 1
            end
            if i <= #key_order then
                local k = key_order[i]
                if k == "global" then
                    return k, globals_enabled
                else
                    return k, rawget(type_system.builtins, k)
                end
            end
        end
        return new_next, type_system.builtins, nil
    end,
})

loaded = true
add_to_G()





return type_system.builtins