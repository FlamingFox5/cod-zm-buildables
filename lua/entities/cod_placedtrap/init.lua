
AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

util.AddNetworkString("TFA.BO2.Buildable.Attack")

DEFINE_BASECLASS( "base_anim" )

function ENT:Initialize()
	if self.BuildableMinBounds and self.BuildableMaxBounds then
		self:PhysicsInitBox(self.BuildableMinBounds, self.BuildableMaxBounds, self.SurfaceType or "Metal")
	else
		self:PhysicsInit(SOLID_VPHYSICS)
	end

	self:SetMoveType(MOVETYPE_NONE)
	self:SetSolid(SOLID_VPHYSICS)

	self:SetUseType(CONTINUOUS_USE)
	self:SetCollisionGroup(COLLISION_GROUP_WORLD)
	self:SetTrigger(true)

	self:EmitSound("TFA_BO2_SHIELD.Plant")

	self:SetDestroyed(false)
	self:SetActivated(false)

	local strTimerLoop = "NZ.BuildableTrap.FloorCheck." .. self:EntIndex()
	self.FloorCheckTimer = strTimerLoop
	timer.Create( strTimerLoop, 0, 0, function()
		if not IsValid( self ) then
			timer.Remove( strTimerLoop )
			return
		end

		self:FloorCheck()
	end )

	self:CallOnRemove( "NZ.BuildableTrap.Destroyed." .. self:EntIndex(), function( entity )
		if not IsValid( entity ) then
			return
		end

		if entity.GetDestroyed and entity:GetDestroyed() then
			local fx = EffectData()
			fx:SetEntity( entity )
			fx:SetOrigin( entity:WorldSpaceCenter() )
			fx:SetNormal( entity:GetUp() )
			fx:SetScale( 25 )

			util.Effect( "cball_explode", fx )
			util.Effect( "HelicopterMegaBomb", fx )

			sound.Play( "TFA_BO2_SHIELD.Break", entity:WorldSpaceCenter(), SNDLVL_TALKING, math.random(97, 103), 0.5 )
		end

		local ply = entity:GetOwner()
		if nzombies and IsValid( ply ) and ply:IsPlayer() then
			ply:RemoveBuildable( entity )
		end

		util.ScreenShake( entity:GetPos(), 5, 10, 0.5, 150 )

		if entity.bRequiresTurbine or entity.bCanUseTurbine then
			for _, turbine in pairs(ents.FindByClass("bo2_trap_turbine")) do //PLEASE DO THIS SPARINGLY, THANKYOU
				if turbine:GetActivated() and turbine.localpower then
					for i = 1, #turbine.localpower do
						local powered = turbine.localpower[ i ]
						if IsValid( powered ) and powered:EntIndex() == entity:EntIndex() then
							table.remove( turbine.localpower, i )
						end
					end
				end
			end
		end

		if entity.FloorCheckTimer and timer.Exists( entity.FloorCheckTimer ) then
			timer.Remove( entity.FloorCheckTimer )
		end
	end )

	if self.bRequiresTurbine or self.bCanUseTurbine then
		for k, v in pairs(ents.FindByClass("bo2_trap_turbine")) do //PLEASE DO THIS SPARINGLY, THANKYOU
			if v:GetActivated() then
				v:TurbinePowerUpdate()
			end
		end
	end

	if nzombies then
		local count = 0
		for k, v in ipairs(ents.FindByClass(self:GetClass())) do
			if v:GetOwner() == self:GetOwner() and v ~= self then
				if #player.GetAllPlaying() <= 1 then
					if count >= 1 then
						v:SetHealth(1)
						v:TakeDamage(666, self, self)
						continue
					end

					count = count + 1
				else
					v:SetHealth(1)
					v:TakeDamage(666, self, self)
				end
			end
		end
	end

	local ply = self:GetOwner()
	if IsValid(ply) then
		if nzombies and ply:IsPlayer() then
			timer.Simple(0, function()
				if not IsValid( ply ) or not IsValid( self ) then return end
				ply:AddBuildable( self )
			end)
		end

		ply.NextTrapUse = CurTime() + 0.35 //use delay

		if not util.IsInWorld( self:GetPos() ) then
			self:SetPos( ply:GetPos() ) //plz dont get stuck in walls

			if self.BuildableWallPlaceable and self:GetUp().z < 0 then
				self:SetAngles( ply:GetForward() )
			end
		end
	end

	if not IsValid( self:GetParent() ) then
		self:DropToFloor()
	end
