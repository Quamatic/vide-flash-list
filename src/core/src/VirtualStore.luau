local FenwickTree = require(script.Parent.Parent.FenwickTree)
type FenwickTree = FenwickTree.FenwickTree

local types = require(script.Parent.types)
type Overscan = types.Overscan

local VirtualStoreSubscription = require(script.Parent.VirtualStoreSubscription)
local splice = require(script.Parent.utils.splice)

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

export type VirtualStoreConfig = {
	elementsCount: number,
	itemSize: number,
	overscan: Overscan?,
	spacing: number?,
	cacheSnapshot: CacheSnapshot?,
	shouldAutoEstimateItemSize: boolean?,
}

local DEFAULT_OVERSCAN: Overscan = {
	type = "elements",
	amount = 4,
}

local VirtualStore = {}
VirtualStore.__index = VirtualStore

-- Type exports

export type VirtualStore = typeof(setmetatable(
	{} :: {
		_stateVersion: {},
		_subscribers: { [Subscription]: true },
		_viewportSize: number,
		_overscan: Overscan,
		_scrollOffset: number,
		_scrollDirection: number,
		_scrollMode: number,
		_startMargin: number,
		_spacing: number,
		_pendingJump: number,
		_jump: number,
		_flushedJump: number,
		_jumpCount: number,
		_previousRange: { number },
		_frozenRange: { number }?,
		_length: number,
		_sizes: { number },
		_offsets: FenwickTree,
		_defaultItemSize: number,
		_totalMeasuredSize: number,
		_shouldAutoEstimateItemSize: boolean,
	},
	VirtualStore
))
-- Private

function VirtualStore._getRelativeScrollOffset(self: VirtualStore)
	return self._scrollOffset - self._startMargin
end

function VirtualStore._getVisibleOffset(self: VirtualStore)
	return self:_getRelativeScrollOffset() + self._pendingJump + self._jump
end

function VirtualStore._setItemSize(self: VirtualStore, index: number, size: number)
	local previousSize = self:getItemSize(index)
	local isInitialMeasurement = self._sizes[index] == UNCACHED_SIZE

	self._sizes[index] = size
	self._offsets:update(index, size - previousSize + (if index ~= self._length then self._spacing else 0))

	return isInitialMeasurement
end

function VirtualStore._findIndex(self: VirtualStore, offset: number)
	return math.clamp(self._offsets:indexOf(offset), 1, self._length)
end

function VirtualStore._estimateDefaultItemSize(self: VirtualStore, startIndex: number)
	local measuredCountBeforeStart = 0
	local measuredSizes = {}

	for index, size in self._sizes do
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

	local previousDefaultItemSize = self._defaultItemSize
	self._defaultItemSize = median

	-- Discard offset tree for now
	self:_discardOffsetTree()

	-- Calculate diff of unmeasured items before start
	return (median - previousDefaultItemSize) * math.max(startIndex - measuredCountBeforeStart, 0)
end

function VirtualStore._updateCacheLength(self: VirtualStore, length: number, shift: boolean?)
	local difference = length - self._length
	self._length = length

	if difference > 0 then
		-- Added
		if shift then
			self:_discardOffsetTree()
		end

		for _ = 1, difference do
			table.insert(self._sizes, UNCACHED_SIZE)
			self._offsets:push(self._defaultItemSize + self._spacing)
		end

		return self._defaultItemSize * difference
	else
		-- Removed
		local removed: { number } = if shift
			then splice(self._sizes, 0, -difference)
			else splice(self._sizes, difference)

		local amount = 0
		for _, size in removed do
			amount -= if size == UNCACHED_SIZE then self._defaultItemSize else size
		end

		if shift then
			self:_discardOffsetTree()
		else
			for _ = 1, math.abs(difference) do
				self._offsets:pop()
			end
		end

		return amount
	end
end

-- Discards (refreshes) the offset tree
function VirtualStore._discardOffsetTree(self: VirtualStore)
	local offsets = table.create(self._length)

	for index, size in self._sizes do
		offsets[index] = if size == UNCACHED_SIZE then self._defaultItemSize else size
	end

	self._offsets = FenwickTree.fromArray(offsets)
