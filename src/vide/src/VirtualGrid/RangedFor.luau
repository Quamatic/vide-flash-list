local vide = require(script.Parent.Parent.Parent.vide)

local source = vide.source
local derive = vide.derive
local root = vide.root
local cleanup = vide.cleanup

type CachedNode<T> = {
	source: vide.Source<T>,
	previous: T,
	row: number,
	column: number,
	element: GuiObject,
	dispose: () -> (),
}

export type Props<T> = {
	data: () -> { T },
	rowRange: () -> { number },
	colRange: () -> { number },
	columns: () -> number,
	render: (data: () -> T, rowIndex: number, colIndex: number) -> GuiObject,
}

-- TODO: Possibly recycle elements.

local function RangedFor<T>(props: Props<T>)
	local render = props.render

	local cache: { [string]: CachedNode<T> } = {}

	cleanup(function()
		for _, node in cache do
			node.dispose()
		end
	end)

	return derive(function()
		local data = props.data()
		local rowRange = props.rowRange()
		local columnRange = props.colRange()

		local columns = props.columns()
		local startRowIndex, endRowIndex = rowRange[1], rowRange[2]
		local startColumnIndex, endColumnIndex = columnRange[1], columnRange[2]

		-- Dispose nodes that are out of range
		for key, node in cache do
			local row = node.row
			local column = node.column

			if row < startRowIndex or row > endRowIndex or column < startColumnIndex or column > endColumnIndex then
				node.dispose()
				cache[key] = nil
			end
		end

		-- Create an exact allocated array of elements
		local elements = table.create((endRowIndex - startRowIndex + 1) * (endColumnIndex - startColumnIndex + 1))

		for row = startRowIndex, endRowIndex do
			for column = startColumnIndex, endColumnIndex do
				-- Cache keys are used here for more "unique" identification.
				-- If the index is used instead then it'll result in miscalculation because column count can change.
				local key = `{row}-{column}`

				local node = cache[key]
				local value = data[(row - 1) * columns + column]

				if node == nil then
					-- Create new node, or recycle one.
					local src = source(value)

					local dispose, element = root(function()
						return render(src, row, column)
					end)

					node = {
						source = src,
						previous = value,
						row = row,
						column = column,
						element = element,
						dispose = dispose,
					}

					cache[key] = node
				elseif node.previous ~= value then
					-- Update previous value
					node.previous = value
					node.source(value)
				end

				table.insert(elements, node.element)
			end
		end

		return elements
	end)
end

return RangedFor
