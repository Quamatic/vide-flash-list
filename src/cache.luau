local splice = require(script.Parent.splice)

export type Cache = {
	length: number,
	-- offsets
	sizes: { number },
	defaultItemSize: number,
	-- sizes
	computedOffsetIndex: number,
	offsets: { number },
}

export type InternalCacheSnapshot = {
	sizes: { number },
	defaultSize: number,
}

local UNCACHED = -1

local function getItemSize(cache: Cache, index: number)
	local size = cache.sizes[index]
	return if size == UNCACHED then cache.defaultItemSize else size
end

local function setItemSize(cache: Cache, index: number, size: number)
	local isInitialMeasurement = cache.sizes[index] == UNCACHED

	cache.sizes[index] = size
	cache.computedOffsetIndex = math.min(index, cache.computedOffsetIndex)

	return isInitialMeasurement
end

local function computeOffset(cache: Cache, index: number)
	if cache.length == 0 or index > cache.length then
		print(#cache.offsets, cache.length, index, debug.info(3, "fnsl"))
		return 0
	end

	if cache.computedOffsetIndex >= index then
		return cache.offsets[index]
	end

	if cache.computedOffsetIndex < 1 then
		cache.offsets[1] = 0
		cache.computedOffsetIndex = 1
	end

	local i = cache.computedOffsetIndex
	local top = cache.offsets[i]

	while i < index do
		top += getItemSize(cache, i)
		i += 1
		cache.offsets[i] = top
	end

	cache.computedOffsetIndex = index

	return top
end

local function computeTotalSize(cache: Cache)
	if cache.length == 0 then
		return 0
	end

	return computeOffset(cache, cache.length) + getItemSize(cache, cache.length)
end

local function findIndex(cache: Cache, offset: number, low: number?, high: number?)
	local low_ = if low == nil then 1 else low
	local high_ = if high == nil then cache.length else high

	while low_ <= high_ do
		local mid = math.floor((low_ + high_) / 2)
		local itemOffset = computeOffset(cache, mid)
		if itemOffset <= offset then
			if itemOffset + getItemSize(cache, mid) > offset then
				return mid
			end
			low_ = mid + 1
		else
			high_ = mid - 1
		end
	end

	return math.clamp(low_, 1, cache.length)
end

local function computeRange(cache: Cache, scrollOffset: number, viewportSize: number, prevStartIndex: number)
	-- Clamp because prevStartIndex may exceed the limit when children decreased a lot after scrolling
	prevStartIndex = math.min(prevStartIndex, cache.length)

	if computeOffset(cache, prevStartIndex) <= scrollOffset then
		-- search forward
		-- start <= end, prevStartIndex <= start
		local endIndex = findIndex(cache, scrollOffset + viewportSize, prevStartIndex)
		return findIndex(cache, scrollOffset, prevStartIndex, endIndex), endIndex
	else
		-- search backward
		-- start <= end, start <= prevStartIndex
		local startIndex = findIndex(cache, scrollOffset, nil, prevStartIndex)
		return startIndex, findIndex(cache, scrollOffset + viewportSize, startIndex)
	end
end

local function sortMeasuredSizes(a: number, b: number)
	return a < b
end

local function estimateDefaultItemSize(cache: Cache, startIndex: number)
	local measuredCountBeforeStart = 0
	local measuredSizes: { number } = {}

	for index, size in cache.sizes do
		if size ~= UNCACHED then
			table.insert(measuredSizes, size)

			if index < startIndex then
				measuredCountBeforeStart += 1
			end
		end
	end

	cache.computedOffsetIndex = -1

	table.sort(measuredSizes, sortMeasuredSizes)

	local length = #measuredSizes
	local mid = bit32.bor(length / 2, 0)
	local median = if not bit32.btest(length, 1)
		then (measuredSizes[mid - 1] + measuredSizes[mid]) / 2
		else measuredSizes[mid]

	local prevDefaultItemSize = cache.defaultItemSize
	cache.defaultItemSize = median

	return (median - prevDefaultItemSize) * math.max(startIndex - measuredCountBeforeStart, 0)
end

local function create(length: number, itemSize: number, snapshot: InternalCacheSnapshot?): Cache
	local sizes: { number }
	if snapshot then
		local previous = snapshot.sizes
		sizes = table.create(#previous + length, UNCACHED)

		for i = 1, math.max(0, length - #previous) do
			sizes[i] = previous[i]
		end
	else
		sizes = table.create(length, UNCACHED)
	end

	return {
		length = length,
		defaultItemSize = if snapshot then snapshot.defaultSize else itemSize,
		sizes = sizes,
		offsets = table.create(length, UNCACHED),
		computedOffsetIndex = -1,
	}
end

local function takeSnapshot(cache: Cache): InternalCacheSnapshot
	return {
		sizes = table.clone(cache.sizes),
		defaultSize = cache.defaultItemSize,
	}
end

local function updateLength(cache: Cache, length: number, isShift: boolean?)
	local previous = cache.length
	local difference = length - previous

	cache.computedOffsetIndex = if isShift then -1 else math.min(length, cache.computedOffsetIndex)
	cache.length = length

	if difference > 0 then
		-- Added
		for _ = 1, difference do
			if isShift then
				table.insert(cache.sizes, 1, UNCACHED)
			else
				table.insert(cache.sizes, UNCACHED)
			end
		end

		return cache.defaultItemSize * difference
	else
		-- Removed
		splice(cache.offsets, difference)

		local removed: { number } = if isShift
			then splice(cache.sizes, 1, -difference)
			else splice(cache.sizes, difference)

		local accumulator = 0
		for _, size in removed do
			accumulator -= if size == UNCACHED then cache.defaultItemSize else size
		end

		return accumulator
	end
end

return {
	create = create,
	takeSnapshot = takeSnapshot,
	updateLength = updateLength,
	getItemSize = getItemSize,
	setItemSize = setItemSize,
	computeOffset = computeOffset,
	computeTotalSize = computeTotalSize,
	computeRange = computeRange,
	findIndex = findIndex,
	estimateDefaultItemSize = estimateDefaultItemSize,
	UNCACHED = UNCACHED,
}
