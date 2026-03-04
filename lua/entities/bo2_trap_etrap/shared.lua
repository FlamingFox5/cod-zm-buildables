
AddCSLuaFile()

--[Info]--
ENT.Base = "cod_placedtrap"
ENT.PrintName = "Electric Trap"

ENT.Delay = 1.5

ENT.NZHudIcon = Material("vgui/icon/zm_etrap_icon.png", "smooth unlitgeneric")
ENT.bIsTrap = true
ENT.bRequiresTurbine = true

function ENT:OnRemove()
	self:StopSound("TFA_BO2_ETRAP.Loop")

	if self.GetDestroyed and self:GetDestroyed() then
		self:EmitSound("TFA_BO2_ETRAP.Stop")
	end
end
