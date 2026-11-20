-- init.server.luau (the GameServer script)
-- SAHUR ZOO bootstrap. Wires the whole zoo together in order:
--   1. the Brainrots folder the live models live in,
--   2. the world (parade path, enclosures, stands, signs),
--   3. per-player setup as keepers arrive (data, enclosure, contracts,
--      trail, slap tool, walk speed),
--   4. the remotes the HUD talks to,
--   5. the running loops: conveyor, events, economy, stealing.
-- Character templates and world dressing load in the background; the
-- game already plays on fallback models while they stream in.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerData = require(script:WaitForChild("PlayerData"))
local GameState = require(script:WaitForChild("GameState"))
local CharacterFactory = require(script:WaitForChild("CharacterFactory"))
local WorldBuilder = require(script:WaitForChild("WorldBuilder"))
local BaseManager = require(script:WaitForChild("BaseManager"))
local Conveyor = require(script:WaitForChild("Conveyor"))
local Economy = require(script:WaitForChild("Economy"))
local StealSystem = require(script:WaitForChild("StealSystem"))
local Contracts = require(script:WaitForChild("Contracts"))
local Trail = require(script:WaitForChild("Trail"))
local Events = require(script:WaitForChild("Events"))

print("[SahurZoo] booting SAHUR ZOO...")

-- Live brainrot models live here (CharacterFactory builds into it and
-- the HUD's prompt filter scans it).
local brainrotsFolder = workspace:FindFirstChild("Brainrots")
if not brainrotsFolder then
	brainrotsFolder = Instance.new("Folder")
	brainrotsFolder.Name = "Brainrots"
	brainrotsFolder.Parent = workspace
end

local world = WorldBuilder.Build()
print("[SahurZoo] world built")
BaseManager.Init(world)
StealSystem.Init(world)

task.spawn(function()
	CharacterFactory.PrepareTemplates()
	print("[SahurZoo] character templates ready")
end)
task.spawn(function()
	WorldBuilder.DressUp()
	print("[SahurZoo] world dressed")
end)

local function setupCharacter(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	StealSystem.ApplyWalkSpeed(player)
	-- A fresh character drops the carry flag and any equipped tool.
	character:SetAttribute("Carrying", false)
	task.defer(function()
		Economy.GiveSlapTool(player)
	end)
	local _ = humanoid
end

local function setupPlayer(player: Player)
	PlayerData.Load(player)
	local baseIndex = BaseManager.AssignBase(player)
	if baseIndex then
		print("[SahurZoo] " .. player.Name .. " took enclosure " .. tostring(baseIndex))
	else
		warn("[SahurZoo] no free enclosure for " .. player.Name)
	end
	Contracts.InitPlayer(player)
	Trail.InitPlayer(player)
	Economy.GiveSlapTool(player)
	Economy.PushHud(player)
	if player.Character then
		setupCharacter(player, player.Character)
	end
	player.CharacterAdded:Connect(function(character: Model)
		setupCharacter(player, character)
	end)
end

local function teardownPlayer(player: Player)
	-- Anything being carried (by or of this player) goes first.
	StealSystem.CleanupPlayer(player)
	Conveyor.DestroyOwned(player)
	-- Then their penned brainrots.
	local placed = GameState.PlacedOf(player)
	if placed then
		for _, entry in ipairs(placed) do
			entry.Cleared = true
			BaseManager.RemoveFromPad(entry)
			GameState.Unregister(entry)
			if entry.Model then
				entry.Model:Destroy()
			end
		end
	end
	BaseManager.ReleaseBase(player)
	PlayerData.Unload(player)
end

Players.PlayerAdded:Connect(setupPlayer)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(setupPlayer, player)
end
Players.PlayerRemoving:Connect(teardownPlayer)

-- Remotes ------------------------------------------------------------
-- HudAction carries the LOCK PEN / REBIRTH buttons (and L / R keys).
-- The slap goes through the SlapHand Tool's own Activated event on the
-- server (see Economy.GiveSlapTool), so the HUD never fires a Slap
-- remote for it.
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local HudAction = Remotes:WaitForChild("HudAction") :: RemoteEvent
HudAction.OnServerEvent:Connect(function(player: Player, action: any)
	if typeof(action) == "string" then
		Economy.HandleAction(player, action)
	end
end)

-- Loops ---------------------------------------------------------------
Conveyor.Start(world)
Events.Start()
Economy.Start(world)

print("[SahurZoo] server ready")
