net.Receive("TenzanCutResult", function()
    print(net.ReadString())
end)

concommand.Add("tenzan_cut_test", function()
    local ply = LocalPlayer()
    local eye_angles = ply:EyeAngles()
    local eye_position = ply:EyePos()
    local trace = util.TraceLine({
        start = eye_position,
        endpos = eye_position + eye_angles:Forward() * 4096,
        filter = ply,
        mask = MASK_SOLID
    })

    if not trace.Hit or not IsValid(trace.Entity) or trace.Entity == game.GetWorld() then
        print("[Tenzan Cut] no valid entity under crosshair")
        return
    end

    net.Start("TenzanCutRequest")
    net.WriteEntity(trace.Entity)
    net.WriteVector(trace.HitPos)
    net.WriteVector(eye_angles:Right())
    net.WriteVector(eye_angles:Up())
    net.SendToServer()

    print(string.format(
        "[Tenzan Cut] requested %s #%d",
        trace.Entity:GetClass(),
        trace.Entity:EntIndex()
    ))
end)
