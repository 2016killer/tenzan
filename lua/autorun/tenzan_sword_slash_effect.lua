if CLIENT then
    Tenzan = Tenzan or {}
    Tenzan.SwordSlashEffects = {}
    Tenzan.SwordSlashMaterial = Material( "tenzan/swordslash.vmt" )


    Tenzan.SwordSlashNormalEffect = {}
    Tenzan.SwordSlashNormalEffect.__index = Tenzan.SwordSlashNormalEffect
    local defaultDuration = 0.4
    local defaultColorVec = Vector(1.0, 0.95, 0.4) * 2
    function Tenzan.SwordSlashNormalEffect.new(pos, angles, duration, colorVec)
        local self = {}

        self.Type = "Normal"
        self.Duration = duration or defaultDuration
        self.ColorVec = colorVec or defaultColorVec
        self.Pos = pos
        self.Angles = angles
        self.Time = 0.0
    end

    local modelMatrix = Matrix()
    modelMatrix:SetScale(Vector(1, 1, 0.1))
    local baseTextureTransform = Matrix()


    hook.Add("PostDrawTranslucentRenderables", "Tenzan_SwordSlashEffects", function()

        if #Tenzan.SwordSlashEffects == 0 then
            return
        end

        for i = #Tenzan.SwordSlashEffects, 1, -1 do
            if effect.Type == "Normal" then
                -- TODO x需要从 1~0 线性插值
                baseTextureTransform:SetScale(Vector(1, 1, 1))
                Tenzan.SwordSlashMaterial:SetMatrix("$basetexturetransform", baseTextureTransform)
                Tenzan.SwordSlashMaterial:SetVector("$color", effect.ColorVec)
                modelMatrix:SetAngles(effect.Angles)

                render.SetMaterial(Tenzan.SwordSlashMaterial)
                cam.PushModelMatrix(modelMatrix)
                render.DrawSphere(effect.Pos, 50, 30, 30)
                cam.PopModelMatrix()
                effect.Time = effect.Time + FrameTime()
                if effect.Time >= effect.Duration then
                    table.remove(Tenzan.SwordSlashEffects, effect)
                end
            else
                
            end
        end
    end)


    -- TODO 网络同步
    
end

-- TODO 一个函数用来添加特效，如果是服务器端需要广播给所有客户端