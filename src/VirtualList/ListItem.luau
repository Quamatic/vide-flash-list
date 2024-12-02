local vide = require(script.Parent.Parent.Parent.vide)

local create = vide.create
local changed = vide.changed

export type Props = {
	index: number,
	offset: number,
	hidden: boolean,
	resizer: (size: Vector2) -> (),
	horizontal: boolean,
	children: Instance,
}

local function ListItem(props: Props)
	local index = props.index

	return create "Frame" {
		Name = `ListItem_{index}`,
		Size = if props.horizontal then UDim2.fromScale(0, 1) else UDim2.fromScale(1, 0),
		Position = if props.horizontal then UDim2.fromOffset(props.offset, 0) else UDim2.fromOffset(0, props.offset),
		AutomaticSize = if props.horizontal then Enum.AutomaticSize.X else Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,

		changed("AbsoluteSize", props.resizer),

		props.children,
	}
end

return ListItem
