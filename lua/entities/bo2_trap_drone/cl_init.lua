
include("shared.lua")

local sv_cheats = GetConVar("sv_cheats")
local host_timescale = GetConVar("host_timescale")

local vecKick = Vector( 1.2, 0, 0 )

local angDroneRest = Angle( 40, 0, 0 )
local angDroneMoving = Angle( 75, 0, 0 )

local GlowMat = Material("sprites/glow04_noz_gmod.vmt")
local BrainGlowMat = Material("sprites/blueflare1_noz_gmod.vmt")

function ENT:Draw()
	self:DrawModel()

	// ammo belt jiggle
	local ammo1 = self:LookupBone("tag_antenna1")
	local ammo2 = self:LookupBone("tag_antenna2")

	if ammo1 then
		self:ManipulateBoneJiggle( ammo1, 1 )
	end
	if ammo2 then
		self:ManipulateBoneJiggle( ammo2, 1 )
	end

	// lights
	if ( !self.Light or !IsValid( self.Light ) ) and ( !self:GetDestroyed() or self.DestroyedFlicker ) then
		self.Light = CreateParticleSystem( self, "bo2_maxisdrone_light", PATTACH_ABSORIGIN_FOLLOW, 1 )
	elseif IsValid( self.Light ) and self:GetDestroyed() and !self.DestroyedFlicker then
		self.Light:StopEmissionAndDestroyImmediately()
		self.Light = NULL
	end

	if !self.Lamp then
		local lamp1 = ProjectedTexture()
		self.Lamp = lamp1

		lamp1:SetTexture( "effects/flashlight001" )
		lamp1:SetFarZ( 512 )
		lamp1:SetFOV( 54 )

		lamp1:SetPos( self:GetPos() + self:GetForward() * 16 )
		lamp1:SetAngles( self:GetAngles() )
		lamp1:SetColor( self.SoftGlowColor )
		lamp1:Update()
	end

	local origin = self:LookupBone("origin_animate_jnt")
	if origin and ( !self:GetDestroyed() or self.DestroyedFlicker ) then
		local matrix = self:GetBoneMatrix( origin )
		if matrix then
			local position = matrix:GetTranslation()
			local direction = matrix:GetAngles():Forward()

			local randXY = math.Rand( 16, 18 )

			render.SetMaterial( BrainGlowMat )
			render.DrawSprite( position + ( direction * 10 ) - ( self:GetUp() * 5 ), randXY, randXY, self.GlowColor )

			render.SetMaterial( GlowMat )
			render.DrawSprite( position - ( direction * 7.3 ) - ( self:GetUp() * 5 ), 8, 8, self.LightGlowColor )
			render.DrawSprite( position - ( direction * 5.4 ) - ( self:GetUp() * 5 ), 8, 8, self.LightGlowColor )
			render.DrawSprite( position - ( direction * 3.5 ) - ( self:GetUp() * 5 ), 8, 8, self.LightGlowColor )
		end
	end
end

function ENT:Initialize()
	self.drone_spark_wait = CurTime() + math.Rand( 0.5, 2 )
	self.current_move_ratio = 0
	self.next_random_jerk = CurTime() + math.Rand( 0.5, 3.5 )
	self.current_jerk = Angle( 0, 0, 0 )

	self.next_nearest_perk = CurTime()

	self.DestroyedTime = math.huge
	self.DestroyedFlicker = false

	self.flicker_wait = 0

	if !TFA.MaxisInitialSpawn then
		TFA.MaxisInitialSpawn = true

		timer.Simple( 0.5, function()
			if !IsValid( self ) or !self.MaxisVoxTable["Initial_A"] then return end

			self:EmitSound( self.MaxisVoxTable["Initial_A"]["vox"], SNDLVL_NORM, 100, 1, CHAN_VOICE2 )

			timer.Create( "MaxisDrone.VoxSchedule", 10.5, 1, function()
				if !IsValid( self ) or !self.MaxisVoxTable["Initial_B"] then return end

				self:EmitSound( self.MaxisVoxTable["Initial_B"]["vox"], SNDLVL_NORM, 100, 1, CHAN_VOICE2 )

				timer.Remove( "MaxisDrone.VoxSchedule" )
			end )
		end )
	end
end

function ENT:Think()
	if self.next_nearest_perk < CurTime() then
		self.next_nearest_perk = CurTime() + 2.5

		local perks = ents.FindByClass("perk_machine")
		if not table.IsEmpty( perks ) then
			local pos = self:GetPos()
			table.sort( perks, function(a, b) return a:GetPos():DistToSqr( pos ) < b:GetPos():DistToSqr( pos ) end )

			local nearperk = perks[1]
			self.nearestperk = tostring( nzPerks:Get( nearperk:GetPerkID() ).name )
		end
	end

	self:LightsThink()

	self:SoundThink()

	self:Targeting()

	self:Blowback()

	self:TrailThink()

	self:SetNextClientThink( CurTime() )
	return true
