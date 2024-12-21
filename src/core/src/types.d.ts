export interface Overscan {
	/**
	 * Determines how overscan is calculated.
	 *
	 * - `"elements"` will overscan by element count, regardless of size.
	 * - `"px"` will overscan by pixels, which can be useful for larger item sizes.
	 */
	type: "elements" | "px";
	/**
	 * The amount of overscan.
	 */
	value: number;
}

/**
 * Defines a custom animator for controlling scrolling behavior during imperative scroll operations.
 *
 * The provided `update` function should be called with a progress
 * value between `[0, 1]`, representing the animation's progress.
 * The scrolling position is interpolated based on this value.
 *
 * The animator must return a cleanup function, which is
 * is invoked once the scrolling operation is complete.
 */
export type ScrollAnimator = (update: (progress: number) => void) => () => void;

export type ScrollToIndexAlign = "nearest" | "start" | "center" | "end";

export interface ListScrollToIndexConfig {
	/**
	 * Determines how the target item should be aligned within the viewport
	 * when it is scrolled into view.
	 *
	 * - `"nearest"` will align the item to the closest edge of the viewport based on
	 * its current position and the offset. If the item is alread visible,
	 * no scrolling occurs unless necessary to bring it closer to the viewport.
	 * - `"start"` will position the item at the top of the viewport.
	 * - `"end"` will position the item at the bottom of the viewport.
	 * - `"center"` will position the item at the center of the viewport.
	 */
	align?: ScrollToIndexAlign;
	/**
	 * Additional offset to apply to the final offset.
	 */
	offset?: number;
	/**
	 * A custom animator to control the scrolling behavior.
	 */
	animator?: ScrollAnimator;
}

export interface GridScrollToIndexConfig {}
