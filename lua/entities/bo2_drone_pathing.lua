
AddCSLuaFile()

ENT.Base = "base_nextbot"
ENT.Spawnable = false

local developer = GetConVar("developer")
local nzombies = engine.ActiveGamemode() == "nzombies"
local sp = game.SinglePlayer()

local color_red = Color( 255, 0, 0, 255 )
local color_red_box = Color( 255, 0, 0, 0 )
local color_white_box = Color( 255, 255, 255, 0 )

local color_yellow = Color( 255, 255, 0, 255 )

local angMowerRest = Angle( 40, 0, 0 )

local vecOrbitOffset = Vector( 0, 0, 48 )

local bit_AND = bit.band
local bit_OR = bit.bor

local DRONE_TO_IDLE = 0 // default behavior
local DRONE_TO_FOLLOW_PLAYER = 1 // default behavior
local DRONE_TO_FOLLOW_TARGET = 2 // default behavior
local DRONE_TO_HOME_POSITION = 3 // special condition
local DRONE_TO_ORBIT_PLAYER = 4 // special condition
local DRONE_TO_PASSENGER = 5 // special condition
local DRONE_TO_SCRIPTED = 6 // external only

local t_EnumNames = {
	[DRONE_TO_IDLE] = "IDLE",
	[DRONE_TO_FOLLOW_PLAYER] = "FOLLOW PLAYER",
	[DRONE_TO_FOLLOW_TARGET] = "FOLLOW TARGET",
	[DRONE_TO_HOME_POSITION] = "TO HOME",
	[DRONE_TO_SCRIPTED] = "TO SCRIPTED",
}

local t_DroneStatus = {
	["idling"] = 1, // pathing finished and stationary
	["pathing"] = 2, // actively pathing
	["roaming"] = 3, // not an actual state, used subtick in certain behaviors for pathing
	["climbing"] = 4, // climbing a CNavLadder (not a func_ladder)
	["passenger"] = 5, // riding vehicle alongside player
}

local t_FollowEnums = {
	[DRONE_TO_FOLLOW_TARGET] = true,
	[DRONE_TO_FOLLOW_PLAYER] = true,
}

function ENT:Draw()
	if !developer or !developer:GetBool() then return end
	self:DrawModel()
end

function ENT:Initialize()
	self:SetModel( "models/Barney.mdl" )

	//self:SetNoDraw( true )
	self:DrawShadow( false )

	self:SetCollisionBounds( Vector( -18, -18, 0 ), Vector( 18, 18, 64 ) )
	self:SetSurroundingBounds( Vector( -18, -18, 0 ), Vector( 18, 18, 70 ) )

	self:AddFlags( FL_NOTARGET )
	self:AddEFlags( EFL_DONTBLOCKLOS )
	self:AddSolidFlags( FSOLID_NOT_SOLID )

	self:SetCollisionGroup( COLLISION_GROUP_IN_VEHICLE )

	if SERVER then
		self.loco:SetDeathDropHeight( 200 )
		self.loco:SetDesiredSpeed( 200 )
		self.loco:SetStepHeight( 40 )
		self.loco:SetJumpHeight( 400 )
		self.loco:SetJumpGapsAllowed( true )
		self.loco:SetClimbAllowed( true )

		self:SetFOV( 120 )
		self:SetMaxVisionRange( 2000 )
		self:SetSolidMask( MASK_NPCSOLID )

		self:SetKeyValue( "m_takedamage", "0" )
		self:SetKeyValue( "m_lifeState", "0" )

		self:SetMaxHealth( math.huge )

		SafeRemoveEntityDelayed( self, 0.1 )
	end

	self:SetHealth( math.huge )

	self:AddEFlags( CLIENT and bit_OR( EFL_NO_THINK_FUNCTION, EFL_FORCE_CHECK_TRANSMIT ) or EFL_FORCE_CHECK_TRANSMIT )
end

function ENT:OnTakeDamage( damageinfo )
	damageinfo:ScaleDamage( 0 )
	damageinfo:SetDamage( 0 )
	damageinfo:SetMaxDamage( 0 )
	damageinfo:SetBaseDamage( 0 )
	damageinfo:SetDamageBonus( 0 )
	damageinfo:SetAttacker( NULL )
	damageinfo:SetInflictor( NULL )
	damageinfo:SetWeapon( NULL )
	return true
end

