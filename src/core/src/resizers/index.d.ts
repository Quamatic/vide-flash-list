import VirtualStore from "../VirtualStore";

interface BaseResizer {
	/**
	 * Observes the size changes of the given viewport.
	 */
	observeViewport(viewport: GuiObject): void;
	/**
	 * Disposes of the resizer. This should be called when the resizer is no longer needed.
	 */
	dispose(): void;
}

interface ListResizer extends BaseResizer {
	/**
	 * Observes the size changes of an item.
	 *
	 * @param element The element to observe.
	 * @param index The index of the item.
	 * @returns A cleanup function that should be called when the item is no longer needed. (i.e., deleted or out of view).
	 */
	observeItem(element: GuiObject, index: number): () => void;
}

interface ListResizerConstructor {
	/**
	 * @param store The {@link VirtualStore | virtual store} to use.
	 * @param horizontal `true` if the list is horizontal. This affects how item sizes are observed (`X` values if horizontal, `Y` otherwise)
	 */
	new (store: VirtualStore, horizontal: boolean): ListResizer;
}

export const ListResizer: ListResizerConstructor;

interface GridResizer extends BaseResizer {
	/**
	 * Observes the size changes of an item.
	 *
	 * @param element The element to observe.
	 * @param rowIndex The row index of the item.
	 * @param colIndex The column index of the item.
	 * @returns A cleanup function that should be called when the item is no longer needed. (i.e., deleted or out of view).
	 */
	observeItem(element: GuiObject, rowIndex: number, colIndex: number): () => void;
}

interface GridResizerConstructor {
	/**
	 * @param vStore The store that manages the vertical axis.
	 * @param hStore The store that manages the horizontal axis.
	 */
	new (vStore: VirtualStore, hStore: VirtualStore): GridResizer;
}

export const GridResizer: GridResizerConstructor;
