export type VirtualStoreActionPayload = {
	type: "scroll",
	offset: number,
} | {
	type: "items-changed",
	length: number,
	shift: boolean?,
} | {
	type: "viewport-resized",
	size: Vector2,
} | {
	type: "item-resized",
	index: number,
	size: number,
}

local VirtualStoreAction = {
	Scroll = "scroll" :: "scroll",
	ItemsChanged = "items-changed" :: "items-changed",
	ViewportResized = "viewport-resized" :: "viewport-resized",
	ItemResized = "item-resized" :: "item-resized",
}

return VirtualStoreAction
