local VirtualList = require(script.VirtualList)
export type VirtualListProps<T> = VirtualList.Props<T>
export type VirtualListHandle = VirtualList.VirtualListHandle

local store = require(script.store)
export type VirtualStore = store.VirtualStore

local scroller = require(script.scroller)
export type Scroller = scroller.Scroller

local types = require(script.types)
export type ScrollAnimator = types.ScrollAnimator
export type ScrollToIndexParams = types.ScrollToIndexParams

return table.freeze({
	-- Core
	createVirtualStore = store.createVirtualStore,
	createScroller = scroller.createScroller,
	VirtualStoreAction = require(script.VirtualStoreAction),
	VirtualStoreSubscription = require(script.VirtualStoreSubscription),

	-- Components
	VirtualList = VirtualList,
})
