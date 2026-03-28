if fs.exists("autorun") and not fs.isDir("autorun") then
    printError("'autorun' exists and is not a folder.")
    return
end

if not fs.exists("autorun") then
    fs.makeDir("autorun")
end

local file = fs.open("autorun/TurtleExplorerAPI.lua", "w")
file.writeLine("shell.setPath(shell.path()..':TurtleExplorerAPI/bin')")
file.writeLine("package.path = package.path..';TurtleExplorerAPI/lib/?.lua'")
file.writeLine("for index, filename in ipairs(fs.list('TurtleExplorerAPI/autocomplete')) do")
file.writeLine("\tlocal path = shell.resolveProgram(filename)")
file.writeLine("\tlocal func = dofile('TurtleExplorerAPI/autocomplete/'..filename)")
file.writeLine("\tshell.setCompletionFunction(path, func)")
file.writeLine("end")
file.close()

print("Setup complete. Reboot to get access to TurtleExplorerAPI.")