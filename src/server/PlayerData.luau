-- PlayerData.luau
-- In-memory per-player state with a DataStore-shaped seam: Load / Get /
-- Unload mirror what a persistent version would do, so swapping the table
-- for real DataStore reads later touches only this module.

local Config = require(game.ReplicatedStorage.Shared.Config)

export type PlayerRecord = {
	Cash: number,
	Rebirths: number,
	SlapLevel: number,
	SpeedLevel: number,
	BaseCapacityLevel: number,
	IncomePerSec: number,
	LifetimeIncome: number,
	Contracts: { [string]: any },
	TrailFlags: { [string]: any },
	TrailDone: boolean,
	BaseIndex: number?,
}

local store: { [Player]: PlayerRecord } = {}
local leaderFolders: { [Player]: Folder } = {}

local function buildLeaderstats(player: Player, data: PlayerRecord): Folder
	local folder = Instance.new("Folder")
	folder.Name = "leaderstats"

	local cash = Instance.new("IntValue")
	cash.Name = "Cash"
	cash.Value = math.floor(data.Cash)
	cash.Parent = folder

	local income = Instance.new("IntValue")
	income.Name = "Income"
	income.Value = math.floor(data.IncomePerSec)
	income.Parent = folder

	local rebirths = Instance.new("IntValue")
	rebirths.Name = "Rebirths"
	rebirths.Value = math.floor(data.Rebirths)
	rebirths.Parent = folder

	folder.Parent = player
	return folder
end

local PlayerData = {}

function PlayerData.Load(player: Player): PlayerRecord
	local existing = store[player]
	if existing then
		return existing
	end

	local data: PlayerRecord = {
		Cash = Config.StartCash,
		Rebirths = 0,
		SlapLevel = 0,
		SpeedLevel = 0,
		BaseCapacityLevel = 0,
		IncomePerSec = 0,
		LifetimeIncome = 0,
		Contracts = {},
		TrailFlags = {},
		TrailDone = false,
		BaseIndex = nil,
	}

	store[player] = data

	local old = player:FindFirstChild("leaderstats")
	if old then
		old:Destroy()
	end
	leaderFolders[player] = buildLeaderstats(player, data)

	return data
end

function PlayerData.Get(player: Player): PlayerRecord?
	return store[player]
end

function PlayerData.Unload(player: Player)
	store[player] = nil
	leaderFolders[player] = nil
end

function PlayerData.SyncLeaderstats(player: Player)
	local data = store[player]
	if not data then
		return
	end
	local folder = leaderFolders[player] or player:FindFirstChild("leaderstats")
	if not folder then
		return
	end
	local cash = folder:FindFirstChild("Cash")
	if cash and cash:IsA("IntValue") then
		cash.Value = math.floor(data.Cash)
	end
	local income = folder:FindFirstChild("Income")
	if income and income:IsA("IntValue") then
		income.Value = math.floor(data.IncomePerSec)
	end
	local rebirths = folder:FindFirstChild("Rebirths")
	if rebirths and rebirths:IsA("IntValue") then
		rebirths.Value = math.floor(data.Rebirths)
	end
end

-- Test / debug helper: wipe everything (not used in normal play).
function PlayerData._ResetAll()
	table.clear(store)
	table.clear(leaderFolders)
end

return PlayerData
