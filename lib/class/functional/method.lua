--- This module defines the Method class, which represents a method of a class. It also defines BoundMethod, which represents a method that is bound to an instance of a class.





---@generic T
---@class Method : Object A method of a class. This is a wrapper around a function that allows it to retain the name and class it is bound to.
---@field __func fun(instance : T, ...) The underlying function of the method.
---@field __name string The name of the method.
---@field __owner Type<T> The class the method is bound to.
local Method = {}
type_system.Method = Method
type_system.builtins.Method = Method





---@generic T
--- Creates a new method.
--- @param func fun(instance : T, ...) The underlying function of the method.
function Method:__init(func)
    if type_system.type(func) ~= "function" then
        error("expected function for argument #1, got '"..type_system.type(func).."'")
    end
    self.__dict.__func = func
end


--- Internal function used to create a method before the type system is fully initialized, since the Method class is not a proper class yet.
function type_system.create_method_before_type_system(func)
    local method = {__dict = {__class = Method, __func = func}}
    type_system.old_setmetatable(method, type_system.pythonic_overloading_metatable)
    return method
end


---@generic T
--- Sets the name and class of the method. This is called when the method is assigned to the class.
--- @param owner Type<T> The class the method is being assigned to.
--- @param name string The name of the method.
function Method:__set_name(owner, name)
    self.__dict.__owner = owner
    self.__dict.__name = name
end


---@generic T
--- Calls the method as a normal function.
function Method:__call(...)
    local res = {pcall(self.__dict.__func, ...)}
    if not res[1] then
        error(res[2], 0)
    end
    return table.unpack(res, 2)
end

type_system.method_resolution_loop_breakers[Method] = {
    __call = Method.__call,
    __getindex = Object.__getindex
}


--- Returns a string representation of the method.
function Method:__tostring()
    if self.__dict.__owner ~= nil and self.__dict.__name ~= nil then
        return "<method '"..tostring(self.__dict.__name).."' of class '"..tostring(self.__dict.__owner.__name).."'>"
    else
        return "<unbound method at "..tostring(self)..">"
    end
end





---@generic T
---@class BoundMethod : Object A method that is bound to an instance of a class. This is what you get when you access a method on an instance of a class.
---@field __method Method<T> The underlying method.
---@field __instance T The instance the method is bound to.
local BoundMethod = {}
type_system.BoundMethod = BoundMethod
type_system.builtins.BoundMethod = BoundMethod





---@generic T
--- Creates a new bound method.
---@param method Method<T> The underlying method.
---@param instance T The instance the method is bound to.
function BoundMethod:__init(method, instance)
    self.__method = method
    self.__instance = instance
end


---@generic T
--- Calls the bound method, passing the instance as the first argument if not already passed.
function BoundMethod:__call(...)
    log("Calling bound method '"..tostring(self.__dict.__method.__dict.__name).."'!")
    local args = {...}
    local skip_first_arg = rawequal(args[1], self.__instance)
    local res = {pcall(self.__dict.__method.__dict.__func, self.__instance, table.unpack(args, skip_first_arg and 2 or 1))}
    if not res[1] then
        error(res[2], 0)
    end
    return table.unpack(res, 2)
end


--- Returns a string representation of the bound method.
function BoundMethod:__tostring()
    if self.__method.__owner ~= nil and self.__method.__name ~= nil then
        return "<bound method '"..tostring(self.__method.__name).."' of instance of class '"..tostring(self.__method.__owner.__name).."'>"
    else
        return "<bound method of object '"..tostring(self.__instance).."'>"
    end
end