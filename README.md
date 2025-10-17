![Layta](https://github.com/TRtam/Layta/blob/main/logo.png?raw=true)

# Layta
Layta is a embeddable modern flexbox-based layout engine and dxGUI framework designed to simplify interface development. It provides a comprehensive toolkit for building responsive, visually consistent user interfaces with minimal complexity. Layta streamlines layout management and component design, empowering developers to create modern applications efficiently and elegantly.

## Why?
Since I began developing scripts for MTA:SA, I’ve created numerous user interfaces using [dx-drawing functions](https://wiki.multitheftauto.com/wiki/Client_Scripting_Functions#Drawing_functions). Throughout that process, I often wished for a system that could handle interface layout automatically—eliminating the need to manually position elements or rely on small helper functions to align them with their parent components. Layta was born from that vision: a desire to bring structure, flexibility, and ease to UI creation, allowing developers to focus on design and functionality rather than layout constraints.

## Getting Started
```lua
local tree = Layta.Node({
	justifyContent = "center",
	alignItems = "center",
	width = 500,
	height = 500,
	backgroundColor = 0xff222222,
	children = {
		Layta.Node({ width = "100%", height = 100, backgroundColor = 0xff553333 }),
	},
})

addEventHandler("onClientRender", root, function()
	Layta.computeLayout(tree, 1920, nil, nil, nil, true, false)
end)

addEventHandler("onClientRender", root, function()
	Layta.renderer(tree, 0, 0)
end)
```