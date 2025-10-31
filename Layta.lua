--
-- Localize globals (micro optimization)
--

local table_insert = table.insert
local table_remove = table.remove

local math_floor = math.floor
local math_min = math.min
local math_max = math.max

local utf8_len = utf8.len
local utf8_sub = utf8.sub

local isElement = isElement
local destroyElement = destroyElement
local getElementType = getElementType

--
-- Enums
--

local Position = {
	Relative = "relative",
	Absolute = "absolute",
}

local FlexDirection = {
	Row = "row",
	Column = "column",
}

local FlexWrap = {
	NoWrap = "nowrap",
	Wrap = "wrap",
}

local JustifyContent = {
	FlexStart = "flex-start",
	FlexEnd = "flex-end",
	Center = "center",
	SpaceBetween = "space-between",
	SpaceEvenly = "space-evenly",
	SpaceAround = "space-around",
}

local AlignItems = {
	FlexStart = "flex-start",
	FlexEnd = "flex-end",
	Center = "center",
	Stretch = "stretch",
}

local AlignSelf = {
	Auto = "auto",
	FlexStart = "flex-start",
	FlexEnd = "flex-end",
	Center = "center",
	Stretch = "stretch",
}

local Overflow = {
	None = "none",
	Hidden = "hidden",
	Auto = "auto",
	Scroll = "scroll",
}

local Unit = {
	Auto = "auto",
	FitContent = "fit-content",
	Pixel = "pixel",
	Percentage = "percentage",
	Stretch = "stretch",
}

local MaterialType = {
	Shader = "shader",
	Svg = "svg",
	Texture = "texture",
}

local BlendMode = {
	Blend = "blend",
	Add = "add",
	ModulateAdd = "modulateAdd",
	Overwrite = "overwrite",
}

--
-- Utilities
--

local SCREEN_WIDTH, SCREEN_HEIGHT = guiGetScreenSize()
local SCREEN_SCALE = SCREEN_HEIGHT / 1080

function scale(value)
	if type(value) ~= "number" then
		return false
	end

	return math_floor(value * SCREEN_SCALE + 0.5)
end

local function createClass(super)
	if super ~= nil and type(super) ~= "table" then
		return false
	end

	local class

	class = {}
	class.__index = class

	function class.destroy(object, ...)
		if type(object.destructor) == "function" then
			object:destructor(...)
		end

		setmetatable(self, nil)
	end

	setmetatable(class, {
		__index = function(_, key)
			return super and super[key]
		end,
		__call = function(_, ...)
			local object = setmetatable({}, class)

			if type(object.constructor) == "function" then
				object:constructor(...)
			end

			return object
		end,
	})

	return class
end

local function isMaterial(material)
	if not isElement(material) then
		return false
	end

	local materialType = getElementType(material)

	if not materialType == MaterialType.Shader and not materialType == MaterialType.Svg and not materialType == MaterialType.Texture then
		return false
	end

	return true, materialType
end

local function resolveLength(length)
	if type(length) == "number" then
		return length, Unit.Pixel
	elseif length == Unit.Auto then
		return 0, Unit.Auto
	elseif length == Unit.FitContent then
		return 0, Unit.FitContent
	elseif type(length) == "string" then
		local _value, unit = utf8.match(length, "^([+-]?%d+%.?%d*)(.*)$")
		local value = tonumber(_value)

		if not value then
			return 0, Unit.Auto
		elseif not unit or unit == "" then
			return value, Unit.Pixel
		elseif unit == "px" then
			return value, Unit.Pixel
		elseif unit == "%" then
			return value * 0.01, Unit.Percentage
		elseif unit == "sw" then
			return math_floor(value * 0.01 * SCREEN_WIDTH + 0.5), Unit.Pixel
		elseif unit == "sh" then
			return math_floor(value * 0.01 * SCREEN_HEIGHT + 0.5), Unit.Pixel
		elseif unit == "sc" then
			return scale(value), Unit.Pixel
		end
	else
		return 0, Unit.Auto
	end
end

local function isPointInRectangle(px, py, x, y, width, height)
	return px >= x and py >= y and px <= x + width and py <= y + height
end

--
-- Color
--

local TRANSPARENT = 0x00ffffff
local WHITE = 0xffffffff
local BLACK = 0xff000000

local function getColorAlpha(color)
	return math_floor(color / 0x1000000) % 0x100
end

--
-- Drawing
--

local _dxCreateRenderTarget = dxCreateRenderTarget
local _dxSetRenderTarget = dxSetRenderTarget
local _dxSetBlendMode = dxSetBlendMode
local _dxGetBlendMode = dxGetBlendMode
local _dxDrawImage = dxDrawImage
local dxDrawText = dxDrawText
local dxDrawRectangle = dxDrawRectangle

local dxCreatedRenderTargets = {}
local dxCurrentRenderTarget
local dxCurrentBlendMode = BlendMode.Blend

local function dxIsRenderTarget(dxRenderTarget)
	return dxCreatedRenderTargets[dxRenderTarget] == true
end

local function dxCreateRenderTarget(width, height, alpha)
	local dxRenderTarget = _dxCreateRenderTarget(width, height, alpha)

	if dxRenderTarget then
		dxCreatedRenderTargets[dxRenderTarget] = true
	end

	return dxRenderTarget
end

local function dxDestroyRenderTarget(dxRenderTarget)
	if isElement(dxRenderTarget) then
		destroyElement(dxRenderTarget)
	end

	if dxCreatedRenderTargets[dxRenderTarget] then
		dxCreatedRenderTargets[dxRenderTarget] = nil
	end
end

local function dxSetRenderTarget(dxRenderTarget, clear)
	local success = _dxSetRenderTarget(dxRenderTarget, clear)

	if success then
		dxCurrentRenderTarget = dxRenderTarget
	end

	return success
end

local function dxGetRenderTarget()
	return dxCurrentRenderTarget
end

local function dxSetBlendMode(blendMode)
	if blendMode == dxCurrentBlendMode then
		return false
	end

	local success = _dxSetBlendMode(blendMode)

	if succes then
		dxCurrentBlendMode = blendMode
	end

	return success
end

local function dxGetBlendMode()
	return dxCurrentBlendMode
end

local function dxDrawImage(x, y, width, height, material, rotation, rotationCenterOffsetX, rotationCenterOffsetY, color)
	local valid, materialType = isMaterial(material)

	if not valid then
		return false
	end

	local dxPreviousBlendMode = dxGetBlendMode()
	local changedBlendMode =
		dxSetBlendMode(materialType == MaterialType.Shader and BlendMode.Blend or dxIsRenderTarget(material) and BlendMode.Add or dxPreviousBlendMode)

	_dxDrawImage(x, y, width, height, material, rotation, rotationCenterOffsetX, rotationCenterOffsetY, color)

	if changedBlendMode then
		dxSetBlendMode(dxPreviousBlendMode)
	end
end

--
-- Basic Id. system
--

local IDs = {}

function getNodeById(id)
	if type(id) ~= "string" then
		return false
	end

	local node = IDs[id]

	if not node then
		return false
	end

	return node
end

--
-- Node
--

Node = createClass()
Node.__node__ = true

local function isNode(node)
	return type(node) == "table" and node.__node__ == true
end

