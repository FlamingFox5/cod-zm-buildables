
AddCSLuaFile()

--[Info]--
ENT.Base = "cod_placedtrap"
ENT.PrintName = "Tramplesteam"
ENT.AutomaticFrameAdvance = true

ENT.Delay = 1.5

ENT.NZHudIcon = Material("vgui/icon/zom_hud_trample_steam_complete.png", "smooth unlitgeneric")
ENT.bIsTrap = true

function ENT:OnRemove()
	self:StopSound("TFA_BO2_FLINGER.Reset")
end
