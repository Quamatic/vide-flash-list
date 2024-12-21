local vide = require(script.Parent.Parent.vide)

local Virtua = require(script.Parent.Parent.Virtua)
type VirtualStore = Virtua.VirtualStore
type Overscan = Virtua.Overscan
type GridResizer = Virtua.GridResizer
type GridScroller = Virtua.GridScroller

local VirtualStore = Virtua.VirtualStore
local VirtualStoreSubscription = Virtua.VirtualStoreSubscription
local GridResizer = Virtua.GridResizer
local GridScroller = Virtua.GridScroller

local useRange = require(script.Parent.useRange)

local source = vide.source
local effect = vide.effect
local derive = vide.derive
local cleanup = vide.cleanup
local untrack = vide.untrack

export type UseGridVirtualizerProps<T> = {
	--[[
		The data to be passed in. This determines the row and column count.
	]]
	data: () -> { T },
	--[[
		The estimated width of each cell.
	]]
	cellWidth: number,
	--[[
		The estimated height of each cell.
	]]
	cellHeight: number,
	--[[
		The number of rows.
	]]
	rows: number,
	--[[
		The number of columns.
	]]
	columns: "auto" | number,
	--[[
		The spacing between each row.
	]]
	rowSpacing: number?,
	--[[
		The spacing between each column.
	]]
	columnSpacing: number?,
	--[[
		The overscan rendering for the rows.
	]]
	rowOverscan: Overscan?,
	--[[
		The overscan rendering for the columns.
	]]
	columnOverscan: Overscan?,
	--[[
		If shfit should occur.
	]]
	shift: boolean?,
}

export type UseGridVirtualizerReturn = {
	--[[
		Source that can be used as a dependency within a scope for when the vertical virtual store updates.
	]]
	vRerender: () -> (),
	--[[
		Source that can be used as a dependency within a scope for when the horizontal virtual store updates.
	]]
	hRerender: () -> (),
	--[[
		The render range for the rows.
	]]
	rowRange: () -> { number },
	--[[
		The render range for the columns.
	]]
	colRange: () -> { number },
	--[[
		The total size of the grid.
	]]
	totalSize: () -> UDim2,
	--[[
		The total amount of columns.
	]]
	columns: () -> number,
	--[[
		Observes the viewport element (ScrollingFrame)
	]]
	observeViewport: (element: ScrollingFrame) -> (),
	--[[
		Observes an item element's size in the grid.
	]]
	observeItem: (element: GuiObject, rowIndex: number, colIndex: number) -> () -> (),
	--[[
		Returns the offset of the given item.
	]]
	getItemOffset: (rowIndex: number, colIndex: number) -> UDim2,
	--[[
		Returns the size of the given item.
	]]
	getItemSize: (rowIndex: number, colIndex: number) -> UDim2,
}

local function getColumnCount(totalCount: number, gridWidth: number, cellWidth: number, columns: "auto" | number)
	if typeof(columns) == "number" or gridWidth == 0 then
		if gridWidth == 0 then
			return 1 -- Viewport not initialized yet
		end

		return math.ceil(totalCount / columns :: number)
	end

	-- Automatic calculation
	return math.floor(gridWidth / cellWidth)
end

local function useGridVirtualizer<T>(props: UseGridVirtualizerProps<T>): UseGridVirtualizerReturn
	local columns: "auto" | number = props.columns
	local cellWidth = props.cellWidth

	-- Stores
	local initialCount = #props.data()

	local rowCount = source(1)
	local columnCount = source(1)

	local vStore = VirtualStore.new({
		elementsCount = math.ceil(initialCount / props.rows),
		itemSize = props.cellHeight,
		overscan = props.rowOverscan,
		spacing = props.rowSpacing,
	})

	local hStore = VirtualStore.new({
		elementsCount = getColumnCount(initialCount, 0, props.cellWidth, props.columns),
		itemSize = props.cellWidth,
		overscan = props.columnOverscan,
		spacing = props.columnSpacing,
	})

	local resizer = GridResizer.new(vStore, hStore)
	local scroller = GridScroller.new(vStore, hStore)

	-- Source
	local vRerender = source(vStore:getStateVersion())
	local hRerender = source(hStore:getStateVersion())

	-- Subscriptions
	local unsubscribeVStore = vStore:subscribe(VirtualStoreSubscription.VirtualStateUpdated, function()
		vRerender(vStore:getStateVersion())
	end)

	local unsubscribeHStore = hStore:subscribe(VirtualStoreSubscription.VirtualStateUpdated, function()
		hRerender(hStore:getStateVersion())
	end)

	local unsubscribeVSize = vStore:subscribe(VirtualStoreSubscription.ViewportSizeChanged, function()
		rowCount(1)
	end)

	local unsubscribeHSize = hStore:subscribe(VirtualStoreSubscription.ViewportSizeChanged, function()
		local gridWidth = hStore:getViewportSize()
		local calculatedColumnCount = getColumnCount(initialCount, gridWidth, cellWidth, columns)

		columnCount(calculatedColumnCount)
	end)

	-- State
	local rowRange = useRange(vStore, vRerender)
	local colRange = useRange(hStore, hRerender)

	local totalSize = derive(function()
		vRerender()
		hRerender()

		return UDim2.fromOffset(hStore:getTotalSize(), vStore:getTotalSize())
	end)

	-- Effects
	effect(function()
		local length = #props.data()
		local count = untrack(columnCount)
	end)

	-- Update column count
	effect(function()
		hStore:setElementsCount(columnCount(), props.shift)
	end)

	-- Cleanup
	cleanup(function()
		unsubscribeVStore()
		unsubscribeHStore()
		unsubscribeVSize()
		unsubscribeHSize()
		resizer:dispose()
		scroller:dispose()
	end)

	-- Utility
	local function observeViewport(element: ScrollingFrame)
		resizer:observeViewport(element)
		scroller:observe(element)
	end

	local function observeItem(element: GuiObject, rowIndex: number, colIndex: number)
		return resizer:observeItem(element, rowIndex, colIndex)
	end

	local function getItemOffset(rowIndex: number, colIndex: number)
		return UDim2.fromOffset(hStore:getItemOffset(colIndex), vStore:getItemOffset(rowIndex))
	end

	local function getItemSize(rowIndex: number, colIndex: number)
		if columns ~= "auto" then
			-- Return native size
			return UDim2.fromOffset(hStore:getItemSize(colIndex), vStore:getItemSize(rowIndex))
		else
			-- Return adjusted size
			local viewportWidth = hStore:getViewportSize()
			if viewportWidth == 0 then
				-- Not ideal, but there will be a case where the viewport hasn't calculated its size yet,
				-- so if this isn't here then it'll produce nan values.
				return UDim2.fromOffset(0, 0)
			end

			local columnCount = getColumnCount(initialCount, viewportWidth, props.cellWidth, props.columns)
			local cellWidth = (viewportWidth - (columnCount - 1) * (props.columnSpacing or 0)) / columnCount

			return UDim2.fromOffset(cellWidth, vStore:getItemSize(rowIndex))
		end
	end

	return {
		vRerender = vRerender,
		hRerender = hRerender,
		rowRange = rowRange,
		colRange = colRange,
		columns = columnCount,
		observeViewport = observeViewport,
		observeItem = observeItem,
		getItemOffset = getItemOffset,
		getItemSize = getItemSize,
		totalSize = totalSize,
	}
end

return useGridVirtualizer
