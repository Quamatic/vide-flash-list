local VirtualStore = require(script.Parent.Parent.VirtualStore)
type VirtualStore = VirtualStore.VirtualStore

local ScrollObserver = require(script.Parent.ScrollObserver)
type ScrollObserver = ScrollObserver.ScrollObserver

local types = require(script.Parent.Parent.types)
type ScrollToIndexConfig = types.ScrollToIndexConfig
type ScrollAnimator = types.ScrollAnimator

local ListScroller = {}
ListScroller.__index = ListScroller

-- Type exports

export type ListScroller = typeof(setmetatable(
	{} :: {
		_store: VirtualStore,
		_horizontal: boolean,
		_element: ScrollingFrame?,
		_scrollObserver: ScrollObserver?,
		_cancelScroll: () -> ()?,
	},
	ListScroller
))

-- Private

function ListScroller._scheduleImperativeScroll(
	self: ListScroller,
	getTargetOffset: () -> number,
	createScrollAnimator: ScrollAnimator?
)
	if not self._element then
		return
	end

	if self._cancelScroll then
		self._cancelScroll() -- Cancel the previous imperative scroll operation
	end

	local function waitForMeasurement()
		--
	end

	waitForMeasurement()

	if createScrollAnimator then
		if self._store:_hasUnmeasuredItemsInFrozenRange() then
			return
		end

		local targetOffset = getTargetOffset()

		self._cancelScroll = createScrollAnimator(function(progress)
			self._element.CanvasPosition = Vector2.new(targetOffset)

			if progress >= 1 then
				(self._cancelScroll :: () -> ())()
			end
		end)
	else
		self._element.CanvasPosition = Vector2.new()
	end
end

-- Public

function ListScroller.observe(self: ListScroller, element: ScrollingFrame)
	self._element = element
	self._scrollObserver = ScrollObserver.new(self._store, element, function(position)
		return if self._horizontal then position.X else position.Y
	end, function(jump, shift)
		element.CanvasPosition += if self._horizontal then Vector2.new(jump, 0) else Vector2.new(0, jump)

		if shift and self._cancelScroll then
			self._cancelScroll()
		end
	end)
end

function ListScroller.scrollTo(self: ListScroller, offset: number)
	self:_scheduleImperativeScroll(function()
		return offset
	end)
end

function ListScroller.scrollBy(self: ListScroller, offset: number)
	offset += self._store:getScrollOffset()

	self:_scheduleImperativeScroll(function()
		return offset
	end)
end

function ListScroller.scrollToIndex(self: ListScroller, index: number, config: ScrollToIndexConfig?)
	local _config = config or {} :: ScrollToIndexConfig

	local align = _config.align
	local offset = _config.offset or 0
	local animator = _config.animator

	if align == "nearest" then
		local itemOffset = self._store:getItemOffset(index)
		local scrollOffset = self._store:getScrollOffset()

		if itemOffset < scrollOffset then
			align = "start"
		elseif itemOffset + self._store:getItemSize(index) > scrollOffset + self._store:getViewportSize() then
			align = "end"
		else
			-- already completely visible
			return
		end
	end

	self:_scheduleImperativeScroll(function()
		return offset
			+ self._store:getStartMargin()
			+ self._store:getItemOffset(index)
			+ (
				if align == "end"
					then self._store:getItemSize(index) - self._store:getViewportSize()
					else if align == "center"
						then (self._store:getItemSize(index) - self._store:getViewportSize()) / 2
						else 0
			)
	end, animator)
end

function ListScroller.dispose(self: ListScroller)
	if self._scrollObserver then
		self._scrollObserver:dispose()
	end
end

-- Constructors

local function new(store: VirtualStore, horizontal: boolean): ListScroller
	return setmetatable({
		_store = store,
		_horizontal = horizontal,
	}, ListScroller)
end

return {
	new = new,
}
