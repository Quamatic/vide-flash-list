local useListVirtualizer = require(script.useListVirtualizer)

local VirtualList = require(script.VirtualList)
export type VirtualizedListHandle = VirtualList.VirtualizerHandle

return table.freeze({
	useListVirtualizer = useListVirtualizer,
	VirtualList = VirtualList,
})
