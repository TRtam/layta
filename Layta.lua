local screenWidth, screenHeight = guiGetScreenSize()
local screenScale = screenHeight / 1080

local function createClass(super)
	local class
	class = {}
	class.__index = class
	function class.destroy(object, ...)
		if type(object.destructor) == "function" then object:destructor(...) end
		setmetatable(object, nil)
	end
	setmetatable(class, {
		__index = function(_, key)
			return super and super[key]
		end,
		__call = function(_, ...)
			local object = setmetatable({}, class)
			if type(object.constructor) == "function" then object:constructor(...) end
			return object
		end,
	})
	return class
end

local function createProxy(source, onchanged)
	return setmetatable({}, {
		__index = function(_, key)
			return source[key]
		end,
		__newindex = function(_, key, value)
			local previous = source[key]
			if value == previous then return end
			source[key] = value
			if onchanged then onchanged(key, value) end
		end,
	})
end

local function resolveLength(length)
	if type(length) == "number" then
		return length, "pixel"
	elseif length == "auto" then
		return 0, "auto"
	elseif length == "fit-content" then
		return 0, "fit-content"
	elseif type(length) == "string" then
		local _value, unit = string.match(length, "^(-?%d*%.?%d+)([%%%a]*)$")
		local value = tonumber(_value)
		if not value then
			return 0, "auto"
		elseif not unit or unit == "" then
			return value, "pixel"
		elseif unit == "px" then
			return value, "pixel"
		elseif unit == "%" then
			return value * 0.01, "percentage"
		elseif unit == "sw" then
			return value * 0.01 * screenWidth, "pixel"
		elseif unit == "sh" then
			return value * 0.01 * screenHeight, "pixel"
		elseif unit == "sc" then
			return value * screenScale, "pixel"
		end
	else
		return 0, "auto"
	end
end

local function getColorAlpha(color)
	return math.floor(color / 0x1000000) % 0x100
end

local function hex(hex)
	hex = hex:gsub("#", "")
	local r, g, b, a
	if #hex == 3 then
		r = tonumber(hex:sub(1, 1):rep(2), 16)
		g = tonumber(hex:sub(2, 2):rep(2), 16)
		b = tonumber(hex:sub(3, 3):rep(2), 16)
		a = 255
	elseif #hex == 4 then
		r = tonumber(hex:sub(1, 1):rep(2), 16)
		g = tonumber(hex:sub(2, 2):rep(2), 16)
		b = tonumber(hex:sub(3, 3):rep(2), 16)
		a = tonumber(hex:sub(4, 4):rep(2), 16)
	elseif #hex == 6 then
		r = tonumber(hex:sub(1, 2), 16)
		g = tonumber(hex:sub(3, 4), 16)
		b = tonumber(hex:sub(5, 6), 16)
		a = 255
	elseif #hex == 8 then
		r = tonumber(hex:sub(1, 2), 16)
		g = tonumber(hex:sub(3, 4), 16)
		b = tonumber(hex:sub(5, 6), 16)
		a = tonumber(hex:sub(7, 8), 16)
	end
	return a * 0x1000000 + r * 0x10000 + g * 0x100 + b
end

local function hue(color)
	local r = math.floor(color / 0x10000) % 0x100
	local g = math.floor(color / 0x100) % 0x100
	local b = color % 0x100
	r, g, b = r / 255, g / 255, b / 255
	local cmax = math.max(r, g, b)
	local cmin = math.min(r, g, b)
	local delta = cmax - cmin
	local h
	if delta == 0 then
		h = 0
	elseif cmax == r then
		h = 60 * (((g - b) / delta) % 6)
	elseif cmax == g then
		h = 60 * (((b - r) / delta) + 2)
	else
		h = 60 * (((r - g) / delta) + 4)
	end
	local l = (cmax + cmin) * 0.5
	local s
	if delta == 0 then
		s = 0
	else
		s = delta / (1 - math.abs(2 * l - 1))
	end
	return h, s, l
end

local function hsl(h, s, l, alpha)
	h = h % 360
	if s == nil or type(s) ~= "number" then s = 1 end
	if l == nil or type(l) ~= "number" then l = 0.5 end
	if alpha == nil or type(alpha) ~= "number" then alpha = 1 end
	local c = (1 - math.abs(2 * l - 1)) * s
	local x = c * (1 - math.abs((h / 60) % 2 - 1))
	local m = l - c * 0.5
	local r, g, b
	if h < 60 then
		r, g, b = c, x, 0
	elseif h < 120 then
		r, g, b = x, c, 0
	elseif h < 180 then
		r, g, b = 0, c, x
	elseif h < 240 then
		r, g, b = 0, x, c
	elseif h < 300 then
		r, g, b = x, 0, c
	else
		r, g, b = c, 0, x
	end
	r = math.floor((r + m) * 255 + 0.5)
	g = math.floor((g + m) * 255 + 0.5)
	b = math.floor((b + m) * 255 + 0.5)
	local a = math.floor(alpha * 255 + 0.5)
	return a * 0x1000000 + r * 0x10000 + g * 0x100 + b
end

local function lighten(color, delta)
	local hue, saturation, lightness = hue(color)
	lightness = math.max(0, math.min(lightness + delta, 1))
	return hsl(hue, saturation, lightness)
end

local materialTypes = {
	shader = true,
	svg = true,
	texture = true,
}

local function isValidMaterial(material)
	if not isElement(material) then return false end
	local type = getElementType(material)
	if not materialTypes[type] then return false end
	return true, type
end


local _dxDrawImage = dxDrawImage
local _dxCreateRenderTarget = dxCreateRenderTarget
local _dxSetRenderTarget = dxSetRenderTarget
local _dxSetBlendMode = dxSetBlendMode
local _dxGetBlendMode = dxGetBlendMode

local dxCreatedRenderTargets = {}
local dxCurrentRenderTarget

local function dxCreateRenderTarget(width, height, alpha)
	local dxRenderTarget = _dxCreateRenderTarget(width, height, alpha or true)
	if dxRenderTarget then
		dxSetTextureEdge(dxRenderTarget, "clamp")
		dxCreatedRenderTargets[dxRenderTarget] = true
	end
	return dxRenderTarget
end

local function dxDestroyRenderTarget(dxRenderTarget)
	if not dxCreatedRenderTargets[dxRenderTarget] then return false end
	dxCreatedRenderTargets[dxRenderTarget] = nil
	if isElement(dxRenderTarget) then destroyElement(dxRenderTarget) end
	return true
end

local function dxSetRenderTarget(dxRenderTarget, clear)
	local success = _dxSetRenderTarget(dxRenderTarget, clear)
	if success then dxCurrentRenderTarget = dxRenderTarget end
	return success
end

local function dxGetRenderTarget()
	return dxCurrentRenderTarget
end

local dxCurrentBlendMode = "blend"

local function dxSetBlendMode(dxBlendMode)
	if dxBlendMode == dxCurrentBlendMode then return false end
	local success = _dxSetBlendMode(dxBlendMode)
	if success then dxCurrentBlendMode = dxBlendMode end
	return success
end

local function dxGetBlendMode()
	return dxCurrentBlendMode
end

local function dxDrawImage(x, y, width, height, material, ...)
	local valid, type = isValidMaterial(material)
	if not valid then return false end
	local dxPreviousBlendMode = dxGetBlendMode()
	if type == "shader" then dxSetBlendMode("blend") end
	_dxDrawImage(x, y, width, height, material, ...)
	dxSetBlendMode(dxPreviousBlendMode)
	return true
end

local IDs = {}

