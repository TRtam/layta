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

local dxGetTextWidth = dxGetTextWidth
local dxGetTextSize = dxGetTextSize
local dxGetFontHeight = dxGetFontHeight
local dxGetMaterialSize = dxGetMaterialSize

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
	ModulateAdd = "modulate_add",
	Overwrite = "overwrite",
}

local AlignX = {
	Left = "left",
	Center = "center",
	Right = "right",
}

local AlignY = {
	Top = "top",
	Center = "center",
	Bottom = "bottom",
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
-- Event
--

local Event = createClass()

function Event:constructor(name, options)
	if type(options) ~= "table" then
		options = { bubbles = false, cancelable = false }
	end

	self.name = name
	self.bubbles = type(options.bubbles) == "boolean" and options.bubbles or false
	self.cancelable = type(options.cancelable) == "boolean" and options.cancelable or false
	self.defaultPrevented = false
	self.propagationStopped = false
	self.immediatePropagationStopped = false
	self.target = false
	self.currentTarget = false
	self.eventPhase = 0
	self.timestamp = getRealTime().timestamp
	self.tick = getTickCount()
end

function Event:preventDefault()
	if self.cancelable then
		self.defaultPrevented = true
	end
end

function Event:stopPropagation()
	self.propagationStopped = true
end

function Event:stopImmediatePropagation()
	self.immediatePropagationStopped = true
end

function Event:getComposedPath()
	local composedPath = {}

	local target = self.target
	while target do
		table.insert(composedPath, target)
		target = target.parent
	end

	return composedPath
end

--
-- EventTarget
--

local EventTarget = createClass()

function EventTarget:constructor()
	self.eventListeners = {}
end

function EventTarget:addEventListener(name, listener, options)
	if type(options) ~= "table" then
		options = { capture = false }
	end

	if not self.eventListeners[name] then
		self.eventListeners[name] = {}
	end

	table.insert(self.eventListeners[name], 1, { listener = listener, capture = type(options.capture) == "boolean" and options.capture or false })

	return true
end

function EventTarget:removeEventListener(name, listener, options)
	if type(options) ~= "table" then
		options = { capture = false }
	end

	local eventListeners = self.eventListeners[name]

	if not eventListeners then
		return false
	end

	for i = #eventListeners, 1, -1 do
		local eventListener = eventListeners[i]

		if eventListener.listener == listener and (eventListener.capture == (type(options.capture) == "boolean" and options.capture or false)) then
			table.remove(eventListeners, i)
			return true
		end
	end

	return false
end

function EventTarget:invokeListeners(target, event, capture)
	if type(capture) ~= "boolean" then
		capture = false
	end

	local eventListeners = target.eventListeners[event.name]

	if not eventListeners then
		return
	end

	for i = 1, #eventListeners do
		local eventListener = eventListeners[i]

		if not event.immediatePropagationStopped and eventListener.capture == capture then
			eventListener.listener(event)
		end
	end
end

function EventTarget:dispatchEvent(event)
	event.target = self

	local composedPath = event:getComposedPath()
	event.eventPhase = 1

	for i = #composedPath, 1, -1 do
		if event.propagationStopped then
			return not event.defaultPrevented
		end

		local target = composedPath[i]
		event.currentTarget = target

		self:invokeListeners(target, event, true)
	end

	event.eventPhase = 2

	if not event.propagationStopped then
		event.currentTarget = self
		self:invokeListeners(self, event, false)
	end

	if event.bubbles and not event.propagationStopped then
		event.eventPhase = 3

		for i = 2, #composedPath do
			if event.propagationStopped then
				break
			end

			local target = composedPath[i]
			event.currentTarget = target

			self:invokeListeners(target, event, false)
		end
	end

	return not event.defaultPrevented
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

Node = createClass(EventTarget)
Node.__node__ = true

local function isNode(node)
	return type(node) == "table" and node.__node__ == true
end

function Node:constructor(attributes, ...)
	EventTarget.constructor(self)

	if type(attributes) ~= "table" then
		attributes = {}
	end

	--
	-- Node properties
	--

	self.parent = false
	self.index = -1
	self.children = {}

	self.hoverable = type(attributes.hoverable) ~= "boolean" and true or attributes.hoverable
	self.clickable = type(attributes.clickable) ~= "boolean" and true or attributes.clickable
	self.focusable = attributes.focusable or false

	--
	-- Dirty flags
	--

	self.layoutDirty = true
	self.canvasDirty = true

	--
	-- States
	--

	self.hovered = false
	self.clicked = false
	self.focused = false

	--
	-- Styles
	--

	self.id = false

	self.visible = true
	self.effectiveVisibility = true

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

	--
	-- Resolved styles
	--

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

	--
	-- Computed values
	--

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

	--
	-- Rendered values
	--

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

	--
	-- Direct Events
	--

	self.onCursorClick = attributes.onCursorClick
	self.onCursorDown = attributes.onCursorDown
	self.onCursorEnter = attributes.onCursorEnter
	self.onCursorLeave = attributes.onCursorLeave
	self.onCursorMove = attributes.onCursorMove
	self.onCursorUp = attributes.onCursorUp

	for i = 1, select("#", ...) do
		self:appendChild(select(i, ...))
	end

	self:setId(attributes.id)
	self:setVisible(attributes.visible)
end

function Node:destructor(...)
	local children = self.children
	local childCount = #children

	for i = childCount, 1, -1 do
		children[i]:destroy(...)
	end

	local parent = self.parent

	if parent then
		parent:removeChild(self)
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
	if id ~= false or (type(id) ~= "string" or utf8_len(id) == 0) then
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

function Node:setClicked(clicked)
	if type(clicked) ~= "boolean" then
		return false
	end

	if clicked == self.clicked then
		return false
	end

	self.clicked = clicked

	return true
end

function Node:setFocused(focused)
	if type(focused) ~= "boolean" then
		return false
	end

	if focused == self.focused then
		return false
	end

	self.focused = focused

	if self.__input__ then
		self:markViewDirty()
	end

	return true
end

function Node:setWidth(width)
	if width == self.width then
		return false
	end

	self.width = width
	self.resolvedWidthValue, self.resolvedWidthUnit = resolveLength(width)

	self:markLayoutDirty()
	self:markCanvasDirty()

	return true
end

function Node:setHeight(height)
	if height == self.height then
		return false
	end

	self.height = height
	self.resolvedWidthValue, self.resolvedWidthUnit = resolveLength(height)

	self:markLayoutDirty()
	self:markCanvasDirty()

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

	--
	-- Styles
	--

	self.text = attributes.text or ""

	self.textSize = attributes.textSize or 1
	self.font = attributes.font or "default"

	self.alignX = attributes.alignX or "left"
	self.alignY = attributes.alignY or "top"

	self.clip = attributes.clip or false
	self.wordWrap = attributes.wordWrap or false
	self.colorCoded = attributes.colorCoded or false

	--
	-- Computed values
	--

	self.computedTextWidth = 0
	self.computedTextHeight = 0

	Node.constructor(self, attributes)
end

function Text:measure(availableWidth, availableHeight)
	local textSize = self.textSize
	local font = self.font

	local textWidth, textHeight = dxGetTextSize(self.text, availableWidth or 0, textSize, font, self.wordWrap, self.colorCoded)
	textHeight = math_max(textHeight, dxGetFontHeight(textSize, font))

	self.computedTextWidth = textWidth
	self.computedTextHeight = textHeight

	return textWidth, textHeight
end

function Text:draw(x, y, width, height, color)
	local text = self.text

	if utf8_len(text) == 0 then
		return
	end

	dxDrawText(text, x, y, x + width, y + height, color, self.textSize, self.font, self.alignX, self.alignY, self.clip, self.wordWrap, false, self.colorCoded)
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

	--
	-- Styles
	--

	self.material = isMaterial(attributes.material) and attributes.material or false

	--
	-- Computed values
	--

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
		attributes = {}
	end

	if attributes.backgroundColor == nil then
		attributes.backgroundColor = WHITE
	end

	if attributes.foregroundColor == nil then
		attributes.foregroundColor = BLACK
	end

	if attributes.padding == nil then
		attributes.padding = 2
	end

	attributes.focusable = true

	--
	-- Node properties
	--

	self.caretIndex = 0
	self.selectIndex = 0

	self.viewScroll = 0
	self.updateViewScroll = false

	--
	-- Dirty flags
	--

	self.viewDirty = true

	--
	-- Styles
	--

	self.caretWidth = attributes.caretWidth or 1
	self.caretColor = attributes.caretColor or BLACK

	self.selectColor = attributes.selectColor or 0x7f0000ff

	self.text = ""
	self.textLength = 0

	self.textSize = attributes.textSize or 1
	self.font = attributes.font or "default"

	self.alignX = attributes.alignX or "left"
	self.alignY = attributes.alignY or "center"

	--
	-- Computed values
	--

	self.viewWidth = 0
	self.viewHeight = 0

	self.computedTextWidth = 0
	self.computedTextHeight = 0

	Node.constructor(self, attributes)

	self:setText(attributes.text)
end

function Input:setCaretIndex(caretIndex, selecting)
	if type(caretIndex) ~= "number" then
		return false
	end

	if type(selecting) ~= "boolean" then
		selecting = false
	end

	local text = self.text
	local textLength = self.textLength

	self.caretIndex = math_max(0, math_min(caretIndex, textLength))

	if not selecting then
		self.selectIndex = self.caretIndex
	end

	self.updateViewScroll = true
	self:markViewDirty()
	self:markCanvasDirty()

	return true
end

function Input:moveCaretIndex(amount, selecting)
	if type(amount) ~= "number" then
		return false
	end

	if type(selection) ~= "boolean" then
		selecting = false
	end

	local caretIndex = self.caretIndex

	if not selecting and caretIndex ~= self.selectIndex then
		self:setCaretIndex(amount > 0 and math_max(caretIndex, self.selectIndex) or math_min(caretIndex, self.selectIndex))
	else
		self:setCaretIndex(caretIndex + amount, selecting)
	end

	return true
end

function Input:getCaretIndexByCursor(cursorX)
	local alignX = self.alignX

	local computedTextWidth = self.computedTextWidth
	local textX = alignX == AlignX.Right and self.renderWidth - computedTextWidth
		or alignX == AlignX.Center and (self.renderWidth - computedTextWidth) * 0.5
		or 0

	cursorX = cursorX - self.renderX - textX - self.viewScroll

	local textLength = self.textLength

	if textLength == 0 then
		return 0
	end

	if cursorX <= 0 then
		return 0
	elseif cursorX >= self.computedTextWidth then
		return textLength
	end

	local text = self.text

	local caretIndex = 0

	local left = 0
	local right = textLength

	while left <= right do
		local mid = math_floor((left + right) * 0.5)
		local widthToMid = dxGetTextWidth(utf8_sub(text, 1, mid))

		if widthToMid <= cursorX then
			caretIndex = mid
			left = mid + 1
		else
			right = mid - 1
		end
	end

	if caretIndex < textLength then
		local widthBefore = dxGetTextWidth(utf8_sub(text, 1, caretIndex))
		local widthNext = dxGetTextWidth(utf8_sub(text, 1, caretIndex + 1))
		local midPoint = (widthBefore + widthNext) * 0.5

		if cursorX >= midPoint then
			caretIndex = caretIndex + 1
		end
	end

	return caretIndex
end

function Input:setText(text)
	if type(text) ~= "string" then
		return false
	end

	if text == self.text then
		return false
	end

	self.text = text
	self.textLength = utf8_len(text)

	self:setCaretIndex(self.textLength)

	return true
end

function Input:insertText(text)
	if type(text) ~= "string" then
		return false
	end

	if utf8_len(text) == 0 then
		return false
	end

	local caretIndex = self.caretIndex
	local selectIndex = self.selectIndex

	local from, to = math_min(caretIndex, selectIndex), math_max(caretIndex, selectIndex)
	from, to = math_max(0, from), math_min(self.textLength, to)

	local previousText = self.text
	self.text = utf8_sub(previousText, 1, from) .. text .. utf8_sub(previousText, to + 1)
	self.textLength = utf8_len(self.text)

	self:markLayoutDirty()

	self:setCaretIndex(from + utf8_len(text))

	return true
end

function Input:removeText(from, to)
	from, to = math_min(from, to), math_max(from, to)
	from, to = math_max(0, from), math_min(self.textLength, to)

	local caretIndex = self.caretIndex

	local previousText = self.text
	self.text = utf8_sub(previousText, 1, from) .. utf8_sub(previousText, to + 1)
	self.textLength = utf8_len(self.text)

	self:markLayoutDirty()

	self:setCaretIndex(from)

	return true
end

function Input:measure()
	local textSize = self.textSize
	local font = self.font

	local textWidth, textHeight = dxGetTextSize(self.text, availableWidth or 0, textSize, font, self.wordWrap, self.colorCoded)
	textHeight = math_max(textHeight, dxGetFontHeight(textSize, font))

	self.computedTextWidth = textWidth
	self.computedTextHeight = textHeight

	return 200, textHeight
end

function Input:markViewDirty()
	if self.viewDirty then
		return false
	end

	self.viewDirty = true

	self:markCanvasDirty()

	return true
end

function Input:draw(x, y, width, height, foregroundColor)
	local view = self.view

	if view == nil then
		view = dxCreateRenderTarget(width, height, true)
		self.view = view

		self.viewWidth = width
		self.viewHeight = height

		self.viewDirty = true
	end

	if view and (self.viewWidth ~= width or self.viewHeight ~= height) then
		dxDestroyRenderTarget(view)
		view = dxCreateRenderTarget(width, height, true)
		self.view = view

		self.viewWidth = width
		self.viewHeight = height

		self.viewDirty = true
	end

	if view then
		if self.viewDirty then
			self.viewDirty = false

			local viewScroll = self.viewScroll

			local text = self.text
			local textSize = self.textSize

			local font = self.font

			local alignX = self.alignX
			local alignY = self.alignY

			local caretIndex = self.caretIndex

			local selectIndex = self.selectIndex
			local selectWidth = 0

			if caretIndex ~= selectIndex then
				if selectIndex > caretIndex then
					selectWidth = dxGetTextWidth(utf8_sub(text, caretIndex + 1, selectIndex), textSize, font)
				else
					selectWidth = -dxGetTextWidth(utf8_sub(text, selectIndex + 1, caretIndex), textSize, font)
				end
			end

			local caretPosition = dxGetTextWidth(utf8_sub(text, 1, caretIndex), textSize, font)

			local textWidth = self.computedTextWidth
			local textX = alignX == AlignX.Right and width - textWidth or alignX == AlignX.Center and (width - textWidth) * 0.5 or 0

			if self.updateViewScroll then
				self.updateViewScroll = false

				local offset = textX + viewScroll + caretPosition

				if offset <= 0 then
					viewScroll = -caretPosition - textX
				elseif offset >= width then
					viewScroll = width - caretPosition - textX
				end

				self.viewScroll = viewScroll
			end

			local previousRenderTarget = dxGetRenderTarget()
			dxSetRenderTarget(view, true)

			local dxPreviousBlendMode = dxGetBlendMode()
			local changedBlendMode = dxSetBlendMode(BlendMode.ModulateAdd)

			if selectWidth ~= 0 then
				local selectX = textX + caretPosition + viewScroll
				local selectY = (height - self.computedTextHeight) * 0.5

				dxDrawRectangle(selectX, selectY, selectWidth, self.computedTextHeight, self.selectColor)
			end

			if utf8_len(text) > 0 then
				dxDrawText(text, textX + viewScroll, 0, width, height, foregroundColor, textSize, font, AlignX.Left, alignY)
			end

			if self.focused then
				local caretX = textX + caretPosition + viewScroll
				local caretY = (height - self.computedTextHeight) * 0.5

				dxDrawRectangle(caretX, caretY, self.caretWidth, self.computedTextHeight, self.caretColor)
			end

			if changedBlendMode then
				dxSetBlendMode(dxPreviousBlendMode)
			end

			dxSetRenderTarget(previousRenderTarget)
		end

		dxDrawImage(x, y, width, height, self.view)
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
	local absoluteItems

	local hasPrevSiblingVisible = false

	for i = 1, childCount do
		local child = children[i]

		while true do
			if not child.visible then
				break
			end

			if child.position == Position.Absolute then
				local childAvailableWidth = isMainAxisRow and containerMainSize or not isMainAxisRow and containerCrossSize or nil
				local childAvailableHeight = isMainAxisRow and containerCrossSize or not isMainAxisRow and containerMainSize or nil

				calculateLayout(child, childAvailableWidth, childAvailableHeight, isMainAxisRow, stretchItems)

				if not doingSecondPass then
					if not absoluteItems then
						absoluteItems = {}
					end

					table.insert(absoluteItems, child)
				end

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
	if node == nil then
		node = tree
	end

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
		if
			node.cachedAvailableWidth == availableWidth
			and node.cachedAvailableHeight == availableHeight
			and node.cachedParentIsMainAxisRow == parentIsMainAxisRow
			and node.cachedParentStretchItems == parentStretchItems
			and node.cachedForcedWidth == forcedWidth
			and node.cachedForcedHeight == forcedHeight
		then
			return false
		end
	end

	node.layoutDirty = false

	node.cachedAvailableWidth = availableWidth
	node.cachedAvailableHeight = availableHeight
	node.cachedParentIsMainAxisRow = parentIsMainAxisRow
	node.cachedParentStretchItems = parentStretchItems
	node.cachedForcedWidth = forcedWidth
	node.cachedForcedHeight = forcedHeight

	if node.resolvedLeftUnit == Unit.Auto then
		node.computedLeft = 0
	elseif node.resolvedLeftUnit == Unit.Pixel then
		node.computedLeft = node.resolvedLeftValue
	elseif node.resolvedLeftUnit == Unit.Percentage then
		node.computedLeft = node.resolvedLeftValue * (availableWidth or 0)
	end

	if node.resolvedTopUnit == Unit.Auto then
		node.computedTop = 0
	elseif node.resolvedTopUnit == Unit.Pixel then
		node.computedTop = node.resolvedTopValue
	elseif node.resolvedTopUnit == Unit.Percentage then
		node.computedTop = node.resolvedTopValue * (availableWidth or 0)
	end

	if node.resolvedRightUnit == Unit.Auto then
		node.computedRight = 0
	elseif node.resolvedRightUnit == Unit.Pixel then
		node.computedRight = node.resolvedRightValue
	elseif node.resolvedRightUnit == Unit.Percentage then
		node.computedRight = node.resolvedRightValue * (availableWidth or 0)
	end

	if node.resolvedBottomUnit == Unit.Auto then
		node.computedBottom = 0
	elseif node.resolvedBottomUnit == Unit.Pixel then
		node.computedBottom = node.resolvedBottomValue
	elseif node.resolvedBottomUnit == Unit.Percentage then
		node.computedBottom = node.resolvedBottomValue * (availableWidth or 0)
	end

	local flexDirection = node.flexDirection
	local isMainAxisRow = flexDirection == FlexDirection.Row

	local mainAxisDimension = isMainAxisRow and "computedWidth" or "computedHeight"
	local mainAxisPosition = isMainAxisRow and "computedX" or "computedY"

	local crossAxisDimension = isMainAxisRow and "computedHeight" or "computedWidth"
	local crossAxisPosition = isMainAxisRow and "computedY" or "computedX"

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

	local computedStrokeLeftWeight = node.computedStrokeLeftWeight
	local computedStrokeTopWeight = node.computedStrokeTopWeight
	local computedStrokeRightWeight = node.computedStrokeRightWeight
	local computedStrokeBottomWeight = node.computedStrokeBottomWeight

	local strokeWeightMainStart = isMainAxisRow and computedStrokeLeftWeight or computedStrokeTopWeight
	local strokeWeightMainEnd = isMainAxisRow and computedStrokeRightWeight or computedStrokeBottomWeight

	local strokeWeightCrossStart = isMainAxisRow and computedStrokeTopWeight or computedStrokeLeftWeight
	local strokeWeightCrossEnd = isMainAxisRow and computedStrokeBottomWeight or computedStrokeRightWeight

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

		local computedColumnGap = node.computedColumnGap
		local computedRowGap = node.computedRowGap

		local gapMain = isMainAxisRow and computedColumnGap or computedRowGap
		local gapCross = isMainAxisRow and computedRowGap or computedColumnGap

		local lines, mainMaxLineSize, crossTotalLinesSize, secondPassItems, thirdPassItems, absoluteItems = splitChildren(
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

				-- child.layoutDirty = true

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

				-- child.layoutDirty = true

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
				node.computedVerticalScrollBarThumbSize = math_max(node.computedVerticalScrollBarThumbSize, 30)
			end
			if overflowX > 0 then
				node.computedHorizontalScrollBarThumbSize = isMainAxisRow
						and (containerMainInnerSize / (containerMainInnerSize + overflowX) * containerMainInnerSize)
					or (containerCrossInnerSize / (containerCrossInnerSize + overflowX) * containerCrossInnerSize)
				node.computedHorizontalScrollBarThumbSize = math_max(node.computedHorizontalScrollBarThumbSize, 30)
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

				local childComputedWidth = isMainAxisRow and childComputedMainSize or childComputedCrossSize
				local childComputedHeight = isMainAxisRow and childComputedCrossSize or childComputedMainSize

				local childComputedX = isMainAxisRow and childMainPosition or childCrossPosition
				local childComputedY = isMainAxisRow and childCrossPosition or childMainPosition

				local hasLeft = child.resolvedLeftUnit ~= Unit.Auto
				local hasRight = child.resolvedRightUnit ~= Unit.Auto

				local hasTop = child.resolvedTopUnit ~= Unit.Auto
				local hasBottom = child.resolvedBottomUnit ~= Unit.Auto

				if (hasLeft and hasRight) or hasLeft then
					childComputedX = childComputedX + child.computedLeft
				elseif hasRight then
					childComputedX = childComputedX - child.computedRight
				end

				if (hasTop and hasBottom) or hasTop then
					childComputedY = childComputedY + child.computedTop
				elseif hasBottom then
					childComputedY = childComputedY - child.computedBottom
				end

				childComputedX = math_floor(childComputedX + 0.5)
				childComputedY = math_floor(childComputedY + 0.5)

				child.computedX = childComputedX
				child.computedY = childComputedY

				caretMainPosition = caretMainPosition + childComputedMainSize + gapMain + lineJustifyContentGap
			end
		end

		if absoluteItems then
			for i = 1, #absoluteItems do
				local child = absoluteItems[i]

				local childComputedWidth = child.computedWidth
				local childComputedHeight = child.computedHeight

				local childComputedX = justifyContent == JustifyContent.FlexEnd and computedWidth - childComputedWidth
					or justifyContent == JustifyContent.Center and (computedWidth - childComputedWidth) * 0.5
					or 0
				local childComputedY = alignItems == AlignItems.FlexEnd and computedHeight - childComputedHeight
					or alignItems == AlignItems.Center and (computedHeight - childComputedHeight) * 0.5
					or 0

				local hasLeft = child.resolvedLeftUnit ~= Unit.Auto
				local hasRight = child.resolvedRightUnit ~= Unit.Auto

				local hasTop = child.resolvedTopUnit ~= Unit.Auto
				local hasBottom = child.resolvedBottomUnit ~= Unit.Auto

				if (hasLeft and hasRight) or hasLeft then
					childComputedX = child.computedLeft
				elseif hasRight then
					childComputedX = computedWidth - childComputedWidth - child.computedRight
				end

				if (hasTop and hasBottom) or hasTop then
					childComputedY = child.computedTop
				elseif hasBottom then
					childComputedY = computedHeight - childComputedHeight - child.computedBottom
				end

				child.computedX = math.floor(childComputedX + 0.5)
				child.computedY = math.floor(childComputedY + 0.5)
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
	if node == nil then
		node = tree
	end

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
	local hasBackground = getColorAlpha(backgroundColor) > 0
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

			canvas = dxCreateRenderTarget(computedWidth, computedHeight, true)
			node.canvas = canvas

			node.canvasWidth = computedWidth
			node.canvasHeight = computedHeight

			node.canvasDirty = true

			if isMaterial(canvasShader) then
				dxSetShaderValue(canvasShader, "TEXTURE", canvas)
			end
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
					local renderScrollBarWidth = node.scrollBarSize
					local renderScrollBarHeight = computedHeight

					node.renderVerticalScrollBarWidth = renderScrollBarWidth
					node.renderVerticalScrollBarHeight = renderScrollBarHeight

					local renderScrollBarX = renderX + computedWidth - renderScrollBarWidth
					local renderScrollBarY = renderY

					node.renderVerticalScrollBarX = renderScrollBarX
					node.renderVerticalScrollBarY = renderScrollBarY

					local visualScrollBarX = computedWidth - renderScrollBarWidth
					local visualScrollBarY = 0

					local renderScrollBarThumbWidth = node.scrollBarSize
					local renderScrollBarThumbHeight = node.computedVerticalScrollBarThumbSize

					node.renderVerticalScrollBarThumbWidth = renderScrollBarThumbWidth
					node.renderVerticalScrollBarThumbHeight = renderScrollBarThumbHeight

					local scrollBarThumbOffset = math_max(
						0,
						math_min(
							node.scrollTop / computedOverflowY * (renderScrollBarHeight - renderScrollBarThumbHeight),
							renderScrollBarHeight - renderScrollBarThumbHeight
						)
					)

					local renderScrollBarThumbX = renderScrollBarX
					local renderScrollBarThumbY = renderScrollBarY + scrollBarThumbOffset

					node.renderVerticalScrollBarThumbX = renderScrollBarThumbX
					node.renderVerticalScrollBarThumbY = renderScrollBarThumbY

					local visualScrollBarThumbX = visualScrollBarX
					local visualScrollBarThumbY = visualScrollBarY + scrollBarThumbOffset

					dxDrawRectangle(visualScrollBarX, visualScrollBarY, renderScrollBarWidth, renderScrollBarHeight, node.scrollBarTrackColor)
					dxDrawRectangle(
						visualScrollBarThumbX,
						visualScrollBarThumbY,
						renderScrollBarThumbWidth,
						renderScrollBarThumbHeight,
						node.scrollBarThumbColor
					)
				end

				if computedOverflowX > 0 then
					local renderScrollBarWidth = computedWidth - (computedOverflowY > 0 and node.scrollBarSize or 0)
					local renderScrollBarHeight = node.scrollBarSize

					node.renderHorizontalScrollBarWidth = renderScrollBarWidth
					node.renderHorizontalScrollBarHeight = renderScrollBarHeight

					local renderScrollBarX = renderX
					local renderScrollBarY = renderY + computedHeight - renderScrollBarHeight

					node.renderHorizontalScrollBarX = renderScrollBarX
					node.renderHorizontalScrollBarY = renderScrollBarY

					local visualScrollBarX = 0
					local visualScrollBarY = computedHeight - renderScrollBarHeight

					local renderScrollBarThumbWidth = node.computedHorizontalScrollBarThumbSize
					local renderScrollBarThumbHeight = node.scrollBarSize

					node.renderHorizontalScrollBarThumbWidth = renderScrollBarThumbWidth
					node.renderHorizontalScrollBarThumbHeight = renderScrollBarThumbHeight

					local scrollBarThumbOffset = math_max(
						0,
						math_min(
							node.scrollLeft / computedOverflowX * (renderScrollBarWidth - renderScrollBarThumbWidth),
							renderScrollBarWidth - renderScrollBarThumbWidth
						)
					)

					local renderScrollBarThumbX = renderScrollBarX + scrollBarThumbOffset
					local renderScrollBarThumbY = renderScrollBarY

					node.renderHorizontalScrollBarThumbX = renderScrollBarThumbX
					node.renderHorizontalScrollBarThumbY = renderScrollBarThumbY

					local visualScrollBarThumbX = visualScrollBarX + scrollBarThumbOffset
					local visualScrollBarThumbY = visualScrollBarY

					dxDrawRectangle(visualScrollBarX, visualScrollBarY, renderScrollBarWidth, renderScrollBarHeight, node.scrollBarTrackColor)
					dxDrawRectangle(
						visualScrollBarThumbX,
						visualScrollBarThumbY,
						renderScrollBarThumbWidth,
						renderScrollBarThumbHeight,
						node.scrollBarThumbColor
					)
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

		local scrollLeft = node.scrollLeft
		local scrollTop = node.scrollTop

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
				renderer(child, renderX, renderY, visualX, visualY, foregroundColor)
			end
		end
	end

	return true
end

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
local hoveredScrollBarAttachedTo

local draggingHorizontalScrollBar = false
local draggingVerticalScrollBar = false
local draggingScrollBarAttachedTo

local draggingScrollBarDeltaX = 0
local draggingScrollBarDeltaY = 0

local function getHoveredNode(node)
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
		local hoveringHorizontalScrollBar = node.computedOverflowX > 0
			and isPointInRectangle(
				cursorX,
				cursorY,
				node.renderHorizontalScrollBarX,
				node.renderHorizontalScrollBarY,
				node.renderHorizontalScrollBarWidth,
				node.renderHorizontalScrollBarHeight
			)
		local hoveringVerticalScrollBar = node.computedOverflowY > 0
			and isPointInRectangle(
				cursorX,
				cursorY,
				node.renderVerticalScrollBarX,
				node.renderVerticalScrollBarY,
				node.renderVerticalScrollBarWidth,
				node.renderVerticalScrollBarHeight
			)

		if hoveringHorizontalScrollBar or hoveringVerticalScrollBar then
			return node, hoveringHorizontalScrollBar, hoveringVerticalScrollBar
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
			local hoveredChild, hoveringHorizontalScrollBar, hoveringVerticalScrollBar = getHoveredNode(child)

			if hoveredChild then
				return hoveredChild, hoveringHorizontalScrollBar, hoveringVerticalScrollBar
			end
		end
	end

	if not hovered then
		return false
	end

	return node
end

local function cursor()
	cursorShowing = isCursorShowing()

	if not cursorShowing then
		cursorX = -SCREEN_WIDTH
		cursorY = -SCREEN_HEIGHT

		return
	end

	local x, y = getCursorPosition()

	cursorX = x * SCREEN_WIDTH
	cursorY = y * SCREEN_HEIGHT

	local hoveringNode, hoveringHorizontalScrollBar, hoveringVerticalScrollBar = getHoveredNode(tree)

	if hoveringNode ~= hoveredNode then
		if hoveredNode and hoveredNode.onCursorLeave then
			hoveredNode:onCursorLeave(cursorX, cursorY)
		end

		hoveredNode = false

		if not hoveringHorizontalScrollBar and not hoveringVerticalScrollBar then
			hoveredNode = hoveringNode

			if hoveredNode and hoveredNode.onCursorEnter then
				hoveredNode:onCursorEnter(cursorX, cursorY)
			end
		end
	end

	hoveredHorizontalScrollBar = hoveringHorizontalScrollBar
	hoveredVerticalScrollBar = hoveringVerticalScrollBar
	hoveredScrollBarAttachedTo = (hoveredHorizontalScrollBar or hoveredVerticalScrollBar) and hoveringNode or nil

	if draggingScrollBarAttachedTo then
		draggingScrollBarAttachedTo:markCanvasDirty()

		if draggingHorizontalScrollBar then
			local movingX = cursorX - draggingScrollBarAttachedTo.renderHorizontalScrollBarX - draggingScrollBarDeltaX
			local computedOverflowX = draggingScrollBarAttachedTo.computedOverflowX

			local scrollLeft = movingX
				/ (draggingScrollBarAttachedTo.renderHorizontalScrollBarWidth - draggingScrollBarAttachedTo.renderHorizontalScrollBarThumbWidth)
				* computedOverflowX
			draggingScrollBarAttachedTo.scrollLeft = math_max(0, math_min(scrollLeft, computedOverflowX))
		elseif draggingVerticalScrollBar then
			local movingY = cursorY - draggingScrollBarAttachedTo.renderVerticalScrollBarY - draggingScrollBarDeltaY
			local computedOverflowY = draggingScrollBarAttachedTo.computedOverflowY

			local scrollTop = movingY
				/ (draggingScrollBarAttachedTo.renderVerticalScrollBarHeight - draggingScrollBarAttachedTo.renderVerticalScrollBarThumbHeight)
				* computedOverflowY
			draggingScrollBarAttachedTo.scrollTop = math_max(0, math_min(scrollTop, computedOverflowY))
		end
	end

	if hoveredNode or clickedNode then
		local movingNode = hoveredNode or clickedNode

		if movingNode.onCursorMove then
			movingNode:onCursorMove(cursorX, cursorY)
		end

		if clickedNode and clickedNode.__input__ then
			clickedNode:setCaretIndex(clickedNode:getCaretIndexByCursor(cursorX), true)
		end
	end
end

local function onClick(button, state)
	local pressed = state == "down"

	if button == "left" then
		if pressed then
			if focusedNode and focusedNode ~= hoveredNode then
				if focusedNode.onBlur then
					focusedNode:onBlur()
				end

				focusedNode:setFocused(false)
				focusedNode = false
			end

			if hoveredNode then
				if hoveredNode.clickable then
					if hoveredNode.onCursorDown then
						hoveredNode:onCursorDown(button, cursorX, cursorY)
					end

					clickedNode = hoveredNode

					if clickedNode.__input__ then
						clickedNode:setCaretIndex(clickedNode:getCaretIndexByCursor(cursorX))
					end

					local cursordown = Event("cursordown")
					cursordown.cursorX = cursorX
					cursordown.cursorY = cursorY

					clickedNode:dispatchEvent(cursordown)
				end

				if hoveredNode.focusable then
					if hoveredNode.onFocus then
						hoveredNode:onFocus()
					end

					focusedNode = hoveredNode
					focusedNode:setFocused(true)
				end
			end

			if hoveredScrollBarAttachedTo then
				local scrollBarThumbX = hoveredHorizontalScrollBar and hoveredScrollBarAttachedTo.renderHorizontalScrollBarThumbX
					or hoveredVerticalScrollBar and hoveredScrollBarAttachedTo.renderVerticalScrollBarThumbX
				local scrollBarThumbY = hoveredHorizontalScrollBar and hoveredScrollBarAttachedTo.renderHorizontalScrollBarThumbY
					or hoveredVerticalScrollBar and hoveredScrollBarAttachedTo.renderVerticalScrollBarThumbY

				if
					isPointInRectangle(
						cursorX,
						cursorY,
						scrollBarThumbX,
						scrollBarThumbY,
						hoveredHorizontalScrollBar and hoveredScrollBarAttachedTo.renderHorizontalScrollBarThumbWidth
							or hoveredVerticalScrollBar and hoveredScrollBarAttachedTo.renderVerticalScrollBarThumbWidth,
						hoveredHorizontalScrollBar and hoveredScrollBarAttachedTo.renderHorizontalScrollBarThumbHeight
							or hoveredVerticalScrollBar and hoveredScrollBarAttachedTo.renderVerticalScrollBarThumbHeight
					)
				then
					draggingHorizontalScrollBar = hoveredHorizontalScrollBar
					draggingVerticalScrollBar = hoveredVerticalScrollBar
					draggingScrollBarAttachedTo = hoveredScrollBarAttachedTo
					draggingScrollBarDeltaX = cursorX - scrollBarThumbX
					draggingScrollBarDeltaY = cursorY - scrollBarThumbY
				end
			end
		else
			if clickedNode then
				if clickedNode.onCursorUp then
					clickedNode:onCursorUp(button, cursorX, cursorY)
				end

				local cursorup = Event("cursorup")
				cursorup.cursorX = cursorX
				cursorup.cursorY = cursorY

				clickedNode:dispatchEvent(cursorup)

				if clickedNode == hoveredNode and clickedNode.onCursorClick then
					clickedNode:onCursorClick(cursorX, cursorY)

					local cursorclick = Event("cursorclick")
					cursorclick.cursorX = cursorX
					cursorclick.cursorY = cursorY

					clickedNode:dispatchEvent(cursorclick)
				end

				clickedNode = false
			end

			if draggingScrollBarAttachedTo then
				draggingHorizontalScrollBar = false
				draggingVerticalScrollBar = false
				draggingScrollBarAttachedTo = nil
				draggingScrollBarDeltaX = 0
				draggingScrollBarDeltaY = 0
			end
		end
	end
end

local function onCharacter(character)
	if not focusedNode then
		return
	end

	if focusedNode.__input__ then
		focusedNode:insertText(character)
	end
end

local keyTimer

local function onKeyPressed(key, pressed, rep)
	if isTimer(keyTimer) then
		killTimer(keyTimer)
	end

	if key == "backspace" then
		if not pressed then
			return
		end

		if focusedNode and focusedNode.__input__ then
			focusedNode:removeText(focusedNode.caretIndex - 1, focusedNode.caretIndex)
			keyTimer = setTimer(onKeyPressed, rep and 50 or 250, 1, key, pressed, true)
		end
	end
end

--
-- Tree
--

tree = Node({ width = SCREEN_WIDTH, height = SCREEN_HEIGHT, alignItems = AlignItems.FlexStart })

--
-- Initializer / Finalizer
--

function initialize()
	addEventHandler("onClientRender", root, calculateLayout)
	addEventHandler("onClientRender", root, renderer)
	addEventHandler("onClientRender", root, cursor)
	addEventHandler("onClientClick", root, onClick)
	addEventHandler("onClientCharacter", root, onCharacter)
	addEventHandler("onClientKey", root, onKeyPressed)
end

function finalize()
	removeEventHandler("onClientRender", root, calculateLayout)
	removeEventHandler("onClientRender", root, renderer)
	removeEventHandler("onClientRender", root, cursor)
	removeEventHandler("onClientClick", root, onClick)
	removeEventHandler("onClientCharacter", root, onCharacter)
	removeEventHandler("onClientKey", root, onKeyPressed)
end
