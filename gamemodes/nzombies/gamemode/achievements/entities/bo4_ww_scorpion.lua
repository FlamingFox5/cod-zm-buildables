
AddCSLuaFile()

ENT.Base = "tfa_ww_base"
ENT.PrintName = "Electric Bolt"

// Custom Settings

ENT.Impacted = false

ENT.ImpactSound = "TFA_BO4_SCORPION.Impact"

// Default Settings

ENT.Delay = 10

ENT.NoDrawNoShadow = true

ENT.HullMaxs = Vector(2, 2, 2)
ENT.HullMins = ENT.HullMaxs:GetNegated()

ENT.TrailEffect = "bo4_scorpion_trail"
ENT.TrailAttachType = PATTACH_ABSORIGIN_FOLLOW
ENT.TrailAttachPoint = 1

ENT.ImpactDecal = "FadingScorch"

ENT.ImpactBubbles = true
ENT.ImpactBubblesSize = 64
ENT.ImpactBubblesMagnitude = 1

// Explosion Settings

ENT.ScreenShakeAmplitude = 5
ENT.ScreenShakeFrequency = 255
ENT.ScreenShakeDuration = 0.6
ENT.ScreenShakeRange = 96

// DLight Settings

ENT.Color = Color(255, 255, 50, 255)

ENT.DLightBrightness = 1
ENT.DLightDecay = 2000
ENT.DLightSize = 200

ENT.DLightFlashOnRemove = true

ENT.DLightFlashSize = 240
ENT.DLightFlashDecay = 1250
ENT.DLightFlashBrightness = 2

DEFINE_BASECLASS(ENT.Base)

local nzombies = engine.ActiveGamemode() == "nzombies"
local sv_true_damage = GetConVar("sv_tfa_bo3ww_cod_damage")

function ENT:SetupDataTables()
	BaseClass.SetupDataTables(self)

	self:NetworkVarTFA("Bool", "Charged")
	self:NetworkVarTFA("Vector", "HitPos")
end

function ENT:PhysicsCollide(data, phys)
	if self.Impacted then return end
	self.Impacted = true

	sound.Play(self.ImpactSound, data.HitPos)

	local trace = self:CollisionDataToTrace(data)
	local direction = data.OurOldVelocity:GetNormalized()
	local hitEntity = trace.Entity

	self:StoreCollisionEventData(data, trace)

	self:DoImpactEffect(trace)

	if trace.Hit and IsValid(hitEntity) and TFA.WonderWeapon.ShouldDamage(hitEntity, self:GetOwner(), self) then
		local hitCharacter = (hitEntity:IsNPC() or hitEntity:IsPlayer() or hitEntity:IsNextBot())

		local myDamage = self.Damage
		if trace.HitGroup == HITGROUP_HEAD then
			if ( sv_true_damage ~= nil and sv_true_damage:GetBool() ) or nzombies then
				myDamage = hitEntity:Health() + 666
			else
				myDamage = myDamage*7
			end
		end

		local hitDamage = DamageInfo()
		hitDamage:SetDamage(myDamage)
		hitDamage:SetAttacker(IsValid(self:GetOwner()) and self:GetOwner() or self)
		hitDamage:SetInflictor(IsValid(self.Inflictor) and self.Inflictor or self)
		hitDamage:SetDamageType(nzombies and bit.bor(DMG_BULLET, DMG_ENERGYBEAM) or DMG_ENERGYBEAM)
		hitDamage:SetDamageForce(hitCharacter and direction*math.random(12000,16000) or direction*2000)
		hitDamage:SetDamagePosition(trace.HitPos)
		hitDamage:SetReportedPosition(trace.StartPos)

		local nLastHealth = hitEntity:Health()

		hitEntity:DispatchTraceAttack(hitDamage, trace, direction)

		if hitEntity:Health() < nLastHealth then
			self:SendHitMarker(hitEntity, hitDamage, trace)
		end
	end

	util.ScreenShake( data.HitPos, 5, 255, 0.6, 96 )

	ParticleEffect("bo4_scorpion_impact", data.HitPos - data.HitNormal, data.HitNormal:Angle() - Angle(90,0,0))

	self:PhysicsStop(phys)

	self:Remove()