end

function ENT:Use(ply)
	if CLIENT then return end
	if self:GetDestroyed() then return end
	if not IsValid(ply) then return end
	if not nzombies and ply ~= self:GetOwner() then return end
	if ply.NextTrapUse and ply.NextTrapUse > CurTime() then return end

	local own = self:GetOwner()
	if nzombies and IsValid(own) and own:IsPlayer() 
		and ply ~= own and own:GetInfoNum("nz_buildable_sharing", 0) < 1 then
		return
	end

	if not ply:HasWeapon(self:GetTrapClass()) then
		ply.NextTrapUse = CurTime() + 0.25

		local weapon = ply:Give( self:GetTrapClass() )
		if IsValid( weapon ) then
			local flRatio = math.Clamp( self:Health() / self:GetMaxHealth(), 0, 1 )
			weapon:SetClip1( math.Round( flRatio * weapon:GetStatL("Primary.ClipSize") ) )
		end

		self:EmitSound("TFA_BO2_SHIELD.Pickup")
		self:Remove()
	end
end

function ENT:OnTakeDamage(dmginfo)
	local attacker = dmginfo:GetAttacker()
	if not IsValid(attacker) then return end
	if nzombies and attacker:IsPlayer() then return end

	local damage = dmginfo:GetDamage()

	local ply = self:GetOwner()
	if nzombies and IsValid(ply) and ply.HasPerk and ply:HasPerk("tortoise") then
		damage = damage * 0.5
	end

	self:SetHealth(self:Health() - dmginfo:GetDamage())

	if self:Health() <= 0 then
		if IsValid(ply) then
			ply:EmitSound("TFA_BO2_SHIELD.Break")
		end

		self:SetDestroyed(true)
		self:Remove()
	end
end

local MOVE_TOGGLE_NONE = 0
local MOVE_TOGGLE_LINEAR = 1

local t_MovetypeIgnore = {
	[MOVETYPE_PUSH] = true,
	[MOVETYPE_NONE] = true,
}

local color_red = Color(255, 0, 0, 0)

local vector_down = Vector( 0, 0, -1 )
local vector_down_256 = Vector( 0, 0, -256 )
local vecOffset = Vector( 0, 0, 4 )

local function IsValidToPlaceOn( entity, bHitWorld )
	if not IsValid( entity ) then
		if bHitWorld then
			return true
		end
		return false
	end

	if entity:IsWorld() or bHitWorld then
		return true
	end

	if entity:IsVehicle() then
		return true
	end

	if entity.GetPhysicsObject and !t_MovetypeIgnore[ entity:GetMoveType() ] then
		local phys = entity:GetPhysicsObject()
		if IsValid( phys ) and phys:IsMotionEnabled() then
			return false
		end

		if entity:GetMoveType() == MOVETYPE_VPHYSICS then
			return false
		end
	end

	if entity:GetMoveType() == MOVETYPE_PUSH then
		local nMoveType = entity:GetInternalVariable( "m_movementType" )
		if nMoveType and nMoveType == MOVE_TOGGLE_LINEAR then
			return false
		end

		if string.find( entity:GetClass(), "_door_rotating" ) then
			return false
		end
	end

	if entity:IsNPC() or entity:IsPlayer() or entity:IsNextBot() then
		return false
	end

	if IsValid( entity:GetOwner() ) and entity:GetOwner():IsPlayer() then
		return false
	end

	if nzombies and nzLevel and nzLevel.InvalidPlaceableClasses and nzLevel.InvalidPlaceableClasses[ entity:GetClass() ] then
		return false
	end

	return entity:IsSolid()
end

