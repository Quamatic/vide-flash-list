local vide = require(script.Parent.Parent.Parent.vide)

local source = vide.source
local root = vide.root
local derive = vide.derive
local cleanup = vide.cleanup

type RenderedNode<T> = {
	data: vide.Source<T>,
	element: Instance,
	previous: T,
	destroy: () -> (),
}

export type Props<T> = {
	each: () -> { T },
	range: () -> { number },
	render: (data: () -> T, index: number) -> Instance,
}

local function RangedFor<T>(props: Props<T>)
	local cache: { [number]: RenderedNode<T> } = {}
	local render = props.render

	cleanup(function()
		for _, node in cache do
			node.destroy()
		end
	end)

	return derive(function()
		local list = props.each()
		local range = props.range()
		local startIndex = range[1]
		local endIndex = range[2]
		local valid = {}

		for index = startIndex, endIndex do
			local value = cache[index]
			local data = list[index]

			if value == nil then
				local src = source(data)

				local destroy, element = root(function()
					return render(src, index)
				end)

				cache[index] = {
					data = src,
					destroy = destroy,
					previous = data,
					element = element,
				}
			elseif data ~= value.previous then
				value.previous = data
				value.data(data)
			end

			valid[index] = true
		end

		for index, value in cache do
			if not valid[index] then
				value.destroy()
				cache[index] = nil
			end
		end

		local elements = table.create(#cache)

		for _, cache in cache do
			table.insert(elements, cache.element)
		end

		return elements
	end)
end

return RangedFor
