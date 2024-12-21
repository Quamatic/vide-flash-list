import React from "@rbxts/react";
import { ListScrollToIndexConfig, Overscan } from "@rbxts/virtua";

export interface VirtualListHandle {
	/**
	 * Scrolls to the given offset.
	 */
	scrollTo: (offset: number) => void;
	/**
	 * Scrolls by a relative offset from the current position.
	 */
	scrollBy: (offset: number) => void;
	/**
	 * Scrolls to the given index.
	 *
	 * @param index The index to scroll to.
	 * @param config The {@link ListScrollToIndexConfig | config} to use.
	 */
	scrollToIndex: (index: number, config?: ListScrollToIndexConfig) => void;
}

export interface VirtualListProps<T extends defined> {
	/**
	 * The data to use for rendering.
	 */
	data: T[];
	/**
	 * The element render prop.
	 *
	 * @param data The data of the element.
	 * @param index The index of the element.
	 */
	render: (data: T, index: number) => React.ReactNode;
	/**
	 * The default item size.
	 */
	itemSize: number;
	/**
	 * The overscan to use for rendering.
	 */
	overscan?: Overscan;
	/**
	 * `true` if the list should be horizontally rendered.
	 */
	horizontal?: boolean;
	/**
	 * `true` if updates in data should cause correction shifting to the scroll.
	 */
	shift?: boolean;
	/**
	 * The spacing between each element.
	 */
	spacing?: number;
	/**
	 * The spacing at the top that takes place before rendering.
	 */
	startMargin?: number;
	/**
	 * Callback that is fired when the scroll offset changes.
	 *
	 * @param offset The new scroll offset.
	 */
	onScroll?: (offset: number) => void;
	/**
	 * Callback that is fired when scrolling has stopped.
	 */
	onScrollEnd?: () => void;
}

/**
 * A component that renders a virtualized list.
 */
declare function VirtualList<T extends defined>(
	props: React.PropsWithoutRef<VirtualListProps<T>> & React.RefAttributes<VirtualListHandle>,
): React.ReactNode;

export { VirtualList };
