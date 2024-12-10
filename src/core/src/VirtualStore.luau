local Bit = require(script.Parent.Bit)
type Bit = Bit.Bit

local VirtualStoreSubscription = require(script.Parent.VirtualStoreSubscription)
local splice = require(script.Parent.splice)

local UNCACHED_SIZE = -1

-- Scroll direction
local SCROLL_UP = 1
local SCROLL_DOWN = 2
local SCROLL_IDLE = 3

-- Scroll mode
local SCROLL_BY_SHIFT = 1
local SCROLL_BY_NATIVE = 2
local SCROLL_BY_MANUAL = 3

type CacheSnapshot = {
	sizes: { number },
	defaultItemSize: number,
}

type Subscription = {
	target: number,
	callback: (shouldSync: boolean) -> (),
}

local VirtualStore = {}
VirtualStore.__index = VirtualStore

-- Type exports

export type VirtualStore = typeof(setmetatable(
	{} :: {
		stateVersion: {},
		subscribers: { [Subscription]: true },
		viewportSize: number,
		overscan: number,
		scrollOffset: number,
		scrollDirection: number,
		scrollMode: number,
		startMargin: number,
		pendingJump: number,
		jump: number,
		flushedJump: number,
		jumpCount: number,
		previousRange: { number },
		frozenRange: { number }?,
		length: number,
		sizes: { number },
		offsets: Bit,
		defaultItemSize: number,
		totalMeasuredSize: number,
		shouldAutoEstimateItemSize: boolean,
	},
	VirtualStore
))

-- Private

function VirtualStore._getRelativeScrollOffset(self: VirtualStore)
	return self.scrollOffset - self.startMargin
end

function VirtualStore._getVisibleOffset(self: VirtualStore)
	return self:_getRelativeScrollOffset() + self.pendingJump + self.jump
end

function VirtualStore._setItemSize(self: VirtualStore, index: number, size: number)
	local previousSize = self:getItemSize(index)
	local isInitialMeasurement = self.sizes[index] == UNCACHED_SIZE

	self.sizes[index] = size
	self.offsets:add(index, size - previousSize)

	return isInitialMeasurement
end

function VirtualStore._findIndex(self: VirtualStore, offset: number)
	return math.clamp(self.offsets:lowerBound(offset), 1, self.length)
end

function VirtualStore._estimateDefaultItemSize(self: VirtualStore, startIndex: number)
	local measuredCountBeforeStart = 0
	local measuredSizes = {}

	for index, size in self.sizes do
		if size ~= UNCACHED_SIZE then
			table.insert(measuredSizes, size)

			if index < startIndex then
				measuredCountBeforeStart += 1
			end
		end
	end

	table.sort(measuredSizes, function(a, b)
		return a < b
	end)

	local length = #measuredSizes
	local mid = bit32.bor(length / 2, 0)
	local median = if bit32.btest(mid, 1)
		then (measuredSizes[mid - 1] + measuredSizes[mid + 1]) / 2
		else measuredSizes[mid]

	local previousDefaultItemSize = self.defaultItemSize
	self.defaultItemSize = median

	-- Discard cache for now
	self.offsets = Bit.new(self.sizes)

	-- Calculate diff of unmeasured items before start
	return (median - previousDefaultItemSize) * math.max(startIndex - measuredCountBeforeStart, 0)
end

function VirtualStore._updateCacheLength(self: VirtualStore, length: number, shift: boolean?)
	local difference = length - self.length
	self.length = length

	if difference > 0 then
		for _ = 1, difference do
			table.insert(self.sizes, UNCACHED_SIZE)
			self.offsets:push(self.defaultItemSize)
		end

		return self.defaultItemSize * difference
	else
		local removed: { number } = if shift then splice(self.sizes, 0, -difference) else splice(self.sizes, difference)
		local amount = 0

		for _, size in removed do
			amount -= if size == UNCACHED_SIZE then self.defaultItemSize else size
		end

		if shift then
			self.offsets = Bit.new(self.sizes)
		else
			for _ = 1, math.abs(difference) do
				self.offsets:pop()
			end
		end

		return amount
	end
