-- WorldBuilder.luau
-- Builds the whole SAHUR ZOO procedurally from parts: baseplate, Parade
-- Path, two sand caves, plaza, and twelve fenced enclosures. The build
-- path uses ZERO InsertService calls so the world always exists even if
-- every external asset fails; DressUp adds optional decoration later.

local Workspace = game:GetService("Workspace")

local Config = require(game.ReplicatedStorage.Shared.Config)
local AssetLibrary = require(script.Parent.AssetLibrary)

local WorldBuilder = {}

-- Part helper ----------------------------------------------------------------

type PartSpec = {
	Name: string?,
	Size: Vector3,
	CFrame: CFrame,
	Color: Color3?,
	Material: Enum.Material?,
	Shape: Enum.PartType?,
	Transparency: number?,
	CanCollide: boolean?,
	CanQuery: boolean?,
	Anchored: boolean?,
}

local function part(parent: Instance, spec: PartSpec): Part
	local p = Instance.new("Part")
	p.Name = spec.Name or "Part"
	p.Size = spec.Size
	p.CFrame = spec.CFrame
	if spec.Color then
		p.Color = spec.Color
	end
	if spec.Material then
		p.Material = spec.Material
	end
	if spec.Shape then
		p.Shape = spec.Shape
	end
	p.Transparency = spec.Transparency or 0
	p.Anchored = if spec.Anchored ~= nil then spec.Anchored else true
	p.CanCollide = if spec.CanCollide ~= nil then spec.CanCollide else true
	-- Decor is non-queryable by default; standing surfaces opt back in.
	p.CanQuery = if spec.CanQuery ~= nil then spec.CanQuery else false
	p.CanTouch = false
	p.Parent = parent
	return p
end

local WOOD = Color3.fromRGB(146, 104, 62)
local WOOD_DARK = Color3.fromRGB(96, 64, 38)
local WOOD_LIGHT = Color3.fromRGB(186, 148, 96)
local SAND = Color3.fromRGB(216, 188, 128)
local SAND_DARK = Color3.fromRGB(186, 156, 96)
local DIRT = Color3.fromRGB(128, 92, 58)
local STRAW = Color3.fromRGB(226, 198, 110)
local GRASS = Color3.fromRGB(96, 168, 72)
local GRASS_DARK = Color3.fromRGB(78, 142, 58)

-- Caves ----------------------------------------------------------------------

