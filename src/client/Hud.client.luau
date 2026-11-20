-- Hud.client.luau
-- SAHUR ZOO heads-up display, built entirely in code: cash panel, event
-- banner, toasts, carrying warning, LOCK / REBIRTH buttons, the
-- contracts board, the keeper-trail banner and the celebration pop.
--
-- Zoo styling: dark-brown chunky panels, rounded corners, dark outline
-- strokes, GothamBlack text. Every panel is a transparent container
-- holding a shadow frame and a body frame as CHILDREN, so hiding the
-- panel always hides its shadow too (an earlier build kept shadows as
-- siblings and they stayed on screen forever after the panel hid).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local HudState = Remotes:WaitForChild("HudState") :: RemoteEvent
local HudAction = Remotes:WaitForChild("HudAction") :: RemoteEvent
local EventState = Remotes:WaitForChild("EventState") :: RemoteEvent
local Notify = Remotes:WaitForChild("Notify") :: RemoteEvent
local Celebrate = Remotes:WaitForChild("Celebrate") :: RemoteEvent
local ContractsState = Remotes:WaitForChild("ContractsState") :: RemoteEvent
local TrailState = Remotes:WaitForChild("TrailState") :: RemoteEvent

local BROWN = Color3.fromRGB(62, 42, 26)
local BROWN_DARK = Color3.fromRGB(43, 29, 17)
local GOLD = Color3.fromRGB(255, 201, 64)
local GREEN = Color3.fromRGB(120, 230, 120)
local PINK = Color3.fromRGB(255, 140, 190)
local RED = Color3.fromRGB(200, 54, 44)
local CREAM = Color3.fromRGB(250, 240, 220)

local gui = Instance.new("ScreenGui")
gui.Name = "SahurZooHud"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.DisplayOrder = 10
gui.Parent = player:WaitForChild("PlayerGui")

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
	return c
end

-- A panel: transparent container + child shadow + child body. Returns
-- (container, body); put content in the body, toggle the container.
local function makePanel(name: string, size: UDim2, position: UDim2, anchor: Vector2, color: Color3): (Frame, Frame)
	local container = Instance.new("Frame")
	container.Name = name
	container.Size = size
	container.Position = position
	container.AnchorPoint = anchor
	container.BackgroundTransparency = 1
	container.BorderSizePixel = 0
	container.Parent = gui

	local shadow = Instance.new("Frame")
	shadow.Name = "Shadow"
	shadow.Size = UDim2.fromScale(1, 1)
	shadow.Position = UDim2.fromOffset(4, 5)
	shadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	shadow.BackgroundTransparency = 0.45
	shadow.BorderSizePixel = 0
	shadow.ZIndex = 1
	corner(shadow, 10)
	shadow.Parent = container

	local body = Instance.new("Frame")
	body.Name = "Body"
	body.Size = UDim2.fromScale(1, 1)
	body.BackgroundColor3 = color
	body.BorderSizePixel = 0
	body.ZIndex = 2
	corner(body, 10)
	local stroke = Instance.new("UIStroke")
	stroke.Color = BROWN_DARK
	stroke.Thickness = 2
	stroke.Parent = body
	body.Parent = container
	return container, body
end

local function makeLabel(parent: Instance, name: string, size: UDim2, position: UDim2, anchor: Vector2, text: string, textSize: number, color: Color3): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Size = size
	label.Position = position
	label.AnchorPoint = anchor
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextSize = textSize
	label.TextColor3 = color
	label.Font = Enum.Font.GothamBlack
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.ZIndex = 3
	label.Parent = parent
	return label
end

local function commas(value: number): string
	local text = tostring(math.floor(value))
	local out = ""
	while #text > 3 do
		out = "," .. string.sub(text, -3) .. out
		text = string.sub(text, 1, -4)
	end
	return text .. out
end

local function clock(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

-- ------------------------------------------------------------ Cash panel
local _, cashBody = makePanel("CashPanel", UDim2.fromOffset(280, 74), UDim2.new(0.5, 0, 0, 10), Vector2.new(0.5, 0), BROWN)
local cashLabel = makeLabel(cashBody, "Cash", UDim2.new(1, -16, 0, 34), UDim2.new(0.5, 0, 0, 4), Vector2.new(0.5, 0), "$100", 30, GOLD)
local incomeLabel = makeLabel(cashBody, "Income", UDim2.new(1, -16, 0, 20), UDim2.new(0.5, 0, 0, 40), Vector2.new(0.5, 0), "+$0/s", 15, GREEN)
local rebirthLabel = makeLabel(cashBody, "Rebirths", UDim2.new(1, -16, 0, 16), UDim2.new(0.5, 0, 0, 57), Vector2.new(0.5, 0), "Rebirths: 0 - Income x1.0", 12, PINK)

-- ----------------------------------------------------------- Event banner
local _, eventBody = makePanel("EventBanner", UDim2.fromOffset(320, 28), UDim2.new(0.5, 0, 0, 92), Vector2.new(0.5, 0), BROWN_DARK)
local eventLabel = makeLabel(eventBody, "EventText", UDim2.fromScale(1, 1), UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5), "Events warming up...", 14, CREAM)

