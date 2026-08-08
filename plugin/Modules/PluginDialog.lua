--!strict

local StarterGui = game:GetService("StarterGui")

local PluginDialog = {}

function PluginDialog.Notify(title: string, text: string)
	local shown = pcall(function()
		StarterGui:SetCore("SendNotification", {
			Title = title,
			Text = text,
			Duration = 6,
		})
	end)
	if not shown then
		print(`[{title}] {text}`)
	end
end

function PluginDialog.Confirm(pluginObject: Plugin, title: string, message: string): boolean
	local widgetInfo = DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Float, true, false, 440, 190, 360, 170)
	local widget = pluginObject:CreateDockWidgetPluginGui(
		`EclipseToolsConfirm_{math.floor(os.clock() * 1000)}`,
		widgetInfo
	)
	widget.Title = title

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(32, 35, 40)
	frame.Parent = widget

	local copy = Instance.new("TextLabel")
	copy.BackgroundTransparency = 1
	copy.Position = UDim2.fromOffset(18, 16)
	copy.Size = UDim2.new(1, -36, 1, -76)
	copy.Font = Enum.Font.SourceSans
	copy.TextSize = 17
	copy.TextColor3 = Color3.fromRGB(230, 234, 240)
	copy.TextWrapped = true
	copy.TextXAlignment = Enum.TextXAlignment.Left
	copy.TextYAlignment = Enum.TextYAlignment.Top
	copy.Text = message
	copy.Parent = frame

	local cancel = Instance.new("TextButton")
	cancel.Position = UDim2.new(1, -220, 1, -50)
	cancel.Size = UDim2.fromOffset(92, 34)
	cancel.Text = "Cancel"
	cancel.Parent = frame

	local proceed = Instance.new("TextButton")
	proceed.Position = UDim2.new(1, -116, 1, -50)
	proceed.Size = UDim2.fromOffset(98, 34)
	proceed.BackgroundColor3 = Color3.fromRGB(74, 126, 104)
	proceed.TextColor3 = Color3.new(1, 1, 1)
	proceed.Text = "Build"
	proceed.Parent = frame

	local answered = Instance.new("BindableEvent")
	local settled = false
	local function settle(value: boolean)
		if settled then
			return
		end
		settled = true
		answered:Fire(value)
	end
	cancel.MouseButton1Click:Connect(function()
		settle(false)
	end)
	proceed.MouseButton1Click:Connect(function()
		settle(true)
	end)
	widget:GetPropertyChangedSignal("Enabled"):Connect(function()
		if not widget.Enabled then
			settle(false)
		end
	end)

	widget.Enabled = true
	local result = answered.Event:Wait()
	widget.Enabled = false
	answered:Destroy()
	widget:Destroy()
	return result
end

return PluginDialog
