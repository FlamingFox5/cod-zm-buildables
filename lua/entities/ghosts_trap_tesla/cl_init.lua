
include("shared.lua")

function ENT:Draw()
	self:DrawModel()

	if self:GetActivated() then
		if !self.pvslight1 or !IsValid(self.pvslight1)then
			self.pvslight1 = CreateParticleSystem(self, "ghosts_teslatrap", PATTACH_POINT_FOLLOW, 1)
		end
		if !self.pvslight2 or !IsValid(self.pvslight2)then
			self.pvslight2 = CreateParticleSystem(self, "ghosts_teslatrap", PATTACH_POINT_FOLLOW, 2)
		end
		if !self.pvslight3 or !IsValid(self.pvslight3)then
			self.pvslight3 = CreateParticleSystem(self, "ghosts_teslatrap", PATTACH_POINT_FOLLOW, 3)
		end
	else
		if self.pvslight1 and IsValid(self.pvslight1)then
			self.pvslight1:StopEmission()
		end
		if self.pvslight2 and IsValid(self.pvslight2)then
			self.pvslight2:StopEmission()
		end
		if self.pvslight3 and IsValid(self.pvslight3)then
			self.pvslight3:StopEmission()
		end
	end
end

function ENT:Initialize()
	self:AddEFlags( EFL_NO_THINK_FUNCTION )
end

function ENT:GetNZTargetText()
	local ply = self:GetOwner()
	if LocalPlayer() == ply then
		return "Press "..string.upper(input.LookupBinding("+USE")).." - pickup Tesla Trap"
	else
		return ply:Nick().."'s - Tesla Trap"
	end
end

function ENT:IsTranslucent()
	return true
end