export type VirtualStoreActionPayload = {
	type: "scroll",
	offset: number,
} | {
	type: "scroll-end",
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
} | {
	type: "manual-scroll-initiated",
} | {
	type: "manual-scroll-animation-initiated",
	offset: number,
}

local VirtualStoreAction = {
	Scroll = "scroll" :: "scroll",
	ScrollEnd = "scroll-end" :: "scroll-end",
	ItemsChanged = "items-changed" :: "items-changed",
	ViewportResized = "viewport-resized" :: "viewport-resized",
	ItemResized = "item-resized" :: "item-resized",
	ManualScrollInitiated = "manual-scroll-initiated" :: "manual-scroll-initiated",
	ManualScrollAnimationInitiated = "manual-scroll-animation-initiated" :: "manual-scroll-animation-initiated",
}

return VirtualStoreAction
