
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
		return "Press "..string.upper(input.LookupBinding("+USE")).." - pickup Rake Trap"
	else
		return ply:Nick().."'s - Rake Trap"
	end
end

function ENT:IsTranslucent()
	return true
end