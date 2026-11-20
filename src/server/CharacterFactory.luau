-- CharacterFactory.luau
-- Owns everything about a brainrot's physical model: template preparation
-- and measurement, cloning, ground placement, overhead labels and the
-- proximity prompts that drive buying / stealing / selling.

local Workspace = game:GetService("Workspace")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")

local Config = require(game.ReplicatedStorage.Shared.Config)
local BrainrotData = require(game.ReplicatedStorage.Shared.BrainrotData)
local AssetLibrary = require(script.Parent.AssetLibrary)

local CharacterFactory = {}

local templatesFolder: Folder? = nil
local labFolder: Folder? = nil

local function getTemplatesFolder(): Folder
	if templatesFolder and templatesFolder.Parent then
		return templatesFolder
	end
	local folder = ServerStorage:FindFirstChild("Templates")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Templates"
		folder.Parent = ServerStorage
	end
	templatesFolder = folder :: Folder
	return templatesFolder :: Folder
end

local function getLabFolder(): Folder
	if labFolder and labFolder.Parent then
		return labFolder
	end
	local folder = Workspace:FindFirstChild("TemplateLab")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "TemplateLab"
		folder.Parent = Workspace
	end
	labFolder = folder :: Folder
	return labFolder :: Folder
end

local function getBrainrotsFolder(): Folder
	local folder = Workspace:FindFirstChild("Brainrots")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Brainrots"
		folder.Parent = Workspace
	end
	return folder :: Folder
end

-- Body measurement -----------------------------------------------------------
-- "Body" parts exclude near-invisible helpers, the Root anchor and any
-- decorative Aura disc, none of which should decide where the feet are.

local function isBodyPart(part: BasePart): boolean
	if part.Name == "Root" then
		return false
	end
	if part.Name == "Aura" then
		return false
	end
	if part.Transparency >= 0.95 then
		return false
	end
	return true
end

-- Lowest oriented-box bottom across all body parts, in world space.
local function lowestBodyBottom(model: Model): number?
	local lowest: number? = nil
	for _, inst in ipairs(model:GetDescendants()) do
		if inst:IsA("BasePart") and isBodyPart(inst) then
			local cf = inst.CFrame
			local half = inst.Size / 2
			for _, sx in ipairs({ -1, 1 }) do
				for _, sy in ipairs({ -1, 1 }) do
					for _, sz in ipairs({ -1, 1 }) do
						local corner = cf * Vector3.new(sx * half.X, sy * half.Y, sz * half.Z)
						if lowest == nil or corner.Y < lowest then
							lowest = corner.Y
						end
					end
				end
			end
		end
	end
	return lowest
end

local function highestBodyTop(model: Model): number?
	local highest: number? = nil
	for _, inst in ipairs(model:GetDescendants()) do
		if inst:IsA("BasePart") and isBodyPart(inst) then
			local cf = inst.CFrame
			local half = inst.Size / 2
			for _, sx in ipairs({ -1, 1 }) do
				for _, sy in ipairs({ -1, 1 }) do
					for _, sz in ipairs({ -1, 1 }) do
						local corner = cf * Vector3.new(sx * half.X, sy * half.Y, sz * half.Z)
						if highest == nil or corner.Y > highest then
							highest = corner.Y
						end
					end
				end
			end
		end
	end
	return highest
end

-- Measure a template once. Returns (groundOffset, bodyHeight) or nil.
-- Two consecutive reads must agree, which guards against measuring a model
-- that is still settling after being parented.
local function measureTemplate(model: Model): (number?, number?)
	local lab = getLabFolder()
	model.Parent = lab
	RunService.Heartbeat:Wait()

	local low1 = lowestBodyBottom(model)
	local high1 = highestBodyTop(model)
	RunService.Heartbeat:Wait()
	local low2 = lowestBodyBottom(model)
	local high2 = highestBodyTop(model)

	if low1 == nil or low2 == nil or high1 == nil or high2 == nil then
		return nil, nil
	end
	if math.abs(low1 - low2) > 0.05 or math.abs(high1 - high2) > 0.05 then
		-- One more settle attempt before giving up on precision.
		RunService.Heartbeat:Wait()
		low2 = lowestBodyBottom(model)
		high2 = highestBodyTop(model)
		if low2 == nil or high2 == nil then
			return nil, nil
		end
		if math.abs(low1 - low2) > 0.05 then
			return nil, nil
		end
	end

	local pivotY = model:GetPivot().Position.Y
	local groundOffset = pivotY - (low2 :: number)
	local bodyHeight = (high2 :: number) - (low2 :: number)
	return groundOffset, bodyHeight
