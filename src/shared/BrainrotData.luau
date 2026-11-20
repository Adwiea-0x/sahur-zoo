-- BrainrotData.luau
-- The cast of SAHUR ZOO: sixteen brainrots with prices, income, spawn
-- weights and (where available) Creator Store asset ids. Six of them have
-- no asset and are built procedurally from plain parts instead.

local Config = require(game.ReplicatedStorage.Shared.Config)

export type BrainrotDef = {
	Id: string,
	Name: string,
	Rarity: string,
	Price: number,
	IncomePerSec: number,
	SpawnWeight: number,
	AssetId: number,
	AccentColor: Color3,
	ScaleTo: number?,
	BuildFallback: (() -> Model)?,
}

-- Part helpers ---------------------------------------------------------------

local function makePart(
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	shape: Enum.PartType?,
	material: Enum.Material?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	if shape then
		p.Shape = shape
	end
	if material then
		p.Material = material
	end
	return p
end

local function makeRoot(height: number): Part
	-- Invisible anchor. Its bottom face sits at local y = 0 so a model can
	-- be planted by putting the Root pivot on the ground.
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(0.4, 0.4, 0.4)
	root.CFrame = CFrame.new(0, 0.2, 0)
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	return root
end

local function finishModel(name: string, parts: { Part }): Model
	local model = Instance.new("Model")
	model.Name = name
	local root: Part? = nil
	for _, p in ipairs(parts) do
		if p.Name == "Root" then
			root = p
		end
		p.Parent = model
	end
	if root then
		model.PrimaryPart = root
	end
	return model
end

local function eyePair(y: number, z: number, spread: number, size: number): { Part }
	local white = Color3.fromRGB(245, 245, 245)
	local black = Color3.fromRGB(15, 15, 18)
	local out = {}
	for _, sx in ipairs({ -1, 1 }) do
		table.insert(out, makePart("Eye", Vector3.new(size, size, 0.12), CFrame.new(sx * spread, y, z), white, Enum.PartType.Ball))
		table.insert(out, makePart("Pupil", Vector3.new(size * 0.45, size * 0.45, 0.08), CFrame.new(sx * spread, y, z - 0.08), black, Enum.PartType.Ball))
	end
	return out
end

local function joinInto(dst: { Part }, src: { Part })
	for _, p in ipairs(src) do
		table.insert(dst, p)
	end
end

-- Fallback builders ----------------------------------------------------------
-- Each returns a fresh anchored Model roughly 3-5 studs tall. All visible
-- parts are CanCollide=false; the Root's bottom is at local y = 0.

local function buildBombombini(): Model
	-- Round goose with a dark bomb belly.
	local white = Color3.fromRGB(240, 240, 235)
	local orange = Color3.fromRGB(255, 150, 30)
	local bombCol = Color3.fromRGB(38, 38, 44)
	local parts: { Part } = { makeRoot(3.4) }
	table.insert(parts, makePart("Body", Vector3.new(2.2, 2.2, 2.4), CFrame.new(0, 1.5, 0), white, Enum.PartType.Ball))
	table.insert(parts, makePart("BombBelly", Vector3.new(1.7, 1.7, 1.7), CFrame.new(0, 1.25, -0.55), bombCol, Enum.PartType.Ball, Enum.Material.Metal))
	table.insert(parts, makePart("Fuse", Vector3.new(0.18, 0.7, 0.18), CFrame.new(0, 2.25, -0.55) * CFrame.Angles(math.rad(25), 0, 0), Color3.fromRGB(160, 120, 70)))
	table.insert(parts, makePart("Spark", Vector3.new(0.42, 0.42, 0.42), CFrame.new(0, 2.62, -0.72), Color3.fromRGB(255, 210, 60), Enum.PartType.Ball, Enum.Material.Neon))
	table.insert(parts, makePart("Neck", Vector3.new(0.7, 1.1, 0.7), CFrame.new(0, 2.9, -0.7), white, Enum.PartType.Ball))
	table.insert(parts, makePart("Head", Vector3.new(1.05, 1.0, 1.05), CFrame.new(0, 3.55, -0.8), white, Enum.PartType.Ball))
	table.insert(parts, makePart("Beak", Vector3.new(0.55, 0.3, 0.7), CFrame.new(0, 3.45, -1.45), orange))
	joinInto(parts, eyePair(3.7, -1.28, 0.28, 0.26))
	table.insert(parts, makePart("FootL", Vector3.new(0.6, 0.18, 0.9), CFrame.new(-0.55, 0.1, -0.2), orange))
	table.insert(parts, makePart("FootR", Vector3.new(0.6, 0.18, 0.9), CFrame.new(0.55, 0.1, -0.2), orange))
	return finishModel("Bombombini Gusini", parts)
end

local function buildTrippi(): Model
	-- Cat-fish: striped fish body, cat ears, whiskers and a tail fin.
	local bodyCol = Color3.fromRGB(255, 170, 90)
	local stripeCol = Color3.fromRGB(210, 90, 40)
	local parts: { Part } = { makeRoot(3.2) }
	table.insert(parts, makePart("Body", Vector3.new(1.9, 1.9, 2.8), CFrame.new(0, 1.6, 0.2), bodyCol, Enum.PartType.Ball))
	table.insert(parts, makePart("Stripe1", Vector3.new(1.96, 0.4, 0.5), CFrame.new(0, 1.7, 0.7), stripeCol))
	table.insert(parts, makePart("Stripe2", Vector3.new(1.9, 0.4, 0.5), CFrame.new(0, 1.65, -0.1), stripeCol))
	table.insert(parts, makePart("Head", Vector3.new(1.5, 1.35, 1.3), CFrame.new(0, 2.15, -1.35), bodyCol, Enum.PartType.Ball))
	table.insert(parts, makePart("EarL", Vector3.new(0.45, 0.65, 0.2), CFrame.new(-0.5, 3.05, -1.3) * CFrame.Angles(0, 0, math.rad(-14)), bodyCol))
	table.insert(parts, makePart("EarR", Vector3.new(0.45, 0.65, 0.2), CFrame.new(0.5, 3.05, -1.3) * CFrame.Angles(0, 0, math.rad(14)), bodyCol))
	table.insert(parts, makePart("Nose", Vector3.new(0.3, 0.22, 0.14), CFrame.new(0, 1.95, -2.02), Color3.fromRGB(255, 120, 140), Enum.PartType.Ball))
	joinInto(parts, eyePair(2.35, -1.95, 0.36, 0.28))
	for _, sx in ipairs({ -1, 1 }) do
		table.insert(parts, makePart("Whisker", Vector3.new(0.9, 0.06, 0.06), CFrame.new(sx * 0.95, 1.9, -1.85) * CFrame.Angles(0, math.rad(sx * 18), 0), Color3.fromRGB(240, 240, 240)))
	end
	table.insert(parts, makePart("TailFin", Vector3.new(0.25, 1.5, 1.1), CFrame.new(0, 1.7, 1.85) * CFrame.Angles(math.rad(20), 0, 0), stripeCol))
	table.insert(parts, makePart("FinL", Vector3.new(0.9, 0.2, 0.6), CFrame.new(-1.15, 1.2, -0.3) * CFrame.Angles(0, 0, math.rad(30)), stripeCol))
	table.insert(parts, makePart("FinR", Vector3.new(0.9, 0.2, 0.6), CFrame.new(1.15, 1.2, -0.3) * CFrame.Angles(0, 0, math.rad(-30)), stripeCol))
	return finishModel("Trippi Troppi", parts)
end

local function buildBoneca(): Model
	-- Frog doll: green head on a little doll dress body.
	local green = Color3.fromRGB(96, 200, 92)
	local dress = Color3.fromRGB(255, 120, 170)
	local parts: { Part } = { makeRoot(3.6) }
	table.insert(parts, makePart("Dress", Vector3.new(1.9, 1.6, 1.9), CFrame.new(0, 0.85, 0), dress, Enum.PartType.Cylinder))
	table.insert(parts, makePart("Torso", Vector3.new(1.25, 0.9, 1.25), CFrame.new(0, 1.95, 0), dress, Enum.PartType.Ball))
	table.insert(parts, makePart("Head", Vector3.new(1.8, 1.25, 1.6), CFrame.new(0, 3.0, 0), green, Enum.PartType.Ball))
	table.insert(parts, makePart("EyeBumpL", Vector3.new(0.55, 0.55, 0.55), CFrame.new(-0.5, 3.75, -0.25), green, Enum.PartType.Ball))
	table.insert(parts, makePart("EyeBumpR", Vector3.new(0.55, 0.55, 0.55), CFrame.new(0.5, 3.75, -0.25), green, Enum.PartType.Ball))
	joinInto(parts, eyePair(3.82, -0.55, 0.5, 0.3))
	table.insert(parts, makePart("Mouth", Vector3.new(0.8, 0.12, 0.1), CFrame.new(0, 2.75, -0.82), Color3.fromRGB(40, 80, 40)))
	table.insert(parts, makePart("ArmL", Vector3.new(0.35, 1.0, 0.35), CFrame.new(-0.95, 1.9, 0) * CFrame.Angles(0, 0, math.rad(28)), green, Enum.PartType.Ball))
	table.insert(parts, makePart("ArmR", Vector3.new(0.35, 1.0, 0.35), CFrame.new(0.95, 1.9, 0) * CFrame.Angles(0, 0, math.rad(-28)), green, Enum.PartType.Ball))
	table.insert(parts, makePart("ShoeL", Vector3.new(0.55, 0.25, 0.8), CFrame.new(-0.45, 0.13, -0.15), Color3.fromRGB(200, 40, 60)))
	table.insert(parts, makePart("ShoeR", Vector3.new(0.55, 0.25, 0.8), CFrame.new(0.45, 0.13, -0.15), Color3.fromRGB(200, 40, 60)))
	table.insert(parts, makePart("Bow", Vector3.new(0.7, 0.35, 0.25), CFrame.new(0.55, 3.85, 0.25), Color3.fromRGB(255, 220, 60), nil, Enum.Material.Neon))
	return finishModel("Boneca Ambalabu", parts)
end

local function buildLosTralaleritos(): Model
	-- Three small dark sharks side by side with a smoky aura disc.
	local shark = Color3.fromRGB(52, 62, 84)
	local belly = Color3.fromRGB(150, 160, 180)
	local parts: { Part } = { makeRoot(3.0) }
	table.insert(parts, makePart("Aura", Vector3.new(5.4, 0.18, 3.4), CFrame.new(0, 0.1, 0), Color3.fromRGB(30, 10, 16), Enum.PartType.Cylinder, Enum.Material.Neon))
	for i, ox in ipairs({ -1.7, 0, 1.7 }) do
		local lift = if i == 2 then 0.25 else 0
		table.insert(parts, makePart("Body", Vector3.new(1.15, 1.1, 2.1), CFrame.new(ox, 1.35 + lift, 0), shark, Enum.PartType.Ball))
		table.insert(parts, makePart("Belly", Vector3.new(0.95, 0.7, 1.6), CFrame.new(ox, 1.05 + lift, -0.1), belly, Enum.PartType.Ball))
		table.insert(parts, makePart("Dorsal", Vector3.new(0.18, 0.7, 0.6), CFrame.new(ox, 2.15 + lift, 0.35), shark))
		table.insert(parts, makePart("Tail", Vector3.new(0.16, 0.9, 0.55), CFrame.new(ox, 1.55 + lift, 1.25) * CFrame.Angles(math.rad(-24), 0, 0), shark))
		table.insert(parts, makePart("EyeGlowL", Vector3.new(0.2, 0.2, 0.1), CFrame.new(ox - 0.3, 1.6 + lift, -1.0), Color3.fromRGB(255, 60, 60), Enum.PartType.Ball, Enum.Material.Neon))
		table.insert(parts, makePart("EyeGlowR", Vector3.new(0.2, 0.2, 0.1), CFrame.new(ox + 0.3, 1.6 + lift, -1.0), Color3.fromRGB(255, 60, 60), Enum.PartType.Ball, Enum.Material.Neon))
	end
	return finishModel("Los Tralaleritos", parts)
end

local function buildGiraffa(): Model
	-- Tall glowing giraffe with a starry neck.
	local hide = Color3.fromRGB(255, 214, 120)
	local spot = Color3.fromRGB(190, 120, 50)
	local glow = Color3.fromRGB(170, 250, 255)
	local parts: { Part } = { makeRoot(5.0) }
	table.insert(parts, makePart("Body", Vector3.new(1.9, 1.5, 2.6), CFrame.new(0, 2.5, 0.2), hide, Enum.PartType.Ball))
	for _, leg in ipairs({ { -0.65, -0.7 }, { 0.65, -0.7 }, { -0.65, 1.0 }, { 0.65, 1.0 } }) do
		table.insert(parts, makePart("Leg", Vector3.new(0.42, 1.9, 0.42), CFrame.new(leg[1], 0.95, leg[2]), hide))
		table.insert(parts, makePart("Hoof", Vector3.new(0.5, 0.22, 0.5), CFrame.new(leg[1], 0.11, leg[2]), spot))
	end
	table.insert(parts, makePart("Neck", Vector3.new(0.75, 2.6, 0.75), CFrame.new(0, 4.15, -0.95) * CFrame.Angles(math.rad(18), 0, 0), hide, Enum.PartType.Ball))
	table.insert(parts, makePart("Spot1", Vector3.new(0.5, 0.5, 0.2), CFrame.new(0.3, 3.9, -1.45), spot, Enum.PartType.Ball))
	table.insert(parts, makePart("Spot2", Vector3.new(0.45, 0.45, 0.2), CFrame.new(-0.28, 4.6, -1.15), spot, Enum.PartType.Ball))
	table.insert(parts, makePart("Spot3", Vector3.new(0.6, 0.5, 0.2), CFrame.new(0.55, 2.6, -1.15), spot, Enum.PartType.Ball))
	table.insert(parts, makePart("Head", Vector3.new(1.0, 0.9, 1.35), CFrame.new(0, 5.35, -1.5), hide, Enum.PartType.Ball))
	table.insert(parts, makePart("OssiconeL", Vector3.new(0.2, 0.55, 0.2), CFrame.new(-0.3, 5.95, -1.35), spot))
	table.insert(parts, makePart("OssiconeR", Vector3.new(0.2, 0.55, 0.2), CFrame.new(0.3, 5.95, -1.35), spot))
	table.insert(parts, makePart("StarL", Vector3.new(0.34, 0.34, 0.34), CFrame.new(-0.3, 6.28, -1.35), glow, Enum.PartType.Ball, Enum.Material.Neon))
	table.insert(parts, makePart("StarR", Vector3.new(0.34, 0.34, 0.34), CFrame.new(0.3, 6.28, -1.35), glow, Enum.PartType.Ball, Enum.Material.Neon))
	joinInto(parts, eyePair(5.5, -2.12, 0.3, 0.24))
	table.insert(parts, makePart("Tail", Vector3.new(0.2, 1.1, 0.2), CFrame.new(0, 2.6, 1.6) * CFrame.Angles(math.rad(-16), 0, 0), spot))
	table.insert(parts, makePart("Aura", Vector3.new(3.6, 0.16, 3.6), CFrame.new(0, 0.08, 0.2), glow, Enum.PartType.Cylinder, Enum.Material.Neon))
	return finishModel("Giraffa Celeste", parts)
end

local function buildNoobrot(): Model
	-- Classic yellow noob with blocky limbs and sparkles.
	local yellow = Color3.fromRGB(245, 205, 40)
	local blue = Color3.fromRGB(40, 110, 220)
	local green = Color3.fromRGB(90, 190, 70)
	local parts: { Part } = { makeRoot(4.2) }
	table.insert(parts, makePart("Torso", Vector3.new(1.7, 1.6, 0.9), CFrame.new(0, 2.15, 0), blue))
	table.insert(parts, makePart("Head", Vector3.new(1.35, 1.1, 1.1), CFrame.new(0, 3.55, 0), yellow))
	table.insert(parts, makePart("ArmL", Vector3.new(0.55, 1.55, 0.55), CFrame.new(-1.15, 2.2, 0), yellow))
	table.insert(parts, makePart("ArmR", Vector3.new(0.55, 1.55, 0.55), CFrame.new(1.15, 2.2, 0), yellow))
	table.insert(parts, makePart("LegL", Vector3.new(0.7, 1.35, 0.7), CFrame.new(-0.42, 0.68, 0), green))
	table.insert(parts, makePart("LegR", Vector3.new(0.7, 1.35, 0.7), CFrame.new(0.42, 0.68, 0), green))
	joinInto(parts, eyePair(3.7, -0.56, 0.3, 0.22))
	table.insert(parts, makePart("Smile", Vector3.new(0.55, 0.1, 0.08), CFrame.new(0, 3.3, -0.56), Color3.fromRGB(30, 30, 30)))
	for i, off in ipairs({ { -1.3, 4.3, -0.4 }, { 1.25, 3.1, 0.5 }, { 0.2, 4.6, 0.45 }, { -0.9, 1.2, -0.7 } }) do
		table.insert(parts, makePart("Sparkle" .. i, Vector3.new(0.3, 0.3, 0.3), CFrame.new(off[1], off[2], off[3]), Color3.fromRGB(255, 245, 160), Enum.PartType.Ball, Enum.Material.Neon))
	end
	table.insert(parts, makePart("Aura", Vector3.new(3.4, 0.16, 3.4), CFrame.new(0, 0.08, 0), Color3.fromRGB(255, 235, 90), Enum.PartType.Cylinder, Enum.Material.Neon))
	return finishModel("Noobrot the OG", parts)
end

-- Cast -----------------------------------------------------------------------

local Cast: { BrainrotDef } = {
	{
		Id = "patapim", Name = "Brr Brr Patapim", Rarity = "Common",
		Price = 25, IncomePerSec = 1, SpawnWeight = 3000,
		AssetId = 121724230281477, AccentColor = Color3.fromRGB(110, 170, 80),
	},
	{
		Id = "gusini", Name = "Bombombini Gusini", Rarity = "Common",
		Price = 40, IncomePerSec = 2, SpawnWeight = 1800,
		AssetId = 0, AccentColor = Color3.fromRGB(235, 235, 230),
		BuildFallback = buildBombombini,
	},
	{
		Id = "lirili", Name = "Lirili Larila", Rarity = "Common",
		Price = 50, IncomePerSec = 2, SpawnWeight = 2400,
		AssetId = 77231614368559, AccentColor = Color3.fromRGB(130, 200, 110),
	},
	{
		Id = "trippi", Name = "Trippi Troppi", Rarity = "Uncommon",
		Price = 150, IncomePerSec = 5, SpawnWeight = 900,
		AssetId = 0, AccentColor = Color3.fromRGB(255, 170, 90),
		BuildFallback = buildTrippi,
	},
	{
		Id = "boneca", Name = "Boneca Ambalabu", Rarity = "Uncommon",
		Price = 300, IncomePerSec = 9, SpawnWeight = 700,
		AssetId = 0, AccentColor = Color3.fromRGB(120, 210, 100),
		BuildFallback = buildBoneca,
	},
	{
		Id = "tralalero", Name = "Tralalero Tralala", Rarity = "Rare",
		Price = 750, IncomePerSec = 16, SpawnWeight = 450,
		AssetId = 111854862176457, AccentColor = Color3.fromRGB(90, 160, 230),
	},
	{
		Id = "chimpanzini", Name = "Chimpanzini Bananini", Rarity = "Rare",
		Price = 1500, IncomePerSec = 30, SpawnWeight = 350,
		AssetId = 83732984780551, AccentColor = Color3.fromRGB(255, 220, 80),
		ScaleTo = 2,
	},
	{
		Id = "ballerina", Name = "Ballerina Cappuccina", Rarity = "Epic",
		Price = 4000, IncomePerSec = 70, SpawnWeight = 200,
		AssetId = 81269930750607, AccentColor = Color3.fromRGB(255, 190, 215),
	},
	{
		Id = "assassino", Name = "Cappuccino Assassino", Rarity = "Epic",
		Price = 7500, IncomePerSec = 130, SpawnWeight = 140,
		AssetId = 88011361629493, AccentColor = Color3.fromRGB(150, 105, 70),
	},
	{
		Id = "tungtung", Name = "Tung Tung Sahur", Rarity = "Legendary",
		Price = 15000, IncomePerSec = 280, SpawnWeight = 60,
		AssetId = 138151705692565, AccentColor = Color3.fromRGB(165, 115, 65),
	},
	{
		Id = "frigo", Name = "Frigo Camelo", Rarity = "Legendary",
		Price = 30000, IncomePerSec = 550, SpawnWeight = 40,
		AssetId = 136392638607318, AccentColor = Color3.fromRGB(200, 225, 235),
	},
	{
		Id = "crocodilo", Name = "Bombardiro Crocodilo", Rarity = "Mythic",
		Price = 75000, IncomePerSec = 1400, SpawnWeight = 15,
		AssetId = 111138597903728, AccentColor = Color3.fromRGB(105, 175, 95),
	},
	{
		Id = "vaca", Name = "La Vaca Saturno Saturnita", Rarity = "Mythic",
		Price = 150000, IncomePerSec = 2800, SpawnWeight = 9,
		AssetId = 76127116347738, AccentColor = Color3.fromRGB(200, 170, 255),
	},
	{
		Id = "tralaleritos", Name = "Los Tralaleritos", Rarity = "Secret",
		Price = 500000, IncomePerSec = 9000, SpawnWeight = 3,
		AssetId = 0, AccentColor = Color3.fromRGB(70, 80, 105),
		BuildFallback = buildLosTralaleritos,
	},
	{
		Id = "giraffa", Name = "Giraffa Celeste", Rarity = "Divine",
		Price = 2000000, IncomePerSec = 35000, SpawnWeight = 1.2,
		AssetId = 0, AccentColor = Color3.fromRGB(255, 214, 120),
		BuildFallback = buildGiraffa,
	},
	{
		Id = "noobrot", Name = "Noobrot the OG", Rarity = "OG",
		Price = 10000000, IncomePerSec = 150000, SpawnWeight = 0.6,
		AssetId = 0, AccentColor = Color3.fromRGB(245, 205, 40),
		BuildFallback = buildNoobrot,
	},
}

-- Lookups --------------------------------------------------------------------

local ById: { [string]: BrainrotDef } = {}
for _, def in ipairs(Cast) do
	ById[def.Id] = def
end

local RankByRarity: { [string]: number } = {}
for i, rarity in ipairs(Config.RarityOrder) do
	RankByRarity[rarity] = i
end

local function RarityRank(rarityName: string): number
	return RankByRarity[rarityName] or 0
end

local totalWeight = 0
for _, def in ipairs(Cast) do
	totalWeight += def.SpawnWeight
end

local function pickWeighted(rng: Random, pool: { BrainrotDef }): BrainrotDef
	local sum = 0
	for _, def in ipairs(pool) do
		sum += def.SpawnWeight
	end
	local roll = rng:NextNumber(0, sum)
	local acc = 0
	for _, def in ipairs(pool) do
		acc += def.SpawnWeight
		if roll <= acc then
			return def
		end
	end
	return pool[#pool]
end

local commons: { BrainrotDef } = {}
for _, def in ipairs(Cast) do
	if def.Rarity == "Common" then
		table.insert(commons, def)
	end
end

-- Roll: weighted pick. doubleRoll takes the rarer of two independent rolls;
-- forceCommon restricts the pool to Common entries only.
local function Roll(rng: Random, doubleRoll: boolean?, forceCommon: boolean?): BrainrotDef
	local pool = if forceCommon then commons else Cast
	local first = pickWeighted(rng, pool)
	if not doubleRoll then
		return first
	end
	local second = pickWeighted(rng, pool)
	if RarityRank(second.Rarity) > RarityRank(first.Rarity) then
		return second
	end
	return first
end

return {
	Cast = Cast,
	ById = ById,
	RarityRank = RarityRank,
	TotalWeight = totalWeight,
	Roll = Roll,
}
