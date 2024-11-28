local store = require(script.Parent.store)

local VirtualStoreAction = require(script.Parent.VirtualStoreAction)

type Scroller = {
	update: (position: Vector2) -> (),
	scrollTo: (offset: number) -> (),
}

local function createScroller(store: store.VirtualStore, horizontal: boolean): Scroller
	local function scheduleImperativeScroll(getTargetOffset: () -> number) end

	return {
		update = function(position)
			store.dispatch({
				type = VirtualStoreAction.Scroll,
				offset = if horizontal then position.X else position.Y,
			})
		end,

		scrollTo = function(offset)
			scheduleImperativeScroll(function()
				return offset
			end)
		end,
	}
end

return {
	createScroller = createScroller,
}
