local vide = require(script.Parent.Parent.vide)

local useGridVirtualizer = require(script.Parent.useGridVirtualizer)
type UseGridVirtualizerProps<T> = useGridVirtualizer.UseGridVirtualizerProps<T>

local RangedFor = require(script.RangedFor)

local create = vide.create
local source = vide.source
local derive = vide.derive
local effect = vide.effect
local action = vide.action
local cleanup = vide.cleanup

export type VirtualizerHandle = {}

export type Props<T> = UseGridVirtualizerProps<T> & {
	ref: (handle: VirtualizerHandle) -> (),
	children: (data: () -> T, rowIndex: number, colIndex: number) -> GuiObject,
}

local function VirtualGrid<T>(props: Props<T>)
	local ref = props.ref
	local children = props.children

	local grid = useGridVirtualizer(props)

	return create "ScrollingFrame" {
		Size = UDim2.fromScale(1, 1),

		ScrollingDirection = if props.columns ~= "auto" then Enum.ScrollingDirection.XY else Enum.ScrollingDirection.Y,
		CanvasSize = grid.totalSize,
		ElasticBehavior = Enum.ElasticBehavior.WhenScrollable,

		BackgroundTransparency = 1,

		-- Children
		RangedFor {
			data = props.data,
			rowRange = grid.rowRange,
			colRange = grid.colRange,
			columns = grid.columns,
			render = function(data, rowIndex, colIndex)
				local element = source(nil :: GuiObject?)

				local offset = derive(function()
					grid.vRerender()
					grid.hRerender()

					return grid.getItemOffset(rowIndex, colIndex)
				end)

				local size = derive(function()
					grid.vRerender()
					grid.hRerender()

					return grid.getItemSize(rowIndex, colIndex)
				end)

				-- Observe item
				effect(function()
					local element = element()
					if element then
						cleanup(grid.observeItem(element, rowIndex, colIndex))
					end
				end)

				return create "Frame" {
					Name = function()
						return `GridItem({rowIndex}/{colIndex})`
					end,

					Position = offset,
					Size = size,
					AutomaticSize = Enum.AutomaticSize.XY,
					BackgroundTransparency = 1,

					-- Children
					children(data, rowIndex, colIndex),

					-- Ref
					action(element),
				}
			end,
		},

		-- Ref
		action(grid.observeViewport),
	}
end

return VirtualGrid
