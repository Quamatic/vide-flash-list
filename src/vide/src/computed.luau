local Vide = require(script.Parent.Parent.vide)

local source = Vide.source
local effect = Vide.effect
local untrack = Vide.untrack

local function computed<T>(compute: (previous: T?) -> T)
	local current = source()

	effect(function()
		local now = untrack(current)
		local value = compute(now)

		current(value)
	end)

	return current :: () -> T
end

return computed
