--- This code defines a common metaclass to handle all Lua operators and its associated methods.





local NotImplemented = {}
type_system.NotImplemented = NotImplemented
type_system.globals.NotImplemented = NotImplemented
type_system.builtins.NotImplemented = NotImplemented

type_system.pythonic_overloading_metatable = {}


--- Redirect all interactions with the interpreter with Pythonic objects through the pythonic_overloading_metatable:
type_system.metamethod_index = {
    -- arithmetics
    __add = {"__add", "__radd"},
    __sub = {"__sub", "__rsub"},
    __mul = {"__mul", "__rmul"},
    __div = {"__div", "__rdiv"},
    __unm = {"__unm"},
    __mod = {"__mod", "__rmod"},
    __pow = {"__pow", "__rpow"},
    __idiv = {"__idiv", "__ridiv"},

    -- binary
    __band = {"__band", "__rband"},
    __bor = {"__bor", "__rbor"},
    __bxor = {"__bxor", "__rbxor"},
    __bnot = {"__bnot"},
    __shl = {"__shl", "__rshl"},
    __shr = {"__shr", "__rshr"},

    -- comparisons
    __eq = {"__eq"},
    __lt = {"__lt", "__gt"},
    __le = {"__le", "__ge"},

    -- tables
    __len = {"__len"},
    __index = {"__getindex"},
    __newindex = {"__setindex"},

    -- strings
    __concat = {"__concat", "__rconcat"},
    __tostring = {"__tostring"},

    -- calling
    __call = {"__call"},
    
    -- iteration
    __pairs = {"__pairs"},
    __ipairs = {"__ipairs"}
}

local method_cache = {}

local function add_metamethod_to_cache(cls, method_name, method)
    if method_cache[cls] == nil then
        method_cache[cls] = {}
    end
    method_cache[cls][method_name] = method
end


local function invalidate_metamethod_cache(cls)
    log("Invalidating metamethod cache for class '"..tostring(cls.__name).."'")
    method_cache[cls] = nil
    for _, subcls in ipairs(cls.__direct_subclasses) do
        invalidate_metamethod_cache(subcls)
    end
end

type_system.register_cache_invalidation_callback(invalidate_metamethod_cache)

---@generic T
--- Tries to find the metamethod for performing a Lua operation but Python style, resolving the method location in the object class.
---@param obj T
---@param method_name string The name of the method to find.
function type_system.simple_resolve_metamethod(obj, method_name)
    local cls = type_system.type(obj)
    if not type_system.is_class(cls) then
        return nil
    end
    if method_cache[cls] ~= nil and method_cache[cls][method_name] ~= nil then
        return method_cache[cls][method_name]
    end
    log("Searching for method '"..method_name.."' for a '"..cls.__name.."' object ("..tostring(type_system.method_resolution_loop_breakers[cls])..", "..tostring(type_system.method_resolution_loop_breakers[cls] and type_system.method_resolution_loop_breakers[cls][method_name])..")")
    if type_system.method_resolution_loop_breakers[cls] ~= nil and type_system.method_resolution_loop_breakers[cls][method_name] ~= nil then
        return type_system.method_resolution_loop_breakers[cls][method_name]
    end
    local meta = type_system.type(cls)
    local mt_getindex = meta.__getindex
    if mt_getindex == nil then
        error("runtime error")
    end
    local res = mt_getindex(cls, method_name)
    add_metamethod_to_cache(cls, method_name, res)
    return res
end

-- Arithmetics

function type_system.pythonic_overloading_metatable.__add(self, other)      -- checks for __add and __radd
    local method = type_system.simple_resolve_metamethod(self, "__add")
    if method ~= nil then
        local ok, err_or_res = pcall(method, self, other)
        if not ok then
            error(err_or_res, 0)
        end
        if not rawequal(err_or_res, NotImplemented) then
            return err_or_res
        end
    end
    local reflexive_method = type_system.simple_resolve_metamethod(other, "__radd")
    if reflexive_method ~= nil then
        local ok, err_or_res = pcall(reflexive_method, other, self)
        if not ok then
            error(err_or_res, 0)
        end
        if not rawequal(err_or_res, NotImplemented) then
            return err_or_res
        end
    end
    error("attempt to perform arithmetic: '+' on '"..tostring(type_system.type(self)).."' and '"..type_system.type(other).."'", 2)
