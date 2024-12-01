local cache = require(script.Parent.cache)

local createCache = cache.create
local computeRange = cache.computeRange
local computeStartOffset = cache.computeOffset
local computeTotalSize = cache.computeTotalSize
local takeSnapshot = cache.takeSnapshot
local findIndex = cache.findIndex
local getItemSize_ = cache.getItemSize
local setItemSize = cache.setItemSize
local estimateDefaultItemSize = cache.estimateDefaultItemSize
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

local ScrollMode = {
	Native = 0,
	Manual = 1,
	Shift = 2,
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
	getItemSize: (index: number) -> number,
	getTotalSize: () -> number,
	getScrollOffset: () -> number,
	getViewportSize: () -> number,
	hasUnmeasuredItemsInFrozenRange: () -> boolean,
	flushJump: () -> (number, boolean),
	getJumpCount: () -> number,
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
	local scrollMode = ScrollMode.Native
	local previousStartIndex = 1
	local previousEndIndex = 1
	local pendingJump = 0
	local jump = 0
	local jumpCount = 0
	local flushedJump = 0
	local totalMeasuredSize = 0
	local frozenRange: { number }? = nil

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

	local function applyJump(amount: number)
		if amount > 0 then
			jump += amount
			jumpCount += 1
		end
	end

	return {
		getStateVersion = function()
			return stateVersion
		end,

		getCacheSnapshot = function()
			return takeSnapshot(cache)
		end,

		getRange = function()
			-- Return previous range for consistent render until next scroll event comes in.
			if flushedJump ~= 0 then
				return previousStartIndex, previousEndIndex
			end

			local startIndex, endIndex = getRange(math.max(0, getVisibleOffset()))
			if frozenRange ~= nil then
				startIndex = math.min(startIndex, frozenRange[1])
				endIndex = math.max(endIndex, frozenRange[2])
			end

			if scrollDirection ~= ScrollDirection.Down then
				startIndex -= math.max(0, overscan)
			end

			if scrollDirection ~= ScrollDirection.Up then
				endIndex += math.max(0, overscan)
			end

			previousStartIndex = math.max(startIndex, 1)
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
		getItemSize = getItemSize,

		getItemsLength = function()
			return cache.length
		end,

		getTotalSize = getTotalSize,

		getScrollOffset = function()
			return scrollOffset
		end,

		getViewportSize = function()
			return viewportSize
		end,

		hasUnmeasuredItemsInFrozenRange = function()
			if frozenRange == nil then
				return false
			end

			for i = math.max(1, frozenRange[1] - 1), math.min(cache.length, frozenRange[2] + 1) + 1 do
				if cache.sizes[i] == UNCACHED then
					return true
				end
			end

			return false
		end,

		flushJump = function()
			flushedJump = jump
			jump = 0

			return flushedJump,
				scrollMode == ScrollMode.Shift or getRelativeScrollOffset() + viewportSize >= getTotalSize()
		end,

		getJumpCount = function()
			return jumpCount
		end,

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
			local shouldFlushPendingJump = false
			local mutated = 0

			if action.type == VirtualStoreAction.Scroll then
				local targetOffset = action.offset

				local currentFlushedJump = flushedJump
				flushedJump = 0

				local delta = targetOffset - scrollOffset
				local distance = math.abs(delta)

				-- Scroll event after jump compensation is not reliable because it may result in the opposite direction.
				-- The delta of artificial scroll may not be equal with the jump because it may be batched with other scrolls.
				local isJustJumped = currentFlushedJump ~= 0 and distance < currentFlushedJump + 1

				-- Scroll events are dispatched enough so it's ok to skip some of them.
				if not isJustJumped and scrollMode == ScrollMode.Native then
					scrollDirection = if delta < 0 then ScrollDirection.Up else ScrollDirection.Down
				end

				-- Update offset
				scrollOffset = targetOffset
				mutated = VirtualStoreSubscription.Scroll

				-- Skip if offset is not changed
				local relativeOffset = getRelativeScrollOffset()
				if relativeOffset >= -viewportSize and relativeOffset <= getTotalSize() then
					mutated += VirtualStoreSubscription.VirtualStateUpdated
				end
			elseif action.type == VirtualStoreAction.ScrollEnd then
				-- The user stopped scrolling.
				mutated = VirtualStoreSubscription.ScrollEnd

				if scrollDirection ~= ScrollDirection.Idle then
					shouldFlushPendingJump = true
					mutated += VirtualStoreSubscription.VirtualStateUpdated
				end

				scrollDirection = ScrollDirection.Idle
				scrollMode = ScrollMode.Native
				frozenRange = nil
			elseif action.type == VirtualStoreAction.ItemResized then
				-- An item was resized
				local index = action.index
				local newSize = action.size
				local currentSize = getItemSize(index)

				-- Check if we actually updated first
				if currentSize ~= newSize then
					-- Calculate jump by resize to minimize junks in appearance
					if
						scrollMode == ScrollMode.Shift
						or (
							if frozenRange
								then index < frozenRange[1]
								else getItemOffset(index) + (if scrollDirection == ScrollDirection.Idle
										and scrollMode == ScrollMode.Shift
									then currentSize
									else 0) < getRelativeScrollOffset()
						)
					then
						applyJump(newSize - currentSize)
					end

					local isInitialMeasurement = setItemSize(cache, index, newSize)

					if shouldAutoEstimateItemSize then
						totalMeasuredSize += if isInitialMeasurement then newSize else newSize - currentSize

						if viewportSize ~= 0 and totalMeasuredSize > viewportSize then
							applyJump(estimateDefaultItemSize(cache, findIndex(cache, getVisibleOffset())))
							shouldAutoEstimateItemSize = false
						end
					end

					mutated = VirtualStoreSubscription.VirtualStateUpdated + VirtualStoreSubscription.SizeChanged
				end
			elseif action.type == VirtualStoreAction.ViewportResized then
				-- Viewport AbsoluteSize changed
				local size = action.size

				if viewportSize ~= size.Y then
					viewportSize = size.Y
					mutated = VirtualStoreSubscription.VirtualStateUpdated + VirtualStoreSubscription.SizeChanged
				end
			elseif action.type == VirtualStoreAction.ItemsChanged then
				-- Items changed, whether they were added or removed.
				if action.shift then
					applyJump(updateCacheLength(cache, action.length, true))
					scrollMode = ScrollMode.Shift
				else
					updateCacheLength(cache, action.length)
				end

				mutated = VirtualStoreSubscription.VirtualStateUpdated
			elseif action.type == VirtualStoreAction.ManualScrollInitiated then
				scrollMode = ScrollMode.Manual
			elseif action.type == VirtualStoreAction.ManualScrollAnimationInitiated then
				-- A scroll animation is in progress, freeze the items up until the target offset.
				frozenRange = { getRange(action.offset) }
				mutated = VirtualStoreSubscription.VirtualStateUpdated
			end

			if mutated ~= 0 then
				stateVersion = {}

				if shouldFlushPendingJump and pendingJump ~= 0 then
					jump += pendingJump
					pendingJump = 0
					jumpCount += 1
				end

				-- Call all subscribers with the target flags
				for subscriber in subscribers do
					if not bit32.btest(mutated, subscriber.target) then
						continue
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
