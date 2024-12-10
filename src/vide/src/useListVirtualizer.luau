local Vide = require(script.Parent.Parent.vide)

local Virtua = require(script.Parent.Parent.Virtua)
type VirtualStore = Virtua.VirtualStore
type ListResizer = Virtua.ListResizer
type ListScroller = Virtua.ListScroller

local types = require(script.Parent.types)
type Derivable<T> = types.Derivable<T>

local computed = require(script.Parent.computed)
local isSameRange = require(script.Parent.isSameRange)

local VirtualStore = Virtua.VirtualStore
local VirtualStoreSubscription = Virtua.VirtualStoreSubscription
local ListResizer = Virtua.ListResizer
local ListScroller = Virtua.ListScroller

local source = Vide.source
local derive = Vide.derive
local effect = Vide.effect
local cleanup = Vide.cleanup

export type UseVirtualizerProps<T> = {
	data: () -> { T },
	itemSize: number,
	overscan: number,
	horizontal: boolean,
	shift: boolean?,
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
	local store = VirtualStore.new(#props.data(), props.itemSize, props.overscan, nil, false)
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

	-- Computed state
	local range = computed(function(previous)
		rerender()

		local next = store:getRange()
		if previous and isSameRange(previous, next) then
			return previous
		end

		return next
	end)

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
