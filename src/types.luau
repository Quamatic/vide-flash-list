export type ScrollAnimator = (update: (progress: number) -> ()) -> () -> ()

export type ScrollToIndexAlign = "nearest" | "start" | "center" | "end"

export type ScrollToIndexParams = {
	align: ScrollToIndexAlign?,
	offset: number?,
	animator: ScrollAnimator?,
}

return nil
