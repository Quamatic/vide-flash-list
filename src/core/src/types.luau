export type Overscan = {
	type: "elements" | "px",
	amount: number,
}

export type ScrollAnimator = (update: (progress: number) -> ()) -> () -> ()

export type ScrollToIndexAlign = "nearest" | "start" | "center" | "end"

export type ScrollToIndexConfig = {
	align: ScrollToIndexAlign?,
	offset: number?,
	animator: ScrollAnimator?,
}

return nil
