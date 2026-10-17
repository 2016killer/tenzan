AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

include("shared.lua")

function ENT:Initialize()
    self:SetSolid(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:DrawShadow(false)

    timer.Simple(0.1, function()
        if IsValid(self) then
            self:Dissolve()
        end
    end)
end
