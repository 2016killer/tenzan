ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "LightningLightEffect"
ENT.Category = "Tenzan"

ENT.RenderGroup = RENDERGROUP_TRANSLUCENT
ENT.Spawnable = false

function ENT:SetupDataTables()
	self:NetworkVar("Float", 0, "AverageIntensity")
	self:NetworkVar("Vector", 0, "EffectColor")
	self:NetworkVar("Float", 1, "EffectSize")
end

if SERVER then
	AddCSLuaFile()

	function ENT:Initialize()
		self:DrawShadow(false)
		self:SetAverageIntensity(2)
		self:SetEffectColor(Vector(1.0, 0.95, 0.4))
		self:SetEffectSize(300)
	end

	function ENT:SetLightIntensity(intensity)
		self:SetAverageIntensity(intensity)
	end

	concommand.Add("tenzan_test_light", function(ply)
		if not IsValid(ply) then
			return
		end

		local tr = ply:GetEyeTrace()
		local ent = ents.Create("tenzan_lightning_light")
		if not IsValid(ent) then
			return
		end

		ent:SetPos(tr.HitPos + tr.HitNormal * 8)
		ent:SetAngles(ply:EyeAngles())
		ent:Spawn()
		ent:SetLightIntensity(2)
		ent:SetEffectColor(Vector(1.0, 0.95, 0.4))
		ent:SetEffectSize(300)

		undo.Create("Tenzan Lightning Light")
		undo.AddEntity(ent)
		undo.SetPlayer(ply)
		undo.Finish()
	end)
end

if CLIENT then
	local LIGHT_MATERIAL = Material("tenzan/light_horizontal")

	function ENT:Initialize()
		self.SmoothedIntensity = self:GetAverageIntensity()
		self.LastTargetIntensity = self.SmoothedIntensity
		self.LerpStartIntensity = self.SmoothedIntensity
		self.LerpStartTime = RealTime()
		self:SetRenderBounds(Vector(-1024, -1024, -1024), Vector(1024, 1024, 1024))
	end

	function ENT:DrawTranslucent()
		local currentTime = RealTime()
		local targetIntensity = self:GetAverageIntensity()

		if targetIntensity ~= self.LastTargetIntensity then
			self.LastTargetIntensity = targetIntensity
			self.LerpStartIntensity = self.SmoothedIntensity
			self.LerpStartTime = currentTime
		end

		local lerpProgress = math.Clamp((currentTime - self.LerpStartTime) / 0.1, 0, 1)
		self.SmoothedIntensity = Lerp(lerpProgress, self.LerpStartIntensity, targetIntensity)

		local intensity = Tenzan.GetLightningLightIntensity(self.SmoothedIntensity)
		local colorVec = self:GetEffectColor()
		local size = self:GetEffectSize()


		local dietimeadditive = self.SmoothedIntensity - intensity
		local dietime = math.Clamp(0.25 + dietimeadditive * 1000, 0.1, 0.4)

		local dlight = DynamicLight(self:EntIndex())
		if dlight then
			dlight.pos = self:GetPos()
			dlight.r = colorVec.x * 255
			dlight.g = colorVec.y * 255
			dlight.b = colorVec.z * 255
			dlight.brightness = self.SmoothedIntensity
			dlight.decay = 1000 / dietime
			dlight.size = size
			dlight.dietime = CurTime() + dietime
		end

		LIGHT_MATERIAL:SetVector("$color", colorVec * intensity)
		render.SetMaterial(LIGHT_MATERIAL)
		render.DrawSprite(self:GetPos(), size * 2, size / 4.0, color_white)
	end
end
