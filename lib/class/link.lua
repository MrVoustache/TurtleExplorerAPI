--- This module creates the final links between the objects declared in the class package.





--- Initialize base classes (Object and Type)

local function pre_classify(name, cls, bases, metaclass, make_methods)
    if bases == nil then
        bases = rawequal(cls, Object) and {} or {Object}
    end
    local dict = {
        __class = metaclass,
    }
    for key, value in pairs(cls) do
        if type_system.old_type(key) ~= "string" then
            error("expected string for key in class dict, got '"..tostring(type_system.type(key)).."'", 2)
        end
        if type_system.type(value) == "function" then
            value = _log_wrap(value)
            if make_methods then
                
            end
        end
        dict[key] = value
        cls[key] = nil
    end
    
    cls.__name = name
    cls.__direct_bases = bases
    cls.__direct_subclasses = {}
    cls.__dict = dict
    type_system.classes[cls] = true
    type_system.old_setmetatable(cls, type_system.pythonic_overloading_metatable)

end

local function post_classify(cls)
    local bases = cls.__direct_bases
    if bases == nil then
        error("What?")
    end
    for _, base in ipairs(bases) do
        local subclasses = base.__direct_subclasses
        if type_system.old_type(subclasses) ~= "table" then
            error("base '"..tostring(base).."' is not a proper class as __direct_subclasses is a '"..tostring(type_system.type(subclasses)).."'", 2)
        end
        table.insert(subclasses, cls)
    end
end

local function make_methods(cls)
    for key, value in pairs(cls.__dict) do
        if type_system.type(value) == "function" then
            local method = type_system.create_method_before_type_system(value)
            method.__dict.__name = key
            method.__dict.__owner = cls
            cls.__dict[key] = method
        end
    end
end

pre_classify("Object", Object, nil, Type, false)
pre_classify("Type", Type, {Object}, Type, false)
post_classify(Type)
post_classify(Object)
pre_classify("Method", type_system.Method, {Object}, Type, false)
post_classify(type_system.Method)





---@generic T
---Transforms a table into a class in place.
---@param name string The name of the class.
---@param cls Type<T> The table that will become a class.
---@param bases Type<T>[]? The list of bases of this class. Defaults to {Object}.
---@param metaclass Type<Type<T>>? The metaclass to use for the class, instead of Type.
---@return Type<T> cls The same input class.
local function classify(name, cls, bases, metaclass)
    if not type_system.builtins.isinstance(name, "string") then
        error("expected string for argument #1, got '"..type(name).."'", 2)
    end
    if not type_system.builtins.isinstance(cls, "table") then
        error("expected table for argument #2, got '"..type(cls).."'", 2)
    end
    if bases ~= nil and not type_system.builtins.isinstance(bases, "table") then
        error("expected table for argument #3, got '"..type(bases).."'", 2)
    end
    if metaclass ~= nil and not type_system.builtins.isinstance(metaclass, type_system.Type) then
        error("expected Type for argument #4, got '"..type(metaclass).."'", 2)
    end
    bases = bases or {Object}
    metaclass = metaclass or Type
    pre_classify(name, cls, bases, metaclass, true)
    post_classify(cls)
    return cls
end
type_system.builtins.classify = classify
type_system.globals.classify = classify


make_methods(Type)
make_methods(Object)
make_methods(type_system.Method)

classify("BoundMethod", type_system.BoundMethod, nil, nil)