-- GameState.luau
-- Registry of every live brainrot entry plus the income maths that depends
-- on who owns what and where it is standing.

local Config = require(game.ReplicatedStorage.Shared.Config)
local PlayerData = require(script.Parent.PlayerData)

export type EntryState = "belt" | "walking" | "placed" | "carried" | "returning"

export type Entry = {
	Id: number,
	DefId: string,
	Def: any,
	Model: Model,
	Owner: Player?,
	State: EntryState,
	BaseIndex: number?,
	PadIndex: number?,
}

local GameState = {}

GameState.GlobalIncomeMultiplier = 1

local entries: { [number]: Entry } = {}
local nextId = 0

function GameState.Register(entry: Entry): Entry
	if not entry.Id or entry.Id == 0 then
		nextId += 1
		entry.Id = nextId
	else
		nextId = math.max(nextId, entry.Id)
	end
	entries[entry.Id] = entry
	return entry
end

function GameState.Unregister(entry: Entry)
	if entry and entry.Id then
		entries[entry.Id] = nil
	end
end

function GameState.GetById(id: number): Entry?
	return entries[id]
end

function GameState.All(): { [number]: Entry }
	return entries
end

function GameState.PlacedOf(player: Player): { Entry }
	local out: { Entry } = {}
	for _, entry in pairs(entries) do
		if entry.Owner == player and entry.State == "placed" then
			table.insert(out, entry)
		end
	end
	table.sort(out, function(a, b)
		return (a.PadIndex or 0) < (b.PadIndex or 0)
	end)
	return out
end

function GameState.EntriesOf(player: Player): { Entry }
	local out: { Entry } = {}
	for _, entry in pairs(entries) do
		if entry.Owner == player then
			table.insert(out, entry)
		end
	end
	return out
end

function GameState.CapacityOf(data: any): number
	if not data then
		return Config.Capacity.PensByLevel[1]
	end
	local level = 0
	if typeof(data.BaseCapacityLevel) == "number" then
		level = data.BaseCapacityLevel
	end
	return Config.CapacityForLevel(level)
end

function GameState.MultiplierOf(data: any): number
	if not data then
		return 1
	end
	local rebirths = 0
	if typeof(data.Rebirths) == "number" then
		rebirths = data.Rebirths
	end
	return Config.MultiplierForRebirths(rebirths)
end

function GameState.RecountIncome(player: Player)
	local data = PlayerData.Get(player)
	if not data then
		return
	end
	local base = 0
	for _, entry in pairs(entries) do
		if entry.Owner == player and entry.State == "placed" and entry.Def then
			base += entry.Def.IncomePerSec or 0
		end
	end
	local total = base * GameState.MultiplierOf(data) * GameState.GlobalIncomeMultiplier
	data.IncomePerSec = total
	PlayerData.SyncLeaderstats(player)
end

function GameState.CountByState(state: EntryState): number
	local n = 0
	for _, entry in pairs(entries) do
		if entry.State == state then
			n += 1
		end
	end
	return n
end

return GameState
