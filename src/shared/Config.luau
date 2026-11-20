-- Config.luau
-- Central tuning table for SAHUR ZOO.
-- Every other module reads positions, prices and timers from here so the
-- whole game can be rebalanced by editing this one file.

local Config = {}

-- Economy / player -----------------------------------------------------------

Config.StartCash = 100

Config.WalkSpeeds = {
	Base = 16,
	Carry = 11,
	-- Speed upgrade bonuses are added on top of Base / Carry.
	-- Index = SpeedLevel (0..3). Level 0 means no bonus.
	BonusByLevel = { 0, 2, 4, 6 },
}

Config.SpeedUpgrades = {
	-- Costs for levels 1, 2, 3.
	Costs = { 500, 2500, 10000 },
	BonusPerLevel = 2,
	MaxLevel = 3,
}

Config.SlapUpgrades = {
	-- Costs for levels 1, 2, 3, 4.
	Costs = { 250, 1000, 4000, 15000 },
	MaxLevel = 4,
	-- Knockback power (studs of impulse) per slap level 0..4.
	PowerByLevel = { 18, 30, 46, 66, 92 },
	-- Vertical lift component per level.
	UpByLevel = { 6, 9, 13, 18, 24 },
	Cooldown = 0.45,
	Range = 9,
}

Config.SellFraction = 0.5

-- Rebirth --------------------------------------------------------------------

Config.Rebirth = {
	BaseCost = 25000,
	CostGrowth = 3, -- cost = BaseCost * CostGrowth ^ rebirthsSoFar
	BonusPerRebirth = 0.5, -- multiplier = 1 + BonusPerRebirth * rebirths
}

-- Belt (the Parade Path) -----------------------------------------------------

Config.Belt = {
	SpawnInterval = 2.2,
	WalkSpeed = 7,
	AliveCap = 14,
	StartX = -194,
	EndX = 194,
	TopY = 2, -- BELT_TOP: surface height of the Parade Path
	HalfWidth = 7,
	Width = 14,
}

-- Short alias used by several modules.
Config.BELT_TOP = 2

-- Enclosures -----------------------------------------------------------------

Config.Enclosures = {
	Count = 12,
	PerSide = 6,
	RowZ = { -46, 46 },
	ColumnX = { -150, -90, -30, 30, 90, 150 },
	PlatformWidth = 45, -- x extent
	PlatformDepth = 34, -- z extent
	PlatformTopY = 2,
	PlatformThickness = 2,
	PenCols = 6,
	PenRows = 4,
	PensPerBase = 24,
	PenSpacingX = 6.6,
	PenSpacingZ = 6.8,
	PenDiscRadius = 2.9,
}

-- Capacity ladder: BaseCapacityLevel 0..4 -> pens unlocked.
Config.Capacity = {
	PensByLevel = { 8, 12, 16, 20, 24 },
	-- Cost to go from level n to n+1, indexed by current level + 1.
	UpgradeCosts = { 5000, 25000, 100000, 400000 },
	MaxLevel = 4,
}

-- Lock -----------------------------------------------------------------------

Config.Lock = {
	Duration = 60,
	Cooldown = 20,
}

-- Rarities -------------------------------------------------------------------
-- Order matters: index in this list is the rank.

Config.RarityOrder = {
	"Common",
	"Uncommon",
	"Rare",
	"Epic",
	"Legendary",
	"Mythic",
	"Secret",
	"Divine",
	"OG",
}

Config.RarityColors = {
	Common = Color3.fromRGB(196, 200, 204),
	Uncommon = Color3.fromRGB(84, 200, 96),
	Rare = Color3.fromRGB(64, 140, 255),
	Epic = Color3.fromRGB(168, 92, 246),
	Legendary = Color3.fromRGB(255, 196, 32),
	Mythic = Color3.fromRGB(255, 64, 110),
	Secret = Color3.fromRGB(52, 18, 22),
	Divine = Color3.fromRGB(196, 250, 255),
	OG = Color3.fromRGB(255, 235, 59),
}

Config.RarityTextColors = {
	Common = Color3.fromRGB(40, 42, 46),
	Uncommon = Color3.fromRGB(18, 60, 24),
	Rare = Color3.fromRGB(255, 255, 255),
	Epic = Color3.fromRGB(255, 255, 255),
	Legendary = Color3.fromRGB(60, 42, 0),
	Mythic = Color3.fromRGB(255, 255, 255),
	Secret = Color3.fromRGB(255, 120, 120),
	Divine = Color3.fromRGB(20, 60, 70),
	OG = Color3.fromRGB(60, 50, 0),
}

-- Layout ---------------------------------------------------------------------
-- Single source of truth for world positions.

