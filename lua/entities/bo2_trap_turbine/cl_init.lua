
include("shared.lua")

local nzombies = engine.ActiveGamemode() == "nzombies"

function ENT:Draw()
	self:DrawModel()

	if not self.GetActivated then return end
	if self:GetActivated() then
		if !self.pvslight1 or !IsValid(self.pvslight1)then
			self.pvslight1 = CreateParticleSystem(self, "bo2_turbine_pulse", PATTACH_ABSORIGIN_FOLLOW)
		end
		if !self.pvslight2 or !IsValid(self.pvslight2)then
			self.pvslight2 = CreateParticleSystem(self, "bo2_turbine_smoke", PATTACH_POINT_FOLLOW, 2)
		end
	else
		if self.pvslight1 and IsValid(self.pvslight1)then
			self.pvslight1:StopEmission()
		end
		if self.pvslight2 and IsValid(self.pvslight2)then
			self.pvslight2:StopEmission()
		end
	end
end

function ENT:Initialize()
	self:AddEFlags( EFL_NO_THINK_FUNCTION )
end

function ENT:GetNZTargetText()
	local ply = self:GetOwner()
	if LocalPlayer() == ply then
		return "Press "..string.upper(input.LookupBinding("+USE")).." - pickup Turbine"
	else
		return ply:Nick().."'s - Turbine"
	end
end

function ENT:IsTranslucent()
	return false
end