function Node:constructor(attributes, ...)
	if type(attributes) ~= "table" then
		attributes = {}
	end

	self.parent = false
	self.index = -1
	self.children = {}

	self.layoutDirty = true
	self.canvasDirty = true

	self.hoverable = type(attributes.hoverable) ~= "boolean" and true or attributes.hoverable
	self.clickable = type(attributes.clickable) ~= "boolean" and true or attributes.clickable
	self.focusable = attributes.focusable or false

	self.hovered = false
	self.clicked = false
	self.focused = false

	self.id = false
	self:setId(attributes.id)

	self.visible = true
	self.effectiveVisibility = true
	self:setVisible(attributes.visible)

	self.position = attributes.position or Position.Relative
	self.left = attributes.left or Unit.Auto
	self.top = attributes.top or Unit.Auto
	self.right = attributes.right or Unit.Auto
	self.bottom = attributes.bottom or Unit.Auto

	self.flexDirection = attributes.flexDirection or FlexDirection.Row
	self.flexWrap = attributes.flexWrap or FlexWrap.NoWrap
	self.flexShrink = attributes.flexShrink or 0
	self.flexGrow = attributes.flexGrow or 0

	self.justifyContent = attributes.justifyContent or JustifyContent.FlexStart
	self.alignItems = attributes.alignItems or AlignItems.Stretch
	self.alignSelf = attributes.alignSelf or AlignSelf.Auto

	self.gap = attributes.gap or Unit.Auto
	self.columnGap = attributes.columnGap or Unit.Auto
	self.rowGap = attributes.rowGap or Unit.Auto

	self.strokeColor = attributes.strokeColor or TRANSPARENT
	self.strokeWeight = attributes.strokeWeight or Unit.Auto
	self.strokeLeftWeight = attributes.strokeLeftWeight or Unit.Auto
	self.strokeTopWeight = attributes.strokeTopWeight or Unit.Auto
	self.strokeRightWeight = attributes.strokeRightWeight or Unit.Auto
	self.strokeBottomWeight = attributes.strokeBottomWeight or Unit.Auto

	self.borderRadius = attributes.borderRadius or Unit.Auto
	self.borderTopLeftRadius = attributes.borderTopLeftRadius or Unit.Auto
	self.borderTopRightRadius = attributes.borderTopRightRadius or Unit.Auto
	self.borderBottomLeftRadius = attributes.borderBottomLeftRadius or Unit.Auto
	self.borderBottomRightRadius = attributes.borderBottomRightRadius or Unit.Auto

	self.padding = attributes.padding or Unit.Auto
	self.paddingLeft = attributes.paddingLeft or Unit.Auto
	self.paddingTop = attributes.paddingTop or Unit.Auto
	self.paddingRight = attributes.paddingRight or Unit.Auto
	self.paddingBottom = attributes.paddingBottom or Unit.Auto

	self.width = attributes.width or Unit.Auto
	self.minWidth = attributes.minWidth or Unit.Auto
	self.maxWidth = attributes.maxWidth or Unit.Auto

	self.height = attributes.height or Unit.Auto
	self.minHeight = attributes.minHeight or Unit.Auto
	self.maxHeight = attributes.maxHeight or Unit.Auto

	self.backgroundColor = attributes.backgroundColor or TRANSPARENT
	self.foregroundColor = attributes.foregroundColor or false

	self.canvasWidth = 0
	self.canvasHeight = 0

	self.scrollLeft = 0
	self.scrollTop = 0

	self.overflow = attributes.overflow or Overflow.None
	self.overflowX = attributes.overflowX or Overflow.None
	self.overflowY = attributes.overflowY or Overflow.None

	self.scrollBarSize = attributes.scrollBarSize or 4
	self.scrollBarTrackColor = 0xff111111
	self.scrollBarThumbColor = 0xff222222

	self.resolvedLeftValue, self.resolvedLeftUnit = resolveLength(self.left)
	self.resolvedTopValue, self.resolvedTopUnit = resolveLength(self.top)
	self.resolvedRightValue, self.resolvedRightUnit = resolveLength(self.right)
	self.resolvedBottomValue, self.resolvedBottomUnit = resolveLength(self.bottom)

	self.resolvedGapValue, self.resolvedGapUnit = resolveLength(self.gap)
	self.resolvedColumnGapValue, self.resolvedColumnGapUnit = resolveLength(self.columnGap)
	self.resolvedRowGapValue, self.resolvedRowGapUnit = resolveLength(self.rowGap)

	self.resolvedWidthValue, self.resolvedWidthUnit = resolveLength(self.width)
	self.resolvedMinWidthValue, self.resolvedMinWidthUnit = resolveLength(self.minWidth)
	self.resolvedMaxWidthValue, self.resolvedMaxWidthUnit = resolveLength(self.maxWidth)

	self.resolvedHeightValue, self.resolvedHeightUnit = resolveLength(self.height)
	self.resolvedMinHeightValue, self.resolvedMinHeightUnit = resolveLength(self.minHeight)
	self.resolvedMaxHeightValue, self.resolvedMaxHeightUnit = resolveLength(self.maxHeight)

	self.resolvedStrokeWeightValue, self.resolvedStrokeWeightUnit = resolveLength(self.strokeWeight)
	self.resolvedStrokeLeftWeightValue, self.resolvedStrokeLeftWeightUnit = resolveLength(self.strokeLeftWeight)
	self.resolvedStrokeTopWeightValue, self.resolvedStrokeTopWeightUnit = resolveLength(self.strokeTopWeight)
	self.resolvedStrokeRightWeightValue, self.resolvedStrokeRightWeightUnit = resolveLength(self.strokeRightWeight)
	self.resolvedStrokeBottomWeightValue, self.resolvedStrokeBottomWeightUnit = resolveLength(self.strokeBottomWeight)

	self.resolvedBorderRadiusValue, self.resolvedBorderRadiusUnit = resolveLength(self.borderRadius)
	self.resolvedBorderTopLefttRadiusValue, self.resolvedBorderTopLefttRadiusUnit = resolveLength(self.borderTopLefttRadius)
	self.resolvedBorderTopRightRadiusValue, self.resolvedBorderTopRightRadiusUnit = resolveLength(self.borderTopRightRadius)
	self.resolvedBorderBottomLefttRadiusValue, self.resolvedBorderBottomLefttRadiusUnit = resolveLength(self.borderBottomLefttRadius)
	self.resolvedBorderBottomRightRadiusValue, self.resolvedBorderBottomRightRadiusUnit = resolveLength(self.borderBottomRightRadius)

	self.resolvedPaddingValue, self.resolvedPaddingUnit = resolveLength(self.padding)
	self.resolvedPaddingLeftValue, self.resolvedPaddingLeftUnit = resolveLength(self.paddingLeft)
	self.resolvedPaddingTopValue, self.resolvedPaddingTopUnit = resolveLength(self.paddingTop)
	self.resolvedPaddingRightValue, self.resolvedPaddingRightUnit = resolveLength(self.paddingRight)
	self.resolvedPaddingBottomValue, self.resolvedPaddingBottomUnit = resolveLength(self.paddingBottom)

	self.computedLeft = 0
	self.computedTop = 0
	self.computedRight = 0
	self.computedBottom = 0

	self.computedFlexBasis = 0

	self.computedGap = 0
	self.computedColumnGap = 0
	self.computedRowGap = 0

	self.computedX = 0
	self.computedY = 0

	self.computedWidth = 0
	self.computedMinWidth = false
	self.computedMaxWidth = false

	self.computedHeight = 0
	self.computedMinHeight = false
	self.computedMaxHeight = false

	self.computedStrokeLeftWeight = 0
	self.computedStrokeTopWeight = 0
	self.computedStrokeRightWeight = 0
	self.computedStrokeBottomWeight = 0

	self.computedBorderTopLeftRadius = 0
	self.computedBorderTopRightRadius = 0
	self.computedBorderBottomLeftRadius = 0
	self.computedBorderBottomRightRadius = 0

	self.computedPaddingLeft = 0
	self.computedPaddingTop = 0
	self.computedPaddingRight = 0
	self.computedPaddingBottom = 0

	self.computedOverflowX = 0
	self.computedOverflowY = 0

	self.computedHorizontalScrollBarThumbSize = 0
	self.computedVerticalScrollBarThumbSize = 0

	self.renderWidth = 0
	self.renderHeight = 0

	self.renderX = 0
	self.renderY = 0

	self.renderHorizontalScrollBarWidth = 0
	self.renderHorizontalScrollBarHeight = 0

	self.renderHorizontalScrollBarX = 0
	self.renderHorizontalScrollBarY = 0

	self.renderHorizontalScrollBarThumbWidth = 0
	self.renderHorizontalScrollBarThumbHeight = 0

	self.renderHorizontalScrollBarThumbX = 0
	self.renderHorizontalScrollBarThumbY = 0

	self.renderVerticalScrollBarWidth = 0
	self.renderVerticalScrollBarHeight = 0

	self.renderVerticalScrollBarX = 0
	self.renderVerticalScrollBarY = 0

	self.renderVerticalScrollBarThumbWidth = 0
	self.renderVerticalScrollBarThumbHeight = 0

	self.renderVerticalScrollBarThumbX = 0
	self.renderVerticalScrollBarThumbY = 0

	self.onCursorClick = attributes.onCursorClick
	self.onCursorDown = attributes.onCursorDown
	self.onCursorEnter = attributes.onCursorEnter
	self.onCursorLeave = attributes.onCursorLeave
	self.onCursorMove = attributes.onCursorMove
	self.onCursorUp = attributes.onCursorUp

	for i = 1, select("#", ...) do
		self:appendChild(select(i, ...))
	end
end

function Node:setParent(parent)
	if parent ~= false and not isNode(parent) then
		return false
	end

	if parent then
		return parent:appendChild(self)
	end

	parent = self.parent

	if parent then
		return parent:removeChild(self)
	end

	return false
end

function Node:appendChild(child)
	if not isNode(child) then
		return false
	end

	if child.parent == self then
		return false
	end

	if child.parent then
		child.parent:removeChild(child)
	end

	table_insert(self.children, child)

	child.parent = self
	child.index = #self.children

	child:markLayoutDirty()
	child:markCanvasDirty()

	return true
end

function Node:removeChild(child)
	if not isNode(child) then
		return false
	end

	if child.parent ~= self then
		return false
	end

	table_remove(self.children, child.index)
	self:reIndexChildren(child.index)

	child.parent = false
	child.index = -1

	self:markLayoutDirty()
	self:markCanvasDirty()

	return true
end

function Node:reIndexChildren(startAt)
	local children = self.children
	local childCount = #children

	for i = startAt or 1, childCount do
		children[i].index = i
	end
end

function Node:markLayoutDirty()
	if not self.layoutDirty then
		self.layoutDirty = true
	end

	local parent = self.parent

	if parent and not parent.layoutDirty then
		parent:markLayoutDirty()
	end
end

function Node:markCanvasDirty()
	if not self.canvasDirty then
		self.canvasDirty = true
	end

	local parent = self.parent

	if parent and not parent.canvasDirty then
		parent:markCanvasDirty()
	end
end

function Node:setVisible(visible)
	if type(visible) ~= "boolean" then
		return false
	end

	if visible == self.visible then
		return false
	end

	self.visible = visible

	return true
end

function Node:setId(id)
	if id ~= false or (type(id) ~= "boolean" or utf8_len(id) == 0) then
		return false
	end

	if id then
		IDs[id] = self
		IDs[self] = id
	else
		local id = IDs[self]

		IDs[self] = nil
		IDs[id] = nil
	end

	return true
end

--
-- Text
--

Text = createClass(Node)
Text.__text__ = true

function Text:constructor(attributes)
	if type(attributes) ~= "table" then
		attributes = {}
	end

	self.value = attributes.value or ""

	self.textSize = attributes.textSize or 1
	self.font = attributes.font or "default"

	self.alignX = attributes.alignX or "left"
	self.alignY = attributes.alignY or "top"

	self.clip = attributes.clip or false
	self.wordWrap = attributes.wordWrap or false
	self.colorCoded = attributes.colorCoded or false

	self.computedTextWidth = 0
	self.computedTextHeight = 0

	Node.constructor(self, attributes)
end

function Text:measure(availableWidth, availableHeight)
	local textSize = self.textSize
	local font = self.font

	local textWidth, textHeight = dxGetTextSize(self.value, availableWidth or 0, textSize, font, self.wordWrap, self.colorCoded)
	textHeight = math_max(textHeight, dxGetFontHeight(textSize, font))

	self.computedTextWidth = textWidth
	self.computedTextHeight = textHeight

	return textWidth, textHeight
end

function Text:draw(x, y, width, height, color)
	local value = self.value

	if utf8_len(value) == 0 then
		return
	end

	dxDrawText(value, x, y, x + width, y + height, color, self.textSize, self.font, self.alignX, self.alignY, self.clip, self.wordWrap, false, self.colorCoded)
end

--
-- Image
--

Image = createClass(Node)
Image.__image__ = true

function Image:constructor(attributes)
	if type(attributes) ~= "table" then
		attributes = {}
	end

	self.material = isMaterial(attributes.material) and attributes.material or false

	self.computedMaterialWidth = 0
	self.computedMaterialHeight = 0

	Node.constructor(self, attributes)
end

function Image:measure()
	local material = self.material
	local materialWidth = 0
	local materialHeight = 0

	if material then
		materialWidth, materialHeight = dxGetMaterialSize(material)
	end

	self.computedMaterialWidth = materialWidth
	self.computedMaterialHeight = materialHeight

	return materialWidth, materialHeight
end

function Image:draw(x, y, width, height, color)
	local material = self.material

	if not material then
		return
	end

	dxDrawImage(x, y, width, height, material, 0, 0, 0, color)
end

--
-- Input
--

Input = createClass(Node)
Input.__input__ = true