end
function type_system.pythonic_overloading_metatable.__sub(self, other)      -- checks for __sub and __rsub
    local method = type_system.simple_resolve_metamethod(self, "__sub")
    if method ~= nil then
        local ok, err_or_res = pcall(method, self, other)
        if not ok then
            error(err_or_res, 0)
        end
        if not rawequal(err_or_res, NotImplemented) then
            return err_or_res
        end
    end
    local reflexive_method = type_system.simple_resolve_metamethod(other, "__rsub")
    if reflexive_method ~= nil then
        local ok, err_or_res = pcall(reflexive_method, other, self)
        if not ok then
            error(err_or_res, 0)
        end
        if not rawequal(err_or_res, NotImplemented) then
            return err_or_res
        end
    end
    error("attempt to perform arithmetic: '-' on '"..tostring(type_system.type(self)).."' and '"..type_system.type(other).."'", 2)
end

function type_system.pythonic_overloading_metatable.__mul(self, other)      -- checks for __mul and __rmul
    local method = type_system.simple_resolve_metamethod(self, "__mul")
    if method ~= nil then
        local ok, err_or_res = pcall(method, self, other)
        if not ok then
            error(err_or_res, 0)
        end
        if not rawequal(err_or_res, NotImplemented) then
            return err_or_res
        end
    end
    local reflexive_method = type_system.simple_resolve_metamethod(other, "__rmul")
    if reflexive_method ~= nil then
        local ok, err_or_res = pcall(reflexive_method, other, self)
        if not ok then
            error(err_or_res, 0)
        end
        if not rawequal(err_or_res, NotImplemented) then
            return err_or_res
        end
    end
    error("attempt to perform arithmetic: '*' on '"..tostring(type_system.type(self)).."' and '"..type_system.type(other).."'", 2)
end

function type_system.pythonic_overloading_metatable.__div(self, other)      -- checks for __div and __rdiv
    local method = type_system.simple_resolve_metamethod(self, "__div")
    if method ~= nil then
        local ok, err_or_res = pcall(method, self, other)
        if not ok then
            error(err_or_res, 0)
        end
        if not rawequal(err_or_res, NotImplemented) then
            return err_or_res
        end
    end
    local reflexive_method = type_system.simple_resolve_metamethod(other, "__rdiv")
    if reflexive_method ~= nil then
        local ok, err_or_res = pcall(reflexive_method, other, self)
        if not ok then
            error(err_or_res, 0)
        end
        if not rawequal(err_or_res, NotImplemented) then
            return err_or_res
        end
    end
    error("attempt to perform arithmetic: '/' on '"..tostring(type_system.type(self)).."' and '"..type_system.type(other).."'", 2)
end

function type_system.pythonic_overloading_metatable.__unm(self)             -- checks for __unm
    local method = type_system.simple_resolve_metamethod(self, "__unm")
    if method ~= nil then
        local ok, err_or_res = pcall(method, self)
        if not ok then
            error(err_or_res, 0)
        end
        if not rawequal(err_or_res, NotImplemented) then
            return err_or_res
        end
    end
    error("attempt to perform arithmetic: unary '-' on '"..tostring(type_system.type(self)).."'", 2)
end

function type_system.pythonic_overloading_metatable.__mod(self, other)      -- checks for __mod and __rmod
    local method = type_system.simple_resolve_metamethod(self, "__mod")
    if method ~= nil then
        local ok, err_or_res = pcall(method, self, other)
        if not ok then
            error(err_or_res, 0)
        end
        if not rawequal(err_or_res, NotImplemented) then
            return err_or_res
        end
    end
    local reflexive_method = type_system.simple_resolve_metamethod(other, "__rmod")
    if reflexive_method ~= nil then
        local ok, err_or_res = pcall(reflexive_method, other, self)
        if not ok then
            error(err_or_res, 0)
        end
        if not rawequal(err_or_res, NotImplemented) then
            return err_or_res
        end
    end
    error("attempt to perform arithmetic: '%' on '"..tostring(type_system.type(self)).."' and '"..type_system.type(other).."'", 2)
end

