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
	getCacheSnapshot(): CacheSnapshot;
	getRange(): readonly [startIndex: number, endIndex: number];
	findStartIndex(): number;
	findEndIndex(): number;
	getItemOffset(index: number): number;
	getItemSize(index: number): number;
	getTotalSize(): number;
	setScrollOffset(scrollOffset: number): void;
	subscribe(target: number, callback: (shouldSync: boolean) => void): () => void;
}

interface VirtualStoreConstructor {
	new (
		elementsCount: number,
		itemSize?: number,
		overscan?: number,
		cacheSnapshot?: CacheSnapshot,
		shouldAutoEstimateItemSize?: boolean,
	): VirtualStore;
}

declare const VirtualStore: VirtualStoreConstructor;

export = VirtualStore;
