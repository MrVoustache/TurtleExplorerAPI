_G.heap = {}

---@generic T
---@class Heap<T> A binary heap class.
---@field hash fun(item: T): string
---@field data {string: T}
---@field heap string[]
---@field priorities {string: number}
---@field indices {string: number}
---@field compare fun(a: T, b: T): boolean
local Heap = {}
heap.Heap = Heap
Heap.__index = Heap
Heap.__name = "Heap"

--- Creates a new Binary Heap.
---@param hash fun(item: T): string
function Heap:new(hash)
    if type(hash) ~= "function" then
        error("expected function for hash, got '"..type(hash).."'", 2)
    end
    local heap = {}
    setmetatable(heap, self or Heap)
    heap.hash = hash
    heap.data = {}
    heap.heap = {}
    heap.priorities = {}
    heap.indices = {}
    return heap
end

-- function Heap:failsafe()
--     local function get_size(tab)
--         local n = 0
--         for key, value in pairs(tab) do
--             n = n + 1
--         end
--         return n
--     end
--     if #self.heap ~= get_size(self.data) or #self.heap ~= get_size(self.priorities) or #self.heap ~= get_size(self.indices) then
--         local file = fs.open("dump.data", "w")
--         file.write("heap: "..textutils.serialise(self.heap).."\n\n")
--         file.write("data: "..textutils.serialise(self.data).."\n\n")
--         file.write("priorities: "..textutils.serialise(self.priorities).."\n\n")
--         file.write("indices: "..textutils.serialise(self.indices).."\n\n")
--         file.close()
--         error("Invalid heap state!", 3)
--     end
-- end

function Heap:is_empty()
    return #self.heap == 0
end

function Heap:__len()
    return #self.heap
end

--- Pushes an item with a given priority.
---@param item T
---@param priority number
function Heap:push(item, priority)
    if type(priority) ~= "number" then
        error("expected number for priority, got '"..type(priority).."'", 2)
    end
    local h = self.hash(item)
    local index 
    if self.indices[h] == nil then
        self.data[h] = item
        table.insert(self.heap, h)
        index = #self.heap
        self.indices[h] = index
    else
        index = self.indices[h]
    end
    
    local old_priority = self.priorities[h]
    self.priorities[h] = priority

    if old_priority == priority then
        return
    end
    
    if old_priority == nil or priority < old_priority then
        -- Move up: priority decreased or new element
        local parent_index = math.floor(index / 2)
        local parent_hash = self.heap[parent_index]
        while parent_index > 0 and self.priorities[parent_hash] > priority do
            self.heap[parent_index], self.heap[index] = self.heap[index], self.heap[parent_index]
            self.indices[parent_hash], self.indices[h] = self.indices[h], self.indices[parent_hash]
            parent_index, index = math.floor(parent_index / 2), parent_index
            parent_hash = self.heap[parent_index]
        end
    elseif priority > old_priority then
        -- Move down: priority increased
        local left_child_index, right_child_index = 2 * index, 2 * index + 1
        local left_child_hash, right_child_hash = self.heap[left_child_index], self.heap[right_child_index]
        local left_child_priority, right_child_priority = self.priorities[left_child_hash] or math.huge, self.priorities[right_child_hash] or math.huge
        while priority > left_child_priority or priority > right_child_priority do
            local new_index, new_hash
            if left_child_priority < right_child_priority then
                new_index, new_hash = left_child_index, left_child_hash
            else
                new_index, new_hash = right_child_index, right_child_hash
            end
            self.heap[index], self.heap[new_index] = self.heap[new_index], self.heap[index]
            self.indices[h], self.indices[new_hash] = self.indices[new_hash], self.indices[h]
            index = new_index
            left_child_index, right_child_index = 2 * index, 2 * index + 1
            left_child_hash, right_child_hash = self.heap[left_child_index], self.heap[right_child_index]
            left_child_priority, right_child_priority = self.priorities[left_child_hash] or math.huge, self.priorities[right_child_hash] or math.huge
        end
    end
    -- self:failsafe()
end

--- Returns the priority of the given element. Returns nil if not in the heap.
---@param item T The item to look for.
---@return number? priority The priority of the given item, or nil.
function Heap:priority(item)
    local h = self.hash(item)
    if self.indices[h] ~= nil and self.data[h] == item then
        return self.priorities[h]
    end
