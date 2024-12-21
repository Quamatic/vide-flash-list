local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local vide = require(script.Parent.Parent.Parent.Parent.DevPackages.vide)
vide.strict = false

local VirtuaVide = require(script.Parent.Parent.Parent.Parent.DevPackages.VirtuaVide)
local VirtualGrid = VirtuaVide.VirtualGrid

local create = vide.create
local source = vide.source

local DATA = table.create(1000, -1)
local RNG = Random.new()
local CONTACT_CARD_HEIGHT = 96

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
		local data = source(DATA)
		local handles = source(nil :: VirtuaVide.VirtualGridHandle?)

		return create "Frame" {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(800, 0),
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

				VirtualGrid {
					data = data,
					rows = 1,
					columns = "auto",
					cellWidth = 100,
					cellHeight = 40,
					children = function(_data, row, column)
						return create "TextLabel" {
							Size = UDim2.fromScale(1, 1),
							Text = `{row}/{column}`,
							TextSize = 16,
							BorderMode = Enum.BorderMode.Middle,
							BorderSizePixel = 1,
						}
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
					text = "Random",
					onClick = function()
						local handles = handles()
						if handles ~= nil then
							handles.scrollToIndex(RNG:NextInteger(1, #DATA), {
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