function type_system.pythonic_overloading_metatable.__pow(self, other)      -- checks for __pow and __rpow
    local method = type_system.simple_resolve_metamethod(self, "__pow")
    if method ~= nil then
        local ok, err_or_res = pcall(method, self, other)
        if not ok then
            error(err_or_res, 0)
        end
        if not rawequal(err_or_res, NotImplemented) then
            return err_or_res
        end
    end
    local reflexive_method = type_system.simple_resolve_metamethod(other, "__rpow")
    if reflexive_method ~= nil then
        local ok, err_or_res = pcall(reflexive_method, other, self)
        if not ok then
            error(err_or_res, 0)
        end
        if not rawequal(err_or_res, NotImplemented) then
            return err_or_res
        end
    end
    error("attempt to perform arithmetic: '^' on '"..tostring(type_system.type(self)).."' and '"..type_system.type(other).."'", 2)
end

function type_system.pythonic_overloading_metatable.__idiv(self, other)      -- checks for __idiv and __ridiv
    local method = type_system.simple_resolve_metamethod(self, "__idiv")
    if method ~= nil then
        local ok, err_or_res = pcall(method, self, other)
        if not ok then
            error(err_or_res, 0)
        end
        if not rawequal(err_or_res, NotImplemented) then
            return err_or_res
        end
    end
    local reflexive_method = type_system.simple_resolve_metamethod(other, "__ridiv")
    if reflexive_method ~= nil then
        local ok, err_or_res = pcall(reflexive_method, other, self)
        if not ok then
            error(err_or_res, 0)
        end
        if not rawequal(err_or_res, NotImplemented) then
            return err_or_res
        end
    end
    error("attempt to perform arithmetic: '//' on '"..tostring(type_system.type(self)).."' and '"..type_system.type(other).."'", 2)
end

-- Binary

function type_system.pythonic_overloading_metatable.__band(self, other)     -- checks for __band and __rband
    local method = type_system.simple_resolve_metamethod(self, "__band")
    if method ~= nil then
        local ok, err_or_res = pcall(method, self, other)
        if not ok then
            error(err_or_res, 0)
        end
        if not rawequal(err_or_res, NotImplemented) then
            return err_or_res
        end
    end
    local reflexive_method = type_system.simple_resolve_metamethod(other, "__rband")
    if reflexive_method ~= nil then
        local ok, err_or_res = pcall(reflexive_method, other, self)
        if not ok then
            error(err_or_res, 0)
        end
        if not rawequal(err_or_res, NotImplemented) then
            return err_or_res
        end
    end
    error("attempt to perform bitwise operation: '&' on '"..tostring(type_system.type(self)).."' and '"..type_system.type(other).."'", 2)
end

function type_system.pythonic_overloading_metatable.__bor(self, other)      -- checks for __bor and __rbor
    local method = type_system.simple_resolve_metamethod(self, "__bor")
    if method ~= nil then
        local ok, err_or_res = pcall(method, self, other)
        if not ok then
            error(err_or_res, 0)
        end
        if not rawequal(err_or_res, NotImplemented) then
            return err_or_res
        end
    end
    local reflexive_method = type_system.simple_resolve_metamethod(other, "__rbor")
    if reflexive_method ~= nil then
        local ok, err_or_res = pcall(reflexive_method, other, self)
        if not ok then
            error(err_or_res, 0)
        end
        if not rawequal(err_or_res, NotImplemented) then
            return err_or_res
        end
    end
    error("attempt to perform bitwise operation: '|' on '"..tostring(type_system.type(self)).."' and '"..type_system.type(other).."'", 2)
end

function type_system.pythonic_overloading_metatable.__bxor(self, other)     -- checks for __bxor and __rbxor
    local method = type_system.simple_resolve_metamethod(self, "__bxor")
    if method ~= nil then
        local ok, err_or_res = pcall(method, self, other)
        if not ok then
            error(err_or_res, 0)
        end
        if not rawequal(err_or_res, NotImplemented) then
            return err_or_res
        end
    end
    local reflexive_method = type_system.simple_resolve_metamethod(other, "__rbxor")
    if reflexive_method ~= nil then
        local ok, err_or_res = pcall(reflexive_method, other, self)
        if not ok then
            error(err_or_res, 0)
        end
        if not rawequal(err_or_res, NotImplemented) then
            return err_or_res
        end
    end
    error("attempt to perform bitwise operation: '~' on '"..tostring(type_system.type(self)).."' and '"..type_system.type(other).."'", 2)
end