local function setNodeId(node, id)
	if type(id) ~= "string" or #id == 0 then return false end
	IDs[id] = node
	IDs[node] = id
	return true
end

local function getNodeFromId(id)
	local node = IDs[id]
	return node ~= nil and node
end

local attributeAffectsLayout = {
	alignItems = true,
	alignSelf = true,
	bottom = true,
	display = true,
	flexDirection = true,
	flexGrow = true,
	flexShrink = true,
	flexWrap = true,
	font = true,
	gap = true,
	height = true,
	justifyContent = true,
	left = true,
	material = true,
	padding = true,
	paddingBottom = true,
	paddingLeft = true,
	paddingRight = true,
	paddingTop = true,
	position = true,
	right = true,
	text = true,
	textColorCoded = true,
	textSize = true,
	textWordWrap = true,
	top = true,
	visible = true,
	width = true,
}

local attributeAffectsPaint = {

}

local Node = createClass()
Node.__node__ = true

function isNode(node)
	return type(node) == "table" and node.__node__ == true
end

function Node:constructor(attributes, ...)
	self.parent = false
	self.index = false
	self.children = {}
	self.dirty = true
	self.paint = false
	self.states = { hovered = false, clicked = false }
	self.resolved = {
		borderBottomLeftRadius = { value = 0, unit = "auto" },
		borderBottomRightRadius = { value = 0, unit = "auto" },
		borderRadius = { value = 0, unit = "auto" },
		borderTopLeftRadius = { value = 0, unit = "auto" },
		borderTopRightRadius = { value = 0, unit = "auto" },
		bottom = { value = 0, unit = "auto" },
		flexGrow = { value = 0, unit = "pixel" },
		flexShrink = { value = 0, unit = "pixel" },
		gap = { value = 0, unit = "auto" },
		height = { value = 0, unit = "auto" },
		left = { value = 0, unit = "auto" },
		padding = { value = 0, unit = "auto" },
		paddingBottom = { value = 0, unit = "auto" },
		paddingLeft = { value = 0, unit = "auto" },
		paddingRight = { value = 0, unit = "auto" },
		paddingTop = { value = 0, unit = "auto" },
		right = { value = 0, unit = "auto" },
		strokeBottomWeight = { value = 0, unit = "auto" },
		strokeLeftWeight = { value = 0, unit = "auto" },
		strokeRightWeight = { value = 0, unit = "auto" },
		strokeTopWeight = { value = 0, unit = "auto" },
		strokeWeight = { value = 0, unit = "auto" },
		top = { value = 0, unit = "auto" },
		width = { value = 0, unit = "auto" },
	}
	self.__attributes = {
		alignItems = "stretch",
		alignSelf = "auto",
		backgroundColor = 0x00ffffff,
		borderBottomLeftRadius = "auto",
		borderBottomRightRadius = "auto",
		borderRadius = "auto",
		borderTopLeftRadius = "auto",
		borderTopRightRadius = "auto",
		bottom = "auto",
		clickable = true,
		clipContent = false,
		color = false,
		display = "flex",
		flexDirection = "row",
		flexGrow = 0,
		flexShrink = 0,
		flexWrap = "nowrap",
		font = "default",
		gap = "auto",
		height = "auto",
		hoverable = true,
		id = "",
		justifyContent = "flex-start",
		left = "auto",
		material = false,
		padding = "auto",
		paddingBottom = "auto",
		paddingLeft = "auto",
		paddingRight = "auto",
		paddingTop = "auto",
		position = "relative",
		right = "auto",
		strokeBottomWeight = "auto",
		strokeColor = black,
		strokeLeftWeight = "auto",
		strokeRightWeight = "auto",
		strokeTopWeight = "auto",
		strokeWeight = "auto",
		text = "",
		textAlignX = "left",
		textAlignY = "top",
		textClip = false,
		textColorCoded = false,
		textSize = 1,
		textWordWrap = false,
		top = "auto",
		visible = true,
		width = "auto",
	}
	self.attributes = createProxy(self.__attributes, function(key, value)
		local resolvedAttribute = self.resolved[key]
		if resolvedAttribute then resolvedAttribute.value, resolvedAttribute.unit = resolveLength(value) end
		if key == "id" then
			setNodeId(self, value)
		elseif key == "material" then
			local computed = self.computed
			local materialWidth = 0
			local materialHeight = 0
			local attributes = self.__attributes
			local material = attributes.material
			if isValidMaterial(material) then materialWidth, materialHeight = dxGetMaterialSize(material) end
			computed.materialWidth = materialWidth
			computed.materialHeight = materialHeight
		end
		if attributeAffectsLayout[key] then self:markDirty() end
		self:invalidateRenderTarget()
	end)
	self.computed = {
		bottom = 0,
		flexBasis = 0,
		height = 0,
		left = 0,
		materialHeight = 0,
		materialWidth = 0,
		right = 0,
		textHeight = dxGetFontHeight(1, "default"),
		textWidth = 0,
		top = 0,
		width = 0,
		x = 0,
		y = 0,
	}
	self.render = {
		backgroundShader = nil,
		borderBottomLeftRadius = 0,
		borderBottomRightRadius = 0,
		borderTopLeftRadius = 0,
		borderTopRightRadius = 0,
		height = 0,
		target = nil,
		strokeBottomWeight = 0,
		strokeLeftWeight = 0,
		strokeRightWeight = 0,
		strokeShader = nil,
		strokeTopWeight = 0,
		width = 0,
		x = 0,
		y = 0,
	}
	if attributes then
		if type(attributes.onCursorEnter) == "function" then
			self.onCursorEnter = attributes.onCursorEnter
		end
		if type(attributes.onCursorLeave) == "function" then
			self.onCursorLeave = attributes.onCursorLeave
		end
		if type(attributes.onCursorOver) == "function" then
			self.onCursorOver = attributes.onCursorOver
		end
		if type(attributes.onCursorOut) == "function" then
			self.onCursorOut = attributes.onCursorOut
		end
		if type(attributes.onCursorDown) == "function" then
			self.onCursorDown = attributes.onCursorDown
		end
		if type(attributes.onCursorUp) == "function" then
			self.onCursorUp = attributes.onCursorUp
		end
		if type(attributes.onClick) == "function" then
			self.onClick = attributes.onClick
		end
		for key, value in pairs(attributes) do
			if key == "debug" or self.__attributes[key] ~= nil then self.attributes[key] = value end
		end
	end
	local childCount = select("#", ...)
	for i = 1, childCount do self:appendChild(select(i, ...)) end
end

function Node:destructor()
	local children = self.children
	local childCount = #children
	for i = childCount, 1, -1 do children[i]:destroy() end
	if self.parent then self.parent:removeChild(self) end
end

function Node:setParent(parent)
	if parent ~= false and not isNode(parent) then return false end
	if parent then
		parent:appendChild(self)
	elseif self.parent then
		self.parent:removeChild(self)
	end
	return true
end

function Node:appendChild(child)
	if not isNode(child) then return false end
	if child.parent == self then return false end
	if child.parent then child.parent:removeChild(child) end
	table.insert(self.children, child)
	child.parent = self
	child.index = #self.children
	child.dirty = true
	child.paint = true
	self:markDirty()
	self:invalidateRenderTarget()
	return true
end

function Node:removeChild(child)
	if not isNode(child) then return false end
	if child.parent ~= self then return false end
	table.remove(self.children, child.index)
	self:reindexChildren(child.index)
	child.parent = false
	child.index = false
	self:markDirty()
	self:invalidateRenderTarget()
	return true
end

