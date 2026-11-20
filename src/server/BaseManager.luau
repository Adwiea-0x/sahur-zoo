-- BaseManager.luau
-- SAHUR ZOO: owns the twelve zoo enclosures ("bases").
--
-- One enclosure per player, handed out first-come-first-served. Each
-- enclosure has 24 pen pads; how many of them are usable depends on the
-- owner's capacity level (GameState.CapacityOf). Pads past capacity are
-- hidden and non-collidable so an enclosure visibly grows as its owner
-- upgrades. This module also owns the lock wall state and the big sign
-- board text for every enclosure.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local GameState = require(script.Parent:WaitForChild("GameState"))
local CharacterFactory = require(script.Parent:WaitForChild("CharacterFactory"))
local PlayerData = require(script.Parent:WaitForChild("PlayerData"))

local function cfg(key: string, fallback: any): any
	local value = (Config :: any)[key]
	if value == nil then
		return fallback
	end
	return value
end

local TOTAL_PADS = cfg("PadsPerBase", 24)
local DEFAULT_CAPACITY = 8
local PEN_COLS = 6
do
	local enclosures = (Config :: any).Enclosures
	if typeof(enclosures) == "table" and typeof(enclosures.PenCols) == "number" then
		PEN_COLS = enclosures.PenCols
	end
end

local BaseManager = {}

local world: any = nil
local baseOwners: { [number]: Player } = {} -- baseIndex -> player
local playerBases: { [Player]: number } = {} -- player -> baseIndex
local padOccupants: { [number]: { [number]: any } } = {} -- baseIndex -> padIndex -> entry
local lockedBases: { [number]: boolean } = {}
local padParts: { [number]: { [number]: BasePart } } = {}

-- Finds the pen disc WorldBuilder laid for one pad. Pads are numbered
-- row-major (6 discs per row), matching PadPositions order.
local function getPadPart(baseIndex: number, padIndex: number): BasePart?
	local byBase = padParts[baseIndex]
	if byBase and byBase[padIndex] then
		return byBase[padIndex]
	end
	if not world then
		return nil
	end
	local base = world.Bases[baseIndex]
	if not base or not base.Folder then
		return nil
	end
	local row = math.floor((padIndex - 1) / PEN_COLS) + 1
	local col = ((padIndex - 1) % PEN_COLS) + 1
	local disc = base.Folder:FindFirstChild(string.format("Pen_%d_%d", row, col))
	if disc and disc:IsA("BasePart") then
		if not byBase then
			byBase = {}
			padParts[baseIndex] = byBase
		end
		byBase[padIndex] = disc :: BasePart
		return disc :: BasePart
	end
	return nil
end

local function capacityForBase(baseIndex: number): number
	local owner = baseOwners[baseIndex]
	if not owner then
		return DEFAULT_CAPACITY
	end
	local data = PlayerData.Get(owner)
	if not data then
		return DEFAULT_CAPACITY
	end
	local ok, capacity = pcall(function()
		return GameState.CapacityOf(data)
	end)
	if ok and typeof(capacity) == "number" then
		return capacity
	end
	return DEFAULT_CAPACITY
end

