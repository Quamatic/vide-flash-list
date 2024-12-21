local React = require(script.Parent.Parent.React)

local useRef = React.useRef
local useEffect = React.useEffect

local function useLatestRef<T>(value: T)
	local ref = useRef(value)

	useEffect(function()
		ref.current = value
	end, { value })

	return ref
end

return useLatestRef
