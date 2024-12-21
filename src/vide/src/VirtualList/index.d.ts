import Vide from "@rbxts/vide";
import { Overscan } from "@rbxts/virtua";

export interface VirtualizerHandle {
	scrollTo: (offset: number) => void;
	scrollBy: (offset: number) => void;
	scrollToIndex: (index: number) => void;
}

export interface VirtualListProps<T extends defined> {
	data: () => T[];
	children: (data: () => T, index: number) => Vide.Node;
	ref: (handle: VirtualizerHandle) => void;
	itemSize: number;
	overscan?: Overscan;
	horizontal?: boolean;
	shift?: boolean;
	spacing?: number;
	onScroll?: (offset: number) => void;
	onScrollEnd?: () => void;
}

/**
 * An element that renders a virtual list.
 */
declare function VirtualList<T extends defined>(props: VirtualListProps<T>): ScrollingFrame;

export { VirtualList };