function Input:constructor(attributes)
	if type(attributes) ~= "table" then
		attributes = { backgroundColor = WHITE, foregroundColor = BLACK }
	end

	attributes.focusable = true

	self.caretPosition = 0
	self.caretWidth = attributes.caretWidth or 1
	self.caretColor = attributes.caretColor or BLACK

	self.value = ""
	self.valueLength = 0
	self:setValue(attributes.value)

	self.textSize = attributes.textSize or 1
	self.font = attributes.font or "default"

	self.alignX = attributes.alignX or "left"
	self.alignY = attributes.alignY or "center"

	self.computedTextWidth = 0
	self.computedTextHeight = 0

	Node.constructor(self, attributes)
end

function Input:setValue(value)
	if type(value) ~= "string" then
		return false
	end

	if value == self.value then
		return false
	end

	self.value = value
	self.valueLength = utf8_len(value)

	self.caretPosition = self.valueLength

	self:markLayoutDirty()
	self:markCanvasDirty()

	return true
end

function Input:insertText(text)
	if type(text) ~= "string" then
		return false
	end

	if utf8_len(text) == 0 then
		return false
	end

	local caretPosition = self.caretPosition

	local previousValue = self.value
	self.value = utf8_sub(previousValue, 1, caretPosition) .. text .. utf8_sub(previousValue, caretPosition + 1)
	self.valueLength = utf8_len(self.value)

	self.caretPosition = caretPosition + utf8_len(text)

	self:markLayoutDirty()
	self:markCanvasDirty()

	return true
end

function Input:removeText(from, to)
	from, to = math_min(from, to), math_max(from, to)
	from, to = math_max(0, from), math_min(self.valueLength, to)

	local caretPosition = self.caretPosition

	local previousValue = self.value
	self.value = utf8_sub(previousValue, 1, from) .. utf8_sub(previousValue, to + 1)
	self.valueLength = utf8_len(self.value)

	self.caretPosition = from

	self:markLayoutDirty()
	self:markCanvasDirty()

	return true
end

function Input:measure()
	local textSize = self.textSize
	local font = self.font

	local textWidth, textHeight = dxGetTextSize(self.value, availableWidth or 0, textSize, font, self.wordWrap, self.colorCoded)
	textHeight = math_max(textHeight, dxGetFontHeight(textSize, font))

	self.computedTextWidth = textWidth
	self.computedTextHeight = textHeight

	return 200, textHeight
end

function Input:draw(x, y, width, height, foregroundColor)
	local value = self.value

	if utf8_len(value) > 0 then
		dxDrawText(value, x, y, x + width, y + height, foregroundColor, self.textSize, self.font, self.alignX, self.alignY)
	end

	if self.focused then
		local caretX = x + dxGetTextWidth(utf8_sub(value, 1, self.caretPosition), self.textSize, self.font)
		local caretY = y + (height - self.computedTextHeight) * 0.5

		dxDrawRectangle(caretX, caretY, self.caretWidth, self.computedTextHeight, self.caretColor)
	end
end

--
-- Algorithm
--

local splitChildren
local calculateLayout