-- ----------------------------------------------------------------- Toast
local toastPanel, toastBody = makePanel("Toast", UDim2.fromOffset(380, 32), UDim2.new(0.5, 0, 0, 128), Vector2.new(0.5, 0), BROWN)
local toastLabel = makeLabel(toastBody, "ToastText", UDim2.new(1, -16, 1, 0), UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5), "", 14, CREAM)
toastLabel.TextWrapped = true
toastPanel.Visible = false
local toastToken = 0
local function showToast(text: string)
	toastToken += 1
	local myToken = toastToken
	toastLabel.Text = text
	toastBody.BackgroundTransparency = 0
	toastLabel.TextTransparency = 0
	toastPanel.Visible = true
	task.spawn(function()
		task.wait(3)
		if myToken ~= toastToken then
			return
		end
		for step = 1, 10 do
			if myToken ~= toastToken then
				return
			end
			local alpha = step / 10
			toastBody.BackgroundTransparency = alpha
			toastLabel.TextTransparency = alpha
			task.wait(0.04)
		end
		if myToken == toastToken then
			toastPanel.Visible = false
		end
	end)
end

-- --------------------------------------------------------- Carrying pill
local carryingPanel, carryingBody = makePanel("Carrying", UDim2.fromOffset(250, 30), UDim2.new(0.5, 0, 0, 168), Vector2.new(0.5, 0), RED)
makeLabel(carryingBody, "CarryingText", UDim2.fromScale(1, 1), UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5), "CARRYING! Get it home!", 14, CREAM)
carryingPanel.Visible = false

-- --------------------------------------------------------------- Buttons
local function makeButton(name: string, y: number, text: string, color: Color3): TextButton
	local container, body = makePanel(name, UDim2.fromOffset(134, 44), UDim2.new(1, -14, 0, y), Vector2.new(1, 0), color)
	local _ = container
	local button = Instance.new("TextButton")
	button.Name = "Button"
	button.Size = UDim2.fromScale(1, 1)
	button.BackgroundTransparency = 1
	button.Text = text
	button.TextSize = 15
	button.TextColor3 = CREAM
	button.Font = Enum.Font.GothamBlack
	button.ZIndex = 3
	button.Parent = body
	return button
end

local lockButton = makeButton("LockButton", 118, "LOCK PEN [L]", BROWN)
local rebirthButton = makeButton("RebirthButton", 170, "REBIRTH [R]", Color3.fromRGB(122, 52, 110))
lockButton.MouseButton1Click:Connect(function()
	HudAction:FireServer("Lock")
end)
rebirthButton.MouseButton1Click:Connect(function()
	HudAction:FireServer("Rebirth")
end)
UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
	if gameProcessed then
		return
	end
	if input.KeyCode == Enum.KeyCode.L then
		HudAction:FireServer("Lock")
	elseif input.KeyCode == Enum.KeyCode.R then
		HudAction:FireServer("Rebirth")
	end
end)

-- --------------------------------------------------------- Contracts board
local _, contractsBody = makePanel("Contracts", UDim2.fromOffset(216, 150), UDim2.new(1, -14, 0, 226), Vector2.new(1, 0), BROWN)
makeLabel(contractsBody, "Title", UDim2.new(1, -12, 0, 22), UDim2.new(0.5, 0, 0, 2), Vector2.new(0.5, 0), "CONTRACTS", 14, GOLD)
type ContractRow = { Text: TextLabel, Meta: TextLabel, Fill: Frame }
local contractRows: { ContractRow } = {}
for i = 1, 3 do
	local rowY = 26 + (i - 1) * 41
	local text = makeLabel(contractsBody, "RowText" .. i, UDim2.new(1, -12, 0, 20), UDim2.new(0, 6, 0, rowY), Vector2.new(0, 0), "-", 12, CREAM)
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.TextWrapped = true
	local meta = makeLabel(contractsBody, "RowMeta" .. i, UDim2.new(1, -12, 0, 14), UDim2.new(0, 6, 0, rowY + 19), Vector2.new(0, 0), "", 11, GREEN)
	meta.TextXAlignment = Enum.TextXAlignment.Left
	local barBack = Instance.new("Frame")
	barBack.Name = "BarBack" .. i
	barBack.Size = UDim2.new(1, -12, 0, 6)
	barBack.Position = UDim2.new(0, 6, 0, rowY + 34)
	barBack.BackgroundColor3 = BROWN_DARK
	barBack.BorderSizePixel = 0
	barBack.ZIndex = 3
	corner(barBack, 3)
	barBack.Parent = contractsBody
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = GOLD
	fill.BorderSizePixel = 0
	fill.ZIndex = 4
	corner(fill, 3)
	fill.Parent = barBack
	contractRows[i] = { Text = text, Meta = meta, Fill = fill }
