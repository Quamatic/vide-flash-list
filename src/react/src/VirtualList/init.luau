local Virtua = require(script.Parent.Parent.Virtua)
local React = require(script.Parent.Parent.React)
local ReactRoblox = require(script.Parent.Parent.ReactRoblox)

local VirtualStore = Virtua.VirtualStore
local VirtualStoreSubscription = Virtua.VirtualStoreSubscription
local ListResizer = Virtua.ListResizer
local ListScroller = Virtua.ListScroller

local ListItem = require(script.ListItem)

local flushSync = ReactRoblox.flushSync
local useEffect = React.useEffect
local useImperativeHandle = React.useImperativeHandle
local useRerender = require(script.Parent.useRerender)
local useStatic = require(script.Parent.useStatic)
local useLatestRef = require(script.Parent.useLatestRef)

local e = React.createElement

export type VirtualizerHandle = {
	scrollTo: (offset: number) -> (),
	scrollBy: (offset: number) -> (),
	scrollToIndex: (offset: number, config: Virtua.ListScrollToIndexConfig?) -> (),
}

export type Props<T> = {
	data: { T },
	render: (data: T, index: number) -> React.ReactNode,
	itemSize: number,
	overscan: Virtua.Overscan?,
	horizontal: boolean?,
	shift: boolean?,
	spacing: number?,
	startMargin: number?,
	onScroll: (offset: number) -> ()?,
	onScrollEnd: () -> ()?,
}

--[[
	A component that renders a virtualized list.
]]
local VirtualList = React.forwardRef(function(props: Props<unknown>, ref: React.Ref<VirtualizerHandle>)
	local data = props.data
	local horizontal = not not props.horizontal
	local shift = props.shift

	-- Static data
	local static = useStatic(function()
		local store = VirtualStore.new({
			elementsCount = #data,
			itemSize = props.itemSize,
			overscan = props.overscan,
			spacing = props.spacing,
			shouldAutoEstimateItemSize = false,
		})

		return {
			store = store,
			resizer = ListResizer.new(store, horizontal),
			scroller = ListScroller.new(store, horizontal),
		}
	end)

	local store = static.store
	local resizer = static.resizer
	local scroller = static.scroller

	-- Check for changes in data
	if #data ~= store:getElementsCount() then
		store:setElementsCount(#data, shift)
	end

	local rerender = useRerender(store)

	local onScroll = useLatestRef(props.onScroll)
	local onScrollEnd = useLatestRef(props.onScrollEnd)

	-- Subscriptions
	useEffect(function()
		local unsubscribeStore = store:subscribe(VirtualStoreSubscription.VirtualStateUpdated, function(shouldSync)
			if shouldSync then
				flushSync(rerender)
			else
				rerender()
			end
		end)

		local unsubscribeOnScroll = store:subscribe(VirtualStoreSubscription.Scroll, function()
			if onScroll.current then
				onScroll.current(store:getScrollOffset())
			end
		end)

		local unsubscribeOnScrollEnd = store:subscribe(VirtualStoreSubscription.ScrollEnd, function()
			if onScrollEnd.current then
				onScrollEnd.current()
			end
		end)

		return function()
			unsubscribeStore()
			unsubscribeOnScroll()
			unsubscribeOnScrollEnd()
			resizer:dispose()
			scroller:dispose()
		end
	end)

	-- Fix jumps in scrolling
	useEffect(function()
		scroller:fixScrollJump()
	end, { store:getJumpCount() })

	-- Provide virtualizer handle
	useImperativeHandle(ref, function()
		return {
			scrollTo = function(offset)
				scroller:scrollTo(offset)
			end,

			scrollBy = function(offset)
				scroller:scrollBy(offset)
			end,

			scrollToIndex = function(index, config)
				scroller:scrollToIndex(index, config)
			end,
		} :: VirtualizerHandle
	end, {})

	-- Create items
	local range = store:getRange()
	local startIndex, endIndex = range[1], range[2]
	local items: { React.ReactNode } = table.create(endIndex - startIndex + 1)

	for index = startIndex, endIndex do
		table.insert(
			items,
			e(ListItem, {
				key = `ListItem_{index}`,
				index = index,
				offset = store:getItemOffset(index),
				resizer = resizer,
				horizontal = horizontal,
			}, props.render(data[index], index))
		)
	end

	return e("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		ScrollingDirection = if horizontal then Enum.ScrollingDirection.X else Enum.ScrollingDirection.Y,

		CanvasSize = if horizontal
			then UDim2.fromOffset(store:getTotalSize(), 0)
			else UDim2.fromOffset(0, store:getTotalSize()),

		ElasticBehavior = Enum.ElasticBehavior.WhenScrollable,
		BackgroundTransparency = 1,

		-- Assign ref
		ref = function(element: ScrollingFrame?)
			if not element then
				return
			end

			resizer:observeViewport(element)
			scroller:observe(element)
		end,
	}, items)
end)

return VirtualList