function splitChildren(
	isMainAxisRow,
	mainAxisDimension,
	mainAxisPosition,
	crossAxisDimension,
	crossAxisPosition,
	containerMainSize,
	containerMainInnerSize,
	containerCrossSize,
	containerCrossInnerSize,
	strokeWeightMainStart,
	strokeWeightCrossStart,
	paddingMainStart,
	paddingCrossStart,
	gapMain,
	gapCross,
	canWrap,
	stretchItems,
	children,
	childCount,
	doingSecondPass,
	doingThirdPass
)
	local lines = {
		{
			[mainAxisDimension] = 0,
			[mainAxisPosition] = 0,
			[crossAxisDimension] = 0,
			[crossAxisPosition] = 0,
			remainingFreeSpace = 0,
			totalFlexGrowFactor = 0,
			totalFlexShrinkScaledFactor = 0,
		},
	}

	local previousLine
	local currentLine = lines[1]

	local mainMaxLineSize = 0
	local crossTotalLinesSize = 0

	local secondPassItems
	local thirdPassItems

	local hasPrevSiblingVisible = false

	for i = 1, childCount do
		local child = children[i]

		while true do
			if not child.visible then
				break
			end

			if not doingSecondPass then
				local childAvailableWidth = isMainAxisRow and containerMainSize ~= nil and containerMainInnerSize
					or not isMainAxisRow and containerCrossSize ~= nil and containerCrossInnerSize
					or nil
				local childAvailableHeight = isMainAxisRow and containerCrossSize ~= nil and containerCrossInnerSize
					or not isMainAxisRow and containerMainSize ~= nil and containerMainInnerSize
					or nil

				calculateLayout(child, childAvailableWidth, childAvailableHeight, isMainAxisRow, stretchItems)

				local childAlignSelf = child.alignSelf

				local childResolvedWidthUnit = child.resolvedWidthUnit
				local childResolvedHeightUnit = child.resolvedHeightUnit

				local childResolvedMinWidthUnit = child.resolvedMinWidthUnit
				local childResolvedMinHeightUnit = child.resolvedMinHeightUnit

				local childResolvedMaxWidthUnit = child.resolvedMaxWidthUnit
				local childResolvedMaxHeightUnit = child.resolvedMaxHeightUnit

				local childResolvedMainSizeUnit = isMainAxisRow and childResolvedWidthUnit or childResolvedHeightUnit
				local childResolvedMinMainSizeUnit = isMainAxisRow and childResolvedMinWidthUnit or childResolvedMinHeightUnit
				local childResolvedMaxMainSizeUnit = isMainAxisRow and childResolvedMaxWidthUnit or childResolvedMaxHeightUnit

				local childResolvedCrossSizeUnit = isMainAxisRow and childResolvedHeightUnit or childResolvedWidthUnit
				local childResolvedMinCrossSizeUnit = isMainAxisRow and childResolvedMinHeightUnit or childResolvedMinWidthUnit
				local childResolvedMaxCrossSizeUnit = isMainAxisRow and childResolvedMaxHeightUnit or childResolvedMaxWidthUnit

				if
					not containerMainSize
						and (childResolvedMainSizeUnit == Unit.Percentage or (childResolvedMinMainSizeUnit == Unit.Percentage or childResolvedMinMainSizeUnit == Unit.Stretch) or (childResolvedMaxMainSizeUnit == Unit.Percentage or childResolvedMaxMainSizeUnit == Unit.Stretch))
					or not containerCrossSize and (childResolvedCrossSizeUnit == Unit.Percentage or (childResolvedMinCrossSizeUnit == Unit.Percentage or childResolvedMinCrossSizeUnit == Unit.Stretch) or (childResolvedMaxCrossSizeUnit == Unit.Percentage or childResolvedMaxCrossSizeUnit == Unit.Stretch))
					or childResolvedCrossSizeUnit == Unit.Auto
						and stretchItems
						and (childAlignSelf == AlignSelf.Auto or childAlignSelf == AlignSelf.Stretch)
				then
					if not secondPassItems then
						secondPassItems = {}
					end

					table_insert(secondPassItems, child)
				end
			end

			local childComputedMainSize = not doingThirdPass and child.computedFlexBasis or child[mainAxisDimension]
			local childComputedCrossSize = child[crossAxisDimension]

			if canWrap and hasPrevSiblingVisible and currentLine[mainAxisDimension] + gapMain + childComputedMainSize > containerMainInnerSize then
				previousLine = currentLine
				currentLine = {
					[mainAxisDimension] = 0,
					[mainAxisPosition] = 0,
					[crossAxisDimension] = 0,
					[crossAxisPosition] = previousLine[crossAxisPosition] + previousLine[crossAxisDimension] + gapCross,
					remainingFreeSpace = 0,
					totalFlexGrowFactor = 0,
					totalFlexShrinkScaledFactor = 0,
				}

				table_insert(lines, currentLine)

				hasPrevSiblingVisible = false
			end

			table_insert(currentLine, child)

			if not hasPrevSiblingVisible then
				hasPrevSiblingVisible = true
			end

			currentLine[mainAxisDimension] = currentLine[mainAxisDimension] + (hasPrevSiblingVisible and i < #children and gapMain or 0) + childComputedMainSize
			currentLine[crossAxisDimension] = math_max(currentLine[crossAxisDimension], childComputedCrossSize)

			if containerMainSize then
				currentLine.remainingFreeSpace = containerMainInnerSize - currentLine[mainAxisDimension]
			end

			mainMaxLineSize = math_max(mainMaxLineSize, currentLine[mainAxisDimension])
			crossTotalLinesSize = math_max(crossTotalLinesSize, currentLine[crossAxisPosition] + currentLine[crossAxisDimension])

			if not doingThirdPass then
				local childFlexGrow = child.flexGrow
				local childFlexShrink = child.flexShrink

				if childFlexGrow > 0 or childFlexShrink > 0 then
					currentLine.totalFlexGrowFactor = currentLine.totalFlexGrowFactor + childFlexGrow
					currentLine.totalFlexShrinkScaledFactor = currentLine.totalFlexShrinkScaledFactor + childFlexShrink * childComputedMainSize

					if not thirdPassItems then
						thirdPassItems = {}
					end

					table_insert(thirdPassItems, child)
					thirdPassItems[child] = currentLine
				end
			end

			break
		end
	end

	return lines, mainMaxLineSize, crossTotalLinesSize, secondPassItems, thirdPassItems
end

function calculateLayout(node, availableWidth, availableHeight, parentIsMainAxisRow, parentStretchItems, forcedWidth, forcedHeight)
	if not isNode(node) then
		return false
	end

	if not node.visible then
		return false
	end

	if parentIsMainAxisRow == nil then
		parentIsMainAxisRow = true
	end
	if parentStretchItems == nil then
		parentStretchItems = false
	end

	local alignSelf = node.alignSelf

	local computedWidth
	local computedHeight

	local resolvedWidthValue, resolvedWidthUnit = node.resolvedWidthValue, node.resolvedWidthUnit
	local resolvedHeightValue, resolvedHeightUnit = node.resolvedHeightValue, node.resolvedHeightUnit

	if forcedWidth then
		computedWidth = forcedWidth
	elseif resolvedWidthUnit == Unit.Pixel then
		computedWidth = resolvedWidthValue
	elseif resolvedWidthUnit == Unit.Percentage then
		computedWidth = resolvedWidthValue * (availableWidth or 0)
	elseif
		resolvedWidthUnit == Unit.Auto
		and availableWidth
		and not parentIsMainAxisRow
		and parentStretchItems
		and (alignSelf == AlignSelf.Auto or alignSelf == AlignSelf.Stretch)
	then
		computedWidth = availableWidth
	end

	if forcedHeight then
		computedHeight = forcedHeight
	elseif resolvedHeightUnit == Unit.Pixel then
		computedHeight = resolvedHeightValue
	elseif resolvedHeightUnit == Unit.Percentage then
		computedHeight = resolvedHeightValue * (availableHeight or 0)
	elseif
		resolvedHeightUnit == Unit.Auto
		and availableHeight
		and parentIsMainAxisRow
		and parentStretchItems
		and (alignSelf == AlignSelf.Auto or alignSelf == AlignSelf.Stretch)
	then
		computedHeight = availableHeight
	end

	if not node.layoutDirty then
		return false
	end

	node.layoutDirty = false

	local flexDirection = node.flexDirection
	local isMainAxisRow = flexDirection == FlexDirection.Row

	local mainAxisDimension = isMainAxisRow and "computedWidth" or "computedHeight"
	local mainAxisPosition = isMainAxisRow and "computedX" or "computedY"

	local crossAxisDimension = isMainAxisRow and "computedHeight" or "computedWidth"
	local crossAxisPosition = isMainAxisRow and "computedY" or "computedX"

	if
		node.strokeWeight ~= node.previousStrokeWeight
		or node.strokeLeftWeight ~= node.previousStrokeLeftWeight
		or node.strokeTopWeight ~= node.previousStrokeTopWeight
		or node.strokeRightWeight ~= node.previousStrokeRightWeight
		or node.strokeBottomWeight ~= node.previousStrokeBottomWeight
	then
		node.previousStrokeWeight = node.strokeWeight
		node.previousStrokeLeftWeight = node.strokeLeftWeight
		node.previousStrokeTopWeight = node.strokeTopWeight
		node.previousStrokeRightWeight = node.strokeRightWeight
		node.previousStrokeBottomWeight = node.strokeBottomWeight

		if node.resolvedStrokeWeightUnit == Unit.Auto then
			local computedStrokeWeight = 0
			node.computedStrokeLeftWeight = computedStrokeWeight
			node.computedStrokeTopWeight = computedStrokeWeight
			node.computedStrokeRightWeight = computedStrokeWeight
			node.computedStrokeBottomWeight = computedStrokeWeight
		elseif node.resolvedStrokeWeightUnit == Unit.Pixel then
			local computedStrokeWeight = node.resolvedStrokeWeightValue
			node.computedStrokeLeftWeight = computedStrokeWeight
			node.computedStrokeTopWeight = computedStrokeWeight
			node.computedStrokeRightWeight = computedStrokeWeight
			node.computedStrokeBottomWeight = computedStrokeWeight
		end

		if node.resolvedStrokeLeftWeightUnit == Unit.Pixel then
			node.computedStrokeLeftWeight = node.resolvedStrokeLeftWeightValue
		end

		if node.resolvedStrokeTopWeightUnit == Unit.Pixel then
			node.computedStrokeTopWeight = node.resolvedStrokeTopWeightValue
		end

		if node.resolvedStrokeRightWeightUnit == Unit.Pixel then
			node.computedStrokeRightWeight = node.resolvedStrokeRightWeightValue
		end

		if node.resolvedStrokeBottomWeightUnit == Unit.Pixel then
			node.computedStrokeBottomWeight = node.resolvedStrokeBottomWeightValue
		end
	end

	local computedStrokeLeftWeight = node.computedStrokeLeftWeight
	local computedStrokeTopWeight = node.computedStrokeTopWeight
	local computedStrokeRightWeight = node.computedStrokeRightWeight
	local computedStrokeBottomWeight = node.computedStrokeBottomWeight

	local strokeWeightMainStart = isMainAxisRow and computedStrokeLeftWeight or computedStrokeTopWeight
	local strokeWeightMainEnd = isMainAxisRow and computedStrokeRightWeight or computedStrokeBottomWeight

	local strokeWeightCrossStart = isMainAxisRow and computedStrokeTopWeight or computedStrokeLeftWeight
	local strokeWeightCrossEnd = isMainAxisRow and computedStrokeBottomWeight or computedStrokeRightWeight

	if
		node.padding ~= node.previousPadding
		or node.paddingLeft ~= node.previousPaddingLeft
		or node.paddingTop ~= node.previousPaddingTop
		or node.paddingRight ~= node.previousPaddingRight
		or node.paddingBottom ~= node.previousPaddingBottom
	then
		node.previousPadding = node.padding
		node.previousPaddingLeft = node.paddingLeft
		node.previousPaddingTop = node.paddingTop
		node.previousPaddingRight = node.paddingRight
		node.previousPaddingBottom = node.paddingBottom

		if node.resolvedPaddingUnit == Unit.Auto then
			local computedPadding = 0
			node.computedPaddingLeft = computedPadding
			node.computedPaddingTop = computedPadding
			node.computedPaddingRight = computedPadding
			node.computedPaddingBottom = computedPadding
		elseif node.resolvedPaddingUnit == Unit.Pixel then
			local computedPadding = node.resolvedPaddingValue
			node.computedPaddingLeft = computedPadding
			node.computedPaddingTop = computedPadding
			node.computedPaddingRight = computedPadding
			node.computedPaddingBottom = computedPadding
		end

		if node.resolvedPaddingLeftUnit == Unit.Pixel then
			node.computedPaddingLeft = node.resolvedPaddingLeftValue
		end

		if node.resolvedPaddingTopUnit == Unit.Pixel then
			node.computedPaddingTop = node.resolvedPaddingTopValue
		end

		if node.resolvedPaddingRightUnit == Unit.Pixel then
			node.computedPaddingRight = node.resolvedPaddingRightValue
		end

		if node.resolvedPaddingBottomUnit == Unit.Pixel then
			node.computedPaddingBottom = node.resolvedPaddingBottomValue
		end
	end

	local computedPaddingLeft = node.computedPaddingLeft
	local computedPaddingTop = node.computedPaddingTop
	local computedPaddingRight = node.computedPaddingRight
	local computedPaddingBottom = node.computedPaddingBottom

	local paddingMainStart = isMainAxisRow and computedPaddingLeft or computedPaddingTop
	local paddingMainEnd = isMainAxisRow and computedPaddingRight or computedPaddingBottom

	local paddingCrossStart = isMainAxisRow and computedPaddingTop or computedPaddingLeft
	local paddingCrossEnd = isMainAxisRow and computedPaddingBottom or computedPaddingRight

	local containerMainSize = isMainAxisRow and computedWidth or not isMainAxisRow and computedHeight or nil
	local containerMainInnerSize = math_max((containerMainSize or 0) - strokeWeightMainStart - strokeWeightMainEnd - paddingMainStart - paddingMainEnd, 0)
	local containerMainFitToContent = false

	local containerCrossSize = isMainAxisRow and computedHeight or not isMainAxisRow and computedWidth or nil
	local containerCrossInnerSize = math_max((containerCrossSize or 0) - strokeWeightCrossStart - strokeWeightCrossEnd - paddingCrossStart - paddingCrossEnd, 0)
	local containerCrossFitToContent = false

	local children = node.children
	local childCount = #children

	if node.measure then
		local measuredWidth, measuredHeight = node:measure(computedWidth, computedHeight)

		if not computedWidth and (resolvedWidthUnit == Unit.Auto or resolvedWidthUnit == Unit.FitContent) then
			computedWidth = measuredWidth + computedStrokeLeftWeight + computedStrokeRightWeight + computedPaddingLeft + computedPaddingRight
		end

		if not computedHeight and (resolvedHeightUnit == Unit.Auto or resolvedHeightUnit == Unit.FitContent) then
			computedHeight = measuredHeight + computedStrokeTopWeight + computedStrokeBottomWeight + computedPaddingTop + computedPaddingBottom
		end

		if
			not forcedWidth
			and not parentIsMainAxisRow
			and parentStretchItems
			and resolvedWidthUnit == Unit.Auto
			and (alignSelf == AlignSelf.Auto or alignSelf == AlignSelf.Stretch)
			and availableWidth
		then
			computedWidth = math_max(computedWidth, availableWidth)
		elseif
			not forcedHeight
			and parentIsMainAxisRow
			and parentStretchItems
			and resolvedHeightUnit == Unit.Auto
			and (alignSelf == AlignSelf.Auto or alignSelf == AlignSelf.Stretch)
			and availableHeight
		then
			computedHeight = math_max(computedHeight, availableHeight)
		end
	elseif childCount == 0 then
		if not computedWidth and (resolvedWidthUnit == Unit.Auto or resolvedWidthUnit == Unit.FitContent) then
			computedWidth = computedStrokeLeftWeight + computedStrokeRightWeight + computedPaddingLeft + computedPaddingRight
		end

		if not computedHeight and (resolvedHeightUnit == Unit.Auto or resolvedHeightUnit == Unit.FitContent) then
			computedHeight = computedStrokeTopWeight + computedStrokeBottomWeight + computedPaddingTop + computedPaddingBottom
		end

		if
			not forcedWidth
			and not parentIsMainAxisRow
			and parentStretchItems
			and resolvedWidthUnit == Unit.Auto
			and (alignSelf == AlignSelf.Auto or alignSelf == AlignSelf.Stretch)
			and availableWidth
		then
			computedWidth = math_max(computedWidth, availableWidth)
		elseif
			not forcedHeight
			and parentIsMainAxisRow
			and parentStretchItems
			and resolvedHeightUnit == Unit.Auto
			and (alignSelf == AlignSelf.Auto or alignSelf == AlignSelf.Stretch)
			and availableHeight
		then
			computedHeight = math_max(computedHeight, availableHeight)
		end
	else
		local flexWrap = node.flexWrap
		local canWrap = flexWrap ~= FlexWrap.NoWrap and containerMainSize ~= nil

		local justifyContent = node.justifyContent
		local alignItems = node.alignItems
		local stretchItems = alignItems == AlignItems.Stretch

		if node.gap ~= node.previousGap or node.columnGap ~= node.previousColumnGap or node.rowGap ~= node.previousRowGap then
			node.previousGap = node.gap
			node.previousColumnGap = node.columnGap
			node.previousRowGap = node.rowGap

			if node.resolvedGapUnit == Unit.Auto then
				local computedGap = 0
				node.computedColumnGap = computedGap
				node.computedRowGap = computedGap
			elseif node.resolvedGapUnit == Unit.Pixel then
				local computedGap = node.resolvedGapValue
				node.computedColumnGap = computedGap
				node.computedRowGap = computedGap
			end

			if node.resolvedColumnGapUnit == Unit.Pixel then
				node.computedColumnGap = node.resolvedColumnGapValue
			end

			if node.resolvedRowGapUnit == Unit.Pixel then
				node.computedRowGap = node.resolvedRowGapValue
			end
		end

		local computedColumnGap = node.computedColumnGap
		local computedRowGap = node.computedRowGap

		local gapMain = isMainAxisRow and computedColumnGap or computedRowGap
		local gapCross = isMainAxisRow and computedRowGap or computedColumnGap

		local lines, mainMaxLineSize, crossTotalLinesSize, secondPassItems, thirdPassItems = splitChildren(
			isMainAxisRow,
			mainAxisDimension,
			mainAxisPosition,
			crossAxisDimension,
			crossAxisPosition,
			containerMainSize,
			containerMainInnerSize,
			containerCrossSize,
			containerCrossInnerSize,
			strokeWeightMainStart,
			strokeWeightCrossStart,
			paddingMainStart,
			paddingCrossStart,
			gapMain,
			gapCross,
			canWrap,
			stretchItems,
			children,
			childCount,
			false
		)

		local resolvedMainSizeUnit = isMainAxisRow and resolvedWidthUnit or resolvedHeightUnit
		local resolvedCrossSizeUnit = isMainAxisRow and resolvedHeightUnit or resolvedWidthUnit

		local forcedMainSize = isMainAxisRow and forcedWidth or not isMainAxisRow and forcedHeight or nil
		local forcedCrossSize = isMainAxisRow and forcedHeight or not isMainAxisRow and forcedWidth or nil

		if not forcedMainSize and not containerMainSize and (resolvedMainSizeUnit == Unit.Auto or resolvedMainSizeUnit == Unit.FitContent) then
			computedWidth = isMainAxisRow and (mainMaxLineSize + strokeWeightMainStart + strokeWeightMainEnd + paddingMainStart + paddingMainEnd)
				or computedWidth
			computedHeight = not isMainAxisRow and (mainMaxLineSize + strokeWeightMainStart + strokeWeightMainEnd + paddingMainStart + paddingMainEnd)
				or computedHeight

			containerMainSize = isMainAxisRow and computedWidth or computedHeight
			containerMainInnerSize = mainMaxLineSize
			containerMainFitToContent = true
		end

		if not forcedCrossSize and not containerCrossSize and (resolvedCrossSizeUnit == Unit.Auto or resolvedCrossSizeUnit == Unit.FitContent) then
			computedWidth = not isMainAxisRow and (crossTotalLinesSize + strokeWeightCrossStart + strokeWeightCrossEnd + paddingCrossStart + paddingCrossEnd)
				or computedWidth
			computedHeight = isMainAxisRow and (crossTotalLinesSize + strokeWeightCrossStart + strokeWeightCrossEnd + paddingCrossStart + paddingCrossEnd)
				or computedHeight

			containerCrossSize = not isMainAxisRow and computedWidth or computedHeight
			containerCrossInnerSize = crossTotalLinesSize
			containerCrossFitToContent = true
		end

		if
			not forcedWidth
			and not parentIsMainAxisRow
			and parentStretchItems
			and resolvedWidthUnit == Unit.Auto
			and (alignSelf == AlignSelf.Auto or alignSelf == AlignSelf.Stretch)
			and availableWidth
		then
			computedWidth = math_max(computedWidth, availableWidth)
		elseif
			not forcedHeight
			and parentIsMainAxisRow
			and parentStretchItems
			and resolvedHeightUnit == Unit.Auto
			and (alignSelf == AlignSelf.Auto or alignSelf == AlignSelf.Stretch)
			and availableHeight
		then
			computedHeight = math_max(computedHeight, availableHeight)
		end

		if secondPassItems then
			for i = 1, #secondPassItems do
				local child = secondPassItems[i]

				child.layoutDirty = true

				local childAvailableWidth = isMainAxisRow and containerMainInnerSize or containerCrossInnerSize
				local childAvailableHeight = isMainAxisRow and containerCrossInnerSize or containerMainInnerSize

				calculateLayout(child, childAvailableWidth, childAvailableHeight, isMainAxisRow, stretchItems)
			end

			lines, mainMaxLineSize, crossTotalLinesSize, secondPassItems, thirdPassItems = splitChildren(
				isMainAxisRow,
				mainAxisDimension,
				mainAxisPosition,
				crossAxisDimension,
				crossAxisPosition,
				containerMainSize,
				containerMainInnerSize,
				containerCrossSize,
				containerCrossInnerSize,
				strokeWeightMainStart,
				strokeWeightCrossStart,
				paddingMainStart,
				paddingCrossStart,
				gapMain,
				gapCross,
				canWrap,
				stretchItems,
				children,
				childCount,
				true
			)

			if not forcedCrossSize and containerCrossFitToContent then
				computedWidth = not isMainAxisRow
						and (crossTotalLinesSize + strokeWeightCrossStart + strokeWeightCrossEnd + paddingCrossStart + paddingCrossEnd)
					or computedWidth
				computedHeight = isMainAxisRow and (crossTotalLinesSize + strokeWeightCrossStart + strokeWeightCrossEnd + paddingCrossStart + paddingCrossEnd)
					or computedHeight

				containerCrossSize = not isMainAxisRow and computedWidth or computedHeight
				containerCrossInnerSize = crossTotalLinesSize
			end

			if
				not forcedWidth
				and not parentIsMainAxisRow
				and parentStretchItems
				and resolvedWidthUnit == Unit.Auto
				and (alignSelf == AlignSelf.Auto or alignSelf == AlignSelf.Stretch)
				and availableWidth
			then
				computedWidth = math_max(computedWidth, availableWidth)
			elseif
				not forcedHeight
				and parentIsMainAxisRow
				and parentStretchItems
				and resolvedHeightUnit == Unit.Auto
				and (alignSelf == AlignSelf.Auto or alignSelf == AlignSelf.Stretch)
				and availableHeight
			then
				computedHeight = math_max(computedHeight, availableHeight)
			end
		end

		if thirdPassItems then
			for i = 1, #thirdPassItems do
				local child = thirdPassItems[i]

				child.layoutDirty = true

				local childFlexGrow = child.flexGrow
				local childFlexShrink = child.flexShrink

				local line = thirdPassItems[child]
				local lineRemainingFreeSpace = line.remainingFreeSpace

				local childAvailableWidth = isMainAxisRow and containerMainInnerSize or containerCrossInnerSize
				local childAvailableHeight = isMainAxisRow and containerCrossInnerSize or containerCrossInnerSize

				local childForcedWidth
				local childForcedHeight

				if childFlexGrow > 0 and lineRemainingFreeSpace > 0 then
					local childComputedMainSize = child.computedFlexBasis

					local flexGrowAmount = (childFlexGrow / line.totalFlexGrowFactor) * lineRemainingFreeSpace
					childForcedWidth = isMainAxisRow and (childComputedMainSize + flexGrowAmount) or nil
					childForcedHeight = not isMainAxisRow and (childComputedMainSize + flexGrowAmount) or nil
				elseif lineRemainingFreeSpace < 0 then
					local childComputedMainSize = child.computedFlexBasis

					local flexShrinkAmount = childComputedMainSize * (childFlexShrink / line.totalFlexShrinkScaledFactor) * -lineRemainingFreeSpace
					childForcedWidth = isMainAxisRow and math_max(childComputedMainSize - flexShrinkAmount, 0) or nil
					childForcedHeight = not isMainAxisRow and math_max(childComputedMainSize - flexShrinkAmount, 0) or nil
				end

				calculateLayout(child, childAvailableWidth, childAvailableHeight, isMainAxisRow, parentStretchItems, childForcedWidth, childForcedHeight)
			end

			lines, mainMaxLineSize, crossTotalLinesSize = splitChildren(
				isMainAxisRow,
				mainAxisDimension,
				mainAxisPosition,
				crossAxisDimension,
				crossAxisPosition,
				containerMainSize,
				containerMainInnerSize,
				containerCrossSize,
				containerCrossInnerSize,
				strokeWeightMainStart,
				strokeWeightCrossStart,
				paddingMainStart,
				paddingCrossStart,
				gapMain,
				gapCross,
				canWrap,
				stretchItems,
				children,
				childCount,
				true,
				true
			)

			if not forcedCrossSize and containerCrossFitToContent then
				computedWidth = not isMainAxisRow
						and (crossTotalLinesSize + strokeWeightCrossStart + strokeWeightCrossEnd + paddingCrossStart + paddingCrossEnd)
					or computedWidth
				computedHeight = isMainAxisRow and (crossTotalLinesSize + strokeWeightCrossStart + strokeWeightCrossEnd + paddingCrossStart + paddingCrossEnd)
					or computedHeight

				containerCrossSize = not isMainAxisRow and computedWidth or computedHeight
				containerCrossInnerSize = crossTotalLinesSize
			end

			if
				not forcedWidth
				and not parentIsMainAxisRow
				and parentStretchItems
				and resolvedWidthUnit == Unit.Auto
				and (alignSelf == AlignSelf.Auto or alignSelf == AlignSelf.Stretch)
				and availableWidth
			then
				computedWidth = math_max(computedWidth, availableWidth)
			elseif
				not forcedHeight
				and parentIsMainAxisRow
				and parentStretchItems
				and resolvedHeightUnit == Unit.Auto
				and (alignSelf == AlignSelf.Auto or alignSelf == AlignSelf.Stretch)
				and availableHeight
			then
				computedHeight = math_max(computedHeight, availableHeight)
			end
		end

		local overflowX = isMainAxisRow and math_max(mainMaxLineSize - containerMainInnerSize, 0) or math_max(crossTotalLinesSize - containerCrossInnerSize, 0)
		local overflowY = isMainAxisRow and math_max(crossTotalLinesSize - containerCrossInnerSize, 0) or math_max(mainMaxLineSize - containerMainInnerSize, 0)

		if node.overflow ~= Overflow.None and node.overflow ~= Overflow.Hidden then
			if overflowY > 0 then
				node.computedVerticalScrollBarThumbSize = isMainAxisRow
						and (containerCrossInnerSize / (containerCrossInnerSize + overflowY) * containerCrossInnerSize)
					or (containerMainInnerSize / (containerMainInnerSize + overflowY) * containerMainInnerSize)
			end
			if overflowX > 0 then
				node.computedHorizontalScrollBarThumbSize = isMainAxisRow
						and (containerMainInnerSize / (containerMainInnerSize + overflowX) * containerMainInnerSize)
					or (containerCrossInnerSize / (containerCrossInnerSize + overflowX) * containerCrossInnerSize)
			end
		end

		node.computedOverflowX = overflowX
		node.computedOverflowY = overflowY

		local linesAlignItemsOffset = alignItems == AlignItems.Center and ((containerCrossInnerSize - crossTotalLinesSize) * 0.5)
			or alignItems == AlignItems.FlexEnd and (containerCrossInnerSize - crossTotalLinesSize)
			or 0

		for i = 1, #lines do
			local line = lines[i]
			local lineChildCount = #line
			local lineCrossSize = line[crossAxisDimension]
			local lineRemainingFreeSpace = line.remainingFreeSpace

			local lineJustifyContentGap = justifyContent == JustifyContent.SpaceBetween
					and lineChildCount > 1
					and (lineRemainingFreeSpace / (lineChildCount - 1))
				or justifyContent == JustifyContent.SpaceAround and (lineRemainingFreeSpace / lineChildCount)
				or justifyContent == JustifyContent.SpaceEvenly and (lineRemainingFreeSpace / (lineChildCount + 1))
				or 0
			local lineJustifyContentOffset = justifyContent == JustifyContent.Center and (lineRemainingFreeSpace * 0.5)
				or justifyContent == JustifyContent.FlexEnd and lineRemainingFreeSpace
				or justifyContent == JustifyContent.SpaceBetween and 0
				or justifyContent == JustifyContent.SpaceAround and (lineJustifyContentGap * 0.5)
				or justifyContent == JustifyContent.SpaceEvenly and lineJustifyContentGap
				or 0

			local caretMainPosition = line[mainAxisPosition] + lineJustifyContentOffset + strokeWeightMainStart + paddingMainStart
			local caretCrossPosition = line[crossAxisPosition] + linesAlignItemsOffset + strokeWeightCrossStart + paddingCrossStart

			for i = 1, #line do
				local child = line[i]

				local childAlignSelf = child.alignSelf
				if childAlignSelf == AlignSelf.Auto then
					childAlignSelf = alignItems
				end

				local childComputedMainSize = child[mainAxisDimension]
				local childComputedCrossSize = child[crossAxisDimension]

				local childMainPosition = caretMainPosition
				local childCrossPosition = caretCrossPosition
					+ (
						childAlignSelf == AlignItems.Center and ((lineCrossSize - childComputedCrossSize) * 0.5)
						or childAlignSelf == AlignItems.FlexEnd and (lineCrossSize - childComputedCrossSize)
						or 0
					)

				childMainPosition = math_floor(childMainPosition + 0.5)
				childCrossPosition = math_floor(childCrossPosition + 0.5)

				child[mainAxisPosition] = childMainPosition
				child[crossAxisPosition] = childCrossPosition

				caretMainPosition = caretMainPosition + childComputedMainSize + gapMain + lineJustifyContentGap
			end
		end
	end

	node.computedWidth = math_floor((computedWidth or 0) + 0.5)
	node.computedHeight = math_floor((computedHeight or 0) + 0.5)

	if not forcedWidth then
		node.computedFlexBasis = parentIsMainAxisRow and node.computedWidth or node.computedFlexBasis
	end

	if not forcedHeight then
		node.computedFlexBasis = not parentIsMainAxisRow and node.computedHeight or node.computedFlexBasis
	end

	return true
end

--
-- Renderer
--

local RectangleShaderRaw = [[
float4 STROKE_WEIGHT;
float4 BORDER_RADIUS;
texture TEXTURE;
bool USING_TEXTURE;

SamplerState TEXTURE_SAMPLER {
  Texture = TEXTURE;
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Linear;
};

float fill(float signedDistance, float antialiasing, float blur) {
  return smoothstep(0.5 * antialiasing, -0.5 * antialiasing - blur, signedDistance);
}

float stroke(float signedDistance, float weight, float antialiasing, float blur) {
  return smoothstep((weight + antialiasing) * 0.5, (weight - antialiasing) * 0.5 - blur, abs(signedDistance));
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
  
  float4 strokeWeight = STROKE_WEIGHT * scaleFactor;
  bool hasStroke = any(strokeWeight);
  
  float4 borderRadius = BORDER_RADIUS * scaleFactor;
    
  float2 position = texcoord;
  float2 size = float2(1.0 / ((aspectRatio <= 1.0) ? aspectRatio : 1.0), (aspectRatio <= 1.0) ? 1.0 : aspectRatio) * 0.5 - strokeWeight.x * 0.5;

  float signedDistance = sdRectangle(position, size, borderRadius);
  float antialiasing = length(fwidth(position));

  float alpha = hasStroke ? stroke(signedDistance, strokeWeight.x, antialiasing, 0.0) : fill(signedDistance, antialiasing, 0.0);
  color.a *= alpha;

  color.rgb *= color.a;

  if (USING_TEXTURE)
    color *= tex2D(TEXTURE_SAMPLER, originalTexcoord);

  return color;
}

technique rectangle {
  pass p0 {
    SrcBlend = One;
    DestBlend = InvSrcAlpha;
    PixelShader = compile ps_2_a pixel();
  }
}
]]

local function renderer(node, parentRenderX, parentRenderY, parentVisualX, parentVisualY, parentForegroundColor)
	if not isNode(node) then
		return false
	end

	if not node.visible then
		return false
	end

	if not parentRenderX then
		parentRenderX = 0
	end
	if not parentRenderY then
		parentRenderY = 0
	end

	if not parentVisualX then
		parentVisualX = 0
	end
	if not parentVisualY then
		parentVisualY = 0
	end

	if not parentForegroundColor then
		parentForegroundColor = 0xffffffff
	end

	local computedWidth = node.computedWidth
	local computedHeight = node.computedHeight

	local minSize = math_min(computedWidth, computedHeight)

	node.renderWidth = computedWidth
	node.renderHeight = computedHeight

	local computedX = node.computedX
	local computedY = node.computedY

	local renderX = (parentRenderX or 0) + computedX
	local renderY = (parentRenderY or 0) + computedY

	node.renderX = renderX
	node.renderY = renderY

	local visualX = (parentVisualX or 0) + computedX
	local visualY = (parentVisualY or 0) + computedY

	local computedBorderTopLeftRadius = 0
	local computedBorderTopRightRadius = 0
	local computedBorderBottomLeftRadius = 0
	local computedBorderBottomRightRadius = 0

	if node.resolvedBorderRadiusUnit == Unit.Pixel then
		local computedBorderRadius = node.resolvedBorderRadiusValue
		computedBorderTopLeftRadius = computedBorderRadius
		computedBorderTopRightRadius = computedBorderRadius
		computedBorderBottomLeftRadius = computedBorderRadius
		computedBorderBottomRightRadius = computedBorderRadius
	elseif node.resolvedBorderRadiusUnit == Unit.Percentage then
		local computedBorderRadius = node.resolvedBorderRadiusValue * minSize
		computedBorderTopLeftRadius = computedBorderRadius
		computedBorderTopRightRadius = computedBorderRadius
		computedBorderBottomLeftRadius = computedBorderRadius
		computedBorderBottomRightRadius = computedBorderRadius
	end

	if node.resolvedBorderTopLeftRadiusUnit == Unit.Pixel then
		computedBorderTopLeftRadius = node.resolvedBorderTopLeftRadiusValue
	elseif node.resolvedBorderTopLeftRadiusUnit == Unit.Percentage then
		computedBorderTopLeftRadius = node.resolvedBorderTopLeftRadiusValue * minSize
	end

	if node.resolvedBorderTopRightRadiusUnit == Unit.Pixel then
		computedBorderTopRightRadius = node.resolvedBorderTopRightRadiusValue
	elseif node.resolvedBorderTopRightRadiusUnit == Unit.Percentage then
		computedBorderTopRightRadius = node.resolvedBorderTopRightRadiusValue * minSize
	end

	if node.resolvedBorderBottomLeftRadiusUnit == Unit.Pixel then
		computedBorderBottomLeftRadius = node.resolvedBorderBottomLeftRadiusValue
	elseif node.resolvedBorderBottomLeftRadiusUnit == Unit.Percentage then
		computedBorderBottomLeftRadius = node.resolvedBorderBottomLeftRadiusValue * minSize
	end

	if node.resolvedBorderBottomRightRadiusUnit == Unit.Pixel then
		computedBorderBottomRightRadius = node.resolvedBorderBottomRightRadiusValue
	elseif node.resolvedBorderBottomRightRadiusUnit == Unit.Percentage then
		computedBorderBottomRightRadius = node.resolvedBorderBottomRightRadiusValue * minSize
	end

	local backgroundColor = node.backgroundColor
	local hasBackground = getColorAlpha(backgroundColor)
	local backgroundShader = node.backgroundShader

	local computedStrokeLeftWeight = node.computedStrokeLeftWeight
	local computedStrokeTopWeight = node.computedStrokeTopWeight
	local computedStrokeRightWeight = node.computedStrokeRightWeight
	local computedStrokeBottomWeight = node.computedStrokeBottomWeight

	local strokeColor = node.strokeColor
	local hasStroke = (computedStrokeLeftWeight > 0 or computedStrokeTopWeight > 0 or computedStrokeRightWeight > 0 or computedStrokeBottomWeight > 0)
		and getColorAlpha(strokeColor) > 0
	local strokeShader = node.strokeShader

	local canvas = node.canvas
	local canvasShader = node.canvasShader

	if node.overflow ~= Overflow.None then
		if canvas == nil then
			canvas = dxCreateRenderTarget(computedWidth, computedHeight, true)
			node.canvas = canvas

			node.canvasWidth = computedWidth
			node.canvasHeight = computedHeight

			node.canvasDirty = true
		end

		if canvas and (node.canvasWidth ~= computedWidth or node.canvasHeight ~= computedHeight) then
			dxDestroyRenderTarget(canvas)
			node.canvas = dxCreateRenderTarget(computedWidth, computedHeight, true)

			node.canvasWidth = computedWidth
			node.canvasHeight = computedHeight

			node.canvasDirty = true
		end
	elseif canvas ~= nil then
		dxDestroyRenderTarget(canvas)

		canvas = nil
		node.canvas = canvas

		node.canvasWidth = 0
		node.canvasHeight = 0

		if isElement(canvasShader) then
			destroyElement(canvasShader)
		end

		canvasShader = nil
		node.canvasShader = canvasShader
	end

	if computedBorderTopLeftRadius > 0 or computedBorderTopRightRadius > 0 or computedBorderBottomLeftRadius > 0 or computedBorderBottomRightRadius > 0 then
		if hasBackground then
			if backgroundShader == nil then
				backgroundShader = dxCreateShader(RectangleShaderRaw)
				node.backgroundShader = backgroundShader
			end
		end

		if hasStroke then
			if strokeShader == nil then
				strokeShader = dxCreateShader(RectangleShaderRaw)
				node.strokeShader = strokeShader
			end
		end

		if canvas then
			if canvasShader == nil then
				canvasShader = dxCreateShader(RectangleShaderRaw)
				node.canvasShader = canvasShader

				dxSetShaderValue(canvasShader, "TEXTURE", canvas)
				dxSetShaderValue(canvasShader, "USING_TEXTURE", true)
			end
		end

		if
			computedBorderTopLeftRadius ~= node.previousComputedBorderTopLeftRadius
			or computedBorderTopRightRadius ~= node.previousComputedBorderTopRightRadius
			or computedBorderBottomLeftRadius ~= node.previousComputedBorderBottomLeftRadius
			or computedBorderBottomRightRadius ~= node.previousComputedBorderBottomRightRadius
		then
			node.previousComputedBorderTopLeftRadius = computedBorderTopLeftRadius
			node.previousComputedBorderTopRightRadius = computedBorderTopRightRadius
			node.previousComputedBorderBottomLeftRadius = computedBorderBottomLeftRadius
			node.previousComputedBorderBottomRightRadius = computedBorderBottomRightRadius

			if backgroundShader then
				dxSetShaderValue(
					backgroundShader,
					"BORDER_RADIUS",
					computedBorderTopLeftRadius,
					computedBorderTopRightRadius,
					computedBorderBottomLeftRadius,
					computedBorderBottomRightRadius
				)
			end

			if strokeShader then
				dxSetShaderValue(
					strokeShader,
					"BORDER_RADIUS",
					computedBorderTopLeftRadius,
					computedBorderTopRightRadius,
					computedBorderBottomLeftRadius,
					computedBorderBottomRightRadius
				)
			end

			if canvasShader then
				dxSetShaderValue(
					canvasShader,
					"BORDER_RADIUS",
					computedBorderTopLeftRadius,
					computedBorderTopRightRadius,
					computedBorderBottomLeftRadius,
					computedBorderBottomRightRadius
				)
			end
		end

		if
			computedStrokeLeftWeight ~= node.previousComputedStrokeLeftWeight
			or computedStrokeTopWeight ~= node.previousComputedStrokeTopWeight
			or computedStrokeRightWeight ~= node.previousComputedStrokeRightWeight
			or computedStrokeBottomWeight ~= node.previousComputedStrokeBottomWeight
		then
			node.previousComputedStrokeLeftWeight = computedStrokeLeftWeight
			node.previousComputedStrokeTopWeight = computedStrokeTopWeight
			node.previousComputedStrokeRightWeight = computedStrokeRightWeight
			node.previousComputedStrokeBottomWeight = computedStrokeBottomWeight

			if strokeShader then
				dxSetShaderValue(
					strokeShader,
					"STROKE_WEIGHT",
					computedStrokeLeftWeight,
					computedStrokeTopWeight,
					computedStrokeRightWeight,
					computedStrokeBottomWeight
				)
			end
		end
	else
		if backgroundShader ~= nil then
			if isElement(backgroundShader) then
				destroyElement(backgroundShader)
			end

			backgroundShader = nil
			node.backgroundShader = backgroundShader
		end

		if strokeShader ~= nil then
			if isElement(strokeShader) then
				destroyElement(strokeShader)
			end

			strokeShader = nil
			node.strokeShader = strokeShader
		end

		if canvasShader ~= nil then
			if isElement(canvasShader) then
				destroyElement(canvasShader)
			end

			canvasShader = nil
			node.canvasShader = canvasShader
		end
	end

	if hasBackground then
		if backgroundShader then
			dxDrawImage(visualX, visualY, computedWidth, computedHeight, backgroundShader, 0, 0, 0, backgroundColor)
		else
			dxDrawRectangle(visualX, visualY, computedWidth, computedHeight, backgroundColor)
		end
	end

	local foregroundColor = node.foregroundColor
	if not foregroundColor then
		foregroundColor = parentForegroundColor
	end

	if canvas then
		if node.canvasDirty then
			node.canvasDirty = false

			local previousRenderTarget = dxGetRenderTarget()
			dxSetRenderTarget(canvas, true)

			local dxPreviousBlendMode = dxGetBlendMode()
			local changedBlendMode = dxSetBlendMode(BlendMode.ModulateAdd)

			if node.draw and getColorAlpha(foregroundColor) > 0 then
				local computedPaddingLeft = node.computedPaddingLeft
				local computedPaddingTop = node.computedPaddingTop

				local innerWidth = computedWidth - computedStrokeLeftWeight - computedStrokeRightWeight - computedPaddingLeft - node.computedPaddingRight
				local innerHeight = computedHeight - computedStrokeTopWeight - computedStrokeBottomWeight - computedPaddingTop - node.computedPaddingBottom

				local innerX = visualX + computedStrokeLeftWeight + computedPaddingLeft
				local innerY = visualY + computedStrokeTopWeight + computedPaddingTop

				node:draw(innerX, innerY, innerWidth, innerHeight, foregroundColor)
			end

			local scrollLeft = -node.scrollLeft
			local scrollTop = -node.scrollTop

			local children = node.children
			local childCount = #children

			for i = 1, childCount do
				local child = children[i]

				local childComputedWidth = child.computedWidth
				local childComputedHeight = child.computedHeight

				local childComputedX = child.computedX + scrollLeft
				local childComputedY = child.computedY + scrollTop

				if
					childComputedX + childComputedWidth > 0
					and childComputedY + childComputedHeight > 0
					and childComputedX < computedWidth
					and childComputedY < computedHeight
				then
					renderer(children[i], renderX + scrollLeft, renderY + scrollTop, scrollLeft, scrollTop, foregroundColor)
				end
			end

			if node.overflow ~= Overflow.None and node.overflow ~= Overflow.Hidden then
				local computedOverflowX = node.computedOverflowX
				local computedOverflowY = node.computedOverflowY

				if computedOverflowY > 0 then
					local renderScrollbarWidth = node.scrollbarSize
					local renderScrollbarHeight = computedHeight

					node.renderVerticalScrollBarWidth = renderScrollbarWidth
					node.renderVerticalScrollBarHeight = renderScrollbarHeight

					local renderScrollbarX = renderX + computedWidth - renderScrollbarWidth
					local renderScrollbarY = renderY

					node.renderVerticalScrollBarX = renderScrollbarX
					node.renderVerticalScrollBarY = renderScrollbarY

					local visualScrollbarX = computedWidth - renderScrollbarWidth
					local visualScrollbarY = 0

					local renderScrollbarThumbWidth = node.scrollbarSize
					local renderScrollbarThumbHeight = node.computedVerticalScrollBarThumbSize

					node.renderVerticalScrollBarThumbWidth = renderScrollbarThumbWidth
					node.renderVerticalScrollBarThumbHeight = renderScrollbarThumbHeight

					local scrollbarThumbOffset = math_max(
						0,
						math_min(
							node.scrollTop / computedOverflowY * (renderScrollbarHeight - renderScrollbarThumbHeight),
							renderScrollbarHeight - renderScrollbarThumbHeight
						)
					)

					local renderScrollbarThumbX = renderScrollbarX
					local renderScrollbarThumbY = renderScrollbarY + scrollbarThumbOffset

					node.renderVerticalScrollBarThumbX = renderScrollbarThumbX
					node.renderVerticalScrollBarThumbY = renderScrollbarThumbY

					local visualScrollbarThumbX = visualScrollbarX
					local visualScrollbarThumbY = visualScrollbarY + scrollbarThumbOffset

					dxDrawRectangle(visualScrollbarX, visualScrollbarY, renderScrollbarWidth, renderScrollbarHeight, self.scrollBarTrackColor)
					dxDrawRectangle(
						visualScrollbarThumbX,
						visualScrollbarThumbY,
						renderScrollbarThumbWidth,
						renderScrollbarThumbHeight,
						self.scrollBarThumbColor
					)
				end

				if computedOverflowX > 0 then
					local renderScrollbarWidth = computedWidth - (computedOverflowY > 0 and node.scrollbarSize or 0)
					local renderScrollbarHeight = node.scrollbarSize

					node.renderHorizontalScrollBarWidth = renderScrollbarWidth
					node.renderHorizontalScrollBarHeight = renderScrollbarHeight

					local renderScrollbarX = renderX
					local renderScrollbarY = renderY + computedHeight - renderScrollbarHeight

					node.renderHorizontalScrollBarX = renderScrollbarX
					node.renderHorizontalScrollBarY = renderScrollbarY

					local visualScrollbarX = 0
					local visualScrollbarY = computedHeight - renderScrollbarHeight

					local renderScrollbarThumbWidth = node.computedHorizontalScrollBarThumbSize
					local renderScrollbarThumbHeight = node.scrollbarSize

					node.renderHorizontalScrollBarThumbWidth = renderScrollbarThumbWidth
					node.renderHorizontalScrollBarThumbHeight = renderScrollbarThumbHeight

					local scrollbarThumbOffset = math_max(
						0,
						math_min(
							node.scrollLeft / computedOverflowX * (renderScrollbarWidth - renderScrollbarThumbWidth),
							renderScrollbarWidth - renderScrollbarThumbWidth
						)
					)

					local renderScrollbarThumbX = renderScrollbarX + scrollbarThumbOffset
					local renderScrollbarThumbY = renderScrollbarY

					node.renderHorizontalScrollBarThumbX = renderScrollbarThumbX
					node.renderHorizontalScrollBarThumbY = renderScrollbarThumbY

					local visualScrollbarThumbX = visualScrollbarX + scrollbarThumbOffset
					local visualScrollbarThumbY = visualScrollbarY

					dxDrawRectangle(visualScrollbarX, visualScrollbarY, renderScrollbarWidth, renderScrollbarHeight, 0xff171717)
					dxDrawRectangle(visualScrollbarThumbX, visualScrollbarThumbY, renderScrollbarThumbWidth, renderScrollbarThumbHeight, 0xffffffff)
				end
			end

			if changedBlendMode then
				dxSetBlendMode(dxPreviousBlendMode)
			end

			dxSetRenderTarget(previousRenderTarget)
		end

		dxDrawImage(visualX, visualY, computedWidth, computedHeight, canvasShader or canvas)
	end

	if hasStroke then
		if strokeShader then
			dxDrawImage(visualX, visualY, computedWidth, computedHeight, strokeShader, 0, 0, 0, strokeColor)
		else
			dxDrawRectangle(visualX, visualY, computedStrokeLeftWeight, computedHeight, strokeColor)
			dxDrawRectangle(visualX, visualY, computedWidth, computedStrokeTopWeight, strokeColor)
			dxDrawRectangle(visualX + computedWidth - computedStrokeRightWeight, visualY, computedStrokeRightWeight, computedHeight, strokeColor)
			dxDrawRectangle(visualX, visualY + computedHeight - computedStrokeBottomWeight, computedWidth, computedStrokeBottomWeight, strokeColor)
		end
	end

	if not canvas then
		if node.draw and getColorAlpha(foregroundColor) > 0 then
			local computedPaddingLeft = node.computedPaddingLeft
			local computedPaddingTop = node.computedPaddingTop

			local innerWidth = computedWidth - computedStrokeLeftWeight - computedStrokeRightWeight - computedPaddingLeft - node.computedPaddingRight
			local innerHeight = computedHeight - computedStrokeTopWeight - computedStrokeBottomWeight - computedPaddingTop - node.computedPaddingBottom

			local innerX = visualX + computedStrokeLeftWeight + computedPaddingLeft
			local innerY = visualY + computedStrokeTopWeight + computedPaddingTop

			node:draw(innerX, innerY, innerWidth, innerHeight, foregroundColor)
		end

		local children = node.children
		local childCount = #children

		for i = 1, childCount do
			renderer(children[i], renderX, renderY, visualX, visualY, foregroundColor)
		end
	end

	return true
end

--
-- Tree
--

tree = Node()

addEventHandler("onClientRender", root, function()
	calculateLayout(tree)
end)

addEventHandler("onClientRender", root, function()
	renderer(tree)
end)

--
-- Cursor / Keyboard
--

local cursorShowing = false

local cursorX = -SCREEN_WIDTH
local cursorY = -SCREEN_HEIGHT

local hoveredNode = false
local clickedNode = false
local focusedNode = false

local hoveredHorizontalScrollBar = false
local hoveredVerticalScrollBar = false
local hoveredScrollbarAttachedTo

local draggingHorizontalScrollBar = false
local draggingVerticalScrollBar = false
local draggingScrollbarAttachedTo

local draggingScrollbarDeltaX = 0
local draggingScrollbarDeltaY = 0

function getHoveredNode(node)
	if not node.visible then
		return false
	end

	local renderWidth = node.renderWidth
	local renderHeight = node.renderHeight

	local renderX = node.renderX
	local renderY = node.renderY

	local hovered = node.hoverable and isPointInRectangle(cursorX, cursorY, renderX, renderY, renderWidth, renderHeight)

	if node.canvas and not hovered then
		return false
	end

	if hovered and (node.overflow ~= Overflow.None and node.overflow ~= Overflow.Hidden) then
		local hoveringHorizontalScrollbar = node.computedOverflowX > 0
			and isPointInRectangle(
				cursorX,
				cursorY,
				node.renderHorizontalScrollBarX,
				node.renderHorizontalScrollBarY,
				node.renderHorizontalScrollBarWidth,
				node.renderHorizontalScrollBarHeight
			)
		local hoveringVerticalScrollbar = node.computedOverflowY > 0
			and isPointInRectangle(
				cursorX,
				cursorY,
				node.renderVerticalScrollBarX,
				node.renderVerticalScrollBarY,
				node.renderVerticalScrollBarWidth,
				node.renderVerticalScrollBarHeight
			)

		if hoveringHorizontalScrollbar or hoveringVerticalScrollbar then
			return node, hoveringHorizontalScrollbar, hoveringVerticalScrollbar
		end
	end

	local computedWidth = node.computedWidth
	local computedHeight = node.computedHeight

	local scrollLeft = node.scrollLeft
	local scrollTop = node.scrollTop

	local children = node.children
	local childcount = #children

	for i = childcount, 1, -1 do
		local child = children[i]

		local childComputedWidth = child.computedWidth
		local childComputedHeight = child.computedHeight

		local childComputedX = child.computedX + scrollLeft
		local childComputedY = child.computedY + scrollTop

		if
			childComputedX + childComputedWidth > 0
			and childComputedY + childComputedHeight > 0
			and childComputedX < computedWidth
			and childComputedY < computedHeight
		then
			local hoveredChild, hoveringHorizontalScrollbar, hoveringVerticalScrollbar = getHoveredNode(child)

			if hoveredChild then
				return hoveredChild, hoveringHorizontalScrollbar, hoveringVerticalScrollbar
			end
		end
	end

	if not hovered then
		return false
	else
		dxDrawRectangle(renderX, renderY, renderWidth, renderHeight, 0x0f0088ff)
	end

	return node
end

addEventHandler("onClientRender", root, function()
	cursorShowing = isCursorShowing()

	if not cursorShowing then
		cursorX = -SCREEN_WIDTH
		cursorY = -SCREEN_HEIGHT

		return
	end

	local x, y = getCursorPosition()

	cursorX = x * SCREEN_WIDTH
	cursorY = y * SCREEN_HEIGHT

	local hoveringNode, hoveringHorizontalScrollbar, hoveringVerticalScrollbar = getHoveredNode(tree)

	if hoveringNode ~= hoveredNode then
		if hoveredNode and hoveredNode.onCursorLeave then
			hoveredNode:onCursorLeave(cursorX, cursorY)
		end

		hoveredNode = false

		if not hoveringHorizontalScrollbar and not hoveringVerticalScrollbar then
			hoveredNode = hoveringNode

			if hoveredNode and hoveredNode.onCursorEnter then
				hoveredNode:onCursorEnter(cursorX, cursorY)
			end
		end
	end

	hoveredHorizontalScrollBar = hoveringHorizontalScrollbar
	hoveredVerticalScrollBar = hoveringVerticalScrollbar
	hoveredScrollbarAttachedTo = (hoveredHorizontalScrollBar or hoveredVerticalScrollBar) and hoveredNode or nil

	if draggingScrollbarAttachedTo then
		draggingScrollbarAttachedTo:markCanvasDirty()

		if draggingHorizontalScrollBar then
			local movingX = cursorX - draggingScrollbarAttachedTo.renderHorizontalScrollBarX - draggingScrollbarDeltaX
			local computedOverflowX = draggingScrollbarAttachedTo.computedOverflowX

			local scrollLeft = movingX
				/ (draggingScrollbarAttachedTo.renderHorizontalScrollBarWidth - draggingScrollbarAttachedTo.renderHorizontalScrollBarThumbWidth)
				* computedOverflowX
			draggingScrollbarAttachedTo.scrollLeft = math_max(0, math_min(scrollLeft, computedOverflowX))
		elseif draggingVerticalScrollBar then
			local movingY = cursorY - draggingScrollbarAttachedTo.renderVerticalScrollBarY - draggingScrollbarDeltaY
			local computedOverflowY = draggingScrollbarAttachedTo.computedOverflowY

			local scrollTop = movingY
				/ (draggingScrollbarAttachedTo.renderVerticalScrollBarHeight - draggingScrollbarAttachedTo.renderVerticalScrollBarThumbHeight)
				* computedOverflowY
			draggingScrollbarAttachedTo.scrollTop = math_max(0, math_min(scrollTop, computedOverflowY))
		end
	end

	if hoveredNode or clickedNode then
		local node = hoveredNode or clickedNode

		if node.onCursorMove then
			node:onCursorMove(cursorX, cursorY)
		end
	end
end)

addEventHandler("onClientClick", root, function(button, state)
	local pressed = state == "down"

	if button == "left" then
		if pressed then
			if focusedNode and focusedNode ~= hoveredNode then
				if focusedNode.onBlur then
					focusedNode:onBlur()
				end

				focusedNode.focused = false
				focusedNode = false
			end

			if hoveredNode then
				if hoveredNode.clickable then
					if hoveredNode.onCursorDown then
						hoveredNode:onCursorDown(button, cursorX, cursorY)
					end

					clickedNode = hoveredNode
				end

				if hoveredNode.focusable then
					if hoveredNode.onFocus then
						hoveredNode:onFocus()
					end

					focusedNode = hoveredNode
					focusedNode.focused = true
				end
			end

			if hoveredScrollbarAttachedTo then
				local scrollbarThumbX = hoveredHorizontalScrollBar and hoveredScrollbarAttachedTo.renderHorizontalScrollBarThumbX
					or hoveredVerticalScrollBar and hoveredScrollbarAttachedTo.renderVerticalScrollBarThumbX
				local scrollbarThumbY = hoveredHorizontalScrollBar and hoveredScrollbarAttachedTo.renderHorizontalScrollBarThumbY
					or hoveredVerticalScrollBar and hoveredScrollbarAttachedTo.renderVerticalScrollBarThumbY

				if
					isPointInRectangle(
						cursorX,
						cursorY,
						scrollbarThumbX,
						scrollbarThumbY,
						hoveredHorizontalScrollBar and hoveredScrollbarAttachedTo.renderHorizontalScrollBarThumbWidth
							or hoveredVerticalScrollBar and hoveredScrollbarAttachedTo.renderVerticalScrollBarThumbWidth,
						hoveredHorizontalScrollBar and hoveredScrollbarAttachedTo.renderHorizontalScrollBarHeight
							or hoveredVerticalScrollBar and hoveredScrollbarAttachedTo.renderVerticalScrollBarHeight
					)
				then
					draggingHorizontalScrollBar = hoveredHorizontalScrollBar
					draggingVerticalScrollBar = hoveredVerticalScrollBar
					draggingScrollbarAttachedTo = hoveredScrollbarAttachedTo
					draggingScrollbarDeltaX = cursorX - scrollbarThumbX
					draggingScrollbarDeltaY = cursorY - scrollbarThumbY
				end
			end
		else
			if clickedNode then
				if clickedNode.onCursorUp then
					clickedNode:onCursorUp(button, cursorX, cursorY)
				end

				if clickedNode == hoveredNode and clickedNode.onCursorClick then
					clickedNode:onCursorClick(cursorX, cursorY)
				end

				clickedNode = false
			end

			if draggingScrollbarAttachedTo then
				draggingHorizontalScrollBar = false
				draggingVerticalScrollBar = false
				draggingScrollbarAttachedTo = nil
				draggingScrollbarDeltaX = 0
				draggingScrollbarDeltaY = 0
			end
		end
	end
end)

addEventHandler("onClientCharacter", root, function(character)
	if not focusedNode then
		return
	end

	if focusedNode.__input__ then
		focusedNode:insertText(character)
	end
end)

local keyTimer

local function keyPressed(key, pressed, rep)
	if isTimer(keyTimer) then
		killTimer(keyTimer)
	end

	if key == "backspace" then
		if not pressed then
			return
		end

		if focusedNode and focusedNode.__input__ then
			focusedNode:removeText(focusedNode.caretPosition - 1, focusedNode.caretPosition)
			keyTimer = setTimer(keyPressed, rep and 50 or 250, 1, key, pressed, true)
		end
	end
end
addEventHandler("onClientKey", root, keyPressed)
