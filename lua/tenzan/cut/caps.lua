local Cut = Tenzan.Cut

local EPSILON = 0.01
local MIN_CAP_AREA = 0.01

local function GetPosition(value)
    if isvector(value) then return value end
    return value.pos
end

local function IsSamePoint(point_a, point_b)
    return point_a:DistToSqr(point_b) <= EPSILON * EPSILON
end

local function CleanPolygon(points)
    local cleaned = {}

    for _, point in ipairs(points) do
        if #cleaned == 0 or not IsSamePoint(cleaned[#cleaned], point) then
            cleaned[#cleaned + 1] = point
        end
    end

    if #cleaned > 1 and IsSamePoint(cleaned[1], cleaned[#cleaned]) then
        cleaned[#cleaned] = nil
    end

    if #cleaned < 3 then return nil end
    return cleaned
end

local function ClipPolygon(points, plane, keep_positive)
    local clipped = {}

    for index = 1, #points do
        local point_a = points[index]
        local point_b = points[index % #points + 1]
        local distance_a = plane.Normal:Dot(point_a - plane.Point)
        local distance_b = plane.Normal:Dot(point_b - plane.Point)
        local inside_a
        local inside_b

        if keep_positive then
            inside_a = distance_a >= -EPSILON
            inside_b = distance_b >= -EPSILON
        else
            inside_a = distance_a <= EPSILON
            inside_b = distance_b <= EPSILON
        end

        if inside_a then
            clipped[#clipped + 1] = point_a
        end

        if inside_a ~= inside_b then
            local fraction = distance_a / (distance_a - distance_b)
            clipped[#clipped + 1] = point_a + (point_b - point_a) * fraction
        end
    end

    return CleanPolygon(clipped)
end

local function BuildConvexTriangles(raw_convex)
    local triangles = {}

    for index = 1, #raw_convex - 2, 3 do
        local point_a = GetPosition(raw_convex[index])
        local point_b = GetPosition(raw_convex[index + 1])
        local point_c = GetPosition(raw_convex[index + 2])

        if point_a and point_b and point_c then
            triangles[#triangles + 1] = {
                A = point_a,
                B = point_b,
                C = point_c
            }
        end
    end

    return triangles
end

local function AddUniquePoint(points, point)
    for _, existing in ipairs(points) do
        if IsSamePoint(existing, point) then return end
    end

    points[#points + 1] = point
end

local function BuildCrossSection(triangles, plane)
    local points = {}

    for _, triangle in ipairs(triangles) do
        local corners = { triangle.A, triangle.B, triangle.C }

        for index = 1, 3 do
            local point_a = corners[index]
            local point_b = corners[index % 3 + 1]
            local distance_a = plane.Normal:Dot(point_a - plane.Point)
            local distance_b = plane.Normal:Dot(point_b - plane.Point)

            if math.abs(distance_a) <= EPSILON then
                AddUniquePoint(points, point_a)
            end

            if (distance_a > EPSILON and distance_b < -EPSILON)
                or (distance_a < -EPSILON and distance_b > EPSILON) then
                local fraction = distance_a / (distance_a - distance_b)
                AddUniquePoint(points, point_a + (point_b - point_a) * fraction)
            end
        end
    end

    if #points < 3 then return nil end

    local center = vector_origin
    for _, point in ipairs(points) do
        center = center + point
    end
    center = center * (1 / #points)

    local reference = math.abs(plane.Normal.x) < 0.9
        and Vector(1, 0, 0)
        or Vector(0, 1, 0)
    local axis_u = reference - plane.Normal * plane.Normal:Dot(reference)
    axis_u:Normalize()
    local axis_v = plane.Normal:Cross(axis_u)

    table.sort(points, function(point_a, point_b)
        local offset_a = point_a - center
        local offset_b = point_b - center
        local angle_a = math.atan2(axis_v:Dot(offset_a), axis_u:Dot(offset_a))
        local angle_b = math.atan2(axis_v:Dot(offset_b), axis_u:Dot(offset_b))
        return angle_a < angle_b
    end)

    return CleanPolygon(points)
end

local function GetPolygonArea(points)
    local area = 0

    for index = 2, #points - 1 do
        local edge_a = points[index] - points[1]
        local edge_b = points[index + 1] - points[1]
        area = area + edge_a:Cross(edge_b):Length() * 0.5
    end

    return area
end

function Cut.BuildCaps(source, planes)
    local caps_by_mask = {
        {},
        {},
        {},
        {}
    }

    local physics_object = source:GetPhysicsObject()
    if not IsValid(physics_object) then return caps_by_mask end

    local physics_mesh = physics_object:GetMeshConvexes()
    if not istable(physics_mesh) or #physics_mesh == 0 then
        return caps_by_mask
    end

    local convex_mesh = {}
    for index, raw_convex in ipairs(physics_mesh) do
        convex_mesh[index] = BuildConvexTriangles(raw_convex)
    end

    for mask = 0, 3 do
        local keep_positive = {
            mask % 2 == 1,
            math.floor(mask / 2) % 2 == 1
        }
        local caps = caps_by_mask[mask + 1]

        for _, triangles in ipairs(convex_mesh) do
            for plane_index = 1, 2 do
                local other_index = 3 - plane_index
                local cap = BuildCrossSection(triangles, planes[plane_index])

                if cap then
                    cap = ClipPolygon(
                        cap,
                        planes[other_index],
                        keep_positive[other_index]
                    )
                end

                if cap and GetPolygonArea(cap) >= MIN_CAP_AREA then
                    caps[#caps + 1] = {
                        Normal = keep_positive[plane_index]
                            and planes[plane_index].Normal * -1
                            or planes[plane_index].Normal,
                        Points = cap
                    }
                end
            end
        end
    end

    return caps_by_mask
end
