
AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

include("shared.lua")

DEFINE_BASECLASS( ENT.Base )

local nzombies = engine.ActiveGamemode() == "nzombies"

local angMowerRest = Angle( -45, 0, 0 )

function ENT:Initialize()
	BaseClass.Initialize( self )

	self:EmitSound("TFA_BO2_MOWER.Start")

	self:SetTurnRate( self.TurnRate )

	self.turret_activate_wait = CurTime() + 1
	self.turret_power_wait = CurTime() + math.random(8, 12)
end

function ENT:Think()
	local ply = self:GetOwner()
	local ct = CurTime()

	if not IsValid(ply) then
		self:SetHealth(1)
		self:TakeDamage(666, self, self)
		return false
	end

	if self.turret_power_wait < ct and ( !IsValid( self.Turbine ) or ( self.Turbine.GetActivated and !self.Turbine:GetActivated() ) ) then
		self:TurnOff()
		self.turret_activate_wait = ct + math.random(4, 6)
		self.turret_power_wait = self.turret_activate_wait + math.random(14, 20)
	end

	if not self:GetActivated() and self.turret_activate_wait < ct then
		self:TurnOn()
	end

	local flRate = ( self:GetTurnRate() * FrameTime() )
	if self:GetActivated() then
		local muzzle = self:GetAttachment( 1 )
		local aimbone = self:LookupBone( "tag_aim" )

		if muzzle and aimbone then
			local entity = self:GetTarget()

			if IsValid( entity ) then
				local vecToTarget = ( entity:WorldSpaceCenter() - muzzle.Pos ):GetNormalized()
				local vecDirection = self:GetForward()
				local flDot = vecDirection:Dot( vecToTarget )

				if flDot < 0.2 or entity:Health() < 0 or entity:GetNoDraw() or entity.Invulnerable or !self:Visible( entity ) then
					self:SetTarget( NULL )

					entity = NULL

					self.NextTargetAttempt = CurTime() + ( 60 / self.RPM )
				end
			end

			if ( !self.NextTargetAttempt or self.NextTargetAttempt < CurTime() ) then
				if ( self:GetNextAttack() < CurTime() ) then
					self:SetTarget( self:FindNearestEntity( muzzle.Pos ) )

					entity = self:GetTarget()

					if IsValid( entity ) then
						self.NextTargetAttempt = CurTime() + 2
					end
				end
			end

			if IsValid( entity ) and self:GetAttackDelay() < CurTime() then
				// activated and tracking our target

				local hitbone = entity:LookupBone( "ValveBiped.Bip01_Spine2" )
				if !hitbone then
					hitbone = entity:LookupBone( "j_spineupper" )
				end

				local vecFinal = entity:WorldSpaceCenter()
				if hitbone then
					local matrix = entity:GetBoneMatrix( hitbone )
					if matrix then
						vecFinal = matrix:GetTranslation()
					end
				end

				local angStart = self:GetManipulateBoneAngles( aimbone )
				local angFinal = WorldToLocal( vecFinal, angle_zero, muzzle.Pos, self:GetAngles() ):Angle()
				local angCurrent = LerpAngle( flRate, angStart, angFinal )

				self:ManipulateBoneAngles( aimbone, angCurrent, false ) // dont network to client

				muzzle = self:GetAttachment( 1 )

				local matrix = self:GetBoneMatrix( aimbone )
				local vecAimOrigin = matrix:GetTranslation()

				local vecToTarget = ( vecFinal - vecAimOrigin ):GetNormalized()
				local vecDirection = muzzle.Ang:Forward()
				local flDot = vecDirection:Dot( vecToTarget )

				//debugoverlay.Axis( muzzle.Pos, muzzle.Ang, 5, 1, true )
				//debugoverlay.Axis( vecAimOrigin, vecToTarget:Angle(), 5, 1, true )

				if ( self:GetNextAttack() < CurTime() ) and flDot > 0.96 then
					self:Attack( entity, muzzle )
					self:TakeDamage( math.random(5), entity, entity )

					local rapid = tobool( self.RapidFire )
					if nzombies and IsValid(ply) and ply:HasPerk("time") then
						rapid = true
					end

					self:SetNextAttack( CurTime() + ( 60 / ( rapid and self.RPMRapid or self.RPM ) ) )
				end
			else
				// activated and returning to default pose
				local aimbone = self:LookupBone("tag_aim")

				if aimbone then
					local angStart = self:GetManipulateBoneAngles( aimbone )
					if !angStart:IsZero() then
						local angCurrent = LerpAngle( flRate, angStart, angle_zero )

						self:ManipulateBoneAngles( aimbone, angCurrent, false )
					end
				end
			end
		end
	else
		if IsValid( self:GetTarget() ) then
			self:SetTarget( NULL )
		end

		if self:GetCreationTime() + 2 < CurTime() then
			// deactivated and returning to rest pose
			local aimbone = self:LookupBone("tag_aim")

			if aimbone then
				local angStart = self:GetManipulateBoneAngles( aimbone )
				if angStart ~= angMowerRest then
					local angCurrent = LerpAngle( flRate, angStart, angMowerRest )

					self:ManipulateBoneAngles( aimbone, angCurrent, false )
				end
			end
		end
	end

	self:NextThink( CurTime() )
	return true
