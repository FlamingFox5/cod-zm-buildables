
include("shared.lua")

function ENT:Draw()
	self:DrawModel()

	if !self.pvslight1 or !IsValid(self.pvslight1)then
		self.pvslight1 = CreateParticleSystem(self, "bo2_flinger_leak", PATTACH_POINT_FOLLOW, 2)
	end
end

function ENT:Initialize()
	self:AddEFlags( EFL_NO_THINK_FUNCTION )
end

function ENT:GetNZTargetText()
	local ply = self:GetOwner()
	if LocalPlayer() == ply then
		return "Press "..string.upper(input.LookupBinding("+USE")).." - pickup Trample Steam"
	else
		return ply:Nick().."'s - Trample Steam"
	end
end

function ENT:IsTranslucent()
	return false
end