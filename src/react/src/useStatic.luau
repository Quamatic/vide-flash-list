local React = require(script.Parent.Parent.React)

local useRef = React.useRef

local function useStatic<T>(init: () -> T)
	local ref = useRef(nil :: T?)

	if ref.current == nil then
		ref.current = init()
	end

	return ref.current :: T
end

return useStatic
