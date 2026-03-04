
include("shared.lua")

local nzombies = engine.ActiveGamemode() == "nzombies"
local sv_cheats = GetConVar("sv_cheats")
local host_timescale = GetConVar("host_timescale")

local angMowerRest = Angle( -45, 0, 0 )

function ENT:Draw()
	self:DrawModel()

	if self:GetActivated() then
		if !self.pvslight1 or !IsValid(self.pvslight1)then
			self.pvslight1 = CreateParticleSystem(self, "bo2_mowerturret_leak", PATTACH_POINT_FOLLOW, 3)
		end
	else
		if self.pvslight1 and IsValid(self.pvslight1)then
			self.pvslight1:StopEmission()
		end
	end
end

function ENT:Think()
	local ft = RealFrameTime() * game.GetTimeScale() * (sv_cheats:GetBool() and host_timescale:GetFloat() or 1)
	local flRate = ( self:GetTurnRate() * ft )

	if self:GetCreationTime() + 0.5 > CurTime() then
		// initial placement
		local aimbone = self:LookupBone("tag_aim")
		if aimbone then
			local flRatio = math.Clamp( ( ( self:GetCreationTime() - CurTime() ) + 0.4 ) / 0.4, 0, 1 )
			self:ManipulateBoneAngles( aimbone, Angle( -45 * flRatio, 0, 0 ) )
		end
	elseif self:GetActivated() then
		local target = self:GetTarget()

		if IsValid( target ) and self:GetAttackDelay() < CurTime() then
			// activated and tracking our target

			local muzzle = self:GetAttachment(1)
			local aimbone = self:LookupBone("tag_aim")

			if aimbone and muzzle and muzzle.Pos then
				local hitbone = target:LookupBone("ValveBiped.Bip01_Spine2")
				if !hitbone then
					hitbone = target:LookupBone("j_spineupper")
				end

				local finalpos = target:WorldSpaceCenter()
				if hitbone then
					local matrix = target:GetBoneMatrix( hitbone )
					if matrix then
						finalpos = matrix:GetTranslation()
					end
				end

				local angFinal = WorldToLocal( finalpos, Angle( 0, 0, 0 ), muzzle.Pos, self:GetAngles() ):Angle()
				local angStart = self:GetManipulateBoneAngles( aimbone )
				local angCurrent = LerpAngle( flRate, angStart, angFinal )

				self:ManipulateBoneAngles( aimbone, angCurrent )
			end
		else
			// activated and returning to default pose
			local aimbone = self:LookupBone("tag_aim")

			if aimbone then
				local angStart = self:GetManipulateBoneAngles( aimbone )
				if !angStart:IsZero() then
					local angCurrent = LerpAngle( flRate, angStart, angle_zero )

					self:ManipulateBoneAngles( aimbone, angCurrent )
				end
			end
		end
	elseif self:GetCreationTime() + 2 < CurTime() then
		// deactivated and returning to rest pose
		local aimbone = self:LookupBone("tag_aim")

		if aimbone then
			local angStart = self:GetManipulateBoneAngles( aimbone )
			if angStart ~= angMowerRest then
				local angCurrent = LerpAngle( flRate, angStart, angMowerRest )

				self:ManipulateBoneAngles( aimbone, angCurrent )
			end
		end
	end

	if self.BlowbackCurrent > 0.01 then
		// fake firing animation

		local aimbone = self:LookupBone("tag_aim")
		if aimbone then
			local matrix = self:GetBoneMatrix( aimbone )
			if matrix then
				local flRatio = self.BlowbackCurrent
				local vecBBack = WorldToLocal( matrix:GetTranslation() + matrix:GetAngles():Forward(), Angle( 0, 0, 0 ), self:GetBonePosition( aimbone ) )
				vecBBack:Mul( -2 )
				if flRatio > 0.5 then
					local cuntas = math.Clamp( ( flRatio - 0.5 ) / 0.5, 0, 1 )

					vecBBack:Add( Vector( 0, 0, cuntas ) )
				end
				vecBBack:Mul( flRatio )

				self:ManipulateBonePosition( aimbone, vecBBack )
			end
		end
	end

	if self.BlowbackCurrent > 0 or self.BlowbackCurrent > 0 then
		self.BlowbackCurrent = math.Approach( self.BlowbackCurrent, 0, self.BlowbackCurrent * ft * 12 )
	end

	self:SetNextClientThink( CurTime() )
	return true
end

function ENT:Attack( endpos )
	if isvector( endpos ) and not endpos:IsZero() then
		local muzzle = self:GetAttachment(1)
		if muzzle and muzzle.Pos then
			local tracer = CreateParticleSystem( self, "bo2_mowerturret_tracer", PATTACH_POINT, 1 )
			if IsValid( tracer ) then
				tracer:SetControlPoint( 0 , muzzle.Pos )
				tracer:SetControlPoint( 1 , endpos )
			end
		end
	end

	self.BlowbackCurrent = 1

	self:EmitSound( "TFA_BO2_MOWER.Shoot" )
	self:EmitSound( "TFA_BO2_MOWER.Decay" )

	ParticleEffectAttach( "bo2_mowerturret_muzzleflash", PATTACH_POINT_FOLLOW, self, 1 )

	ParticleEffectAttach( "tfa_ins2_shell_eject", PATTACH_POINT_FOLLOW, self, 2 )

	local brass = self:GetAttachment(2)
	if not brass or not brass.Pos then
		return
	end

	local fx2 = EffectData()
	fx2:SetOrigin(brass.Pos)
	fx2:SetAngles(brass.Ang + Angle(-25,0,0))
	fx2:SetFlags(50)

	util.Effect("EjectBrass_556", fx2)
end

function ENT:GetNZTargetText()
	local ply = self:GetOwner()
	if LocalPlayer() == ply then
		return "Press "..string.upper(input.LookupBinding("+USE")).." - pickup Lawnmower Turret"
	else
		return ply:Nick().."'s - Turret"
	end
end

function ENT:IsTranslucent()
	return false
end
