local vide = require(script.Parent.Parent.Parent.vide)

local source = vide.source
local derive = vide.derive
local root = vide.root
local cleanup = vide.cleanup

type CachedNode<T> = {
	source: vide.Source<T>,
	previous: T,
	element: GuiObject,
	dispose: () -> (),
}

export type Props<T> = {
	data: () -> { T },
	range: () -> { number },
	render: (data: () -> T, index: number) -> GuiObject,
}

-- TODO: Possibly recycle elements.

local function RangedFor<T>(props: Props<T>)
	local render = props.render

	local cache: { [number]: CachedNode<T> } = {}

	-- Cleanup nodes on unmount
	cleanup(function()
		for _, node in cache do
			node.dispose()
		end
	end)

	return derive(function()
		local data = props.data()
		local range = props.range()

		local startIndex, endIndex = range[1], range[2]

		for index, node in cache do
			if data[index] == nil or index < startIndex or index > endIndex then
				node.dispose()
				cache[index] = nil
			end
		end

		local elements = table.create(endIndex - startIndex + 1)

		-- Iterate through the range
		for i = startIndex, endIndex do
			local value = data[i]
			local node = cache[i]

			if node == nil then
				-- Create new node
				local src = source(value)

				local dispose, element = root(function()
					return render(src, i)
				end)

				node = {
					source = src,
					previous = value,
					element = element,
					dispose = dispose,
				}

				cache[i] = node
			elseif node.previous ~= value then
				-- Update previous value
				node.previous = value
				node.source(value)
			end

			table.insert(elements, node.element)
		end

		return elements
	end)
end

return RangedFor