end

function VirtualStore._getRange(self: VirtualStore, offset: number)
	return self:_findIndex(offset), self:_findIndex(offset + self.viewportSize)
end

function VirtualStore._applyJump(self: VirtualStore, amount: number)
	if amount > 0 then
		self.pendingJump += 1
		self.jump += amount
	end
end

function VirtualStore._flushJump(self: VirtualStore)
	self.flushedJump = self.jump
	self.jump = 0

	return self.flushedJump,
		self.scrollMode == SCROLL_BY_SHIFT or self:_getRelativeScrollOffset() + self.viewportSize >= self:getTotalSize()
end

function VirtualStore._hasUnmeasuredItemsInFrozenRange(self: VirtualStore)
	if self.frozenRange == nil then
		return false
	end

	for i = 1, #self.sizes do
		if self.sizes[i] == UNCACHED_SIZE then
			return true
		end
	end

	return false
end

function VirtualStore._performMutation(self: VirtualStore, target: number, shouldSync: boolean)
	self.stateVersion = {}

	for subscription in self.subscribers do
		if not bit32.btest(target, subscription.target) then
			continue
		end

		subscription.callback(shouldSync)
	end
end

-- Public

--[[
	Returns the current state version. Use this for reactivity.
]]
function VirtualStore.getStateVersion(self: VirtualStore)
	return self.stateVersion
end

--[[
    Takes a snapshot of the current cache
]]
function VirtualStore.getCacheSnapshot(self: VirtualStore): CacheSnapshot
	return {
		sizes = table.clone(self.sizes),
		defaultItemSize = self.defaultItemSize,
	}
end

--[[
	Returns the starting margin.
]]
function VirtualStore.getStartMargin(self: VirtualStore)
	return self.startMargin
end

--[[
	Returns the size of the given index. If it has not been cached yet, then the default item size is returned.
]]
function VirtualStore.getItemSize(self: VirtualStore, index: number)
	local size = self.sizes[index]
	return if size == UNCACHED_SIZE then self.defaultItemSize else size
end

--[[
	Returns the offset of the given index.
]]
function VirtualStore.getItemOffset(self: VirtualStore, index: number)
	if self.length == 0 then
		return 0
	end

	return self.offsets:get(index)
end

--[[
	Returns the total size (sum) of all the items.
]]
function VirtualStore.getTotalSize(self: VirtualStore)
	return self:getItemOffset(self.length)
end

--[[
	Returns the current scroll offset.
]]
function VirtualStore.getScrollOffset(self: VirtualStore)
	return self.scrollOffset
end

--[[
	Returns `true` if the current scroll direction isn't idle.
]]
function VirtualStore.isScrolling(self: VirtualStore)
	return self.scrollDirection ~= SCROLL_IDLE
end

--[[
	Returns the current viewport size.
]]
function VirtualStore.getViewportSize(self: VirtualStore)
	return self.viewportSize
end

--[[
	Returns the start and end index range for rendering.
]]
function VirtualStore.getRange(self: VirtualStore)
	if self.flushedJump ~= 0 then
		return self.previousRange
	end

	local startIndex, endIndex = self:_getRange(math.max(0, self:_getVisibleOffset()))
	if self.frozenRange ~= nil then
		startIndex = math.min(startIndex, self.frozenRange[1])
		endIndex = math.max(endIndex, self.frozenRange[2])
	end

	if self.scrollDirection ~= SCROLL_DOWN then
		startIndex -= math.max(0, self.overscan)
	end

	if self.scrollDirection ~= SCROLL_UP then
		endIndex += math.max(0, self.overscan)
	end

	self.previousRange[1] = math.max(startIndex, 1)
	self.previousRange[2] = math.min(endIndex, self.length)

	return self.previousRange
end

