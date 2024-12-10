local GridScrollerConstructors = {}
local GridScroller = {}
GridScroller.__index = GridScroller

-- Type exports

export type GridScroller = typeof(setmetatable({} :: {}, GridScroller))

function GridScrollerConstructors.new(): GridScroller
	return setmetatable({}, GridScroller)
end

return GridScrollerConstructors
