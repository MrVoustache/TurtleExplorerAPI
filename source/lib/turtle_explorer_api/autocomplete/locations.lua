--- Handles the autocompletion of the arguments of the locations script.

local tracker = import "turtle_explorer_api.tracker"





local modes = {["list"] = "list", ["ls"] = "ls", ["remove"] = "remove ", ["rm"] = "rm ", ["delete"] = "delete ", ["del"] = "del ", ["add"] = "add ", ["save"] = "save "}

local function complete(shell, arg_index, current_arg, previous_args)
    if arg_index == 1 then
        local dict = {}
        for key, value in pairs(modes) do
            if key:find(current_arg) == 1 then
                table.insert(dict, value:sub(#current_arg + 1))
            end
        end
        return dict
    else
        local mode = previous_args[2]
        if (mode == "remove" or mode == "rm" or mode == "delete" or mode == "del") and arg_index == 2 then
            local names = tracker.get_dict_names()
            local dict = {}
            for _, name in ipairs(names) do
                if name:find(current_arg) == 1 then
                    table.insert(dict, name:sub(#current_arg + 1))
                end
            end
            return dict
        else
            return {}
        end
    end
end

shell.setCompletionFunction(shell.resolveProgram("locations"), complete)
