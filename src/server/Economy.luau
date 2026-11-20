-- Economy.luau
-- SAHUR ZOO: money and the things money does.
--  * A one-second tick pays every keeper their pens' income and keeps
--    the HUD fed.
--  * Lock: seals your enclosure for 60s, then a 20s cooldown.
--  * Rebirth: two-tap confirmed reset for a permanent income multiplier.
--  * The four upgrade stands around each enclosure (Lock / Rebirth /
--    Slap / Speed / Capacity) sell their wares to the enclosure's owner.
--  * The SlapHand tool: whack a thief who is carrying one of yours (or
--    any carrier, if you are feeling neighbourly) and they drop it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local GameState = require(script.Parent:WaitForChild("GameState"))
local PlayerData = require(script.Parent:WaitForChild("PlayerData"))
local BaseManager = require(script.Parent:WaitForChild("BaseManager"))
local Contracts = require(script.Parent:WaitForChild("Contracts"))
local Trail = require(script.Parent:WaitForChild("Trail"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local HudState = Remotes:WaitForChild("HudState") :: RemoteEvent
local Notify = Remotes:WaitForChild("Notify") :: RemoteEvent
local Celebrate = Remotes:WaitForChild("Celebrate") :: RemoteEvent

local function cfg(key: string, fallback: any): any
	local value = (Config :: any)[key]
	if value == nil then
		return fallback
	end
	return value
end

local START_CASH = cfg("StartCash", 100)
local LOCK_DURATION = cfg("LockDuration", 60)
local LOCK_COOLDOWN = cfg("LockCooldown", 20)
local SLAP_COSTS = cfg("SlapCosts", { 250, 1000, 4000, 15000 })
local SPEED_COSTS = cfg("SpeedCosts", { 500, 2500, 10000 })
local CAPACITY_COSTS = cfg("CapacityCosts", { 5000, 25000, 100000, 400000 })
local BASE_WALK_SPEED = cfg("BaseWalkSpeed", 16)
local SLAP_RANGE = 14
local SLAP_COOLDOWN = 0.6

local Economy = {}

local world: any = nil
local lockBusyUntil: { [Player]: number } = {} -- locked-until or cooldown-until
local lockCooldownUntil: { [Player]: number } = {}
local rebirthArmedUntil: { [Player]: number } = {}
local lastSlapAt: { [Player]: number } = {}
local standPrompts: { { Prompt: ProximityPrompt, BaseIndex: number, Kind: string } } = {}

local function notify(player: Player, text: string)
	Notify:FireClient(player, text)
end

local function stealSystem(): any
	return require(script.Parent:WaitForChild("StealSystem"))
end

local function rebirthCost(data: any): number
	local ok, cost = pcall(function()
		local fn = (Config :: any).RebirthCost
		if typeof(fn) == "function" then
			return fn(data.Rebirths or 0)
		end
		return nil
	end)
	if ok and typeof(cost) == "number" then
		return cost
	end
	return 25000 * (3 ^ (data.Rebirths or 0))
end

local function multiplierOf(data: any): number
	local ok, mult = pcall(function()
		return GameState.MultiplierOf(data)
	end)
	if ok and typeof(mult) == "number" then
		return mult
	end
	return 1 + 0.5 * (data.Rebirths or 0)
end

local function pushHud(player: Player, data: any)
	HudState:FireClient(player, {
		Cash = data.Cash,
		IncomePerSec = data.IncomePerSec or 0,
		Rebirths = data.Rebirths or 0,
		Multiplier = multiplierOf(data),
		RebirthCost = rebirthCost(data),
	})
end

function Economy.PushHud(player: Player)
	local data = PlayerData.Get(player)
	if data then
		pushHud(player, data)
	end
end

local function applyWalkSpeed(player: Player)
	local ok, steal = pcall(stealSystem)
	if ok and steal and steal.ApplyWalkSpeed then
		steal.ApplyWalkSpeed(player)
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		local data = PlayerData.Get(player)
		local hum = humanoid :: any
		hum.WalkSpeed = BASE_WALK_SPEED + 2 * (data and data.SpeedLevel or 0)
	end
end

-- ---------------------------------------------------------------- Lock

local function doLock(player: Player)
	local baseIndex = BaseManager.GetBase(player)
	if not baseIndex then
		notify(player, "You have no enclosure to lock")
		return
	end
	local now = os.clock()
	if BaseManager.IsLocked(baseIndex) then
		local left = math.ceil((lockBusyUntil[player] or now) - now)
		notify(player, "Already locked (" .. tostring(math.max(0, left)) .. "s left)")
		return
	end
	if now < (lockCooldownUntil[player] or 0) then
		local left = math.ceil(lockCooldownUntil[player] - now)
		notify(player, "Lock recharging (" .. tostring(left) .. "s)")
		return
	end
	BaseManager.SetLocked(baseIndex, true)
	lockBusyUntil[player] = now + LOCK_DURATION
	Contracts.OnEvent(player, "Lock")
	Trail.OnEvent(player, "Lock")
	notify(player, "Enclosure locked for " .. tostring(LOCK_DURATION) .. "s")
	task.delay(LOCK_DURATION, function()
		if BaseManager.GetBase(player) == baseIndex then
			BaseManager.SetLocked(baseIndex, false)
			lockCooldownUntil[player] = os.clock() + LOCK_COOLDOWN
			if player.Parent then
				notify(player, "Your enclosure unlocked")
			end
		end
	end)
end

-- ------------------------------------------------------------- Rebirth

local function doRebirth(player: Player)
	local data = PlayerData.Get(player)
	if not data then
		return
	end
	local ok, steal = pcall(stealSystem)
	if ok and steal and steal.IsCarrying and steal.IsCarrying(player) then
		notify(player, "You cannot rebirth while carrying a brainrot")
		return
	end
	local cost = rebirthCost(data)
	local now = os.clock()
	if now > (rebirthArmedUntil[player] or 0) then
		rebirthArmedUntil[player] = now + 5
		notify(player, string.format(
			"REBIRTH? Pay $%d. Resets cash, pens, slap, speed and capacity. New multiplier x%.1f. Tap REBIRTH again to confirm!",
			cost, 1 + 0.5 * ((data.Rebirths or 0) + 1)))
		return
	end
	rebirthArmedUntil[player] = 0
	if data.Cash < cost then
		notify(player, "Not enough cash for rebirth ($" .. tostring(cost) .. ")")
		return
	end
	local baseIndex = BaseManager.GetBase(player)
	-- Destroy every penned brainrot; in-flight walks check Cleared.
	local placed = GameState.PlacedOf(player)
	if placed then
		for _, entry in ipairs(placed) do
			entry.Cleared = true
			if baseIndex then
				BaseManager.RemoveFromPad(entry)
			end
			GameState.Unregister(entry)
			if entry.Model then
				entry.Model:Destroy()
			end
		end
	end
	data.Cash = START_CASH
	data.BaseCapacityLevel = 0
	data.SlapLevel = 0
	data.SpeedLevel = 0
	data.Rebirths = (data.Rebirths or 0) + 1
	if baseIndex then
		BaseManager.SetLocked(baseIndex, false)
		BaseManager.RefreshPadVisibility(baseIndex)
		BaseManager.RefreshSign(baseIndex)
	end
	lockBusyUntil[player] = nil
	lockCooldownUntil[player] = nil
	GameState.RecountIncome(player)
	PlayerData.SyncLeaderstats(player)
	applyWalkSpeed(player)
	pushHud(player, data)
	Economy.RefreshStandPrompts()
	Celebrate:FireClient(player, "REBIRTH! Income x" .. string.format("%.1f", multiplierOf(data)))
	notify(player, "Reborn! Your pens now earn x" .. string.format("%.1f", multiplierOf(data)))
end

-- -------------------------------------------------------------- Stands

local function buySlap(player: Player)
	local data = PlayerData.Get(player)
	if not data then
		return
	end
	local level = data.SlapLevel or 0
	local cost = SLAP_COSTS[level + 1]
	if not cost then
		notify(player, "Slap is already MAX")
		return
	end
	if data.Cash < cost then
		notify(player, "Not enough cash")
		return
	end
	data.Cash -= cost
	data.SlapLevel = level + 1
	PlayerData.SyncLeaderstats(player)
	pushHud(player, data)
	Economy.RefreshStandPrompts()
	notify(player, "Slap upgraded to level " .. tostring(data.SlapLevel) .. "!")
end

local function buySpeed(player: Player)
	local data = PlayerData.Get(player)
	if not data then
		return
	end
	local level = data.SpeedLevel or 0
	local cost = SPEED_COSTS[level + 1]
	if not cost then
		notify(player, "Speed is already MAX")
		return
	end
	if data.Cash < cost then
		notify(player, "Not enough cash")
		return
	end
	data.Cash -= cost
	data.SpeedLevel = level + 1
	PlayerData.SyncLeaderstats(player)
	applyWalkSpeed(player)
	pushHud(player, data)
	Economy.RefreshStandPrompts()
	notify(player, "Speed upgraded! WalkSpeed is now " .. tostring(BASE_WALK_SPEED + 2 * data.SpeedLevel))
end

local function buyCapacity(player: Player)
	local data = PlayerData.Get(player)
	if not data then
		return
	end
	local level = data.BaseCapacityLevel or 0
	local cost = CAPACITY_COSTS[level + 1]
	if not cost then
		notify(player, "Pen capacity is already MAX")
		return
	end
	if data.Cash < cost then
		notify(player, "Not enough cash")
		return
	end
	data.Cash -= cost
	data.BaseCapacityLevel = level + 1
	PlayerData.SyncLeaderstats(player)
	local baseIndex = BaseManager.GetBase(player)
	if baseIndex then
		BaseManager.RefreshPadVisibility(baseIndex)
		BaseManager.RefreshSign(baseIndex)
	end
	GameState.RecountIncome(player)
	pushHud(player, data)
	Economy.RefreshStandPrompts()
	notify(player, "Pen capacity upgraded!")
end

local function standLabel(kind: string, data: any): (string, string)
	if kind == "Lock" then
		return "Lock Pen", "60s seal"
	elseif kind == "Rebirth" then
		if data then
			return "Rebirth", "$" .. tostring(rebirthCost(data))
		end
		return "Rebirth", ""
	elseif kind == "Slap" then
		local cost = data and SLAP_COSTS[(data.SlapLevel or 0) + 1]
		return "Slap Upgrade", cost and ("$" .. tostring(cost)) or "MAX"
	elseif kind == "Speed" then
		local cost = data and SPEED_COSTS[(data.SpeedLevel or 0) + 1]
		return "Speed Upgrade", cost and ("$" .. tostring(cost)) or "MAX"
	elseif kind == "Capacity" then
		local cost = data and CAPACITY_COSTS[(data.BaseCapacityLevel or 0) + 1]
		return "Bigger Pen", cost and ("$" .. tostring(cost)) or "MAX"
	end
	return kind, ""
end

function Economy.RefreshStandPrompts()
	for _, record in ipairs(standPrompts) do
		local owner = BaseManager.GetOwner(record.BaseIndex)
		local data = owner and PlayerData.Get(owner) or nil
		local action, object = standLabel(record.Kind, data)
		record.Prompt.ActionText = action
		record.Prompt.ObjectText = object
	end
end

local function attachStandPrompts()
	if not world then
		return
	end
	local kinds = { "Lock", "Rebirth", "Slap", "Speed", "Capacity" }
	for baseIndex, base in ipairs(world.Bases) do
		if base.Stands then
			for _, kind in ipairs(kinds) do
				local part = base.Stands[kind]
				if part and part:IsA("BasePart") then
					local prompt = Instance.new("ProximityPrompt")
					prompt.Name = kind .. "StandPrompt"
					prompt.RequiresLineOfSight = false
					prompt.MaxActivationDistance = 10
					prompt.HoldDuration = 0
					prompt.Parent = part
					table.insert(standPrompts, { Prompt = prompt, BaseIndex = baseIndex, Kind = kind })
					prompt.Triggered:Connect(function(player: Player)
						if BaseManager.GetBase(player) ~= baseIndex then
							notify(player, "This is not your enclosure")
							return
						end
						if kind == "Lock" then
							doLock(player)
						elseif kind == "Rebirth" then
							doRebirth(player)
						elseif kind == "Slap" then
							buySlap(player)
						elseif kind == "Speed" then
							buySpeed(player)
						elseif kind == "Capacity" then
							buyCapacity(player)
						end
					end)
				end
			end
		end
	end
	Economy.RefreshStandPrompts()
end

-- ---------------------------------------------------------------- Slap

function Economy.GiveSlapTool(player: Player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then
		return
	end
	if backpack:FindFirstChild("SlapHand") then
		return
	end
	local character = player.Character
	if character and character:FindFirstChild("SlapHand") then
		return
	end
	local tool = Instance.new("Tool")
	tool.Name = "SlapHand"
	tool.ToolTip = "Slap a thief to make them drop your brainrot!"
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(1.4, 0.5, 1.8)
	handle.Color = Color3.fromRGB(255, 190, 90)
	handle.Material = Enum.Material.SmoothPlastic
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool
	tool.Activated:Connect(function()
		Economy.OnSlapHit(player)
	end)
	tool.Parent = backpack
end

function Economy.OnSlapHit(player: Player)
	local now = os.clock()
	if now - (lastSlapAt[player] or 0) < SLAP_COOLDOWN then
		return
	end
	lastSlapAt[player] = now
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local ok, steal = pcall(stealSystem)
	if not ok or not steal then
		return
	end
	local data = PlayerData.Get(player)
	local slapLevel = data and data.SlapLevel or 0
	-- Prefer a carrier holding the attacker's own brainrot; fall back
	-- to any carrier in range.
	local victim: Player? = nil
	local fallbackVictim: Player? = nil
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player then
			local entry = steal.IsCarrying(other)
			if entry then
				local otherRoot = other.Character and other.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if otherRoot then
					local distance = (otherRoot.Position - root.Position).Magnitude
					if distance <= SLAP_RANGE then
						if entry.Owner == player then
							victim = other
							break
						elseif not fallbackVictim then
							fallbackVictim = other
						end
					end
				end
			end
		end
	end
	victim = victim or fallbackVictim
	if not victim then
		return
	end
	local victimRoot = victim.Character and victim.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not victimRoot then
		return
	end
	local direction = Vector3.new(victimRoot.Position.X - root.Position.X, 0, victimRoot.Position.Z - root.Position.Z)
	if direction.Magnitude < 0.01 then
		direction = root.CFrame.LookVector
	else
		direction = direction.Unit
	end
	steal.DropCarried(victim, direction)
	local power = 24 + 5 * slapLevel
	victimRoot.AssemblyLinearVelocity = direction * power + Vector3.new(0, 14, 0)
	notify(player, "Slapped " .. victim.DisplayName .. " - they dropped it!")
	notify(victim, "You got slapped by " .. player.DisplayName .. " and dropped the brainrot!")
end

-- -------------------------------------------------------------- Actions

function Economy.HandleAction(player: Player, action: string)
	if action == "Lock" then
		doLock(player)
	elseif action == "Rebirth" then
		doRebirth(player)
	end
end

function Economy.Start(w: any)
	world = w
	attachStandPrompts()
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in ipairs(Players:GetPlayers()) do
				local data = PlayerData.Get(player)
				if data then
					GameState.RecountIncome(player)
					local income = data.IncomePerSec or 0
					if income > 0 then
						data.Cash += income
						data.LifetimeIncome = (data.LifetimeIncome or 0) + income
						Contracts.OnEvent(player, "Earn", income)
						Trail.OnEvent(player, "Earn", income)
					end
					PlayerData.SyncLeaderstats(player)
					pushHud(player, data)
				end
			end
			Economy.RefreshStandPrompts()
		end
	end)
	print("[SahurZoo] Economy ticking")
end

Players.PlayerRemoving:Connect(function(player: Player)
	lockBusyUntil[player] = nil
	lockCooldownUntil[player] = nil
	rebirthArmedUntil[player] = nil
	lastSlapAt[player] = nil
end)

return Economy