--[[
	Finds the first visible index.
]]
function VirtualStore.findStartIndex(self: VirtualStore)
	return self:_findIndex(self:_getVisibleOffset())
end

--[[
	Finds the last visible index.
]]
function VirtualStore.findEndIndex(self: VirtualStore)
	return self:_findIndex(self:_getVisibleOffset() + self.viewportSize)
end

--[[
	Returns `true` if the given index hasn't been measured.
]]
function VirtualStore.isUnmeasuredItem(self: VirtualStore, index: number)
	return self.sizes[index] == UNCACHED_SIZE
end

--[[
    Sets the current size of the viewport.
]]
function VirtualStore.setViewportSize(self: VirtualStore, size: number)
	if self.viewportSize ~= size then
		self.viewportSize = size
		self:_performMutation(
			VirtualStoreSubscription.SizeChanged + VirtualStoreSubscription.VirtualStateUpdated,
			false
		)
	end
end

--[[
    Updates the current scroll offset.
]]
function VirtualStore.setScrollOffset(self: VirtualStore, scrollOffset: number)
	local delta = scrollOffset - self.scrollOffset
	local distance = math.abs(delta)

	local flushedJump = self.flushedJump
	self.flushedJump = 0

	local isJustJumped = flushedJump ~= 0 and distance < math.abs(flushedJump) + 1
	if not isJustJumped and self.scrollMode == SCROLL_BY_NATIVE then
		self.scrollDirection = if delta < 0 then SCROLL_UP else SCROLL_DOWN
	end

	self.scrollOffset = scrollOffset

	local target = VirtualStoreSubscription.Scroll
	local relativeScrollOffset = self:_getRelativeScrollOffset()

	if relativeScrollOffset >= -self.viewportSize and relativeScrollOffset <= self:_getVisibleOffset() then
		target += VirtualStoreSubscription.VirtualStateUpdated
	end

	self:_performMutation(target, distance > self.viewportSize)
end

--[[
	Notifys the store about the scroll ending.
]]
function VirtualStore.notifyScrollEnded(self: VirtualStore)
	local target = VirtualStoreSubscription.ScrollEnd

	if self.scrollDirection ~= SCROLL_IDLE then
		target += VirtualStoreSubscription.VirtualStateUpdated
	end

	if self.pendingJump ~= 0 then
		self.jump += self.pendingJump
		self.pendingJump = 0
		self.jumpCount += 1
	end

	self.scrollDirection = SCROLL_IDLE
	self.scrollMode = SCROLL_BY_NATIVE
	self.frozenRange = nil

	self:_performMutation(target, false)
end

--[[
    Updates the given array of items with their new size(s).
]]
function VirtualStore.updateItemSizes(self: VirtualStore, items: { { number } })
	local totalUpdatedItems = 0
	local totalJumpApplied = 0

	for _, item in items do
		local index = item[1]
		local size = item[2]

		if self.sizes[index] == size then
			continue -- Size didn't change for this index.
		end

		local previousSize = self:getItemSize(index)

		-- Calculate jump by resize to minimize junks in appearance
		if
			self.scrollMode == SCROLL_BY_SHIFT
			or (
				if self.frozenRange ~= nil
					then index < self.frozenRange[1]
					else self:getItemOffset(index) + (if self.scrollDirection == SCROLL_IDLE
							and self.scrollMode == SCROLL_BY_NATIVE
						then self:getItemSize(index)
						else 0) < self:_getRelativeScrollOffset()
			)
		then
			totalJumpApplied += size - previousSize
		end

		local isInitialMeasurement = self:_setItemSize(index, size)

		if self.shouldAutoEstimateItemSize then
			self.totalMeasuredSize += if isInitialMeasurement then size else size - previousSize
		end

		totalUpdatedItems += 1
	end

	if totalUpdatedItems > 0 then
		if
			self.shouldAutoEstimateItemSize
			and self.viewportSize ~= 0
			and self.totalMeasuredSize > self.viewportSize
		then
			totalJumpApplied += self:_estimateDefaultItemSize(self:_findIndex(self:_getVisibleOffset()))
			self.shouldAutoEstimateItemSize = false
		end

		self:_applyJump(totalJumpApplied)
		self:_performMutation(VirtualStoreSubscription.VirtualStateUpdated + VirtualStoreSubscription.SizeChanged, true)
	end