function ENT:FloorCheck()
	local hParent = self:GetParent()

	if not IsValid( hParent ) and !self.bIsBeingBlocked then
		return
	end

	local vecDirection = vector_down

	if IsValid( hParent ) then
		local hMoveParent = hParent:GetMoveParent()
		if hParent:GetMoveType() ~= MOVETYPE_PUSH or ( IsValid( hMoveParent ) and hMoveParent ~= MOVETYPE_PUSH ) then
			return
		end

		local nMoveType = hParent:GetInternalVariable( "m_movementType" )
		if nMoveType and nMoveType == MOVE_TOGGLE_NONE then
			return
		end

		local vecMoveDir = hParent:GetInternalVariable( "m_vecMoveDir" )
		if IsValid( hMoveParent ) and ( !vecMoveDir or vecMoveDir:IsZero() ) then
			vecMoveDir = hMoveParent:GetInternalVariable( "m_vecMoveDir" )
		end

		if vecMoveDir and !vecMoveDir:IsZero() then
			vecDirection = vecMoveDir
		end
	end

	local vecMins, vecMaxs = self:GetCollisionBounds()
	local vecStart = self:GetPos() + vecOffset
	local flProbeDist = self.BuildableWallOffset or math.Clamp( math.max( vecMaxs[1], vecMaxs[2] ), 4, 24 )
	local trace = {}

	local mFilter = { self, self:GetOwner() }
	table.Add( mFilter, player.GetAll() )

	debugoverlay.Axis( self:WorldSpaceCenter(), vecDirection:Angle(), 10, FrameTime()*2, true )

	util.TraceLine( {
		start = vecStart,
		endpos = vecStart + ( vecDirection * flProbeDist ),
		mask = MASK_PLAYERSOLID,
		filter = mFilter,
		output = trace,
	} )

	debugoverlay.Line( trace.StartPos, vecStart + ( vecDirection * flProbeDist ), FrameTime()*2, trace.Hit and color_red or color_white, true )

	if IsValid( hParent ) then
		self.LastParent = hParent
	end

	local hitEntity = trace.Entity
	if hitEntity ~= self.LastParent then
		if trace.HitWorld then
			local vecPos = trace.HitPos + trace.HitNormal
			local vecAng = Angle( 0, self:GetAngles()[2], 0 )
			local flDot = trace.HitNormal:Dot( vector_up )

			self:SetParent( NULL )

			if ( flDot <= 0.5 ) and ( flDot >= -0.1 ) then
				vecAng = Angle( 0, trace.HitNormal:Angle()[2], 0 )
				vecPos = trace.HitPos + vecAng:Forward() * flProbeDist
			end

			self:SetPos( vecPos )
			self:SetAngles( vecAng )

			self:DropToFloor()

			self:EmitSound( "TFA_BO2_SHIELD.Plant" )

			self.bIsBeingBlocked = false
		else
			local vecPos = trace.HitPos + Angle( 0, trace.HitNormal:Angle()[2], 0 ):Forward() * flProbeDist
			local vecAng = Angle( 0, self:GetAngles()[2], 0 )

			table.insert( mFilter, trace.Entity )

			util.TraceLine( {
				start = vecPos,
				endpos = vecPos + ( vector_down_256 ),
				mask = MASK_PLAYERSOLID,
				filter = mFilter,
				output = trace,
			} )

			debugoverlay.Line( trace.StartPos, trace.HitPos, FrameTime()*2, trace.Hit and color_red or color_white, true )

			vecStart = self:GetPos()

			if IsValid( hParent ) then
				self:SetParent( NULL )
			end

			if trace.Hit then
				if trace.Entity ~= self.LastParent then
					vecPos = trace.HitPos + trace.HitNormal*0.5

					self:SetPos( vecPos )
					self:SetAngles( vecAng )

					if trace.HitWorld then
						self:DropToFloor()
					elseif IsValidToPlaceOn( trace.Entity, false ) then
						self:SetParent( trace.Entity )
					end

					self:EmitSound( "TFA_BO2_SHIELD.Plant" )

					self.bIsBeingBlocked = false
				else
					self.bIsBeingBlocked = true
				end
			else
				self:SetPos( vecStart )
				self:SetAngles( vecAng )

				self:SetHealth(1)
				self:TakeDamage(666, self, self)

				if self.FloorCheckTimer and timer.Exists( self.FloorCheckTimer ) then
					timer.Remove( self.FloorCheckTimer )
				end
			end
		end
	end
end