end

--- Removes the given item with given priority from the heap.
---@param item T
function Heap:remove(item)
    local h = self.hash(item)
    if self.indices[h] == nil then
        error("item not found in heap", 2)
    end
    
    local index = self.indices[h]
    if self.data[h] ~= item then
        error("item not found in heap", 2)
    end
    
    local last_hash = table.remove(self.heap)
    
    if index <= #self.heap then
        self.heap[index] = last_hash
        self.indices[last_hash] = index
        
        local parent_index = math.floor(index / 2)
        local parent_hash = self.heap[parent_index]
        
        -- Move up
        while parent_index > 0 and self.priorities[parent_hash] > self.priorities[last_hash] do
            self.heap[index], self.heap[parent_index] = self.heap[parent_index], self.heap[index]
            self.indices[last_hash], self.indices[parent_hash] = self.indices[parent_hash], self.indices[last_hash]
            index = parent_index
            parent_index = math.floor(index / 2)
            parent_hash = self.heap[parent_index]
        end

        -- Move down
        local last_priority = self.priorities[last_hash]
        local left_child_index, right_child_index = 2 * index, 2 * index + 1
        local left_child_hash, right_child_hash = self.heap[left_child_index], self.heap[right_child_index]
        local left_child_priority, right_child_priority = self.priorities[left_child_hash] or math.huge, self.priorities[right_child_hash] or math.huge
        
        while last_priority > left_child_priority or last_priority > right_child_priority do
            local new_index, new_hash
            if left_child_priority < right_child_priority then
                new_index, new_hash = left_child_index, left_child_hash
            else
                new_index, new_hash = right_child_index, right_child_hash
            end
            self.heap[index], self.heap[new_index] = self.heap[new_index], self.heap[index]
            self.indices[last_hash], self.indices[new_hash] = self.indices[new_hash], self.indices[last_hash]
            index = new_index
            left_child_index, right_child_index = 2 * index, 2 * index + 1
            left_child_hash, right_child_hash = self.heap[left_child_index], self.heap[right_child_index]
            left_child_priority, right_child_priority = self.priorities[left_child_hash] or math.huge, self.priorities[right_child_hash] or math.huge
        end
    end
    
    self.data[h], self.priorities[h], self.indices[h] = nil, nil, nil
end

--- Removes and returns the item with the highest priority (lowest score).
---@return T? item
---@return number? priority
function Heap:pop()
    if #self.heap == 0 then return nil end
    
    local root_hash = self.heap[1]
    local last_hash = table.remove(self.heap)
    
    if #self.heap > 0 then
        self.heap[1] = last_hash
        local last_index = 1
        local last_priority = self.priorities[last_hash]
        local left_child_index, right_child_index = 2 * last_index, 2 * last_index + 1
        local left_child_hash, right_child_hash = self.heap[left_child_index], self.heap[right_child_index]
        local left_child_priority, right_child_priority = self.priorities[left_child_hash] or math.huge, self.priorities[right_child_hash] or math.huge
        while last_priority > left_child_priority or last_priority > right_child_priority do
            local new_last_index, new_last_hash
            if left_child_priority < right_child_priority then
                new_last_index, new_last_hash = left_child_index, left_child_hash
            else
                new_last_index, new_last_hash = right_child_index, right_child_hash
            end
            self.heap[last_index], self.heap[new_last_index] = self.heap[new_last_index], self.heap[last_index]
            self.indices[last_hash], self.indices[new_last_hash] = self.indices[new_last_hash], self.indices[last_hash]
            last_index = new_last_index
            left_child_index, right_child_index = 2 * last_index, 2 * last_index + 1
            left_child_hash, right_child_hash = self.heap[left_child_index], self.heap[right_child_index]
            left_child_priority, right_child_priority = self.priorities[left_child_hash] or math.huge, self.priorities[right_child_hash] or math.huge
        end
    end

    local root_item, root_priority = self.data[root_hash], self.priorities[root_hash]
    self.data[root_hash], self.priorities[root_hash], self.indices[root_hash] = nil, nil, nil
    -- self:failsafe()
    return root_item, root_priority
end