end

local function ensureRoot(model: Model): Part
	local existing = model:FindFirstChild("Root")
	if existing and existing:IsA("BasePart") then
		model.PrimaryPart = existing
		return existing
	end
	-- Place the Root at the feet centre: horizontally at the body centre,
	-- vertically so its bottom touches the body's lowest point.
	local low = lowestBodyBottom(model)
	local pivot = model:GetPivot()
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(0.4, 0.4, 0.4)
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	local feetY = if low ~= nil then low else pivot.Position.Y
	root.CFrame = CFrame.new(pivot.Position.X, feetY + 0.2, pivot.Position.Z)
	root.Parent = model
	model.PrimaryPart = root
	return root
end

local function hardenModel(model: Model)
	for _, inst in ipairs(model:GetDescendants()) do
		if inst:IsA("BasePart") then
			inst.Anchored = true
			inst.CanCollide = false
			inst.CanQuery = false
			inst.CanTouch = false
		end
	end
end

-- Template preparation -------------------------------------------------------

local function buildFallbackFor(def: any): Model?
	if def.BuildFallback then
		local ok, model = pcall(def.BuildFallback)
		if ok and model then
			return model :: Model
		end
	end
	-- Generic last-resort blob so a missing builder never breaks spawning.
	local model = Instance.new("Model")
	model.Name = def.Name
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Shape = Enum.PartType.Ball
	body.Size = Vector3.new(2, 2.4, 2)
	body.CFrame = CFrame.new(0, 1.4, 0)
	body.Color = def.AccentColor or Color3.fromRGB(200, 200, 200)
	body.Anchored = true
	body.CanCollide = false
	body.CanQuery = false
	body.Parent = model
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(0.4, 0.4, 0.4)
	root.CFrame = CFrame.new(0, 0.2, 0)
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.Parent = model
	model.PrimaryPart = root
	return model
end

local function prepareOne(def: any)
	local store = getTemplatesFolder()
	if store:FindFirstChild(def.Id) then
		return
	end

	local template: Model? = nil

	if def.AssetId and def.AssetId > 0 then
		local loaded = AssetLibrary.LoadModel(def.AssetId)
		if loaded then
			template = loaded
		end
	end

	if not template then
		template = buildFallbackFor(def)
	end
	if not template then
		return
	end

	template.Name = def.Id
	hardenModel(template)

	if def.ScaleTo then
		pcall(function()
			(template :: Model):ScaleTo(def.ScaleTo)
		end)
	end

	local groundOffset, bodyHeight = measureTemplate(template)
	if groundOffset ~= nil then
		template:SetAttribute("GroundOffset", groundOffset)
	end
	if bodyHeight ~= nil then
		template:SetAttribute("BodyHeight", bodyHeight)
	end
	template:SetAttribute("DefId", def.Id)

	ensureRoot(template)
	hardenModel(template)

	template.Parent = store
end

function CharacterFactory.PrepareTemplates()
	getTemplatesFolder()
	getLabFolder()
	for _, def in ipairs(BrainrotData.Cast) do
		-- Each load runs on its own thread: a slow InsertService call for
		-- one character must never stall the rest of server init.
		task.spawn(prepareOne, def)
	end
end

function CharacterFactory.GetTemplate(defId: string): Model?
	local store = getTemplatesFolder()
	local found = store:FindFirstChild(defId)
	if found and found:IsA("Model") then
		return found
	end
	return nil
end

-- Overhead label -------------------------------------------------------------

local function formatMoney(n: number): string
	if n >= 1000000 then
		return string.format("$%.1fM", n / 1000000)
	elseif n >= 1000 then
		return string.format("$%.1fK", n / 1000)
	end
	return string.format("$%d", math.floor(n))
end

