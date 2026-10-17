Tenzan = Tenzan or {}
Tenzan.Cut = Tenzan.Cut or {}

if SERVER then
    AddCSLuaFile("tenzan/cut/client.lua")

    include("tenzan/cut/caps.lua")
    include("tenzan/cut/server.lua")
end

if CLIENT then
    include("tenzan/cut/client.lua")
end