end

function ENT:Attack( endpos )
	local muzzle = self:GetAttachment( 1 )
	if isvector( endpos ) and not endpos:IsZero() and muzzle and muzzle.Pos then
		local tracer = CreateParticleSystem( self, "bo2_mowerturret_tracer", PATTACH_POINT_FOLLOW, 1 )
		if IsValid( tracer ) then
			tracer:SetControlPoint( 0 , muzzle.Pos )
			tracer:SetControlPoint( 1 , endpos )
		end
	end

	self.BlowbackCurrent = 1

	self.LastAttack = CurTime()

	if !self.ShootingLoopSound then
		self.ShootingLoopSound = true
		self:EmitSound( self:GetUpgraded() and "TFA_BO2_ZMDRONE.Shoot.Upg" or "TFA_BO2_ZMDRONE.Shoot" )
	end

	sound.Play( "weapons/tfa_bo2/drone/dist_00.wav", self:GetPos(), SNDLVL_GUNFIRE, math.random( 97, 103 ), 0.5 )

	ParticleEffectAttach( "bo2_maxisdrone_muzzleflash", PATTACH_POINT_FOLLOW, self, 1 )

	ParticleEffectAttach( "tfa_ins2_shell_eject", PATTACH_POINT_FOLLOW, self, 2 )

	if DynamicLight and muzzle and muzzle.Pos then
		self.dlight = self.dlight or DynamicLight( self:EntIndex() )
		if ( self.dlight ) then
			self.dlight.pos = muzzle.Pos
			self.dlight.dir = muzzle.Ang:Forward()
			self.dlight.r = 255 * 0.7
			self.dlight.g = 240 * 0.7
			self.dlight.b = 128 * 0.7
			self.dlight.brightness = 0
			self.dlight.Decay = 5000
			self.dlight.Size = 256 + 128
			self.dlight.DieTime = CurTime() + 0.2
		end
	end

	local brass = self:GetAttachment( 2 )
	if not brass or not brass.Pos then
		return
	end

	local fx = EffectData()
	fx:SetOrigin( brass.Pos )
	fx:SetAngles( brass.Ang )
	fx:SetFlags( 20 )

	util.Effect( "EjectBrass_556", fx )
end

function ENT:SoundThink()
	if self:GetDestroyed() then
		if self.IdleLoopSound and self.IdleLoopSound:IsPlaying() then
			self.IdleLoopSound:Stop()
		end
		if self.HumLoopSound and self.HumLoopSound:IsPlaying() then
			self.HumLoopSound:Stop()
		end
		if self.DamagedLoopSound and self.DamagedLoopSound:IsPlaying() then
			self.DamagedLoopSound:Stop()
		end

		if self.DestroyedTime and self.DestroyedTime + 9 > CurTime() then
			// destroyed and burning
			if !self.BurningLoopSound or !self.BurningLoopSound:IsPlaying() then
				self:EmitSound( "NZ.Tomb.Torch.Ignite" )

				self.BurningLoopSound = CreateSound( self, "NZ.Tomb.Torch.Loop" )
				self.BurningLoopSound:PlayEx( 1, math.random( 97, 103 ) )
			end
		elseif self:GetMoveType() == MOVETYPE_NONE then
			// has been dead on the ground long enough
			if self.BurningLoopSound and self.BurningLoopSound:IsPlaying() then
				self.BurningLoopSound:Stop()

				self:EmitSound( "NZ.Tomb.Torch.Putout" )
			end
		end
	else
		if self.BurningLoopSound and self.BurningLoopSound:IsPlaying() then
			self.BurningLoopSound:Stop()
		end

		if self:Health() <= 0 then
			// auger death spiral loop
			if self.HumLoopSound and self.HumLoopSound:IsPlaying() then
				self.HumLoopSound:Stop()
			end
			if !self.DamagedLoopSound or !self.DamagedLoopSound:IsPlaying() then
				self.DamagedLoopSound = CreateSound( self, "TFA_BO2_ZMDRONE.Damaged" )
				self.DamagedLoopSound:PlayEx( 1, math.random( 97, 103 ) )
			end
		else
			if self.DamagedLoopSound and self.DamagedLoopSound:IsPlaying() then
				self.DamagedLoopSound:Stop()
			end

			// default looping sounds
			if !self.IdleLoopSound or !self.IdleLoopSound:IsPlaying() then
				self.IdleLoopSound = CreateSound( self, "TFA_BO2_ZMDRONE.Idle" )
				self.IdleLoopSound:PlayEx( 1, math.random( 97, 103 ) )
			end
			if !self.HumLoopSound or !self.HumLoopSound:IsPlaying() then
				self.HumLoopSound = CreateSound( self, "TFA_BO2_ZMDRONE.Hum" )
				self.HumLoopSound:PlayEx( 1, math.random( 97, 103 ) )
			end
		end
	end
