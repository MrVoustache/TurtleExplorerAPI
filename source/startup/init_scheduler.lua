shell.setPath(shell.path() .. ":/lib/turtle_explorer_api/bin")
for index, file in ipairs(fs.list("/lib/turtle_explorer_api/autocomplete")) do
    shell.run("/lib/turtle_explorer_api/autocomplete/"..file)
end