local function buildCave(parent: Folder, caveX: number, isArrivals: boolean, beltTop: number): Folder
	local cave = Instance.new("Folder")
	cave.Name = if isArrivals then "CaveArrivals" else "CaveExit"
	cave.Parent = parent

	-- Direction the cave faces: the west cave opens toward +x, east toward -x.
	local inward = if caveX < 0 then 1 else -1
	local mouthX = caveX + inward * 2

	-- Interior: an opaque near-black box players can see into but which
	-- swallows the path endpoints so characters appear / vanish in dark.
	local interior = part(cave, {
		Name = "Interior",
		Size = Vector3.new(16, 11, 18),
		CFrame = CFrame.new(caveX - inward * 3, beltTop + 3.5, 0),
		Color = Color3.fromRGB(8, 7, 6),
		Material = Enum.Material.Slate,
		CanCollide = false,
		CanQuery = false,
	})
	interior.Transparency = 0

	-- Floor extension at belt height: the ONLY raycast-queryable cave part,
	-- so GroundYAt keeps working right up to the spawn / despawn points.
	part(cave, {
		Name = "CaveFloor",
		Size = Vector3.new(18, 2, 14),
		CFrame = CFrame.new(caveX - inward * 2, beltTop - 1, 0),
		Color = WOOD,
		Material = Enum.Material.WoodPlanks,
		CanCollide = true,
		CanQuery = true,
	})

	-- Sandstone pillars leaning in on both sides of the mouth.
	for _, side in ipairs({ -1, 1 }) do
		local pillarZ = side * 7.5
		part(cave, {
			Name = "Pillar",
			Size = Vector3.new(3.4, 10, 3.4),
			CFrame = CFrame.new(mouthX, beltTop + 4, pillarZ) * CFrame.Angles(side * math.rad(5), 0, inward * math.rad(-6)),
			Color = SAND,
			Material = Enum.Material.Rock,
			CanCollide = false,
			CanQuery = false,
		})
		part(cave, {
			Name = "PillarBase",
			Size = Vector3.new(4.6, 2.2, 4.6),
			CFrame = CFrame.new(mouthX, beltTop + 0.4, pillarZ),
			Color = SAND_DARK,
			Material = Enum.Material.Rock,
			CanCollide = false,
			CanQuery = false,
		})
	end

	-- Three stepped rock slabs doming over the 13-wide mouth.
	local slabSpecs = {
		{ y = 9.2, w = 20, inset = 0 },
		{ y = 11.0, w = 16, inset = 1.6 },
		{ y = 12.6, w = 11, inset = 3.2 },
	}
	for i, s in ipairs(slabSpecs) do
		part(cave, {
			Name = "DomeSlab" .. i,
			Size = Vector3.new(6.5, 1.8, s.w),
			CFrame = CFrame.new(mouthX - inward * s.inset * 0.4, beltTop + s.y - 2, 0),
			Color = if i == 2 then SAND_DARK else SAND,
			Material = Enum.Material.Rock,
			CanCollide = false,
			CanQuery = false,
		})
	end

	-- Loose boulders scattered around the entrance.
	local boulders = {
		{ 4.5, 10.5, 1.6 }, { -3.5, 11, 1.1 }, { 6, -10, 1.3 }, { -5, -11.5, 1.9 }, { 1, 12.5, 0.9 },
	}
	for i, b in ipairs(boulders) do
		part(cave, {
			Name = "Boulder" .. i,
			Size = Vector3.new(b[3], b[3] * 0.8, b[3]),
			CFrame = CFrame.new(mouthX + inward * b[1], beltTop + b[3] * 0.3, b[2]),
			Color = SAND_DARK,
			Material = Enum.Material.Rock,
			Shape = Enum.PartType.Ball,
			CanCollide = false,
			CanQuery = false,
		})
	end

	if isArrivals then
		-- Cream arrivals board above the mouth.
		local board = part(cave, {
			Name = "ArrivalsBoard",
			Size = Vector3.new(0.5, 2.6, 12),
			CFrame = CFrame.new(mouthX + inward * 1.8, beltTop + 7.2, 0),
			Color = Color3.fromRGB(250, 240, 205),
			Material = Enum.Material.Wood,
			CanCollide = false,
			CanQuery = false,
		})
		local gui = Instance.new("SurfaceGui")
		gui.Name = "BoardGui"
		gui.Face = if inward > 0 then Enum.NormalId.Right else Enum.NormalId.Left
		gui.Parent = board
		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, 0, 1, 0)
		label.BackgroundTransparency = 1
		label.Text = "ANIMAL ARRIVALS"
		label.TextColor3 = Color3.fromRGB(70, 48, 22)
		label.Font = Enum.Font.GothamBold
		label.TextScaled = true
		label.Parent = gui
	end

	return cave
end

-- Enclosure ------------------------------------------------------------------

