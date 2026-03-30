--- A module that helps identifying block types.

local blocks = {}
if _G.blocks ~= nil then
    return
end
_G.blocks = blocks
local LIQUIDS = {
    ["minecraft:water"] = true,
    ["minecraft:lava"] = true
}
local TEMPORARY = {
    ["minecraft:fire"] = true,
    ["computercraft:turtle_normal"] = true,
    ["computercraft:turtle_advanced"] = true
}

if fs.exists(".liquids") and not fs.isDir(".liquids") then
    local file = fs.open(".liquids", "r")
    local ok, err = pcall(textutils.unserialiseJSON, file.readAll())
    if ok then
        LIQUIDS = err
    end
    file.close()
end

if fs.exists(".temporary") and not fs.isDir(".temporary") then
    local file = fs.open(".temporary", "r")
    local ok, err = pcall(textutils.unserialiseJSON, file.readAll())
    if ok then
        TEMPORARY = err
    end
    file.close()
end





--- Returns whether this block is identified as a liquid (that the turtle can traverse).
---@param block string | {name: string} A block name or a block info as returned by inspect().
---@return boolean is_liquid If the block is liquid.
function blocks.is_liquid(block)
    if type(block) == "string" then
        return LIQUIDS[block] == true
    elseif type(block) == "table" and type(block.name) == "string" then
        return LIQUIDS[block.name] == true
    else
        error("expected string or block data, got '"..type(block).."'", 2)
    end
end

--- Returns whether this block is identified as a temporary block (that may disappear a few seconds later on its own).
---@param block string | {name: string} A block name or a block info as returned by inspect().
---@return boolean is_temporary If the block is temporary.
function blocks.is_temporary(block)
    if type(block) == "string" then
        return TEMPORARY[block] == true
    elseif type(block) == "table" and type(block.name) == "string" then
        return TEMPORARY[block.name] == true
    else
        error("expected string or block data, got '"..type(block).."'", 2)
    end
end

--- Sets the given block as a liquid (or not).
---@param block string | {name: string} The block name of block info.
---@param is_liquid boolean? If set to false, removes the block from the list of liquids.
function blocks.set_liquid(block, is_liquid)
    if is_liquid == nil then
        is_liquid = true
    end
    if type(is_liquid) ~= "boolean" then
        error("expected boolean or nil for second argument, got '"..type(is_liquid).."'", 2)
    end
    local key
    if type(block) == "string" then
        key = block
    elseif type(block) == "table" and type(block.name) == "string" then
        key = block.name
    else
        error("expected string or block data for first argument, got '"..type(block).."'", 2)
    end
    if is_liquid then
        LIQUIDS[key] = true
    else
        LIQUIDS[key] = nil
    end
    local file = fs.open(".liquids", "w")
    file.write(textutils.serialiseJSON(LIQUIDS))
    file.close()
end

--- Sets the given block as a temporary block (or not).
---@param block string | {name: string} The block name of block info.
---@param is_temporary boolean? If set to false, removes the block from the list of temporary blocks.
function blocks.set_temporary(block, is_temporary)
    if is_temporary == nil then
        is_temporary = true
    end
    if type(is_temporary) ~= "boolean" then
        error("expected boolean or nil for second argument, got '"..type(is_temporary).."'", 2)
    end
    local key
    if type(block) == "string" then
        key = block
    elseif type(block) == "table" and type(block.name) == "string" then
        key = block.name
    else
        error("expected string or block data for first argument, got '"..type(block).."'", 2)
    end
    if is_temporary then
        TEMPORARY[key] = true
    else
        TEMPORARY[key] = nil
    end
    local file = fs.open(".temporary", "w")
    file.write(textutils.serialiseJSON(TEMPORARY))
    file.close()
end





return blocks