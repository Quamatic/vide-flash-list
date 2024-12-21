local types = require(script.Parent.Parent.types)
type ScrollAnimator = types.ScrollAnimator
type ScrollToIndexAlign = types.ScrollToIndexAlign
type GridScrollToIndexConfig = types.GridScrollToIndexConfig

local debounce = require(script.Parent.Parent.utils.debounce)
type Debounce = debounce.Debounce<...any>

local VirtualStore = require(script.Parent.Parent.VirtualStore)
type VirtualStore = VirtualStore.VirtualStore

local utils = require(script.Parent.utils)
local createScrollEndDebouncer = utils.createScrollEndDebouncer
local getScrollToIndexOffset = utils.getScrollToIndexOffset

local GridScroller = {}
GridScroller.__index = GridScroller

-- Type exports

export type GridScroller = typeof(setmetatable(
	{} :: {
		_vStore: VirtualStore,
		_hStore: VirtualStore,
		_element: ScrollingFrame?,
		_scrollConnection: RBXScriptConnection?,
		_cancelScroll: () -> ()?,
		_lastScrollPosition: Vector2,
		_vInvokeScrollEndedCheck: Debounce,
		_hInvokeScrollEndedCheck: Debounce,
	},
	GridScroller
))

-- Private

function GridScroller._scheduleImperativeScroll(
	self: GridScroller,
	getTargetOffset: () -> Vector2,
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

	local targetOffset = getTargetOffset()

	if createScrollAnimator then
		local startOffset = self._element.CanvasPosition

		if targetOffset.Y - startOffset.Y ~= 0 then
			self._vStore:prepareForAnimatedScroll(targetOffset.Y)
		end

		if targetOffset.X - startOffset.X ~= 0 then
			self._hStore:prepareForAnimatedScroll(targetOffset.X)
		end

		self._cancelScroll = createScrollAnimator(function(progress)
			self._element.CanvasPosition = startOffset:Lerp(targetOffset, progress)

			if progress >= 1 then
				return
			end
		end)
	else
		-- Update position immediately and let the store(s) know we just had an imperative movement.
		self._element.CanvasPosition = targetOffset

		-- Notify stores
		self._vStore:setManualScroll()
		self._hStore:setManualScroll()
	end
end

-- Public

function GridScroller.observe(self: GridScroller, element: ScrollingFrame)
	self._element = element
	self._scrollConnection = element:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
		local position = element.CanvasPosition
		local lastScrollPosition = self._lastScrollPosition

		-- Update vertical store if necessary
		if position.Y ~= lastScrollPosition.Y then
			self._vStore:setScrollOffset(position.Y)
			self._vInvokeScrollEndedCheck()
		end

		-- Update horizontal store if necessary
		if position.X ~= lastScrollPosition.X then
			self._hStore:setScrollOffset(position.X)
			self._hInvokeScrollEndedCheck()
		end

		-- Set last position
		self._lastScrollPosition = position
	end)
end

--[[
	Scrolls to the given offset(s).
]]
function GridScroller.scrollTo(self: GridScroller, offsetX: number, offsetY: number, animator: ScrollAnimator?)
	self:_scheduleImperativeScroll(function()
		return Vector2.new(offsetX, offsetY)
	end, animator)
end

--[[
	Scrolls by the given offset(s). (i.e., it is added onto the current scroll offset).
]]
function GridScroller.scrollBy(self: GridScroller, offsetX: number, offsetY: number, animator: ScrollAnimator?)
	offsetX += self._hStore:getScrollOffset()
	offsetY += self._vStore:getScrollOffset()

	self:_scheduleImperativeScroll(function()
		return Vector2.new(offsetX, offsetY)
	end, animator)
end

--[[
	Scrolls to the given indices(s). The x and y values correspond respectively to the row and column index.
]]
function GridScroller.scrollToIndex(
	self: GridScroller,
	indexX: number,
	indexY: number,
	config: GridScrollToIndexConfig?
)
	local _config = config or {} :: GridScrollToIndexConfig

	local offsetX = _config.offsetX or 0
	local offsetY = _config.offsetY or 0
	local alignX: ScrollToIndexAlign? = _config.alignX
	local alignY: ScrollToIndexAlign? = _config.alignY
	local animator = _config.animator

	-- Get offset for both indices
	local x = getScrollToIndexOffset(self._hStore, indexX, offsetX, alignX)
	local y = getScrollToIndexOffset(self._vStore, indexY, offsetY, alignY)

	if x == nil and y == nil then
		return -- Already completely visible
	end

	self:_scheduleImperativeScroll(function()
		return Vector2.new(x, y)
	end, animator)
end

--[[
	Disposes of the scroller. Use this when you don't need it anymore.
]]
function GridScroller.dispose(self: GridScroller)
	if self._scrollConnection then
		self._scrollConnection:Disconnect()
		self._scrollConnection = nil
	end

	self._vInvokeScrollEndedCheck.cancel()
	self._hInvokeScrollEndedCheck.cancel()
end

--[[
	Fixes jumps in scrolling. Only call this during changes in jump count on the virtual store(s).
]]
function GridScroller.fixScrollJump(self: GridScroller)
	if not self._element then
		return
	end

	local vJump, vShift = self._vStore:_flushJump()
	local hJump, hShift = self._hStore:_flushJump()

	if vJump ~= 0 or hJump ~= 0 then
		if vShift or hShift then
			local vScrollOffset = self._vStore:getScrollOffset()
			local hScrollOffset = self._hStore:getScrollOffset()

			self._element.CanvasPosition = Vector2.new(hScrollOffset + hJump, vScrollOffset + vJump)

			if self._cancelScroll then
				self._cancelScroll()
			end
		else
			self._element.CanvasPosition += Vector2.new(hJump, vJump)
		end
	end
end

-- Constructors

local function new(vStore: VirtualStore, hStore: VirtualStore): GridScroller
	return setmetatable({
		-- Stores
		_vStore = vStore,
		_hStore = hStore,

		-- Tracker
		_lastScrollPosition = Vector2.zero,

		-- Debounces
		_vInvokeScrollEndedCheck = createScrollEndDebouncer(vStore),
		_hInvokeScrollEndedCheck = createScrollEndDebouncer(hStore),
	}, GridScroller)
end

return {
	new = new,
}
