include("shared.lua")

local TEXTURE_SCALE = 64
local cap_materials = {}

local function GetWorldNormal(entity, local_normal)
    return (entity:LocalToWorld(local_normal) - entity:GetPos()):GetNormalized()
end

local function GetCapMaterial(material_name)
    local name = material_name or "tenzan/cut_cap"
    local material = cap_materials[name]

    if not material then
        material = Material(name)

        if material:IsError() then
            material = Material("tenzan/cut_cap")
        end

        cap_materials[name] = material
    end

    return material
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

    local material_name = net.ReadString()

    piece.TenzanCutData = {
        Planes = planes,
        Caps = caps,
        Material = material_name
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

    render.SetMaterial(GetCapMaterial(data.Material))
    render.CullMode(MATERIAL_CULLMODE_NONE)

    mesh.Begin(MATERIAL_TRIANGLES, triangle_count)

    for _, cap in ipairs(data.Caps) do
        local world_normal = GetWorldNormal(self, cap.Normal)
        local reference = math.abs(cap.Normal.x) < 0.9
            and Vector(1, 0, 0)
            or Vector(0, 1, 0)
        local axis_u = reference - cap.Normal * cap.Normal:Dot(reference)
        axis_u:Normalize()
        local axis_v = cap.Normal:Cross(axis_u)
        local uv_origin = cap.Points[1]
        local uvs = {}

        for index, point in ipairs(cap.Points) do
            local offset = point - uv_origin
            uvs[index] = {
                offset:Dot(axis_u) / TEXTURE_SCALE,
                offset:Dot(axis_v) / TEXTURE_SCALE
            }
        end

        local first_point = self:LocalToWorld(cap.Points[1])

        for index = 2, #cap.Points - 1 do
            local point_b = self:LocalToWorld(cap.Points[index])
            local point_c = self:LocalToWorld(cap.Points[index + 1])

            mesh.Normal(world_normal)
            mesh.Position(first_point)
            mesh.TexCoord(uvs[1][1], uvs[1][2])
            mesh.AdvanceVertex()

            mesh.Normal(world_normal)
            mesh.Position(point_b)
            mesh.TexCoord(uvs[index][1], uvs[index][2])
            mesh.AdvanceVertex()

            mesh.Normal(world_normal)
            mesh.Position(point_c)
            mesh.TexCoord(uvs[index + 1][1], uvs[index + 1][2])
            mesh.AdvanceVertex()
        end
    end

    mesh.End()

    render.CullMode(MATERIAL_CULLMODE_CCW)
end
