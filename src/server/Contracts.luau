-- Contracts.luau
-- SAHUR ZOO: the contracts board. Every keeper runs three contracts at a
-- time, drawn from a pool of twelve small jobs (buy, pen a rarity, lock,
-- steal, sell, earn). Finishing one pays its reward in cash, pops a
-- celebration on the keeper's screen, and deals a fresh non-duplicate
-- replacement so the board never empties.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BrainrotData = require(Shared:WaitForChild("BrainrotData"))
local PlayerData = require(script.Parent:WaitForChild("PlayerData"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local ContractsState = Remotes:WaitForChild("ContractsState") :: RemoteEvent
local Celebrate = Remotes:WaitForChild("Celebrate") :: RemoteEvent
local Notify = Remotes:WaitForChild("Notify") :: RemoteEvent

local Contracts = {}

-- The pool. Kind is the event that advances the contract; Rarity is only
-- used by PenRarity contracts (the penned brainrot must be that rarity
-- or better).
local POOL = {
	{ Id = "buy1", Kind = "Buy", Goal = 1, Reward = 40, Text = "Buy a brainrot" },
	{ Id = "buy3", Kind = "Buy", Goal = 3, Reward = 150, Text = "Buy 3 brainrots" },
	{ Id = "buy5", Kind = "Buy", Goal = 5, Reward = 300, Text = "Buy 5 brainrots" },
	{ Id = "penrare", Kind = "PenRarity", Goal = 2, Reward = 350, Rarity = "Rare", Text = "Pen 2 RARE or better" },
	{ Id = "penepic", Kind = "PenRarity", Goal = 1, Reward = 300, Rarity = "Epic", Text = "Pen an EPIC or better" },
	{ Id = "penlegendary", Kind = "PenRarity", Goal = 1, Reward = 1200, Rarity = "Legendary", Text = "Pen a LEGENDARY or better" },
	{ Id = "lock1", Kind = "Lock", Goal = 1, Reward = 100, Text = "Lock your enclosure" },
	{ Id = "steal1", Kind = "Steal", Goal = 1, Reward = 400, Text = "Steal a brainrot" },
	{ Id = "steal2", Kind = "Steal", Goal = 2, Reward = 900, Text = "Steal 2 brainrots" },
	{ Id = "sell1", Kind = "Sell", Goal = 1, Reward = 80, Text = "Sell a brainrot" },
	{ Id = "earn1000", Kind = "Earn", Goal = 1000, Reward = 250, Text = "Earn $1000 from income" },
	{ Id = "earn5000", Kind = "Earn", Goal = 5000, Reward = 1000, Text = "Earn $5000 from income" },
}

local rng = Random.new()

local function isActive(data: any, id: string): boolean
	for _, contract in ipairs(data.Contracts) do
		if contract.Id == id then
			return true
		end
	end
	return false
end

local function dealOne(data: any): boolean
	-- Collect the pool entries the player is not already running.
	local options = {}
	for _, def in ipairs(POOL) do
		if not isActive(data, def.Id) then
			table.insert(options, def)
		end
	end
	if #options == 0 then
		return false
	end
	local def = options[rng:NextInteger(1, #options)]
	table.insert(data.Contracts, {
		Id = def.Id,
		Kind = def.Kind,
		Goal = def.Goal,
		Progress = 0,
		Reward = def.Reward,
		Text = def.Text,
		Rarity = def.Rarity,
	})
	return true
end

local function pushState(player: Player, data: any)
	local list = {}
	for _, contract in ipairs(data.Contracts) do
		table.insert(list, {
			Text = contract.Text,
			Progress = math.min(contract.Progress, contract.Goal),
			Goal = contract.Goal,
			Reward = contract.Reward,
		})
	end
	ContractsState:FireClient(player, { contracts = list })
end

function Contracts.InitPlayer(player: Player)
	local data = PlayerData.Get(player)
	if not data then
		return
	end
	if typeof(data.Contracts) ~= "table" then
		data.Contracts = {}
	end
	while #data.Contracts < 3 do
		if not dealOne(data) then
			break
		end
	end
	pushState(player, data)
end

function Contracts.PushState(player: Player)
	local data = PlayerData.Get(player)
	if data then
		pushState(player, data)
	end
end

local function rarityRank(name: string): number
	local ok, rank = pcall(function()
		return BrainrotData.RarityRank(name)
	end)
	if ok and typeof(rank) == "number" then
		return rank
	end
	return 0
end

function Contracts.OnEvent(player: Player, kind: string, payload: any)
	local data = PlayerData.Get(player)
	if not data or typeof(data.Contracts) ~= "table" then
		return
	end
	local changed = false
	local completed = {}
	for _, contract in ipairs(data.Contracts) do
		if contract.Kind == kind then
			if kind == "Earn" then
				local amount = tonumber(payload) or 0
				if amount > 0 then
					contract.Progress += amount
					changed = true
				end
			elseif kind == "PenRarity" then
				local needed = contract.Rarity and rarityRank(contract.Rarity) or 0
				local got = typeof(payload) == "string" and rarityRank(payload) or 0
				if got >= needed then
					contract.Progress += 1
					changed = true
				end
			else
				contract.Progress += 1
				changed = true
			end
			if contract.Progress >= contract.Goal then
				table.insert(completed, contract)
			end
		end
	end
	if #completed > 0 then
		-- Remove finished contracts (walk backwards so indices hold).
		for i = #data.Contracts, 1, -1 do
			for _, done in ipairs(completed) do
				if data.Contracts[i] == done then
					table.remove(data.Contracts, i)
					break
				end
			end
		end
		for _, done in ipairs(completed) do
			data.Cash += done.Reward
			Celebrate:FireClient(player, "+" .. tostring(done.Reward) .. " CONTRACT!")
			Notify:FireClient(player, "Contract done: " .. done.Text .. " (+$" .. tostring(done.Reward) .. ")")
			dealOne(data)
		end
		PlayerData.SyncLeaderstats(player)
		changed = true
	end
	if changed then
		pushState(player, data)
	end
end

return Contracts
