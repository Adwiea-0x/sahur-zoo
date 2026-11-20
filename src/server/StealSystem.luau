-- StealSystem.luau
-- SAHUR ZOO: stealing, selling, carrying and dropping.
--
-- A penned brainrot wears two prompts (built by CharacterFactory): Sell
-- for its owner and Steal for everyone else. Stealing lifts the brainrot
-- onto the thief's back; plodding home at carry speed, the thief claims
-- it by stepping up to their own enclosure's front with a free pen. Get
-- slapped on the way and the brainrot drops, then walks itself home to
-- its owner's pen.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local GameState = require(script.Parent:WaitForChild("GameState"))
local CharacterFactory = require(script.Parent:WaitForChild("CharacterFactory"))
local PlayerData = require(script.Parent:WaitForChild("PlayerData"))
local BaseManager = require(script.Parent:WaitForChild("BaseManager"))
local Contracts = require(script.Parent:WaitForChild("Contracts"))
local Trail = require(script.Parent:WaitForChild("Trail"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Notify = Remotes:WaitForChild("Notify") :: RemoteEvent

local function cfg(key: string, fallback: any): any
	local value = (Config :: any)[key]
	if value == nil then
		return fallback
	end
	return value
end

local SELL_FRACTION = cfg("SellFraction", 0.5)
local CARRY_SPEED = cfg("CarrySpeed", 11)
local BASE_WALK_SPEED = cfg("BaseWalkSpeed", 16)
local RETURN_SPEED = cfg("ReturnSpeed", 13)
local CLAIM_RADIUS = 9

local StealSystem = {}

local world: any = nil
local carriedBy: { [Player]: any } = {} -- carrier -> entry
local carrierOf: { [any]: Player } = {} -- entry -> carrier
local hooked: { [any]: boolean } = {}
local lastFullNotice: { [Player]: number } = {}
local lastCarryPose: { [any]: Vector3 } = {}

local function notify(player: Player, text: string)
	Notify:FireClient(player, text)
end

local function setWalkSpeed(player: Player)
	local character = player.Character
	if not character then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	if carriedBy[player] then
		humanoid.WalkSpeed = CARRY_SPEED
	else
		local data = PlayerData.Get(player)
		local bonus = 0
		if data then
			bonus = 2 * (data.SpeedLevel or 0)
		end
		humanoid.WalkSpeed = BASE_WALK_SPEED + bonus
	end
end

function StealSystem.ApplyWalkSpeed(player: Player)
	setWalkSpeed(player)
end

function StealSystem.GetCarrierOf(entry: any): Player?
	return carrierOf[entry]
end

function StealSystem.IsCarrying(player: Player): any
	return carriedBy[player]
end

-- Connects an entry's Steal/Sell prompts. Called by BaseManager right
-- after placement, and again by the safety-net scan below.
function StealSystem.HookEntry(entry: any)
	if hooked[entry] or not entry.Model then
		return
	end
	local found = false
	for _, descendant in ipairs(entry.Model:GetDescendants()) do
		if descendant:IsA("ProximityPrompt") then
			local label = string.lower(descendant.Name .. " " .. descendant.ActionText)
			if string.find(label, "steal") then
				found = true
				descendant.Triggered:Connect(function(player: Player)
					StealSystem.TrySteal(player, entry)
				end)
			elseif string.find(label, "sell") then
				found = true
				descendant.Triggered:Connect(function(player: Player)
					StealSystem.TrySell(player, entry)
				end)
			end
		end
	end
	if found then
		hooked[entry] = true
	end
end

function StealSystem.TrySteal(player: Player, entry: any)
	if not entry or entry.State ~= "placed" then
		return
	end
	if entry.Owner == player then
		notify(player, "That one is yours - use Sell if you want it gone")
		return
	end
	if entry.BaseIndex and BaseManager.IsLocked(entry.BaseIndex) then
		notify(player, "That pen is locked")
		return
	end
	if carriedBy[player] then
		notify(player, "You are already carrying a brainrot")
		return
	end
	local owner = entry.Owner
	local def = entry.Def
	BaseManager.RemoveFromPad(entry)
	entry.State = "carried"
	if entry.Model then
		entry.Model:SetAttribute("State", "carried")
	end
	CharacterFactory.SetCarried(entry, player)
	carriedBy[player] = entry
	carrierOf[entry] = player
	if player.Character then
		player.Character:SetAttribute("Carrying", true)
	end
	setWalkSpeed(player)
	if owner and def then
		notify(owner, "Your " .. def.Name .. " was stolen by " .. player.DisplayName .. "!")
	end
	notify(player, "Stole " .. (def and def.Name or "a brainrot") .. "! Carry it to your enclosure front!")
end

function StealSystem.TrySell(player: Player, entry: any)
	if not entry or entry.State ~= "placed" then
		return
	end
	if entry.Owner ~= player then
		notify(player, "Only the owner can sell this brainrot")
		return
	end
	local data = PlayerData.Get(player)
	if not data then
		return
	end
	local def = entry.Def
	local payout = 0
	if def then
		payout = math.floor(def.Price * SELL_FRACTION)
	end
	BaseManager.RemoveFromPad(entry)
	GameState.Unregister(entry)
	hooked[entry] = nil
	if entry.Model then
		entry.Model:Destroy()
	end
	data.Cash += payout
	PlayerData.SyncLeaderstats(player)
	Contracts.OnEvent(player, "Sell")
	notify(player, "Sold for $" .. tostring(payout))
end

local function clearCarryMaps(entry: any): Player?
	lastCarryPose[entry] = nil
	local carrier = carrierOf[entry]
	if carrier then
		carrierOf[entry] = nil
		if carriedBy[carrier] == entry then
			carriedBy[carrier] = nil
		end
		if carrier.Character then
			carrier.Character:SetAttribute("Carrying", false)
		end
		setWalkSpeed(carrier)
	end
	return carrier
end

-- Drops whatever a victim is carrying at their feet; the brainrot then
-- walks home on its own. Direction is accepted for signature symmetry
-- with the slap that caused the drop (the fling itself is Economy's).
function StealSystem.DropCarried(victim: Player, direction: Vector3?)
	local entry = carriedBy[victim]
	if not entry then
		return
	end
	clearCarryMaps(entry)
	CharacterFactory.ClearCarried(entry)
	entry.State = "returning"
	if entry.Model then
		entry.Model:SetAttribute("State", "returning")
		local character = victim.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			local dropPos = root.Position + (direction or Vector3.new(0, 0, 1)) * 3
			CharacterFactory.SetPose(entry.Model, dropPos, 0, 0)
		end
	end
	local owner = entry.Owner
	local def = entry.Def
	task.spawn(function()
		if entry.Cleared or not entry.Model or not entry.Model.Parent then
			return
		end
		if not owner or not owner.Parent then
			GameState.Unregister(entry)
			if entry.Model then
				entry.Model:Destroy()
			end
			return
		end
		local baseIndex = BaseManager.GetBase(owner) or entry.LastBaseIndex
		local data = PlayerData.Get(owner)
		if not baseIndex or not data then
			return
		end
		-- Prefer its old pen, else the nearest free pen of the owner.
		local padIndex: number? = nil
		if entry.LastPadIndex and BaseManager.IsPadFree(baseIndex, entry.LastPadIndex) then
			local capacityOk = true
			local ok, capacity = pcall(function()
				return GameState.CapacityOf(data)
			end)
			if ok and typeof(capacity) == "number" and entry.LastPadIndex > capacity then
				capacityOk = false
			end
			if capacityOk then
				padIndex = entry.LastPadIndex
			end
		end
		if not padIndex then
			padIndex = BaseManager.FreePadIndex(baseIndex, data)
		end
		if not padIndex then
			-- Nowhere to live: the zoo buys it back at half price.
			local refund = def and math.floor(def.Price * SELL_FRACTION) or 0
			data.Cash += refund
			PlayerData.SyncLeaderstats(owner)
			GameState.Unregister(entry)
			entry.Model:Destroy()
			notify(owner, "No free pen - your brainrot was bought back for $" .. tostring(refund))
			return
		end
		local target = BaseManager.PadPosition(baseIndex, padIndex)
		if not target then
			return
		end
		local Conveyor = require(script.Parent:WaitForChild("Conveyor"))
		local arrived = Conveyor.WalkTo(entry, target, RETURN_SPEED)
		if entry.Cleared or not entry.Model or not entry.Model.Parent then
			return
		end
		if arrived and BaseManager.IsPadFree(baseIndex, padIndex) then
			BaseManager.PlaceOnPad(entry, baseIndex, padIndex)
			notify(owner, "Your " .. (def and def.Name or "brainrot") .. " made it home!")
		elseif arrived then
			-- Pen was taken during the walk home; try once more anywhere.
			local spare = BaseManager.FreePadIndex(baseIndex, data)
			if spare then
				BaseManager.PlaceOnPad(entry, baseIndex, spare)
			end
		end
	end)
end

local function tryClaim(carrier: Player, entry: any)
	local baseIndex = BaseManager.GetBase(carrier)
	if not baseIndex or not world then
		return
	end
	local base = world.Bases[baseIndex]
	if not base or not base.FrontCenter then
		return
	end
	local character = carrier.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local front = base.FrontCenter :: Vector3
	local flat = Vector3.new(root.Position.X - front.X, 0, root.Position.Z - front.Z)
	if flat.Magnitude > CLAIM_RADIUS then
		return
	end
	local data = PlayerData.Get(carrier)
	if not data then
		return
	end
	local padIndex = BaseManager.FreePadIndex(baseIndex, data)
	if not padIndex then
		local now = os.clock()
		if now - (lastFullNotice[carrier] or 0) > 4 then
			lastFullNotice[carrier] = now
			notify(carrier, "Your pen is full")
		end
		return
	end
	local def = entry.Def
	clearCarryMaps(entry)
	CharacterFactory.ClearCarried(entry)
	BaseManager.PlaceOnPad(entry, baseIndex, padIndex)
	Contracts.OnEvent(carrier, "Steal")
	Trail.OnEvent(carrier, "Steal")
	notify(carrier, "Claimed " .. (def and def.Name or "the brainrot") .. " for your pen!")
end

function StealSystem.Init(w: any)
	world = w
	-- Claim check: carried brainrots are claimed at the carrier's front.
	task.spawn(function()
		while true do
			task.wait(0.25)
			for carrier, entry in pairs(carriedBy) do
				if entry.State == "carried" and carrier.Parent then
					tryClaim(carrier, entry)
				end
			end
		end
	end)
	-- Carry follow: SetCarried poses the brainrot over the carrier's
	-- head once, so re-pose whenever the carrier has actually moved.
	RunService.Heartbeat:Connect(function()
		for carrier, entry in pairs(carriedBy) do
			if entry.State == "carried" and entry.Model and entry.Model.Parent then
				local root = carrier.Character and carrier.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if root then
					local last = lastCarryPose[entry]
					if not last or (root.Position - last).Magnitude > 0.4 then
						lastCarryPose[entry] = root.Position
						CharacterFactory.SetCarried(entry, carrier)
					end
				end
			else
				lastCarryPose[entry] = nil
			end
		end
	end)
	-- Safety net: hook prompts on any placed entry we somehow missed.
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in ipairs(Players:GetPlayers()) do
				local placed = GameState.PlacedOf(player)
				if placed then
					for _, entry in ipairs(placed) do
						StealSystem.HookEntry(entry)
					end
				end
			end
		end
	end)
	print("[SahurZoo] StealSystem armed")
end

-- Removes everything a departing player is tangled in: their placed
-- brainrots are destroyed by the bootstrap via GameState, but a carrier
-- leaving mid-carry (or an owner leaving while their brainrot is being
-- carried) must not strand models or speeds.
function StealSystem.CleanupPlayer(player: Player)
	local carried = carriedBy[player]
	if carried then
		clearCarryMaps(carried)
		CharacterFactory.ClearCarried(carried)
		GameState.Unregister(carried)
		if carried.Model then
			carried.Model:Destroy()
		end
	end
	for entry, carrier in pairs(carrierOf) do
		if entry.Owner == player then
			clearCarryMaps(entry)
			CharacterFactory.ClearCarried(entry)
			GameState.Unregister(entry)
			if entry.Model then
				entry.Model:Destroy()
			end
			local _ = carrier
		end
	end
end

return StealSystem
