shell.setPath(shell.path() .. ":/lib/turtle_explorer_api/bin")
for index, file in ipairs(fs.list("/lib/turtle_explorer_api/autocompletion")) do
    shell.run("/lib/turtle_explorer_api/autocompletion/"..file)
end
