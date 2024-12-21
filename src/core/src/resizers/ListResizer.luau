local VirtualStore = require(script.Parent.Parent.VirtualStore)
type VirtualStore = VirtualStore.VirtualStore

local ListResizer = {}
ListResizer.__index = ListResizer

-- Type exports

export type ListResizer = typeof(setmetatable(
	{} :: {
		_store: VirtualStore,
		_horizontal: boolean,
		_viewportConnection: RBXScriptConnection?,
		_itemConnections: { [GuiObject]: RBXScriptConnection },
		_queuedElementUpdates: { [number]: number },
		_queuedElementUpdatesCount: number,
		_batching: boolean,
		_performBatchedUpdate: () -> (),
	},
	ListResizer
))

-- Private

function ListResizer._prepareBatchedUpdate(self: ListResizer)
	if not self._batching then
		self._batching = true
		task.defer(self._performBatchedUpdate)
	end
end

-- Public

function ListResizer.observeViewport(self: ListResizer, viewport: GuiObject)
	self._viewportConnection = viewport:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		-- Update viewport size
		local size = if self._horizontal then viewport.AbsoluteSize.X else viewport.AbsoluteSize.Y
		self._store:setViewportSize(size)
	end)
end

function ListResizer.observeItem(self: ListResizer, index: number, element: GuiObject)
	local function update()
		-- Skip zero-sized elements
		if not element.Parent then
			return
		end

		-- Queue update (or overwrite)
		local size = if self._horizontal then element.AbsoluteSize.X else element.AbsoluteSize.Y

		if not self._queuedElementUpdates[index] then
			self._queuedElementUpdates[index] = size
			self._queuedElementUpdatesCount += 1
		end

		-- Prepare batch
		self:_prepareBatchedUpdate()
	end

	local connection = element:GetPropertyChangedSignal("AbsoluteSize"):Connect(update)
	self._itemConnections[element] = connection

	-- Call update immediately
	update()

	return function()
		if connection.Connected then
			connection:Disconnect()
			self._itemConnections[element] = nil
		end
	end
end

function ListResizer.dispose(self: ListResizer)
	if self._viewportConnection then
		self._viewportConnection:Disconnect()
		self._viewportConnection = nil
	end

	for _, connection in self._itemConnections do
		connection:Disconnect()
	end

	table.clear(self._itemConnections)
end

-- Constructors

local function new(store: VirtualStore, horizontal: boolean): ListResizer
	local self = setmetatable({
		_store = store,
		_horizontal = horizontal,
		_itemConnections = {},
		_queuedElementUpdates = {} :: { [number]: number },
		_queuedElementUpdatesCount = 0,
		_batching = false,
	}, ListResizer)

	self._performBatchedUpdate = function()
		if not self._batching then
			return
		end

		local resizes = table.create(self._queuedElementUpdatesCount)
		for index, size in self._queuedElementUpdates do
			table.insert(resizes, { index, size })
		end

		self._store:updateItemSizes(resizes)
		self._queuedElementUpdatesCount = 0
		table.clear(self._queuedElementUpdates)

		self._batching = false
	end

	return self
end

return {
	new = new,
}
