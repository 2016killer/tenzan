Tenzan = Tenzan or {}

local NET_SLASH = "tenzan_sword_slash"
local defaultSize = 50
local defaultDuration = 0.4
local defaultColorVec = Vector(1.0, 0.95, 0.4) * 2

if SERVER then
    Tenzan = Tenzan or {}
    util.AddNetworkString(NET_SLASH)

    function Tenzan.PlaySwordSlash(pos, angles, size, duration, colorVec)
        net.Start(NET_SLASH)
        net.WriteVector(pos)
        net.WriteAngle(angles)
        net.WriteFloat(size or defaultSize)
        net.WriteFloat(duration or defaultDuration)
        net.WriteVector(colorVec or defaultColorVec)
        net.Broadcast()
    end

    concommand.Add("tenzan_test_slash", function(ply)
        if not IsValid(ply) then
            return
        end
        local tr = ply:GetEyeTrace()
        Tenzan.PlaySwordSlash(tr.HitPos, ply:EyeAngles(), 100, 5)
    end)
end

if CLIENT then
    Tenzan = Tenzan or {}
    Tenzan.SwordSlashEffects = {}
    Tenzan.SwordSlashMaterial = Material( "tenzan/swordslash" )


    Tenzan.SwordSlashNormalEffect = {}
    Tenzan.SwordSlashNormalEffect.__index = Tenzan.SwordSlashNormalEffect
    function Tenzan.SwordSlashNormalEffect.new(pos, angles, size, duration, colorVec)
        local self = setmetatable({}, Tenzan.SwordSlashNormalEffect)

        self.Type = "Normal" -- string
        self.Duration = duration or defaultDuration -- number (seconds)
        self.ColorVec = colorVec or defaultColorVec -- Vector
        self.Pos = pos -- Vector
        self.Angles = angles -- Angle
        self.Size = size or defaultSize -- number

        return self
    end

    function Tenzan.PlaySwordSlash(pos, angles, size, duration, colorVec)
        Tenzan.SwordSlashEffects[#Tenzan.SwordSlashEffects + 1] =
            Tenzan.SwordSlashNormalEffect.new(pos, angles, size, duration, colorVec)
    end

    net.Receive(NET_SLASH, function()
        Tenzan.PlaySwordSlash(
            net.ReadVector(),
            net.ReadAngle(),
            net.ReadFloat(),
            net.ReadFloat(),
            net.ReadVector()
        )
    end)

    local origin = Vector(0, 0, 0)
    local zoffset = Matrix()
    zoffset:SetAngles(Angle(0, 120, 0))


    hook.Add("PostDrawTranslucentRenderables", "Tenzan_SwordSlashEffects", function(bDrawingDepth, bDrawingSkybox, isDraw3DSkybox)
        if bDrawingDepth or bDrawingSkybox or isDraw3DSkybox then
            return
        end

        if #Tenzan.SwordSlashEffects == 0 then
            return
        end

        local currentTime = CurTime()

        for i = #Tenzan.SwordSlashEffects, 1, -1 do
            local effect = Tenzan.SwordSlashEffects[i]

            if effect.Type == "Normal" then
                if not effect.StartTime then
                    effect.StartTime = currentTime -- number (seconds)
                end

                local elapsed = currentTime - effect.StartTime
                local progress = math.Clamp(elapsed / effect.Duration, 0, 0.95)
                local x = 1 - progress

                local baseTextureTransform = Matrix()
                baseTextureTransform:SetScale(Vector(x, 1, 1))

                Tenzan.SwordSlashMaterial:SetMatrix("$basetexturetransform", baseTextureTransform)
                Tenzan.SwordSlashMaterial:SetVector("$color", effect.ColorVec)

                local modelMatrix = Matrix()
                modelMatrix:SetTranslation(effect.Pos)
                modelMatrix:SetAngles(effect.Angles)
                modelMatrix:SetScale(Vector(1, 1, 0.1))

                render.SetMaterial(Tenzan.SwordSlashMaterial)
                cam.PushModelMatrix(modelMatrix * zoffset)
                render.DrawSphere(origin, effect.Size, 30, 30)
                cam.PopModelMatrix()

                if elapsed >= effect.Duration then
                    table.remove(Tenzan.SwordSlashEffects, i)
                end
            else
                table.remove(Tenzan.SwordSlashEffects, i)
            end
        end
    end)
end
