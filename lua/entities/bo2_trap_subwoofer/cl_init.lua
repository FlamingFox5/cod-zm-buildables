
include("shared.lua")

function ENT:Draw()
	self:DrawModel()
end

function ENT:Initialize()
	self:AddEFlags( EFL_NO_THINK_FUNCTION )
end

function ENT:GetNZTargetText()
	local ply = self:GetOwner()
	if LocalPlayer() == ply then
		return "Press "..string.upper(input.LookupBinding("+USE")).." - pickup Subsurface Resonator"
	else
		return ply:Nick().."'s - Subsurface Resonator"
	end
end

function ENT:IsTranslucent()
	return false
end