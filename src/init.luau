local VirtualList = require(script.VirtualList)

export type VirtualListHandle = VirtualList.VirtualListHandle

return table.freeze({
	VirtualList = VirtualList,
})
