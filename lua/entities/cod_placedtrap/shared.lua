
AddCSLuaFile()

--[Info]--
ENT.Type = "anim"
ENT.PrintName = "Trap"

ENT.Author = "FlamingFox"
ENT.Purpose = "Kill the undead"
ENT.Instructions = ""

ENT.DoNotDuplicate = true
ENT.DisableDuplicator = true

ENT.bIsTrap = true

local sp = game.SinglePlayer()

function ENT:SetupDataTables()
	self:NetworkVar("String", "TrapClass")

	self:NetworkVar("Bool", "Activated")
	self:NetworkVar("Bool", "Destroyed")
	self:NetworkVar("Bool", "BeingBlocked")

	self:SetDestroyed(false)

	if ( CLIENT ) then
		self:NetworkVarNotify( "BeingBlocked", self.OnBeingBlocked )
	end
end

function ENT:IsBeingBlocked()
	return self:GetBeingBlocked()
end

function ENT:EmitSoundNet(sound)
	if CLIENT or sp then
		if sp and not IsFirstTimePredicted() then return end

		self:EmitSound(sound)
		return
	end

	local filter = RecipientFilter()
	filter:AddPAS(self:GetPos())
	if IsValid(self:GetOwner()) then
		filter:RemovePlayer(self:GetOwner())
	end

	net.Start("tfaSoundEvent", true)
	net.WriteEntity(self)
	net.WriteString(sound)
	net.Send(filter)
end
