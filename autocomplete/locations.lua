--- Handles the autocompletion of the arguments of the locations script.





local function complete(shell, arg_index, current_arg, previous_args)
    if arg_index == 1 then
        return textutils.complete(current_arg, {list = "list", ls = "ls", remove = "remove", rm = "rm", delete = "delete", del = "del", add = "add", save = "save"})
    else
        local mode = previous_args[1]
        if (mode == "remove" or mode == "rm" or mode == "delete" or mode == "del") and arg_index == 2 then
            return textutils.complete(current_arg, tracker.get_dict_names())
        else
            return {}
        end
    end
end

shell.setCompletionFunction(shell.resolveProgram("locations"), complete)
print("Set autocompletion for locations to "..tostring(complete))