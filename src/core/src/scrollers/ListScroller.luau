local VirtualStore = require(script.Parent.Parent.VirtualStore)
type VirtualStore = VirtualStore.VirtualStore

local debounce = require(script.Parent.Parent.utils.debounce)
type Debounce = debounce.Debounce<...any>

local types = require(script.Parent.Parent.types)
type ListScrollToIndexConfig = types.ListScrollToIndexConfig
type ScrollToIndexAlign = types.ScrollToIndexAlign
type ScrollAnimator = types.ScrollAnimator

local utils = require(script.Parent.utils)
local createScrollEndDebouncer = utils.createScrollEndDebouncer
local getScrollToIndexOffset = utils.getScrollToIndexOffset

local ListScroller = {}
ListScroller.__index = ListScroller

-- Type exports

export type ListScroller = typeof(setmetatable(
	{} :: {
		_store: VirtualStore,
		_horizontal: boolean,
		_element: ScrollingFrame?,
		_scrollConnection: RBXScriptConnection?,
		_invokeScrollEndedCheck: Debounce,
		_cancelScroll: () -> ()?,
	},
	ListScroller
))

-- Private

function ListScroller._getPositionFromOffset(self: ListScroller, offset: number)
	return if self._horizontal then Vector2.new(offset, 0) else Vector2.new(0, offset)
end

function ListScroller._scheduleImperativeScroll(
	self: ListScroller,
	getTargetOffset: () -> number,
	createScrollAnimator: ScrollAnimator?
)
	if not self._element then
		-- Element hasn't been assigned yet. The original implementation will recursively defer until it exists, but I think it's best to just silently drop it.
		-- Maybe a warning could be issued?
		return
	end

	if self._cancelScroll then
		-- Cancel the previous imperative scroll operation
		self._cancelScroll()
	end

	local function waitForMeasurement()
		--
	end

	waitForMeasurement()

	if createScrollAnimator then
		-- If the items within the target range have already been measured then we don't have to wait for any measurement.
		if self._store:_hasUnmeasuredItemsInFrozenRange() then
			return
		end

		local startOffset = if self._horizontal then self._element.CanvasPosition.X else self._element.CanvasPosition.Y

		-- Get the target offset and prepare for an animated scroll. This will freeze the items within the range.
		local targetOffset = getTargetOffset()
		self._store:prepareForAnimatedScroll(targetOffset)

		-- Let the user control the animation progress.
		self._cancelScroll = createScrollAnimator(function(progress)
			self._element.CanvasPosition =
				self:_getPositionFromOffset(startOffset + (targetOffset - startOffset) * progress)

			if progress >= 1 then
				(self._cancelScroll :: () -> ())()
			end
		end)
	else
		-- Update position immediately and let the store know we just had an imperative movement.
		self._element.CanvasPosition = self:_getPositionFromOffset(getTargetOffset())
		self._store:setManualScroll()
	end
end

-- Public

function ListScroller.observe(self: ListScroller, element: ScrollingFrame)
	self._element = element
	self._scrollConnection = element:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
		-- Update scroll offset
		self._store:setScrollOffset(if self._horizontal then element.CanvasPosition.X else element.CanvasPosition.Y)
		-- Invoke the scroll ended check (this will throttle as intended due to the frequency of scroll dispatches)
		self._invokeScrollEndedCheck()
	end)
end

--[[
	Scrolls to the given offset.
]]
function ListScroller.scrollTo(self: ListScroller, offset: number)
	self:_scheduleImperativeScroll(function()
		return offset
	end)
end

--[[
	Scrolls by a given offset (i.e., it is added onto the current scroll offset).
]]
function ListScroller.scrollBy(self: ListScroller, offset: number)
	offset += self._store:getScrollOffset()

	self:_scheduleImperativeScroll(function()
		return offset
	end)
end

--[[
	Scrolls to the given index.
]]
function ListScroller.scrollToIndex(self: ListScroller, index: number, config: ListScrollToIndexConfig?)
	local _config = config or {} :: ListScrollToIndexConfig

	local align: ScrollToIndexAlign? = _config.align
	local offset = _config.offset or 0
	local animator = _config.animator

	local value = getScrollToIndexOffset(self._store, index, offset, align)
	if value == nil then
		return -- Already completely visible
	end

	self:_scheduleImperativeScroll(function()
		return value
	end, animator)
end

--[[
	Disposes of the scroller. Use this when you are finished using the list.
]]
function ListScroller.dispose(self: ListScroller)
	if self._scrollConnection then
		self._scrollConnection:Disconnect()
		self._scrollConnection = nil
	end

	self._invokeScrollEndedCheck.cancel()
end

--[[
	Fixes jumps in scrolling. Only call this during changes in the jump count from the virtual store.
]]
function ListScroller.fixScrollJump(self: ListScroller)
	local jump, shift = self._store:_flushJump()
	if jump == 0 then
		return
	end

	if shift then
		(self._element :: ScrollingFrame).CanvasPosition =
			self:_getPositionFromOffset(self._store:getScrollOffset() + jump)

		if self._cancelScroll then
			self._cancelScroll()
		end
	else
		(self._element :: ScrollingFrame).CanvasPosition += self:_getPositionFromOffset(jump)
	end
end

-- Constructors

local function new(store: VirtualStore, horizontal: boolean): ListScroller
	return setmetatable({
		_store = store,
		_horizontal = horizontal,
		_invokeScrollEndedCheck = createScrollEndDebouncer(store),
	}, ListScroller)
end

return {
	new = new,
}