end

function ENT:Targeting()
	if self:GetDestroyed() then return end

	local ft = RealFrameTime() * game.GetTimeScale() * (sv_cheats:GetBool() and host_timescale:GetFloat() or 1)
	local flRate = ( self.TurnRate * ft )
	local target = self:GetTarget()

	if IsValid( target ) then
		// activated and tracking our target

		self.CurrentSweep = math.abs( math.sin( CurTime() * 2.4 ) )

		local muzzle = self:GetAttachment(1)
		local aimbone = self:LookupBone("tag_barrel")

		if aimbone and muzzle and muzzle.Pos then
			local hitbone = target:LookupBone("ValveBiped.Bip01_Neck")
			if !hitbone then
				hitbone = target:LookupBone("j_neck")
			end

			local vecFinal = target:EyePos()
			if hitbone then
				local matrix = target:GetBoneMatrix( hitbone )
				if matrix then
					vecFinal = matrix:GetTranslation()
				end
			end

			local vecToTarget = ( vecFinal - muzzle.Pos ):GetNormalized()
			vecToTarget:SetUnpacked( vecToTarget[1], vecToTarget[2], 0 )

			local vecDirection = self:GetForward()
			vecDirection:SetUnpacked( vecDirection[1], vecDirection[2], 0 )

			local flDot = vecDirection:Dot( vecToTarget )

			if flDot > 0.86 then
				local vecSweep = Lerp( self.CurrentSweep, target:GetPos(), vecFinal )

				local angStart = self:GetManipulateBoneAngles( aimbone )
				local angFinal = WorldToLocal( vecSweep, Angle( 0, 0, 0 ), muzzle.Pos, self:GetAngles() ):Angle()
				angFinal:SetUnpacked( angFinal[1], 0, 0 )

				local angCurrent = LerpAngle( flRate, angStart, angFinal )

				self:ManipulateBoneAngles( aimbone, angCurrent )

				self.next_random_jerk = CurTime() + math.Rand( 1, 2.5 )
			end
		end
	else
		// stop shooting
		if self.ShootingLoopSound then
			self.ShootingLoopSound = false
			self:StopSound( self:GetUpgraded() and "TFA_BO2_ZMDRONE.Shoot.Upg" or "TFA_BO2_ZMDRONE.Shoot" )
			self:EmitSound( self:GetUpgraded() and "TFA_BO2_ZMDRONE.Decay.Upg" or "TFA_BO2_ZMDRONE.Decay" )
		end

		// activated and returning to default pose
		local aimbone = self:LookupBone("tag_barrel")

		if aimbone then
			local angStart = self:GetManipulateBoneAngles( aimbone )
			local angDesired = Angle( angDroneRest )

			if self.next_random_jerk < CurTime() then
				self.next_random_jerk = CurTime() + math.Rand( 0.5, 3.5 )
				self.current_jerk = Angle( math.Rand( -8, 8 ), 0, 0 )
			end

			angDesired:Add( self.current_jerk )

			// cheap way of detecting movement
			if self:GetAngles().p > 6 then
				self.current_move_ratio = math.Approach( self.current_move_ratio, 1, 4 * ft )
			elseif self.current_move_ratio > 0 then
				self.current_move_ratio = math.Approach( self.current_move_ratio, 0, 4 * ft )
			end

			if self.current_move_ratio > 0 then
				// TODO: use a variable thats reset and increases only when moving, as curtime causes an initial jitter b/c of time difference

				local flSway = math.sin( CurTime() * 2 * math.ease.InCirc( self.current_move_ratio ) )

				angDesired = LerpAngle( self.current_move_ratio, angDroneRest, angDroneMoving + Angle( 6 * flSway, 0, 0 ) )
			end

			if angStart ~= angDesired then
				local angCurrent = LerpAngle( flRate, angStart, angDesired )

				self:ManipulateBoneAngles( aimbone, angCurrent )
			end
		end
	end
end

