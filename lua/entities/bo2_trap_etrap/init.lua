
AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

DEFINE_BASECLASS( ENT.Base )

local nzombies = engine.ActiveGamemode() == "nzombies"

function ENT:Initialize()
	BaseClass.Initialize( self )

	self:SetNextAttack( 0 )
end

function ENT:Touch(ent)
	if not self:GetActivated() then return end
	if self:GetNextAttack() > CurTime() then return end

	if nzombies and ent:IsPlayer() then return end
	if ent:Health() <= 0 then return end
	if not ent:IsSolid() then return end
	if ent:IsPlayer() and ent:Crouching() then return end

	self:InflictDamage(ent)
	self:TakeDamage(math.random(5)*5, ent, ent)

	local ply = self:GetOwner()
	if nzombies and IsValid(ply) then
		self:SetNextAttack(CurTime() + (ply:HasPerk("time") and 0.05 or 0.5))
	else
		self:SetNextAttack(CurTime() + 0.5)
	end
end

function ENT:Think()
	local ply = self:GetOwner()
	if not IsValid(ply) then
		self:SetHealth(1)
		self:TakeDamage(666, self, self)
		return false
	end

	self:NextThink(CurTime())
	return true
end

function ENT:InflictDamage(ent)
	local ply = self:GetOwner()

	local damage = DamageInfo()
	damage:SetDamage( ent:Health() + 666 )
	damage:SetAttacker( IsValid(ply) and ply or self )
	damage:SetInflictor( IsValid(self.Inflictor) and self.Inflictor or self )
	damage:SetDamageForce( ent:GetUp() )
	damage:SetDamagePosition( math.random(5) == 1 and ent:EyePos() or ent:WorldSpaceCenter() )
	damage:SetDamageType( DMG_SHOCK )

	if ent.NZBossType then
		damage:SetDamage(math.max(240, ent:GetMaxHealth() / 24))
	end

	if ent == ply then
		damage:SetDamage(20)
	else
		if ent:IsPlayer() or ent:IsNextBot() or ent:IsNPC() then
			ParticleEffectAttach("bo3_waffe_electrocute", PATTACH_POINT_FOLLOW, ent, 2)
			if ent:OnGround() then
				ParticleEffectAttach("bo3_waffe_ground", PATTACH_ABSORIGIN_FOLLOW, ent, 1)
			end

			ent:EmitSound("TFA_BO3_WAFFE.Sizzle")
			ent:EmitSound("TFA_BO3_WAFFE.Zap")
		end
	end

	ent:TakeDamageInfo(damage)

	self:EmitSound("TFA_BO2_ETRAP.Zap")

	if nzombies and IsValid(ply) and IsValid( self.Turbine ) then
		for k, v in pairs( ents.FindByClass( "bo2_trap_turbine" ) ) do
			if v.GetActivated and v:GetActivated() and self.Turbine == v and v:GetOwner() ~= ply then
				local helper = v:GetOwner()
				if IsValid( helper ) and helper:IsPlayer() and helper:Alive() then
					helper:GivePoints(10)
				end
			end
		end
	end
end

function ENT:SetNextAttack( time )
	self.NextAttack = tonumber( time )
end

function ENT:GetNextAttack()
	return self.NextAttack
end

function ENT:TurnOn()
	if self:GetActivated() then return end
	self:SetActivated(true)

	self:EmitSound("TFA_BO2_ETRAP.Start")
	self:EmitSound("TFA_BO2_ETRAP.Loop")
end

function ENT:TurnOff()
	if not self:GetActivated() then return end
	self:SetActivated(false)

	self:StopSound("TFA_BO2_ETRAP.Loop")
	self:StopParticles()
end
