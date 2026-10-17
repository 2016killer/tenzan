ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "LightningLightEffect"
ENT.Category = "Tenzan"

-- TODO，使用开发者控制台变量决定
ENT.Spawnable = ...

if SERVER then
	AddCSLuaFile()

	function ENT:Initialize()
		self:DrawShadow(false)
	end

	function ENT:SetLightIntensity(intensity)
		-- TODO 使用网络变量, 在客户端需要监听变化，然后使用线性插值（0.1s内完成）
	end
end

if CLIENT then
	function ENT:Draw()
		-- TODO 光效绘制
	end
end