Config.Layout = {
	BaseplateSize = 440,
	BaseplateTopY = 0,
	GrassColor = Color3.fromRGB(96, 168, 72),

	PathStartX = -194,
	PathEndX = 194,
	PathWidth = 14,
	PathTopY = 2,
	PathThickness = 2,

	PlazaDepth = 22, -- gap between path edge and enclosure front

	CaveX = { -194, 194 },
	CaveMouthWidth = 13,

	SpawnOffsetFromArrivals = Vector3.new(14, 0, 18),

	SignSize = Vector3.new(18, 5, 0.6),

	StandRadius = 2.2,
	StandHeight = 0.6,
	-- Order along the front walkway, left to right when facing the base.
	StandOrder = { "Lock", "Rebirth", "Slap", "Speed", "Capacity" },
	StandColors = {
		Lock = Color3.fromRGB(0, 220, 235),
		Rebirth = Color3.fromRGB(235, 0, 200),
		Slap = Color3.fromRGB(255, 130, 30),
		Speed = Color3.fromRGB(60, 220, 90),
		Capacity = Color3.fromRGB(255, 215, 40),
	},
	StandLabels = {
		Lock = "LOCK",
		Rebirth = "REBIRTH",
		Slap = "SLAP+",
		Speed = "SPEED+",
		Capacity = "PEN+",
	},
}

-- Income tick ----------------------------------------------------------------

Config.IncomeTickSeconds = 1

-- Flat aliases -----------------------------------------------------------------
-- Several modules read single values with a flat cfg("Key", fallback)
-- lookup. These aliases mirror the nested tables above so both styles
-- always agree. Keep them in sync when retuning.

Config.BeltTopY = Config.Belt.TopY
Config.BeltStartX = Config.Belt.StartX
Config.BeltEndX = Config.Belt.EndX
Config.BeltSpeed = Config.Belt.WalkSpeed
Config.BeltCap = Config.Belt.AliveCap
Config.SpawnInterval = Config.Belt.SpawnInterval
Config.BaseWalkSpeed = Config.WalkSpeeds.Base
Config.WalkSpeed = Config.WalkSpeeds.Base
Config.CarrySpeed = Config.WalkSpeeds.Carry
Config.ReturnSpeed = 13
Config.CapacityCosts = Config.Capacity.UpgradeCosts
Config.SlapCosts = Config.SlapUpgrades.Costs
Config.SpeedCosts = Config.SpeedUpgrades.Costs
Config.LockDuration = Config.Lock.Duration
Config.LockCooldown = Config.Lock.Cooldown
Config.PadsPerBase = Config.Enclosures.PensPerBase

-- Helpers --------------------------------------------------------------------

function Config.CapacityForLevel(level: number): number
	local pens = Config.Capacity.PensByLevel
	local idx = math.clamp(math.floor(level) + 1, 1, #pens)
	return pens[idx]
end

function Config.RebirthCost(rebirthsSoFar: number): number
	return Config.Rebirth.BaseCost * (Config.Rebirth.CostGrowth ^ math.max(0, math.floor(rebirthsSoFar)))
end

function Config.MultiplierForRebirths(rebirths: number): number
	return 1 + Config.Rebirth.BonusPerRebirth * math.max(0, rebirths)
end

function Config.WalkSpeedFor(data: any, carrying: boolean): number
	local bonus = 0
	if data and typeof(data.SpeedLevel) == "number" then
		local lvl = math.clamp(math.floor(data.SpeedLevel), 0, Config.SpeedUpgrades.MaxLevel)
		bonus = lvl * Config.SpeedUpgrades.BonusPerLevel
	end
	if carrying then
		return Config.WalkSpeeds.Carry + bonus
	end
	return Config.WalkSpeeds.Base + bonus
end

function Config.SlapPowerFor(level: number): (number, number)
	local lvl = math.clamp(math.floor(level), 0, Config.SlapUpgrades.MaxLevel)
	return Config.SlapUpgrades.PowerByLevel[lvl + 1], Config.SlapUpgrades.UpByLevel[lvl + 1]
end

-- Base layout helper: returns the centre Vector3 for base index 1..12.
-- Bases 1..6 sit on the north row (z = -46), 7..12 on the south row.
function Config.BaseCenter(index: number): Vector3
	local perSide = Config.Enclosures.PerSide
	local col = ((index - 1) % perSide) + 1
	local row = if index <= perSide then 1 else 2
	local x = Config.Enclosures.ColumnX[col]
	local z = Config.Enclosures.RowZ[row]
	return Vector3.new(x, Config.Enclosures.PlatformTopY, z)
end

-- Facing: north-row bases face south (+z toward the path), south-row bases
-- face north (-z). Returns the outward direction toward the Parade Path.
function Config.BaseFacingSign(index: number): number
	return if index <= Config.Enclosures.PerSide then 1 else -1
end

return Config
