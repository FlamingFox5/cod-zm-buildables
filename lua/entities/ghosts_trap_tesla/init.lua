
AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

DEFINE_BASECLASS( ENT.Base )

local nzombies = engine.ActiveGamemode() == "nzombies"

function ENT:Initialize()
	BaseClass.Initialize( self )

	self:EmitSound("TFA_GHOSTS_TESLA.Arc")

	self.ActivateTime = CurTime() + 0.5
	self:SetNextAttack(0)
end

function ENT:Touch(ent)
	if not self:GetActivated() then return end
	if self:GetNextAttack() > CurTime() then return end
	
	if not ent:IsSolid() then return end
	if nzombies and ent:IsPlayer() then return end
	if ent:Health() <= 0 then return end

	if ent:IsPlayer() and ent:Crouching() then return end

	self:InflictDamage(ent)
	self:TakeDamage(math.random(5)*5, ent, ent)

	local ply = self:GetOwner()
	if nzombies and IsValid(ply) then
		local mult = ( ply.HasPerk and ply:HasPerk("time") ) and 0.5 or 1
		self:SetNextAttack(CurTime() + self.AttackRateMin*mult)
	else
		self:SetNextAttack(CurTime() + self.AttackRateMin)
	end
end

function ENT:Think()
	local ply = self:GetOwner()
	if not IsValid(ply) then
		self:SetHealth(1)
		self:TakeDamage(666, self, self)
		return false
	end

	if self:GetActivated() then
		if self:GetNextAttack() <= CurTime() then
			local tr = {
				start = self:GetAttachment(4).Pos,
				filter = self,
				mask = MASK_SOLID_BRUSHONLY,
			}

			for k, v in RandomPairs(ents.FindInSphere(self:GetPos(), self.Range)) do
				if v:IsNPC() or v:IsNextBot() then
					if v == self:GetOwner() then continue end
					if v:Health() <= 0 then continue end
					if v.Alive and not v:Alive() then continue end

					tr.endpos = v:EyePos()
					local tr1 = util.TraceLine(tr)
					if tr1.HitWorld then continue end

					self:InflictDamage(v)

					if nzombies then
						local mult = ( ply.HasPerk and ply:HasPerk("time") ) and 0.5 or 1
						self:SetNextAttack(CurTime() + math.Rand(self.AttackRateMin*mult, self.AttackRateMax*mult))
					else
						self:SetNextAttack(CurTime() + math.Rand(self.AttackRateMin, self.AttackRateMax))
					end

					self:TakeDamage( math.random(5)*5, v, v )
					break
				end
			end
		end

		if self.NextArcSound and self.NextArcSound <= CurTime() then
			self:EmitSound("TFA_GHOSTS_TESLA.Arc")
			self.NextArcSound = CurTime() + math.Rand(2,4.5)
		end
	end

	if !self:GetActivated() and self.ActivateTime and self.ActivateTime <= CurTime() then
		self:SetActivated(true)
		self:SetNextAttack(CurTime() + self.AttackRateMin)

		self.ActivateTime = nil
		self.NextArcSound = CurTime() + math.Rand(0.5,1.5)

		self:EmitSound("TFA_GHOSTS_TESLA.Loop")
		self:EmitSound("TFA_GHOSTS_TESLA.Arc")
	end

	self:NextThink(CurTime())
	return true
end

function ENT:InflictDamage(ent)
	local ply = self:GetOwner()
	local damage = DamageInfo()
	damage:SetDamage(ent:Health() + 666)
	damage:SetAttacker(IsValid(ply) and ply or self)
	damage:SetInflictor(IsValid(self.Inflictor) and self.Inflictor or self)
	damage:SetDamageForce(ent:GetUp())
	damage:SetDamagePosition(ent:WorldSpaceCenter() + ent:OBBCenter()*math.Rand(0.1,0.6))
	damage:SetDamageType(DMG_SHOCK)

	if ent == ply then
		damage:SetDamage(20)
	else
		if ent:IsPlayer() or ent:IsNextBot() or ent:IsNPC() then
			util.ParticleTracerEx("bo3_waffe_jump", self:GetAttachment(math.random(3)).Pos, ent:EyePos(), false, ply:EntIndex(), 0)

			if nzombies and (ent.NZBossType or ent.IsMooBossZombie or string.find(ent:GetClass(), "nz_zombie_boss")) then
				damage:SetDamage(math.max(240, ent:GetMaxHealth()/16))
			else
				ParticleEffectAttach("bo3_waffe_electrocute", PATTACH_POINT_FOLLOW, ent, 2)
			end

			if ent:OnGround() then
				ParticleEffectAttach("bo3_waffe_ground", PATTACH_ABSORIGIN_FOLLOW, ent, 0)
			end

			ent:EmitSound("TFA_BO3_WAFFE.Sizzle")
			ent:EmitSound("TFA_GHOSTS_TESLA.Explode")
		end
	end

	ent:TakeDamageInfo(damage)

	self:EmitSound("TFA_GHOSTS_TESLA.Zap")
end

function ENT:SetNextAttack( time )
	self.NextAttack = tonumber( time )
end

function ENT:GetNextAttack()
	return self.NextAttack
end
