import { Overscan } from "./types";
import type VirtualStoreSubscription from "./VirtualStoreSubscription";

type StateVersion = readonly [];

interface CacheSnapshot {
	sizes: number[];
	defaultItemSize: number;
}

interface VirtualStore {
	/**
	 * Returns the current version of the state as a table reference.
	 */
	getStateVersion(): StateVersion;
	/**
	 * Returns a snapshot of the cache.
	 */
	getCacheSnapshot(): CacheSnapshot;
	/**
	 * Returns the total amount of jumps that have been performed over the lifetime of the store.
	 */
	getJumpCount(): number;
	/**
	 * Returns the rendering range of elements (start - end).
	 */
	getRange(): readonly [startIndex: number, endIndex: number];
	/**
	 * Returns the first currently rendered index.
	 */
	findStartIndex(): number;
	/**
	 * Returns the last currently rendered index.
	 */
	findEndIndex(): number;
	/**
	 * Returns `true` if this index has not been measured yet (i.e., hasn't come into view before).
	 */
	isUnmeasuredItem(index: number): boolean;
	/**
	 * Sets the current size of the viewport.
	 */
	setViewportSize(size: number): void;
	/**
	 * Returns the current scroll offset.
	 */
	getScrollOffset(): number;
	/**
	 * Returns `true` if the current scroll direction isn't idle. (i.e., the user is scrolling).
	 */
	isScrolling(): boolean;
	/**
	 * Returns the current start margin (the space that takes place before rendering).
	 */
	getStartMargin(): number;
	/**
	 * Returns the offset of the given index.
	 */
	getItemOffset(index: number): number;
	/**
	 * Returns the size of the given index.
	 */
	getItemSize(index: number): number;
	/**
	 * Returns the total area that all of the elements take up.
	 *
	 * Note that this can change as the user scrolls, as elements sizes are cached and not known until received - making
	 * it dynamic.
	 */
	getTotalSize(): number;
	/**
	 * Updates the current scroll offset.
	 */
	setScrollOffset(scrollOffset: number): void;
	/**
	 * Notifies the store that scrolling has stopped.
	 */
	notifyScrollEnded(): void;
	/**
	 * Updates the given array of items with a new size.
	 */
	updateItemSizes(items: [index: number, size: number][]): void;
	/**
	 * Sets the current amount of elements to store.
	 *
	 * Note that the store takes into account the previous length, so items will be removed or added dependig on the difference.
	 *
	 * @param elementsCount The new element count
	 * @param shift If the store should shift the item into view.
	 */
	setElementsCount(elementsCount: number, shift: boolean): void;
	/**
	 * Sets the starting margin, which is the space at the top before rendering calcuations take place.
	 *
	 * This is useful for creating something like a header, which does not need to be taken into account during the process.
	 */
	setStartMargin(startMargin: number): void;
	/**
	 * Sets the current scroll mode to manual. Use this when performing imperative scrolling (i.e., scroll changes)
	 * that are not performed by the user.
	 */
	setManualScroll(): void;
	/**
	 * Prepares the store for an animated scroll, freezing the items within the scroll range
	 * to create a seamless feeling.
	 *
	 * Note that this can be quite performance intensive, especially depending on how large the list is. It is
	 * best to not abuse scroll animations, as doing so may defeat the purpose of a virtual container.
	 *
	 * @param targetOffset The offset the animation will scroll to. This is used to calcuation the range to freeze the items between it.
	 */
	prepareForAnimatedScroll(targetOffset: number): void;
	/**
	 * Subscribes to a {@link VirtualStoreSubscription | virtual store subscription}.
	 *
	 * @example
	 * Multiple fields can be subscribed to at once due to the subscriptions being in binary. For example, this will
	 * be called when both subscriptions are called at once:
	 * ```
	 * store.subscribe(VirtualStoreSubscription.VirtualStateUpdated + VirtualStoreSubscription.SizeUpdated, () => {
	 * 	 print("state and size were both updated!")
	 * })
	 * ```
	 */
	subscribe(target: number, callback: (shouldSync: boolean) => void): () => void;
}

interface VirtualStoreConfig {
	/**
	 * The initial amount of elements to store.
	 */
	elementsCount: number;
	/**
	 * The default size of items.
	 */
	itemSize?: number;
	/**
	 * The overscan to use.
	 */
	overscan?: Overscan;
	/**
	 * The spacing between items.
	 */
	spacing?: number;
	/**
	 * A cache snapshot to initialize from.
	 */
	cacheSnapshot?: CacheSnapshot;
	/**
	 * If item sizes should be estimates. This will calculate the average between them.
	 */
	shouldAutoEstimateItemSize?: boolean;
}

interface VirtualStoreConstructor {
	new (config: VirtualStoreConfig): VirtualStore;
}

declare const VirtualStore: VirtualStoreConstructor;

export = VirtualStore;
