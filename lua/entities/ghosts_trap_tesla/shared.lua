
AddCSLuaFile()

--[Info]--
ENT.Base = "cod_placedtrap"
ENT.PrintName = "Tesla Trap"

ENT.Delay = 1.5
ENT.Range = 200

ENT.AttackRateMin = 1
ENT.AttackRateMax = 2.5

ENT.NZHudIcon = Material("vgui/icon/director_trap.png", "smooth unlitgeneric")
ENT.bIsTrap = true

function ENT:OnRemove()
	self:StopSound("TFA_GHOSTS_TESLA.Loop")
end
