local vide = require(script.Parent.Parent.vide)

local source = vide.source
local effect = vide.effect
local untrack = vide.untrack

local function usePrevious<T>(compute: () -> T, predicate: (a: T, b: T) -> boolean)
	local previous = source(nil :: T?)

	effect(function()
		local current = compute()
		local old = untrack(previous)

		if not predicate(old, current) then
			previous(current)
		end
	end)

	return previous :: () -> T
end

return usePrevious
