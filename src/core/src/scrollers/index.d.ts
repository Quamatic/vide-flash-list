import { ListScrollToIndexConfig } from "../types";
import VirtualStore from "../VirtualStore";

interface BaseScroller {
	/**
	 * Observes the canvas position changes of the given scroll element.
	 */
	observe(element: ScrollingFrame): void;
	/**
	 * Disposes of the scroller. This should be called when the resizer is no longer needed.
	 */
	dispose(): void;
	/**
	 * Fixes "jumps" in the scrolling. This should be called when the jump count of the store changes.
	 */
	fixScrollJump(): void;
}

interface ListScroller extends BaseScroller {
	/**
	 * Scrolls to the given offset.
	 */
	scrollTo(offset: number): void;
	/**
	 * Scrolls *by* the given offset, adjusting the current scroll offset.
	 */
	scrollBy(offset: number): void;
	/**
	 * Scrolls to the given item index.
	 *
	 * @param index The index to scroll to
	 * @param config Optional {@link ListScrollToIndexConfig | configuration} to use.
	 */
	scrollToIndex(index: number, config?: ListScrollToIndexConfig): void;
}

interface ListScrollerConstructor {
	/**
	 * @param store The store to use.
	 */
	new (store: VirtualStore): ListScroller;
}

export const ListScroller: ListScrollerConstructor;

interface GridScroller extends BaseScroller {
	scrollTo(offsetX: number, offsetY: number): void;
	scrollBy(offsetX: number, offsetY: number): void;
	scrollToIndex(indexX: number, indexY: number, config: {}): void;
}

interface GridScrollerConstructor {
	new (vStore: VirtualStore, hStore: VirtualStore): GridScroller;
}

export const GridScroller: GridScrollerConstructor;
