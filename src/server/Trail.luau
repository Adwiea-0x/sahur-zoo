-- Trail.luau
-- SAHUR ZOO: the new-keeper trail. Four steps, completable in any order:
--   1. Buy a brainrot from the Parade Path.
--   2. Watch your first brainrot settle into a pen.
--   3. Lock your enclosure.
--   4. Steal from a rival, OR earn $500 of lifetime income.
-- Finishing all four pays a one-off $250 welcome bonus.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerData = require(script.Parent:WaitForChild("PlayerData"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local TrailState = Remotes:WaitForChild("TrailState") :: RemoteEvent
local Celebrate = Remotes:WaitForChild("Celebrate") :: RemoteEvent
local Notify = Remotes:WaitForChild("Notify") :: RemoteEvent

local EARN_TARGET = 500
local COMPLETION_BONUS = 250

local Trail = {}

local function ensureFlags(data: any)
	if typeof(data.TrailFlags) ~= "table" then
		data.TrailFlags = { false, false, false, false }
	end
	for i = 1, 4 do
		if data.TrailFlags[i] == nil then
			data.TrailFlags[i] = false
		end
	end
end

local function pushState(player: Player, data: any)
	ensureFlags(data)
	local done = {
		data.TrailFlags[1] == true,
		data.TrailFlags[2] == true,
		data.TrailFlags[3] == true,
		data.TrailFlags[4] == true,
	}
	local firstOpen = 5
	for i = 1, 4 do
		if not done[i] then
			firstOpen = i
			break
		end
	end
	TrailState:FireClient(player, {
		Step = firstOpen,
		Done = done,
		Complete = firstOpen == 5,
	})
end

function Trail.InitPlayer(player: Player)
	local data = PlayerData.Get(player)
	if not data then
		return
	end
	ensureFlags(data)
	if data.TrailDone == nil then
		data.TrailDone = false
	end
	-- A returning keeper may already qualify for step 4 on income.
	if not data.TrailFlags[4] and (data.LifetimeIncome or 0) >= EARN_TARGET then
		data.TrailFlags[4] = true
	end
	pushState(player, data)
end

function Trail.PushState(player: Player)
	local data = PlayerData.Get(player)
	if data then
		pushState(player, data)
	end
end

function Trail.OnEvent(player: Player, kind: string, payload: any)
	local data = PlayerData.Get(player)
	if not data then
		return
	end
	ensureFlags(data)
	local flags = data.TrailFlags
	local before = flags[1] and flags[2] and flags[3] and flags[4]
	if kind == "Buy" then
		flags[1] = true
	elseif kind == "Placed" then
		flags[2] = true
	elseif kind == "Lock" then
		flags[3] = true
	elseif kind == "Steal" then
		flags[4] = true
	elseif kind == "Earn" then
		if (data.LifetimeIncome or 0) >= EARN_TARGET then
			flags[4] = true
		end
	end
	local after = flags[1] and flags[2] and flags[3] and flags[4]
	pushState(player, data)
	if after and not before and not data.TrailDone then
		data.TrailDone = true
		data.Cash += COMPLETION_BONUS
		PlayerData.SyncLeaderstats(player)
		Celebrate:FireClient(player, "TRAIL COMPLETE! +$" .. tostring(COMPLETION_BONUS))
		Notify:FireClient(player, "Keeper trail complete! Bonus $" .. tostring(COMPLETION_BONUS) .. " paid.")
	end
end

return Trail