function type_system.pythonic_overloading_metatable.__bnot(self)            -- checks for __bnot
    local method = type_system.simple_resolve_metamethod(self, "__bnot")
    if method ~= nil then
        local ok, err_or_res = pcall(method, self)
        if not ok then
            error(err_or_res, 0)
        end
        if not rawequal(err_or_res, NotImplemented) then
            return err_or_res
        end
    end
    error("attempt to perform bitwise operation: '~' on '"..tostring(type_system.type(self)).."'", 2)
end

function type_system.pythonic_overloading_metatable.__shl(self, other)      -- checks for __shl and __rshl
    local method = type_system.simple_resolve_metamethod(self, "__shl")
    if method ~= nil then
        local ok, err_or_res = pcall(method, self, other)
        if not ok then
            error(err_or_res, 0)
        end
        if not rawequal(err_or_res, NotImplemented) then
            return err_or_res
        end
    end
    local reflexive_method = type_system.simple_resolve_metamethod(other, "__rshl")
    if reflexive_method ~= nil then
        local ok, err_or_res = pcall(reflexive_method, other, self)
        if not ok then
            error(err_or_res, 0)
        end
        if not rawequal(err_or_res, NotImplemented) then
            return err_or_res
        end
    end
    error("attempt to perform bitwise operation: '<<' on '"..tostring(type_system.type(self)).."' and '"..type_system.type(other).."'", 2)
end

function type_system.pythonic_overloading_metatable.__shr(self, other)      -- checks for __shr and __rshr
    local method = type_system.simple_resolve_metamethod(self, "__shr")
    if method ~= nil then
        local ok, err_or_res = pcall(method, self, other)
        if not ok then
            error(err_or_res, 0)
        end
        if not rawequal(err_or_res, NotImplemented) then
            return err_or_res
        end
    end
    local reflexive_method = type_system.simple_resolve_metamethod(other, "__rshr")
    if reflexive_method ~= nil then
        local ok, err_or_res = pcall(reflexive_method, other, self)
        if not ok then
            error(err_or_res, 0)
        end
        if not rawequal(err_or_res, NotImplemented) then
            return err_or_res
        end
    end
    error("attempt to perform bitwise operation: '>>' on '"..tostring(type_system.type(self)).."' and '"..type_system.type(other).."'", 2)
end

-- Comparisons

function type_system.pythonic_overloading_metatable.__eq(self, other)       -- checks for __eq
    local method = type_system.simple_resolve_metamethod(self, "__eq")
    if method ~= nil then
        local ok, err_or_res = pcall(method, self, other)
        if not ok then
            error(err_or_res, 0)
        end
        if not rawequal(err_or_res, NotImplemented) then
            return err_or_res
        end
    end
    local reflexive_method = type_system.simple_resolve_metamethod(other, "__eq")
    if reflexive_method ~= nil then
        local ok, err_or_res = pcall(reflexive_method, other, self)
        if not ok then
            error(err_or_res, 0)
        end
        if not rawequal(err_or_res, NotImplemented) then
            return err_or_res
        end
    end
    return false
end

function type_system.pythonic_overloading_metatable.__lt(self, other)       -- checks for __lt and __gt
    local method = type_system.simple_resolve_metamethod(self, "__lt")
    if method ~= nil then
        local ok, err_or_res = pcall(method, self, other)
        if not ok then
            error(err_or_res, 0)
        end
        if not rawequal(err_or_res, NotImplemented) then
            return err_or_res
        end
    end
    local reflexive_method = type_system.simple_resolve_metamethod(other, "__gt")
    if reflexive_method ~= nil then
        local ok, err_or_res = pcall(reflexive_method, other, self)
        if not ok then
            error(err_or_res, 0)
        end
        if not rawequal(err_or_res, NotImplemented) then
            return err_or_res
        end
    end
    error("attempt to compare '"..tostring(type_system.type(self)).."' and '"..type_system.type(other).."'", 2)
end

function type_system.pythonic_overloading_metatable.__le(self, other)       -- checks for __le and __ge
    local method = type_system.simple_resolve_metamethod(self, "__le")
    if method ~= nil then
        local ok, err_or_res = pcall(method, self, other)
        if not ok then
            error(err_or_res, 0)
        end
        if not rawequal(err_or_res, NotImplemented) then
            return err_or_res
        end
    end
    local reflexive_method = type_system.simple_resolve_metamethod(other, "__ge")
    if reflexive_method ~= nil then
        local ok, err_or_res = pcall(reflexive_method, other, self)
        if not ok then
            error(err_or_res, 0)
        end
        if not rawequal(err_or_res, NotImplemented) then
            return err_or_res
        end
    end
    error("attempt to compare '"..tostring(type_system.type(self)).."' and '"..type_system.type(other).."'", 2)
