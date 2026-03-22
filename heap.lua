_G.heap = {}

---@generic T
---@class Heap<T> A binary heap class.
---@field hash fun(item: T): string
---@field data {string: T}
---@field heap string[]
---@field priorities {string: number}
---@field indices {string: number}
---@field locked boolean
---@field postponed {method: string, arguments:any[]}[]
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
    heap.locked = false
    heap.postponed = {}
    return heap
end

function Heap:__len()
    return #self.heap
end

--- Returns the priority of the next object.
---@return number? priority The priority or nil if the heap is empty.
function Heap:next_priority()
    if #self.heap > 0 then
        return
    end
    return self.priorities[self.heap[1]]
end

--- Acquires the heap for iteration. Modification operations will be postponed to a call to "release".
---@return boolean success If the heap lock was acquired.
function Heap:acquire()
    if self.locked then
        return false
    end
    self.locked = true
    return true
end

--- Releases the heap after iteration. Calls all the postponed modification method calls.
function Heap:release()
    if not self.locked then
        error("the heap was not locked", 2)
    end
    self.locked = false
    for index, operation in ipairs(self.postponed) do
        local method_name, arguments = operation.method, operation.arguments
        self[method_name](self, table.unpack(arguments))
    end
    self.postponed = {}
end

--- Pushes an item with a given priority.
---@param item T
---@param priority number
function Heap:push(item, priority)
    if type(priority) ~= "number" then
        error("expected number for priority, got '"..type(priority).."'", 2)
    end

    if self.locked then
        table.insert(self.postponed, {method = "push", arguments = {item, priority}})
        return
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

    if self.locked then
        table.insert(self.postponed, {method = "remove", arguments = {item}})
        return
    end

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

    if self.locked then
        table.insert(self.postponed, {method = "push", arguments = {}})
        return
    end

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
    return root_item, root_priority
end

--- Returns an iterator over the elements of the heap. They are NOT yielded in order but the heap does not change.
---@param max_priority number? A optional maximum priority. Elements with priority > max_priority will not be yielded.
---@return fun(): T? iterator An iterator function.
function Heap:iter(max_priority)
    if max_priority == nil then
        max_priority = math.huge
    end
    if type(max_priority) ~= "number" then
        error("expected number or nil as argument, got '"..type(max_priority).."'", 2)
    end
    local to_do = {1}
    return function ()
        if not self.locked then
            error("heap must be locked before iterating over it", 2)
        end
        while true do
            if #to_do == 0 then
                return
            end
            local index = to_do.pop()
            local h = self.heap[index]
            if h ~= nil then
                local priority = self.priorities[h]
                if priority <= max_priority then
                    table.insert(to_do, 2 * index)
                    table.insert(to_do, 2 * index + 1)
                    return self.data[h]
                end
            end
        end
    end
end