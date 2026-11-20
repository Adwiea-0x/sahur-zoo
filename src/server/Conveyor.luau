-- Conveyor.luau
-- SAHUR ZOO: the Parade Path. Brainrots wander out of the arrivals cave
-- at the west end (x = -194), stroll east along the belt past all twelve
-- enclosures, and disappear into the exit cave at x = +194 if nobody
-- buys them. A keeper with cash and a free pen can buy one straight off
-- the path; the brainrot then walks off the path, across the plaza and
-- in through the open front of the buyer's enclosure to its pen.
--
-- WalkTo is shared: StealSystem sends dropped brainrots home with it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local BrainrotData = require(Shared:WaitForChild("BrainrotData"))
local GameState = require(script.Parent:WaitForChild("GameState"))
local CharacterFactory = require(script.Parent:WaitForChild("CharacterFactory"))
local PlayerData = require(script.Parent:WaitForChild("PlayerData"))
local BaseManager = require(script.Parent:WaitForChild("BaseManager"))
local Contracts = require(script.Parent:WaitForChild("Contracts"))
local Trail = require(script.Parent:WaitForChild("Trail"))
local Events = require(script.Parent:WaitForChild("Events"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Notify = Remotes:WaitForChild("Notify") :: RemoteEvent

local function cfg(key: string, fallback: any): any
	local value = (Config :: any)[key]
	if value == nil then
		return fallback
	end
	return value
end

local BELT_START_X = cfg("BeltStartX", -194)
local BELT_END_X = cfg("BeltEndX", 194)
local BELT_TOP_Y = cfg("BeltTopY", 2)
local BELT_SPEED = cfg("BeltSpeed", 9)
local BELT_CAP = cfg("BeltCap", 14)
local SPAWN_INTERVAL = cfg("SpawnInterval", 2.4)
local WALK_SPEED = cfg("WalkSpeed", 15)
local MYTHIC_RANK = 6 -- RarityRank of Mythic in Config.RarityOrder (announce at/above)

local Conveyor = {}

local rng = Random.new()
local world: any = nil
local beltEntries: { [any]: boolean } = {}
local walkingEntries: { [any]: boolean } = {}
local nextEntryId = 1

local function notify(player: Player, text: string)
	Notify:FireClient(player, text)
end

local function beltCount(): number
	local count = 0
	for entry in pairs(beltEntries) do
		if entry.Model and entry.Model.Parent then
			count += 1
		else
			beltEntries[entry] = nil
		end
	end
	return count
end

local function modelPosition(model: Model): Vector3
	return model:GetPivot().Position
end

-- Steps a brainrot toward a ground target, re-grounding every step via
-- CharacterFactory.SetPose. Returns true on arrival, false if the entry
-- was cleared (rebirth), destroyed, or the walk timed out.
function Conveyor.WalkTo(entry: any, targetPosition: Vector3, speed: number?): boolean
	local model = entry.Model
	if not model or not model.Parent then
		return false
	end
	walkingEntries[entry] = true
	local walkSpeed = speed or WALK_SPEED
	local deadline = os.clock() + 60
	local bobPhase = rng:NextNumber(0, math.pi * 2)
	local arrived = false
	while os.clock() < deadline do
		if entry.Cleared or not model.Parent then
			break
		end
		local current = modelPosition(model)
		local flat = Vector3.new(targetPosition.X - current.X, 0, targetPosition.Z - current.Z)
		local distance = flat.Magnitude
		if distance <= 1.4 then
			arrived = true
			break
		end
		local dt = RunService.Heartbeat:Wait()
		if entry.Cleared or not model.Parent then
			break
		end
		current = modelPosition(model)
		flat = Vector3.new(targetPosition.X - current.X, 0, targetPosition.Z - current.Z)
		distance = flat.Magnitude
		if distance <= 0.01 then
			arrived = true
			break
		end
		local step = math.min(distance, walkSpeed * dt)
		local direction = flat.Unit
		local nextPos = current + direction * step
		nextPos = Vector3.new(nextPos.X, current.Y, nextPos.Z)
		local facing = math.atan2(-direction.Z, direction.X)
		bobPhase += dt * 9
		local bob = math.abs(math.sin(bobPhase)) * 0.14
		CharacterFactory.SetPose(model, nextPos, facing, bob)
	end
	walkingEntries[entry] = nil
	if arrived and model.Parent and not entry.Cleared then
		CharacterFactory.SetPose(model, modelPosition(model), math.pi, 0)
		return true
	end
	return false
end

function Conveyor.BuyRequest(player: Player, entry: any)
	if not entry or entry.State ~= "belt" then
		return
	end
	local data = PlayerData.Get(player)
	if not data then
		return
	end
	local def = entry.Def
	if not def then
		return
	end
	if data.Cash < def.Price then
		notify(player, "Not enough cash")
		return
	end
	local baseIndex = BaseManager.GetBase(player)
	if not baseIndex then
		notify(player, "You have no enclosure yet")
		return
	end
	local padIndex = BaseManager.FreePadIndex(baseIndex, data)
	if not padIndex then
		notify(player, "Your pen is full")
		return
	end
	-- Claim the pad before the walk so a second buy cannot race for it.
	data.Cash -= def.Price
	PlayerData.SyncLeaderstats(player)
	beltEntries[entry] = nil
	entry.State = "walking"
	entry.Owner = player
	if entry.Model then
		entry.Model:SetAttribute("State", "walking")
		-- The belt prompt comes off: this one is spoken for.
		for _, descendant in ipairs(entry.Model:GetDescendants()) do
			if descendant:IsA("ProximityPrompt") then
				descendant:Destroy()
			end
		end
	end
	Contracts.OnEvent(player, "Buy")
	Trail.OnEvent(player, "Buy")
	local targetPad = BaseManager.PadPosition(baseIndex, padIndex)
	task.spawn(function()
		if not targetPad then
			return
		end
		local arrived = Conveyor.WalkTo(entry, targetPad, WALK_SPEED)
		if entry.Cleared then
			return
		end
		if not arrived or not entry.Model or not entry.Model.Parent then
			-- The walk failed; refund rather than strand the purchase.
			local live = PlayerData.Get(player)
			if live then
				live.Cash += def.Price
				PlayerData.SyncLeaderstats(player)
			end
			GameState.Unregister(entry)
			if entry.Model then
				entry.Model:Destroy()
			end
			return
		end
		-- The reserved pad may have been taken while walking; re-pick.
		local liveData = PlayerData.Get(player)
		local finalPad = padIndex
		if not BaseManager.IsPadFree(baseIndex, finalPad) then
			finalPad = liveData and BaseManager.FreePadIndex(baseIndex, liveData) or nil
		end
		if not finalPad then
			if liveData then
				liveData.Cash += def.Price
				PlayerData.SyncLeaderstats(player)
			end
			GameState.Unregister(entry)
			entry.Model:Destroy()
			notify(player, "Your pen filled up - purchase refunded")
			return
		end
		BaseManager.PlaceOnPad(entry, baseIndex, finalPad)
		Contracts.OnEvent(player, "PenRarity", def.Rarity)
		Trail.OnEvent(player, "Placed")
	end)
end

local function spawnOne()
	local modifier = Events.SpawnModifier()
	local def = BrainrotData.Roll(rng, modifier.DoubleRoll == true, modifier.ForceCommon == true)
	if not def then
		return
	end
	local model = CharacterFactory.Build(def.Id)
	if not model then
		return
	end
	local entry = {
		Id = nextEntryId,
		DefId = def.Id,
		Def = def,
		Model = model,
		Owner = nil,
		State = "belt",
		BaseIndex = nil,
		PadIndex = nil,
	}
	nextEntryId += 1
	GameState.Register(entry)
	beltEntries[entry] = true
	local spawnPos = Vector3.new(BELT_START_X, BELT_TOP_Y, 0)
	CharacterFactory.SetPose(model, spawnPos, 0, 0)
	CharacterFactory.AttachBeltPrompt(entry, function(_promptEntry: any, buyer: Player)
		Conveyor.BuyRequest(buyer, entry)
	end)
	local ok, rank = pcall(function()
		return BrainrotData.RarityRank(def.Rarity)
	end)
	if ok and typeof(rank) == "number" and rank >= MYTHIC_RANK then
		Notify:FireAllClients("A " .. string.upper(def.Rarity) .. " " .. def.Name .. " appeared on the Parade Path!")
	end
end

function Conveyor.Start(w: any)
	world = w
	if world and typeof(world.BeltStartX) == "number" then
		-- Trust the built world over local fallbacks when it offers them.
	end
	-- Spawn loop: interval breathes with the live event modifiers.
	task.spawn(function()
		while true do
			local modifier = Events.SpawnModifier()
			local interval = SPAWN_INTERVAL * (modifier.IntervalScale or 1)
			task.wait(math.max(0.25, interval))
			modifier = Events.SpawnModifier()
			local cap = BELT_CAP + (modifier.ExtraCap or 0)
			if beltCount() < cap then
				spawnOne()
			end
		end
	end)
	-- Walk loop: everything on the belt shuffles east, grounded and
	-- bobbing, until it slips into the exit cave and despawns.
	RunService.Heartbeat:Connect(function(dt)
		local step = BELT_SPEED * dt
		for entry in pairs(beltEntries) do
			local model = entry.Model
			if not model or not model.Parent or entry.State ~= "belt" then
				beltEntries[entry] = nil
			else
				local current = modelPosition(model)
				local nextX = current.X + step
				if nextX >= BELT_END_X then
					beltEntries[entry] = nil
					GameState.Unregister(entry)
					model:Destroy()
				else
					local bob = math.abs(math.sin(os.clock() * 7 + entry.Id)) * 0.12
					local nextPos = Vector3.new(nextX, current.Y, current.Z)
					CharacterFactory.SetPose(model, nextPos, 0, bob)
				end
			end
		end
	end)
	print("[SahurZoo] Conveyor rolling")
end

-- Destroys any belt/walking entries a departing player owns so nothing
-- is left strolling the path with no keeper.
function Conveyor.DestroyOwned(player: Player)
	for entry in pairs(beltEntries) do
		if entry.Owner == player then
			beltEntries[entry] = nil
			GameState.Unregister(entry)
			if entry.Model then
				entry.Model:Destroy()
			end
		end
	end
	for entry in pairs(walkingEntries) do
		if entry.Owner == player then
			entry.Cleared = true
			GameState.Unregister(entry)
			if entry.Model then
				entry.Model:Destroy()
			end
		end
	end
end

function Conveyor.IsWalking(entry: any): boolean
	return walkingEntries[entry] == true
end

Players.PlayerRemoving:Connect(function()
	-- Cleanup is driven by the bootstrap; kept here as documentation
	-- that DestroyOwned is the entry point for it.
end)

return Conveyor