end

-- Tables

function type_system.pythonic_overloading_metatable.__index(self, key)
    local method = type_system.simple_resolve_metamethod(self, "__getindex")
    if method ~= nil then
        local ok, err_or_res = pcall(method, self, key)
        if not ok then
            error(err_or_res, 0)
        end
        if not rawequal(err_or_res, NotImplemented) then
            return err_or_res
        end
    end
    error("attempt to index '"..tostring(type_system.type(self)).."' with key '"..tostring(key).."'", 2)
end

function type_system.pythonic_overloading_metatable.__newindex(self, key, value)
    local method = type_system.simple_resolve_metamethod(self, "__setindex")
    if method ~= nil then
        local ok, err = pcall(method, self, key, value)
        if not ok then
            error(err, 0)
        end
        return
    end
    error("attempt to set index '"..tostring(key).."' on '"..tostring(type_system.type(self)).."'", 2)
end

function type_system.pythonic_overloading_metatable.__len(self)
    local method = type_system.simple_resolve_metamethod(self, "__len")
    if method ~= nil then
        local ok, err_or_res = pcall(method, self)
        if not ok then
            error(err_or_res, 0)
        end
        if not rawequal(err_or_res, NotImplemented) then
            return err_or_res
        end
    end
    error("attempt to get length of '"..tostring(type_system.type(self)).."'", 2)
end

-- Strings

function type_system.pythonic_overloading_metatable.__tostring(self)
    local method = type_system.simple_resolve_metamethod(self, "__tostring")
    if method ~= nil then
        local ok, err_or_res = pcall(method, self)
        if not ok then
            error(err_or_res, 0)
        end
        if not rawequal(err_or_res, NotImplemented) then
            return err_or_res
        end
    end
    error("attempt to convert '"..tostring(type_system.type(self)).."' to string", 2)
end

function type_system.pythonic_overloading_metatable.__concat(self, other)
    local method = type_system.simple_resolve_metamethod(self, "__concat")
    if method ~= nil then
        local ok, err_or_res = pcall(method, self, other)
        if not ok then
            error(err_or_res, 0)
        end
        if not rawequal(err_or_res, NotImplemented) then
            return err_or_res
        end
    end
    local reflexive_method = type_system.simple_resolve_metamethod(other, "__rconcat")
    if reflexive_method ~= nil then
        local ok, err_or_res = pcall(reflexive_method, other, self)
        if not ok then
            error(err_or_res, 0)
        end
        if not rawequal(err_or_res, NotImplemented) then
            return err_or_res
        end
    end
    error("attempt to concatenate '"..tostring(type_system.type(self)).."' and '"..type_system.type(other).."'", 2)
end

-- Calling

function type_system.pythonic_overloading_metatable.__call(self, ...)
    local method = type_system.simple_resolve_metamethod(self, "__call")
    if method ~= nil then
        local ok, err_or_res = pcall(method, self, ...)
        if not ok then
            error(err_or_res, 0)
        end
        if not rawequal(err_or_res, NotImplemented) then
            return err_or_res
        end
    end
    error("attempt to call '"..tostring(type_system.type(self)).."'", 2)
end

-- Iteration

function type_system.pythonic_overloading_metatable.__pairs(self)
    local method = type_system.simple_resolve_metamethod(self, "__pairs")
    if method ~= nil then
        local ok, err_or_res = pcall(method, self)
        if not ok then
            error(err_or_res, 0)
        end
        if not rawequal(err_or_res, NotImplemented) then
            return err_or_res
        end
    end
    error("attempt to iterate over '"..tostring(type_system.type(self)).."'", 2)
end

function type_system.pythonic_overloading_metatable.__ipairs(self)
    local method = type_system.simple_resolve_metamethod(self, "__ipairs")
    if method ~= nil then
        local ok, err_or_res = pcall(method, self)
        if not ok then
            error(err_or_res, 0)
        end
        if not rawequal(err_or_res, NotImplemented) then
            return err_or_res
        end
    end
    error("attempt to iterate over '"..tostring(type_system.type(self)).."'", 2)
end