local move_old = false
if fs.exists("startup") and not fs.isDir("startup") then
    os.rename("startup", "startup_old")
    move_old = true
end

if not fs.exists("startup") then
    fs.makeDir("startup")
end
if move_old then
    fs.copy("startup_old", "startup/startup")
    fs.delete("startup_old")
end

fs.copy("TurtleExplorerAPI/TurtleExplorerAPI.lua", "startup/TurtleExplorerAPI.lua")

print("Setup complete. Reboot to get access to TurtleExplorerAPI.")