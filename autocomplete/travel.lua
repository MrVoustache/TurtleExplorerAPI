--- Handles the autocompletion of the arguments of the travel script.
 
local tracker = require "tracker"





local function complete(shell, arg_index, current_arg, previous_args)
    if arg_index == 1 then
        return textutils.complete(current_arg, tracker.get_dict_names())
    end
    return {}
end

return complete