local file = fileOpen("layta.lua")
local bundle = fileRead(file, fileGetSize(file))
fileClose(file)

-- stylua: ignore start
local module = table.concat({
	"if not Layta then",
		"Layta = setmetatable({}, {__index = _G})",
		"local fn = loadstring([=[" .. bundle .. "]=])",
		"setfenv(fn, Layta)",
		"pcall(fn)",
		"Layta.initialize()",
	"end",
}, "\n")
-- stylua: ignore end

function import()
	return module
end