function ENT:OnInjured( damageinfo )
	damageinfo:ScaleDamage( 0 )
	damageinfo:SetDamage( 0 )
	damageinfo:SetMaxDamage( 0 )
	damageinfo:SetBaseDamage( 0 )
	damageinfo:SetDamageBonus( 0 )
	damageinfo:SetAttacker( NULL )
	damageinfo:SetInflictor( NULL )
	damageinfo:SetWeapon( NULL )
	return true
end

function ENT:OnTraceAttack( damageinfo, dir, trace )
	damageinfo:ScaleDamage( 0 )
	damageinfo:SetDamage( 0 )
	damageinfo:SetMaxDamage( 0 )
	damageinfo:SetBaseDamage( 0 )
	damageinfo:SetDamageBonus( 0 )
	damageinfo:SetAttacker( NULL )
	damageinfo:SetInflictor( NULL )
	damageinfo:SetWeapon( NULL )
	return true
end

function ENT:CreatePathFollower( drone )
	if not IsValid( drone ) then
		SafeRemoveEntity( self )
		return
	end

	local action = drone.current_action
	local actionName = t_EnumNames[action] or "ERROR"
	debugoverlay.Text( self:EyePos() + vector_up * 5, actionName, 2 )

	local spot = self:GetPos()
	local target = drone:GetTarget()

	if action == DRONE_TO_FOLLOW_PLAYER then
		local ply = drone.current_player_goal
		if IsValid( ply ) and ply:Alive() then
			local vecOrigin = ply:GetPos()
			local nearest = navmesh.GetNearestNavArea( vecOrigin, false, 10, false )

			if IsValid( drone.revive_player ) and ply == drone.revive_player then
				if IsValid( nearest ) then
					local closest = 32767
					for i = 1, 6 do
						local test = nearest:GetRandomPoint()
						local distance = test:Distance( vecOrigin )
						if distance < closest then
							closest = distance
							spot = test

							debugoverlay.Cross( spot, 10, 5, color_red, true )
						end
					end
				else
					spot = vecOrigin
				end
			else
				if IsValid( nearest ) then
					drone.last_nav = nearest
				end

				local nearby = drone:FindFreeSpot( vecOrigin, 0, 256, 100, 100, true )
				if IsValid( nearby ) then
					debugoverlay.Cross( nearby:GetCenter(), 10, 5, color_red, true )

					local closest = 32767
					for i = 1, 10 do
						local test = nearby:GetRandomPoint()
						local distance = test:Distance( vecOrigin )
						if distance < closest then
							closest = distance
							spot = test
							debugoverlay.Cross( spot, 10, 5, color_white, true )
						end
					end
				end
			end
		else
			debugoverlay.Text( self:EyePos() + vector_up * 15, "INVALID PLAYER", 2 )

			if IsValid( target ) and ( target:IsNPC() and target:IsNextBot() ) and math.random( 2 ) == 1 then
				drone.current_action = DRONE_TO_FOLLOW_TARGET
				self:CreatePathFollower( drone )
			else
				print("DRONE PATHING FAILED '"..actionName.."'\nNO VALID PLAYER TO TARGET")
				drone.current_status = "idling"
				drone.current_action = DRONE_TO_IDLE

				self.PathingFailed = true
			end
			return
		end
	elseif action == DRONE_TO_FOLLOW_TARGET and IsValid( target ) then
		local vecOrigin = target:GetPos()
		local nearest = navmesh.GetNearestNavArea( vecOrigin, false, 600, true )
		if IsValid( nearest ) then
			drone.last_nav = nearest
		end

		local nearby = drone:FindFreeSpot( vecOrigin, 0, 128, 40, 40, true )
		if IsValid( nearby ) then
			local closest = 32767
			for i = 1, 10 do
				local test = nearby:GetRandomPoint()
				local distance = test:Distance( vecOrigin )
				if distance < closest then
					closest = distance
					spot = test

					debugoverlay.Cross( spot, 10, 5, color_white, true )
				end
			end
		end
	elseif action == DONE_TO_IDLE then

		if drone.current_status == "roaming" then
			debugoverlay.Text( self:EyePos() + vector_up * 15, "ROAMING", 2 )

			spot = drone.current_roam_position
		else
			self.PathingFailed = true
			return
		end

	elseif action == DRONE_TO_HOME_POSITION then

		spot = drone:GetHomePosition( true )

	elseif action == DRONE_TO_SCRIPTED then
		if drone.current_scripted_goal then
			if isvector( drone.current_scripted_goal ) then
				spot = drone.current_scripted_goal
			elseif IsValid( drone.current_scripted_goal ) then
				spot = drone.current_scripted_goal:GetPos()
			else
				debugoverlay.Text( self:EyePos() + vector_up * 15, "SCRIPTED FAILED", 2 )

				drone.current_status = "idling"
				drone.current_action = DRONE_TO_IDLE

				self.PathingFailed = true
				return
			end
		else
			debugoverlay.Text( self:EyePos() + vector_up * 15, "SCRIPTED FAILED", 2 )

			drone.current_status = "idling"
			drone.current_action = DRONE_TO_IDLE

			self.PathingFailed = true
			return
		end
	end

	if isvector( spot ) then
		self:SetAngles( Angle( 0, ( self:GetPos() - spot ):Angle()[2], 0 ) )
		self.loco:FaceTowards( spot )

		debugoverlay.Text( spot, "SPOT", 5 )

		self.SetupPathFollower = true
		self.current_path_elevators_areas = {}

		local PathFollower = Path( "Follow" )
		PathFollower:SetMinLookAheadDistance( 300 )
		PathFollower:SetGoalTolerance( 20 )
		drone.current_path_success = PathFollower:Compute( self, spot, function( area, fromArea, ladder, elevator, length )
			if ( !IsValid( fromArea ) ) then
				-- first area in path, no cost
				return 0
			else
				if ( !self.loco:IsAreaTraversable( area ) ) then
					-- our locomotor says we can't move here
					return -1
				end

				-- compute distance traveled along path so far
				local dist = 0

				if ( IsValid( ladder ) ) then
					dist = ladder:GetLength()
				elseif ( length > 0 ) then
					-- optimization to avoid recomputing length
					dist = length
				else
					dist = ( area:GetCenter() - fromArea:GetCenter() ):GetLength()
				end

				local cost = dist + fromArea:GetCostSoFar()

				-- check height change
				local deltaZ = fromArea:ComputeAdjacentConnectionHeightChange( area )
				if !( IsValid( ladder ) ) then
					if ( deltaZ >= self.loco:GetStepHeight() ) then
						if ( deltaZ >= self.loco:GetMaxJumpHeight() ) then
							-- too high to reach
							return -1
						end

						-- jumping is slower than flat ground
						local jumpPenalty = 5
						cost = cost + jumpPenalty * dist
					elseif ( deltaZ < -self.loco:GetDeathDropHeight() ) then
						-- too far to drop
						return -1
					end
				else
					cost = cost * 0.5
				end

				-- From the Terminator Nextbot addon(PEAK)
				-- Code Credit: StrawWagen
				local sizeX = area:GetSizeX()
				local sizeY = area:GetSizeY()

				local attributes = area:GetAttributes()

				if bit_AND( attributes, bit_OR( NAV_MESH_BLOCKED_LUA, NAV_MESH_BLOCKED_PROPDOOR ) ) ~= 0 then
					return -1
				end

				if sizeX < 26 or sizeY < 26 then
					-- generator often makes small 1x1 areas with this attribute, on very complex terrain
					if bit_AND( attributes, NAV_MESH_NO_MERGE ) ~= 0 then
						cost = cost * 4
					elseif bit_AND( attributes, NAV_MESH_JUMP ) ~= 0 then
						cost = cost * 0.5
					else
						cost = cost * 1.8
					end
				end

				if sizeX > 151 and sizeY > 151 then --- mmm very simple terrain
					cost = cost * 0.25

				elseif sizeX > 76 and sizeY > 76 then -- this makes us prefer paths thru simple terrain, it's cheaper!
					cost = cost * 0.8

				end

				if bit_AND( attributes, NAV_MESH_AVOID ) ~= 0 then
					cost = cost * 20
				end

				if bit_AND( attributes, NAV_MESH_CLIFF ) ~= 0 then
					cost = cost * 4
				end

				if area:IsUnderwater() then
					cost = cost * 2
				end

				/*if self.current_path_elevators_areas and bit_AND( attributes, NAV_MESH_HAS_ELEVATOR ) and IsValid( elevator ) then
					self.current_path_elevators_areas[ area ] = elevator
				end*/

				return cost
			end
		end )

		self.PathFollower = PathFollower
	end
end

function ENT:RunBehaviour()
	while ( true ) do
		local drone = self:GetOwner()
		if IsValid( drone ) and !self.PathingFailed then
			if !self.SetupPathFollower then
				self:StartActivity( ACT_RUN )
				self.loco:SetDesiredSpeed( 200 )

				self:CreatePathFollower( drone )
			end
		else
			SafeRemoveEntity( self )
		end

		coroutine.yield()
	end
end

function ENT:UpdateTransmitState()
	return TRANSMIT_NEVER
end
