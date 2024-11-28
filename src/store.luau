local cache = require(script.Parent.cache)

local createCache = cache.create
local computeRange = cache.computeRange
local computeStartOffset = cache.computeOffset
local computeTotalSize = cache.computeTotalSize
local takeSnapshot = cache.takeSnapshot
local findIndex = cache.findIndex
local getItemSize_ = cache.getItemSize
local setItemSize = cache.setItemSize
local updateCacheLength = cache.updateLength

local VirtualStoreAction = require(script.Parent.VirtualStoreAction)
type VirtualStoreActionPayload = VirtualStoreAction.VirtualStoreActionPayload

local VirtualStoreSubscription = require(script.Parent.VirtualStoreSubscription)

local UNCACHED = cache.UNCACHED

local ScrollDirection = {
	Idle = 0,
	Up = 1,
	Down = 2,
}

type Subscription = {
	target: number,
	callback: () -> (),
}

export type VirtualStore = {
	getStateVersion: () -> {},
	getCacheSnapshot: () -> cache.InternalCacheSnapshot,
	getRange: () -> (number, number),
	findStartIndex: () -> number,
	findEndIndex: () -> number,
	isUnmeasuredItem: (index: number) -> boolean,
	getItemOffset: (index: number) -> number,
	getItemsLength: () -> number,
	getTotalSize: () -> number,
	subscribe: (target: number, callback: () -> ()) -> () -> (),
	dispatch: (action: VirtualStoreActionPayload) -> (),
}

local function createVirtualStore(
	elementsCount: number,
	itemSize: number,
	overscan: number,
	cacheSnapshot: cache.InternalCacheSnapshot?,
	shouldAutoEstimateItemSize: boolean?
): VirtualStore
	-- State
	local stateVersion = {}
	local subscribers: { [Subscription]: true } = {}
	local viewportSize = 0
	local scrollOffset = 0
	local startSpacerSize = 0
	local scrollDirection = ScrollDirection.Idle
	local previousStartIndex = 1
	local previousEndIndex = 1
	local pendingJump = 0
	local jump = 0
	local totalMeasuredSize = 0

	-- Create cache
	local cache = createCache(elementsCount, itemSize, cacheSnapshot)

	-- Utility
	local function getRelativeScrollOffset()
		return scrollOffset - startSpacerSize
	end

	local function getVisibleOffset()
		return getRelativeScrollOffset() + pendingJump + jump
	end

	local function getRange(offset: number)
		return computeRange(cache, offset, viewportSize, previousStartIndex)
	end

	local function getItemSize(index: number)
		return getItemSize_(cache, index)
	end

	local function getItemOffset(index: number)
		return computeStartOffset(cache, index) - pendingJump
	end

	local function getTotalSize()
		return computeTotalSize(cache)
	end

	return {
		getStateVersion = function()
			return stateVersion
		end,

		getCacheSnapshot = function()
			return takeSnapshot(cache)
		end,

		getRange = function()
			local startIndex, endIndex = getRange(math.max(0, getVisibleOffset()))

			if scrollDirection ~= ScrollDirection.Down then
				startIndex -= math.max(1, overscan)
			end

			if scrollDirection ~= ScrollDirection.Up then
				endIndex += math.max(1, overscan)
			end

			print(startIndex, endIndex)

			previousStartIndex = math.max(1, startIndex)
			previousEndIndex = math.min(endIndex, cache.length)

			return previousStartIndex, previousEndIndex
		end,

		findStartIndex = function()
			return findIndex(cache, getVisibleOffset())
		end,

		findEndIndex = function(): number
			return findIndex(cache, getVisibleOffset() + viewportSize)
		end,

		isUnmeasuredItem = function(index)
			return cache.sizes[index] == UNCACHED
		end,

		getItemOffset = getItemOffset,

		getItemsLength = function()
			return cache.length
		end,

		getTotalSize = getTotalSize,

		subscribe = function(target, callback)
			local subscription: Subscription = {
				target = target,
				callback = callback,
			}

			subscribers[subscription] = true

			return function()
				subscribers[subscription] = nil
			end
		end,

		dispatch = function(action)
			print(action.type)
			local mutated = 0

			if action.type == VirtualStoreAction.Scroll then
				local delta = action.offset - scrollOffset

				-- Update scroll direction
				scrollDirection = if delta < 0 then ScrollDirection.Up else ScrollDirection.Down

				-- Update offset
				scrollOffset = action.offset
				mutated = VirtualStoreSubscription.Scroll

				-- Skip if offset is not changed
				local relativeOffset = getRelativeScrollOffset()
				if relativeOffset >= -viewportSize and relativeOffset <= getTotalSize() then
					mutated += VirtualStoreSubscription.VirtualStateUpdated
				end
			elseif action.type == VirtualStoreAction.ItemResized then
				local index = action.index
				local size = action.size
				local previous = getItemSize(index)

				-- Check if we actually updated first
				if previous ~= size then
					local isInitialMeasurement = setItemSize(cache, index, size)

					if shouldAutoEstimateItemSize then
						totalMeasuredSize += if isInitialMeasurement then size else size - previous
					end

					mutated = VirtualStoreSubscription.VirtualStateUpdated + VirtualStoreSubscription.SizeChanged
				end
			elseif action.type == VirtualStoreAction.ViewportResized then
				-- TODO: change later
				viewportSize = action.size.Y
				mutated = VirtualStoreSubscription.VirtualStateUpdated + VirtualStoreSubscription.SizeChanged
			elseif action.type == VirtualStoreAction.ItemsChanged then
				updateCacheLength(cache, action.length)
			end

			if mutated ~= 0 then
				stateVersion = {}

				for subscriber in subscribers do
					if not bit32.btest(bit32.band(mutated, subscriber.target)) then
						return
					end

					subscriber.callback()
				end
			end
		end,
	}
end

return {
	createVirtualStore = createVirtualStore,
}
