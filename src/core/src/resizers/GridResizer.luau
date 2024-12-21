local VirtualStore = require(script.Parent.Parent.VirtualStore)
type VirtualStore = VirtualStore.VirtualStore

local GridResizer = {}
GridResizer.__index = GridResizer

-- Type exports

export type GridResizer = typeof(setmetatable(
	{} :: {
		_vStore: VirtualStore,
		_hStore: VirtualStore,
		_viewportConnection: RBXScriptConnection?,
		_itemConnections: { [GuiObject]: RBXScriptConnection },
		_queuedRowResizes: { number },
		_queuedColResizes: { number },
		_queuedRowResizesCount: number,
		_queuedColResizesCount: number,
		_sizeCache: { [GuiObject]: Vector2 },
		_deferBatchedUpdate: () -> (),
		_batching: boolean,
	},
	GridResizer
))

-- Private

function GridResizer._performBatchedUpdate(self: GridResizer)
	-- Update rows
	if self._queuedRowResizesCount > 0 then
		local resizedRows = table.create(self._queuedRowResizesCount)
		for rowIndex, size in self._queuedRowResizes do
			table.insert(resizedRows, { rowIndex, size })
		end

		self._vStore:updateItemSizes(resizedRows)
		self._queuedRowResizesCount = 0
		table.clear(self._queuedRowResizes)
	end

	-- Update columns
	if self._queuedColResizesCount > 0 then
		local resizedCols = table.create(self._queuedColResizesCount)
		for colIndex, size in self._queuedColResizes do
			table.insert(resizedCols, { colIndex, size })
		end

		self._hStore:updateItemSizes(resizedCols)
		self._queuedColResizesCount = 0
		table.clear(self._queuedColResizes)
	end

	self._batching = false
end

function GridResizer._prepareBatchedUpdate(self: GridResizer)
	if not self._batching then
		self._batching = true
		task.defer(self._deferBatchedUpdate)
	end
end

-- Public

function GridResizer.observeViewport(self: GridResizer, element: GuiObject)
	self._viewportConnection = element:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		local size = element.AbsoluteSize

		self._vStore:setViewportSize(size.Y)
		self._hStore:setViewportSize(size.X)
	end)
end

function GridResizer.observeItem(self: GridResizer, element: GuiObject, rowIndex: number, colIndex: number)
	local function update()
		if not element.Parent then
			return -- Skip zero-sized elements
		end

		local size = element.AbsoluteSize
		local didElementUpdate = false

		-- Check and update row size
		if self._queuedRowResizes[rowIndex] ~= size.Y then
			self._queuedRowResizes[rowIndex] = size.Y
			self._queuedRowResizesCount += 1
			didElementUpdate = true
		end

		-- Check and update column size
		if self._queuedColResizes[colIndex] ~= size.X then
			self._queuedColResizes[colIndex] = size.X
			self._queuedColResizesCount += 1
			didElementUpdate = true
		end

		if didElementUpdate then
			self:_prepareBatchedUpdate()
		end
	end

	-- Connect
	local connection = element:GetPropertyChangedSignal("AbsoluteSize"):Connect(update)
	self._itemConnections[element] = connection

	-- Update immediately
	update()

	return function()
		self._sizeCache[element] = nil

		if connection.Connected then
			connection:Disconnect()
			self._itemConnections[element] = nil
		end
	end
end

function GridResizer.dispose(self: GridResizer)
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

local function new(vStore: VirtualStore, hStore: VirtualStore): GridResizer
	local self = setmetatable({
		_vStore = vStore,
		_hStore = hStore,
		_itemConnections = {},
		_queuedRowResizes = {},
		_queuedColResizes = {},
		_queuedRowResizesCount = 0,
		_queuedColResizesCount = 0,
		_sizeCache = {},
		_batching = false,
	}, GridResizer)

	self._deferBatchedUpdate = function()
		if self._batching then
			self:_performBatchedUpdate()
		end
	end

	return self
end

return {
	new = new,
}