end

-- ------------------------------------------------------------ Trail banner
local trailPanel, trailBody = makePanel("Trail", UDim2.fromOffset(400, 42), UDim2.new(0.5, 0, 1, -54), Vector2.new(0.5, 1), BROWN)
local trailDots: { Frame } = {}
for i = 1, 4 do
	local dot = Instance.new("Frame")
	dot.Name = "Dot" .. i
	dot.Size = UDim2.fromOffset(16, 16)
	dot.Position = UDim2.new(0, 10 + (i - 1) * 22, 0.5, 0)
	dot.AnchorPoint = Vector2.new(0, 0.5)
	dot.BackgroundColor3 = BROWN_DARK
	dot.BorderSizePixel = 0
	dot.ZIndex = 3
	corner(dot, 8)
	dot.Parent = trailBody
	trailDots[i] = dot
end
local trailLabel = makeLabel(trailBody, "TrailText", UDim2.new(1, -110, 1, 0), UDim2.new(0, 102, 0, 0), Vector2.new(0, 0), "TRAIL 0/4", 13, CREAM)
trailLabel.TextXAlignment = Enum.TextXAlignment.Left
local TRAIL_TEXTS = {
	"Buy a brainrot from the Parade Path",
	"Your brainrot settles into a pen",
	"Lock your enclosure",
	"Steal from a rival or earn $500 lifetime",
}

-- ------------------------------------------------------------- Celebrate
local celebrateLabel = Instance.new("TextLabel")
celebrateLabel.Name = "Celebrate"
celebrateLabel.Size = UDim2.fromOffset(640, 90)
celebrateLabel.Position = UDim2.fromScale(0.5, 0.38)
celebrateLabel.AnchorPoint = Vector2.new(0.5, 0.5)
celebrateLabel.BackgroundTransparency = 1
celebrateLabel.Text = ""
celebrateLabel.TextSize = 44
celebrateLabel.TextColor3 = GOLD
celebrateLabel.Font = Enum.Font.GothamBlack
celebrateLabel.TextStrokeColor3 = BROWN_DARK
celebrateLabel.TextStrokeTransparency = 0.25
celebrateLabel.Visible = false
celebrateLabel.ZIndex = 20
celebrateLabel.Parent = gui
local celebrateScale = Instance.new("UIScale")
celebrateScale.Scale = 0.5
celebrateScale.Parent = celebrateLabel
local celebrateToken = 0
local function showCelebrate(text: string)
	celebrateToken += 1
	local myToken = celebrateToken
	celebrateLabel.Text = text
	celebrateLabel.Visible = true
	celebrateScale.Scale = 0.5
	local grow = TweenService:Create(celebrateScale, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.12 })
	grow:Play()
	grow.Completed:Connect(function()
		if myToken == celebrateToken then
			TweenService:Create(celebrateScale, TweenInfo.new(0.12), { Scale = 1 }):Play()
		end
	end)
	task.spawn(function()
		task.wait(1.8)
		if myToken == celebrateToken then
			celebrateLabel.Visible = false
		end
	end)
end

-- --------------------------------------------------------- Logo and hint
local logo = makeLabel(gui, "Logo", UDim2.fromOffset(220, 34), UDim2.new(0, 14, 1, -14), Vector2.new(0, 1), "SAHUR ZOO", 24, GOLD)
logo.TextXAlignment = Enum.TextXAlignment.Left
logo.TextStrokeColor3 = BROWN_DARK
logo.TextStrokeTransparency = 0.3
local hint = makeLabel(gui, "Hint", UDim2.fromOffset(760, 20), UDim2.new(0.5, 0, 1, -8), Vector2.new(0.5, 1), "Buy brainrots from the Parade Path - steal from rival pens - slap thieves who grab yours!", 13, CREAM)
hint.TextStrokeColor3 = BROWN_DARK
hint.TextStrokeTransparency = 0.4