local function addLabel(model: Model, def: any)
	local old = model:FindFirstChild("OverheadLabel")
	if old then
		old:Destroy()
	end
	local root = model.PrimaryPart or model:FindFirstChild("Root")
	local adornee: BasePart? = nil
	if root and root:IsA("BasePart") then
		adornee = root
	end

	local gui = Instance.new("BillboardGui")
	gui.Name = "OverheadLabel"
	gui.Size = UDim2.new(6, 0, 2.2, 0)
	gui.StudsOffset = Vector3.new(0, 3.4, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 90
	if adornee then
		gui.Adornee = adornee
	end

	local rarityColor = Config.RarityColors[def.Rarity] or Color3.fromRGB(255, 255, 255)

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.Size = UDim2.new(1, 0, 0.38, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = def.Name
	nameLabel.TextColor3 = rarityColor
	nameLabel.TextStrokeTransparency = 0.35
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextScaled = true
	nameLabel.Parent = gui

	local rarityLabel = Instance.new("TextLabel")
	rarityLabel.Name = "RarityLabel"
	rarityLabel.Position = UDim2.new(0, 0, 0.38, 0)
	rarityLabel.Size = UDim2.new(1, 0, 0.26, 0)
	rarityLabel.BackgroundTransparency = 1
	rarityLabel.Text = string.upper(def.Rarity)
	rarityLabel.TextColor3 = rarityColor
	rarityLabel.TextStrokeTransparency = 0.5
	rarityLabel.Font = Enum.Font.GothamBold
	rarityLabel.TextScaled = true
	rarityLabel.Parent = gui

	local statsLabel = Instance.new("TextLabel")
	statsLabel.Name = "StatsLabel"
	statsLabel.Position = UDim2.new(0, 0, 0.64, 0)
	statsLabel.Size = UDim2.new(1, 0, 0.3, 0)
	statsLabel.BackgroundTransparency = 1
	statsLabel.Text = string.format("%s/s  •  %s", formatMoney(def.IncomePerSec), formatMoney(def.Price))
	statsLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	statsLabel.TextStrokeTransparency = 0.4
	statsLabel.Font = Enum.Font.Gotham
	statsLabel.TextScaled = true
	statsLabel.Parent = gui

	gui.Parent = model
end

-- Build ----------------------------------------------------------------------

function CharacterFactory.Build(defId: string): Model?
	local def = BrainrotData.ById[defId]
	if not def then
		return nil
	end

	local model: Model? = nil
	local template = CharacterFactory.GetTemplate(defId)
	if template then
		model = template:Clone()
	else
		model = buildFallbackFor(def)
		if model then
			-- Measure the fresh fallback so clones are not the only ones
			-- carrying grounding data.
			local groundOffset, bodyHeight = measureTemplate(model)
			if groundOffset ~= nil then
				model:SetAttribute("GroundOffset", groundOffset)
			end
			if bodyHeight ~= nil then
				model:SetAttribute("BodyHeight", bodyHeight)
			end
		end
	end
	if not model then
		return nil
	end

	model.Name = def.Name
	model:SetAttribute("DefId", def.Id)
	model:SetAttribute("State", "belt")

	-- Carry measured grounding data over from the template when present.
	if template then
		local go = template:GetAttribute("GroundOffset")
		if go ~= nil and model:GetAttribute("GroundOffset") == nil then
			model:SetAttribute("GroundOffset", go)
		end
		local bh = template:GetAttribute("BodyHeight")
		if bh ~= nil and model:GetAttribute("BodyHeight") == nil then
			model:SetAttribute("BodyHeight", bh)
		end
	end

	ensureRoot(model)
	hardenModel(model)
	addLabel(model, def)

	model.Parent = getBrainrotsFolder()
	return model
end

-- Grounding ------------------------------------------------------------------

function CharacterFactory.GroundYAt(x: number, z: number, fallbackY: number): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude: { Instance } = {}
	local brainrots = Workspace:FindFirstChild("Brainrots")
	if brainrots then
		table.insert(exclude, brainrots)
	end
	for _, player in ipairs(game:GetService("Players"):GetPlayers()) do
		if player.Character then
			table.insert(exclude, player.Character)
		end
	end
	params.FilterDescendantsInstances = exclude
	params.IgnoreWater = true

	local origin = Vector3.new(x, fallbackY + 40, z)
	local result = Workspace:Raycast(origin, Vector3.new(0, -80, 0), params)
	if result then
		return result.Position.Y + 0.02
	end
	return fallbackY
end

-- Position a model so its body rests exactly on the ground.
-- position: desired feet position (x/z used; y is a raycast fallback hint).
function CharacterFactory.SetPose(model: Model, position: Vector3, facingAngle: number?, bobY: number?)
	local facing = facingAngle or 0
	local bob = bobY or 0
	local groundY = CharacterFactory.GroundYAt(position.X, position.Z, position.Y)
	local targetFeetY = groundY + bob

	local groundOffset = model:GetAttribute("GroundOffset")
	local pivotY: number
	if typeof(groundOffset) == "number" then
		pivotY = targetFeetY + groundOffset
	else
		pivotY = targetFeetY + 0.2
	end

	local target = CFrame.new(position.X, pivotY, position.Z) * CFrame.Angles(0, facing, 0)
	model:PivotTo(target)

	-- Self-correction: trust the actual parts, not the cached offset.
	local lowest = lowestBodyBottom(model)
	if lowest ~= nil then
		local delta = targetFeetY - lowest
		if math.abs(delta) > 0.01 then
			model:PivotTo(model:GetPivot() + Vector3.new(0, delta, 0))
		end
	end
end

-- Prompts --------------------------------------------------------------------

local function clearPrompts(model: Model, keepName: string?)
	for _, inst in ipairs(model:GetDescendants()) do
		if inst:IsA("ProximityPrompt") and inst.Name ~= keepName then
			inst:Destroy()
		end
	end
end

local function promptHost(model: Model): BasePart
	local root = model:FindFirstChild("Root")
	if root and root:IsA("BasePart") then
		return root
	end
	local primary = model.PrimaryPart
	if primary then
		return primary
	end
	local anyPart = model:FindFirstChildWhichIsA("BasePart", true)
	return anyPart :: BasePart
end

function CharacterFactory.AttachBeltPrompt(entry: any, onBuy: (entry: any, player: Player) -> ())
	local model: Model = entry.Model
	local def = entry.Def
	clearPrompts(model)
	local host = promptHost(model)
	if not host then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "BuyPrompt"
	prompt.ActionText = "Buy"
	prompt.ObjectText = string.format("%s — $%d", def.Name, def.Price)
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = host
	prompt.Triggered:Connect(function(player: Player)
		onBuy(entry, player)
	end)
	entry.BuyPrompt = prompt
end

function CharacterFactory.SetPlacedPrompts(entry: any)
	local model: Model = entry.Model
	clearPrompts(model)
	local host = promptHost(model)
	if not host then
		return
	end

	if entry.Owner then
		model:SetAttribute("OwnerUserId", entry.Owner.UserId)
	else
		model:SetAttribute("OwnerUserId", 0)
	end
	model:SetAttribute("State", "placed")

	local steal = Instance.new("ProximityPrompt")
	steal.Name = "StealPrompt"
	steal.ActionText = "Steal"
	steal.ObjectText = entry.Def.Name
	steal.HoldDuration = 0.5
	steal.MaxActivationDistance = 10
	steal.RequiresLineOfSight = false
	steal.Parent = host

	local sell = Instance.new("ProximityPrompt")
	sell.Name = "SellPrompt"
	sell.ActionText = "Sell"
	local sellValue = math.floor((entry.Def.Price or 0) * Config.SellFraction)
	sell.ObjectText = string.format("%s — $%d", entry.Def.Name, sellValue)
	sell.HoldDuration = 0.3
	sell.MaxActivationDistance = 10
	sell.RequiresLineOfSight = false
	sell.Parent = host

	entry.StealPrompt = steal
	entry.SellPrompt = sell
end

-- Carrying -------------------------------------------------------------------

function CharacterFactory.SetCarried(entry: any, carrier: Player)
	local model: Model = entry.Model
	clearPrompts(model)
	model:SetAttribute("State", "carried")

	local character = carrier.Character
	if not character then
		return
	end
	local head = character:FindFirstChild("Head")
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	local anchor: BasePart? = nil
	if head and head:IsA("BasePart") then
		anchor = head
	elseif rootPart and rootPart:IsA("BasePart") then
		anchor = rootPart
	end
	if not anchor then
		return
	end

	-- Feet rest just above the carrier's head. SetPose cannot be reused
	-- here (it raycasts to the floor), so place directly with the cached
	-- ground offset and then self-correct against the real part bottoms,
	-- exactly like SetPose does for grounded poses.
	local feetY = anchor.Position.Y + anchor.Size.Y / 2 + 0.9
	local groundOffset = model:GetAttribute("GroundOffset")
	local pivotY = feetY + (if typeof(groundOffset) == "number" then groundOffset else 0.2)
	local look = anchor.CFrame.LookVector
	local facing = math.atan2(-look.X, -look.Z)
	model:PivotTo(CFrame.new(anchor.Position.X, pivotY, anchor.Position.Z) * CFrame.Angles(0, facing, 0))

	local lowest = lowestBodyBottom(model)
	if lowest ~= nil then
		local delta = feetY - lowest
		if math.abs(delta) > 0.01 then
			model:PivotTo(model:GetPivot() + Vector3.new(0, delta, 0))
		end
	end
end

function CharacterFactory.ClearCarried(entry: any)
	local model: Model = entry.Model
	if model then
		model:SetAttribute("State", "walking")
	end
end

CharacterFactory._lowestBodyBottom = lowestBodyBottom
CharacterFactory._isBodyPart = isBodyPart

return CharacterFactory
