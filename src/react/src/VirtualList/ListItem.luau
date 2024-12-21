local Virtua = require(script.Parent.Parent.Parent.Virtua)
local React = require(script.Parent.Parent.Parent.React)

local useState = React.useState
local useEffect = React.useEffect

local e = React.createElement

export type Props = {
	index: number,
	offset: number,
	resizer: Virtua.ListResizer,
	horizontal: boolean,
	children: React.ReactNode?,
}

local function ListItem(props: Props): React.ReactNode
	local horizontal = props.horizontal
	local element, setElement = useState(nil :: Frame?)

	useEffect(function()
		if element then
			return props.resizer:observeItem(props.index, element)
		end

		return nil :: never -- forcing typechecker to be quiet
	end, { element })

	return e("Frame", {
		Size = if horizontal then UDim2.fromScale(0, 1) else UDim2.fromScale(1, 0),
		Position = if horizontal then UDim2.fromOffset(props.offset, 0) else UDim2.fromOffset(0, props.offset),
		AutomaticSize = if horizontal then Enum.AutomaticSize.X else Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,

		ref = setElement,
	}, props.children)
end

return React.memo(ListItem)
