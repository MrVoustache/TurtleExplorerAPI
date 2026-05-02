--- Handles the autocompletion of the arguments of the travel script.

local tracker = import "turtle_explorer_api.tracker"
 




local function complete(shell, arg_index, current_arg, previous_args)
    if arg_index == 1 then
        local names = tracker.get_dict_names()
        local dict = {}
        for _, name in ipairs(names) do
            if name:find(current_arg) == 1 then
                table.insert(dict, name:sub(#current_arg + 1))
            end
        end
        return dict
    end
    return {}
end

shell.setCompletionFunction(shell.resolveProgram("travel"), complete)