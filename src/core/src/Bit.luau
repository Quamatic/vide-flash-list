--[[
	Binary Indexed Tree implementation for fast item offset lookups.
]]

local Bit = {}
Bit.__index = Bit

-- Type exports

export type Bit = typeof(setmetatable(
	{} :: {
		tree: { number },
	},
	Bit
))

-- Public

function Bit.push(self: Bit, value: number)
	local length = #self.tree
	local k = bit32.band(length, -length)

	local i = 1
	while i < k do
		value += self.tree[length - i + 1]
		i = bit32.lshift(i, 1)
	end

	table.insert(self.tree, value)
end

function Bit.add(self: Bit, index: number, delta: number)
	index += 1

	while index <= #self.tree do
		self.tree[index] += delta
		index += bit32.band(index, -index)
	end
end

function Bit.get(self: Bit, index: number)
	local sum = 0

	while index > 0 do
		sum += self.tree[index]
		index -= bit32.band(index, -index)
	end

	return sum
end

function Bit.pop(self: Bit)
	self.tree[#self.tree] = nil
end

function Bit.lowerBound(self: Bit, value: number)
	if value <= 0 then
		return 0
	else
		local bit = self.tree
		local length = #bit
		local index = 0
		local t = bit32.lshift(1, 31 - bit32.countlz(length - 1))

		while t > 0 do
			local nextIndex = index + t

			if nextIndex < length and bit[nextIndex] <= value then
				value -= bit[nextIndex]
				index = nextIndex
			end

			t = bit32.rshift(t, 1)
		end

		return index
	end
end

-- Constructors

local function new(values: { number }): Bit
	local length = #values + 1
	local self = setmetatable({ tree = table.create(length, 0) }, Bit)

	-- TODO: optimize later
	for i = 1, length do
		self:add(i, values[i])
	end

	return self
end

return {
	new = new,
}
