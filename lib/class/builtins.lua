--- Defines the builtins table and functions used by this Pythonic type system.





type_system.old_type = type
type_system.old_getmetatable = getmetatable
type_system.old_setmetatable = setmetatable

type_system.classes = {}          ---@type table<Type, boolean> A set of classes. Used by isinstance and issubclass to check for class membership and inheritance without infinite recursion.

local builtins = {}
type_system.builtins = builtins

local globals = {}
type_system.globals = globals





-- The functions to check for class membership and inheritance.

--- Internal function for fast checking if an object is a class.
function type_system.is_class(obj)
    return type_system.classes[obj] ~= nil
end

local builtins_types = {
    ["nil"] = true,
    ["number"] = true,
    ["string"] = true,
    ["boolean"] = true,
    ["function"] = true,
    ["table"] = true,
    ["thread"] = true,
    ["userdata"] = true,
}

---@generic T
--- Returns the type of the object as its class.
---@param value T The value to get the type of.
---@return Type<T> class The class of the object.
function type_system.type(value)
    if type_system.old_type(value) ~= "table" then
        return type_system.old_type(value)
    else
        local mt = type_system.old_getmetatable(value)
        if mt == nil then
            return "table"
        else
            if rawequal(mt, type_system.pythonic_overloading_metatable) and type_system.old_type(rawget(value, "__dict")) == "table" and type_system.is_class(rawget(rawget(value, "__dict"), "__class")) then
                _G.last_stack = get_stack_info()
                return rawget(rawget(value, "__dict"), "__class")
            else
                return mt
            end
        end
    end
end

---@generic T
--- Checks if a class is a subclass of another class.
---@param subclass Type<T> The class to check if it is a subclass of the other.
---@param superclass Type<T> The class to check if the first class is a subclass of.
---@return boolean is_subclass True if sub is a subclass of cls, false otherwise.
local function issubclass(subclass, superclass)
    if not type_system.is_class(subclass) then
        error("expected class for argument #1, got '"..tostring(type_system.type(subclass)).."'", 2)
    end
    if not type_system.is_class(superclass) then
        error("expected class for argument #2, got '"..tostring(type_system.type(superclass)).."'", 2)
    end
    local subclasscheck_method = type_system.simple_resolve_metamethod(superclass, "__subclasscheck")
    if subclasscheck_method == nil then
        return false
    end
    if type_system.old_type(subclasscheck_method) ~= "function" then
        error("__subclasscheck should be a function, not a '"..type_system.type(subclasscheck_method).."'", 2)
    end
    local ok, err_or_res = pcall(subclasscheck_method, superclass, subclass)
    if not ok then
        error(err_or_res, 0)
    end
    return err_or_res
end
builtins.issubclass = issubclass
globals.issubclass = builtins.issubclass
type_system.issubclass = issubclass

---@generic T
--- Checks if an object is an instance of a class.
---@param obj any The object to check.
---@param cls Type<T> The class to check if the object is an instance of.
---@return boolean is_instance True if obj is an instance of cls, false otherwise.
local function isinstance(obj, cls)
    if builtins_types[cls] ~= nil then
        return type_system.old_type(obj) == cls
    end
    if not type_system.is_class(cls) then
        error("expected class for argument #2, got '"..tostring(type_system.type(cls)).."'", 2)
    end
    if type_system.old_type(obj) ~= "table" then
        return false
    end
    local c = type_system.type(obj)
    if issubclass(c, cls) then      -- This is to avoid Lua's f****** tail calls for understadable tracebacks
        return true
    else
        return false
    end
end
builtins.isinstance = isinstance
globals.isinstance = builtins.isinstance
type_system.isinstance = isinstance

function _G.getmetatable(obj)
    return type_system.type(obj)
end

function _G.setmetatable(obj, type)
    return type_system.old_setmetatable(obj, type)
    -- error("cannot change metatable of an object: use the class function to create classes and instances", 2)
end

local function dir(obj)
    if type_system.old_getmetatable(obj) ~= type_system.pythonic_overloading_metatable then
        return {}
    end
    local dir_method = type_system.simple_resolve_metamethod(obj, "__dir")
    if dir_method == nil then
        return {}
    end
    if type_system.old_type(dir_method) ~= "function" then
        return dir_method
    end
    local ok, err_or_res = pcall(dir_method, obj)
    if not ok then
        error(err_or_res, 0)
    end
    return err_or_res
end
builtins.dir = dir
globals.dir = dir
type_system.dir = dir