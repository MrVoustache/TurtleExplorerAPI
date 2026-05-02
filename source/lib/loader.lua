--- This module defines a working alternative to "require" and the package module.





if _G.loader ~= nil then
    return _G.loader
end
local loader = {}
_G.loader = loader

local PATH = {          ---@type string[] A list of paths in which to search for modules.
    "/lib/",
    "/rom/modules/main/",
}

if _G.turtle ~= nil then
    table.insert(PATH, "/rom/modules/turtle")
end

--- Converts a module name to a path (replaces "." by "/").
---@param name string The module name.
---@return string path The module path.
local function name_to_path(name)
    local path = name:gsub("%.", "/")
    return path
end

--- Returns an absolute module name given a relative module name. For each leading "." the module path is resolved to the above directory (a single means relative to the cwd). 
---@param name string The relative module name.
---@param cwd string The current working directory.
---@return string absolute_path The absolute module name to be used by the importators.
function loader.relative_to_absolute_module(name, cwd)
    -- Count leading dots
    local dots = 0
    while name:sub(1, 1) == "." do
        dots = dots + 1
        name = name:sub(2)
    end
    -- Calculate levels to go up (dots - 1, since one dot means relative to cwd)
    local up = dots - 1
    -- Split cwd into directory parts
    local parts = {}
    local i = 1
    while i <= #cwd do
        if cwd:sub(i, i) == "/" then
            i = i + 1
        else
            local j = cwd:find("/", i)
            if not j then j = #cwd + 1 end
            table.insert(parts, cwd:sub(i, j - 1))
            i = j
        end
    end
    -- Remove 'up' levels from the end
    for _ = 1, up do
        if #parts > 0 then
            table.remove(parts)
        end
    end
    -- Construct base path
    local base = "." .. table.concat(parts, "/")
    if #parts == 0 then base = "/" end
    -- Convert remaining name dots to slashes
    local path = name:gsub("%.", "/")
    -- Return absolute path with .lua extension
    return base .. "/" .. path
end

local relative_to_absolute_module = loader.relative_to_absolute_module

--- Executes the module at the given path and returns status and the loaded module.
---@param path string The path to the Lua file to execute.
---@return boolean succes If the module was successfully loaded.
---@return any | string mod_or_err Whatever the script returned on success, or the error message on error.
local function exec_module(path)
    local func, err = loadfile(path, "t", _G)
    if not func then
        return false, err
    end
    local ok, err_or_mod = pcall(func)
    return ok, err_or_mod
end

---@alias module_loader
---| fun(): boolean, table | string

--- Loads a lua file.
---@param name string The name of the lua module to look for.
---@param cwd string? The directory containing the script calling import().
---@return module_loader? loader The module loader if the module was found.
---@return string? final_path The path that the module was resolved to on success (for caching).
local function lua_file_loader(name, cwd)
    local path = nil
    local partial_path = nil
    if name:sub(1, 1) == "." then
        if cwd == nil then
            error("Cannot handle relative module path without source file.", 2)
        end
        partial_path = relative_to_absolute_module(name, cwd)
    else
        partial_path = name_to_path(name)
    end
    for _, pth in ipairs(PATH) do
        if fs.exists(pth..partial_path) and not fs.isDir(pth..partial_path) then
            path = pth..partial_path
            break
        end
        if fs.exists(pth..partial_path..".lua") and not fs.isDir(pth..partial_path..".lua") then
            path = pth..partial_path..".lua"
            break
        end
    end
    if path ~= nil then
        return function ()
            return exec_module(path)
        end, path
    end
end

--- Loads a lua package (a folder with a "init.lua" file in it).
---@param name string The name of the lua package to look for.
---@param cwd string? The directory containing the script calling import().
---@return module_loader? loader The module loader if the module was found.
---@return string? final_path The path that the module was resolved to on success (for caching).
local function lua_package_loader(name, cwd)
    local path = nil
    local partial_path = nil
    if name:sub(1, 1) == "." then
        if cwd == nil then
            error("Cannot handle relative module path without source file.", 2)
        end
        partial_path = relative_to_absolute_module(name, cwd)
    else
        partial_path = name_to_path(name)
    end
    for _, pth in ipairs(PATH) do
        if fs.exists(pth..partial_path.."/init.lua") and not fs.isDir(pth..partial_path.."/init.lua") then
            path = pth..partial_path.."/init.lua"
            break
        end
    end
    if path ~= nil then
        return function ()
            return exec_module(path)
        end, path
    end
end





local METAPATH = {      ---@type (fun(name: string, cwd: string?): nil | module_loader, nil | string)[]
    lua_file_loader,
    lua_package_loader
}





--- Return the current package path as an array of string.byte
---@return string[] path The different module paths.
function loader.get_path()
    local copy = {}
    for i, v in ipairs(PATH) do
        copy[i] = v
    end
    return copy
end


--- Adds a new entry to the package path.
---@param path string The new path to add. Should end with "/".
function loader.add_path(path)
    if type(path) ~= "string" then
        error("expected string, got '"..type(path).."'", 2)
    end
    table.insert(PATH, path)
end

--- Removes an existing entry in the path. Does nothing if it was not in the path.
---@param path string The path to remove.
---@return boolean existed If the given path was in the package path.
function loader.remove_from_path(path)
    for i, p in ipairs(PATH) do
        if p == path then
            table.remove(PATH, i)
            return true
        end
    end
    return false
end





local module_cache = {}             ---@type table<string, any> The module cache for modules that have already been loaded.

local this_path = debug.getinfo(1).source:sub(2)
module_cache[this_path] = loader

--- Imports and returns the given module. Resolving the package through the module metapath and path.
---@param module_name string The module name. If preceeded with a ".", the import is relative to the directory of the script performing the import. With ".." it is relative to the parent, etc.
---@return any module The loaded module, whatever the corresponding script returned.
function loader.import(module_name)
    if type(module_name) ~= "string" then
        error("expected string for argument #1, got '"..type(module_name).."'", 2)
    end
    
    -- Get the path of the script that called import
    local caller_path = nil
    local debug_info = debug.getinfo(2)
    if debug_info and debug_info.source and debug_info.source:sub(1, 1) == "@" then
        caller_path = debug_info.source:sub(2)
    else
        caller_path = nil
        if module_name.sub(1, 1) == "." then
            error("trying to import a relative module from outside a Lua script file", 2)
        end
    end

    
    for _, metaloader in ipairs(METAPATH) do
        local loader, final_path = metaloader(module_name, caller_path)
        if loader ~= nil and final_path ~= nil then
            if module_cache[final_path] ~= nil then
                return module_cache[final_path]
            end
            local ok, mod_or_err = loader()
            if not ok then
                error(mod_or_err, 2)
            end
            module_cache[final_path] = mod_or_err
            return mod_or_err
        end
    end

    error("could not locate module '"..module_name.."'", 2)
end
_G.import = loader.import





return loader