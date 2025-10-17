local tree = Layta.Node({
	flexDirection = "column",
	padding = 10,
	gap = 10,
	width = 500,
	backgroundColor = 0xff222222,
	children = {
		Layta.Node({
			padding = 10,
			borderRadius = 5,
			backgroundColor = 0xff1c1e21,
			strokeColor = 0xff444950,
			gap = 10,
			children = {
				Layta.Node({
					borderRadius = 5,
					width = 100,
					height = 100,
					backgroundColor = 0xff444950,
					strokeColor = 0xff606770,
				}),
				Layta.Node({
					borderRadius = 5,
					width = 100,
					height = 100,
					backgroundColor = 0xff444950,
					strokeColor = 0xff606770,
				}),
				Layta.Node({
					borderRadius = 5,
					width = 100,
					height = 100,
					backgroundColor = 0xff444950,
					strokeColor = 0xff606770,
				}),
			},
		}),
		Layta.Node({
			flexDirection = "column",
			padding = 10,
			borderRadius = 5,
			backgroundColor = 0xff1c1e21,
			strokeColor = 0xff444950,
			gap = 10,
			children = {
				Layta.Node({
					borderRadius = 5,
					width = 100,
					height = 100,
					backgroundColor = 0xff444950,
					strokeColor = 0xff606770,
				}),
				Layta.Node({
					borderRadius = 5,
					width = 100,
					height = 100,
					backgroundColor = 0xff444950,
					strokeColor = 0xff606770,
				}),
				Layta.Node({
					borderRadius = 5,
					width = 100,
					height = 100,
					backgroundColor = 0xff444950,
					strokeColor = 0xff606770,
				}),
			},
		}),
	},
})

addEventHandler("onClientRender", root, function()
	Layta.computeLayout(tree, 1920, nil, nil, nil, true, false)
end)

addEventHandler("onClientRender", root, function()
	Layta.renderer(tree, 0, 0)
end)
