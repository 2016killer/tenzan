local Cut = Tenzan.Cut
local PIECE_SEPARATION = 0.75

hook.Add("ShouldCollide", "TenzanCutPiece_Collisions", function(entity_a, entity_b)
    if IsValid(entity_a)
        and IsValid(entity_b)
        and entity_a:GetClass() == "tenzan_cut_piece"
        and entity_b:GetClass() == "tenzan_cut_piece" then
        return false
    end
end)

util.AddNetworkString("TenzanCutRequest")
util.AddNetworkString("TenzanCutResult")
util.AddNetworkString("TenzanCutPieceDataRequest")
util.AddNetworkString("TenzanCutPieceData")

local function GetCutMaterial(surface_prop)
    local surface = string.lower(surface_prop or "")
    local function contains(text)
        return string.find(surface, text, 1, true) ~= nil
    end

    if surface == "combine_metal" then
        return "cut_entity/surface/combine_metal"
    end

    if surface == "gunship" then
        return "cut_entity/surface/gunship_flesh"
    end

    if surface == "strider" then
        return "cut_entity/surface/strider_flesh"
    end

    if contains("metal")
        or contains("canister")
        or contains("chain")
        or surface == "weapon"
        or surface == "crowbar"
        or surface == "roller" then
        return "cut_entity/surface/metal"
    end

    if contains("wood") or surface == "foliage" then
        return "cut_entity/surface/wood"
    end

    if contains("concrete")
        or contains("stone")
        or contains("brick")
        or contains("rock")
        or surface == "tile"
        or surface == "asphalt"
        or surface == "gravel"
        or surface == "sand" then
        return "cut_entity/surface/concrete"
    end

    if contains("plaster") then
        return "cut_entity/surface/plaster"
    end

    if contains("rubber") then
        return "cut_entity/surface/rubber"
    end

    if contains("flesh")
        or surface == "antlion"
        or surface == "bloodyflesh"
        or surface == "armorflesh" then
        return "cut_entity/surface/flesh"
    end

    return "models/props_c17/FurnitureMetal001a"
end

local function SendResult(ply, message)
    print(message)

    if IsValid(ply) then
        net.Start("TenzanCutResult")
        net.WriteString(message)
        net.Send(ply)
    end
end

local function CopyVisualState(source, piece)
    piece:SetSkin(source:GetSkin())
    piece:SetColor(source:GetColor())
    piece:SetRenderMode(source:GetRenderMode())
    piece:SetRenderFX(source:GetRenderFX())
    piece:SetModelScale(source:GetModelScale(), 0)

    local material = source:GetMaterial()
    if material and material ~= "" then
        piece:SetMaterial(material)
    end

    for index = 0, source:GetNumBodyGroups() - 1 do
        piece:SetBodygroup(index, source:GetBodygroup(index))
    end
end

local function LocalizePlanes(source, world_planes)
    local local_planes = {}

    for index = 1, 2 do
        local world_plane = world_planes[index]
        local world_normal = world_plane.Normal:GetNormalized()

        if world_normal:LengthSqr() == 0 then
            return nil, "cut plane has no normal"
        end

        local local_point = source:WorldToLocal(world_plane.Point)
        local local_direction = source:WorldToLocal(
            world_plane.Point + world_normal
        ) - local_point

        local_planes[index] = {
            Point = local_point,
            Normal = local_direction:GetNormalized()
        }
    end

    if math.abs(local_planes[1].Normal:Dot(local_planes[2].Normal)) > 0.999 then
        return nil, "cut planes are parallel"
    end

    return local_planes
end

local function AddUndo(ply, pieces)
    if not IsValid(ply) then return end

    undo.Create("Tenzan Cut")
    undo.SetPlayer(ply)

    for _, piece in ipairs(pieces) do
        undo.AddEntity(piece)
    end

    undo.Finish("Tenzan Cut")
end

local function CreateVisualPiece(
    source,
    position,
    angles,
    planes,
    caps,
    physics_state
)
    local piece = ents.Create("tenzan_cut_piece")
    if not IsValid(piece) then return nil end

    piece:SetModel(source:GetModel())
    piece:SetPos(position)
    piece:SetAngles(angles)
    CopyVisualState(source, piece)
    piece:Spawn()
    piece:Activate()

    piece:PhysicsInit(SOLID_VPHYSICS)
    piece:SetSolid(SOLID_VPHYSICS)
    piece:SetMoveType(MOVETYPE_VPHYSICS)

    local physics_object = piece:GetPhysicsObject()
    if not IsValid(physics_object) then
        piece:Remove()
        return nil
    end

    piece:SetCollisionGroup(physics_state.CollisionGroup)
    piece:EnableCustomCollisions()
    piece:SetCustomCollisionCheck(true)
    piece:CollisionRulesChanged()
    physics_object:SetMass(math.max(physics_state.Mass / 4, 0.1))

    if physics_state.Material and physics_state.Material ~= "" then
        physics_object:SetMaterial(physics_state.Material)
    end

    if physics_state.MotionEnabled then
        physics_object:SetVelocity(physics_state.Velocity)
        physics_object:SetAngleVelocity(physics_state.AngleVelocity)
        physics_object:Wake()
    else
        physics_object:EnableMotion(false)
    end

    piece.TenzanCutData = {
        Planes = planes,
        Caps = caps,
        Material = physics_state.CutMaterial
    }

    return piece
