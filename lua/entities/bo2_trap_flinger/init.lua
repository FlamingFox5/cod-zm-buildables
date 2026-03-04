
AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

DEFINE_BASECLASS( ENT.Base )

local nzombies = engine.ActiveGamemode() == "nzombies"

function ENT:Initialize()
	BaseClass.Initialize( self )

	local ply = self:GetOwner()
	if nzombies and IsValid(ply) then
		self:SetNextAttack(CurTime() + (ply:HasPerk("time") and 1.2 or 8))
		self:SequenceThenIdle(ply:HasPerk("time") and "reset_zombie" or "reset")
		if ply:HasPerk('time') then
			self:EmitSound("TFA_BO2_FLINGER.Ready")
		end
	else
		self:SetNextAttack(CurTime() + 8)
		self:SequenceThenIdle("reset")
	end
end

function ENT:Touch(ent)
	if self:GetDestroyed() then return end
	if self:GetNextAttack() > CurTime() then return end
	if not ent:IsPlayer() then return end
	if ent:Crouching() then return end

	local vecDir = self:GetForward()
	vecDir = Vector(vecDir[1], vecDir[2], 0)

	ent:Fire( "ignorefalldamage", "", 0 )
	ent:SetGroundEntity( nil )
	ent:SetLocalVelocity( vecDir * 450 + Vector( 0, 0, 400 ) )

	local trace = self:GetTouchTrace()

	local vecPos = trace.HitPos
	local vecMins, vecMaxs = self:GetCollisionBounds()

	debugoverlay.Axis( trace.HitPos, trace.Normal:Angle(), 10, 4, true)

	debugoverlay.BoxAngles( self:GetPos(), vecMins, vecMaxs, self:GetAngles(), 4, Color(255, 0, 0, 0) )

	vecMins:Rotate( self:GetAngles() )
	vecMaxs:Rotate( self:GetAngles() )

	vecMins:Add( self:GetPos() )
	vecMaxs:Add( self:GetPos() )

	debugoverlay.Axis( vecMins, self:GetAngles(), 10, 4, true)
	debugoverlay.Axis( vecMaxs, self:GetAngles(), 10, 4, true)

	local nearbyEnts = ents.FindInBox( vecMins, vecMaxs )
	for k, v in pairs( nearbyEnts ) do
		if ( v:IsNPC() or v:IsNextBot() ) and v:Health() > 0 and self:TargetVisisble( v, vecPos ) then
			local vecPoint = self:NearestPoint( v:GetPos() + vector_up )

			debugoverlay.Axis( vecPoint, (vecPoint - self:GetPos()):Angle(), 5, 4, true)

			if v:IsPointInBounds( vecPoint ) then
				self:InflictDamage(v)

				self:TakeDamage(math.random(3)*5, v, v)
			end
		end
	end

	local timetraveler = false
	if nzombies and ent:HasPerk('time') then
		timetraveler = true
	end

	self:ResetSequence("launch")
	timer.Simple(self:SequenceDuration(), function()
		if not IsValid(self) or not IsValid(ent) then return end
		if nzombies then
			self:SequenceThenIdle(timetraveler and "reset_zombie" or "reset")
			if timetraveler then
				self:EmitSound("TFA_BO2_FLINGER.Ready")
			end
		else
			self:SequenceThenIdle("reset")
		end
	end)

	if attData and attData.Pos then
		ParticleEffect("bo2_flinger_launch", attData.Pos, attData.Ang)
	end

	self:TakeDamage(20, self)
	self:EmitSound("TFA_BO2_FLINGER.Shoot")

	if nzombies then
		self:SetNextAttack(CurTime() + (timetraveler and 1.4 or 8))
	else
		self:SetNextAttack(CurTime() + 8)
	end
end

