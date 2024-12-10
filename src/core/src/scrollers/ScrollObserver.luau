local VirtualStore = require(script.Parent.Parent.VirtualStore)
type VirtualStore = VirtualStore.VirtualStore

local ARBITRARY_SCROLL_END_DETECTION_DELAY = 150 / 1000

local ScrollObserver = {}
ScrollObserver.__index = ScrollObserver

-- Type exports

export type ScrollObserver = typeof(setmetatable(
	{} :: {
		_store: VirtualStore,
		_element: ScrollingFrame,
		_scrollConnection: RBXScriptConnection,
		_scrollEndedDetectionThread: thread?,
		_notifyScrollEnded: () -> (),
		_getScrollOffset: (position: Vector2) -> number,
		_updateScrollOffset: (value: number, shift: boolean) -> (),
		_getStartMargin: (() -> number)?,
		_lastScrollTime: number,
	},
	ScrollObserver
))

-- Private

function ScrollObserver._onScroll(self: ScrollObserver, position: Vector2)
	self._lastScrollTime = os.clock()

	-- Cancel previous thread if one exists
	if self._scrollEndedDetectionThread ~= nil then
		task.cancel(self._scrollEndedDetectionThread)
	end

	-- Update the store's scroll offset
	self._store:setScrollOffset(self._getScrollOffset(position))

	-- Create new scroll end detection thread
	self._scrollEndedDetectionThread = task.delay(ARBITRARY_SCROLL_END_DETECTION_DELAY, self._notifyScrollEnded)
end

-- Public

function ScrollObserver.dispose(self: ScrollObserver)
	self._scrollConnection:Disconnect()

	if self._scrollEndedDetectionThread ~= nil then
		task.cancel(self._scrollEndedDetectionThread)
	end
end

function ScrollObserver.fixScrollJump(self: ScrollObserver)
	local jump, shift = self._store:_flushJump()
	if jump == 0 then
		return
	end

	self._updateScrollOffset(jump, shift)

	if shift and self._store:getViewportSize() > self._store:getTotalSize() then
		-- In this case applying jump may not cause scroll.
		-- Current logic expects scroll event occurs after applying jump so we dispatch it manually.
		self._store:setScrollOffset(self._getScrollOffset(self._element.CanvasPosition))
	end
end

-- Constructors

local function new(
	store: VirtualStore,
	element: ScrollingFrame,
	getScrollOffset: (position: Vector2) -> number,
	updateScrollOffset: (value: number, shift: boolean) -> (),
	getStartMargin: (() -> number)?
): ScrollObserver
	local self = setmetatable({
		_store = store,
		_element = element,
		_getScrollOffset = getScrollOffset,
		_updateScrollOffset = updateScrollOffset,
		_getStartMargin = getStartMargin,
		_lastScrollTime = 0,
	}, ScrollObserver)

	self._notifyScrollEnded = function()
		store:notifyScrollEnded()
	end

	self._scrollConnection = element:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
		self:_onScroll(element.CanvasPosition)
	end)

	return self
end

return {
	new = new,
}