-- ------------------------------------------------------------ Remote feed
HudState.OnClientEvent:Connect(function(state: any)
	if typeof(state) ~= "table" then
		return
	end
	cashLabel.Text = "$" .. commas(state.Cash or 0)
	incomeLabel.Text = "+$" .. commas(state.IncomePerSec or 0) .. "/s"
	rebirthLabel.Text = string.format("Rebirths: %d - Income x%.1f", state.Rebirths or 0, state.Multiplier or 1)
	rebirthButton.Text = "REBIRTH [R]\n$" .. commas(state.RebirthCost or 0)
	rebirthButton.TextSize = 13
end)

EventState.OnClientEvent:Connect(function(state: any)
	if typeof(state) ~= "table" then
		return
	end
	local name = state.Name or ""
	local left = clock(state.SecondsLeft or 0)
	if state.Mode == "live" then
		eventLabel.Text = name .. "! " .. left
		eventLabel.TextColor3 = GOLD
	else
		eventLabel.Text = "NEXT: " .. name .. " " .. left
		eventLabel.TextColor3 = CREAM
	end
end)

Notify.OnClientEvent:Connect(function(text: any)
	if typeof(text) == "string" then
		showToast(text)
	end
end)

Celebrate.OnClientEvent:Connect(function(text: any)
	if typeof(text) == "string" then
		showCelebrate(text)
	end
end)

ContractsState.OnClientEvent:Connect(function(state: any)
	if typeof(state) ~= "table" or typeof(state.contracts) ~= "table" then
		return
	end
	for i, row in ipairs(contractRows) do
		local contract = state.contracts[i]
		if contract then
			row.Text.Text = contract.Text or "-"
			row.Meta.Text = string.format("%s/%s  +$%s", commas(contract.Progress or 0), commas(contract.Goal or 0), commas(contract.Reward or 0))
			local goal = math.max(1, contract.Goal or 1)
			row.Fill.Size = UDim2.fromScale(math.clamp((contract.Progress or 0) / goal, 0, 1), 1)
		else
			row.Text.Text = "-"
			row.Meta.Text = ""
			row.Fill.Size = UDim2.fromScale(0, 1)
		end
	end
end)

TrailState.OnClientEvent:Connect(function(state: any)
	if typeof(state) ~= "table" then
		return
	end
	if state.Complete then
		trailPanel.Visible = false
		return
	end
	trailPanel.Visible = true
	local doneCount = 0
	if typeof(state.Done) == "table" then
		for i = 1, 4 do
			local done = state.Done[i] == true
			trailDots[i].BackgroundColor3 = done and GREEN or BROWN_DARK
			if done then
				doneCount += 1
			end
		end
	end
	local step = state.Step or 1
	local stepText = TRAIL_TEXTS[step] or ""
	trailLabel.Text = string.format("TRAIL %d/4 - %s", doneCount, stepText)
end)

-- ------------------------------------------- Carrying + prompt filtering
local brainrotsFolder = workspace:WaitForChild("Brainrots")

local function amCarrying(): boolean
	local character = player.Character
	if character and character:GetAttribute("Carrying") == true then
		return true
	end
	for _, model in ipairs(brainrotsFolder:GetChildren()) do
		if model:IsA("Model") and model:GetAttribute("State") == "carried" then
			if model:GetAttribute("CarrierUserId") == player.UserId then
				return true
			end
		end
	end
	return false
end

task.spawn(function()
	while true do
		task.wait(1)
		carryingPanel.Visible = amCarrying()
	end
end)

-- Sell is for the owner only; Steal is for everyone else. The server
-- still validates every trigger - this just hides useless prompts.
task.spawn(function()
	while true do
		task.wait(0.3)
		for _, model in ipairs(brainrotsFolder:GetChildren()) do
			if model:IsA("Model") then
				local ownerId = model:GetAttribute("OwnerUserId")
				if ownerId ~= nil and model:GetAttribute("State") == "placed" then
					local isOwner = ownerId == player.UserId
					for _, descendant in ipairs(model:GetDescendants()) do
						if descendant:IsA("ProximityPrompt") then
							local label = string.lower(descendant.Name .. " " .. descendant.ActionText)
							if string.find(label, "sell") then
								descendant.Enabled = isOwner
							elseif string.find(label, "steal") then
								descendant.Enabled = not isOwner
							end
						end
					end
				end
			end
		end
	end
end)

print("[SahurZoo] HUD ready")