function Node:reindexChildren(startAt)
	if startAt ~= nil and type(startAt) ~= "number" then startAt = 1 end
	local children = self.children
	local childCount = #children
	for i = startAt, childCount do children[i].index = i end
end

function Node:markDirty()
	if not self.dirty then self.dirty = true end
	local parent = self.parent
	if parent and not parent.dirty then parent:markDirty() end
end

function Node:invalidateRenderTarget()
	if not self.paint then self.paint = true end
	local parent = self.parent
	if parent and not parent.paint then parent:invalidateRenderTarget() end
end

Text = createClass(Node)
Text.__text__ = true

function Text:measure()
	local computed = self.computed
	local computedWidth = computed.width
	local attributes = self.__attributes
	local text = attributes.text
	local textSize = attributes.textSize
	local textWordWrap = attributes.textWordWrap
	local textColorCoded = attributes.textColorCoded
	local font = attributes.font
	local fontHeight = dxGetFontHeight(textSize, font)
	local textWidth, textHeight = dxGetTextSize(text, computedWidth, textSize, font, textWordWrap, textColorCoded)
	textHeight = math.max(textHeight, fontHeight)
	computed.textWidth = textWidth
	computed.textHeight = textHeight
	return textWidth, textHeight
end

function Text:draw(x, y, width, height, color)
	local attributes = self.attributes
	local text = attributes.text
	if text ~= "" then dxDrawText(text, x, y, x + width, y + height, color, attributes.textSize, attributes.font, attributes.textAlignX, attributes.textAlignY, attributes.textClip, attributes.textWordWrap, false, attributes.textColorCoded) end
end

Image = createClass(Node)
Image.__image__ = true

function Image:measure()
	local computed = self.computed
	return computed.materialWidth, computed.materialHeight
end

function Image:draw(x, y, width, height, color)
	local attributes = self.attributes
	local material = attributes.material
	if isValidMaterial(material) then
		local render = self.render
		local shader = render.imageShader
		dxDrawImage(x, y, width, height, isValidMaterial(shader) and shader or material, 0, 0, 0, color)
	end
end

Button = createClass(Node)
Button.__button__ = true

function Button:constructor(attributes, ...)
	if attributes.hoverable ~= nil then attributes.hoverable = false end
	local childCount = select("#", ...)
	for i = 1, childCount do
		local child = select(i, ...)
		child.__attributes.hoverable = false
	end
	Node.constructor(self, attributes, ...)
end

local splitChildrenIntoLines
local calculateLayout

