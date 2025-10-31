local file = fileOpen("layta.lua")
local bundle = fileRead(file, fileGetSize(file))
fileClose(file)

local module = table.concat({
	"if not Layta then",
	"Layta = setmetatable({}, {__index = _G})",
	"local fn = loadstring([=[" .. bundle .. "]=])",
	"setfenv(fn, Layta)",
	"pcall(fn)",
	"end",
}, "\n")

function import()
	return module
end