end

function ENT:EntityCollide(trace)
	if self.Impacted then return end

	sound.Play(self.ImpactSound, trace.HitPos)

	self:DoImpactEffect(trace)

	local hitEntity = trace.Entity
	local direction = trace.Normal

	local phys = self:GetPhysicsObject()
	if IsValid(phys) then
		direction = phys:GetVelocity():GetNormalized()
	end

	local playerEntity = self:GetOwner()

	self.Damage = self.mydamage or self.Damage

	if ( hitEntity:IsPlayer() or hitEntity:IsNPC() or hitEntity:IsNextBot() or hitEntity:IsRagdoll() ) then
		if self:GetCharged() and not hitEntity:BO4IsSpinning() and not hitEntity:BO4IsShocked() and not hitEntity:IsRagdoll() then
			self.Impacted = true

			TFA.WonderWeapon.GiveStatus(hitEntity, "BO4_Orion_Spinner", 10, self:GetOwner(), self.Inflictor, self.Damage)

			util.ScreenShake( trace.HitPos, 5, 255, 0.6, 96 )

			ParticleEffect("bo4_scorpion_impact", trace.HitPos - trace.HitNormal, trace.HitNormal:Angle() - Angle(90,0,0))

			self:PhysicsStop()

			self:Remove()
			return false
		else
			ParticleEffect("bo4_scorpion_hit", trace.HitPos, self:GetUp():Angle())

			local myDamage = self.Damage

			if trace.HitGroup == HITGROUP_HEAD then
				if ( sv_true_damage ~= nil and sv_true_damage:GetBool() ) or nzombies then
					myDamage = hitEntity:Health() + 666
				else
					myDamage = myDamage*7
				end
			end

			local hitDamage = DamageInfo()
			hitDamage:SetDamage(myDamage)
			hitDamage:SetAttacker(IsValid(playerEntity) and playerEntity or self)
			hitDamage:SetInflictor(IsValid(self.Inflictor) and self.Inflictor or self)
			hitDamage:SetDamageType(nzombies and bit.bor(DMG_BULLET, DMG_ENERGYBEAM) or DMG_ENERGYBEAM)
			hitDamage:SetDamageForce(direction*math.random(9000, 14000))
			hitDamage:SetDamagePosition(trace.HitPos)
			hitDamage:SetReportedPosition(trace.StartPos)

			hitEntity:DispatchTraceAttack(hitDamage, trace, trace.Normal)

			self:SendHitMarker(hitEntity, hitDamage, trace)

			if IsValid(playerEntity) and playerEntity:IsPlayer() and not hitEntity:IsRagdoll() then
				TFA.WonderWeapon.NotifyAchievement( "BO4_Orion_Penetration_Kills", playerEntity, hitEntity, self )
			end
		end
	else
		self.Impacted = true

		ParticleEffect("bo4_scorpion_impact", trace.HitPos - trace.HitNormal, trace.HitNormal:Angle() - Angle(90,0,0))

		local myDamage = self.Damage

		if trace.HitGroup == HITGROUP_HEAD then
			if ( sv_true_damage ~= nil and sv_true_damage:GetBool() ) or nzombies then
				myDamage = hitEntity:Health() + 666
			else
				myDamage = myDamage*7
			end
		end

		local hitDamage = DamageInfo()
		hitDamage:SetDamage(myDamage)
		hitDamage:SetAttacker(IsValid(self:GetOwner()) and self:GetOwner() or self)
		hitDamage:SetInflictor(IsValid(self.Inflictor) and self.Inflictor or self)
		hitDamage:SetDamageType(nzombies and bit.bor(DMG_BULLET, DMG_ENERGYBEAM) or DMG_ENERGYBEAM)
		hitDamage:SetDamageForce(direction*2000)
		hitDamage:SetDamagePosition(trace.HitPos)
		hitDamage:SetReportedPosition(trace.StartPos)

		hitEntity:DispatchTraceAttack(hitDamage, trace, trace.Normal)

		self:SendHitMarker(hitEntity, hitDamage, trace)

		util.ScreenShake( trace.HitPos, 5, 255, 0.6, 96 )

		self:PhysicsStop()

		self:Remove()
		return false
	end
end
