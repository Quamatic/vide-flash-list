-- "px" = used as a "draw distance" value
-- "elements" = will always render over the given amount regardless of element size.
export type Overscan = {
	type: "elements" | "px",
	amount: number,
}

export type ScrollAnimator = (update: (progress: number) -> ()) -> () -> ()

export type ScrollToIndexAlign = "nearest" | "start" | "center" | "end"

export type ListScrollToIndexConfig = {
	align: ScrollToIndexAlign?,
	offset: number?,
	animator: ScrollAnimator?,
}

export type GridScrollToIndexConfig = {
	offsetX: number?,
	offsetY: number?,
	alignX: ScrollToIndexAlign?,
	alignY: ScrollToIndexAlign?,
	animator: ScrollAnimator?,
}

return nil
