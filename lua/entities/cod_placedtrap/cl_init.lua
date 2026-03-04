
include("shared.lua")

function ENT:Draw()
	self:DrawModel()
end

function ENT:IsTranslucent()
	return false
end

function ENT:OnBeingBlocked( name, old, new )
	if new == true then
	else
	end
end

// for networking the firing mechanic of a buildable from serverside only code to the client (muzzleflash, sounds, tracer, shell ejection, etc)
net.Receive("TFA.BO2.Buildable.Attack", function( length )
	local entity = net.ReadEntity()
	local endpos = net.ReadVector()

	if not IsValid( entity ) or not entity.Attack or not isfunction( entity.Attack ) then
		return
	end

	entity:Attack( endpos )
end)
