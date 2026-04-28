--- This module declares the Type class, which is creates the principle of instances.





---@generic T
---@class Type<T> : Object The type of classes. Every class created with the class function is an instance of Type, and every instance of a class created with the class function has its class as its type
---@field __name string The name of the class.
---@field __direct_bases Type[] The direct base classes of the class, in order of priority. When looking up a method or field, the class will first look in its own table, then in the tables of its base classes in order.
---@field __direct_subclasses Type[] The direct subclasses of the class. This is used to keep track of the class hierarchy and to implement the issubclass function.
local Type = {}
_G.Type = Type
type_system.builtins.Type = Type
type_system.globals.Type = Type
type_system.Type = Type





function Type:__cast(cls)
    Object.__cast(self, cls)
    type_system.classes[cls] = true
end


function Type:__init(name, bases, dict)
    if type_system.type(name) ~= "string" then
        error("expected string for argument #1, got '"..tostring(type_system.type(name)).."'", 2)
    end
    if type_system.type(bases) ~= "table" then
        error("expected table for argument #2, got '"..tostring(type_system.type(bases)).."'", 2)
    end
    for key, value in pairs(bases) do
        if type_system.old_type(key) ~= "number" or math.floor(key) ~= key or key <= 0 or key > #bases then
            error("expected array for argument #2, got table with non-numeric key '"..tostring(key).."'", 2)
        end
    end
    if type_system.type(dict) ~= "table" then
        error("expected table for argument #3, got '"..tostring(type_system.type(dict)).."'", 2)
    end
    if #bases == 0 then
        bases = {Object}
    end
    local unique_bases = {}
    local seen_bases = {}
    local n_bases = #bases
    for index, base in ipairs(bases) do
        if not type_system.isinstance(base, Type) then
            error("expected Type for base #"..index..", got '"..tostring(type_system.type(base)).."'", 2)
        end
        if seen_bases[base] == nil then
            seen_bases[base] = true
            if not rawequal(base, Object) or n_bases == 1 then
                table.insert(unique_bases, base)
            end
        end
    end
    local cls = self
    for _, base in ipairs(unique_bases) do
        table.insert(base.__subclasses, cls)
    end
    for field, value in pairs(dict) do
        if type_system.old_type(field) ~= "string" then
            error("expected string for key in class dict, got '"..tostring(type_system.type(field)).."'", 2)
        end
        if type_system.type(value) == "function" then
            -- To-Do : add support for method objects, as well as static and class methods and property variants.
        end
    end
    rawset(cls, "__name", name)
    rawset(cls, "__direct_bases", unique_bases)
    rawset(cls, "__direct_subclasses",  {})
end


local dir_cache = {}

local function add_dir_to_cache(cls, dir)
    dir_cache[cls] = dir
end

local function invalidate_dir_cache(cls)
    log("Invalidating dir cache for class '"..tostring(cls.__name).."'")
    dir_cache[cls] = nil
    for _, subcls in ipairs(cls.__direct_subclasses) do
        invalidate_dir_cache(subcls)
    end
end

type_system.register_cache_invalidation_callback(invalidate_dir_cache)

function Type:__dir()
    if dir_cache[self] ~= nil then
        return dir_cache[self]
    end
    local tab = Object.__dir(self)
    log("Calling type __dir")
    table.insert(tab, "__name")
    table.insert(tab, "__direct_bases")
    table.insert(tab, "__direct_subclasses")
    table.sort(tab)
    add_dir_to_cache(self, tab)
    return tab
end


function Type:__getindex(key)
    log("Calling type __getindex for key '"..tostring(key).."'")
    if key == "__name" then
        local name = rawget(self, "__name")
        if name == nil then
            _G.villain = self
            error("How?")
        end
        return name
    end
    if key == "__direct_bases" then
        return rawget(self, "__direct_bases")
    end
    if key == "__direct_subclasses" then
        return rawget(self, "__direct_subclasses")
    end

    local seen_classes = {}
    local function explore_class_hierarchy(base)
        log("Exploring class '"..tostring(base.__name).."' for key '"..tostring(key).."'")
        if seen_classes[base] then
            return
        end
        seen_classes[base] = true
        local base_dict = rawget(base, "__dict")
        if base_dict[key] ~= nil then
            return base_dict[key]
        end
        for index, super_base in ipairs(base.__direct_bases) do
            local res = explore_class_hierarchy(super_base)
            if res ~= nil then
                return res
            end
        end
    end

    return explore_class_hierarchy(self)
end


function Type:__setindex(key, value)
    log("Calling type __setindex for key '"..tostring(key).."'")
    type_system.invalidate_cache(self)
    if type_system.type(value) == "function" then
        value = _log_wrap(value)
        log("Wrapping function value for key '"..tostring(key).."' in class '"..tostring(self.__name).."' as a method")
        value = type_system.Method(value)
    end
    rawget(Object, "__dict").__setindex(self, key, value)
    if type_system.type(key) == "string" then
        local set_name = type_system.simple_resolve_metamethod(value, "__set_name")
        if set_name then
            set_name(value, self, key)
        end
    end
end


function Type:__call(...)
    local args = {self, ...}
    if #args == 2 and rawequal(args[1], Type) then      -- Asking the type of args[2]
        return type_system.type(args[2])

    elseif #args == 4 and rawequal(args[1], Type) and type_system.type(args[2]) == "string" and (type_system.type(args[3]) == "table" or args[3] == nil) and type_system.type(args[4]) == "table" then      -- Dynamic creation of a class
        local ok, err_or_instance = pcall(self.__new, self, table.unpack(args, 2))
        if not ok then
            error(err_or_instance, 2)
        end
        local ok, err = pcall(err_or_instance.__init, err_or_instance, table.unpack(args, 2))
        if not ok then
            error(err, 2)
        end
        return err_or_instance
    
    elseif type_system.is_class(args[1]) then          -- Creating an instance of a class
        log(">>> Calling "..tostring(self).." to create an instance.")
        log(tostring(type_system.type(self.__new)))
        local ok, err_or_instance = pcall(self.__new, self, table.unpack(args, 2))
        if not ok then
            error(err_or_instance, 2)
        end
        local ok, err = pcall(self.__init, err_or_instance, table.unpack(args, 2))
        if not ok then
            error(err, 2)
        end
        return err_or_instance

    else
        local name = type_system.isinstance(self, Type) and self.__name or tostring(self)
        error("invalid signature for calling '"..name.."'()")
    end
end

function Type:__subclasscheck(subclass)
    if not type_system.is_class(subclass) then
        error("expected class for argument #1, got '"..tostring(type_system.type(subclass)).."'", 2)
    end
    if rawequal(subclass, self) then
        return true
    end
    for _, parent in ipairs(subclass.__direct_bases) do
        if type_system.issubclass(parent, self) then
            return true
        end
    end
    return false
end


function Type:__instancecheck(instance)
    if type_system.old_getmetatable(instance) ~= type_system.pythonic_overloading_metatable then
        return false
    end
    return type_system.issubclass(Type(instance), self)
end


function Type:__tostring()
    if self.__name == nil then
        error("No!")
    end
    return "Class <"..tostring(self.__name)..">"
end


function Type:__concat(other)
    if type_system.type(other) == "string" then
        return self.__name .. other
    end
    return tostring(self) .. tostring(other)
end





-- Type is the upper class class. Any direct instances must resolve their metamethods to Type's.

type_system.method_resolution_loop_breakers[Type] = {}
for key, value in pairs(Type) do
    type_system.method_resolution_loop_breakers[Type][key] = value
end