end

function Cut.ApplyEntityCut(source, world_planes, ply)
    if not IsValid(source) or source == game.GetWorld() then
        return false, "invalid target entity"
    end

    local class = source:GetClass()
    if class == "prop_ragdoll" or source:IsPlayer() or source:IsNPC() then
        return false, "ragdolls, players and NPCs are not supported yet"
    end

    local model = source:GetModel()
    if string.sub(model, 1, 7) ~= "models/" then
        return false, "entity has no model path"
    end

    local local_planes, plane_error = LocalizePlanes(source, world_planes)
    if not local_planes then return false, plane_error end

    local caps_by_mask = Cut.BuildCaps(source, local_planes)
    local source_angles = source:GetAngles()
    local pieces = {}
    local source_physics = source:GetPhysicsObject()
    local physics_state = {
        CollisionGroup = source:GetCollisionGroup(),
        Mass = 1,
        Material = nil,
        MotionEnabled = true,
        Velocity = vector_origin,
        AngleVelocity = vector_origin
    }

    if IsValid(source_physics) then
        physics_state.Mass = math.max(source_physics:GetMass(), 0.4)
        physics_state.Material = source_physics:GetMaterial()
        physics_state.MotionEnabled = source_physics:IsMotionEnabled()
        physics_state.Velocity = source_physics:GetVelocity()
        physics_state.AngleVelocity = source_physics:GetAngleVelocity()
    end

    physics_state.CutMaterial = GetCutMaterial(physics_state.Material)

    for mask = 0, 3 do
        local keep_positive = {
            mask % 2 == 1,
            math.floor(mask / 2) % 2 == 1
        }
        local piece_planes = {}

        for index = 1, 2 do
            piece_planes[index] = {
                Point = local_planes[index].Point,
                Normal = keep_positive[index]
                    and local_planes[index].Normal
                    or local_planes[index].Normal * -1
            }
        end

        local offset = piece_planes[1].Normal + piece_planes[2].Normal
        offset:Normalize()
        offset:Mul(PIECE_SEPARATION)

        local piece = CreateVisualPiece(
            source,
            source:LocalToWorld(offset),
            source_angles,
            piece_planes,
            caps_by_mask[mask + 1],
            physics_state
        )

        if not piece then
            for _, created in ipairs(pieces) do
                if IsValid(created) then created:Remove() end
            end

            return false, "failed to create visual cut entity"
        end

        pieces[#pieces + 1] = piece
    end

    source:Remove()
    AddUndo(ply, pieces)

    return true, {
        Entities = pieces
    }
end

local function ApplyCutAndReport(ply, entity, world_planes)
    if not IsValid(entity) then
        SendResult(ply, "[Tenzan Cut] invalid target entity")
        return
    end

    local class = entity:GetClass()
    local entity_index = entity:EntIndex()
    local success, result = Cut.ApplyEntityCut(entity, world_planes, ply)

    if not success then
        SendResult(ply, "[Tenzan Cut] " .. result)
        return
    end

    SendResult(ply, string.format(
        "[Tenzan Cut] created %d visual entities from %s #%d",
        #result.Entities,
        class,
        entity_index
    ))
end

net.Receive("TenzanCutRequest", function(_, ply)
    local entity = net.ReadEntity()
    local point = net.ReadVector()
    local normal_one = net.ReadVector()
    local normal_two = net.ReadVector()

    ApplyCutAndReport(ply, entity, {
        { Point = point, Normal = normal_one },
        { Point = point, Normal = normal_two }
    })
end)

net.Receive("TenzanCutPieceDataRequest", function(_, ply)
    local piece = net.ReadEntity()
    if not IsValid(ply)
        or not IsValid(piece)
        or piece:GetClass() ~= "tenzan_cut_piece"
        or not piece.TenzanCutData then
        return
    end

    local planes = piece.TenzanCutData.Planes

    net.Start("TenzanCutPieceData")
    net.WriteEntity(piece)
    net.WriteUInt(#planes, 3)

    for _, plane in ipairs(planes) do
        net.WriteVector(plane.Point)
        net.WriteVector(plane.Normal)
    end

    local caps = piece.TenzanCutData.Caps
    net.WriteUInt(#caps, 16)

    for _, cap in ipairs(caps) do
        net.WriteVector(cap.Normal)
        net.WriteUInt(#cap.Points, 16)

        for _, point in ipairs(cap.Points) do
            net.WriteVector(point)
        end
    end

    net.WriteString(piece.TenzanCutData.Material)

    net.Send(ply)
end)

concommand.Add("tenzan_cut_entity", function(ply, _, args)
    local entity = Entity(tonumber(args[1]) or 0)
    if not IsValid(entity) then
        SendResult(ply, "[Tenzan Cut] usage: tenzan_cut_entity <entity index>")
        return
    end

    local center = entity:WorldSpaceCenter()
    ApplyCutAndReport(ply, entity, {
        { Point = center, Normal = Vector(1, 0, 0) },
        { Point = center, Normal = Vector(0, 1, 0) }
    })
end)
