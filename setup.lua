if fs.exists("autorun") and not fs.isDir("autorun") then
    printError("'autorun' exists and is not a folder.")
    return
end

if not fs.exists("autorun") then
    fs.makeDir("autorun")
end

fs.copy("TurtleExplorerAPI/TurtleExplorerAPI.lua", "autorun/TurtleExplorerAPI.lua")

local file = fs.open("startup.lua", "w")
file.writeLine("if fs.exists('autorun') and fs.isDir('autorun') then")
file.writeLine("\tfor index, filename in ipairs(fs.list('autorun')) do")
file.writeLine("\t\tshell.run('autorun/'..filename)")
file.writeLine("\tend")
file.writeLine("end")
file.close()

print("Setup complete. Reboot to get access to TurtleExplorerAPI.")