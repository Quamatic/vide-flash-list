local React = require(script.Parent.Parent.React)

local e = React.createElement

export type Props = {}

local function VirtualGrid(props: Props)
	return e("ScrollingFrame", {}, {})
end

return VirtualGrid
