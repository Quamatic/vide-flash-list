import VirtualStore from "./VirtualStore";
import { ListScroller, GridScroller } from "./scrollers";
import { ListResizer, GridResizer } from "./resizers";
import { Overscan, ScrollAnimator, ScrollToIndexAlign, ListScrollToIndexConfig } from "./types";

export = Virtua;
export as namespace Virtua;

declare namespace Virtua {
	// Store
	export { VirtualStore };

	// Scrollers
	export { ListScroller, GridScroller };

	// Resizers
	export { ListResizer, GridResizer };

	// Types
	export type { Overscan, ScrollAnimator, ScrollToIndexAlign, ListScrollToIndexConfig };
}