end

function VirtualStore._getRange(self: VirtualStore, offset: number)
	return self:_findIndex(offset), self:_findIndex(offset + self._viewportSize)
end

function VirtualStore._applyJump(self: VirtualStore, amount: number)
	if amount > 0 then
		self._jump += amount
		self._jumpCount += 1
	end
end

function VirtualStore._flushJump(self: VirtualStore)
	self._flushedJump = self._jump
	self._jump = 0

	return self._flushedJump,
		self._scrollMode == SCROLL_BY_SHIFT
			or self:_getRelativeScrollOffset() + self._viewportSize >= self:getTotalSize()
end

function VirtualStore._hasUnmeasuredItemsInFrozenRange(self: VirtualStore)
	if self._frozenRange == nil then
		return false
	end

	local startIndex = math.max(1, self._frozenRange[1] - 1)
	local endIndex = math.min(self._length, self._frozenRange[2] + 1) + 1

	for i = startIndex, endIndex do
		if self._sizes[i] == UNCACHED_SIZE then
			return true
		end
	end

	return false
end

function VirtualStore._performMutation(self: VirtualStore, target: number, shouldSync: boolean)
	self._stateVersion = {}

	for subscription in self._subscribers do
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
	return self._stateVersion
end

--[[
    Takes a snapshot of the current cache
]]
function VirtualStore.getCacheSnapshot(self: VirtualStore): CacheSnapshot
	return {
		sizes = table.clone(self._sizes),
		defaultItemSize = self._defaultItemSize,
	}
end

--[[
	Returns the starting margin.
]]
function VirtualStore.getStartMargin(self: VirtualStore)
	return self._startMargin
end

--[[
	Returns the size of the given index. If it has not been cached yet, then the default item size is returned.
]]
function VirtualStore.getItemSize(self: VirtualStore, index: number)
	local size = self._sizes[index]
	return if size == UNCACHED_SIZE then self._defaultItemSize else size
end

--[[
	Returns the offset of the given index.
]]
function VirtualStore.getItemOffset(self: VirtualStore, index: number)
	if self._length == 0 then
		return 0
	end

	return self._offsets:prefixSum(index)
end

--[[
	Returns the current element count.
]]
function VirtualStore.getElementsCount(self: VirtualStore)
	return self._length
end

--[[
	Returns the total size (sum) of all the items.
]]
function VirtualStore.getTotalSize(self: VirtualStore)
	return self:getItemOffset(self._length + 1)
end

--[[
	Returns the current scroll offset.
]]
function VirtualStore.getScrollOffset(self: VirtualStore)
	return self._scrollOffset
end

--[[
	Returns `true` if the current scroll direction isn't idle.
]]
function VirtualStore.isScrolling(self: VirtualStore)
	return self._scrollDirection ~= SCROLL_IDLE
end

--[[
	Returns the current viewport size.
]]
function VirtualStore.getViewportSize(self: VirtualStore)
	return self._viewportSize
end

--[[
	Returns the total amount of jumps that have been performed over the lifetime of the store.
]]
function VirtualStore.getJumpCount(self: VirtualStore)
	return self._jumpCount
end

--[[
	Returns the start and end index range for rendering.
]]
function VirtualStore.getRange(self: VirtualStore)
	if self._flushedJump ~= 0 then
		return self._previousRange
	end

	local visibleOffset = self:_getVisibleOffset()
	local startIndex, endIndex = self:_getRange(math.max(0, visibleOffset))

	if self._frozenRange ~= nil then
		startIndex = math.min(startIndex, self._frozenRange[1])
		endIndex = math.max(endIndex, self._frozenRange[2])
	end

	if self._overscan.type == "elements" then
		if self._scrollDirection ~= SCROLL_DOWN then
			startIndex -= math.max(0, self._overscan.amount)
		end

		if self._scrollDirection ~= SCROLL_UP then
			endIndex += math.max(0, self._overscan.amount)
		end
	end

	-- We could just edit the indices instead of making a new table
	-- ...but it's easier in the end to create a new reference because of reactivity (especially for UI libraries).
	self._previousRange = {
		math.max(startIndex, 1),
		math.min(endIndex, self._length),
	}

	return self._previousRange
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
	return self:_findIndex(self:_getVisibleOffset() + self._viewportSize)
