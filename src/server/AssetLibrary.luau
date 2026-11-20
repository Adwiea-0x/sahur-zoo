-- AssetLibrary.luau
-- Thin, defensive wrapper around InsertService. Loading a community asset
-- must never crash the game: every call is pcall'd, loaded content is
-- sanitised, and failures simply return nil so callers can fall back.

local InsertService = game:GetService("InsertService")

local AssetLibrary = {}

local SCRIPT_CLASSES: { [string]: boolean } = {
	Script = true,
	LocalScript = true,
	ModuleScript = true,
}

-- Remove anything executable or noisy from a freshly inserted model.
local function sanitize(instance: Instance)
	if SCRIPT_CLASSES[instance.ClassName] then
		instance:Destroy()
		return
	end
	if instance:IsA("Sound") then
		-- Keep the node but silence it; some packs reference sounds by id.
		instance.Volume = 0
		instance.Playing = false
	end
	if instance:IsA("BasePart") then
		instance.Anchored = true
		instance.CanCollide = false
		instance.CanQuery = false
		instance.CanTouch = false
	end
	-- Snapshot children first: Destroy during iteration is unsafe.
	local children = instance:GetChildren()
	for _, child in ipairs(children) do
		sanitize(child)
	end
end

AssetLibrary.Sanitize = sanitize

-- Load a model by asset id. Returns nil on any failure.
function AssetLibrary.LoadModel(assetId: number): Model?
	if not assetId or assetId <= 0 then
		return nil
	end
	local ok, result = pcall(function()
		return InsertService:LoadAsset(assetId)
	end)
	if not ok or not result then
		return nil
	end

	local container = result :: Instance
	local model: Model? = nil

	if container:IsA("Model") then
		model = container
	else
		-- LoadAsset returns a container Model holding the asset; unwrap it.
		local found = container:FindFirstChildWhichIsA("Model", true)
		if found then
			model = found
		elseif container:IsA("BasePart") then
			local wrap = Instance.new("Model")
			wrap.Name = container.Name
			container.Parent = wrap
			model = wrap
		else
			-- Last resort: treat the container itself as the model shell.
			local wrap = Instance.new("Model")
			wrap.Name = container.Name
			for _, child in ipairs(container:GetChildren()) do
				child.Parent = wrap
			end
			container:Destroy()
			model = wrap
		end
	end

	if not model then
		container:Destroy()
		return nil
	end

	-- Detach from the LoadAsset container if we unwrapped a child.
	if model.Parent == container and container ~= (model :: Instance) then
		model.Parent = nil
		container:Destroy()
	end

	sanitize(model)
	return model
end

-- Re-pivot a model so its pivot sits at the bottom centre of its body.
--
-- IMPORTANT: Model has no settable "PivotOffset" property. The correct
-- mechanism is to offset the model's pivot relative to its PrimaryPart,
-- or (simpler and robust) to add an explicit Root part and point
-- PrimaryPart at it. CharacterFactory does the Root approach; this helper
-- handles the pure-pivot case for dressing models by moving the model so
-- that GetBoundingBox's lowest point lands on the target height.
--
-- The computation is wrapped in pcall: if anything about the model is
-- unusual (empty, streaming, etc.) the model is left exactly as it was.
function AssetLibrary.GroundPivotTo(model: Model, targetBottomY: number?)
	local ok = pcall(function()
		local cf, size = model:GetBoundingBox()
		if size.Magnitude == 0 then
			return
		end
		local bottomY = cf.Position.Y - size.Y / 2
		local wanted = targetBottomY or 0
		local lift = wanted - bottomY
		if math.abs(lift) > 0.001 then
			model:PivotTo(model:GetPivot() + Vector3.new(0, lift, 0))
		end
		-- Record where the ground sits relative to the pivot for callers
		-- that clone this model later.
		local pivotY = model:GetPivot().Position.Y
		model:SetAttribute("GroundOffset", pivotY - wanted)
		model:SetAttribute("BodyHeight", size.Y)
	end)
	return ok
end

return AssetLibrary