function ENT:Blowback()
	local ft = RealFrameTime() * game.GetTimeScale() * (sv_cheats:GetBool() and host_timescale:GetFloat() or 1)

	if self.BlowbackCurrent > 0.01 then
		// fake firing animation

		local aimbone = self:LookupBone("tag_barrel")
		if aimbone then
			local matrix = self:GetBoneMatrix( aimbone )
			if matrix then
				local flRatio = self.BlowbackCurrent
				self:ManipulateBonePosition( aimbone, vecKick * flRatio )
			end
		end
	end

	if self.BlowbackCurrent > 0 or self.BlowbackCurrent > 0 then
		self.BlowbackCurrent = math.Approach( self.BlowbackCurrent, 0, self.BlowbackCurrent * ft * ( self.RPM / 60 ) )
	end
end

function ENT:LightsThink()
	if self:GetDestroyed() then
		local flFixTPS = ( 66 / ( 1 / engine.TickInterval() ) )

		if self.DestroyedFlicker and self.flicker_wait < CurTime() then
			self.DestroyedFlicker = false
		end

		local flMult = 0
		if self.DestroyedTime and self.DestroyedTime + 5 < CurTime() then
			flMult = 1 - math.Clamp( ( ( self.DestroyedTime + 15 ) - CurTime() ) / 10 , 0, 1 )
		end

		if !self.DestroyedFlicker then
			self.DestroyedFlicker = math.random( ( 30 / flFixTPS ) + ( ( 120 / flFixTPS ) * flMult ) ) == 1

			if self.DestroyedFlicker then
				local flTime = math.Rand( 0, 0.12 )
				if math.random( 4 ) == 1 then
					flTime = flTime * ( math.random( 2 ) == 1 and math.Rand( 1, 3 ) or 2 )
				end

				self.flicker_wait = CurTime() + flTime
			end
		end
	end

	if ( !self:GetDestroyed() or self.DestroyedFlicker ) and self.drone_spark_wait and self.drone_spark_wait < CurTime() then
		ParticleEffect( "bo2_turbine_spark", self:GetPos(), Angle(0,0,0) )

		self.drone_spark_wait = CurTime() + math.Rand( 0.5, 2 )
	end

	if self.Lamp and ( IsValid( self.Lamp ) ) then
		self.Lamp:SetPos( self:GetPos() + self:GetForward() * 16 )
		self.Lamp:SetAngles( self:GetAngles() )

		if self:GetDestroyed() then
			if self.DestroyedFlicker then
				self.Lamp:SetFarZ( 512 )
				self.Lamp:SetFOV( 54 )
			else
				self.Lamp:SetFarZ( 0 )
				self.Lamp:SetFOV( 0 )
			end
		end

		self.Lamp:Update()
	end

	if DynamicLight and self.dlight and self.dlight.DieTime then
		local muzzle = self:GetAttachment( 1 )
		if self.dlight.DieTime > CurTime() and muzzle and muzzle.Pos then
			self.dlight.pos = muzzle.Pos
			self.dlight.dir = muzzle.Ang:Forward()
		end
	end
end

function ENT:TrailThink()
	local nLifeState = self:GetInternalVariable( "m_lifeState" )

	local desired_trail = nil

	if self:Health() > ( self:GetMaxHealth() / 2 ) and IsValid( self.Trail ) then
		// were healthy again (somehow)
		self.Trail:StopEmissionAndDestroyImmediately()
		self.Trail = NULL

	elseif self:Health() <= 0 then
		// auger death spiraling
		if !self:GetDestroyed() then
			desired_trail = "bo2_maxisdrone_dead_trail"
		end

	elseif self:Health() < 45 then
		desired_trail = "bo2_maxisdrone_dying_trail"

	elseif self:Health() < ( self:GetMaxHealth() / 4 ) then
		desired_trail = "bo2_maxisdrone_critical_trail"

	elseif self:Health() < ( self:GetMaxHealth() / 3 ) then
		desired_trail = "bo2_maxisdrone_damaged_trail"

	end

	if self.DestroyedTime and self.DestroyedTime + 15 < CurTime() then
		if IsValid( self.Trail ) then
			self.Trail:StopEmission()
			self.Trail = NULL
		end

	elseif desired_trail ~= nil then
		if ( !self.Trail or !IsValid( self.Trail ) ) then
			self.Trail = CreateParticleSystem( self, desired_trail, PATTACH_ABSORIGIN_FOLLOW, 1 )
		end

		if ( IsValid( self.Trail ) and self.Trail:GetEffectName() ~= desired_trail ) then
			self.Trail:StopEmissionAndDestroyImmediately()
			self.Trail = NULL
		end
	end
end

function ENT:GetNZTargetText()
	local ply = self:GetOwner()
	if LocalPlayer() == ply then
		return "Press "..string.upper(input.LookupBinding("+USE")).." - pickup Maxis Drone"
	else
		return ply:Nick().."'s - Maxis Drone"
	end
end

function ENT:IsTranslucent()
	return true
end