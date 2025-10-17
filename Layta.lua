Layta = {}

Layta.screenWidth, Layta.screenHeight = guiGetScreenSize()
Layta.screenScale = Layta.screenHeight / 1080

local function createClass(super)
	return setmetatable({
		destroy = function(object)
			if type(object.destructor) == "function" then
				object:destructor()
			end

			setmetatable(object, nil)
		end,
	}, {
		__call = function(class, ...)
			local object = setmetatable({}, { __index = class })

			if type(object.constructor) == "function" then
				object:constructor(...)
			end

			return object
		end,
		__index = function(_, key)
			return super and super[key]
		end,
	})
end

local function createProxy(original, onChanged)
	return setmetatable({}, {
		__index = function(_, key)
			return original[key]
		end,
		__newindex = function(_, key, value)
			local previous = original[key]

			if value ~= previous then
				original[key] = value

				if type(onChanged) == "function" then
					onChanged(key, value)
				end
			end
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
			return value * 0.01 * Layta.screenWidth, "pixel"
		elseif unit == "sh" then
			return value * 0.01 * Layta.screenHeight, "pixel"
		elseif unit == "sc" then
			return value * Layta.screenScale, "pixel"
		end
	else
		return 0, "auto"
	end
end

local function createStyle()
	return {
		display = "flex",
		flexDirection = "row",
		flexWrap = "nowrap",
		justifyContent = "flex-start",
		alignContent = "flex-start",
		alignItems = "stretch",
		alignSelf = "auto",
		flexGrow = 0,
		flexShrink = 0,
		gap = "auto",
		columnGap = "auto",
		rowGap = "auto",
		padding = "auto",
		paddingLeft = "auto",
		paddingTop = "auto",
		paddingRight = "auto",
		paddingBottom = "auto",
		width = "auto",
		height = "auto",
		borderRadius = 0,
		borderTopLeftRadius = "auto",
		borderTopRightRadius = "auto",
		borderBottomLeftRadius = "auto",
		borderBottomRightRadius = "auto",
		backgroundColor = 0x00ffffff,
		strokeColor = 0xff000000,
		strokeWeight = 1,
		strokeLeftWeight = "auto",
		strokeTopWeight = "auto",
		strokeRightWeight = "auto",
		strokeBottomWeight = "auto",
	}
end

Layta.Node = createClass()

function Layta.Node:constructor(attributes)
	self.parent = false
	self.index = false
	self.children = {}
	self.dirty = true
	self.resolvedStyling = {
		flexGrow = { value = 0, unit = "pixel" },
		flexShrink = { value = 0, unit = "pixel" },
		gap = { value = 0, unit = "auto" },
		columnGap = { value = 0, unit = "auto" },
		rowGap = { value = 0, unit = "auto" },
		padding = { value = 0, unit = "auto" },
		paddingLeft = { value = 0, unit = "auto" },
		paddingTop = { value = 0, unit = "auto" },
		paddingRight = { value = 0, unit = "auto" },
		paddingBottom = { value = 0, unit = "auto" },
		width = { value = 0, unit = "auto" },
		height = { value = 0, unit = "auto" },
		borderRadius = { value = 0, unit = "auto" },
		borderTopLeftRadius = { value = 0, unit = "auto" },
		borderTopRightRadius = { value = 0, unit = "auto" },
		borderBottomLeftRadius = { value = 0, unit = "auto" },
		borderBottomRightRadius = { value = 0, unit = "auto" },
		strokeWeight = { value = 1, unit = "pixel" },
		strokeLeftWeight = { value = 0, unit = "auto" },
		strokeTopWeight = { value = 0, unit = "auto" },
		strokeRightWeight = { value = 0, unit = "auto" },
		strokeBottomWeight = { value = 0, unit = "auto" },
	}
	self.__style = createStyle()
	self.style = createProxy(self.__style, function(key, value)
		local resolvedStyle = self.resolvedStyling[key]
		if resolvedStyle then
			resolvedStyle.value, resolvedStyle.unit = resolveLength(value)
		end
		self:markDirty()
	end)
	self.computedLayout = { width = 0, height = 0, x = 0, y = 0, flexContainerMainSize = 0, flexContainerCrossSize = 0 }
	self.render = {}
	if attributes then
		for key, value in pairs(attributes) do
			if key ~= "id" and key ~= "children" then
				self.style[key] = value
			end
		end
		local children = attributes.children
		if children then
			for i = 1, #children do
				self:appendChild(children[i])
			end
		end
	end
end

function Layta.Node:destructor() end

function Layta.Node:appendChild(child)
	if child.parent == self then
		return false
	end

	if child.parent then
		child.parent:removeChild(child)
	end

	table.insert(self.children, child)

	child.parent = self
	child.index = #self.children
	child.dirty = true

	self:markDirty()

	return true
end

function Layta.Node:removeChild(child)
	if child.parent ~= self then
		return false
	end

	table.remove(self.children, child.index)
	self:reIndexChildren(child.index)

	child.parent = false
	child.index = false

	self:markDirty()

	return true
end

function Layta.Node:reIndexChildren(startAt)
	local children = self.children

	for i = (startAt or 1), #children do
		children[i].index = i
	end
end

function Layta.Node:markDirty()
	if self.dirty then
		return false
	end

	self.dirty = true

	if self.parent then
		self.parent:markDirty()
	end

	return true
end

local function flexSplitChildrenIntoLines(
	node,
	flexIsMainAxisRow,
	flexMainAxisDimension,
	flexMainAxisPosition,
	flexCrossAxisDimension,
	flexCrossAxisPosition,
	flexPaddingMainStart,
	flexPaddingCrossStart,
	flexContainerMainSizeDefined,
	flexContainerMainSizeChanged,
	flexContainerMainInnerSize,
	flexContainerCrossSizeDefined,
	flexContainerCrossSizeChanged,
	flexContainerCrossInnerSize,
	flexCanWrap,
	flexStretchChildren,
	flexMainGap,
	flexCrossGap,
	children,
	childCount,
	doingSecondPass,
	doingThirdPass
)
	local flexLines = {
		{
			children = {},
			[flexMainAxisDimension] = 0,
			[flexCrossAxisDimension] = 0,
			[flexMainAxisPosition] = flexPaddingMainStart,
			[flexCrossAxisPosition] = flexPaddingCrossStart,
			remainingFreeSpace = 0,
			totalFlexGrowFactor = 0,
			totalFlexShrinkScaledFactor = 0,
		},
	}
	local flexCurrentLine = flexLines[1]

	local flexLinesMainMaximumSize = 0
	local flexLinesCrossTotalSize = 0

	local flexSecondPassChildren
	local flexThirdPassChildren

	for i = 1, childCount do
		local child = children[i]

		local childResolvedStyling = child.resolvedStyling
		local childResolvedMainSize = childResolvedStyling[flexMainAxisDimension]
		local childResolvedCrossSize = childResolvedStyling[flexCrossAxisDimension]

		if not doingSecondPass then
			if
				(
					childResolvedMainSize.unit == "auto"
					or childResolvedMainSize.unit == "fit-content"
					or childResolvedMainSize.unit == "pixel"
					or childResolvedMainSize.unit == "percentage"
						and flexContainerMainSizeDefined
						and not flexContainerMainSizeChanged
				)
				and (
					childResolvedCrossSize.unit == "auto"
					or childResolvedCrossSize.unit == "fit-content"
					or childResolvedCrossSize.unit == "pixel"
					or childResolvedCrossSize.unit == "percentage"
						and flexContainerCrossSizeDefined
						and not flexContainerCrossSizeChanged
				)
			then
				local availableWidth = flexIsMainAxisRow and flexContainerMainSizeDefined and flexContainerMainInnerSize
					or not flexIsMainAxisRow and flexContainerCrossSizeDefined and flexContainerCrossInnerSize
					or nil
				local availableHeight = flexIsMainAxisRow
						and flexContainerCrossSizeDefined
						and flexContainerCrossInnerSize
					or not flexIsMainAxisRow and flexContainerMainSizeDefined and flexContainerMainInnerSize
					or nil

				Layta.computeLayout(
					child,
					availableWidth,
					availableHeight,
					nil,
					nil,
					flexIsMainAxisRow,
					flexStretchChildren
				)
			else
				child.dirty = true

				if not flexSecondPassChildren then
					flexSecondPassChildren = {}
				end

				table.insert(flexSecondPassChildren, child)
			end
		end

		local childComputedLayout = child.computedLayout
		local childComputedMainSize = childComputedLayout[flexMainAxisDimension]
		local childComputedCrossSize = childComputedLayout[flexCrossAxisDimension]

		if
			flexCanWrap
			and #flexCurrentLine.children > 0
			and flexCurrentLine[flexMainAxisDimension] + flexMainGap + childComputedMainSize
				> flexContainerMainInnerSize
		then
			local flexPreviousLine = flexCurrentLine

			flexCurrentLine = {
				children = {},
				[flexMainAxisDimension] = 0,
				[flexCrossAxisDimension] = 0,
				[flexMainAxisPosition] = flexPaddingMainStart,
				[flexCrossAxisPosition] = flexPreviousLine[flexCrossAxisPosition]
					+ flexPreviousLine[flexCrossAxisDimension]
					+ flexCrossGap,
				remainingFreeSpace = 0,
				totalFlexGrowFactor = 0,
				totalFlexShrinkScaledFactor = 0,
			}

			table.insert(flexLines, flexCurrentLine)
		end

		table.insert(flexCurrentLine.children, child)

		flexCurrentLine[flexMainAxisDimension] = flexCurrentLine[flexMainAxisDimension]
			+ (#flexCurrentLine.children > 0 and i < childCount and flexMainGap or 0)
			+ childComputedMainSize
		flexCurrentLine[flexCrossAxisDimension] =
			math.max(flexCurrentLine[flexCrossAxisDimension], childComputedCrossSize)
		flexCurrentLine.remainingFreeSpace = flexContainerMainInnerSize - flexCurrentLine[flexMainAxisDimension]

		flexLinesMainMaximumSize = math.max(
			flexLinesMainMaximumSize,
			flexCurrentLine[flexMainAxisPosition] + flexCurrentLine[flexMainAxisDimension]
		)
		flexLinesCrossTotalSize = math.max(
			flexLinesCrossTotalSize,
			flexCurrentLine[flexCrossAxisPosition] + flexCurrentLine[flexCrossAxisDimension]
		)

		if not doingThirdPass then
			local childComputedFlexGrow = childResolvedStyling.flexGrow.value
			local childComputedFlexShrink = childResolvedStyling.flexShrink.value

			flexCurrentLine.totalFlexGrowFactor = flexCurrentLine.totalFlexGrowFactor + childComputedFlexGrow
			flexCurrentLine.totalFlexShrinkScaledFactor = flexCurrentLine.totalFlexShrinkScaledFactor
				+ childComputedFlexShrink * childComputedMainSize

			if childComputedFlexGrow > 0 or childComputedFlexShrink > 0 then
				if not flexThirdPassChildren then
					flexThirdPassChildren = {}
				end

				table.insert(flexThirdPassChildren, child)
				flexThirdPassChildren[child] = flexCurrentLine
			end
		end
	end

	return flexLines, flexLinesMainMaximumSize, flexLinesCrossTotalSize, flexSecondPassChildren, flexThirdPassChildren
end

function Layta.computeLayout(
	node,
	availableWidth,
	availableHeight,
	forcedWidth,
	forcedHeight,
	parentFlexIsMainAxisRow,
	parentFlexStretchItems
)
	if not node.dirty then
		return false
	end

	node.dirty = false

	local computedLayout = node.computedLayout
	local computedWidth
	local computedHeight

	local resolvedStyling = node.resolvedStyling
	local resolvedWidth = resolvedStyling.width
	local resolvedHeight = resolvedStyling.height

	local measuredWidth
	local measuredHeight

	if forcedWidth then
		computedWidth = forcedWidth
	elseif measuredWidth then
		computedWidth = measuredWidth
	elseif resolvedWidth.unit == "pixel" then
		computedWidth = resolvedWidth.value
	elseif resolvedWidth.unit == "percentage" and availableWidth then
		computedWidth = resolvedWidth.value * availableWidth
	elseif resolvedWidth.unit == "auto" and not parentFlexIsMainAxisRow and parentFlexStretchItems then
		computedWidth = availableWidth
	end

	if forcedHeight then
		computedHeight = forcedHeight
	elseif measuredHeight then
		computedHeight = measuredHeight
	elseif resolvedHeight.unit == "pixel" then
		computedHeight = resolvedHeight.value
	elseif resolvedHeight.unit == "percentage" and availableHeight then
		computedHeight = resolvedHeight.value * availableHeight
	elseif resolvedHeight.unit == "auto" and parentFlexIsMainAxisRow and parentFlexStretchItems then
		computedHeight = availableHeight
	end

	local resolvedPadding = resolvedStyling.padding
	local resolvedPaddingLeft = resolvedStyling.paddingLeft
	local resolvedPaddingTop = resolvedStyling.paddingTop
	local resolvedPaddingRight = resolvedStyling.paddingRight
	local resolvedPaddingBottom = resolvedStyling.paddingBottom

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

	if resolvedPaddingLeft.unit == "pixel" then
		computedPaddingLeft = resolvedPaddingLeft.value
	end

	if resolvedPaddingTop.unit == "pixel" then
		computedPaddingTop = resolvedPaddingTop.value
	end

	if resolvedPaddingRight.unit == "pixel" then
		computedPaddingRight = resolvedPaddingRight.value
	end

	if resolvedPaddingBottom.unit == "pixel" then
		computedPaddingBottom = resolvedPaddingBottom.value
	end

	local style = node.style
	local styleDisplay = style.display

	if styleDisplay == "flex" then
		local flexDirection = style.flexDirection

		local flexIsMainAxisRow = flexDirection == "row" or flexDirection == "row-reverse"
		local flexMainAxisDimension = flexIsMainAxisRow and "width" or "height"
		local flexMainAxisPosition = flexIsMainAxisRow and "x" or "y"
		local flexCrossAxisDimension = flexIsMainAxisRow and "height" or "width"
		local flexCrossAxisPosition = flexIsMainAxisRow and "y" or "x"

		local flexPaddingMainStart = flexIsMainAxisRow and computedPaddingLeft or computedPaddingTop
		local flexPaddingMainEnd = flexIsMainAxisRow and computedPaddingRight or computedPaddingBottom
		local flexPaddingCrossStart = flexIsMainAxisRow and computedPaddingTop or computedPaddingLeft
		local flexPaddingCrossEnd = flexIsMainAxisRow and computedPaddingBottom or computedPaddingRight

		local flexContainerMainPreviousSize = computedLayout.flexContainerMainSize
		local flexContainerMainSize = flexIsMainAxisRow and computedWidth
			or not flexIsMainAxisRow and computedHeight
			or nil
		local flexContainerMainSizeDefined = flexContainerMainSize ~= nil
		local flexContainerMainInnerSize =
			math.max((flexContainerMainSize or 0) - flexPaddingMainStart - flexPaddingMainEnd, 0)

		local flexContainerCrossPreviousSize = computedLayout.flexContainerCrossSize
		local flexContainerCrossSize = flexIsMainAxisRow and computedHeight
			or not flexIsMainAxisRow and computedWidth
			or nil
		local flexContainerCrossSizeDefined = flexContainerCrossSize ~= nil
		local flexContainerCrossInnerSize =
			math.max((flexContainerCrossSize or 0) - flexPaddingCrossStart - flexPaddingCrossEnd, 0)

		local flexWrap = style.flexWrap
		local flexCanWrap = flexWrap ~= "nowrap" and flexContainerMainSizeDefined

		local flexJustifyContent = style.justifyContent

		local flexAlignItems = style.alignItems
		local flexStretchChildren = flexAlignItems == "stretch"

		local resolvedGap = resolvedStyling.gap
		local resolvedColumnGap = resolvedStyling.columnGap
		local resolvedRowGap = resolvedStyling.rowGap

		local computedColumnGap = 0
		local computedRowGap = 0

		if resolvedGap.unit == "pixel" then
			local computedGap = resolvedGap.value
			computedColumnGap = computedGap
			computedRowGap = computedGap
		end

		if resolvedColumnGap.unit == "pixel" then
			computedColumnGap = resolvedColumnGap.value
		end

		if resolvedRowGap.unit == "pixel" then
			computedRowGap = resolvedRowGap.value
		end

		local flexMainGap = flexIsMainAxisRow and computedColumnGap or computedRowGap
		local flexCrossGap = flexIsMainAxisRow and computedRowGap or computedColumnGap

		local children = node.children
		local childCount = #children

		if childCount > 0 then
			local flexLines, flexLinesMainMaximumSize, flexLinesCrossTotalSize, flexSecondPassChildren, flexThirdPassChildren =
				flexSplitChildrenIntoLines(
					node,
					flexIsMainAxisRow,
					flexMainAxisDimension,
					flexMainAxisPosition,
					flexCrossAxisDimension,
					flexCrossAxisPosition,
					flexPaddingMainStart,
					flexPaddingCrossStart,
					flexContainerMainSizeDefined,
					flexContainerMainSize ~= flexContainerMainPreviousSize,
					flexContainerMainInnerSize,
					flexContainerCrossSizeDefined,
					flexContainerCrossSize ~= flexContainerCrossPreviousSize,
					flexContainerCrossInnerSize,
					flexCanWrap,
					flexStretchChildren,
					flexMainGap,
					flexCrossGap,
					children,
					childCount,
					false,
					false
				)

			local flexResolvedMainSize = flexIsMainAxisRow and resolvedWidth or resolvedHeight
			local flexResolvedCrossSize = flexIsMainAxisRow and resolvedHeight or resolvedWidth

			if
				not flexContainerMainSizeDefined
				and (flexResolvedMainSize.unit == "auto" or flexResolvedMainSize.unit == "fit-content")
			then
				computedWidth = flexIsMainAxisRow and (flexLinesMainMaximumSize + flexPaddingMainEnd) or computedWidth
				computedHeight = not flexIsMainAxisRow and (flexLinesMainMaximumSize + flexPaddingMainEnd)
					or computedHeight
				flexContainerMainSize = flexIsMainAxisRow and computedWidth or computedHeight
				flexContainerMainSizeDefined = true
				flexContainerMainInnerSize = flexLinesMainMaximumSize - flexPaddingMainStart
			end

			if
				not flexContainerCrossSizeDefined
				and (flexResolvedCrossSize.unit == "auto" or flexResolvedCrossSize.unit == "fit-content")
			then
				computedWidth = not flexIsMainAxisRow and (flexLinesCrossTotalSize + flexPaddingCrossEnd)
					or computedWidth
				computedHeight = flexIsMainAxisRow and (flexLinesCrossTotalSize + flexPaddingCrossEnd) or computedHeight
				flexContainerCrossSize = flexIsMainAxisRow and computedHeight or computedWidth
				flexContainerCrossSizeDefined = true
				flexContainerMainSize = flexLinesCrossTotalSize - flexPaddingCrossStart
			end

			if flexSecondPassChildren then
				for i = 1, #flexSecondPassChildren do
					local child = flexSecondPassChildren[i]

					local availableWidth = flexIsMainAxisRow and flexContainerMainInnerSize
						or flexContainerCrossInnerSize
					local availableHeight = flexIsMainAxisRow and flexContainerCrossInnerSize
						or flexContainerMainInnerSize

					Layta.computeLayout(
						child,
						availableWidth,
						availableHeight,
						nil,
						nil,
						flexIsMainAxisRow,
						flexStretchChildren
					)
				end

				flexLines, flexLinesMainMaximumSize, flexLinesCrossTotalSize, _, flexThirdPassChildren =
					flexSplitChildrenIntoLines(
						node,
						flexIsMainAxisRow,
						flexMainAxisDimension,
						flexMainAxisPosition,
						flexCrossAxisDimension,
						flexCrossAxisPosition,
						flexPaddingMainStart,
						flexPaddingCrossStart,
						flexContainerMainSizeDefined,
						flexContainerMainSize ~= flexContainerMainPreviousSize,
						flexContainerMainInnerSize,
						flexContainerCrossSizeDefined,
						flexContainerCrossSize ~= flexContainerCrossPreviousSize,
						flexContainerCrossInnerSize,
						flexCanWrap,
						flexStretchChildren,
						flexMainGap,
						flexCrossGap,
						children,
						childCount,
						true,
						false
					)
			end

			if flexThirdPassChildren then
				for i = 1, #flexThirdPassChildren do
					local child = flexThirdPassChildren[i]

					child.dirty = true

					local flexCurrentLine = flexThirdPassChildren[child]
					local flexCurrentLineRemainingFreeSpace = flexCurrentLine.remainingFreeSpace

					if flexCurrentLineRemainingFreeSpace > 0 then
						local childResolvedStyling = child.resolvedStyling

						local childComputedFlexShrink = childResolvedStyling.flexShrink.value
						local childComputedLayout = child.computedLayout
						local childComputedMainSize = childComputedLayout[flexMainAxisDimension]
						local childComputedCrossSize = childComputedLayout[flexCrossAxisDimension]

						local flexGrowShrink = (childComputedFlexShrink / flexCurrentLine.totalFlexShrinkScaledFactor)
							* flexCurrentLineRemainingFreeSpace

						local forcedWidth = flexIsMainAxisRow and (childComputedMainSize + flexGrowShrink)
							or childComputedCrossSize
						local forcedHeight = not flexIsMainAxisRow and (childComputedMainSize + flexGrowShrink)
							or childComputedCrossSize

						Layta.computeLayout(
							child,
							nil,
							nil,
							forcedWidth,
							forcedHeight,
							flexIsMainAxisRow,
							flexStretchChildren
						)
					elseif flexCurrentLineRemainingFreeSpace < 0 then
						local childResolvedStyling = child.resolvedStyling

						local childComputedFlexShrink = childResolvedStyling.flexShrink.value
						local childComputedLayout = child.computedLayout
						local childComputedMainSize = childComputedLayout[flexMainAxisDimension]
						local childComputedCrossSize = childComputedLayout[flexCrossAxisDimension]

						local flexShrinkAmount = childComputedMainSize
							* (childComputedFlexShrink / flexCurrentLine.totalFlexShrinkScaledFactor)
							* -flexCurrentLineRemainingFreeSpace

						local forcedWidth = flexIsMainAxisRow and (childComputedMainSize - flexShrinkAmount)
							or childComputedCrossSize
						local forcedHeight = not flexIsMainAxisRow and (childComputedMainSize - flexShrinkAmount)
							or childComputedCrossSize

						Layta.computeLayout(
							child,
							nil,
							nil,
							forcedWidth,
							forcedHeight,
							flexIsMainAxisRow,
							flexStretchChildren
						)
					end
				end

				flexLines = flexSplitChildrenIntoLines(
					node,
					flexIsMainAxisRow,
					flexMainAxisDimension,
					flexMainAxisPosition,
					flexCrossAxisDimension,
					flexCrossAxisPosition,
					flexPaddingMainStart,
					flexPaddingCrossStart,
					flexContainerMainSizeDefined,
					flexContainerMainSize ~= flexContainerMainPreviousSize,
					flexContainerMainInnerSize,
					flexContainerCrossSizeDefined,
					flexContainerCrossSize ~= flexContainerCrossPreviousSize,
					flexContainerCrossInnerSize,
					flexCanWrap,
					flexStretchChildren,
					flexMainGap,
					flexCrossGap,
					children,
					childCount,
					true,
					true
				)
			end

			local flexLinesAlignItemsOffset = flexAlignItems == "center"
					and (flexContainerCrossInnerSize - flexLinesCrossTotalSize) * 0.5
				or flexAlignItems == "flex-end" and flexContainerCrossInnerSize - flexLinesCrossTotalSize
				or 0

			for i = 1, #flexLines do
				local flexCurrentLine = flexLines[i]

				local flexCurrentLineChildren = flexCurrentLine.children
				local flexCurrentLineChildCount = #flexCurrentLineChildren
				local flexCurrentLineCrossSize = flexCurrentLine[flexCrossAxisDimension]
				local flexCurrentLineRemainingFreeSpace = flexCurrentLine.remainingFreeSpace

				local flexCurrentLineJustifyContentGap = flexJustifyContent == "space-between"
						and flexCurrentLineChildCount > 1
						and flexCurrentLineRemainingFreeSpace / (flexCurrentLineChildCount - 1)
					or flexJustifyContent == "space-around" and flexCurrentLineRemainingFreeSpace / flexCurrentLineChildCount
					or flexJustifyContent == "space-evenly" and flexCurrentLineRemainingFreeSpace / (flexCurrentLineChildCount + 1)
					or 0

				local flexCurrentLineJustifyContentOffset = flexJustifyContent == "center"
						and flexCurrentLineRemainingFreeSpace * 0.5
					or flexJustifyContent == "flex-end" and flexCurrentLineRemainingFreeSpace
					or flexJustifyContent == "space-between" and 0
					or flexJustifyContent == "space-around" and flexCurrentLineJustifyContentGap * 0.5
					or flexJustifyContent == "space-evenly" and flexCurrentLineJustifyContentGap
					or 0

				local flexCurrentLineCaretMainPosition = flexCurrentLine[flexMainAxisPosition]
					+ flexCurrentLineJustifyContentOffset
				local flexCurrentLineCaretCrossPosition = flexCurrentLine[flexCrossAxisPosition]
					+ flexLinesAlignItemsOffset

				for j = 1, flexCurrentLineChildCount do
					local child = flexCurrentLineChildren[j]

					local childStyle = child.__style
					local childStyleAlignSelf = childStyle.self_align
					if childStyleAlignSelf == "auto" then
						childStyleAlignSelf = flexAlignItems
					end

					local childComputedLayout = child.computedLayout
					local childComputedCrossSize = childComputedLayout[flexCrossAxisDimension]

					local childCrossOffset = childStyleAlignSelf == "center"
							and (flexCurrentLineCrossSize - childComputedCrossSize) * 0.5
						or childStyleAlignSelf == "flex-end" and flexCurrentLineCrossSize - childComputedCrossSize
						or 0

					childComputedLayout[flexMainAxisPosition] = math.floor(flexCurrentLineCaretMainPosition)
					childComputedLayout[flexCrossAxisPosition] =
						math.floor(flexCurrentLineCaretCrossPosition + childCrossOffset)

					flexCurrentLineCaretMainPosition = flexCurrentLineCaretMainPosition
						+ (j > 0 and j < flexCurrentLineChildCount and flexMainGap or 0)
						+ flexCurrentLineJustifyContentGap
						+ childComputedLayout[flexMainAxisDimension]
				end
			end

			computedLayout.flexContainerMainSize = flexContainerMainSize
			computedLayout.flexContainerCrossSize = flexContainerCrossSize
		end
	end

	computedLayout.width = math.ceil(computedWidth or 0)
	computedLayout.height = math.ceil(computedHeight or 0)

	return true
end

local rectangleShaderRaw = [[
	float4 BORDER_RADIUS;
	float4 STROKE_WEIGHT;

	float fill(float sdf, float aa, float blur)
	{
		return smoothstep(0.5 * aa, -0.5 * aa - blur, sdf);
	}

	float stroke(float sdf, float weight, float aa, float blur)
	{
		return smoothstep((weight + aa) * 0.5, (weight - aa) * 0.5 - blur, abs(sdf));
	}

	float sdRectangle(float2 position, float2 size, float4 borderRadius)
	{
		borderRadius.xy = (position.x > 0.0) ? borderRadius.xy : borderRadius.zw;
		borderRadius.x = (position.y > 0.0) ? borderRadius.y : borderRadius.x;

		float2 q = abs(position) - size + borderRadius.x;
		return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - borderRadius.x;
	}

	float4 pixel(float2 texcoord: TEXCOORD0, float4 color: COLOR0): COLOR0
	{
		texcoord -= 0.5;

		float2 dx = ddx(texcoord);
		float2 dy = ddy(texcoord);
		float2 resolution = float2(length(float2(dx.x, dy.x)), length(float2(dx.y, dy.y)));

		float aspectRatio = resolution.x / resolution.y;
  	float scaleFactor = (aspectRatio <= 1.0) ? resolution.y : resolution.x;

		if (aspectRatio <= 1.0)
		{
			texcoord.x /= aspectRatio;
		}
		else
		{
			texcoord.y *= aspectRatio;	
		}

		float4 borderRadius = BORDER_RADIUS * scaleFactor;
		float4 strokeWeight = STROKE_WEIGHT * scaleFactor;

		float2 position = texcoord;
		float2 size = float2(1.0 / ((aspectRatio <= 1.0) ? aspectRatio : 1.0), (aspectRatio <= 1.0) ? 1.0 : aspectRatio) * 0.5 - strokeWeight.x * 0.5;

		float sdf = sdRectangle(position, size, borderRadius);
		float aa = length(fwidth(position));

		float alpha = any(strokeWeight) ? stroke(sdf, strokeWeight.x, aa, 0.0) : fill(sdf, aa, 0.0);
		color.a *= alpha;

		return color;
	}

	technique rectangle
	{
		pass p0
		{
			SeparateAlphaBlendEnable = true;
			SrcBlendAlpha = One;
			DestBlendAlpha = InvSrcAlpha;
			PixelShader = compile ps_2_a pixel();
		}
	}
]]

local function getColorAlpha(color)
	return math.floor(color / 0x1000000) % 0x100
end

function Layta.renderer(node, px, py)
	local computedLayout = node.computedLayout

	local computedWidth = computedLayout.width
	local computedHeight = computedLayout.height

	local x = px + computedLayout.x
	local y = py + computedLayout.y

	local resolvedStyling = node.resolvedStyling

	local resolvedBorderRadius = resolvedStyling.borderRadius
	local resolvedBorderTopLeftRadius = resolvedStyling.borderTopLeftRadius
	local resolvedBorderTopRightRadius = resolvedStyling.borderTopRightRadius
	local resolvedBorderBottomLeftRadius = resolvedStyling.borderBottomLeftRadius
	local resolvedBorderBottomRightRadius = resolvedStyling.borderBottomRightRadius

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
		renderBorderBottomLeftRadius = resolvedBorderBottomLeftRadius.value
			* math.min(computedWidth, computedHeight)
			* 0.5
	end

	if resolvedBorderBottomRightRadius.unit == "pixel" then
		renderBorderBottomRightRadius = resolvedBorderBottomRightRadius.value
	elseif resolvedBorderBottomRightRadius.unit == "percentage" then
		renderBorderBottomRightRadius = resolvedBorderBottomRightRadius.value
			* math.min(computedWidth, computedHeight)
			* 0.5
	end

	local resolvedStrokeWeight = resolvedStyling.strokeWeight
	local resolvedStrokeLeftWeight = resolvedStyling.strokeLeftWeight
	local resolvedStrokeTopWeight = resolvedStyling.strokeTopWeight
	local resolvedStrokeRightWeight = resolvedStyling.strokeRightWeight
	local resolvedStrokeBottomWeight = resolvedStyling.strokeBottomWeight

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

	if resolvedStrokeLeftWeight.unit == "pixel" then
		renderStrokeLeftWeight = resolvedStrokeLeftWeight.value
	end

	if resolvedStrokeTopWeight.unit == "pixel" then
		renderStrokeTopWeight = resolvedStrokeTopWeight.value
	end

	if resolvedStrokeRightWeight.unit == "pixel" then
		renderStrokeRightWeight = resolvedStrokeRightWeight.value
	end

	if resolvedStrokeBottomWeight.unit == "pixel" then
		renderStrokeBottomWeight = resolvedStrokeBottomWeight.value
	end

	local usingRectangleShader = renderBorderTopLeftRadius > 0
		or renderBorderTopRightRadius > 0
		or renderBorderBottomLeftRadius > 0
		or renderBorderBottomRightRadius > 0

	local style = node.__style
	local styleBackgroundColor = style.backgroundColor
	local styleStrokeColor = style.strokeColor

	local render = node.render

	local renderBackgroundShader = render.backgroundShader
	local hasBackground = getColorAlpha(styleBackgroundColor) > 0

	local renderStrokeShader = render.strokeShader
	local hasStroke = getColorAlpha(styleStrokeColor) > 0
		and (
			renderStrokeLeftWeight > 0
			or renderStrokeTopWeight > 0
			or renderStrokeRightWeight > 0
			or renderStrokeBottomWeight > 0
		)

	if usingRectangleShader then
		if hasBackground then
			if renderBackgroundShader == nil then
				renderBackgroundShader = dxCreateShader(rectangleShaderRaw)
				render.backgroundShader = renderBackgroundShader
			end
		end

		if hasStroke then
			if renderStrokeShader == nil then
				renderStrokeShader = dxCreateShader(rectangleShaderRaw)
				render.strokeShader = renderStrokeShader
			end
		end

		local previousBorderTopLeftRadius = render.borderTopLeftRadius
		local previousBorderTopRightRadius = render.borderTopRightRadius
		local previousBorderBottomLeftRadius = render.borderBottomLeftRadius
		local previousBorderBottomRightRadius = render.borderBottomRightRadius

		if
			renderBorderTopLeftRadius ~= previousBorderTopLeftRadius
			or renderBorderTopRightRadius ~= previousBorderTopRightRadius
			or renderBorderBottomLeftRadius ~= previousBorderBottomLeftRadius
			or renderBorderBottomRightRadius ~= previousBorderBottomRightRadius
		then
			render.borderTopLeftRadius = renderBorderTopLeftRadius
			render.borderTopRightRadius = renderBorderTopRightRadius
			render.borderBottomLeftRadius = renderBorderBottomLeftRadius
			render.borderBottomRightRadius = renderBorderBottomRightRadius

			if renderBackgroundShader and isElement(renderBackgroundShader) then
				dxSetShaderValue(
					renderBackgroundShader,
					"BORDER_RADIUS",
					renderBorderTopLeftRadius,
					renderBorderTopRightRadius,
					renderBorderBottomLeftRadius,
					renderBorderBottomRightRadius
				)
			end

			if renderStrokeShader and isElement(renderStrokeShader) then
				dxSetShaderValue(
					renderStrokeShader,
					"BORDER_RADIUS",
					renderBorderTopLeftRadius,
					renderBorderTopRightRadius,
					renderBorderBottomLeftRadius,
					renderBorderBottomRightRadius
				)
			end
		end

		local previousStrokeLeftWeight = render.strokeLeftWeight
		local previousStrokeTopWeight = render.strokeTopWeight
		local previousStrokeRightWeight = render.strokeRightWeight
		local previousStrokeBottomWeight = render.strokeBottomWeight

		if
			renderStrokeLeftWeight ~= previousStrokeLeftWeight
			or renderStrokeTopWeight ~= previousStrokeTopWeight
			or renderStrokeRightWeight ~= previousStrokeRightWeight
			or renderStrokeBottomWeight ~= previousStrokeBottomWeight
		then
			render.strokeLeftWeight = renderStrokeLeftWeight
			render.strokeTopWeight = renderStrokeTopWeight
			render.strokeRightWeight = renderStrokeRightWeight
			render.strokeBottomWeight = renderStrokeBottomWeight

			if renderStrokeShader and isElement(renderStrokeShader) then
				dxSetShaderValue(
					renderStrokeShader,
					"STROKE_WEIGHT",
					renderStrokeLeftWeight,
					renderStrokeTopWeight,
					renderStrokeRightWeight,
					renderStrokeBottomWeight
				)
			end
		end
	else
		if renderBackgroundShader ~= nil then
			if renderBackgroundShader and isElement(renderBackgroundShader) then
				destroyElement(renderBackgroundShader)
			end

			renderBackgroundShader = nil
			render.backgroundShader = renderBackgroundShader
		end
	end

	if hasBackground then
		if usingRectangleShader and renderBackgroundShader and isElement(renderBackgroundShader) then
			dxDrawImage(x, y, computedWidth, computedHeight, renderBackgroundShader, 0, 0, 0, styleBackgroundColor)
		else
			dxDrawRectangle(x, y, computedWidth, computedHeight, styleBackgroundColor)
		end
	end

	if hasStroke then
		if usingRectangleShader and renderStrokeShader and isElement(renderStrokeShader) then
			dxDrawImage(x, y, computedWidth, computedHeight, renderStrokeShader, 0, 0, 0, styleStrokeColor)
		else
			dxDrawRectangle(x, y, renderStrokeLeftWeight, computedHeight, styleStrokeColor)
			dxDrawRectangle(x, y, computedWidth, renderStrokeTopWeight, styleStrokeColor)
			dxDrawRectangle(
				x + computedWidth - renderStrokeRightWeight,
				y,
				renderStrokeRightWeight,
				computedHeight,
				styleStrokeColor
			)
			dxDrawRectangle(
				x,
				y + computedHeight - renderStrokeBottomWeight,
				computedWidth,
				renderStrokeBottomWeight,
				styleStrokeColor
			)
		end
	end

	local children = node.children
	local childCount = #children

	for i = 1, childCount do
		Layta.renderer(children[i], x, y)
	end
end
