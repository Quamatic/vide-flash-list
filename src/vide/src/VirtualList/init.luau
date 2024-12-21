local vide = require(script.Parent.Parent.vide)

local Virtua = require(script.Parent.Parent.Virtua)
type Overscan = Virtua.Overscan

local types = require(script.Parent.types)
type Derivable<T> = types.Derivable<T>

local useListVirtualizer = require(script.Parent.useListVirtualizer)

local RangedFor = require(script.RangedFor)

local create = vide.create
local source = vide.source
local derive = vide.derive
local effect = vide.effect
local action = vide.action
local cleanup = vide.cleanup

export type VirtualizerHandle = {
	findStartIndex: () -> number,
	findEndIndex: () -> number,
	getItemOffset: (index: number) -> (),
	getItemSize: (index: number) -> (),
	scrollTo: (offset: number) -> (),
	scrollBy: (offset: number) -> (),
	scrollToIndex: (index: number) -> (),
}

export type Props<T> = {
	data: () -> { T },
	children: (data: () -> T, index: number) -> GuiObject,
	ref: (handle: VirtualizerHandle) -> ()?,
	overscan: Overscan,
	itemSize: number,
	shift: boolean?,
	horizontal: boolean,
	spacing: number?,
	onScroll: (offset: number) -> ()?,
	onScrollEnd: () -> ()?,
	style: { [string]: unknown }?,
}

local function VirtualList<T>(props: Props<T>)
	local horizontal = props.horizontal
	local children = props.children
	local virtualizer = useListVirtualizer(props)

	return create "ScrollingFrame" {
		Size = UDim2.fromScale(1, 1),

		props.style,

		ScrollingDirection = if horizontal then Enum.ScrollingDirection.X else Enum.ScrollingDirection.Y,

		CanvasSize = function()
			return if horizontal
				then UDim2.new(0, virtualizer.totalSize(), 1, 0)
				else UDim2.new(1, 0, 0, virtualizer.totalSize())
		end,

		ElasticBehavior = Enum.ElasticBehavior.WhenScrollable,
		BackgroundTransparency = 1,

		-- Children
		RangedFor {
			data = props.data,
			range = virtualizer.range,
			render = function(data, index)
				local element = source(nil :: GuiObject?)

				local offset = derive(function()
					virtualizer.rerender()

					local offset = virtualizer.store:getItemOffset(index)
					return if horizontal then UDim2.fromOffset(offset, 0) else UDim2.fromOffset(0, offset)
				end)

				effect(function()
					local element = element()
					if element then
						cleanup(virtualizer.resizer:observeItem(index, element))
					end
				end)

				return create "Frame" {
					Name = `ListItem/{index}`,
					Size = if horizontal then UDim2.fromScale(0, 1) else UDim2.fromScale(1, 0),
					AutomaticSize = if horizontal then Enum.AutomaticSize.X else Enum.AutomaticSize.Y,
					Position = offset,
					BackgroundTransparency = 1,

					-- Children
					children(data, index),

					-- Ref
					action(element),
				}
			end,
		} :: any,

		-- Ref
		action(function(ref)
			virtualizer.resizer:observeViewport(ref)
			virtualizer.scroller:observe(ref :: ScrollingFrame)
		end),
	}
end

return VirtualList
