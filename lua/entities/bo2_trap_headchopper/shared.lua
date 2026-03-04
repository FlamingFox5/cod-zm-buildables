
AddCSLuaFile()

--[Info]--
ENT.Base = "cod_placedtrap"
ENT.PrintName = "Head Chopper"
ENT.AutomaticFrameAdvance = true

ENT.Delay = 1.5
ENT.Range = 44

ENT.TraceHullMaxs = Vector( 0.1, 0.1, 0.1 )
ENT.TraceHullMins = ENT.TraceHullMaxs:GetNegated()

ENT.BuildableWallPlaceable = true

ENT.NZHudIcon = Material("vgui/icon/zom_hud_icon_buildable_chopper.png", "smooth unlitgeneric")
ENT.bIsTrap = true