function splitChildrenIntoLines(node, isMainAxisRow, mainAxisDimension, mainAxisPosition, crossAxisDimension, crossAxisPosition, containerMainSize, containerCrossSize, containerMainInnerSize, containerCrossInnerSize, paddingMainStart, paddingCrossStart, gapMain, gapCross, flexCanWrap, stretchChildren, children, childCount, doingSecondPass, doingThirdPass)
	local lines = {{[mainAxisDimension] = 0, [mainAxisPosition] = paddingMainStart, [crossAxisDimension] = 0, [crossAxisPosition] = paddingCrossStart, remainingFreeSpace = 0, totalFlexGrowFactor = 0, totalFlexShrinkScaledFactor = 0,},}
	local currentLine = lines[1]
	local linesMainMaximumLineSize = 0
	local linesCrossTotalLinesSize = 0
	local secondPassChildren
	local thirdPassChildren
	local absoluteChildren
	for i = 1, childCount do
		local child = children[i]
		local childAttributes = child.__attributes
		local childPosition = childAttributes.position
		if childAttributes.visible then
			local childResolved = child.resolved
			if not doingSecondPass then
				if childPosition == "absolute" then
					local availableWidth = isMainAxisRow and containerMainSize ~= nil and containerMainSize or not isMainAxisRow and containerCrossSize ~= nil and containerCrossSize or nil
					local availableHeight = isMainAxisRow and containerCrossSize ~= nil and containerCrossSize or not isMainAxisRow and containerMainSize ~= nil and containerMainSize or nil
					calculateLayout(child, availableWidth, availableHeight, nil, nil, isMainAxisRow, stretchChildren)
				elseif childPosition == "relative" then
					local availableWidth = isMainAxisRow and containerMainSize ~= nil and containerMainInnerSize or not isMainAxisRow and containerCrossSize ~= nil and containerCrossInnerSize or nil
					local availableHeight = isMainAxisRow and containerCrossSize ~= nil and containerCrossInnerSize or not isMainAxisRow and containerMainSize ~= nil and containerMainInnerSize or nil
					calculateLayout(child, availableWidth, availableHeight, nil, nil, isMainAxisRow, stretchChildren)
				end
				local childResolvedMainSize = childResolved[mainAxisDimension]
				local childResolvedCrossSize = childResolved[crossAxisDimension]
				local childAlignSelf = childAttributes.alignSelf
				if childResolvedMainSize.unit == "percentage" and containerMainSize == nil or (childResolvedCrossSize.unit == "auto" and stretchChildren and (childAlignSelf == "auto" or childAlignSelf == "stretch") and childPosition == "relative") or childResolvedCrossSize.unit == "percentage" and containerCrossSize == nil then
					if not secondPassChildren then secondPassChildren = {} end
					table.insert(secondPassChildren, child)
				end
				if childPosition == "absolute" then
					if not absoluteChildren then absoluteChildren = {} end
					table.insert(absoluteChildren, child)
				end
			end
			if childPosition == "relative" then
				local childComputed = child.computed
				local childComputedMainSize = not doingThirdPass and childComputed.flexBasis or childComputed[mainAxisDimension]
				local childComputedCrossSize = childComputed[crossAxisDimension]
				if flexCanWrap and #currentLine > 1 and currentLine[mainAxisDimension] + gapMain + childComputedMainSize > containerMainInnerSize then
					local previousLine = currentLine
					currentLine = {[mainAxisDimension] = 0, [mainAxisPosition] = paddingMainStart, [crossAxisDimension] = 0, [crossAxisPosition] = gapCross + previousLine[crossAxisPosition] + previousLine[crossAxisDimension], remainingFreeSpace = 0, totalFlexGrowFactor = 0, totalFlexShrinkScaledFactor = 0,}
					table.insert(lines, currentLine)
				end
				table.insert(currentLine, child)
				currentLine[mainAxisDimension] = currentLine[mainAxisDimension] + (#currentLine > 0 and i < childCount and gapMain or 0) + childComputedMainSize
				currentLine[crossAxisDimension] = math.max(currentLine[crossAxisDimension], childComputedCrossSize)
				if containerMainSize ~= nil then currentLine.remainingFreeSpace = containerMainInnerSize - currentLine[mainAxisDimension] end
				linesMainMaximumLineSize = math.max(linesMainMaximumLineSize, currentLine[mainAxisPosition] + currentLine[mainAxisDimension])
				linesCrossTotalLinesSize = math.max(linesCrossTotalLinesSize, currentLine[crossAxisPosition] + currentLine[crossAxisDimension])
				local childFlexGrow = childResolved.flexGrow.value
				local childFlexShrink = childResolved.flexShrink.value
				if childFlexGrow > 0 or childFlexShrink > 0 then
					currentLine.totalFlexGrowFactor = currentLine.totalFlexGrowFactor + childFlexGrow
					currentLine.totalFlexShrinkScaledFactor = currentLine.totalFlexShrinkScaledFactor + childFlexShrink * childComputedMainSize
					if not thirdPassChildren then thirdPassChildren = {} end
					table.insert(thirdPassChildren, child)
					thirdPassChildren[child] = currentLine
				end
			end
		end
	end

	return lines, linesMainMaximumLineSize - paddingMainStart, linesCrossTotalLinesSize - paddingCrossStart, secondPassChildren, thirdPassChildren, absoluteChildren
end

function calculateLayout(node, availableWidth, availableHeight, forcedWidth, forcedHeight, pIsMainAxisRow, pStretchChildren)
	if not node.dirty then return false end
	node.dirty = false
	local resolved = node.resolved
	local resolvedWidth = resolved.width
	local resolvedHeight = resolved.height
	local computed = node.computed
	local computedWidth
	local computedHeight
	local attributes = node.__attributes
	local alignSelf = attributes.alignSelf
	if forcedWidth then
		computedWidth = forcedWidth
	elseif resolvedWidth.unit == "pixel" then
		computedWidth = resolvedWidth.value
	elseif resolvedWidth.unit == "percentage" and availableWidth then
		computedWidth = resolvedWidth.value * availableWidth
	elseif resolvedWidth.unit == "auto" and not pIsMainAxisRow and pStretchChildren and (alignSelf == "auto" or alignSelf == "stretch") and availableWidth then
		computedWidth = availableWidth
	end
	if forcedHeight then
		computedHeight = forcedHeight
	elseif resolvedHeight.unit == "pixel" then
		computedHeight = resolvedHeight.value
	elseif resolvedHeight.unit == "percentage" and availableHeight then
		computedHeight = resolvedHeight.value * availableHeight
	elseif resolvedHeight.unit == "auto" and pIsMainAxisRow and pStretchChildren and (alignSelf == "auto" or alignSelf == "stretch") and availableHeight then
		computedHeight = availableHeight
	end
	local resolvedLeft = resolved.left
	local resolvedTop = resolved.top
	local resolvedRight = resolved.right
	local resolvedBottom = resolved.bottom
	if resolvedLeft.unit == "pixel" then
		computed.left = resolvedLeft.value
	elseif resolvedLeft.unit == "percentage" and availableWidth then
		computed.left = resolvedLeft.value * availableWidth
	else
		computed.left = 0
	end
	if resolvedTop.unit == "pixel" then
		computed.top = resolvedTop.value
	elseif resolvedTop.unit == "percentage" and availableHeight then
		computed.top = resolvedTop.value * availableHeight
	else
		computed.top = 0
	end
	if resolvedRight.unit == "pixel" then
		computed.right = resolvedRight.value
	elseif resolvedRight.unit == "percentage" and availableWidth then
		computed.right = resolvedRight.value * availableWidth
	else
		computed.right = 0
	end
	if resolvedBottom.unit == "pixel" then
		computed.bottom = resolvedBottom.value
	elseif resolvedBottom.unit == "percentage" and availableHeight then
		computed.bottom = resolvedBottom.value * availableHeight
	else
		computed.bottom = 0
	end
	local flexDirection = attributes.flexDirection
	local isMainAxisRow = flexDirection == "row" or flexDirection == "row-reverse"
	local mainAxisDimension = isMainAxisRow and "width" or "height"
	local mainAxisPosition = isMainAxisRow and "x" or "y"
	local crossAxisDimension = isMainAxisRow and "height" or "width"
	local crossAxisPosition = isMainAxisRow and "y" or "x"
	local resolvedPadding = resolved.padding
	local resolvedPaddingLeft = resolved.paddingLeft
	local resolvedPaddingTop = resolved.paddingTop
	local resolvedPaddingRight = resolved.paddingRight
	local resolvedPaddingBottom = resolved.paddingBottom
	local computedPaddingLeft = 0
	local computedPaddingTop = 0
	local computedPaddingRight = 0
	local computedPaddingBottom = 0
	if resolvedPadding.unit == "pixel" then
		local computedPadding = resolvedPadding.value
		computedPaddingLeft = computedPadding
		computedPaddingTop = computedPadding
		computedPaddingRight = computedPadding
		computedPaddingBottom = computedPadding
	end
	if resolvedPaddingLeft.unit == "pixel" then computedPaddingLeft = resolvedPaddingLeft.value end
	if resolvedPaddingTop.unit == "pixel" then computedPaddingTop = resolvedPaddingTop.value end
	if resolvedPaddingRight.unit == "pixel" then computedPaddingRight = resolvedPaddingRight.value end
	if resolvedPaddingBottom.unit == "pixel" then computedPaddingBottom = resolvedPaddingBottom.value end
	local paddingMainStart = isMainAxisRow and computedPaddingLeft or computedPaddingTop
	local paddingMainEnd = isMainAxisRow and computedPaddingRight or computedPaddingBottom
	local paddingCrossStart = isMainAxisRow and computedPaddingTop or computedPaddingLeft
	local paddingCrossEnd = isMainAxisRow and computedPaddingBottom or computedPaddingRight
	local containerMainSize = isMainAxisRow and computedWidth or not isMainAxisRow and computedHeight or nil
	local containerMainInnerSize = math.max((containerMainSize or 0) - paddingMainStart - paddingMainEnd, 0)
	local containerCrossSize = isMainAxisRow and computedHeight or not isMainAxisRow and computedWidth or nil
	local containerCrossInnerSize = math.max((containerCrossSize or 0) - paddingCrossStart - paddingCrossEnd, 0)
	local flexWrap = attributes.flexWrap
	local flexCanWrap = flexWrap ~= "nowrap" and containerMainSize ~= nil
	local justifyContent = attributes.justifyContent
	local alignItems = attributes.alignItems
	local stretchChildren = alignItems == "stretch"
	local resolvedGap = resolved.gap
	local computedGap = resolvedGap.value
	local gapMain = computedGap
	local gapCross = computedGap
	local children = node.children
	local childCount = children and #children or 0
	if childCount > 0 then
		local lines, linesMainMaximumLineSize, linesCrossTotalLinesSize, secondPassChildren, thirdPassChildren, absoluteChildren = splitChildrenIntoLines(node, isMainAxisRow, mainAxisDimension, mainAxisPosition, crossAxisDimension, crossAxisPosition, containerMainSize, containerCrossSize, containerMainInnerSize, containerCrossInnerSize, paddingMainStart, paddingCrossStart, gapMain, gapCross, flexCanWrap, stretchChildren, children, childCount, false, false)
		local resolvedMainSize = isMainAxisRow and resolvedWidth or resolvedHeight
		local resolvedCrossSize = isMainAxisRow and resolvedHeight or resolvedWidth
		local forcedMainSize = isMainAxisRow and forcedWidth or forcedHeight
		local forcedCrossSize = isMainAxisRow and forcedHeight or forcedWidth
		if forcedMainSize == nil and containerMainSize == nil and (resolvedMainSize.unit == "auto" or resolvedMainSize.unit == "fit-content") then
			computedWidth = isMainAxisRow and (linesMainMaximumLineSize + paddingMainStart + paddingMainEnd) or computedWidth
			computedHeight = not isMainAxisRow and (linesMainMaximumLineSize + paddingMainStart + paddingMainEnd) or computedHeight
			containerMainSize = isMainAxisRow and computedWidth or computedHeight
			containerMainInnerSize = math.max(containerMainSize - paddingMainStart - paddingMainEnd, 0)
		end
		local containerCrossSizeFitToContent = false
		if forcedCrossSize == nil and containerCrossSize == nil and resolvedCrossSize.unit == "auto" or resolvedCrossSize.unit == "fit-content" then
			computedWidth = not isMainAxisRow and (linesCrossTotalLinesSize + paddingCrossStart + paddingCrossEnd) or computedWidth
			computedHeight = isMainAxisRow and (linesCrossTotalLinesSize + paddingCrossStart + paddingCrossEnd) or computedHeight
			containerCrossSize = isMainAxisRow and computedHeight or computedWidth
			containerCrossInnerSize = math.max(containerCrossSize - paddingCrossStart - paddingCrossEnd, 0)
			containerCrossSizeFitToContent = true
		end
		if forcedWidth == nil and not pIsMainAxisRow and pStretchChildren and resolvedWidth.unit == "auto" and (alignSelf == "auto" or alignSelf == "stretch") and availableWidth then
			computedWidth = math.max(computedWidth, availableWidth)
		elseif forcedHeight == nil and pIsMainAxisRow and pStretchChildren and resolvedHeight.unit == "auto" and (alignSelf == "auto" or alignSelf == "stretch") and availableHeight then
			computedHeight = math.max(computedHeight, availableHeight)
		end
		if secondPassChildren then
			for i = 1, #secondPassChildren do
				local child = secondPassChildren[i]
				child.dirty = true
				local availableWidth = isMainAxisRow and containerMainSize ~= nil and containerMainInnerSize or not isMainAxisRow and containerCrossSize ~= nil and containerCrossInnerSize
				local availableHeight = isMainAxisRow and containerCrossSize ~= nil and containerCrossInnerSize or not isMainAxisRow and containerMainSize ~= nil and containerMainInnerSize
				calculateLayout(child, availableWidth, availableHeight, nil, nil, isMainAxisRow, stretchChildren)
			end
			lines, _, linesCrossTotalLinesSize, _, thirdPassChildren = splitChildrenIntoLines(node, isMainAxisRow, mainAxisDimension, mainAxisPosition, crossAxisDimension, crossAxisPosition, containerMainSize, containerCrossSize, containerMainInnerSize, containerCrossInnerSize, paddingMainStart, paddingCrossStart, gapMain, gapCross, flexCanWrap, stretchChildren, children, childCount, true, false)
			if forcedCrossSize == nil and containerCrossSizeFitToContent and resolvedCrossSize.unit == "auto" or resolvedCrossSize.unit == "fit-content" then
				computedWidth = not isMainAxisRow and (linesCrossTotalLinesSize + paddingCrossStart + paddingCrossEnd) or computedWidth
				computedHeight = isMainAxisRow and (linesCrossTotalLinesSize + paddingCrossStart + paddingCrossEnd) or computedHeight
				containerCrossSize = isMainAxisRow and computedHeight or computedWidth
				containerCrossInnerSize = math.max(containerCrossSize - paddingCrossStart - paddingCrossEnd, 0)
			end
			if forcedWidth == nil and not pIsMainAxisRow and pStretchChildren and resolvedWidth.unit == "auto" and (alignSelf == "auto" or alignSelf == "stretch") and availableWidth then
				computedWidth = math.max(computedWidth, availableWidth)
			elseif forcedHeight == nil and pIsMainAxisRow and pStretchChildren and resolvedHeight.unit == "auto" and (alignSelf == "auto" or alignSelf == "stretch") and availableHeight then
				computedHeight = math.max(computedHeight, availableHeight)
			end
		end
		if thirdPassChildren then
			for i = 1, #thirdPassChildren do
				local child = thirdPassChildren[i]
				child.dirty = true
				local childResolved = child.resolved
				local childFlexGrow = childResolved.flexGrow.value
				local childFlexShrink = childResolved.flexShrink.value
				local line = thirdPassChildren[child]
				local lineRemainingFreeSpace = line.remainingFreeSpace
				local availableWidth = isMainAxisRow and containerMainSize ~= nil and containerMainInnerSize or not isMainAxisRow and containerCrossSize ~= nil and containerCrossInnerSize
				local availableHeight = isMainAxisRow and containerCrossSize ~= nil and containerCrossInnerSize or not isMainAxisRow and containerMainSize ~= nil and containerMainInnerSize
				local forcedWidth
				local forcedHeight
				if childFlexGrow > 0 and lineRemainingFreeSpace > 0 then
					local childComputed = child.computed
					local childComputedMainSize = childComputed.flexBasis
					local flexGrowAmount = (childFlexGrow / line.totalFlexGrowFactor) * lineRemainingFreeSpace
					forcedWidth = isMainAxisRow and (childComputedMainSize + flexGrowAmount) or nil
					forcedHeight = not isMainAxisRow and (childComputedMainSize + flexGrowAmount) or nil
				elseif childFlexShrink > 0 and lineRemainingFreeSpace < 0 then
					local childComputed = child.computed
					local childComputedMainSize = childComputed.flexBasis
					local flexShrinkAmount = childComputedMainSize * (childFlexShrink / line.totalFlexShrinkScaledFactor) * -lineRemainingFreeSpace
					forcedWidth = isMainAxisRow and math.max(childComputedMainSize - flexShrinkAmount, 0) or nil
					forcedHeight = not isMainAxisRow and math.max(childComputedMainSize - flexShrinkAmount, 0) or nil
				end
				calculateLayout(child, availableWidth, availableHeight, forcedWidth, forcedHeight, isMainAxisRow, stretchChildren)
			end
		end
		local flexLinesAlignItemsOffset = alignItems == "center" and (containerCrossInnerSize - linesCrossTotalLinesSize) * 0.5 or alignItems == "flex-end" and containerCrossInnerSize - linesCrossTotalLinesSize or 0
		for i = 1, #lines do
			local currentLine = lines[i]
			local currentLineChildCount = #currentLine
			local currentLineCrossSize = currentLine[crossAxisDimension]
			local currentLineRemainingFreeSpace = currentLine.remainingFreeSpace
			local currentLineJustifyContentGap = justifyContent == "space-between" and currentLineChildCount > 1 and currentLineRemainingFreeSpace / (currentLineChildCount - 1) or justifyContent == "space-around" and currentLineRemainingFreeSpace / currentLineChildCount or justifyContent == "space-evenly" and currentLineRemainingFreeSpace / (currentLineChildCount + 1) or 0
			local currentLineJustifyContentOffset = justifyContent == "center" and currentLineRemainingFreeSpace * 0.5 or justifyContent == "flex-end" and currentLineRemainingFreeSpace or justifyContent == "space-between" and 0 or justifyContent == "space-around" and currentLineJustifyContentGap * 0.5 or justifyContent == "space-evenly" and currentLineJustifyContentGap or 0
			local caretMainPosition = currentLine[mainAxisPosition] + currentLineJustifyContentOffset
			local caretCrossPosition = currentLine[crossAxisPosition] + flexLinesAlignItemsOffset
			for i = 1, #currentLine do
				local child = currentLine[i]
				local childAttributes = child.__attributes
				local childAlignSelf = childAttributes.alignSelf
				if childAlignSelf == "auto" then childAlignSelf = alignItems end
				local childComputed = child.computed
				local childComputedCrossSize = childComputed[crossAxisDimension]
				local childCrossOffset = childAlignSelf == "center" and (currentLineCrossSize - childComputedCrossSize) * 0.5 or childAlignSelf == "flex-end" and currentLineCrossSize - childComputedCrossSize or 0
				childComputed[mainAxisPosition] = caretMainPosition
				childComputed[crossAxisPosition] = caretCrossPosition + childCrossOffset
				local childResolved = child.resolved
				local resolvedLeft = childResolved.left
				local resolvedTop = childResolved.top
				local resolvedRight = childResolved.right
				local resolvedBottom = childResolved.bottom
				childComputed.x = childComputed.x + ( resolvedLeft.unit ~= "auto" and childComputed.left or resolvedRight.unit ~= "auto" and computedWidth - childComputed.right - childComputed.width or 0)
				childComputed.y = childComputed.y + (resolvedTop.unit ~= "auto" and childComputed.top or resolvedBottom.unit ~= "auto" and computedHeight - childComputed.bottom - childComputed.height or 0)
				childComputed.x = math.floor(childComputed.x + 0.5)
				childComputed.y = math.floor(childComputed.y + 0.5)
				caretMainPosition = caretMainPosition + childComputed[mainAxisDimension] + gapMain + currentLineJustifyContentGap
			end
		end
		if absoluteChildren then
			for i = 1, #absoluteChildren do
				local child = absoluteChildren[i]
				local childResolved = child.resolved
				local resolvedLeft = childResolved.left
				local resolvedTop = childResolved.top
				local resolvedRight = childResolved.right
				local resolvedBottom = childResolved.bottom
				local childComputed = child.computed
				local childComputedWidth = childComputed.width
				local childComputedHeight = childComputed.height
				childComputed.x = resolvedLeft.unit ~= "auto" and childComputed.left or resolvedRight.unit ~= "auto" and computedWidth - childComputed.right - childComputedWidth or 0
				childComputed.y = resolvedTop.unit ~= "auto" and childComputed.top or resolvedBottom.unit ~= "auto" and computedHeight - childComputed.bottom - childComputedHeight or 0
			end
		end
	else
		local measuredWidth
		local measuredHeight
		if node.measure then measuredWidth, measuredHeight = node:measure() end
		if measuredWidth and not computedWidth and (resolvedWidth.unit == "auto" or resolvedWidth.unit == "fit-content") then computedWidth = measuredWidth + computedPaddingLeft + computedPaddingRight end
		if measuredHeight and not computedHeight and (resolvedHeight.unit == "auto" or resolvedHeight.unit == "fit-content") then computedHeight = measuredHeight + computedPaddingTop + computedPaddingBottom end
	end
	computed.width = math.floor((computedWidth or 0) + 0.5)
	computed.height = math.floor((computedHeight or 0) or 0.5)
	if not forcedWidth then computed.flexBasis = pIsMainAxisRow and computed.width or computed.flexBasis end
	if not forcedHeight then computed.flexBasis = not pIsMainAxisRow and computed.height or computed.flexBasis end
	return true
end

local RectangleShaderString = [[
	float4 BORDER_RADIUS;
	float4 STROKE_WEIGHT;
	texture TEXTURE;
	SamplerState TEXTURE_SAMPLER {Texture = TEXTURE;};
	bool USING_TEXTURE;

	float fill(float sdf, float aa, float blur) {
		return smoothstep(0.5 * aa, -0.5 * aa - blur, sdf);
	}

	float stroke(float sdf, float weight, float aa, float blur) {
		return smoothstep((weight + aa) * 0.5, (weight - aa) * 0.5 - blur, abs(sdf));
	}

	float sdRectangle(float2 position, float2 size, float4 borderRadius) {
		borderRadius.xy = (position.x > 0.0) ? borderRadius.yw : borderRadius.xz;
		borderRadius.x = (position.y > 0.0) ? borderRadius.x : borderRadius.y;
		float2 q = abs(position) - size + borderRadius.x;
		return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - borderRadius.x;
	}

	float4 pixel(float2 texcoord: TEXCOORD0, float4 color: COLOR0): COLOR0 {
		float2 originalTexcoord = texcoord;
		texcoord -= 0.5;
		float2 dx = ddx(texcoord);
		float2 dy = ddy(texcoord);
		float2 resolution = float2(length(float2(dx.x, dy.x)), length(float2(dx.y, dy.y)));
		float aspectRatio = resolution.x / resolution.y;
  	float scaleFactor = (aspectRatio <= 1.0) ? resolution.y : resolution.x;
		if (aspectRatio <= 1.0)
			texcoord.x /= aspectRatio;
		else
			texcoord.y *= aspectRatio;
		float4 borderRadius = BORDER_RADIUS * scaleFactor;
		float4 strokeWeight = STROKE_WEIGHT * scaleFactor;
		float2 position = texcoord;
		float2 size = float2(1.0 / ((aspectRatio <= 1.0) ? aspectRatio : 1.0), (aspectRatio <= 1.0) ? 1.0 : aspectRatio) * 0.5 - strokeWeight.x * 0.5;
		float sdf = sdRectangle(position, size, borderRadius);
		float aa = length(fwidth(position));
		float alpha = any(strokeWeight) ? stroke(sdf, strokeWeight.x, aa, 0.0) : fill(sdf, aa, 0.0);
		color.a *= alpha;
		if (USING_TEXTURE) color *= tex2D(TEXTURE_SAMPLER, originalTexcoord);
		return color;
	}

	technique rectangle {
		pass p0 {
			SeparateAlphaBlendEnable = true;
			SrcBlendAlpha = One;
			DestBlendAlpha = InvSrcAlpha;
			PixelShader = compile ps_2_a pixel();
		}
	}
]]

local function renderer(node, pVisualX, pVisualY, pRenderX, pRenderY, pColor)
	local attributes = node.__attributes
	if not attributes.visible then return false end
	local computed = node.computed
	local computedWidth = computed.width
	local computedHeight = computed.height
	local computedX = computed.x
	local computedY = computed.y
	local visualX = pVisualX + computedX
	local visualY = pVisualY + computedY
	local renderX = pRenderX + computedX
	local renderY = pRenderY + computedY
	local resolved = node.resolved
	local resolvedBorderRadius = resolved.borderRadius
	local resolvedBorderTopLeftRadius = resolved.borderTopLeftRadius
	local resolvedBorderTopRightRadius = resolved.borderTopRightRadius
	local resolvedBorderBottomLeftRadius = resolved.borderBottomLeftRadius
	local resolvedBorderBottomRightRadius = resolved.borderBottomRightRadius
	local renderBorderTopLeftRadius = 0
	local renderBorderTopRightRadius = 0
	local renderBorderBottomLeftRadius = 0
	local renderBorderBottomRightRadius = 0
	if resolvedBorderRadius.unit == "pixel" then
		local renderBorderRadius = resolvedBorderRadius.value
		renderBorderTopLeftRadius = renderBorderRadius
		renderBorderTopRightRadius = renderBorderRadius
		renderBorderBottomLeftRadius = renderBorderRadius
		renderBorderBottomRightRadius = renderBorderRadius
	elseif resolvedBorderRadius.unit == "percentage" then
		local renderBorderRadius = resolvedBorderRadius.value * math.min(computedWidth, computedHeight) * 0.5
		renderBorderTopLeftRadius = renderBorderRadius
		renderBorderTopRightRadius = renderBorderRadius
		renderBorderBottomLeftRadius = renderBorderRadius
		renderBorderBottomRightRadius = renderBorderRadius
	end
	if resolvedBorderTopLeftRadius.unit == "pixel" then
		renderBorderTopLeftRadius = resolvedBorderTopLeftRadius.value
	elseif resolvedBorderTopLeftRadius.unit == "percentage" then
		renderBorderTopLeftRadius = resolvedBorderTopLeftRadius.value * math.min(computedWidth, computedHeight) * 0.5
	end
	if resolvedBorderTopRightRadius.unit == "pixel" then
		renderBorderTopRightRadius = resolvedBorderTopRightRadius.value
	elseif resolvedBorderTopRightRadius.unit == "percentage" then
		renderBorderTopRightRadius = resolvedBorderTopRightRadius.value * math.min(computedWidth, computedHeight) * 0.5
	end
	if resolvedBorderBottomLeftRadius.unit == "pixel" then
		renderBorderBottomLeftRadius = resolvedBorderBottomLeftRadius.value
	elseif resolvedBorderBottomLeftRadius.unit == "percentage" then
		renderBorderBottomLeftRadius = resolvedBorderBottomLeftRadius.value * math.min(computedWidth, computedHeight) * 0.5
	end
	if resolvedBorderBottomRightRadius.unit == "pixel" then
		renderBorderBottomRightRadius = resolvedBorderBottomRightRadius.value
	elseif resolvedBorderBottomRightRadius.unit == "percentage" then
		renderBorderBottomRightRadius = resolvedBorderBottomRightRadius.value * math.min(computedWidth, computedHeight) * 0.5
	end
	local resolvedStrokeWeight = resolved.strokeWeight
	local resolvedStrokeLeftWeight = resolved.strokeLeftWeight
	local resolvedStrokeTopWeight = resolved.strokeTopWeight
	local resolvedStrokeRightWeight = resolved.strokeRightWeight
	local resolvedStrokeBottomWeight = resolved.strokeBottomWeight
	local renderStrokeLeftWeight = 0
	local renderStrokeTopWeight = 0
	local renderStrokeRightWeight = 0
	local renderStrokeBottomWeight = 0
	if resolvedStrokeWeight.unit == "pixel" then
		local renderStrokeWeight = resolvedStrokeWeight.value
		renderStrokeLeftWeight = renderStrokeWeight
		renderStrokeTopWeight = renderStrokeWeight
		renderStrokeRightWeight = renderStrokeWeight
		renderStrokeBottomWeight = renderStrokeWeight
	end
	if resolvedStrokeLeftWeight.unit == "pixel" then renderStrokeLeftWeight = resolvedStrokeLeftWeight.value end
	if resolvedStrokeTopWeight.unit == "pixel" then renderStrokeTopWeight = resolvedStrokeTopWeight.value end
	if resolvedStrokeRightWeight.unit == "pixel" then renderStrokeRightWeight = resolvedStrokeRightWeight.value end
	if resolvedStrokeBottomWeight.unit == "pixel" then renderStrokeBottomWeight = resolvedStrokeBottomWeight.value end
	local usingRectangleShader = renderBorderTopLeftRadius > 0 or renderBorderTopRightRadius > 0 or renderBorderBottomLeftRadius > 0 or renderBorderBottomRightRadius > 0
	local attributes = node.__attributes
	local backgroundColor = attributes.backgroundColor
	local strokeColor = attributes.strokeColor
	local color = attributes.color
	if not color then color = pColor end
	local render = node.render
	render.width = computedWidth
	render.height = computedHeight
	render.x = renderX
	render.y = renderY
	local renderTarget = render.target
	local hasRenderTarget = isValidMaterial(renderTarget)
	if attributes.clipContent then
		if renderTarget == nil then
			renderTarget = dxCreateRenderTarget(computedWidth, computedHeight, true)
			hasRenderTarget = renderTarget ~= false
			render.target = renderTarget
			node.paint = true
		end
		if hasRenderTarget then
			local renderTargetWidth, renderTargetHeight = dxGetMaterialSize(renderTarget)
			if renderTargetWidth ~= computedWidth or renderTargetHeight ~= computedHeight then
				dxDestroyRenderTarget(renderTarget)
				renderTarget = dxCreateRenderTarget(computedWidth, computedHeight, true)
				render.target = renderTarget
				node.paint = true
			end
		end
	elseif renderTarget ~= nil then
		if hasRenderTarget then
			dxDestroyRenderTarget(renderTarget)
		end
		renderTarget = nil
		render.target = renderTarget
	end
	local renderBackgroundShader = render.backgroundShader
	local hasBackground = getColorAlpha(backgroundColor) > 0
	local renderStrokeShader = render.strokeShader
	local hasStroke = getColorAlpha(strokeColor) > 0 and (renderStrokeLeftWeight > 0 or renderStrokeTopWeight > 0 or renderStrokeRightWeight > 0 or renderStrokeBottomWeight > 0)
	local renderImageShader = false
	local hasMaterial = false
	if node.__image__ then
		renderImageShader = render.imageShader
		local material = attributes.material
		hasMaterial = isValidMaterial(material) and material
	end
	if usingRectangleShader then
		if hasBackground then
			if renderBackgroundShader == nil then
				renderBackgroundShader = dxCreateShader(RectangleShaderString)
				render.backgroundShader = renderBackgroundShader
			end
		end
		if hasStroke then
			if renderStrokeShader == nil then
				renderStrokeShader = dxCreateShader(RectangleShaderString)
				render.strokeShader = renderStrokeShader
			end
		end
		if hasMaterial then
			if renderImageShader == nil then
				renderImageShader = dxCreateShader(RectangleShaderString)
				render.imageShader = renderImageShader
				if renderImageShader then
					dxSetShaderValue(renderImageShader, "TEXTURE", hasMaterial)
					dxSetShaderValue(renderImageShader, "USING_TEXTURE", true)
				end
			end
		end
		local previousBorderTopLeftRadius = render.borderTopLeftRadius
		local previousBorderTopRightRadius = render.borderTopRightRadius
		local previousBorderBottomLeftRadius = render.borderBottomLeftRadius
		local previousBorderBottomRightRadius = render.borderBottomRightRadius
		if renderBorderTopLeftRadius ~= previousBorderTopLeftRadius or renderBorderTopRightRadius ~= previousBorderTopRightRadius or renderBorderBottomLeftRadius ~= previousBorderBottomLeftRadius or renderBorderBottomRightRadius ~= previousBorderBottomRightRadius then
			render.borderTopLeftRadius = renderBorderTopLeftRadius
			render.borderTopRightRadius = renderBorderTopRightRadius
			render.borderBottomLeftRadius = renderBorderBottomLeftRadius
			render.borderBottomRightRadius = renderBorderBottomRightRadius
			if isValidMaterial(renderBackgroundShader) then dxSetShaderValue(renderBackgroundShader, "BORDER_RADIUS", renderBorderTopLeftRadius, renderBorderTopRightRadius, renderBorderBottomLeftRadius, renderBorderBottomRightRadius) end
			if isValidMaterial(renderStrokeShader) then dxSetShaderValue(renderStrokeShader, "BORDER_RADIUS", renderBorderTopLeftRadius, renderBorderTopRightRadius, renderBorderBottomLeftRadius, renderBorderBottomRightRadius) end
			if isValidMaterial(renderImageShader) then dxSetShaderValue(renderImageShader, "BORDER_RADIUS", renderBorderTopLeftRadius, renderBorderTopRightRadius, renderBorderBottomLeftRadius, renderBorderBottomRightRadius) end
		end
		local previousStrokeLeftWeight = render.strokeLeftWeight
		local previousStrokeTopWeight = render.strokeTopWeight
		local previousStrokeRightWeight = render.strokeRightWeight
		local previousStrokeBottomWeight = render.strokeBottomWeight
		if renderStrokeLeftWeight ~= previousStrokeLeftWeight or renderStrokeTopWeight ~= previousStrokeTopWeight or renderStrokeRightWeight ~= previousStrokeRightWeight or renderStrokeBottomWeight ~= previousStrokeBottomWeight then
			render.strokeLeftWeight = renderStrokeLeftWeight
			render.strokeTopWeight = renderStrokeTopWeight
			render.strokeRightWeight = renderStrokeRightWeight
			render.strokeBottomWeight = renderStrokeBottomWeight
			if isValidMaterial(renderStrokeShader) then dxSetShaderValue(renderStrokeShader, "STROKE_WEIGHT", renderStrokeLeftWeight, renderStrokeTopWeight, renderStrokeRightWeight, renderStrokeBottomWeight) end
		end
	else
		if renderBackgroundShader ~= nil then
			if isValidMaterial(renderBackgroundShader) then destroyElement(renderBackgroundShader) end
			renderBackgroundShader = nil
			render.backgroundShader = renderBackgroundShader
		end
		if renderStrokeShader ~= nil then
			if isValidMaterial(renderStrokeShader) then destroyElement(renderStrokeShader) end
			renderStrokeShader = nil
			render.strokeShader = renderStrokeShader
		end
		if renderImageShader ~= nil then
			if isValidMaterial(renderImageShader) then destroyElement(renderImageShader) end
			renderImageShader = nil
			render.imageShader = renderImageShader
		end
	end
	if hasBackground then
		if isValidMaterial(renderBackgroundShader) then
			dxDrawImage(visualX, visualY, computedWidth, computedHeight, renderBackgroundShader, 0, 0, 0, backgroundColor)
		else
			dxDrawRectangle(visualX, visualY, computedWidth, computedHeight, backgroundColor)
		end
	end
	if hasRenderTarget then
		if node.paint then
			node.paint = false
			local previousRenderTarget = dxGetRenderTarget()
			dxSetRenderTarget(renderTarget, true)
			local previousBlendMode = dxGetBlendMode()
			local changedBlendMode = dxSetBlendMode("modulate_add")
			if node.draw and getColorAlpha(color) > 0 then node:draw(0, 0, computedWidth, computedHeight, color) end
			local children = node.children
			local childCount = children and #children or 0
			for i = 1, childCount do
				renderer(children[i], 0, 0, renderX, renderY, color)
			end
			if changedBlendMode then dxSetBlendMode(previousBlendMode) end
			dxSetRenderTarget(previousRenderTarget)
		end
		dxDrawImage(visualX, visualY, computedWidth, computedHeight, renderTarget)
	end
	if hasStroke then
		if isValidMaterial(renderStrokeShader) then
			dxDrawImage(visualX, visualY, computedWidth, computedHeight, renderStrokeShader, 0, 0, 0, strokeColor)
		else
			dxDrawRectangle(visualX, visualY, renderStrokeLeftWeight, computedHeight, strokeColor)
			dxDrawRectangle(visualX, visualY, computedWidth, renderStrokeTopWeight, strokeColor)
			dxDrawRectangle(visualX + computedWidth - renderStrokeRightWeight, visualY, renderStrokeRightWeight, computedHeight, strokeColor)
			dxDrawRectangle(visualX, visualY + computedHeight - renderStrokeBottomWeight, computedWidth, renderStrokeBottomWeight, strokeColor)
		end
	end
	if not isValidMaterial(renderTarget) then
		if node.draw and getColorAlpha(color) > 0 then node:draw(visualX, visualY, computedWidth, computedHeight, color) end
		local children = node.children
		local childCount = children and #children or 0
		for i = 1, childCount do renderer(children[i], visualX, visualY, renderX, renderY, color) end
	end
	return true
end

local tree = Node()

local function getHoveredNode(cursorX, cursorY, node)
	local attributes = node.__attributes
	if not attributes.visible then return nil end
	local topmost
	local render = node.render
	local renderWidth = render.width
	local renderHeight = render.height
	local renderX = render.x
	local renderY = render.y
	local hovering = attributes.hoverable and cursorX >= renderX and cursorY >= renderY and cursorX <= renderX + renderWidth and cursorY <= renderY + renderHeight
	local renderTarget = render.target
	local hasRenderTarget = isValidMaterial(renderTarget)
	if hasRenderTarget and not hovering then return nil end
	local states = node.states
	if hovering and not states.hovered then
		states.hovered = true
		if node.onCursorEnter then node:onCursorEnter(cursorX, cursorY) end
	elseif not hovering and states.hovered then
		states.hovered = false
		if node.onCursorLeave then node:onCursorLeave(cursorX, cursorY) end
	end
	local children = node.children
	local childCount = #children
	for i = 1, childCount do
		local child = children[i]
		local childRender = child.render
		local childRenderWidth = childRender.width
		local childRenderHeight = childRender.height
		local childRenderX = childRender.x
		local childRenderY = childRender.y
		if childRenderX + childRenderWidth > 0 and childRenderY + childRenderHeight > 0 and childRenderX < screenWidth and childRenderY < screenHeight or hasRenderTarget and childRenderX + childRenderWidth > renderX and childRenderY + childRenderHeight > renderY and childRenderX < renderWidth and childRenderY < renderHeight then
			local childAttributes = child.__attributes
			if childAttributes.visible then
				local hoveredChild = getHoveredNode(cursorX, cursorY, child)
				if hoveredChild then topmost = hoveredChild end
			end
		end
	end
	if hovering and not topmost then topmost = node end
	return topmost
end

local cursorHoveredNode

local cursorX = -screenWidth
local cursorY = -screenHeight

local cursorButton = {
	left = { pressed = false, clickedNode = false },
	middle = { pressed = false, clickedNode = false },
	right = { pressed = false, clickedNode = false },
}

local function cursor()
	local cursorShowing = isCursorShowing()
	if cursorShowing then
		cursorX, cursorY = getCursorPosition()
		cursorX = cursorX * screenWidth
		cursorY = cursorY * screenHeight
		local hoveredNode = getHoveredNode(cursorX, cursorY, tree)
		if hoveredNode ~= cursorHoveredNode then
			if cursorHoveredNode and cursorHoveredNode.onCursorOut then cursorHoveredNode:onCursorOut(cursorX, cursorY) end
			cursorHoveredNode = hoveredNode
			if cursorHoveredNode and cursorHoveredNode.onCursorOver then cursorHoveredNode:onCursorOver(cursorX, cursorY) end
		end
	else
		cursorX = -screenWidth
		cursorY = -screenHeight
	end
end

addEventHandler("onClientRender", root, function()
	cursor(tree)
end)

addEventHandler("onClientClick", root, function(button, state)
	local data = cursorButton[button]
	data.x = cursorX
	data.y = cursorY
	local pressed = state == "down"
	data.pressed = pressed
	if pressed then
		if cursorHoveredNode then
			cursorHoveredNode.states.clicked = true
			data.clickedNode = cursorHoveredNode
			if cursorHoveredNode.onCursorDown then cursorHoveredNode:onCursorDown(button, pressed, cursorX, cursorY) end
		end
	else
		local cursorClickedNode = data.clickedNode
		if cursorClickedNode then
			cursorClickedNode.states.clicked = false
			if cursorClickedNode.onCursorUp then cursorClickedNode:onCursorUp(button, pressed, cursorX, cursorY) end
			if cursorClickedNode == cursorHoveredNode and cursorClickedNode.onClick then cursorClickedNode:onClick(button, cursorX, cursorY) end
			data.clickedNode = false
		end
	end
end)

addEventHandler("onClientRender", root, function()
	calculateLayout(tree, screenWidth, nil, nil, nil, false, true)
end)

addEventHandler("onClientRender", root, function()
	renderer(tree, 0, 0, 0, 0, white)
end)

Layta = {
	Button = Button,
	hex = hex,
	hsl = hsl,
	hue = hue,
	Image = Image,
	lighten = lighten,
	Node = Node,
	Text = Text,
	tree = tree,
}
