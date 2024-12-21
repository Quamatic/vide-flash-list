local vide = require(script.Parent.Parent.vide)

local Virtua = require(script.Parent.Parent.Virtua)
type VirtualStore = Virtua.VirtualStore
type ListResizer = Virtua.ListResizer
type ListScroller = Virtua.ListScroller

local types = require(script.Parent.types)
type Derivable<T> = types.Derivable<T>

local useRange = require(script.Parent.useRange)

local VirtualStore = Virtua.VirtualStore
local VirtualStoreSubscription = Virtua.VirtualStoreSubscription
local ListResizer = Virtua.ListResizer
local ListScroller = Virtua.ListScroller

local source = vide.source
local derive = vide.derive
local effect = vide.effect
local cleanup = vide.cleanup

export type VirtualizerHandle = {
	scrollTo: (offset: number) -> (),
	scrollBy: (offset: number) -> (),
	scrollToIndex: (index: number) -> (),
}

export type UseVirtualizerProps<T> = {
	data: () -> { T },
	itemSize: number,
	overscan: Virtua.Overscan?,
	spacing: number?,
	horizontal: boolean,
	shift: boolean?,
	--initialScrollIndex: number?,
	onScroll: (offset: number) -> ()?,
	onScrollEnd: () -> ()?,
}

export type UseVirtualizerReturn<T> = {
	store: VirtualStore,
	resizer: ListResizer,
	scroller: ListScroller,
	rerender: () -> (),
	range: () -> { number },
	totalSize: () -> number,
}

--[[
	A composable for managing data of a virtualized list.
]]
local function useListVirtualizer<T>(props: UseVirtualizerProps<T>): UseVirtualizerReturn<T>
	-- Store
	local store = VirtualStore.new({
		elementsCount = #props.data(),
		itemSize = props.itemSize,
		overscan = props.overscan,
		spacing = props.spacing,
		shouldAutoEstimateItemSize = props.itemSize == nil or props.itemSize == 0,
	})

	local resizer = ListResizer.new(store, props.horizontal)
	local scroller = ListScroller.new(store, props.horizontal)

	-- Source for creating "re-renders"
	local rerender = source(store:getStateVersion())

	-- Subscriptions
	local unsubscribeStoreState = store:subscribe(VirtualStoreSubscription.VirtualStateUpdated, function()
		rerender(store:getStateVersion())
	end)

	local unsubscribeOnScroll = store:subscribe(VirtualStoreSubscription.Scroll, function()
		if props.onScroll then
			props.onScroll(store:getScrollOffset())
		end
	end)

	local unsubscribeOnScrollEnd = store:subscribe(VirtualStoreSubscription.ScrollEnd, function()
		if props.onScrollEnd then
			props.onScrollEnd()
		end
	end)

	-- State
	local range = useRange(store, rerender)

	local totalSize = derive(function()
		rerender()
		return store:getTotalSize()
	end)

	-- Effects
	effect(function()
		local length = #props.data()
		store:setElementsCount(length, props.shift)
	end)

	-- Cleanup
	cleanup(function()
		unsubscribeStoreState()
		unsubscribeOnScroll()
		unsubscribeOnScrollEnd()
		resizer:dispose()
		scroller:dispose()
	end)

	return {
		store = store,
		resizer = resizer,
		scroller = scroller,
		rerender = rerender,
		range = range,
		totalSize = totalSize,
	}
end

return useListVirtualizer
