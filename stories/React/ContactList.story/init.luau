local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local React = require(script.Parent.Parent.Parent.DevPackages.React)
local ReactRoblox = require(script.Parent.Parent.Parent.DevPackages.ReactRoblox)

local VirtuaReact = require(script.Parent.Parent.Parent.DevPackages.VirtuaReact)
local VirtualList = VirtuaReact.VirtualList

local ContactData = require(script.ContactData)
type Contact = ContactData.Contact

local useState = React.useState

local e = React.createElement

local RNG = Random.new()
local CONTACT_CARD_HEIGHT = 96

local function SectionHeader(props: {
	item: string,
})
	return e("TextLabel", {
		Size = UDim2.new(1, 0, 0, 36),
		Text = props.item,
		TextSize = 24,
		BackgroundColor3 = Color3.new(0.9, 0.9, 0.9),
		BorderSizePixel = 0,
	})
end

local function Contact(props: {
	index: number,
	maxIndex: number,
	item: {
		userId: number,
		firstName: string,
		lastName: string,
	},
})
	return e("Frame", {
		Size = UDim2.new(1, 0, 0, CONTACT_CARD_HEIGHT),
		BorderSizePixel = 0,
	}, {
		UIListLayout = e("UIListLayout", {
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			VerticalFlex = Enum.UIFlexAlignment.Fill,
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 12),
		}),

		UIPadding = e("UIPadding", {
			PaddingTop = UDim.new(0, 12),
			PaddingBottom = UDim.new(0, 12),
			PaddingLeft = UDim.new(0, 12),
			PaddingRight = UDim.new(0, 12),
		}),

		Thumbnail = e("ImageLabel", {
			Size = UDim2.fromOffset(96 - 24, 0),
			BackgroundColor3 = Color3.fromHSV(props.index / props.maxIndex, 0.5, 0.5),
			Image = `rbxthumb://type=AvatarHeadShot&id={props.item.userId}&w=48&h=48`,
			BorderSizePixel = 0,
		}, {
			UICorner = e("UICorner", {
				CornerRadius = UDim.new(1, 0),
			}),

			UIStroke = e("UIStroke", {
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Color = Color3.new(0.223529, 0.223529, 0.223529),
				Thickness = 1,
				Transparency = 0.6,
			}),
		}),

		Information = e("Frame", {
			BackgroundTransparency = 1,
		}, {
			Layout = e("UIListLayout", {
				HorizontalAlignment = Enum.HorizontalAlignment.Left,
				VerticalFlex = Enum.UIFlexAlignment.Fill,
				FillDirection = Enum.FillDirection.Vertical,
				Padding = UDim.new(0, 12),
			}),

			Flex = e("UIFlexItem", {
				FlexMode = Enum.UIFlexMode.Grow,
			}),

			Name = e("TextLabel", {
				AutomaticSize = Enum.AutomaticSize.XY,
				Text = `{props.item.firstName} {props.item.lastName}`,
				TextSize = 24,
				BackgroundTransparency = 1,
			}),
		}),
	})
end

local function Header()
	return e("TextLabel", {
		Size = UDim2.new(1, 0, 0, 36),
		Text = "These are the start of the contacts...",
		TextSize = 24,
	})
end

local function ItemSeparator()
	return e("Frame", {
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = Color3.new(0.9, 0.9, 0.9),
		BorderSizePixel = 0,
	})
end

local function Button(props: {
	text: string,
	onClick: () -> (),
})
	return e("TextButton", {
		AutomaticSize = Enum.AutomaticSize.Y,
		Text = props.text,
		TextSize = 18,
		[React.Event.Activated] = props.onClick,
	}, {
		UIPadding = e("UIPadding", {
			PaddingTop = UDim.new(0, 12),
			PaddingBottom = UDim.new(0, 12),
			PaddingLeft = UDim.new(0, 12),
			PaddingRight = UDim.new(0, 12),
		}),
	})
end

local function Container()
	local data, setData = useState(ContactData)
	local handles, setHandles = useState(nil :: VirtuaReact.VirtualListHandle?)

	return e("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(400, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
	}, {
		UIListLayout = e("UIListLayout", {
			HorizontalFlex = Enum.UIFlexAlignment.Fill,
			FillDirection = Enum.FillDirection.Vertical,
			Padding = UDim.new(0, 12),
		}),

		ListContainer = e("Frame", {
			Size = UDim2.fromOffset(0, 400),
			BackgroundTransparency = 1,
		}, {
			List = e(VirtualList, {
				data = data,
				horizontal = false,
				overscan = { type = "elements", amount = 4 },
				itemSize = CONTACT_CARD_HEIGHT,
				render = function(item: ContactData.Contact | string, index)
					if typeof(item) == "string" then
						return e(SectionHeader, { item = item :: string })
					end

					return e(Contact, {
						index = index,
						item = item,
						maxIndex = #ContactData,
					})
				end,
				ref = setHandles,
			}),
		}),

		RandomIndex = e("Frame", {
			Size = UDim2.fromOffset(0, 36),
			BackgroundTransparency = 1,
		}, {
			UIListLayout = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalFlex = Enum.UIFlexAlignment.Fill,
				VerticalFlex = Enum.UIFlexAlignment.Fill,
				Padding = UDim.new(0, 12),
			}),

			Button = e(Button, {
				text = "Random",
				onClick = function()
					local handles = handles()
					if handles ~= nil then
						handles.scrollToIndex(RNG:NextInteger(1, #ContactData), {
							animator = function(update)
								local t = 0
								local duration = 0.8

								local connection = RunService.PreRender:Connect(function(delta: number)
									t += delta / duration
									update(TweenService:GetValue(t, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut))
								end)

								return function()
									connection:Disconnect()
								end
							end,
						})
					end
				end,
			}),
		}),

		Options = e("Frame", {
			Size = UDim2.fromOffset(0, 36),
			BackgroundTransparency = 1,
		}, {
			UIListLayout = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalFlex = Enum.UIFlexAlignment.Fill,
				VerticalFlex = Enum.UIFlexAlignment.Fill,
				Padding = UDim.new(0, 12),
			}),

			AddContact = e(Button, {
				text = "Add Contact",
				onClick = function()
					setData(function(previous)
						local cloned = table.clone(previous)
						table.insert(cloned, {
							id = HttpService:GenerateGUID(),
							userId = 1,
							firstName = "John",
							lastName = "Doe",
						})

						return cloned
					end)
				end,
			}),

			RemoveContact = e(Button, {
				text = "Remove Last",
				onClick = function()
					setData(function(previous)
						local cloned = table.clone(previous)
						cloned[#cloned] = nil

						return cloned
					end)
				end,
			}),
		}),
	})
end

return {
	react = React,
	reactRoblox = ReactRoblox,
	story = function()
		return e(Container)
	end,
}