function BaseManager.Init(w: any)
	world = w
	for index, base in ipairs(world.Bases) do
		padOccupants[index] = {}
		lockedBases[index] = false
		local _ = base
		BaseManager.RefreshPadVisibility(index)
		BaseManager.SetLocked(index, false)
		BaseManager.RefreshSign(index)
	end
	-- Signs show live cash / pen counts, so keep occupied ones fresh.
	task.spawn(function()
		while true do
			task.wait(0.5)
			for baseIndex in pairs(baseOwners) do
				BaseManager.RefreshSign(baseIndex)
			end
		end
	end)
	print("[SahurZoo] BaseManager ready (" .. tostring(#world.Bases) .. " enclosures)")
end

function BaseManager.AssignBase(player: Player): number?
	if playerBases[player] then
		return playerBases[player]
	end
	for index = 1, #world.Bases do
		if not baseOwners[index] then
			baseOwners[index] = player
			playerBases[player] = index
			BaseManager.RefreshPadVisibility(index)
			BaseManager.RefreshSign(index)
			return index
		end
	end
	return nil
end

function BaseManager.ReleaseBase(player: Player)
	local index = playerBases[player]
	if not index then
		return
	end
	playerBases[player] = nil
	baseOwners[index] = nil
	padOccupants[index] = {}
	BaseManager.SetLocked(index, false)
	BaseManager.RefreshPadVisibility(index)
	BaseManager.RefreshSign(index)
end

function BaseManager.GetBase(player: Player): number?
	return playerBases[player]
end

function BaseManager.GetOwner(baseIndex: number): Player?
	return baseOwners[baseIndex]
end

function BaseManager.GetWorld(): any
	return world
end

function BaseManager.GetBaseInfo(baseIndex: number): any
	if not world then
		return nil
	end
	return world.Bases[baseIndex]
end

function BaseManager.RefreshPadVisibility(baseIndex: number)
	if not world then
		return
	end
	local base = world.Bases[baseIndex]
	if not base then
		return
	end
	local capacity = capacityForBase(baseIndex)
	for padIndex = 1, #base.PadPositions do
		local part = getPadPart(baseIndex, padIndex)
		if part then
			if padIndex <= capacity then
				part.Transparency = 0
			else
				part.Transparency = 1
				part.CanCollide = false
			end
		end
	end
end

function BaseManager.FreePadIndex(baseIndex: number, data: any): number?
	if not world then
		return nil
	end
	local capacity = DEFAULT_CAPACITY
	local ok, result = pcall(function()
		return GameState.CapacityOf(data)
	end)
	if ok and typeof(result) == "number" then
		capacity = result
	end
	local occupants = padOccupants[baseIndex]
	if not occupants then
		return nil
	end
	for padIndex = 1, math.min(capacity, TOTAL_PADS) do
		if not occupants[padIndex] then
			return padIndex
		end
	end
	return nil
end

function BaseManager.IsPadFree(baseIndex: number, padIndex: number): boolean
	local occupants = padOccupants[baseIndex]
	if not occupants then
		return false
	end
	return occupants[padIndex] == nil
end

function BaseManager.PadPosition(baseIndex: number, padIndex: number): Vector3?
	if not world then
		return nil
	end
	local base = world.Bases[baseIndex]
	if not base then
		return nil
	end
	return base.PadPositions[padIndex]
end

function BaseManager.PadsUsed(baseIndex: number): number
	local occupants = padOccupants[baseIndex]
	if not occupants then
		return 0
	end
	local used = 0
	for _ in pairs(occupants) do
		used += 1
	end
	return used
end

function BaseManager.PlaceOnPad(entry: any, baseIndex: number, padIndex: number)
	local base = world.Bases[baseIndex]
	local position = base.PadPositions[padIndex]
	padOccupants[baseIndex][padIndex] = entry
	entry.BaseIndex = baseIndex
	entry.PadIndex = padIndex
	entry.State = "placed"
	local owner = baseOwners[baseIndex]
	if owner then
		entry.Owner = owner
	end
	if entry.Model then
		entry.Model:SetAttribute("State", "placed")
		if owner then
			entry.Model:SetAttribute("OwnerUserId", owner.UserId)
		end
		-- Face the front of the enclosure so visitors see the label.
		CharacterFactory.SetPose(entry.Model, position, math.pi, 0)
		CharacterFactory.SetPlacedPrompts(entry)
	end
	if owner then
		GameState.RecountIncome(owner)
	end
	BaseManager.RefreshSign(baseIndex)
	-- Let StealSystem wire the fresh Steal/Sell prompts (lazy require:
	-- StealSystem requires this module, so never load it at file scope).
	task.defer(function()
		local ok, steal = pcall(function()
			return require(script.Parent:WaitForChild("StealSystem"))
		end)
		if ok and steal and steal.HookEntry then
			steal.HookEntry(entry)
		end
	end)
end

function BaseManager.RemoveFromPad(entry: any)
	local baseIndex = entry.BaseIndex
	local padIndex = entry.PadIndex
	if baseIndex and padIndex and padOccupants[baseIndex] then
		if padOccupants[baseIndex][padIndex] == entry then
			padOccupants[baseIndex][padIndex] = nil
		end
	end
	-- Remember the home pen so a dropped brainrot can walk back to it.
	if baseIndex then
		entry.LastBaseIndex = baseIndex
	end
	if padIndex then
		entry.LastPadIndex = padIndex
	end
	entry.BaseIndex = nil
	entry.PadIndex = nil
	if entry.Model then
		entry.Model:SetAttribute("OwnerUserId", nil)
	end
	local owner = entry.Owner
	if owner then
		GameState.RecountIncome(owner)
	end
	if baseIndex then
		BaseManager.RefreshSign(baseIndex)
	end
end

function BaseManager.SetLocked(baseIndex: number, locked: boolean)
	lockedBases[baseIndex] = locked
	if not world then
		return
	end
	local base = world.Bases[baseIndex]
	if base and base.LockWall then
		local wall = base.LockWall :: BasePart
		wall.CanCollide = locked
		wall.Transparency = locked and 0.35 or 1
	end
	BaseManager.RefreshSign(baseIndex)
end

function BaseManager.IsLocked(baseIndex: number): boolean
	return lockedBases[baseIndex] == true
end

function BaseManager.RefreshSign(baseIndex: number)
	if not world then
		return
	end
	local base = world.Bases[baseIndex]
	if not base or not base.SignGui then
		return
	end
	local owner = baseOwners[baseIndex]
	local data = owner and PlayerData.Get(owner) or nil
	local capacity = capacityForBase(baseIndex)
	local used = BaseManager.PadsUsed(baseIndex)
	local locked = BaseManager.IsLocked(baseIndex)
	-- WorldBuilder's sign has one named label per line; write each line
	-- to its own label when they exist.
	local labels: { [string]: TextLabel } = {}
	local fallback: TextLabel? = nil
	for _, descendant in ipairs(base.SignGui:GetDescendants()) do
		if descendant:IsA("TextLabel") then
			labels[descendant.Name] = descendant :: TextLabel
			if not fallback then
				fallback = descendant :: TextLabel
			end
		end
	end
	if labels.TitleLabel or labels.OwnerLabel or labels.StatsLabel or labels.StatusLabel then
		if labels.TitleLabel then
			labels.TitleLabel.Text = "PEN " .. tostring(baseIndex)
		end
		if labels.OwnerLabel then
			labels.OwnerLabel.Text = owner and owner.DisplayName or "UNOCCUPIED"
		end
		if labels.StatsLabel then
			labels.StatsLabel.Text = string.format("$%d  -  %d/%d pens", data and data.Cash or 0, used, capacity)
		end
		if labels.StatusLabel then
			labels.StatusLabel.Text = locked and "LOCKED" or "OPEN"
		end
	elseif fallback then
		local lines = {
			"PEN " .. tostring(baseIndex),
			owner and owner.DisplayName or "UNOCCUPIED",
			"$" .. tostring(data and data.Cash or 0),
			string.format("Pens %d/%d", used, capacity),
			locked and "LOCKED" or "OPEN",
		}
		(fallback :: TextLabel).Text = table.concat(lines, "\n")
	end
end

-- Kept for symmetry with the other managers; nothing per-player to set up
-- beyond AssignBase, which the server bootstrap calls directly.
function BaseManager.PlayerLeft(player: Player)
	BaseManager.ReleaseBase(player)
end

Players.PlayerRemoving:Connect(function()
	-- ReleaseBase is driven by the bootstrap so entry cleanup happens
	-- first; this connection only guards against a missed release.
end)

return BaseManager
