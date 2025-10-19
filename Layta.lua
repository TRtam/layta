local screenWidth, screenHeight = guiGetScreenSize()
local screenScale = screenHeight / 1080

local function createClass(super)
  local class

  class = {}
  class.__index = class

  setmetatable(class, {
    __call = function(_, ...)
      local instance = setmetatable({
        destroy = function(self, ...)
          if self.destructor then
            self:destructor(...)
          end

          setmetatable(self, nil)
        end,
      }, class)

      if instance.constructor then
        instance:constructor(...)
      end

      return instance
    end,

    __index = function(_, key)
      return super and super[key]
    end,
  })

  return class
end

local function createProxy(source, onchanged)
  return setmetatable({}, {
    __newindex = function(_, key, value)
      local previous = source[key]

      if value == previous then
        return
      end

      source[key] = value

      if onchanged then
        onchanged(key, value)
      end
    end,

    __index = function(_, key)
      return source[key]
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

local transparent = 0x00ffffff
local white = 0xffffffff
local black = 0xff000000


local function getColorAlpha(color)
  return math.floor(color / 0x1000000) % 0x100
end

local function hue2rgb(p, q, t)
  local tmod = t

  if tmod < 0 then
    tmod = tmod + 1
  end

  if tmod > 1 then
    tmod = tmod - 1
  end

  if tmod < 1 / 6 then
    return p + (q - p) * 6 * tmod
  elseif tmod < 1 / 2 then
    return q
  elseif tmod < 2 / 3 then
    return p + (q - p) * (2 / 3 - tmod) * 6
  end

  return p
end

local function hsl(h, s, l, alpha)
  local red, green, blue

  if s == 0 then
    red, green, blue = l, l, l
  else
    local q = (l < 0.5) and (l * (1 + s)) or (l + s - l * s)
    local p = 2 * l - q

    local huer = h + 1 / 3
    local hueg = h
    local hueb = h - 1 / 3

    red = hue2rgb(p, q, huer)
    green = hue2rgb(p, q, hueg)
    blue = hue2rgb(p, q, hueb)
  end

  local r = math.floor(red * 255 + 0.5)
  local g = math.floor(green * 255 + 0.5)
  local b = math.floor(blue * 255 + 0.5)
  local a = math.floor((alpha or 1) * 255 + 0.5)

  return a * 0x1000000 + r * 0x10000 + g * 0x100 + b
end

local function createAttributes()
  return {
    alignItems = "stretch",
    alignSelf = "auto",
    backgroundColor = 0x00ffffff,
    borderBottomLeftRadius = "auto",
    borderBottomRightRadius = "auto",
    borderRadius = "auto",
    borderTopLeftRadius = "auto",
    borderTopRightRadius = "auto",
    color = white,
    display = "flex",
    flexDirection = "row",
    flexGrow = 0,
    flexShrink = 0,
    flexWrap = "nowrap",
    font = "default",
    gap = "auto",
    height = "auto",
    justifyContent = "flex-start",
    material = false,
    padding = "auto",
    paddingBottom = "auto",
    paddingLeft = "auto",
    paddingRight = "auto",
    paddingTop = "auto",
    position = "relative",
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
    visible = true,
    width = "auto",
  }
end

local Node = createClass()

function Node:constructor(attributes, ...)
  self.parent = false

  self.index = false

  self.children = {}

  self.dirty = true

  self.resolved = {
    borderBottomLeftRadius = { value = 0, unit = "auto" },
    borderBottomRightRadius = { value = 0, unit = "auto" },
    borderRadius = { value = 0, unit = "auto" },
    borderTopLeftRadius = { value = 0, unit = "auto" },
    borderTopRightRadius = { value = 0, unit = "auto" },
    flexGrow = { value = 0, unit = "pixel" },
    flexShrink = { value = 0, unit = "pixel" },
    gap = { value = 0, unit = "auto" },
    height = { value = 0, unit = "auto" },
    padding = { value = 0, unit = "auto" },
    paddingBottom = { value = 0, unit = "auto" },
    paddingLeft = { value = 0, unit = "auto" },
    paddingRight = { value = 0, unit = "auto" },
    paddingTop = { value = 0, unit = "auto" },
    strokeBottomWeight = { value = 0, unit = "auto" },
    strokeLeftWeight = { value = 0, unit = "auto" },
    strokeRightWeight = { value = 0, unit = "auto" },
    strokeTopWeight = { value = 0, unit = "auto" },
    strokeWeight = { value = 0, unit = "auto" },
    width = { value = 0, unit = "auto" },
  }

  self.__attributes = createAttributes()

  self.attributes = createProxy(self.__attributes, function(key, value)
    local resolvedAttribute = self.resolved[key]

    if resolvedAttribute then
      resolvedAttribute.value, resolvedAttribute.unit = resolveLength(value)
    end

    if key == "text" then
      local attributes = self.__attributes
      local computed = self.computed

      computed.textWidth = dxGetTextWidth(value, attributes.textSize, attributes.font)
      computed.textHeight = dxGetFontHeight(attributes.textSize, attributes.font)
    elseif key == "textSize" then
      local attributes = self.__attributes
      local computed = self.computed

      computed.textWidth = dxGetTextWidth(attributes.text, value, attributes.font)
      computed.textHeight = dxGetFontHeight(value, attributes.font)
    elseif key == "font" then
      local attributes = self.__attributes
      local computed = self.computed

      computed.textWidth = dxGetTextWidth(attributes.text, attributes.textSize, value)
      computed.textHeight = dxGetFontHeight(attributes.textSize, value)
    elseif key == "material" then
      local attributes = self.__attributes
      local computed = self.computed

      local materialWidth = 0
      local materialHeight = 0

      if attributes.material then
        materialWidth, materialHeight = dxGetMaterialSize(attributes.material)
      end

      computed.materialWidth = materialWidth
      computed.materialHeight = materialHeight
    end

    self:markDirty()
  end)

  self.computed = {
    flexBasis = 0,
    height = 0,
    materialHeight = 0,
    materialWidth = 0,
    textHeight = dxGetFontHeight(1, "default"),
    textWidth = 0,
    width = 0,
    x = 0,
    y = 0,
  }

  self.render = {}

  if attributes then
    for key, value in pairs(attributes) do
      self.attributes[key] = value
    end
  end

  local childcount = select("#", ...)

  for i = 1, childcount do
    self:appendChild(select(i, ...))
  end
end

function Node:destructor()

end

function Node:setParent(parent)
  if parent then
    parent:appendChild(self)
  elseif self.parent then
    self.parent:removeChild(self)
  end
end

function Node:appendChild(child)
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

function Node:removeChild(child)
  if child.parent ~= self then
    return false
  end

  table.remove(self.children, child.index)
  self:reindexChildren(child.index)

  child.parent = false
  child.index = false

  self:markDirty()

  return true
end

function Node:reindexChildren(startAt)
  local children = self.children

  for i = startAt or 1, #children do
    children[i].index = i
  end
end

function Node:markDirty()
  if not self.dirty then
    self.dirty = true
  end

  if self.parent then
    self.parent:markDirty()
  end
end

Text = createClass(Node)

function Text:measure()
  local computed = self.computed

  return computed.textWidth, computed.textHeight
end

function Text:draw(x, y, width, height, color)
  local attributes = self.attributes

  if attributes.text ~= "" then
    dxDrawText(attributes.text, x, y, x + width, y + height, color, attributes.textSize, attributes.font, attributes.textAlignX, attributes.textAlignY, attributes.textClip, false, attributes.textWordWrap, attributes.textColorCoded)
  end
end

Image = createClass(Node)

function Image:measure()
  local computed = self.computed

  return computed.materialWidth, computed.materialHeight
end

function Image:draw(x, y, width, height, color)
  local attributes = self.attributes

  if attributes.material then
    dxDrawImage(x, y, width, height, attributes.material, 0, 0, 0, color)
  end
end

local splitChildrenIntoLines

local calculateLayout

function splitChildrenIntoLines(node, isMainAxisRow, mainAxisDimension, mainAxisPosition, crossAxisDimension, crossAxisPosition, containerMainSize, containerCrossSize, containerMainInnerSize, containerCrossInnerSize, paddingMainStart, paddingCrossStart, gapMain, gapCross, flexCanWrap, stretchChildren, children, childcount, doingSecondPass, doingThirdPass)
  local flexLines = { { [mainAxisDimension] = 0, [mainAxisPosition] = paddingMainStart, [crossAxisDimension] = 0, [crossAxisPosition] = paddingCrossStart, remainingFreeSpace = 0, totalFlexGrowFactor = 0, totalFlexShrinkScaledFactor = 0 } }
  local currentLine = flexLines[1]

  local linesMainMaximumLineSize = 0
  local linesCrossTotalLinesSize = 0

  local secondPassChildren
  local thirdPassChildren

  for i = 1, childcount do
    local child = children[i]
    local childAttributes = child.__attributes

    if childAttributes.visible then
      local childResolved = child.resolved

      if not doingSecondPass then
        local availableWidth = isMainAxisRow and containerMainSize ~= nil and containerMainInnerSize or not isMainAxisRow and containerCrossSize ~= nil and containerCrossInnerSize or nil
        local availableHeight = isMainAxisRow and containerCrossSize ~= nil and containerCrossInnerSize or not isMainAxisRow and containerMainSize ~= nil and containerMainInnerSize or nil

        calculateLayout(child, availableWidth, availableHeight, nil, nil, isMainAxisRow, stretchChildren)

        local childResolvedMainSize = childResolved[mainAxisDimension]
        local childResolvedCrossSize = childResolved[crossAxisDimension]

        local childAlignSelf = childAttributes.alignSelf

        if childResolvedMainSize.unit == "percentage" and containerMainSize == nil or (childResolvedCrossSize.unit == "auto" and stretchChildren and (childAlignSelf == "auto" or childAlignSelf == "stretch")) and containerCrossSize == nil then
          if not secondPassChildren then secondPassChildren = {} end
          table.insert(secondPassChildren, child)
        end
      end

      local childComputed = child.computed
      local childComputedMainSize = not doingThirdPass and childComputed.flexBasis or childComputed[mainAxisDimension]
      local childComputedCrossSize = childComputed[crossAxisDimension]

      if flexCanWrap and #currentLine > 1 and currentLine[mainAxisDimension] + gapMain + childComputedMainSize > containerMainInnerSize then
        local previousLine = currentLine

        currentLine = { [mainAxisDimension] = 0, [mainAxisPosition] = paddingMainStart, [crossAxisDimension] = 0, [crossAxisPosition] = gapCross + previousLine[crossAxisPosition] + previousLine[crossAxisDimension], remainingFreeSpace = 0, totalFlexGrowFactor = 0, totalFlexShrinkScaledFactor = 0 }

        table.insert(flexLines, currentLine)
      end

      table.insert(currentLine, child)

      currentLine[mainAxisDimension] = currentLine[mainAxisDimension] +
      (#currentLine > 0 and i < childcount and gapMain or 0) + childComputedMainSize
      currentLine[crossAxisDimension] = math.max(currentLine[crossAxisDimension], childComputedCrossSize)

      if containerMainSize ~= nil then
        currentLine.remainingFreeSpace = containerMainInnerSize - currentLine[mainAxisDimension]
      end

      linesMainMaximumLineSize = math.max(linesMainMaximumLineSize,
        currentLine[mainAxisPosition] + currentLine[mainAxisDimension])
      linesCrossTotalLinesSize = math.max(linesCrossTotalLinesSize,
        currentLine[crossAxisPosition] + currentLine[crossAxisDimension])

      local childFlexGrow = childResolved.flexGrow.value
      local childFlexShrink = childResolved.flexShrink.value

      if childFlexGrow > 0 or childFlexShrink > 0 then
        currentLine.totalFlexGrowFactor = currentLine.totalFlexGrowFactor + childFlexGrow
        currentLine.totalFlexShrinkScaledFactor = currentLine.totalFlexShrinkScaledFactor +
        childFlexShrink * childComputedMainSize

        if not thirdPassChildren then thirdPassChildren = {} end
        table.insert(thirdPassChildren, child)
        thirdPassChildren[child] = currentLine
      end
    end
  end

  return flexLines, linesMainMaximumLineSize - paddingMainStart, linesCrossTotalLinesSize - paddingCrossStart, secondPassChildren, thirdPassChildren
end

function calculateLayout(node, availableWidth, availableHeight, forcedWidth, forcedHeight, parentIsMainAxisRow, parentStretchChildren)
  if not node.dirty then
    return false
  end

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
  elseif resolvedWidth.unit == "auto" and not parentIsMainAxisRow and parentStretchChildren and (alignSelf == "auto" or alignSelf == "stretch") and availableWidth then
    computedWidth = availableWidth
  end

  if forcedHeight then
    computedHeight = forcedHeight
  elseif resolvedHeight.unit == "pixel" then
    computedHeight = resolvedHeight.value
  elseif resolvedHeight.unit == "percentage" and availableHeight then
    computedHeight = resolvedHeight.value * availableHeight
  elseif resolvedHeight.unit == "auto" and parentIsMainAxisRow and parentStretchChildren and (alignSelf == "auto" or alignSelf == "stretch") and availableHeight then
    computedHeight = availableHeight
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
  local childcount = children and #children or 0

  if childcount > 0 then
    local flexLines, linesMainMaximumLineSize, linesCrossTotalLinesSize, secondPassChildren, thirdPassChildren = splitChildrenIntoLines(node, isMainAxisRow, mainAxisDimension, mainAxisPosition, crossAxisDimension, crossAxisPosition, containerMainSize, containerCrossSize, containerMainInnerSize, containerCrossInnerSize, paddingMainStart, paddingCrossStart, gapMain, gapCross, flexCanWrap, stretchChildren, children, childcount, false, false)

    local resolvedMainSize = isMainAxisRow and resolvedWidth or resolvedHeight
    local resolvedCrossSize = isMainAxisRow and resolvedHeight or resolvedWidth

    if containerMainSize == nil and (resolvedMainSize.unit == "auto" or resolvedMainSize.unit == "fit-content") then
      computedWidth = isMainAxisRow and (linesMainMaximumLineSize + paddingMainStart + paddingMainEnd) or computedWidth
      computedHeight = not isMainAxisRow and (linesMainMaximumLineSize + paddingMainStart + paddingMainEnd) or computedHeight

      containerMainSize = isMainAxisRow and computedWidth or computedHeight
      containerMainInnerSize = linesMainMaximumLineSize
    end

    if resolvedCrossSize.unit == "auto" or resolvedCrossSize.unit == "fit-content" then
      computedWidth = not isMainAxisRow and (linesCrossTotalLinesSize + paddingCrossStart + paddingCrossEnd) or computedWidth
      computedHeight = isMainAxisRow and (linesCrossTotalLinesSize + paddingCrossStart + paddingCrossEnd) or computedHeight

      containerCrossSize = isMainAxisRow and computedHeight or computedWidth
      containerCrossInnerSize = linesCrossTotalLinesSize
    end

    if not parentIsMainAxisRow and parentStretchChildren and resolvedWidth.unit == "auto" and (alignSelf == "auto" or alignSelf == "stretch") and availableWidth then
      computedWidth = math.max(computedWidth, availableWidth)
    elseif parentIsMainAxisRow and parentStretchChildren and resolvedHeight.unit == "auto" and (alignSelf == "auto" or alignSelf == "stretch") and availableHeight then
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

      flexLines, _, linesCrossTotalLinesSize, _, thirdPassChildren = splitChildrenIntoLines(node, isMainAxisRow, mainAxisDimension, mainAxisPosition, crossAxisDimension, crossAxisPosition, containerMainSize, containerCrossSize, containerMainInnerSize, containerCrossInnerSize, paddingMainStart, paddingCrossStart, gapMain, gapCross, flexCanWrap, stretchChildren, children, childcount, true, false)

      if (resolvedCrossSize.unit == "auto" or resolvedCrossSize.unit == "fit-content") then
        computedWidth = not isMainAxisRow and (linesCrossTotalLinesSize + paddingCrossStart + paddingCrossEnd) or computedWidth
        computedHeight = isMainAxisRow and (linesCrossTotalLinesSize + paddingCrossStart + paddingCrossEnd) or computedHeight

        containerCrossSize = isMainAxisRow and computedHeight or computedWidth
        containerCrossInnerSize = linesCrossTotalLinesSize
      end

      if not parentIsMainAxisRow and parentStretchChildren and resolvedWidth.unit == "auto" and (alignSelf == "auto" or alignSelf == "stretch") and availableWidth then
        computedWidth = math.max(computedWidth, availableWidth)
      elseif parentIsMainAxisRow and parentStretchChildren and resolvedHeight.unit == "auto" and (alignSelf == "auto" or alignSelf == "stretch") and availableHeight then
        computedHeight = math.max(computedHeight, availableHeight)
      end
    end

    if thirdPassChildren then
      for i = 1, #thirdPassChildren do
        local child = thirdPassChildren[i]

        local childResolved = child.resolved
        local childFlexGrow = childResolved.flexGrow.value
        local childFlexShrink = childResolved.flexShrink.value

        local line = thirdPassChildren[child]
        local lineRemainingFreeSpace = line.remainingFreeSpace

        if childFlexGrow > 0 and lineRemainingFreeSpace > 0 then
          child.dirty = true

          local childComputed = child.computed
          local childComputedMainSize = childComputed.flexBasis

          local flexGrowAmount = (childFlexGrow / line.totalFlexGrowFactor) * lineRemainingFreeSpace

          local availableWidth = isMainAxisRow and containerMainSize ~= nil and containerMainInnerSize or not isMainAxisRow and containerCrossSize ~= nil and containerCrossInnerSize
          local availableHeight = isMainAxisRow and containerCrossSize ~= nil and containerCrossInnerSize or not isMainAxisRow and containerMainSize ~= nil and containerMainInnerSize

          local forcedWidth = isMainAxisRow and (childComputedMainSize + flexGrowAmount) or nil
          local forcedHeight = not isMainAxisRow and (childComputedMainSize + flexGrowAmount) or nil

          calculateLayout(child, availableWidth, availableHeight, forcedWidth, forcedHeight, isMainAxisRow, stretchChildren)
        elseif childFlexShrink > 0 and lineRemainingFreeSpace < 0 then
          child.dirty = true

          local childComputed = child.computed
          local childComputedMainSize = childComputed.flexBasis

          local flexShrinkAmount = childComputedMainSize * (childFlexShrink / line.totalFlexShrinkScaledFactor) *
          -lineRemainingFreeSpace

          local availableWidth = isMainAxisRow and containerMainSize ~= nil and containerMainInnerSize or not isMainAxisRow and containerCrossSize ~= nil and containerCrossInnerSize
          local availableHeight = isMainAxisRow and containerCrossSize ~= nil and containerCrossInnerSize or not isMainAxisRow and containerMainSize ~= nil and containerMainInnerSize

          local forcedWidth = isMainAxisRow and math.max(childComputedMainSize - flexShrinkAmount, 0) or nil
          local forcedHeight = not isMainAxisRow and math.max(childComputedMainSize - flexShrinkAmount, 0) or nil

          calculateLayout(child, availableWidth, availableHeight, forcedWidth, forcedHeight, isMainAxisRow, stretchChildren)
        end
      end
    end

    local flexLinesAlignItemsOffset = alignItems == "center" and (containerCrossInnerSize - linesCrossTotalLinesSize) * 0.5 or alignItems == "flex-end" and containerCrossInnerSize - linesCrossTotalLinesSize or 0

    for i = 1, #flexLines do
      local currentLine = flexLines[i]

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

        if childAlignSelf == "auto" then
          childAlignSelf = alignItems
        end

        local childComputed = child.computed
        local childComputedCrossSize = childComputed[crossAxisDimension]

        local childCrossOffset = childAlignSelf == "center" and (currentLineCrossSize - childComputedCrossSize) * 0.5 or childAlignSelf == "flex-end" and currentLineCrossSize - childComputedCrossSize or 0

        childComputed[mainAxisPosition] = math.floor(caretMainPosition + 0.5)
        childComputed[crossAxisPosition] = math.floor((caretCrossPosition + childCrossOffset) + 0.5)

        caretMainPosition = caretMainPosition + childComputed[mainAxisDimension] + gapMain + currentLineJustifyContentGap
      end
    end
  else
    local measuredWidth
    local measuredHeight

    if node.measure then
      measuredWidth, measuredHeight = node:measure()
    end

    if measuredWidth and not computedWidth and (resolvedWidth.unit == "auto" or resolvedHeight.unit == "fit-content") then
      computedWidth = measuredWidth + computedPaddingLeft + computedPaddingRight
    end

    if measuredHeight and not computedHeight and (resolvedHeight.unit == "auto" or resolvedHeight.unit == "fit-content") then
      computedHeight = measuredHeight + computedPaddingTop + computedPaddingBottom
    end
  end

  computed.width = math.floor((computedWidth or 0) + 0.5)
  computed.height = math.floor((computedHeight or 0) or 0.5)

  if not forcedWidth then
    computed.flexBasis = parentIsMainAxisRow and computed.width or computed.flexBasis
  end

  if not forcedHeight then
    computed.flexBasis = not parentIsMainAxisRow and computed.height or computed.flexBasis
  end

  return true
end

local RectangleShaderString = [[
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

local function renderer(node, px, py)
  local attributes = node.__attributes

  if not attributes.visible then
    return false
  end

  local computed = node.computed

  local computedWidth = computed.width
  local computedHeight = computed.height

  local x = px + computed.x
  local y = py + computed.y

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

  local usingRectangleShader = renderBorderTopLeftRadius > 0 or renderBorderTopRightRadius > 0 or renderBorderBottomLeftRadius > 0 or renderBorderBottomRightRadius > 0

  local attributes = node.__attributes
  local backgroundColor = attributes.backgroundColor
  local strokeColor = attributes.strokeColor
  local color = attributes.color

  local render = node.render

  local renderBackgroundShader = render.backgroundShader
  local hasBackground = getColorAlpha(backgroundColor) > 0

  local renderStrokeShader = render.strokeShader
  local hasStroke = getColorAlpha(strokeColor) > 0 and (renderStrokeLeftWeight > 0 or renderStrokeTopWeight > 0 or renderStrokeRightWeight > 0 or renderStrokeBottomWeight > 0)

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

    local previousBorderTopLeftRadius = render.borderTopLeftRadius
    local previousBorderTopRightRadius = render.borderTopRightRadius
    local previousBorderBottomLeftRadius = render.borderBottomLeftRadius
    local previousBorderBottomRightRadius = render.borderBottomRightRadius

    if renderBorderTopLeftRadius ~= previousBorderTopLeftRadius or renderBorderTopRightRadius ~= previousBorderTopRightRadius or renderBorderBottomLeftRadius ~= previousBorderBottomLeftRadius or renderBorderBottomRightRadius ~= previousBorderBottomRightRadius then
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

    if renderStrokeLeftWeight ~= previousStrokeLeftWeight or renderStrokeTopWeight ~= previousStrokeTopWeight or renderStrokeRightWeight ~= previousStrokeRightWeight or renderStrokeBottomWeight ~= previousStrokeBottomWeight then
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

    if renderStrokeShader ~= nil then
      if renderStrokeShader and isElement(renderStrokeShader) then
        destroyElement(renderStrokeShader)
      end

      renderStrokeShader = nil
      render.strokeShader = renderStrokeShader
    end
  end

  if hasBackground then
    if usingRectangleShader and renderBackgroundShader and isElement(renderBackgroundShader) then
      dxDrawImage(x, y, computedWidth, computedHeight, renderBackgroundShader, 0, 0, 0, backgroundColor)
    else
      dxDrawRectangle(x, y, computedWidth, computedHeight, backgroundColor)
    end
  end

  if hasStroke then
    if usingRectangleShader and renderStrokeShader and isElement(renderStrokeShader) then
      dxDrawImage(x, y, computedWidth, computedHeight, renderStrokeShader, 0, 0, 0, strokeColor)
    else
      dxDrawRectangle(x, y, renderStrokeLeftWeight, computedHeight, strokeColor)
      dxDrawRectangle(x, y, computedWidth, renderStrokeTopWeight, strokeColor)
      dxDrawRectangle(
        x + computedWidth - renderStrokeRightWeight,
        y,
        renderStrokeRightWeight,
        computedHeight,
        strokeColor
      )
      dxDrawRectangle(
        x,
        y + computedHeight - renderStrokeBottomWeight,
        computedWidth,
        renderStrokeBottomWeight,
        strokeColor
      )
    end
  end

  if node.draw and getColorAlpha(color) > 0 then
    node:draw(x, y, computedWidth, computedHeight, color)
  end

  local children = node.children
  local childCount = children and #children or 0

  for i = 1, childCount do
    renderer(children[i], x, y)
  end

  return true
end

local tree = Node()

addEventHandler("onClientRender", root, function()
  calculateLayout(tree, screenWidth, nil, nil, nil, false, false)
end)

addEventHandler("onClientRender", root, function()
  renderer(tree, 0, 0)
end)

Layta = {
  Node = Node,
  Text = Text,
  Image = Image,
  hsl = hsl,
  transparent = transparent,
  white = white,
  black = black,
  tree = tree,
}
