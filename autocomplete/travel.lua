--- Handles the autocompletion of the arguments of the travel script.
 




local function complete(shell, arg_index, current_arg, previous_args)
    if arg_index == 1 then
        local names = tracker.get_dict_names()
        local dict = {}
        for _, name in ipairs(names) do
            dict[name] = name
        end
        return textutils.complete(current_arg, dict)
    end
    return {}
end

shell.setCompletionFunction(shell.resolveProgram("travel"), complete)