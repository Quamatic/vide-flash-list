local _store = require(script.Parent.store)
type VirtualStore = _store.VirtualStore

local VirtualStoreAction = require(script.Parent.VirtualStoreAction)

local types = require(script.Parent.types)
type ScrollAnimator = types.ScrollAnimator
type ScrollToIndexParams = types.ScrollToIndexParams

local SCROLL_END_DETECTION_DELAY = 150 / 1000 -- 150ms

export type Scroller = {
	-- Lifecycle
	setScrollElement: (element: ScrollingFrame) -> (),
	updateScrollPosition: (position: Vector2) -> (),
	destroy: () -> (),
	-- Imperative scroll utilities
	scrollTo: (offset: number, animator: ScrollAnimator?) -> (),
	scrollBy: (offset: number, animator: ScrollAnimator?) -> (),
	scrollToIndex: (index: number, params: ScrollToIndexParams?) -> (),
	-- Misc
	fixScrollJump: () -> (),
}

local function createScroller(store: VirtualStore, horizontal: boolean): Scroller
	local scrollElement: ScrollingFrame? = nil
	local cancelScroll: () -> () = nil
	local scrollEndDetectionThread: thread? = nil

	-- Schedules an imperative canvas position update.
	local function scheduleImperativeScroll(getTargetOffset: () -> number, animator: ScrollAnimator?)
		if not scrollElement then
			-- Wait for the element to be parented.
			task.defer(scheduleImperativeScroll, getTargetOffset, animator)
			return
		end

		if cancelScroll ~= nil then
			-- Cancel waiting scrollTo()
			cancelScroll()
		end

		local targetOffset = getTargetOffset()

		if animator then
			-- Notify the store about a scroll animation starting.
			store.dispatch({
				type = VirtualStoreAction.ManualScrollAnimationInitiated,
				offset = targetOffset,
			})

			local startOffset = if horizontal then scrollElement.CanvasPosition.X else scrollElement.CanvasPosition.Y

			-- Begin the animator lifecycle.
			cancelScroll = animator(function(progress: number)
				local offset = math.floor(startOffset + (targetOffset - startOffset) * progress)
				scrollElement.CanvasPosition = if horizontal then Vector2.new(offset, 0) else Vector2.new(0, offset)

				if progress >= 1 then
					cancelScroll()
				end
			end)
		else
			-- Manual scroll.
			scrollElement.CanvasPosition = if horizontal
				then Vector2.new(targetOffset, 0)
				else Vector2.new(0, targetOffset)

			store.dispatch({ type = VirtualStoreAction.ManualScrollInitiated })
		end
	end

	local function notifyScrollEnded()
		store.dispatch({ type = VirtualStoreAction.ScrollEnd })
	end

	return {
		setScrollElement = function(element)
			scrollElement = element
		end,

		updateScrollPosition = function(position)
			-- Cancel the detection thread if it exists
			if scrollEndDetectionThread ~= nil then
				task.cancel(scrollEndDetectionThread)
			end

			-- Notify store
			store.dispatch({
				type = VirtualStoreAction.Scroll,
				offset = if horizontal then position.X else position.Y,
			})

			-- Create thread to detect scroll ends
			-- TODO: better way of detecting this? Arbitrary delay isn't the greatest.
			scrollEndDetectionThread = task.delay(SCROLL_END_DETECTION_DELAY, notifyScrollEnded)
		end,

		destroy = function()
			-- Cancel the detection thread if it exists
			if scrollEndDetectionThread ~= nil then
				task.cancel(scrollEndDetectionThread)
				scrollEndDetectionThread = nil
			end
		end,

		scrollTo = function(offset, animator)
			scheduleImperativeScroll(function()
				return offset
			end, animator)
		end,

		scrollBy = function(offset, animator)
			offset += store.getScrollOffset()

			scheduleImperativeScroll(function()
				return offset
			end, animator)
		end,

		scrollToIndex = function(index, params)
			local config = params or {} :: ScrollToIndexParams
			local align = config.align
			local offset = config.offset or 0

			index = math.clamp(index, 1, store.getItemsLength())

			if align == "nearest" then
				local itemOffset = store.getItemOffset(index)
				local scrollOffset = store.getScrollOffset()

				if itemOffset < scrollOffset then
					align = "start"
				elseif itemOffset + store.getItemSize(index) > scrollOffset + store.getViewportSize() then
					align = "end"
				else
					return
				end
			end

			scheduleImperativeScroll(function()
				local itemOffset = offset + store.getItemOffset(index)
				local alignmentOffset = if align == "end"
					then store.getItemSize(index) - store.getViewportSize()
					else if align == "center" then (store.getItemSize(index) - store.getViewportSize()) / 2 else 0

				return itemOffset + alignmentOffset
			end, config.animator)
		end,

		fixScrollJump = function()
			local jump, shift = store.flushJump()
			if jump == 0 or not scrollElement then
				return
			end

			if shift then
				local offset = store.getScrollOffset() + jump
				scrollElement.CanvasPosition = if horizontal then Vector2.new(offset, 0) else Vector2.new(0, offset)

				if cancelScroll ~= nil then
					cancelScroll()
				end

				if store.getViewportSize() > store.getTotalSize() then
					store.dispatch({
						type = VirtualStoreAction.Scroll,
						offset = if horizontal then scrollElement.CanvasPosition.X else scrollElement.CanvasPosition.Y,
					})
				end
			else
				local position = scrollElement.CanvasPosition
				scrollElement.CanvasPosition = if horizontal
					then Vector2.new(position.X + jump, 0)
					else Vector2.new(0, position.Y + jump)
			end
		end,
	}
end

return {
	createScroller = createScroller,
}