function ENT:StartTouch(ent)
	if self:GetDestroyed() then return end
	if self:GetNextAttack() > CurTime() then return end
	if not ent:IsSolid() then return end

	if ent:IsPlayer() then return end
	if ent:Health() <= 0 then return end

	local trace = self:GetTouchTrace()

	local vecPos = trace.HitPos
	local vecMins, vecMaxs = self:GetCollisionBounds()

	debugoverlay.Axis( trace.HitPos, trace.Normal:Angle(), 10, 4, true)

	debugoverlay.BoxAngles( self:GetPos(), vecMins, vecMaxs, self:GetAngles(), 4, Color(255,0,0,0))

	vecMins:Rotate( self:GetAngles() )
	vecMaxs:Rotate( self:GetAngles() )

	vecMins:Add( self:GetPos() )
	vecMaxs:Add( self:GetPos() )

	debugoverlay.Axis( vecMins, self:GetAngles(), 10, 4, true)
	debugoverlay.Axis( vecMaxs, self:GetAngles(), 10, 4, true)

	local bSuccess = false
	local nearbyEnts = ents.FindInBox( vecMins, vecMaxs )
	for k, v in pairs( nearbyEnts ) do
		if v ~= ent and ( v:IsNPC() or v:IsNextBot() ) and v:Health() > 0 and self:TargetVisisble( v, vecPos ) then
			local vecPoint = self:NearestPoint( v:GetPos() + vector_up )

			debugoverlay.Axis( vecPoint, (vecPoint - self:GetPos()):Angle(), 5, 4, true)

			if v:IsPointInBounds( vecPoint ) then
				if !bSuccess then
					bSuccess = true
				end

				self:InflictDamage(v)

				self:TakeDamage(math.random(3)*5, v, v)
			end
		end
	end

	if bSuccess or ( ent:IsNPC() or ent:IsNextBot() ) then
		self:InflictDamage(ent)
		self:TakeDamage(math.random(5)*5, ent, ent)

		local attData = self:GetAttachment(1)
		if attData and attData.Pos then
			ParticleEffect("bo2_flinger_launch", attData.Pos, attData.Ang)
		end

		self:EmitSound("TFA_BO2_FLINGER.Shoot")
		self:SetNextAttack(CurTime() + 1)

		self:ResetSequence("launch")
		timer.Simple( self:SequenceDuration(), function()
			if not IsValid(self) then return end
			self:SequenceThenIdle("reset_zombie")
		end )
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

function ENT:SequenceThenIdle(seq)
	self:ResetSequence(seq)

	timer.Simple(self:SequenceDuration(), function() 
		if not IsValid(self) then return end
		self:StopSound("TFA_BO2_FLINGER.Reset")
		self:ResetSequence("idle")
	end)
end

function ENT:TargetVisisble(entity, pos)
	if not IsValid(entity) then
		return false
	end

	local trace = {}

	util.TraceLine({
		start = pos,
		endpos = entity:EyePos(),
		mask = MASK_SOLID_BRUSHONLY,
		filter = { self, self:GetOwner() },
		output = trace,
	})

	//debugoverlay.Line( trace.StartPos, entity:EyePos(), 4, color_white, true )

	return !trace.HitWorld
end

function ENT:InflictDamage(ent)
	local ply = self:GetOwner()
	local damage = DamageInfo()
	damage:SetDamage(ent:Health() + 666)
	damage:SetAttacker(IsValid(ply) and ply or self)
	damage:SetInflictor(IsValid(self.Inflictor) and self.Inflictor or self)
	damage:SetDamageForce(self:GetForward()*40000 + ent:GetUp()*20000)
	damage:SetDamagePosition(ent:WorldSpaceCenter())
	damage:SetDamageType(DMG_MISSILEDEFENSE)

	if ent.NZBossType then
		damage:SetDamage(math.max(1000, ent:GetMaxHealth() / 10))
	end

	ent:TakeDamageInfo(damage)

	if (ent:IsNPC() or ent:IsNextBot()) and IsValid(ply) and ply:IsPlayer() then
		if not self.Kills then self.Kills = 0 end

		self.Kills = self.Kills + 1
		if self.Kills == 10 then
			if not ply.bo2flingerachievment then
				TFA.BO3GiveAchievement("Vertigoner", "vgui/overlay/achievment/Vertigoner.png", ply)
				ply.bo2flingerachievment = true
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
