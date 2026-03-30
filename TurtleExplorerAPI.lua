--- The startup script for the API. This is what sets up the API and makes it available to the user.

shell.setPath(shell.path()..":TurtleExplorerAPI/bin")

local function load_lib_dir(dir)
    for index, filename in ipairs(fs.list(dir)) do
        if fs.isDir(dir.."/"..filename) then
            load_lib_dir(dir.."/"..filename)
        else
            shell.run(dir.."/"..filename)
        end
    end
end

load_lib_dir("TurtleExplorerAPI/lib")
load_lib_dir("TurtleExplorerAPI/autocomplete")