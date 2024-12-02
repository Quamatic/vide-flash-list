local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local vide = require(script.Parent.Parent.Packages.vide)
vide.strict = false

local VideFlashList = require(script.Parent.Parent.Packages.VideFlashList)
local VirtualList = VideFlashList.VirtualList

local ContactData = require(script.Parent.ContactData)
type Contact = ContactData.Contact

local create = vide.create
local source = vide.source

local CONTACTS = require(script.Parent.ContactData)
local STICKY_HEADER_INDICES = {}

for index, item in CONTACTS do
	if typeof(item) == "string" then
		table.insert(STICKY_HEADER_INDICES, index)
	end
end

local RNG = Random.new()
local CONTACT_CARD_HEIGHT = 96

local function SectionHeader(props: {
	item: string,
})
	return create "TextLabel" {
		Size = UDim2.new(1, 0, 0, 36),
		Text = props.item,
		TextSize = 24,
		BackgroundColor3 = Color3.new(0.9, 0.9, 0.9),
		BorderSizePixel = 0,
	}
end

local function Contact(props: {
	index: number,
	maxIndex: number,
	item: vide.Source<{
		userId: number,
		firstName: string,
		lastName: string,
	}>,
})
	return create "Frame" {
		Size = UDim2.new(1, 0, 0, CONTACT_CARD_HEIGHT),

		create "UIListLayout" {
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			VerticalFlex = Enum.UIFlexAlignment.Fill,
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 12),
		},

		create "UIPadding" {
			PaddingTop = UDim.new(0, 12),
			PaddingBottom = UDim.new(0, 12),
			PaddingLeft = UDim.new(0, 12),
			PaddingRight = UDim.new(0, 12),
		},

		create "ImageLabel" {
			Size = UDim2.fromOffset(96 - 24, 0),
			BackgroundColor3 = Color3.fromHSV(props.index / props.maxIndex, 0.5, 0.5),
			Image = function()
				return `rbxthumb://type=AvatarHeadShot&id={props.item().userId}&w=48&h=48`
			end,

			create "UICorner" {
				CornerRadius = UDim.new(1, 0),
			},

			create "UIStroke" {
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Color = Color3.new(0.223529, 0.223529, 0.223529),
				Thickness = 1,
				Transparency = 0.6,
			},
		},

		create "Frame" {
			BackgroundTransparency = 1,

			create "UIListLayout" {
				HorizontalAlignment = Enum.HorizontalAlignment.Left,
				VerticalFlex = Enum.UIFlexAlignment.Fill,
				FillDirection = Enum.FillDirection.Vertical,
				Padding = UDim.new(0, 12),
			},

			create "UIFlexItem" {
				FlexMode = Enum.UIFlexMode.Grow,
			},

			create "TextLabel" {
				AutomaticSize = Enum.AutomaticSize.XY,
				Text = function()
					return `{props.item().firstName} {props.item().lastName}`
				end,
				TextSize = 24,
				BackgroundTransparency = 1,
			},
		},
	}
end

local function Header()
	return create "TextLabel" {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, 36),
		Text = "These are the start of the contacts...",
		TextSize = 24,
	}
end

local function ItemSeparator()
	return create "Frame" {
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = Color3.new(0.9, 0.9, 0.9),
		BorderSizePixel = 0,
	}
end

local function Button(props: {
	text: string,
	onClick: () -> (),
})
	return create "TextButton" {
		AutomaticSize = Enum.AutomaticSize.Y,
		Text = props.text,
		TextSize = 18,

		Activated = props.onClick,

		create "UIPadding" {
			PaddingTop = UDim.new(0, 12),
			PaddingBottom = UDim.new(0, 12),
			PaddingLeft = UDim.new(0, 12),
			PaddingRight = UDim.new(0, 12),
		},
	}
end

return {
	vide = vide,
	story = function()
		local data = source(CONTACTS)
		local handles = source(nil :: VideFlashList.VirtualListHandle?)

		return create "Frame" {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(400, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,

			create "UIListLayout" {
				HorizontalFlex = Enum.UIFlexAlignment.Fill,
				FillDirection = Enum.FillDirection.Vertical,
				Padding = UDim.new(0, 12),
			},

			create "Frame" {
				Size = UDim2.fromOffset(0, 400),
				BackgroundTransparency = 1,

				VirtualList {
					data = data,
					horizontal = false,
					overscan = 4,
					itemSize = CONTACT_CARD_HEIGHT,
					children = function(item: vide.Source<ContactData.Contact | string>, index)
						if typeof(item()) == "string" then
							return SectionHeader { item = item() :: string }
						end

						return Contact {
							index = index,
							item = item :: any,
							maxIndex = #CONTACTS,
						}
					end,
					ref = handles,
				},
			},

			create "Frame" {
				Size = UDim2.fromOffset(0, 36),
				BackgroundTransparency = 1,

				create "UIListLayout" {
					FillDirection = Enum.FillDirection.Horizontal,
					HorizontalFlex = Enum.UIFlexAlignment.Fill,
					VerticalFlex = Enum.UIFlexAlignment.Fill,
					Padding = UDim.new(0, 12),
				},

				Button {
					text = "Random",
					onClick = function()
						local handles = handles()
						if handles ~= nil then
							handles.scrollToIndex(RNG:NextInteger(1, #CONTACTS), {
								animator = function(update)
									local t = 0
									local duration = 0.8

									local connection = RunService.PreRender:Connect(function(delta: number)
										t += delta / duration
										update(
											TweenService:GetValue(t, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
										)
									end)

									return function()
										connection:Disconnect()
									end
								end,
							})
						end
					end,
				},
			},

			create "Frame" {
				Size = UDim2.fromOffset(0, 36),
				BackgroundTransparency = 1,

				create "UIListLayout" {
					FillDirection = Enum.FillDirection.Horizontal,
					HorizontalFlex = Enum.UIFlexAlignment.Fill,
					VerticalFlex = Enum.UIFlexAlignment.Fill,
					Padding = UDim.new(0, 12),
				},

				Button {
					text = "Add Contact",
					onClick = function()
						local cloned = table.clone(data())

						table.insert(cloned, {
							id = HttpService:GenerateGUID(),
							userId = 1,
							firstName = "John",
							lastName = "Doe",
						})

						data(cloned)
					end,
				},

				Button {
					text = "Remove Last Contact",
					onClick = function()
						local cloned = table.clone(data())
						cloned[#cloned] = nil

						data(cloned)
					end,
				},
			},
		}
	end,
}
