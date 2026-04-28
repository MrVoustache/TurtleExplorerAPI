--- This module defines the Object class, the final superclass, responsible for creating object, and defining inheritance.





---@class Object The base class for all objects. Every instance of a class created with the class function will have Object as a base class, and every class created with the class function will have Object as a base class as well (since all classes have Type as a base class, and Type has Object as a base class).
---@field __dict table A table of fields defined in the object.
local Object = {}
_G.Object = Object
type_system.builtins.Object = Object
type_system.globals.Object = Object
type_system.Object = Object





---@generic T
--- Creates a new object of the calling class.
---@param self Type<T> The class to create an instance of.
---@return T obj A new instance of the class.
function Object:__new()
    log(">>> Creating a new "..tostring(self.__name).." object")
    local obj = {}
    self:__cast(obj)
    return obj
end


---@generic T
--- Casts a table to an instance of the calling class.
---@param self Type<T> The class to cast to.
---@param obj table The table to cast.
function Object:__cast(obj)
    log(">>> Casting a new "..tostring(self.__name).." object")
    if type_system.type(obj) ~= "table" then
        error("expected table for argument #1, got '"..tostring(type_system.type(obj)).."'", 2)
    end
    if not type_system.is_class(self) then
        error("cannot cast to non-class type '"..tostring(type_system.type(self)).."'", 2)
    end
    local dict = {__class = self}
    local bound_method_cache = {}
    obj.__dict = dict
    obj.__bound_method_cache = {}
    type_system.old_setmetatable(obj, type_system.pythonic_overloading_metatable)
end


--- Initializes the object.
function Object:__init()
end


function Object:__getindex(key)
    -- if rawget(self, "__name") ~= nil then
    --     log("Calling super __getindex for key '"..tostring(key).."' on class '"..rawget(self, "__name").."'")
    -- else
    --     log("Calling super __getindex for key '"..tostring(key).."' on a '"..type_system.type(self).__name.."' object")
    -- end
    local dict = rawget(self, "__dict")
    if dict[key] ~= nil then
        return dict[key]
    end

    local bound_method_cache = rawget(self, "__bound_method_cache")
    if bound_method_cache[key] ~= nil then
        return bound_method_cache[key]
    end

    local seen_classes = {}
    local function explore_class_hierarchy(base)
        log("Exploring class '"..base.__name.."' for key '"..tostring(key).."'")
        if seen_classes[base] then
            return
        end
        seen_classes[base] = true
        local base_dict = rawget(base, "__dict")
        if base_dict[key] ~= nil then
            local value = base_dict[key]
            log("Is a '"..tostring(type_system.type(value)).."' object a dynamic attribute?")
            if type_system.builtins.isinstance(value, type_system.Method) then
                log("I need to bind method '"..key.."' to an instance")
                value = type_system.BoundMethod(value, self)
                bound_method_cache[key] = value
            end
            return value
        end
        for index, super_base in ipairs(base.__direct_bases) do
            local res = explore_class_hierarchy(super_base)
            if res ~= nil then
                return res
            end
        end
    end

    return explore_class_hierarchy(type_system.type(self))
end


function Object:__setindex(key, value)
    rawget(self, "__dict")[key] = value
end


function Object:__dir()
    log("Calling super __dir")
    local dir = {}
    for key in pairs(rawget(self, "__dict")) do
        dir[key] = true
    end

    local seen_classes = {}
    local function explore_class_hierarchy(base)
        log("Enumerating class '"..base.__name.."' keys")
        if seen_classes[base] then
            return
        end
        seen_classes[base] = true
        local base_dict = rawget(base, "__dict")
        for key, value in pairs(base_dict) do
            dir[key] = true
        end
        for index, super_base in ipairs(base.__direct_bases) do
            explore_class_hierarchy(super_base)
        end
    end
    explore_class_hierarchy(type_system.type(self))

    local keys = {}

    for key in pairs(dir) do
        table.insert(keys, key)
    end
    table.sort(keys)

    log("Finished enumerating super dir")
    return keys
end


function Object:__pairs()
    local keys = type_system.type(self).__dir(self)
    local i = 0
    return function()
        i = i + 1
        local key = keys[i]
        if key then
            log("Next key of object "..tostring(self).." of class "..tostring(type_system.type(self)).." is '"..key.."'")
            return key, self[key]
        end
    end, self, nil
end


function Object:__tostring()
    local old_mt = type_system.old_getmetatable(self)
    type_system.old_setmetatable(self, nil)
    local raw_string = tostring(self)
    type_system.old_setmetatable(self, old_mt)
    local memory_address = raw_string:match(".*: ([0-9a-fA-F]+)")
    return "<"..tostring(type_system.type(self).__name).." object" ..(memory_address and (" at 0x"..memory_address) or "") ..">"
end
