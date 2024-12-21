local VirtualStore = require(script.Parent.Parent.VirtualStore)
type VirtualStore = VirtualStore.VirtualStore

local debounce = require(script.Parent.Parent.utils.debounce)
type Debounce = debounce.Debounce<...any>

local types = require(script.Parent.Parent.types)
type ScrollToIndexAlign = types.ScrollToIndexAlign

-- Can't really find a better way to detect scroll ends so here's a 150ms delay.
local ARBITRARY_SCROLL_END_DETECTION_DELAY = 150 / 1000

local function createScrollEndDebouncer(store: VirtualStore): Debounce
	return debounce(function()
		store:notifyScrollEnded()
	end, ARBITRARY_SCROLL_END_DETECTION_DELAY)
end

local function getScrollToIndexOffset(
	store: VirtualStore,
	index: number,
	offset: number,
	align: ScrollToIndexAlign?
): number?
	if align == "nearest" then
		local itemOffset = store:getItemOffset(index)
		local scrollOffset = store:getScrollOffset()

		if itemOffset < scrollOffset then
			align = "start"
		elseif itemOffset + store:getItemSize(index) > scrollOffset + store:getViewportSize() then
			align = "end"
		else
			-- already completely visible
			return nil
		end
	end

	local targetOffset = offset + store:getStartMargin() + store:getItemOffset(index)

	if align == "end" then
		targetOffset += store:getItemSize(index) - store:getViewportSize()
	elseif align == "center" then
		targetOffset += (store:getItemSize(index) - store:getViewportSize()) / 2
	end

	return targetOffset
end

return {
	createScrollEndDebouncer = createScrollEndDebouncer,
	getScrollToIndexOffset = getScrollToIndexOffset,
}