end

--[[
	Returns `true` if the given index hasn't been measured.
]]
function VirtualStore.isUnmeasuredItem(self: VirtualStore, index: number)
	return self._sizes[index] == UNCACHED_SIZE
end

--[[
    Sets the current size of the viewport.
]]
function VirtualStore.setViewportSize(self: VirtualStore, size: number)
	if self._viewportSize ~= size then
		self._viewportSize = size
		self:_performMutation(
			VirtualStoreSubscription.ViewportSizeChanged + VirtualStoreSubscription.VirtualStateUpdated,
			false
		)
	end
end

--[[
    Updates the current scroll offset.
]]
function VirtualStore.setScrollOffset(self: VirtualStore, scrollOffset: number)
	local delta = scrollOffset - self._scrollOffset
	if delta == 0 then
		return -- No change
	end

	local distance = math.abs(delta)

	local flushedJump = self._flushedJump
	self._flushedJump = 0

	local isJustJumped = flushedJump ~= 0 and distance < math.abs(flushedJump) + 1
	if not isJustJumped and self._scrollMode == SCROLL_BY_NATIVE then
		self._scrollDirection = if delta < 0 then SCROLL_UP else SCROLL_DOWN
	end

	self._scrollOffset = scrollOffset

	local target = VirtualStoreSubscription.Scroll
	local relativeScrollOffset = self:_getRelativeScrollOffset()

	if relativeScrollOffset >= -self._viewportSize and relativeScrollOffset <= self:_getVisibleOffset() then
		target += VirtualStoreSubscription.VirtualStateUpdated
	end

	self:_performMutation(target, distance > self._viewportSize)
end

--[[
	Notifies the store about the scroll ending.
]]
function VirtualStore.notifyScrollEnded(self: VirtualStore)
	local target = VirtualStoreSubscription.ScrollEnd

	if self._scrollDirection ~= SCROLL_IDLE then
		target += VirtualStoreSubscription.VirtualStateUpdated
	end

	if self._pendingJump ~= 0 then
		self._jump += self._pendingJump
		self._pendingJump = 0
		self._jumpCount += 1
	end

	self._scrollDirection = SCROLL_IDLE
	self._scrollMode = SCROLL_BY_NATIVE
	self._frozenRange = nil

	self:_performMutation(target, false)
end

--[[
    Updates the given array of items with their new size.
]]
function VirtualStore.updateItemSizes(self: VirtualStore, items: { { number } })
	local totalUpdatedItems = 0
	local totalJumpApplied = 0

	for _, item in items do
		local index = item[1]
		local size = item[2]

		if self._sizes[index] == size then
			continue -- Size didn't change for this index.
		end

		local previousSize = self:getItemSize(index)

		-- Calculate jump by resize to minimize junks in appearance
		if
			self._scrollMode == SCROLL_BY_SHIFT
			or (
				if self._frozenRange ~= nil
					then index < self._frozenRange[1]
					else self:getItemOffset(index) + (if self._scrollDirection == SCROLL_IDLE
							and self._scrollMode == SCROLL_BY_NATIVE
						then self:getItemSize(index)
						else 0) < self:_getRelativeScrollOffset()
			)
		then
			totalJumpApplied += size - previousSize
		end

		local isInitialMeasurement = self:_setItemSize(index, size)

		if self._shouldAutoEstimateItemSize then
			self._totalMeasuredSize += if isInitialMeasurement then size else size - previousSize
		end

		totalUpdatedItems += 1
	end

	if totalUpdatedItems > 0 then
		if
			self._shouldAutoEstimateItemSize
			and self._viewportSize ~= 0
			and self._totalMeasuredSize > self._viewportSize
		then
			totalJumpApplied += self:_estimateDefaultItemSize(self:_findIndex(self:_getVisibleOffset()))
			self._shouldAutoEstimateItemSize = false
		end

		self:_applyJump(totalJumpApplied)
		self:_performMutation(
			VirtualStoreSubscription.VirtualStateUpdated + VirtualStoreSubscription.ItemSizeChanged,
			true
		)
	end