end

function ENT:Attack( entity, muzzle )
	if not muzzle or not istable( muzzle ) then
		return
	end
	if not IsValid( entity ) then
		return
	end

	local ply = self:GetOwner()

	local bulletinfo = {
		Attacker = IsValid( ply ) and ply or self,
		Callback = function( attacker, trace, dmginfo )
			if CLIENT then return end

			dmginfo:SetDamageType( DMG_BULLET )

			local target = trace.Entity

			if nzombies and IsValid( target ) and target:IsValidZombie() then
				local round = nzRound:GetNumber() > 0 and nzRound:GetNumber() or 1
				local health = tonumber( nzCurves.GenerateHealthCurve( round ) )
				local rand = math.random( 6, 12 )

				dmginfo:SetDamage( math.max( 45, health / rand ) )

				if target.NZBossType or string.find( target:GetClass(), "nz_zombie_boss" ) then
					local rand = math.random( 40, 60 )
					dmginfo:SetDamage( math.max( 15, target:GetMaxHealth() / rand ) )
				end

				if math.random( 2 ) == 1 then
					target:EmitSound( "TFA_BO3_GENERIC.Gib" )
				end
			end

			if IsValid( target:GetOwner() ) and ( target:GetOwner() == attacker or ( nzombies and target:GetOwner():IsPlayer() ) ) then
				dmginfo:ScaleDamage( 0 )
			end

			local filter = RecipientFilter()
			filter:AddPVS( muzzle.Pos )

			net.Start( "TFA.BO2.Buildable.Attack" )
				net.WriteEntity( dmginfo:GetInflictor() )
				net.WriteVector( trace.HitPos )
			net.Send( filter:GetPlayers() )
		end,
		Damage = entity:IsPlayer() and 25 or 45,
		Force = 20,
		Num = ( IsValid( ply ) and ply.HasPerk ) and ply:HasPerk( "dtap2" ) and 2 or 1,
		Tracer = 0,
		Src = muzzle.Pos,
		Dir = muzzle.Ang:Forward(),
		Spread = Vector( 0.04, 0.04, 0.04 ),
		IgnoreEntity = self,
	}

	self:FireBullets( bulletinfo )
end

function ENT:TargetVisisble( entity, position )
	if not IsValid( entity ) then
		return false
	end

	local trace = {}

	util.TraceLine({
		start = position,
		endpos = entity:WorldSpaceCenter(),
		mask = MASK_SHOT,
		filter = { self, self:GetOwner() },
		output = trace,
	})

	//debugoverlay.Line( trace.StartPos, trace.HitPos, 1, color_white, true )

	return trace.Entity == entity
end

local t_SpeakingTerms = {
	[D_LI] = true,
	[D_NU] = true,
}

function ENT:FindNearestEntity( position )
	local nearbyents = {}
	local ply = self:GetOwner()

	for k, v in pairs( ents.FindInSphere( self:GetPos(), 450 ) ) do
		if v:IsNPC() or v:IsNextBot() or v:IsPlayer() then
			if nzombies and v:IsPlayer() then continue end
			if v == ply then continue end

			if v:Health() <= 0 then continue end
			if v.Alive and not v:Alive() then continue end
			if v.IsAlive and not v:IsAlive() then continue end
			if v.Invulnerable or v.BeingNuked then continue end
			if v.Disposition and ( t_SpeakingTerms[ v:Disposition( ply ) ] ) then continue end

			local vecToTarget = ( v:GetPos() - position ):GetNormalized()
			local vecForward = self:GetForward()
			local flDot = vecForward:Dot( vecToTarget )

			if flDot < 0.4 then continue end

			if not self:TargetVisisble( v, position ) then continue end

			table.insert( nearbyents, v )
		end
	end

	table.sort( nearbyents, function( a, b ) return a:GetPos():DistToSqr( position ) < b:GetPos():DistToSqr( position ) end )
	return nearbyents[ 1 ]
end

function ENT:TurnOn()
	if self:GetActivated() then return end
	self:SetActivated( true )
	self:SetAttackDelay( CurTime() + 1 )

	self:EmitSound( "TFA_BO2_MOWER.Loop" )

	if nzombies then
		self:SetTargetPriority( TARGET_PRIORITY_NONE )
		self:SetCollisionGroup( COLLISION_GROUP_WORLD )
	end
end

function ENT:TurnOff()
	if not self:GetActivated() then return end
	self:SetActivated(false)

	self:EmitSound( "TFA_BO2_MOWER.Stop" )
	self:StopSound( "TFA_BO2_MOWER.Loop" )

	if nzombies then
		self:SetTargetPriority( TARGET_PRIORITY_PLAYER )
		self:SetCollisionGroup( COLLISION_GROUP_PASSABLE_DOOR )
	end
end

// Legacy
function ENT:TurretOn()
	self:TurnOn()
end

function ENT:TurretOff()
	self:TurnOff()
end

function ENT:SetNextAttack( time )
	self.NextAttack = tonumber( time )
end

function ENT:GetNextAttack()
	return self.NextAttack
end
