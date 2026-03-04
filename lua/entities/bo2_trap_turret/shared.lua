
AddCSLuaFile()

--[Info]--
ENT.Base = "cod_placedtrap"
ENT.PrintName = "Turret Trap"

ENT.RPM = 400
ENT.RPMRapid = 600

ENT.RapidFire = false
ENT.NextAttack = 0

ENT.TurnRate = 8
ENT.BlowbackCurrent = 0

ENT.NZHudIcon = Material("vgui/icon/zm_turret_icon.png", "smooth unlitgeneric")

ENT.bCanUseTurbine = true

local nzombies = engine.ActiveGamemode() == "nzombies"
local sp = game.SinglePlayer()

DEFINE_BASECLASS( ENT.Base )

function ENT:SetupDataTables()
	BaseClass.SetupDataTables( self )

	self:NetworkVar("Entity", "Target")
	self:NetworkVar("Float", "AttackDelay")
	self:NetworkVar("Float", "TurnRate")
end

function ENT:SetNextAttack( float )
	self:SetAttackDelay( float )
end

function ENT:GetNextAttacK()
	return self:GetAttackDelay()
end

function ENT:OnRemove()
	self:StopSound("TFA_BO2_MOWER.Start")
	self:StopSound("TFA_BO2_MOWER.Loop")
	if self.GetDestroyed and self:GetDestroyed() then
		self:EmitSound("TFA_BO2_MOWER.Stop")
	end
end