local function buildSign(parent: Folder, center: Vector3, facingSign: number, index: number): (Part, SurfaceGui)
	local frontZ = center.Z + facingSign * (Config.Enclosures.PlatformDepth / 2 + 1.2)
	local sign = part(parent, {
		Name = "SignBoard",
		Size = Config.Layout.SignSize,
		CFrame = CFrame.new(center.X, Config.Enclosures.PlatformTopY + 3.2, frontZ)
			* CFrame.Angles(0, if facingSign > 0 then math.pi else 0, 0),
		Color = WOOD_DARK,
		Material = Enum.Material.Wood,
		CanCollide = false,
		CanQuery = false,
	})
	-- Two stubby legs so the board reads as a planted sign, not a floater.
	for _, sx in ipairs({ -7, 7 }) do
		part(parent, {
			Name = "SignLeg",
			Size = Vector3.new(0.7, 3.4, 0.7),
			CFrame = CFrame.new(center.X + sx, Config.Enclosures.PlatformTopY + 1.2, frontZ),
			Color = WOOD_DARK,
			Material = Enum.Material.Wood,
			CanCollide = false,
			CanQuery = false,
		})
	end
	-- Owner-coloured roof strip along the top of the board.
	local strip = part(parent, {
		Name = "SignRoofStrip",
		Size = Vector3.new(Config.Layout.SignSize.X + 0.8, 0.55, 1.1),
		CFrame = CFrame.new(center.X, Config.Enclosures.PlatformTopY + 3.2 + Config.Layout.SignSize.Y / 2 + 0.25, frontZ),
		Color = Color3.fromRGB(170, 170, 170),
		Material = Enum.Material.Wood,
		CanCollide = false,
		CanQuery = false,
	})
	strip:SetAttribute("Role", "OwnerColorStrip")

	local gui = Instance.new("SurfaceGui")
	gui.Name = "SignGui"
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(900, 250)
	gui.Parent = sign

	local function makeLabel(name: string, posY: number, sizeY: number, text: string, scale: number): TextLabel
		local label = Instance.new("TextLabel")
		label.Name = name
		label.Position = UDim2.new(0, 0, posY, 0)
		label.Size = UDim2.new(1, 0, sizeY, 0)
		label.BackgroundTransparency = 1
		label.Text = text
		label.TextColor3 = Color3.fromRGB(255, 244, 214)
		label.Font = Enum.Font.GothamBold
		label.TextScaled = true
		label.TextXAlignment = Enum.TextXAlignment.Center
		label.Parent = gui
		return label
	end

	makeLabel("TitleLabel", 0.02, 0.3, string.format("PEN %d", index), 1)
	makeLabel("OwnerLabel", 0.32, 0.24, "Unclaimed", 1)
	makeLabel("StatsLabel", 0.56, 0.22, "$0  •  0/8 pens", 1)
	local status = makeLabel("StatusLabel", 0.78, 0.2, "OPEN", 1)
	status.TextColor3 = Color3.fromRGB(120, 255, 140)

	return sign, gui
end

local function buildFence(parent: Folder, center: Vector3, facingSign: number)
	local halfW = Config.Enclosures.PlatformWidth / 2
	local halfD = Config.Enclosures.PlatformDepth / 2
	local topY = Config.Enclosures.PlatformTopY
	local fence = Instance.new("Folder")
	fence.Name = "Fence"
	fence.Parent = parent

	local function railRun(fromPos: Vector3, toPos: Vector3)
		local mid = (fromPos + toPos) / 2
		local length = (toPos - fromPos).Magnitude
		local alongX = math.abs(toPos.X - fromPos.X) > math.abs(toPos.Z - fromPos.Z)
		-- Posts every ~7.5 studs.
		local steps = math.max(2, math.floor(length / 7.5))
		for i = 0, steps do
			local t = i / steps
			local pos = fromPos:Lerp(toPos, t)
			part(fence, {
				Name = "FencePost",
				Size = Vector3.new(0.65, 2.6, 0.65),
				CFrame = CFrame.new(pos.X, topY + 1.3, pos.Z),
				Color = WOOD,
				Material = Enum.Material.Wood,
				CanCollide = true,
				CanQuery = false,
			})
		end
		for _, h in ipairs({ 0.9, 1.9 }) do
			part(fence, {
				Name = "FenceRail",
				Size = if alongX then Vector3.new(length, 0.35, 0.3) else Vector3.new(0.3, 0.35, length),
				CFrame = CFrame.new(mid.X, topY + h, mid.Z),
				Color = WOOD_LIGHT,
				Material = Enum.Material.Wood,
				CanCollide = true,
				CanQuery = false,
			})
		end
	end

	local backZ = center.Z - facingSign * halfD
	local frontZ = center.Z + facingSign * halfD
	local leftX = center.X - halfW
	local rightX = center.X + halfW

	-- Back run (full width) and both side runs (full depth).
	railRun(Vector3.new(leftX, topY, backZ), Vector3.new(rightX, topY, backZ))
	railRun(Vector3.new(leftX, topY, backZ), Vector3.new(leftX, topY, frontZ))
	railRun(Vector3.new(rightX, topY, backZ), Vector3.new(rightX, topY, frontZ))

	-- Front: no fence, just a gate frame (two posts + a beam).
	for _, sx in ipairs({ -3.4, 3.4 }) do
		part(fence, {
			Name = "GatePost",
			Size = Vector3.new(0.85, 3.6, 0.85),
			CFrame = CFrame.new(center.X + sx, topY + 1.8, frontZ),
			Color = WOOD_DARK,
			Material = Enum.Material.Wood,
			CanCollide = true,
			CanQuery = false,
		})
	end
	part(fence, {
		Name = "GateBeam",
		Size = Vector3.new(7.6, 0.6, 0.7),
		CFrame = CFrame.new(center.X, topY + 3.7, frontZ),
		Color = WOOD_DARK,
		Material = Enum.Material.Wood,
		CanCollide = false,
		CanQuery = false,
	})