end

--[[
	Sets the current amount of elements the store needs to capture.

	Note that the store stores the previous element count, so items will be removed or added based on the difference.
]]
function VirtualStore.setElementsCount(self: VirtualStore, length: number, shift: boolean?)
	if shift then
		self:_applyJump(self:_updateCacheLength(length, true))
		self.scrollMode = SCROLL_BY_SHIFT
	else
		self:_updateCacheLength(length)
	end

	self:_performMutation(VirtualStoreSubscription.VirtualStateUpdated, false)
end

--[[

]]
function VirtualStore.setStartMargin(self: VirtualStore, startMargin: number)
	self.startMargin = startMargin
end

--[[
	Sets the scroll mode to manual.
]]
function VirtualStore.setManualScroll(self: VirtualStore)
	self.scrollMode = SCROLL_BY_MANUAL
end

--[[
	Prepares the store for an animated scroll, freezing the items within the scroll range
	to create a seamless feeling.
	
	Note that scroll animations are quite performance intensive, and should not be overused because it removes
	the point of a virtualized container.
]]
function VirtualStore.prepareForAnimatedScroll(self: VirtualStore, targetOffset: number)
	self.frozenRange = { self:_getRange(targetOffset) }
	self:_performMutation(VirtualStoreSubscription.VirtualStateUpdated, false)
end

--[[
	Subscribes to the given target.
]]
function VirtualStore.subscribe(self: VirtualStore, target: number, callback: () -> ())
	local subscription: Subscription = {
		target = target,
		callback = callback,
	}

	self.subscribers[subscription] = true

	return function()
		self.subscribers[subscription] = nil
	end
end

-- Constructors

local function new(
	elementsCount: number,
	itemSize: number,
	overscan: number,
	cacheSnapshot: CacheSnapshot?,
	shouldAutoEstimateItemSize: boolean?
): VirtualStore
	local defaultItemSize = itemSize
	local sizes: { number }
	local offsets: { number }

	if cacheSnapshot then
		defaultItemSize = cacheSnapshot.defaultItemSize

		local snapshotLength = #cacheSnapshot.sizes
		local length = elementsCount + (elementsCount - snapshotLength)

		sizes = table.create(length)
		offsets = table.create(length)

		-- Make every element after uncached
		for i = 1, length do
			if i > math.min(elementsCount, length) then
				sizes[i] = UNCACHED_SIZE
				offsets[i] = defaultItemSize
			else
				local size = cacheSnapshot.sizes[i]
				sizes[i] = size
				offsets[i] = size
			end
		end
	else
		sizes = table.create(elementsCount, UNCACHED_SIZE)
		offsets = table.create(elementsCount, defaultItemSize)
	end

	return setmetatable({
		stateVersion = {},
		subscribers = {},
		viewportSize = 0,
		overscan = overscan,
		scrollOffset = 0,
		scrollDirection = SCROLL_IDLE,
		scrollMode = SCROLL_BY_NATIVE,
		startMargin = 0,
		pendingJump = 0,
		jump = 0,
		flushedJump = 0,
		jumpCount = 0,
		previousRange = { 1, 1 },
		frozenRange = nil,
		sizes = sizes,
		offsets = Bit.new(offsets),
		defaultItemSize = defaultItemSize,
		length = elementsCount,
		totalMeasuredSize = 0,
		shouldAutoEstimateItemSize = if shouldAutoEstimateItemSize ~= nil then shouldAutoEstimateItemSize else false,
	}, VirtualStore)
end

return {
	new = new,
}
