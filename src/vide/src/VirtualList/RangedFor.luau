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

local function RangedFor<T>(props: Props<T>)
	local cache: { [number]: CachedNode<T> } = {}

	cleanup(function()
		for _, node in cache do
			node.dispose()
		end
	end)

	return derive(function()
		local data = props.data()
		local range = props.range()

		local startIndex = range[1]
		local endIndex = range[2]

		for index, node in cache do
			if data[index] == nil or index < startIndex or index > endIndex then
				node.dispose()
				cache[index] = nil
			end
		end

		for i = startIndex, endIndex do
			local value = data[i]
			local node = cache[i]

			if node == nil then
				local src = source(value)
				local destroy, element = root(function()
					return props.render(src, i)
				end)

				cache[i] = {
					source = src,
					previous = value,
					element = element,
					dispose = destroy,
				}
			elseif node.previous ~= value then
				node.source(value)
			end
		end

		local elements = table.create(endIndex - startIndex)
		for _, node in cache do
			table.insert(elements, node.element)
		end

		return elements
	end)
end

return RangedFor
