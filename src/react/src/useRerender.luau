local Virtua = require(script.Parent.Parent.Virtua)
type VirtualStore = Virtua.VirtualStore

local React = require(script.Parent.Parent.React)

local useReducer = React.useReducer

local function useRerender(store: VirtualStore)
	local function reducer()
		return store:getStateVersion()
	end

	local _, rerender = useReducer(reducer, nil, reducer)
	return rerender
end

return useRerender