end

--[[
	Sets the current amount of elements the store needs to capture.

	Note that the store stores the previous element count, so items will be removed or added based on the difference.
]]
function VirtualStore.setElementsCount(self: VirtualStore, length: number, shift: boolean?)
	if shift then
		self:_applyJump(self:_updateCacheLength(length, true))
		self._scrollMode = SCROLL_BY_SHIFT
	else
		self:_updateCacheLength(length)
	end

	self:_performMutation(VirtualStoreSubscription.VirtualStateUpdated, false)
end

--[[
	Set the starting offset (the space at the top) before rendering calculations take place.

	This is useful for creating something like a header, which is not involved in the virtual process.
]]
function VirtualStore.setStartMargin(self: VirtualStore, startMargin: number)
	self._startMargin = startMargin
end

--[[
	Sets the scroll mode to manual.
]]
function VirtualStore.setManualScroll(self: VirtualStore)
	self._scrollMode = SCROLL_BY_MANUAL
end

--[[
	Prepares the store for an animated scroll, freezing the items within the scroll range
	to create a seamless feeling.
	 
	Note that this can be quite performance intensive, especially depending on how large the list is. It is
	best to not abuse scroll animations, as doing so may defeat the purpose of a virtual container.
]]
function VirtualStore.prepareForAnimatedScroll(self: VirtualStore, targetOffset: number)
	self._frozenRange = { self:_getRange(targetOffset) }
	self:_performMutation(VirtualStoreSubscription.VirtualStateUpdated, false)
end

--[[
	Subscribes to the given target.
]]
function VirtualStore.subscribe(self: VirtualStore, target: number, callback: (shouldSync: boolean) -> ())
	local subscription: Subscription = {
		target = target,
		callback = callback,
	}

	self._subscribers[subscription] = true

	return function()
		self._subscribers[subscription] = nil
	end
end

-- Constructors

local function new(config: VirtualStoreConfig): VirtualStore
	local elementsCount = config.elementsCount
	local defaultItemSize = config.itemSize
	local sizes: { number }
	local offsets: { number }
	local spacing = config.spacing or 0

	local cacheSnapshot = config.cacheSnapshot
	if cacheSnapshot ~= nil then
		defaultItemSize = cacheSnapshot.defaultItemSize

		local snapshotLength = #cacheSnapshot.sizes
		local length = elementsCount + (elementsCount - snapshotLength)

		sizes = table.create(length)
		offsets = table.create(length)

		-- Make every element after uncached
		for i = 1, length do
			if i > math.min(elementsCount, length) then
				sizes[i] = UNCACHED_SIZE
				offsets[i] = defaultItemSize + spacing
			else
				local size = cacheSnapshot.sizes[i]
				sizes[i] = size
				offsets[i] = size + spacing
			end
		end
	else
		sizes = table.create(elementsCount, UNCACHED_SIZE)
		offsets = table.create(elementsCount, defaultItemSize)
	end

	return setmetatable({
		_stateVersion = {},
		_subscribers = {},
		_viewportSize = 0,
		_overscan = config.overscan or DEFAULT_OVERSCAN,
		_scrollOffset = 0,
		_scrollDirection = SCROLL_IDLE,
		_scrollMode = SCROLL_BY_NATIVE,
		_startMargin = 0,
		_spacing = spacing,
		_pendingJump = 0,
		_jump = 0,
		_flushedJump = 0,
		_jumpCount = 0,
		_previousRange = { 1, 1 },
		_frozenRange = nil,
		_sizes = sizes,
		_offsets = FenwickTree.fromArray(offsets),
		_defaultItemSize = defaultItemSize,
		_length = elementsCount,
		_totalMeasuredSize = 0,
		_shouldAutoEstimateItemSize = if config.shouldAutoEstimateItemSize ~= nil
			then config.shouldAutoEstimateItemSize
			else false,
	}, VirtualStore)
end

return {
	new = new,
}
