include("shared.lua")

local cap_material

local function GetWorldNormal(entity, local_normal)
    return (entity:LocalToWorld(local_normal) - entity:GetPos()):GetNormalized()
end

local function GetCapMaterial()
    if not cap_material then
        cap_material = Material("tenzan/cut_cap")
    end

    return cap_material
end

function ENT:Initialize()
    timer.Simple(0, function()
        if not IsValid(self) then return end

        net.Start("TenzanCutPieceDataRequest")
        net.WriteEntity(self)
        net.SendToServer()
    end)
end

net.Receive("TenzanCutPieceData", function()
    local piece = net.ReadEntity()
    if not IsValid(piece) then return end

    local planes = {}
    for index = 1, net.ReadUInt(3) do
        planes[index] = {
            Point = net.ReadVector(),
            Normal = net.ReadVector()
        }
    end

    local caps = {}
    for index = 1, net.ReadUInt(16) do
        local cap = {
            Normal = net.ReadVector(),
            Points = {}
        }

        for point_index = 1, net.ReadUInt(16) do
            cap.Points[point_index] = net.ReadVector()
        end

        caps[index] = cap
    end

    piece.TenzanCutData = {
        Planes = planes,
        Caps = caps
    }
end)

function ENT:Draw()
    local data = self.TenzanCutData
    if not data then return end

    for _, plane in ipairs(data.Planes) do
        local world_point = self:LocalToWorld(plane.Point)
        local world_normal = GetWorldNormal(self, plane.Normal)

        render.PushCustomClipPlane(
            world_normal,
            world_normal:Dot(world_point)
        )
    end

    self:DrawModel()

    for index = #data.Planes, 1, -1 do
        render.PopCustomClipPlane()
    end

    local triangle_count = 0
    for _, cap in ipairs(data.Caps) do
        triangle_count = triangle_count + math.max(#cap.Points - 2, 0)
    end

    if triangle_count == 0 then return end

    render.SetMaterial(GetCapMaterial())
    render.SetColorModulation(0.58, 0.45, 0.32)
    render.CullMode(MATERIAL_CULLMODE_NONE)

    mesh.Begin(MATERIAL_TRIANGLES, triangle_count)

    for _, cap in ipairs(data.Caps) do
        local world_normal = GetWorldNormal(self, cap.Normal)
        local first_point = self:LocalToWorld(cap.Points[1])

        for index = 2, #cap.Points - 1 do
            local point_b = self:LocalToWorld(cap.Points[index])
            local point_c = self:LocalToWorld(cap.Points[index + 1])

            mesh.Normal(world_normal)
            mesh.Position(first_point)
            mesh.TexCoord(0, 0)
            mesh.AdvanceVertex()

            mesh.Normal(world_normal)
            mesh.Position(point_b)
            mesh.TexCoord(0, 0)
            mesh.AdvanceVertex()

            mesh.Normal(world_normal)
            mesh.Position(point_c)
            mesh.TexCoord(0, 0)
            mesh.AdvanceVertex()
        end
    end

    mesh.End()

    render.CullMode(MATERIAL_CULLMODE_CCW)
    render.SetColorModulation(1, 1, 1)
end
