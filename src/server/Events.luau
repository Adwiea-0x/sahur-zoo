-- Events.luau
-- SAHUR ZOO: rotating server events that shake up the Parade Path.
--   STAMPEDE    45s of spawns at double pace, each spawn rolled twice
--               (keep the better rarity), and a roomier belt.
--   GOLDEN HOUR 60s of double income for every pen in the zoo.
--   ANIMAL RAIN 30s of commons absolutely pouring out of the cave.
-- The first event starts 60s after the server boots, events rest for
-- 150s between runs, and the same event never runs twice in a row. The
-- HUD banner is fed by an EventState broadcast every second.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameState = require(script.Parent:WaitForChild("GameState"))
local PlayerData = require(script.Parent:WaitForChild("PlayerData"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local EventState = Remotes:WaitForChild("EventState") :: RemoteEvent
local Notify = Remotes:WaitForChild("Notify") :: RemoteEvent

local FIRST_DELAY = 60
local REST_SECONDS = 150

local DEFS = {
	{
		Id = "STAMPEDE",
		Name = "STAMPEDE",
		Duration = 45,
		Modifiers = { IntervalScale = 0.5, ForceCommon = false, DoubleRoll = true, ExtraCap = 4 },
	},
	{
		Id = "GOLDEN",
		Name = "GOLDEN HOUR",
		Duration = 60,
		Modifiers = { IntervalScale = 1, ForceCommon = false, DoubleRoll = false, ExtraCap = 0 },
	},
	{
		Id = "RAIN",
		Name = "ANIMAL RAIN",
		Duration = 30,
		Modifiers = { IntervalScale = 0.18, ForceCommon = true, DoubleRoll = false, ExtraCap = 12 },
	},
}

local Events = {}

local rng = Random.new()
local mode = "rest" -- "rest" | "live"
local activeDef: any = nil
local nextDef: any = nil
local phaseEndsAt = os.clock() + FIRST_DELAY
local lastDefId: string? = nil

local function notifyAll(text: string)
	Notify:FireAllClients(text)
end

local function pickNext(): any
	local options = {}
	for _, def in ipairs(DEFS) do
		if def.Id ~= lastDefId then
			table.insert(options, def)
		end
	end
	return options[rng:NextInteger(1, #options)]
end

local function refreshIncomes()
	for _, player in ipairs(Players:GetPlayers()) do
		GameState.RecountIncome(player)
		PlayerData.SyncLeaderstats(player)
	end
end

local function startEvent(def: any)
	activeDef = def
	lastDefId = def.Id
	mode = "live"
	phaseEndsAt = os.clock() + def.Duration
	if def.Id == "GOLDEN" then
		GameState.GlobalIncomeMultiplier = 2
		refreshIncomes()
	end
	notifyAll(def.Name .. " has begun at the Parade Path!")
end

local function endEvent()
	if activeDef and activeDef.Id == "GOLDEN" then
		GameState.GlobalIncomeMultiplier = 1
		refreshIncomes()
	end
	if activeDef then
		notifyAll(activeDef.Name .. " is over.")
	end
	activeDef = nil
	mode = "rest"
	nextDef = pickNext()
	phaseEndsAt = os.clock() + REST_SECONDS
end

function Events.SpawnModifier(): any
	if mode == "live" and activeDef then
		local m = activeDef.Modifiers
		return {
			IntervalScale = m.IntervalScale,
			ForceCommon = m.ForceCommon,
			DoubleRoll = m.DoubleRoll,
			ExtraCap = m.ExtraCap,
		}
	end
	return { IntervalScale = 1, ForceCommon = false, DoubleRoll = false, ExtraCap = 0 }
end

function Events.Start()
	nextDef = pickNext()
	phaseEndsAt = os.clock() + FIRST_DELAY
	task.spawn(function()
		while true do
			task.wait(1)
			local now = os.clock()
			if now >= phaseEndsAt then
				if mode == "rest" then
					startEvent(nextDef or pickNext())
				else
					endEvent()
				end
			end
			local shown = if mode == "live" then activeDef else nextDef
			EventState:FireAllClients({
				Mode = mode,
				Name = shown and shown.Name or "",
				SecondsLeft = math.max(0, math.ceil(phaseEndsAt - os.clock())),
			})
		end
	end)
	print("[SahurZoo] Events rotating (first event in " .. tostring(FIRST_DELAY) .. "s)")
end

return Events
