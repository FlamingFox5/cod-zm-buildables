
AddCSLuaFile()

--[Info]--
ENT.Base = "cod_placedtrap"
ENT.PrintName = "Turbine Generator"
ENT.AutomaticFrameAdvance = true

ENT.Delay = 1
ENT.Range = 200

ENT.NZHudIcon = Material("vgui/icon/zm_turbine_icon.png", "smooth unlitgeneric")

ENT.IgnoreLocalPower = true
ENT.bIsTrap = true

local nzombies = engine.ActiveGamemode() == "nzombies"
local sp = game.SinglePlayer()

DEFINE_BASECLASS( ENT.Base )

function ENT:OnRemove()
	self:StopParticles()

	self:StopSound("TFA_BO2_TURBINE.Loop")

	if SERVER then
		self:TurbineRemovePower()
	end
end