end

-- Build ----------------------------------------------------------------------

function WorldBuilder.Build()
	local existing = Workspace:FindFirstChild("ZooWorld")
	if existing then
		existing:Destroy()
	end
	local worldFolder = Instance.new("Folder")
	worldFolder.Name = "ZooWorld"
	worldFolder.Parent = Workspace

	local beltTop = Config.Belt.TopY
	local topY = Config.Enclosures.PlatformTopY

	-- Safety baseplate + outer grass ring.
	part(worldFolder, {
		Name = "Baseplate",
		Size = Vector3.new(Config.Layout.BaseplateSize, 2, Config.Layout.BaseplateSize),
		CFrame = CFrame.new(0, Config.Layout.BaseplateTopY - 1, 0),
		Color = GRASS,
		Material = Enum.Material.Grass,
		CanCollide = true,
		CanQuery = true,
	})
	part(worldFolder, {
		Name = "OuterGrassRing",
		Size = Vector3.new(Config.Layout.BaseplateSize + 60, 1.6, Config.Layout.BaseplateSize + 60),
		CFrame = CFrame.new(0, Config.Layout.BaseplateTopY - 1.05, 0),
		Color = GRASS_DARK,
		Material = Enum.Material.Grass,
		CanCollide = true,
		CanQuery = true,
	})

	-- The Parade Path.
	part(worldFolder, {
		Name = "ParadePath",
		Size = Vector3.new(Config.Belt.EndX - Config.Belt.StartX, Config.Layout.PathThickness, Config.Layout.PathWidth),
		CFrame = CFrame.new(0, beltTop - Config.Layout.PathThickness / 2, 0),
		Color = WOOD,
		Material = Enum.Material.WoodPlanks,
		CanCollide = true,
		CanQuery = true,
	})
	-- Lighter plank stripes across the path.
	for x = -189, 189, 9 do
		part(worldFolder, {
			Name = "PathStripe",
			Size = Vector3.new(1.1, 0.12, Config.Layout.PathWidth - 0.6),
			CFrame = CFrame.new(x, beltTop + 0.05, 0),
			Color = WOOD_LIGHT,
			Material = Enum.Material.WoodPlanks,
			CanCollide = false,
			CanQuery = false,
		})
	end
	-- Wood rails + fence posts along both path edges.
	for _, side in ipairs({ -1, 1 }) do
		local edgeZ = side * (Config.Layout.PathWidth / 2 + 0.4)
		part(worldFolder, {
			Name = "PathRail",
			Size = Vector3.new(Config.Belt.EndX - Config.Belt.StartX, 0.4, 0.35),
			CFrame = CFrame.new(0, beltTop + 1.05, edgeZ),
			Color = WOOD_DARK,
			Material = Enum.Material.Wood,
			CanCollide = true,
			CanQuery = false,
		})
		for x = -192, 192, 12 do
			part(worldFolder, {
				Name = "PathPost",
				Size = Vector3.new(0.6, 1.5, 0.6),
				CFrame = CFrame.new(x, beltTop + 0.6, edgeZ),
				Color = WOOD_DARK,
				Material = Enum.Material.Wood,
				CanCollide = true,
				CanQuery = false,
			})
		end
	end

	-- Caves at both ends.
	buildCave(worldFolder, Config.Belt.StartX, true, beltTop)
	buildCave(worldFolder, Config.Belt.EndX, false, beltTop)

	-- Plaza: wood planks between the path and each row of enclosures.
	for _, rowSign in ipairs({ -1, 1 }) do
		local plazaCenterZ = rowSign * (Config.Layout.PathWidth / 2 + Config.Layout.PlazaDepth / 2)
		part(worldFolder, {
			Name = "Plaza",
			Size = Vector3.new(400, 2, Config.Layout.PlazaDepth),
			CFrame = CFrame.new(0, topY - 1, plazaCenterZ),
			Color = WOOD_LIGHT,
			Material = Enum.Material.WoodPlanks,
			CanCollide = true,
			CanQuery = true,
		})
	end

	-- Spawn point on the plaza near the arrivals cave.
	local spawnPos = Vector3.new(
		Config.Belt.StartX + 22,
		topY,
		-(Config.Layout.PathWidth / 2 + 6)
	)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "ZooSpawn"
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.CFrame = CFrame.new(spawnPos.X, topY + 0.5, spawnPos.Z)
	spawn.Color = Color3.fromRGB(235, 225, 195)
	spawn.Material = Enum.Material.WoodPlanks
	spawn.Anchored = true
	spawn.CanCollide = true
	spawn.CanQuery = true
	spawn.Neutral = true
	spawn.Parent = worldFolder

	-- Lamp posts along the path (procedural; DressUp may add fancier ones).
	for x = -180, 180, 36 do
		for _, side in ipairs({ -1, 1 }) do
			local lampZ = side * (Config.Layout.PathWidth / 2 + 2.2)
			part(worldFolder, {
				Name = "LampPost",
				Size = Vector3.new(0.45, 5.2, 0.45),
				CFrame = CFrame.new(x, beltTop + 2.6, lampZ),
				Color = WOOD_DARK,
				Material = Enum.Material.Wood,
				CanCollide = false,
				CanQuery = false,
			})
			local bulb = part(worldFolder, {
				Name = "LampBulb",
				Size = Vector3.new(0.9, 0.9, 0.9),
				CFrame = CFrame.new(x, beltTop + 5.4, lampZ),
				Color = Color3.fromRGB(255, 226, 150),
				Material = Enum.Material.Neon,
				Shape = Enum.PartType.Ball,
				CanCollide = false,
				CanQuery = false,
			})
			local light = Instance.new("PointLight")
			light.Color = Color3.fromRGB(255, 220, 160)
			light.Range = 18
			light.Brightness = 1.2
			light.Parent = bulb
		end
	end

	-- Big SAHUR ZOO arch over the plaza near spawn.
	local archFolder = Instance.new("Folder")
	archFolder.Name = "EntranceArch"
	archFolder.Parent = worldFolder
	for _, sx in ipairs({ -8, 8 }) do
		part(archFolder, {
			Name = "ArchPost",
			Size = Vector3.new(1.1, 9, 1.1),
			CFrame = CFrame.new(spawnPos.X + sx, topY + 4.5, spawnPos.Z - 6),
			Color = WOOD_DARK,
			Material = Enum.Material.Wood,
			CanCollide = false,
			CanQuery = false,
		})
	end
	local archBoard = part(archFolder, {
		Name = "ArchBoard",
		Size = Vector3.new(19, 3.2, 0.7),
		CFrame = CFrame.new(spawnPos.X, topY + 9.2, spawnPos.Z - 6),
		Color = WOOD_DARK,
		Material = Enum.Material.Wood,
		CanCollide = false,
		CanQuery = false,
	})
	local archGui = Instance.new("SurfaceGui")
	archGui.Face = Enum.NormalId.Front
	archGui.Parent = archBoard
	local archLabel = Instance.new("TextLabel")
	archLabel.Size = UDim2.new(1, 0, 1, 0)
	archLabel.BackgroundTransparency = 1
	archLabel.Text = "SAHUR ZOO"
	archLabel.TextColor3 = Color3.fromRGB(255, 226, 140)
	archLabel.Font = Enum.Font.GothamBold
	archLabel.TextScaled = true
	archLabel.Parent = archGui
	-- Back face copy so the arch reads from both sides.
	local archGuiBack = Instance.new("SurfaceGui")
	archGuiBack.Face = Enum.NormalId.Back
	archGuiBack.Parent = archBoard
	local archLabelBack = archLabel:Clone()
	archLabelBack.Parent = archGuiBack

	-- Enclosures.
	local bases = {}

	for index = 1, Config.Enclosures.Count do
		local center = Config.BaseCenter(index)
		local facingSign = Config.BaseFacingSign(index) -- toward the path
		-- NOTE: BaseCenter's z already sits on its row; the front of the
		-- enclosure is the side nearest z = 0 (the path).
		local frontSign = if center.Z < 0 then 1 else -1

		local baseFolder = Instance.new("Folder")
		baseFolder.Name = string.format("Base%02d", index)
		baseFolder.Parent = worldFolder

		-- Platform with a dirt top surface.
		part(baseFolder, {
			Name = "Platform",
			Size = Vector3.new(Config.Enclosures.PlatformWidth, Config.Enclosures.PlatformThickness, Config.Enclosures.PlatformDepth),
			CFrame = CFrame.new(center.X, topY - Config.Enclosures.PlatformThickness / 2, center.Z),
			Color = DIRT,
			Material = Enum.Material.Ground,
			CanCollide = true,
			CanQuery = true,
		})
		part(baseFolder, {
			Name = "DirtTop",
			Size = Vector3.new(Config.Enclosures.PlatformWidth - 1, 0.18, Config.Enclosures.PlatformDepth - 1),
			CFrame = CFrame.new(center.X, topY + 0.05, center.Z),
			Color = Color3.fromRGB(142, 104, 66),
			Material = Enum.Material.Ground,
			CanCollide = false,
			CanQuery = true,
		})

		-- Pen discs in a 6 x 4 grid.
		local padPositions: { Vector3 } = {}
		local startX = center.X - ((Config.Enclosures.PenCols - 1) * Config.Enclosures.PenSpacingX) / 2
		local startZ = center.Z - ((Config.Enclosures.PenRows - 1) * Config.Enclosures.PenSpacingZ) / 2
		for row = 1, Config.Enclosures.PenRows do
			for col = 1, Config.Enclosures.PenCols do
				local px = startX + (col - 1) * Config.Enclosures.PenSpacingX
				local pz = startZ + (row - 1) * Config.Enclosures.PenSpacingZ
				-- Cylinder parts lie on their side by default; the 90-degree
				-- roll in the CFrame stands the disc flat like a straw mat.
				part(baseFolder, {
					Name = string.format("Pen_%d_%d", row, col),
					Size = Vector3.new(Config.Enclosures.PenDiscRadius * 2, 0.22, Config.Enclosures.PenDiscRadius * 2),
					CFrame = CFrame.new(px, topY + 0.16, pz) * CFrame.Angles(0, 0, math.rad(90)),
					Color = STRAW,
					Material = Enum.Material.Grass,
					Shape = Enum.PartType.Cylinder,
					CanCollide = false,
					CanQuery = true,
				})
				table.insert(padPositions, Vector3.new(px, topY + 0.28, pz))
			end
		end

		local signBoard, signGui = buildSign(baseFolder, center, frontSign, index)
		buildFence(baseFolder, center, frontSign)

		-- Transparent lock wall across the front gate.
		local frontZ = center.Z + frontSign * (Config.Enclosures.PlatformDepth / 2)
		local lockWall = part(baseFolder, {
			Name = "LockWall",
			Size = Vector3.new(7, 4.5, 0.5),
			CFrame = CFrame.new(center.X, topY + 2.25, frontZ),
			Color = Color3.fromRGB(120, 230, 245),
			Material = Enum.Material.ForceField,
			Transparency = 1,
			CanCollide = false,
			CanQuery = false,
		})

		-- Five upgrade stands on the walkway in front of the enclosure.
		local stands: { [string]: Part } = {}
		local standZ = frontZ + frontSign * 3.2
		local standStartX = center.X - 12
		for i, key in ipairs(Config.Layout.StandOrder) do
			local sx = standStartX + (i - 1) * 6
			local stand = part(baseFolder, {
				Name = key .. "Stand",
				Size = Vector3.new(Config.Layout.StandRadius * 2, Config.Layout.StandHeight, Config.Layout.StandRadius * 2),
				CFrame = CFrame.new(sx, topY + Config.Layout.StandHeight / 2, standZ) * CFrame.Angles(0, 0, math.rad(90)),
				Color = Config.Layout.StandColors[key],
				Material = Enum.Material.Neon,
				Shape = Enum.PartType.Cylinder,
				CanCollide = false,
				CanQuery = false,
			})
			stand:SetAttribute("StandKind", key)
			stands[key] = stand
		end

		local frontCenter = Vector3.new(center.X, topY, frontZ + frontSign * 4.5)

		table.insert(bases, {
			Index = index,
			Center = center,
			PadPositions = padPositions,
			SignBoard = signBoard,
			SignGui = signGui,
			LockWall = lockWall,
			Stands = stands,
			FrontCenter = frontCenter,
			Folder = baseFolder,
			FacingSign = frontSign,
		})
		-- facingSign from Config kept for callers that prefer it.
		bases[#bases].ConfigFacingSign = facingSign
	end

	local brainrots = Workspace:FindFirstChild("Brainrots")
	if not brainrots then
		local folder = Instance.new("Folder")
		folder.Name = "Brainrots"
		folder.Parent = Workspace
	end

	return {
		BeltTopY = beltTop,
		BeltStartX = Config.Belt.StartX,
		BeltEndX = Config.Belt.EndX,
		Bases = bases,
		Folder = worldFolder,
		SpawnPosition = spawnPos,
	}
end

-- DressUp --------------------------------------------------------------------
-- Optional decoration loaded after the world already works. Every load is
-- pcall'd through AssetLibrary; a failure changes nothing.

function WorldBuilder.DressUp(world: any)
	task.spawn(function()
		-- Foliage scattered on the outer grass ring.
		local foliage = AssetLibrary.LoadModel(7990107300)
		if foliage and world and world.Folder then
			local rng = Random.new(1234)
			for i = 1, 10 do
				local clone = foliage:Clone()
				local angle = rng:NextNumber(0, math.pi * 2)
				local radius = rng:NextNumber(195, 215)
				local x = math.cos(angle) * radius
				local z = math.sin(angle) * radius
				clone.Parent = world.Folder
				AssetLibrary.GroundPivotTo(clone, 0)
				clone:PivotTo(CFrame.new(x, clone:GetPivot().Position.Y, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
				for _, inst in ipairs(clone:GetDescendants()) do
					if inst:IsA("BasePart") then
						inst.Anchored = true
						inst.CanCollide = false
						inst.CanQuery = false
					end
				end
				if i >= 10 then
					break
				end
			end
		end

		-- Fancier street lamps along the path (purely cosmetic swap-in:
		-- they are placed beside the procedural posts, never replacing them).
		local lamp = AssetLibrary.LoadModel(14212653287)
		if lamp and world and world.Folder then
			for x = -162, 162, 54 do
				local clone = lamp:Clone()
				clone.Parent = world.Folder
				AssetLibrary.GroundPivotTo(clone, Config.Belt.TopY)
				clone:PivotTo(CFrame.new(x, clone:GetPivot().Position.Y, Config.Layout.PathWidth / 2 + 4.4))
				for _, inst in ipairs(clone:GetDescendants()) do
					if inst:IsA("BasePart") then
						inst.Anchored = true
						inst.CanCollide = false
						inst.CanQuery = false
					end
				end
			end
		end

		-- Brainrot display shelf behind the pens of the first enclosure row:
		-- a single decorative pack instance, kept well clear of gameplay.
		local pack = AssetLibrary.LoadModel(137461628889541)
		if pack and world and world.Bases and world.Bases[1] then
			local center = world.Bases[1].Center
			pack.Parent = world.Folder
			AssetLibrary.GroundPivotTo(pack, 0)
			pack:PivotTo(CFrame.new(center.X, pack:GetPivot().Position.Y, center.Z - 26))
			for _, inst in ipairs(pack:GetDescendants()) do
				if inst:IsA("BasePart") then
					inst.Anchored = true
					inst.CanCollide = false
					inst.CanQuery = false
				end
			end
		end
	end)
end

return WorldBuilder
