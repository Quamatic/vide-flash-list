local vide = require(script.Parent.Parent.vide)

local Virtua = require(script.Parent.Parent.Virtua)
type VirtualStore = Virtua.VirtualStore

local source = vide.source
local effect = vide.effect

local function isSameRange(left: { number }, right: { number })
	return left[1] == right[1] and left[2] == right[2]
end

local function useRange(store: VirtualStore, rerender: () -> ())
	local range = source(store:getRange())

	effect(function(previous: { number }?)
		rerender()

		local current = store:getRange()
		if previous ~= nil and isSameRange(previous, current) then
			return previous
		end

		range(current)

		return current
	end, nil :: { number }?)

	return range
end

return useRange
