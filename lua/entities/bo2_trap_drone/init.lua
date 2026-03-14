
AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

local developer = GetConVar("developer")
local sv_cheats = GetConVar("sv_cheats")
local host_timescale = GetConVar("host_timescale")

local function ShouldDisplayDebug( devlevel )
	if not devlevel or not isnumber( devlevel) then
		devlevel = 1
	end

	return sv_cheats:GetBool() and developer:GetInt() >= devlevel
end

local nzombies = engine.ActiveGamemode() == "nzombies"

local color_red = Color( 255, 0, 0, 255 )
local color_red_box = Color( 255, 0, 0, 0 )
local color_yellow = Color( 255, 255, 0 , 255 )
local color_yellow_box = Color( 255, 255, 0 , 0 )
local color_blue = Color( 0, 0, 255, 255 )
local color_blue_box = Color( 0, 0, 255, 0 )
local color_green = Color( 0, 255, 0, 255 )
local color_green_box = Color( 0, 255, 0, 0 )

local vector_down_64 = Vector( 0, 0, -64 )
local vector_down_128 = Vector( 0, 0, -128 )

local angDroneRest = Angle( 40, 0, 0 )
local angDroneMoving = Angle( 60, 0, 0 )

local vecOrbitOffset = Vector( 0, 0, 48 )

local vecPadding = Vector( 1, 1, 2 )

local util_TraceLine = util.TraceLine
local util_TraceHull = util.TraceHull
local util_PointContents = util.PointContents

local string_find = string.find

local DispatchEffect = util.Effect
local PlaySound = sound.Play

// Drone specific Enums

local STUCK_RADIUS = 100

local DRONE_TO_IDLE = 0 // default behavior
local DRONE_TO_FOLLOW_PLAYER = 1 // default behavior
local DRONE_TO_FOLLOW_TARGET = 2 // default behavior
local DRONE_TO_HOME_POSITION = 3 // special condition
local DRONE_TO_ORBIT_PLAYER = 4 // special condition
local DRONE_TO_PASSENGER = 5 // special condition
local DRONE_TO_SCRIPTED = 6 // external only

local DRONE_DISMOUNT_NONE = 0
local DRONE_DISMOUNT_TOP = 1
local DRONE_DISMOUNT_BOTTOM = 2

// NextBotDebugType Enums

local NEXTBOT_DEBUG_NONE = 0
local NEXTBOT_BEHAVIOR = 1
local NEXTBOT_LOOK_AT = 2
local NEXTBOT_PATH = 4
local NEXTBOT_ANIMATION = 8
local NEXTBOT_LOCOMOTION = 16
local NEXTBOT_VISION = 32
local NEXTBOT_HEARING = 64
local NEXTBOT_EVENTS = 128
local NEXTBOT_ERRORS = 256
local NEXTBOT_DEBUG_ALL	= 65535

// LadderDirectionType Enums

local CNavLadder = {}
CNavLadder.LADDER_UP = 0
CNavLadder.LADDER_DOWN = 1

// NavTraverseType Enums

local GO_NORTH = 0
local GO_EAST = 1
local GO_SOUTH = 2
local GO_WEST = 3

local GO_LADDER_UP = 4
local GO_LADDER_DOWN = 5
local GO_JUMP = 6
local GO_ELEVATOR_UP = 7
local GO_ELEVATOR_DOWN = 8

local NUM_TRAVERSE_TYPES = 9

// SegmentType Enums

local ON_GROUND = 0
local DROP_DOWN = 1
local CLIMB_UP = 2
local JUMP_OVER_GAP = 3
local LADDER_UP = 4
local LADDER_DOWN = 5

// DoorState_t Enums

local DOOR_STATE_CLOSED = 0
local DOOR_STATE_OPENING = 1
local DOOR_STATE_OPEN = 2
local DOOR_STATE_CLOSING = 3
local DOOR_STATE_AJAR = 4

// TOGGLE_STATE Enums

local TS_AT_TOP = 0
local TS_AT_BOTTOM = 1
local TS_GOING_UP = 2
local TS_GOING_DOWN = 3

// PropDoorRotatingOpenDirection_e Enums

local DOOR_ROTATING_OPEN_BOTH_WAYS  = 0
local DOOR_ROTATING_OPEN_FORWARD = 1
local DOOR_ROTATING_OPEN_BACKWARD = 2

// m_lifeState values

local LIFE_ALIVE = 0
local LIFE_DYING = 1
local LIFE_DEAD = 2

// translations

local t_EnumNames = {
	[DRONE_TO_IDLE] = "TO IDLE",
	[DRONE_TO_FOLLOW_PLAYER] = "FOLLOW PLAYER",
	[DRONE_TO_FOLLOW_TARGET] = "FOLLOW TARGET",
	[DRONE_TO_HOME_POSITION] = "TO HOME",
	[DRONE_TO_SCRIPTED] = "TO SCRIPTED",
}

local t_MoveTypes = {
	[ON_GROUND] = "Ground",
	[DROP_DOWN] = "Falling",
	[CLIMB_UP] = "Climbing / Jumping",
	[JUMP_OVER_GAP] = "Jumping Air Gap",
	[LADDER_UP] = "Climbing Ladder Up",
	[LADDER_DOWN] = "Climbing Ladder Down",
}

local t_TraverseTypes = {
	[GO_NORTH] = "GO NORTH",
	[GO_EAST] = "GO EAST",
	[GO_SOUTH] = "GO SOUTH",
	[GO_WEST] = "GO WEST",
	[GO_LADDER_UP] = "GO LADDER UP",
	[GO_LADDER_DOWN] = "GO LADDER DOWN",
	[GO_JUMP] = "GO JUMP",
	[GO_ELEVATOR_UP] = "GO ELEVATOR UP",
	[GO_ELEVATOR_DOWN] = "GO ELEVATOR DOWN",
	[NUM_TRAVERSE_TYPES] = "VERTICAL", // gmod wiki says so ¯\_(ツ)_/¯
}

// drone actions and states

local t_DroneStatus = {
	["idling"] = 1, // pathing finished and stationary
	["pathing"] = 2, // actively pathing
	["roaming"] = 3, // not an actual state, used subtick in certain behaviors for pathing
	["climbing"] = 4, // climbing a CNavLadder (not a func_ladder)
	["passenger"] = 5, // riding vehicle alongside player
}

local t_MovingStatus = {
	["pathing"] = true,
	["climbing"] = true,
}

local t_FollowEnums = {
	[DRONE_TO_FOLLOW_TARGET] = true,
	[DRONE_TO_FOLLOW_PLAYER] = true,
}

local t_DoorClasses = {
	["func_door"] = true,
	["func_door_rotating"] = true,
	["prop_door_rotating"] = true,
}

local t_ValidMoveTypes = {
	[MOVETYPE_WALK] = true,
	[MOVETYPE_LADDER] = true,
}

local t_DronePings = {
	["default"] = 1,
	["assist"] = 10,
	["defend"] = 30,
}

local AUGER_YDEVIANCE = 20
local AUGER_XDEVIANCEUP = 8
local AUGER_XDEVIANCEDOWN = 1

ENT.generator_hull_mins = Vector( -16.5, -16.5, 0 )
ENT.generator_hull_maxs = Vector( 16.5, 16.5, 70 )

ENT.ActionCompleted = {
	// drone randomly roams around player
	[DRONE_TO_FOLLOW_PLAYER] = function( self )
		if ShouldDisplayDebug( 1 ) and self.current_path_failure then
			self:GetOwner():ChatPrint("[DRONE] Path Failure!")
		end

		local flWait = ( self.last_path_ladder_dismounted or self.current_path_failure ) and 0.15 or math.Rand( 4, 6 )
		if IsValid( self.current_player_goal ) then
			// roam faster if the player is far away
			local flDistanceToPlayer = self:GetPos():Distance( self.current_player_goal:GetPos() )
			flWait = math.min( flWait / ( flDistanceToPlayer / self.player_repath_distance ), flWait )

			// roam faster if player is sprinting
			local flVelocity = self.current_player_goal:GetVelocity():Length2D()
			flWait = flWait * ( 1 - math.Clamp( flVelocity / self.current_player_goal:GetMaxSpeed(), 0, 1 ) )

			self.next_random_roam = CurTime() + flWait
		else
			self.current_player_goal = NULL
			self.current_action = DRONE_TO_IDLE
			self.time_to_next_action = CurTime() + 0.05
			self.next_random_roam = CurTime() + math.Rand( 2, 4 )
		end

		self.next_random_turn = CurTime() + math.Rand( self.random_turn_delay_min, self.random_turn_delay_max )

		if IsValid( self.current_revive_player ) and self.current_ground_position:DistToSqr( self.current_revive_player:GetPos() ) < 10000 then
			// special case for revive targets, idle for 3 seconds and face towards them

			self.next_random_roam = CurTime() + 3
			self.next_random_turn = self.next_random_roam + FrameTime()

			self.desired_angled = ( self.current_revive_player:GetPos() - self:GetPos() ):Angle()

			self.current_revive_player.DownedWithSoloRevive = true
			self.current_revive_player:SetNW2Int( "nzFakeRevivor", self:GetOwner():EntIndex() )
			self.current_revive_player:StartRevive( self.current_revive_player )

			self:SetNextVox( "Revive" )

			timer.Simple( 2, function()
				if !IsValid( self ) then return end
				if !IsValid( self.current_revive_player ) or self.current_revive_player:GetNotDowned() then return end

				self.current_revive_player:RevivePlayer( self:GetOwner() )
				self.current_revive_player:SetNW2Int( "nzFakeRevivor", 0 )
				self.current_revive_player = NULL
			end )
		elseif IsValid( self.current_player_goal ) and math.random( 3 ) == 1 then
			// occasionally face towards player after pathing to look like a creep

			self.desired_angled = ( self.current_player_goal:GetPos() - self:GetPos() ):Angle()
		end
	end,
	
	// rapidly orbit the nearest target
	[DRONE_TO_FOLLOW_TARGET] = function( self )
		self.next_random_roam = CurTime() + 0.5
	end,

	// drone arrived to home position
	[DRONE_TO_HOME_POSITION] = function( self )
		// in nzombies, remove our self to respawn at the table
		if nzombies and self:GetDestroyed() then
			self.current_action = DRONE_TO_IDLE
			self.time_to_next_action = 0

			self:SetSaveValue( "m_lifeState", LIFE_DEAD )

			SafeRemoveEntity( self )
		else
			self.time_to_next_action = CurTime() + math.Rand( 2, 4 )
			self.desired_angled = self.home_angle or angle_zero
		end
	end,

	// pickup any powerups, reset our goal, and idle for a given duration
	[DRONE_TO_SCRIPTED] = function( self )
		local entity = self.current_scripted_goal
		if IsValid( entity ) then
			self:SetNextVox( "Pickup" )

			if entity:GetClass() == "drop_powerup" then
				hook.Call( "MaxisDronePickupPowerup", nil, self, self:GetOwner(), entity, entity:GetPowerUp() )

				// something could happen to it after the hook is called
				if IsValid( entity ) then
					nzPowerUps:Activate( entity:GetPowerUp(), ply, entity )

					ply:EmitSound( nzPowerUps:Get( entity:GetPowerUp() ).collect or "nz_moo/powerups/powerup_pickup_zhd.mp3" )
					entity:Remove()
				end
			else
				hook.Call( "MaxisDronePickupObject", nil, self, self:GetOwner(), entity )
			end
		end

		self.current_scripted_goal = nil
		self.current_action = DRONE_TO_IDLE
		self.time_to_next_action = CurTime() + ( self.scripted_end_wait or 0.5 )
	end,
}

DEFINE_BASECLASS( "base_anim" )

local function PointOnSegmentNearestToPoint( start, endpos, position )
	local direction = endpos - start
	local facing = position - start

	local t = facing:Dot( direction ) / ( direction.x^2 + direction.y^2 + direction.z^2 )
		t = math.Clamp(t, 0, 1)
	return start + t * direction
end

local function anglemod( a )
	a = (360.0/65536) * (a*(65536/360.0));
	return a;
end

local function AI_ClampYaw( yawSpeedPerSec, current, target, time )
	local direction = 0
	if (current != target) then
		local speed = yawSpeedPerSec * time;
		local move = target - current;

		if (target > current) then
			if (move >= 180) then
				move = move - 360;
			end
		else
			if (move <= -180) then
				move = move + 360;
			end
		end

		if (move > 0) then
			// turning to the npc's left
			direction = -1
			if (move > speed) then
				move = speed;
			end
		else
			// turning to the npc's right
			direction = 1
			if (move < -speed) then
				move = -speed;
			end
		end
		
		return anglemod(current + move), direction
	end
	
	return target, direction
end

local function easedLerp( fraction, from, to )
	return Lerp( math.ease.InExpo( fraction ), from, to )
end

local function easedLerpOut( fraction, from, to )
	return Lerp( math.ease.OutExpo( fraction ), from, to )
end

local function easedLerpOutCirc( fraction, from, to )
	return Lerp( math.ease.OutCirc( fraction ), from, to )
end

local function easedLerpInCirc( fraction, from, to )
	return Lerp( math.ease.InCirc( fraction ), from, to )
end

local function easedLerpOutQuad( fraction, from, to )
	return Lerp( math.ease.OutQuad( fraction ), from, to )
end

local nLayer = 0
local path = {}

local function TraceHullAlongPath( position, mins, maxs, direction, trace, filter )
	if !trace or !istable( trace ) then
		trace = {}
	end

	local bSuccess2 = true

	if nLayer > 3 then
		return false
	end

	util_TraceHull({
		start = position,
		endpos = position,
		maxs = mins,
		mins = maxs,
		mask = MASK_NPCSOLID_BRUSHONLY,
		collisiongroup = COLLISION_GROUP_WORLD,
		filter = filter,
		output = trace,
	})

	if ShouldDisplayDebug( 2 ) then
		debugoverlay.Box( position, mins, maxs, 5, trace.Hit and color_red_box or color_transparent )
	end

	if trace.Hit then
		// if we hit, stop at the current point in the path
		// and trace outwards from point of impact by width of model x2

		local vecHit = trace.HitPos
		util_TraceLine({
			start = position,
			endpos = vecHit + ( position - ( Vector( vecHit[1], vecHit[2], position[3] + 4 ) ) ):GetNormalized() * ( nHullWidth * 2 ),
			mask = MASK_NPCSOLID_BRUSHONLY,
			filter = mFilter,
			output = path,
		})

		if ShouldDisplayDebug( 2 ) then
			debugoverlay.Line( path.StartPos, path.HitPos, 6, path.Hit and color_red or color_yellow, true )
		end

		if path.Hit then
			if ShouldDisplayDebug( 2 ) then
				debugoverlay.Cross( path.HitPos, 15, 5, color_red, true )
			end

			return false
		else
			// repeat the process up to 3 times if we cannot find a valid spot to path around
			nLayer = nLayer + 1

			bSuccess2 = TraceHullAlongPath( path.HitPos, mins, maxs, direction, trace, filter )

			if bSuccess2 then
				vecEnd:Set( path.StartPos + path.Normal * ( nHullWidth ) )

				if ShouldDisplayDebug( 2 ) then
					debugoverlay.Cross( vecEnd, 15, 5, color_red, true )
				end
			end
		end
	end

	return bSuccess2
end

local function FindHullIntersection( entity, trace, trace2, contentsMask )
	local ray = {
		start = trace.HitPos,
		endpos = 48 * trace.Normal + trace.HitPos,
		mask = contentsMask or MASK_SHOT,
		ignoreworld = true,
		output = trace2,
		whitelist = true,
		filter = entity,
	}

	util.TraceLine( ray )

	if trace2.Hit then
		return true
	end

	local endPos = ray.endpos
	endPos:Set( entity:GetPos() )
	endPos[ 3 ] = trace.HitPos[ 3 ]

	util.TraceLine( ray )

	if trace2.Hit then
		return true
	end

	endPos:Set( entity:WorldSpaceCenter() )
	endPos[ 3 ] = 0.5 * ( endPos[ 3 ] + trace.HitPos[ 3 ] )

	util.TraceLine( ray )

	return trace2.Hit
end

local function IsCollisionBoxClear( position, mFilter, minBound, maxBound )
	local tr = util_TraceHull({
		start = position,
		endpos = position + Vector( 0, 0, maxBound[3] ),
		mins = minBound,
		maxs = maxBound,
		filter = mFilter,
		mask = MASK_NPCWORLDSTATIC,
	})

	return !tr.StartSolid
end

local function GetClearPaths( entity, position, tiles )
	local clearPaths = {}
	local mFilter = table.Copy( player.GetAll() )
	table.Add( mFilter, entity )
	table.Add( mFilter, ents.FindByClass( "prop_physics" ) )
	table.Add( mFilter, ents.FindByClass( "prop_physics_multiplayer" ) )
	table.Add( mFilter, ents.FindByClass( "ph_prop" ) )

	for _, tile in pairs( tiles ) do
		local tr = util_TraceLine({
			start = position,
			endpos = tile,
			filter = mFilter,
			mask = MASK_NPCWORLDSTATIC,
		})
		
		if !tr.Hit and util.IsInWorld(tile) then
			table.insert( clearPaths, tile )
		end
	end

	return clearPaths
end

local function GetSurroundingTiles( entity, position, distance )
	if distance == nil or !isnumber(distance) then
		distance = 1
	end

	local tiles = {}
	local x, y, z

	local maxBound = Vector()
	local minBound

	if IsValid( entity ) then
		if entity.GetHull then
			minBound, maxBound = entity:GetHull()
		else
			minBound, maxBound = entity:GetCollisionBounds()
		end
	end

	local checkRange = math.max(distance, maxBound.x, maxBound.y)

	for z = -1, 1, 1 do
		for y = -1, 1, 1 do
			for x = -1, 1, 1 do
				local testTile = Vector( x, y, z )
				testTile:Mul( checkRange )

				table.insert( tiles, position + testTile )
			end
		end
	end

	return tiles
end

//////////////////////////// initialization ////////////////////////////

function ENT:Initialize()
	if !self.BuildableBoundsMaxs then
		self.BuildableBoundsMaxs = Vector( 16, 16, 4)
	end
	if !self.BuildableBoundsMins then
		self.BuildableBoundsMins = Vector(-16, -16, -8)
	end

	self:SetCollisionBounds( self.BuildableBoundsMins, self.BuildableBoundsMaxs )

	self:PhysicsInit( SOLID_VPHYSICS )
	self:SetSolid( SOLID_VPHYSICS )

	self:SetMoveType( MOVETYPE_FLYGRAVITY )

	local phys = self:GetPhysicsObject()
	if IsValid( phys ) then
		phys:Wake()
		phys:EnableGravity( true )
		phys:EnableDrag( true )
	end

	self:SetGravity( 1 )
	self:SetFriction( 0.6 )

	self:SetMoveCollide( MOVECOLLIDE_FLY_BOUNCE )

	self:AddFlags( FL_FLY )
	self:AddFlags( FL_NOTARGET )
	self:AddEFlags( EFL_DONTBLOCKLOS )

	self:SetUseType( CONTINUOUS_USE )
	self:SetCollisionGroup( COLLISION_GROUP_WEAPON )
	self:SetTrigger( true )

	self:SetDestroyed( false )
	self:SetNextAttack( CurTime() + 1 )

	self.CurrentSweep = 0
	self.DecayDelay = CurTime() + 1

	self.TPS = ( 1 / engine.TickInterval() )

	self.LastThink = CurTime()

	local vecMins, vecMaxs = self:GetCollisionBounds()
	local vecEnd = Vector()
	local vecOrigin = self:GetPos()
	local vecForward = self:GetForward()
	vecForward:SetUnpacked( vecForward[1], vecForward[2], 0 )
	local nHullWidth = math.max( vecMaxs[1], vecMaxs[2] )

	local ply = self:GetOwner()
	if IsValid( ply ) then
		vecOrigin = ply:EyePos()
		vecForward = ply:EyeAngles():Forward()
		vecForward:SetUnpacked( vecForward[1], vecForward[2], 0 )
	end

	local trace = {}

	util_TraceLine({
		start = vecOrigin,
		endpos = vecOrigin + vecForward * 40,
		mask = MASK_SOLID,
		filter = { self, ply },
		output = trace,
	})

	vecEnd:Set( trace.HitPos )
	if trace.Hit then
		vecEnd:Set( trace.HitPos - trace.Normal * nHullWidth )
	end

	if ShouldDisplayDebug( 1 ) then
		debugoverlay.Cross( vecEnd, 15, 5, color_white, true)
	end

	// position the drone will return to
	self:SetHomePosition( vecEnd, trace )

	self.desired_angled = self:GetAngles()

	self.forced_action = DRONE_TO_HOME_POSITION
	self.current_action = DRONE_TO_IDLE
	self.current_status = "idling"

	self.time_to_next_action = CurTime()

	self.random_wait_delay_min = 2
	self.random_wait_delay_max = 4

	self.next_ground_check = 0
	self.next_stuck_check = 0
	self.next_random_roam = 0
	self.next_random_turn = CurTime() + math.Rand( self.random_wait_delay_min, self.random_wait_delay_max )

	self.random_turn_delay_min = 1.5
	self.random_turn_delay_max = 3

	self.action_delay = 15
	self.action_retrys_max = 5 // how many times to force retry generating a path for the current action before bailing

	self.maxis_vox_wait = 0

	self.target_pitch_adjust = 1

	self.current_pitch = 0
	self.current_roll = 0
	self.current_speed = 0
	self.current_move_ratio = 0

	self.last_yaw_direction = 0
	self.last_yaw_change = 0

	self.velocity_kick_end = 0
	self.velocity_kick_duration = 0.15
	self.velocity_kick_duration_max = 0.5
	self.desired_velocity_kick = nil
	self.current_kick_duration = nil // handled by system
	self.current_velocity_kick = nil

	self.desired_speed = 260
	self.acceleration_speed = 10 // takes ~ 0.5 seconds
	self.deceleration_speed = 4

	self.ground_distance = 100
	self.ground_crouch_distance = 36
	self.ceiling_distance = 64
	self.ceiling_crouch_distance = 8

	self.ladder_tolerance = 12 // pathing along ladder nodes
	self.climb_goal_tolerance = 16 // pathing along jump/climb nodes
	self.goal_tolerance = 24
	self.scripted_tolerance = 60
	self.path_door_tolerance = 140 // distance to nearest door along path before opening it

	self.turning_roll = 20

	self.turning_speed = 120
	self.turning_rate = ( self.turning_speed / self.TPS ) * engine.TickInterval()
	self.aiming_speed = self.TurnRate or 4

	self.moving_pitch = 26
	self.turning_pitch = 14

	self.hover_speed = 64
	self.hover_weight = 24
	self.hover_cycle_time = 0.5 // time in seconds

	self.current_revive_player = NULL // entity
	self.current_player_goal = NULL // entity
	self.current_scripted_goal = nil // vector or entity

	self.prop_blocked_start = nil // handled by stuck system
	self.prop_blocked_path = nil // handled by stuck system
	self.prop_blocked_wait = 0.5
	self.prop_pushing_wait = 0.2
	self.prop_pushing_table = {} // for entities were pushing

	self.current_blocking_mass = 5
	self.current_blocking_entity = NULL

	self.current_move_dir = self:GetForward()

	self.last_repath_time = CurTime() // this fucking sucks
	self.repathing_time = 6
	self.repathing_distance = 600 // minimum distance the total path length must be before considering repathing
	self.player_repath_distance = 400 // minimum distance the player must be from our current goal pos before considering repathing

	self.player_nearby_repath_distance = 80 // how close to the player we must be [ before considering repathing when we are near the player ]
	self.player_nearby_repath_node_distance = 40 // how close to the current path goal we must be ...^
	self.player_nearby_repath_total_distance = 900 // how long the path must be up to this point ...^

	self.player_behind_repath_dot = 0.25 // the minimum dot product to the player against our current pathing direction [ before considering repathing when we pass the player ]
	self.player_behind_repath_time = 2 // how old the current path must be ...^
	self.player_behind_repath_distance = 800 // how long the current path must be ...^

	self.player_force_roam_distance = 512 // distance from the player before we force roaming state

	self.current_ground_distance = self.ground_distance
	self.current_ground_offset = Vector( 0, 0, self.current_ground_distance )
	self.current_ground_stairs = false

	self.current_path_failure = false
	self.current_path_start = CurTime()
	self.current_path_completed = true
	self.current_path_length_total = 0
	self.current_path_length = 0
	self.current_path_distance = 0
	self.current_path_direction = self:GetForward()
	self.current_path_climbing = false
	self.current_path_climbing_with_player = false
	self.current_path_dismount_ladder = false
	self.current_path_nav = NULL // CNavArea
	self.current_path_step = 1
	self.current_path_type = 0 // enum
	self.current_paths = {} // table of PathSegment structures
	self.current_path = {} // PathSegment structure
	self.current_path_ladders = {} // table of CNavAreas with each key being its path step
	self.current_path_elevators = {} // table of CFuncElevators that occupy any path segments ( do these exist? are we being tricked? )
	self.current_path_doors = {} // TBD
	self.current_nav = NULL
	self.last_nav = NULL // used for when vision check is required for path generation

	self.last_path_step_complete_time = CurTime()
	self.current_nav_attributes = 0

	self.current_action_retrys = 0
	self.current_path_retrys = 0

	self.next_ladder_direction = nil // updated on CurrentPathCompleted()
	self.next_ladder_step = 0 // next path step with a ladder
	self.next_ladder = NULL

	self.current_ladder_length = 1 // DONT DIVIDE BY ZERO
	self.current_ladder_dismount = DRONE_DISMOUNT_NONE
	self.current_ladder = NULL
	self.last_path_ladder_dismounted = false

	self.last_goal_crouched = false

	self.current_door = NULL
	self.current_elevator = NULL

	self.current_player_ladder = NULL
	self.current_player_ladder_navdir = nil
	self.current_player_ground_entity = NULL
	self.last_player_ground_entity = NULL

	self.orbit_random_offset_max = Vector( 24, 24, 0 )
	self.orbit_random_offset_min = Vector( -8, -8, 0 )
	self.current_orbit_position = nil

	self:TraceToGround( trace ) // setup ground trace and generator pos

	self.last_position = self:GetPos() // starting position during pathing and last goal position after each path step complete

	self.m_isStuck = false
	self.current_stuck_counter = 0
	self.current_stuck_position = self:GetPos()
	self.current_stuck_start = 0

	self.cursor_position = self.home_position
	self.cursor_direction = self:GetForward()
	self.cursor_length_to_fail = 150

	self.time_of_last_bounce = CurTime()
	self.bounce_count_penalty = 0

	self.path_generator = NULL // our NextBot

	hook.Call( "MaxisDroneSpawned", nil, self, self:GetOwner(), tobool( TFA.MaxisInitialSpawn ) ) // ( entity Drone, entity OwningPlayer, bool IsFirstTimeEverCreated ) for vox stuff maybe?

	if !TFA.MaxisInitialSpawn then
		TFA.MaxisInitialSpawn = true
		self.maxis_vox_ambient_wait = CurTime() + math.Rand( 20, 24 )
	else
		self:SetNextVox( "Hover" )
		self.maxis_vox_ambient_wait = CurTime() + math.Rand( 4, 12 )
	end

	for k, v in pairs( ents.FindByClass( self:GetClass() ) ) do
		if v:GetOwner() == self:GetOwner() and v ~= self then
			v:Remove()
		end
	end

	self.drone_crafting_table = self:FindCraftingTable()

	local ply = self:GetOwner()
	if IsValid( ply ) then
		if nzombies and ply:IsPlayer() then
			timer.Simple( 0, function()
				if !IsValid( ply ) or !IsValid( self ) then return end
				ply:AddBuildable( self )
			end )
		end

		ply.NextTrapUse = CurTime() + 0.35 //use delay

		if not util.IsInWorld( self:GetPos() ) then
			self:SetPos( ply:EyePos() ) //plz dont get stuck in walls
		end
	end
end

//////////////////////////// main functions ////////////////////////////

function ENT:Think()
	local ply = self:GetOwner()
	if !IsValid( ply ) then
		self:SetHealth( 1 )
		self:TakeDamage( 666, self, self )
		return false
	end

	// current features:

	// [misc]
	// --does not path with no navmesh present
	// --idle for a set duration at a given position
	// --support for ping mod ( go to position, defend position, target enemy, follow player )

	// [pathing]
	// --generate a flight path to anything and follow it
	// --repathing after 6 seconds (scaled based on distance to player / 400, player speed / player max speed, total path length / 800, height difference / 512)
	// --during pathing if the drone passes the player while on its last segment, it will repath to them instantly
	// --during pathing if the player is stood near a path segment with direct line of sight to the drones current goal it will take that shortcut
	// --basic pathing correction using a cursor that acts as a guide (teleports to current goal node) (TODO: why do we somtimes teleport while pathing in the air?)
	// --ladder support, uses a tigher goal tolerance, climbing alongside the player if they are on the same ladder (TODO: add 3 lanes)
	// --jumping / climbing uses a tighter goal tolerance and cannot take shortcuts

	// [npc and nextbot targeting and shooting]
	// --always face the enemy during targeting regardless of current action or status
	// --gun begins shooting immediately upon target acquision but takes time to face the target and aim the gun towards them
	// --aiming has a sweeping motion from target origin to head position

	// [vox system]
	// --scheduling system for vox lines (possibly switch to something similar to the default npc's semaphore system)
	// --global delay before any vox can be played, individual line repeat delay, and line intteruption 

	// [unstuck system]
	// --trace if our center is inside the world, teleport to nearest nav square on stuck (or home if none)
	// --if we go off the nav during pathing, afterwards try to repath to the nearest nav square
	// --if the target player goes off the nav, we drop target
	// --if no valid ground is beneath us to generate a path, use a position around the player
	// --physics object pushing

	// NEEDS MORE TESTING:
	// how to handle doors ( figure out navdir and inserting new path segments )
	// how to handle NAV_MESH_CROUCH squares ( exit crouch squares still in a crouched state )
	// how to handle destroyed ( auger death spiral when killed, return to player / table when running out of fuel )

	// TODO:
	// how to handle tight cooridors
	// how to handle player being on train track ( MOVETYPE_PUSH, m_movementType? 'm_vecMoveDir' with GetVelocity(), func_movelinear, func_train )
	// how to handle elevators ( NAV_MESH_HAS_ELEVATOR, m_elevator  )
	// how to handle vehicles ( either use an available passenger seat or find a consistent spot to sit on, SetMoveParent?, custom status type? )
	// how to handle if we get *stuck stuck* ( teleport to a player spawn )

	if IsValid( self.path_generator ) and self.path_generator:GetCreationTime() + engine.TickInterval() < CurTime() then
		if self.path_generator.PathFollower then
			self:GeneratePath( self.path_generator.PathFollower, self.path_generator )
			SafeRemoveEntity( self.path_generator )
			self.path_generator = NULL
		end
	end

	self:AugerThink()

	self:TurbineDecay()

	self:VoxThink()

	self:StuckThink()

	self:Targeting()

	self:SetupSchedule()

	self:Movement()

	if ShouldDisplayDebug( 1 ) then
		local entity = ply:GetEyeTrace().Entity
		if IsValid( entity ) and entity:EntIndex() == self:EntIndex() then
			debugoverlay.Text( self:GetPos() - vector_up * 25, "Blocking: " .. tostring( self.current_blocking_entity ), FrameTime()*2 )
			debugoverlay.Text( self:GetPos() - vector_up * 20, "Target: " .. tostring( self:GetTarget() ), FrameTime()*2 )
			debugoverlay.Text( self:GetPos() - vector_up * 15, "Action: " .. string.upper( t_EnumNames[ self.current_action ] ), FrameTime()*2 )
			debugoverlay.Text( self:GetPos() - vector_up * 10, "Status: " .. string.NiceName( self.current_status ), FrameTime()*2 )
			//if ShouldDisplayDebug( 2 ) then
				debugoverlay.Text( self:GetPos() - vector_up * 5, "Next Turn: " .. math.Round( self.next_random_turn - CurTime(), 3 ), FrameTime()*2 )
				debugoverlay.Text( self:GetPos() + vector_up * 0, "Next Roam: " .. math.Round( self.next_random_roam - CurTime(), 3 ), FrameTime()*2 )
				debugoverlay.Text( self:GetPos() + vector_up * 5, "Next Action: " .. math.Round( self.time_to_next_action - CurTime(), 3 ), FrameTime()*2 )
			//end
			debugoverlay.Text( self:GetPos() + vector_up * 10, "Can Roam: " .. tostring( self:CanRandomlyRoam() ), FrameTime()*2 )
			debugoverlay.Text( self:GetPos() + vector_up * 15, "Can Path: " .. tostring( self.generator_spot_valid ), FrameTime()*2 )
			debugoverlay.Text( self:GetPos() + vector_up * 20, "Bad Path: " .. tostring( self.current_path_failure ), FrameTime()*2 )
			//if ShouldDisplayDebug( 2 ) then
				debugoverlay.Text( self:GetPos() + vector_up * 25, "Blocked: " .. tostring( self:IsBlocked() ), FrameTime()*2 )
				debugoverlay.Text( self:GetPos() + vector_up * 30, "Stuck: " .. tostring( self:IsStuck() ), FrameTime()*2 )
			//end
		end
	end

	self.LastThink = CurTime()
	self:NextThink( CurTime() )
	return true
end

function ENT:Attack( entity, muzzle )
	if !muzzle or !istable( muzzle ) then
		return
	end
	if !IsValid( entity ) then
		return
	end

	local ply = self:GetOwner()

	local bulletinfo = {
		Attacker = IsValid( ply ) and ply or self,
		Callback = function( attacker, trace, dmginfo )
			if CLIENT then return end

			dmginfo:SetDamageType( DMG_BULLET )

			local target = trace.Entity

			if IsValid( target ) then
				if nzombies and target:IsValidZombie() then
					local round = nzRound:GetNumber() > 0 and nzRound:GetNumber() or 1
					local health = tonumber( nzCurves.GenerateHealthCurve( round ) )
					local rand = math.random( 5, 10 )

					dmginfo:SetDamage( math.max( 30, health / rand ) )

					if target.NZBossType or string_find( target:GetClass(), "nz_zombie_boss" ) then
						local rand = math.random( 40, 50 )
						dmginfo:SetDamage( math.max( 40, target:GetMaxHealth() / rand ) )
					end
				end

				local attackHook = "MaxisDrone.VoxKill" .. target:EntIndex()
				hook.Add( "PostEntityTakeDamage", attackHook, function( entity, damage, bTaken )
					hook.Remove( "PostEntityTakeDamage", attackHook )

					if !IsValid( self ) or entity ~= target then
						return
					end

					if bTaken then
						if damage:GetDamage() > 0 and math.random( 2 ) == 1 then
							PlaySound( "TFA_BO3_GENERIC.Gib", !damage:GetDamagePosition():IsZero() and damage:GetDamagePosition() or entity:WorldSpaceCenter(), SNDLVL_IDLE, math.random(97, 103), 1 )
						end
						if entity:Health() <= 0 then
							hook.Call( "MaxisDroneKilledEnemy", nil, self, self:GetOwner(), entity, damage )

							if math.random( 2 ) == 1 then
								self:ScheduleNextVox( "Kill" )
							end
						end
					end
				end )
			end

			hook.Call( "MaxisDroneShootBullet", nil, self, attacker, trace, dmginfo )

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
		Damage = 30,
		Force = 24,
		Num = ( IsValid( ply ) and ply.HasPerk ) and ply:HasPerk( "dtap2" ) and 2 or 1,
		Tracer = 0,
		Hull = 2,
		Src = muzzle.Pos,
		Dir = muzzle.Ang:Forward(),
		Spread = Vector( 0.045, 0.045, 0.045 ),
		IgnoreEntity = self,
	}

	self:FireBullets( bulletinfo )
end

function ENT:OnTakeDamage( dmginfo )
	if self:GetDestroyed() or self.HasShotDown then return end

	local attacker = dmginfo:GetAttacker()
	if !IsValid( attacker ) then return end
	if nzombies and attacker:IsPlayer() then return end

	local ratio = 0.2
	local bonus = 0.5
	local dmg = dmginfo:GetDamage() * ratio
	local newdmg = ( dmginfo:GetDamage() - dmg ) * bonus
	local damage = math.min( newdmg, 100 )

	local ply = self:GetOwner()
	if nzombies and IsValid(ply) and ply:HasPerk("tortoise") then
		damage = damage * 0.5
	end

	self:SetHealth( math.max( self:Health() - dmginfo:GetDamage(), 0 ) )

	local vecSpot = self:GetPos()
	local vecStart = dmginfo:GetReportedPosition()
	local vecHitPos = dmginfo:GetDamagePosition()
	
	if vecHitPos and !vecHitPos:IsZero() then
		vecSpot = vecSpot + ( vecHitPos - vecSpot ):GetNormalized() * 28;
	end

	ParticleEffect( "bo2_turbine_spark", vecSpot, vector_up:Angle() )

	if self:Health() <= 0 then
		self:SetTarget( NULL )

		if nzombies and self.DecayDelay < CurTime() then
			local vecTable = self.home_floor_position

			local pTable = IsValid( self.drone_crafting_table ) and self.drone_crafting_table or self:FindCraftingTable()
			if IsValid( pTable ) then
				vecTable = pTable:GetPos() + pTable:GetForward() * pTable:OBBMaxs()[2]
			end

			self:SetSaveValue( "m_lifeState", LIFE_DYING )
			self:SetDestroyed( true )
			self:SetHomePosition( vecTable )

			self.break_current_path = true

			self:CurrentPathCompleted()

			self.current_player_goal = NULL

			self.last_action = self.current_action
			self.current_action = DRONE_TO_HOME_POSITION

			self:StartPathing()

			self.time_to_next_action = 0
		else
			local data = EffectData()
			data:SetOrigin( self:GetPos() )
			data:SetNormal( self:GetLocalAngles():Forward() )
			data:SetEntity( self )
			data:SetAngles( ( vecStart - vecSpot ):Angle() )

			DispatchEffect( "RPGShotDown", data )

			self:SetSaveValue( "m_lifeState", LIFE_DYING )
			self.HasShotDown = true

			self.fl_AugerTime = CurTime() + self.AugerTime

			self.break_current_path = true
			self.current_action = DRONE_TO_IDLE

			self:CurrentPathCompleted()

			self.current_action = DRONE_TO_IDLE
			self.time_to_next_action = math.huge
		end
	else
		local flRatio = easedLerpOutQuad( math.Clamp( dmginfo:GetDamageForce():Length2D() / 2000, 0, 4 ), 0.2, 4 )

		if !vecHitPos or vecHitPos:IsZero() then
			vecHitPos = self:NearestPoint( ( vecStart and !vecStart:IsZero() ) and vecStart or ( attacker.GetShootPos and attacker:GetShootPos() or attacker:EyePos() ) )
		end

		local vecDirection = ( self:GetPos() - vecHitPos ):GetNormalized()
		self:SetVelocityKick( vecDirection * ( 200 * flRatio ) )
	end
end

function ENT:Use( ply )
	if CLIENT then return end
	if !IsValid( ply ) then return end
	if !nzombies and !self:GetDestroyed() and ply ~= self:GetOwner() then return end
	if ply.NextTrapUse and ply.NextTrapUse > CurTime() then return end

	local own = self:GetOwner()
	if nzombies and IsValid( own ) and own:IsPlayer() and ply ~= own and own:GetInfoNum( "nz_buildable_sharing", 0 ) < 1 then return end

	if !ply:HasWeapon( self:GetTrapClass() ) then
		ply.NextTrapUse = CurTime() + 0.25

		local weapon = ply:Give( self:GetTrapClass() )
		if IsValid( weapon ) then
			local hp = math.Clamp( self:Health() / self:GetMaxHealth(), 0, 1 )
			weapon:SetClip1( math.Round( hp * weapon.Primary_TFA.ClipSize ) )
			weapon:SetNextPrimaryFire( CurTime() + 10 )
		end

		self:EmitSound( "TFA_BO2_SHIELD.Pickup" )
		self:Remove()
	end
end

function ENT:Touch( entity )
	if !IsValid( entity ) or self.HasShotDown then
		return
	end

	local trace = self:GetTouchTrace()

	if self:IsStuck() and entity:GetMoveType() == MOVETYPE_PUSH and t_DoorClasses[ IsValid( entity:GetMoveParent() ) and entity:GetMoveParent():GetClass() or entity:GetClass() ] then
		local trace2 = {}

		FindHullIntersection( entity, trace, trace2, MASK_NPCSOLID )

		self:OpenDoor( entity, trace2.Hit and trace2 or trace )
	end
end

function ENT:StartTouch( entity )
	if self.HasShotDown then
		if entity ~= NULL and entity:IsWorld() then
			self:SetSaveValue( "m_lifeState", LIFE_DEAD )

			self.fl_AugerTime = -1
		end
		return
	end

	if entity == NULL then
		return
	end

	local trace = self:GetTouchTrace()

	// surface impact kick back and sparks
	if trace.HitNormal[ 2 ] < 0.6 and entity:IsSolid() and !entity:IsPlayer() and !entity:IsNextBot() then
		PlaySound( "TFA_BO2_ZMDRONE.Hit", self:GetPos(), SNDLVL_NORM, math.random( 97, 103 ), 1 )

		local fx_origin = self:GetPos()
		if ( trace.HitNormal[2] < 0.6 ) then
			fx_origin = fx_origin - trace.Normal * 28;
		else
			fx_origin = fx_origin - trace.Normal * 10;
		end

		/*local data = EffectData()
		data:SetOrigin( fx_origin )
		data:SetNormal( trace.HitNormal )
		data:SetAngles( trace.Normal:GetNegated():Angle() )

		DispatchEffect( "ManhackSparks", data, false, true )*/
		ParticleEffect( "bo2_turbine_spark", fx_origin, trace.HitNormal:Angle() )

		local flRatio = easedLerpOutQuad( math.Clamp( self:GetVelocity():Length2D() / self.desired_speed, 0, 1 ), 0.2, 1 )

		local vecDirection = ( self:GetPos() - entity:NearestPoint( trace.HitPos ) ):GetNormalized()
		self:SetVelocityKick( vecDirection * ( math.random( 200, 240 ) * flRatio ) + VectorRand( -8 * self.bounce_count_penalty, 8 * self.bounce_count_penalty ) )

		if ShouldDisplayDebug( 1 ) then
			debugoverlay.Line( trace.HitPos, trace.HitPos + vecDirection * 40, 4, color_red, true )
		end

		if !self.time_of_last_bounce or self.time_of_last_bounce + 1 > CurTime() then
			local flRatio = 1 - math.Clamp( ( CurTime() - self.time_of_last_bounce ) / 1, 0, 1 )

			self.bounce_count_penalty = math.min( ( 1 * flRatio ) + self.bounce_count_penalty, 5 )

			if ShouldDisplayDebug( 1 ) then
				debugoverlay.Text( entity:NearestPoint( trace.HitPos ), tostring( self.bounce_count_penalty ), 4 )
			end
		else
			self.bounce_count_penalty = 0
		end

		self.time_of_last_bounce = CurTime()
	end

	// prop pushing and door opening
	if ( entity.GetPhysicsObject or entity:IsWorld() ) and entity:IsSolid() and !entity:IsPlayer() and self.current_status == "pathing" then
		// started being blocked
		if !self.prop_blocked_start then
			if ShouldDisplayDebug( 2 ) then
				self:GetOwner():ChatPrint('[DRONE] Started Touching [' .. tostring( entity ) .. ']')
			end
			self.prop_blocked_path = self.current_path_step
			self.prop_blocked_start = CurTime()
		end

		self.current_blocking_entity = entity

		local trace2 = {}

		FindHullIntersection( entity, trace, trace2, MASK_NPCSOLID )

		// prop pushing
		if entity.GetPhysicsObject and IsValid( entity:GetPhysicsObject() ) then
			local phys = entity:GetPhysicsObject()

			self.current_blocking_mass = phys:GetMass()

			if entity:GetMoveType() == MOVETYPE_VPHYSICS then
				local flWait = self.prop_pushing_table[ entity:EntIndex() ]
				if !flWait or flWait + self.prop_pushing_wait < CurTime() then
					self.prop_pushing_table[ entity:EntIndex() ] = CurTime()

					local vecPoint = entity:NearestPoint( trace.HitPos )
					local vecDirection = ( vecPoint - self:GetPos() ):GetNormalized()

					local damage = DamageInfo()
					damage:SetDamage( ( self.current_speed / 20 ) * 2 )
					damage:SetAttacker( self )
					damage:SetDamageForce( vecDirection * 4000 )
					damage:SetDamageType( DMG_SLASH )
					damage:SetDamagePosition( vecPoint )

					entity:DispatchTraceAttack( damage, trace, vecDirection )

					if trace2.Hit then
						local data = EffectData()
						data:SetStart( trace2.StartPos )
						data:SetOrigin( trace2.HitPos )
						data:SetEntity( entity )
						data:SetSurfaceProp( trace2.SurfaceProps )
						data:SetHitBox( trace2.HitBox )
						data:SetDamageType( DMG_SLASH )

						DispatchEffect( "Impact", data, false, true )
					end

					if ShouldDisplayDebug( 1 ) then
						self:GetOwner():ChatPrint('[DRONE] Hit Prop [' .. tostring( entity ) .. ']')
					end
				end
			end
		end
	end
end

function ENT:EndTouch( entity )
	if self.prop_blocked_start and ( IsValid( self.current_blocking_entity ) or ( self.current_blocking_entity ~= NULL and self.current_blocking_entity:IsWorld() ) ) and self.last_trace_entity and entity == self.current_blocking_entity and entity == self.last_trace_entity then
		if ShouldDisplayDebug( 2 ) then
			local strEntity = tostring( self.current_blocking_entity )
			self:GetOwner():ChatPrint('[DRONE] Stopped Touching [' .. strEntity .. '] - B')
		end

		self.prop_blocked_start = nil
		self.current_blocking_entity = NULL
	end
end

//////////////////////////// generic helper functions ////////////////////////////

function ENT:FindFreeSpot( pos, mindist, maxdist, stepd, stepu, random, visible, ignoreID )
	if !navmesh.IsLoaded() then
		return
	end

	if random == nil or !isbool( random ) then
		random = true
	end

	if visible == nil or !isbool( visible ) then
		visible = false
	end

	pos = pos or self:GetPos()
	mindist = mindist or -1
	maxdist = maxdist or 5000
	stepd = stepd or 35
	stepu = stepu or 35

	local foundnav

	local tab = navmesh.Find( pos, maxdist, stepd, stepu )
	if random then
		for _, nav in RandomPairs( tab ) do
			if IsValid( nav ) and ( !nav:IsUnderwater() or ( IsValid( self.current_player_goal ) and self.current_player_goal:IsUnderwater() ) )  and ( nav:GetCenter():Distance( pos ) >= mindist ) and nav:GetSizeX() > 24 and nav:GetSizeY() > 24 then
				if IsValid( self.last_nav ) and visible and !self.last_nav:IsPartiallyVisible( nav:GetCenter(), self ) then
					continue
				end
				if ignoreID and nav:GetID() == ignoreID then
					continue
				end
				/*if IsValid( self.last_nav ) and nav:IsConnected( self.last_nav ) and self.last_nav:GetSizeX() < 90 then
					continue
				end*/

				foundnav = nav
				break
			end
		end
	else
		for _, nav in ipairs( tab ) do
			local highest = 0
			if IsValid( nav ) and ( !nav:IsUnderwater() or ( IsValid( self.current_player_goal ) and self.current_player_goal:IsUnderwater() ) ) then
				local distance = nav:GetCenter():Distance( pos )
				if ( distance > mindist ) then
					if IsValid( self.last_nav ) and visible and !self.last_nav:IsPartiallyVisible( nav:GetCenter(), self ) then
						continue
					end
					if ignoreID and nav:GetID() == ignoreID then
						continue
					end
					/*if IsValid( self.last_nav ) and nav:IsConnected( self.last_nav ) and self.last_nav:GetSizeX() < 90 then
						continue
					end*/

					if distance > highest then
						highest = distance
						foundnav = nav
					end
				end
			end
		end
	end

	return foundnav
end

local t_SpeakingTerms = {
	[D_LI] = true,
	[D_NU] = true,
}

function ENT:FindNearestEntity( position )
	local ply = self:GetOwner()
	local nearbyents = {}

	local tr = {
		start = position,
		filter = { self, ply },
		mask = MASK_SOLID,
	}

	for k, v in pairs( ents.FindInSphere( self:GetPos(), 600 ) ) do
		if IsValid( v ) and v:IsNPC() or v:IsNextBot() or ( v:GetClass() == "drop_powerup" ) then
			if v == ply then continue end
			if v:GetMaxHealth() > 0 and v:Health() <= 0 then continue end
			if !nzombies and v.Alive and !v:Alive() then continue end
			if nzombies and v.IsAlive and !v:IsAlive() then continue end
			if v:IsNPC() and t_SpeakingTerms[ v:Disposition( ply ) ] then continue end
			if v.Invulnerable or v.BeingNuked then continue end
			if v:GetCreationTime() + 0.5 >= CurTime() then continue end

			tr.endpos = v:WorldSpaceCenter()
			local tr1 = util_TraceLine(tr)
			if tr1.HitWorld then continue end

			if v:GetClass() == "drop_powerup" and !self.current_scripted_goal then
				self:PathToScripted( v )
				continue
			end

			table.insert( nearbyents, v )
		end
	end

	table.sort( nearbyents, function( a, b ) return a:GetPos():DistToSqr( position ) < b:GetPos():DistToSqr( position ) end )
	return nearbyents[ 1 ]
end

function ENT:FindNearestPlayer( position )
	local nearbyents = {}

	local tr = {
		start = position,
		filter = self,
		mask = MASK_SOLID_BRUSHONLY,
	}

	for _, ply in ipairs( player.GetAll() ) do
		if ply.Alive and !ply:Alive() then continue end

		tr.endpos = ply:WorldSpaceCenter()
		local tr1 = util_TraceLine( tr )
		if tr1.HitWorld then continue end

		table.insert( nearbyents, ply )
	end

	table.sort( nearbyents, function( a, b ) return a:GetPos():DistToSqr( position ) < b:GetPos():DistToSqr( position ) end )
	return nearbyents[ 1 ]
end

function ENT:FaceTowards( facing, speed )
	 if !facing then return end

	local flRate = speed or self:GetInternalVariable("m_fMaxYawSpeed") or self.turning_speed
	local yaw
	if isvector( facing ) then
		yaw = ( facing - self:GetPos() ):Angle().yaw
	elseif isangle( facing ) then
		yaw = facing.yaw
	elseif IsValid( facing ) then
		yaw = ( facing:GetPos() - self:GetPos() ):Angle().yaw
	end

	self.m_IdealYaw = yaw
	self.m_YawSpeed = flRate

	local current = anglemod( self:GetLocalAngles().y )
	local ideal = anglemod( self.m_IdealYaw or 0 )

	local dt = math.min( 0.2, CurTime() - ( self.LastThink or ( CurTime() - FrameTime() ) ) )

	local newYaw, direction = AI_ClampYaw( self.m_YawSpeed * 10, current, ideal, dt )

	if newYaw ~= current then
		local angles = self:GetLocalAngles()
		angles.y = Lerp( 0.25, angles.y, newYaw )

		self:SetLocalAngles( angles )
	end

	local change = math.abs( current - newYaw )

	self.last_yaw_direction = direction
	self.last_yaw_change = change
end

function ENT:SetNextAttack( time )
	self.NextAttack = tonumber( time )
end

function ENT:GetNextAttack()
	return self.NextAttack
end

function ENT:IsPathing()
	return t_MovingStatus[ self.current_status ]
end

function ENT:IsStuck()
	return self.m_isStuck and self.current_stuck_counter > 3
end

function ENT:IsBlocked()
	return self.prop_blocked_start and self.current_blocking_entity ~= NULL and self.prop_blocked_start + self.prop_blocked_wait < CurTime() or false
end

function ENT:IsClimbing()
	return ( self.current_path_climbing and self.current_status == "climbing" ) or self:IsDismountingLadder()
end

function ENT:IsClimbingLadder()
	return ( self.current_path_climbing and self.current_status == "climbing" )
end

function ENT:IsClimbingLadderWithPlayer()
	return ( self.current_path_climbing and self.current_status == "climbing" ) and self.current_path_climbing_with_player
end

function ENT:IsDismountingLadder()
	return self.current_ladder_dismount > DRONE_DISMOUNT_NONE and IsValid( self.current_ladder )
end

function ENT:IsCrouching()
	return ( bit.band( self.current_nav_attributes, NAV_MESH_CROUCH ) ~= 0 ) or ( self.last_path_step_complete_time + 0.75 > CurTime() and self.last_goal_crouched )
end

function ENT:ResetBlocked()
	self.prop_blocked_path = nil
	self.prop_blocked_start = nil
	self.current_blocking_entity = NULL
end

function ENT:ResetStuck()
	self.m_isStuck = false
	self.current_stuck_counter = 0
	self.current_stuck_start = CurTime()
	//self.current_stuck_position = self:GetPos()
end

function ENT:SetVelocityKick( offset, angle )
	self.current_kick_duration = math.min( self.velocity_kick_duration_max, self.velocity_kick_duration * ( self:GetPos():Distance( self:GetPos() + offset ) / 32 ) )
	self.velocity_kick_end = CurTime() + self.current_kick_duration
	self.desired_velocity_kick = offset
	self.current_velocity_kick = Vector( 0, 0, 0 )
end

function ENT:GetVelocityKickRatio()
	return math.Clamp( ( self.velocity_kick_end - CurTime() ) / ( self.current_kick_duration or 1 ), 0, 1 )
end

function ENT:GetVelocityKick()
	return self.desired_velocity_kick or Vector()
end

function ENT:GetCurrentVelocityKick()
	return self.current_velocity_kick or Vector()
end

function ENT:GetVelocityKickAngleRatio()
	return math.Clamp( ( self.velocity_kick_end - CurTime() ) / ( self.current_kick_duration or 1 ), 0, 1 )
end

function ENT:GetVelocityKickAngle()
	return self.desired_velocity_kick or Vector()
end

function ENT:GetCurrentVelocityKickAngle()
	return self.current_velocity_kick or Vector()
end

function ENT:SetHomePosition( position, trace )
	self.home_position = position
	self.home_angle = Angle( 0, self:GetAngles()[ 2 ], 0)

	if !trace or !istable( trace ) then
		trace = {}
	end

	util_TraceLine({
		start = self.home_position,
		endpos = self.home_position - Vector( 0, 0, 512 ),
		mask = MASK_NPCSOLID_BRUSHONLY,
		filter = { self },
		output = trace
	})

	self.home_floor_position = trace.HitPos
end

function ENT:GetHomePosition( bReturnFloor )
	return tobool( bReturnFloor ) and self.home_floor_position or self.home_position
end

function ENT:FindCraftingTable()
	if not nzombies then
		return NULL
	end

	for _, entity in ipairs( ents.FindByClass( "nz_buildtable" ) ) do
		if entity:GetNW2Bool( "MaxisDeployed", false ) then
			return entity
		end
	end

	return NULL
end

//////////////////////////// navigation helper functions ////////////////////////////

function ENT:TraceToGround( trace )
	local start = self:GetPos()
	if !trace or !istable( trace ) then
		trace = {}
	end

	local mFilter = table.Copy( player.GetAll() )
	table.Add( mFilter, entity )

	if IsValid( self.current_scripted_goal ) then
		table.insert( mFilter, self.current_scripted_goal )
	end

	util_TraceLine({
		start = start,
		endpos = start - vector_up * ( self.ground_distance + 28 ),
		mask = MASK_NPCSOLID_BRUSHONLY,
		filter = mFilter,
		output = trace,
	})

	if ShouldDisplayDebug( 1 ) then
		debugoverlay.Cross( start, 5, 2, true )
		debugoverlay.Cross( trace.HitPos, 5, 2, true )
	end

	self.current_ground_trace = trace
	self.current_ground_position = self.current_ground_trace.HitPos

	self.current_nav = navmesh.GetNearestNavArea( self.current_ground_position, false, 16, true )

	if IsValid( self.current_nav ) then
		self.current_nav_attributes = self.current_nav:GetAttributes()

		self.current_ground_stairs = IsValid( self.current_nav ) and ( bit.band( self.current_nav_attributes, NAV_MESH_STAIRS ) ~= 0 ) or false
	end

	self:FindGeneratorSpot( mFilter )

	return trace
end

function ENT:FindGeneratorSpot( filter )
	local start = IsValid( self.current_nav ) and self.current_nav:GetClosestPointOnArea( self.current_ground_position ) or self.current_ground_position
	local trace = {}

	util_TraceLine({
		start = start,
		endpos = start - vector_up * ( self.ground_distance + 28 ),
		mask = MASK_NPCSOLID_BRUSHONLY,
		filter = filter,
		output = trace,
	})

	local bSuccess = true

	local vecFloor = IsValid( self.current_nav ) and self.current_nav:GetClosestPointOnArea( trace.HitPos ) or trace.HitPos + vector_up * 2
	local minBounds = self.generator_hull_mins
	local maxBounds = self.generator_hull_maxs

	local target = self.current_player_goal
	if !IsValid( target ) then
		if self.current_action == DRONE_TO_FOLLOW_TARGET and IsValid( self:GetTarget() ) then
			target = self:GetTarget()
		elseif self.current_action == DRONE_TO_IDLE and IsValid( self:GetOwner() ) then
			target = self:GetOwner()
		end
	end

	if !trace.Hit and IsValid( target ) then
		if IsValid( self.current_player_nav ) then
			vecFloor = self.current_player_nav:GetClosestPointOnArea( self:GetPos() ) + vector_up * 2
		else
			local navTest = navmesh.GetNearestNavArea( target:GetPos(), false, 200, false )
			if IsValid( navTest ) then
				vecFloor = navTest:GetClosestPointOnArea( self:GetPos() ) + vector_up * 2
			end
		end
	end

	/*if !IsCollisionBoxClear( vecFloor, mFilter, minBounds, maxBounds ) then
		bSuccess = false

		for i = 1, 4 do
			local surroundingTiles = GetSurroundingTiles( self, vecFloor, 16 * i )
			local clearPaths = GetClearPaths( self, vecFloor, surroundingTiles )	

			for _, tile in pairs( clearPaths ) do
				if IsCollisionBoxClear( tile, tTeleportFilter, minBounds, maxBounds ) then
					local tempNav = navmesh.GetNavArea( tile, self.ground_distance - self.generator_hull_maxs[ 3 ] )
					if IsValid( tempNav ) or !navmesh.IsLoaded() then
						bSuccess = true

						vecFloor = tempNav:GetClosestPointOnArea( tile )
						break
					end
				end
			end

			if bSuccess then
				break
			end
		end
	end*/

	if ShouldDisplayDebug( 1 ) then
		debugoverlay.Sphere( vecFloor, 20, 0.6, color_yellow_box )
	end

	self.generator_spot_valid = bSuccess
	self.generator_position = vecFloor
end

function ENT:GetClosestPathDoor( step )
	local tempDoors = {}
	local position = self:GetPos()

	// check 2 steps ahead
	for i = 0, 4, 1 do
		local pathDoors = self.current_path_doors[ step + i ]

		if not pathDoors then
			continue
		end

		for _, entity in pairs( pathDoors ) do
			if IsValid( entity ) then
				local class = entity:GetClass()

				local bFuncDoor = string_find( class, "func" )
				local bPropDoor = string_find( class, "prop" )

				local nToggleState = entity:GetInternalVariable( "m_toggle_state" ) or 0 // open or close
				local nDoorState = entity:GetInternalVariable( "m_eDoorState" ) or 0 // open or close (or other)

				local nState = 0
				if bFuncDoor and ( nToggleState == TS_AT_TOP or nToggleState == TS_GOING_UP ) then
					nState = 1
				end
				if bPropDoor and ( nDoorState == DOOR_STATE_OPEN or nDoorState == DOOR_STATE_OPENING ) then
					nState = 1
				end

				local data = { door = entity, open = nState }
				table.insert( tempDoors, data )
			end
		end

		if #tempDoors > 1 then
			table.sort( tempDoors, function( a, b ) return a.door:GetPos():DistToSqr( position ) < b.door:GetPos():DistToSqr( position ) end )

			table.sort( tempDoors, function( a, b ) return a.open < b.open end )
		end

		// break if theres already doors on the current path step
		if #tempDoors > 0 and i == 0 then
			break
		end
	end

	if tempDoors[ 1 ] and IsValid( tempDoors[ 1 ].door ) then
		if ( tempDoors[ 1 ].open == 1 ) then
			self.current_door_open = true
		else
			self.current_door_open = false
		end

		return tempDoors[ 1 ].door
	else
		return NULL
	end
end

function ENT:GetPlayerLadder( ply, nav )
	if not IsValid( nav ) then
		return NULL
	end

	if not IsValid( ply ) or ply:GetMoveType() ~= MOVETYPE_LADDER then
		return NULL
	end

	local position = ply:GetPos()
	local playerZ = position.z
	local navDir = CNavLadder.LADDER_UP
	local navLadders = nav:GetLaddersAtSide( navDir )

	local testladders = {}
	for i, navLadder in pairs( navLadders ) do
		if IsValid( navLadder ) then
			local testZ = navLadder:GetBottom().z
			if playerZ > testZ then
				table.insert( testladders, navLadder )
			end
		end
	end

	if table.IsEmpty( testladders ) then
		navDir = CNavLadder.LADDER_DOWN
		navLadders = nav:GetLaddersAtSide( navDir )

		for i, navLadder in pairs( navLadders ) do
			if IsValid( navLadder ) then
				local testZ = navLadder:GetBottom().z
				if playerZ > testZ then
					table.insert( testladders, navLadder )
				end
			end
		end
	end

	if ShouldDisplayDebug( 2 ) then
		self:GetOwner():ChatPrint('[DRONE] Player Ladder CNavDir [' .. navDir ..'] CNavLadder [' .. tostring( navLadders[1] ) .. ']')
	end

	if IsValid( testladders[ 1 ] ) then
		self.current_player_ladder_navdir = navDir
	elseif self.current_player_ladder_navdir then
		self.current_player_ladder_navdir = nil
	end

	if next( testladders ) ~= nil then
		if #testladders > 1 then
			table.sort( nearbyents, function( a, b ) return a:GetBottom():DistToSqr( position ) < b:GetBottom():DistToSqr( position ) end )
		end

		return testladders[1]
	else
		return nav:GetLadders()[1] or NULL
	end
end

function ENT:OpenDoor( entity, trace )
	if not IsValid( entity ) then
		return
	end
	if not trace then
		return
	end

	// door opening

	local class = entity:GetClass()
	if !string_find( class, "_door_rotating" ) then
		return
	end

	local bFuncDoor = string_find( class, "func" )
	local bPropDoor = string_find( class, "prop" )

	local flSpeed = entity:GetInternalVariable( "m_flSpeed" ) or 100 // door movespeed
	local flDistance = bFuncDoor and ( entity:GetInternalVariable( "m_flMoveDistance" ) or 90 ) or ( entity:GetInternalVariable( "m_flDistance" ) or 90 ) // how many degrees the door opens by
	local nToggleState = entity:GetInternalVariable( "m_toggle_state" ) or 0 // open or close
	local nDoorState = entity:GetInternalVariable( "m_eDoorState" ) or 0 // open or close (or other)

	// ignore doors that are already open
	if bFuncDoor and ( nToggleState == TS_AT_TOP or nToggleState == TS_GOING_UP ) then
		return
	end
	if bPropDoor and ( nDoorState == DOOR_STATE_OPEN or nDoorState == DOOR_STATE_OPENING ) then
		return
	end

	if entity:GetInternalVariable( "m_bLocked" ) then
		if ShouldDisplayDebug( 1 ) then
			self:GetOwner():ChatPrint('[DRONE] Hit Locked Door!')
		end
		return
	end

	if ShouldDisplayDebug( 1 ) then
		self:GetOwner():ChatPrint('[DRONE] Hit Rotating Door')
	end

	if tobool( entity:GetInternalVariable( "m_isChaining" ) ) then
		entity:Input( "close", self, self )
	else
		entity:Fire( "close", nil, 0, self, self )
	end

	local strName = "TFABash" .. self:EntIndex()
	self.PreBashName = self:GetName()
	self:SetName( strName )

	local nOpenDir = entity:GetInternalVariable( "opendir" ) or DOOR_ROTATING_OPEN_BOTH_WAYS

	if bFuncDoor then
		// source-sdk-2013/src/game/server/doors.cpp#L994
		local hOldActivator = entity:GetInternalVariable( "m_hActivator" )

		entity:SetSaveValue( "m_hActivator", self ) // open away from us

		entity:Fire( "open", strName, 0, self, self )

		entity:SetSaveValue( "m_hActivator", hOldActivator )
	else
		local vecDirection = trace.HitNormal:GetNegated()

		if vecDirection:Dot( entity:GetForward() ) < 0 then
			entity:SetKeyValue( "opendir", DOOR_ROTATING_OPEN_BACKWARD )
		else
			entity:SetKeyValue( "opendir", DOOR_ROTATING_OPEN_FORWARD )
		end

		entity:Fire( "openawayfrom", strName, 0, self, self )
	end

	timer.Simple( ( flDistance / flSpeed ) + engine.TickInterval(), function()
		if !IsValid( entity ) then
			return
		end

		entity:SetKeyValue( "opendir", nOpenDir )
	end )

	self:SetName( self.PreBashName )
end

function ENT:ActionFailed()
	self.forced_action = nil

	self.current_action_retrys = 0

	self.current_status = "idling"
	self.current_action = DRONE_TO_IDLE

	self.current_player_goal = NULL
	self.time_to_next_action = CurTime() + 2
end

function ENT:TeleportToNextPathSegment()
	if !self:IsPathing() then
		return
	end

	local lastPath = self.current_paths[ self.current_path_step ]

	if !lastPath then
		if ShouldDisplayDebug( 1 ) then
			self:GetOwner():ChatPrint('[DRONE] INVALID PATH, WHERE AM I?')
		end

		self.break_current_path = true
		self:CurrentPathCompleted()
		return
	end

	PlaySound( "TFA_BO2_ZMDRONE.Teleport", self:GetPos() )

	ParticleEffect("nzr_building_poof", self:GetPos(), angle_zero)

	self:SetTarget( NULL )

	self:ResetBlocked()
	self:ResetStuck()

	local nextStep = self.current_path_step + 1

	if self.current_paths[ nextStep ] then
		self.current_path_step = nextStep

		self:UpdatePathStep( lastPath )

		self:SetPos( self.last_position )

		ParticleEffect("nzr_building_poof", self.last_position, angle_zero)
	elseif self.current_path_goal then
		self:SetPos( self.current_path_goal )

		ParticleEffect("nzr_building_poof", self.current_path_goal, angle_zero)

		self:CurrentPathCompleted()
	end

	// reset ground info
	self:TraceToGround()
end

function ENT:TeleportToLastPathSegment()
	if !self:IsPathing() then
		return
	end

	local lastPath = self.current_paths[ #self.current_paths - 1 ]

	if !lastPath then
		if ShouldDisplayDebug( 1 ) then
			self:GetOwner():ChatPrint('[DRONE] INVALID PATH, WHERE AM I?')
		end

		self.break_current_path = true
		self:CurrentPathCompleted()
		return
	end

	PlaySound( "TFA_BO2_ZMDRONE.Teleport", self:GetPos() )

	ParticleEffect("nzr_building_poof", self:GetPos(), angle_zero)

	self:SetTarget( NULL )

	self:ResetBlocked()
	self:ResetStuck()

	local nextStep = #self.current_paths

	if self.final_path then
		self.current_path_step = nextStep

		self:UpdatePathStep( lastPath )

		self:SetPos( self.last_position )

		ParticleEffect("nzr_building_poof", self.last_position, angle_zero)
	else
		if self.current_action == DRONE_TO_FOLLOW_PLAYER then
			self:TeleportToPlayer()
		else
			self:SetPos( self.home_position )

			ParticleEffect("nzr_building_poof", self.home_position, angle_zero)
		end
	end

	// reset ground info
	self:TraceToGround()
end

function ENT:TeleportToHome()
	//if ShouldDisplayDebug( 1 ) then
		self:GetOwner():ChatPrint('[DRONE] Teleported to Home Position')
	//end

	PlaySound( "TFA_BO2_ZMDRONE.Teleport", self:GetPos() )

	ParticleEffect("nzr_building_poof", self:GetPos(), angle_zero)

	self:SetTarget( NULL )
	self:SetPos( self.home_position )

	if !self:GetDestroyed() then
		ParticleEffect("nzr_building_poof", self.home_position, angle_zero)
	end

	self.current_path_retrys = 0

	// reset ground info
	self:TraceToGround()

	if self:GetDestroyed() then
		self.time_to_next_action = 0

		SafeRemoveEntityDelayed( self, 0.5 )
	end
end

function ENT:TeleportToPlayer()
	local ply = self.current_player_goal
	if !IsValid( ply ) then
		ply = self:GetOwner()
	end

	if IsValid( ply ) then
		self.current_player_goal = ply
	end

	local vecOrigin = IsValid( ply ) and ply:GetPos() + ply:OBBCenter() or self:GetHomePosition( false )
	local nearest = navmesh.GetNearestNavArea( vecOrigin, false, 200, true )

	local spot
	if IsValid( self.current_revive_player ) and ply == self.current_revive_player then
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
			self.last_nav = nearest
		end

		local nearby = self:FindFreeSpot( vecOrigin, 0, 400, 400, 400, true )
		if IsValid( nearby ) then
			local closest = 32767
			for i = 1, 6 do
				local test = nearby:GetRandomPoint()
				local distance = test:Distance( vecOrigin )
				if distance < closest then
					closest = distance
					spot = test

					debugoverlay.Cross( spot, 10, 5, color_red, true )
				end
			end
		end
	end

	if isvector( spot ) then
		if ShouldDisplayDebug( 1 ) then
			local strName = (IsValid( ply ) and ply.Nick) and ply:Nick() or ""
			self:GetOwner():ChatPrint('[DRONE] Teleporting to Player ' .. strName )
		end

		self.break_current_path = true
		self.current_action = DRONE_TO_FOLLOW_PLAYER
		self:CurrentPathCompleted()

		PlaySound( "TFA_BO2_ZMDRONE.Teleport", self:GetPos() )

		ParticleEffect("nzr_building_poof", self:GetPos(), angle_zero)

		self:SetTarget( NULL )
		self:SetPos( spot + vecOrbitOffset )
	end

	// reset ground info
	self:TraceToGround()
end

function ENT:TeleportToNearestNav()
	local vecOrigin = self.current_ground_position
	local nearest = navmesh.GetNearestNavArea( vecOrigin, false, 32, true )

	local spot
	if IsValid( nearest ) then
		self.last_nav = nearest
	end

	local nearby = self:FindFreeSpot( vecOrigin, 0, 256, 256, 128, true )
	if IsValid( nearby ) then
		local closest = 32767
		for i = 1, 6 do
			local test = nearby:GetRandomPoint()
			local distance = test:Distance( vecOrigin )
			if distance < closest then
				closest = distance
				spot = test

				debugoverlay.Cross( spot, 10, 5, color_red, true )
			end
		end
	end

	if isvector( spot ) then
		if ShouldDisplayDebug( 1 ) then
			self:GetOwner():ChatPrint('[DRONE] Teleporting to nearest Nav Square')
		end

		PlaySound( "TFA_BO2_ZMDRONE.Teleport", self:GetPos() )

		ParticleEffect("nzr_building_poof", self:GetPos(), angle_zero)

		self:SetTarget( NULL )
		self:SetPos( spot + vecOrbitOffset )
	else
		self:TeleportToHome()
	end

	// reset ground info
	self:TraceToGround()
end

function ENT:PathToPlayer( entity )
	if !IsValid( entity ) or !entity:IsPlayer() then
		return
	end

	if nzombies and !entity:GetNotDowned() then
		self.current_revive_player = entity
	else
		self.current_player_goal = entity
	end

	// force path to end after next node is reached
	self.break_current_path = true

	// force next action immediately
	self.forced_action = DRONE_TO_FOLLOW_PLAYER
	self.time_to_next_action = CurTime()
end

function ENT:PathToTarget( entity )
	if !IsValid( entity ) or !( entity:IsNPC() or entity:IsNextBot() ) then
		if self.marked_target then
			self.marked_target = false
		end
		return
	end

	self.marked_target = true
	self:SetTarget( entity )

	self.break_current_path = true

	self.forced_action = DRONE_TO_FOLLOW_TARGET
	self.time_to_next_action = CurTime()
end

function ENT:PathToHome()
	// force path to end after next node is reached
	self.break_current_path = true

	// force next action immediately
	self.forced_action = DRONE_TO_HOME_POSITION
	self.time_to_next_action = CurTime()
end

function ENT:PathToScripted( pos_or_ent, duration )
	self.break_current_path = true

	self.current_scripted_goal = pos_or_ent

	self.forced_action = DRONE_TO_SCRIPTED
	self.scripted_end_wait = duration or 1
	self.time_to_next_action = CurTime()
end

function ENT:DirectPathToScripted( pos_or_ent )
	if !isvector( pos_or_ent ) then
		if !IsValid( pos_or_ent ) then
			return false
		end

		local id = TypeID( pos_or_ent )

		if id == TYPE_ENTITY then
			pos_or_ent = pos_or_ent:GetPos()
		elseif id == TYPE_NAVAREA then
			pos_or_ent = pos_or_ent:GetCenter() + self.current_ground_offset
		end
	end

	if !util.IsInWorld( pos_or_ent ) then
		return false
	end

	local navarea = navmesh.GetNearestNavArea( pos_or_ent, false, 64, true, true )
	if !IsValid( navarea ) then
		return false
	end

	local flDistance = pos_or_ent:Distance( self:GetPos() )
	local vecDirection = ( pos_or_ent - self:GetPos() ):GetNormalized()

	local tempPaths = {
		[1] = {
			area = self.current_nav,
			curvature = 0,
			distanceFromStart = 1,
			forward = vecDirection,
			how = 0,
			ladder = NULL,
			length = 1,
			pos = self:GetPos() + vecDirection,
			type = 0,
		},
		[2] = {
			area = navarea,
			curvature = 0,
			distanceFromStart = flDistance,
			forward = vecDirection,
			how = 9,
			ladder = NULL,
			length = flDistance,
			pos = pos_or_ent,
			type = 0,
		}
	}

	self.last_position = self:GetPos()

	self.current_path_completed = false

	self.current_ladder_dismount = DRONE_DISMOUNT_NONE
	self.break_current_path = nil
	self.forced_action = nil

	self.last_repath_time = CurTime()
	self.current_path_start = CurTime()

	self.current_paths = tempPaths
	self.current_path_step = 1
	self.current_path = self.current_paths[ 1 ]
	self.current_path_nav = self.current_path.area
	self.current_path_goal = self.current_path.pos
	self.current_path_length = self.current_path.length
	self.current_path_length_total = flDistance
	self.current_path_distance = self.current_path.distanceFromStart
	self.current_path_type = self.current_path.type
	self.current_path_direction = ( self.current_path_goal - self.last_position ):GetNormalized()

	self.cursor_position = self.last_position

	self.final_path = self.current_paths[ #self.current_paths ]
	self.final_path_goal = self.final_path.pos

	self.current_scripted_goal = pos_or_ent
	self.current_action = DRONE_TO_SCRIPTED

	self.current_path_failure = false

	self.current_status = "pathing"

	return true
end

//////////////////////////// main threads ////////////////////////////

function ENT:LadderPathing( navLadder)
	if not IsValid( navLadder ) then
		return
	end

	local ply = self.current_player_goal

	self.current_ladder_length = math.max( navLadder:GetLength(), 1 )

	if self.current_status ~= "climbing" then
		if ShouldDisplayDebug( 1 ) then
			self:GetOwner():ChatPrint("[DRONE] Climbing ladder")
		end

		self.current_status = "climbing"
		self.desired_angled = navLadder:GetNormal():GetNegated():Angle()
	end

	// climbing alongside the player
	if IsValid( ply ) then
		local playerZ = ply:GetPos().z
		local goalZ = playerZ + math.max( ply:OBBCenter()[3], 16 )

		local dismountZ = navLadder:GetTop().z
		local mountZ = navLadder:GetBottom().z + math.max( ply:OBBCenter()[3], 16 )

		// is the player on the ladder
		if self.current_path_type > JUMP_OVER_GAP and ( playerZ > mountZ and goalZ < dismountZ ) and ply:GetMoveType() == MOVETYPE_LADDER and self.current_path_climbing_with_player then
			if !self.current_path_dismount_ladder then
				self.current_path_dismount_ladder = true
			end

			self.current_destination:SetUnpacked( self.current_destination[1], self.current_destination[2], goalZ + 16 )

			self.current_destination:Add( navLadder:GetNormal() * 48 )

			if !util.IsInWorld( self.current_destination ) then
				// climb under the player instead

				self.current_destination:Sub( navLadder:GetNormal() * 48 )
				self.current_destination:SetUnpacked( self.current_destination[1], self.current_destination[2], goalZ - 16 )
			end

			self.cursor_direction = ( self.current_destination - self:GetPos() ):GetNormalized()
		elseif self.current_path_dismount_ladder then
			if self.current_status == "climbing" and self.current_ladder_dismount == DRONE_DISMOUNT_NONE then
				if goalZ > dismountZ then
					if ShouldDisplayDebug( 1 ) then
						self:GetOwner():ChatPrint("[DRONE] Player Dismounted at Top")
					end

					// were going down, but the player has climbed up
					if self.current_path_type == LADDER_DOWN then
						local nextPath = self.current_paths[ self.current_path_step - 1 ]
						local lastPath = self.current_paths[ self.current_path_step - 2 ]

						if lastPath then
							nextPath.climbing = true
							lastPath.climbing = false

							table.insert( self.current_paths, self.current_path_step + 1, nextPath )
							table.insert( self.current_paths, self.current_path_step + 2, lastPath )

							self.final_path = lastPath
							self.final_path_goal = lastPath.pos

							for i = 1, #self.current_paths do
								if i > self.current_path_step + 2 then
									table.remove( self.current_paths, i )
								end
							end

							self:CurrentPathCompleted()
						end
					end

					//self.current_path_dismount_ladder = false
					self.current_ladder_dismount = DRONE_DISMOUNT_TOP
				elseif playerZ < mountZ or ply:GetMoveType() ~= MOVETYPE_LADDER then
					if ShouldDisplayDebug( 1 ) then
						if ply:GetMoveType() ~= MOVETYPE_LADDER then
							self:GetOwner():ChatPrint("[DRONE] Player Dismounted Ladder")
						else
							self:GetOwner():ChatPrint("[DRONE] Player Dismounted at Bottom")
						end
					end

					// were going up, but the player has climbed down
					if self.current_path_type == LADDER_UP then
						local lastPath = self.current_paths[ self.current_path_step - 1 ]

						if lastPath then
							self.current_path.climbing = true
							lastPath.climbing = true

							table.insert( self.current_paths, self.current_path_step + 1, lastPath )

							self.final_path = lastPath
							self.final_path_goal = lastPath.pos

							for i = 1, #self.current_paths do
								if i > self.current_path_step + 1 then
									table.remove( self.current_paths, i )
								end
							end

							self:CurrentPathCompleted()
						end
					end

					//self.current_path_dismount_ladder = false
					self.current_ladder_dismount = DRONE_DISMOUNT_BOTTOM
				end
			end
		end
	end
end

function ENT:Pathing()
	local vecOrigin = self:GetPos()
	local flSpeed = self.desired_speed

	local ply = self.current_player_goal

	local pathDoor = self:GetClosestPathDoor( self.current_path_step )
	local navLadder = self.current_path_ladders[ self.current_path_step ]
	local bClimbing = self.current_path_climbing and IsValid( navLadder )

	self.current_ladder = bClimbing and navLadder or NULL
	self.current_door = IsValid( pathDoor ) and pathDoor or NULL

	self.current_destination = nil

	if self.current_path_direction then
		self.cursor_direction = LerpVector( IsValid( self.current_door ) and 0.25 or 0.1, self.cursor_direction, self.current_path_direction )
	else
		self.cursor_direction = LerpVector( IsValid( self.current_door ) and 0.25 or 0.1, self.cursor_direction, self:GetForward() )
	end

	if self.current_path_goal then
		self.current_destination = Vector( self.current_path_goal )

		// ladder climbing
		if bClimbing then
			self:LadderPathing( self.current_ladder )
		end
	end

	if self.current_destination then
		local flDistance = self.current_destination:Distance( vecOrigin )

		local bLastStep = self.current_path_step == #self.current_paths

		// movement
		local path_total_50_pecent = self.current_path_length_total * 0.5
		local path_length_25_percent = self.current_path_length * 0.25
		local vecToGoal = ( self.current_destination - vecOrigin ):GetNormalized()

		local flRatio = 1

		local vecCurrentDir = self:GetVelocity()
		if vecCurrentDir:Length2D() <= 2 then
			vecCurrentDir = self:GetForward()
		else
			vecCurrentDir:Normalize()
		end

		local flMoveDot = vecToGoal:Dot( vecCurrentDir );
		local flFacingDot = vecToGoal:Dot( self:GetForward() )

		if self.current_action == DRONE_TO_FOLLOW_TARGET then
			ply = self:GetTarget()
		end

		// repathing system
		if IsValid( ply ) and self.current_status ~= "climbing" and t_FollowEnums[ self.current_action ] and self.current_path_length_total > self.repathing_distance then

			local flPlayerSpeed = math.Round( ply:GetVelocity():Length2D(), 3 )
			local flPlayerMaxSpeed = ( ply.GetRunSpeed and ply:GetRunSpeed() ) or ( ply.loco and IsValid( ply.loco ) and ply.loco:GetDesiredSpeed() ) or ply:GetSequenceGroundSpeed( ply:GetSequence() )

			local flGoalDistanceToPlayer = ( self.current_path_goal - self.current_ground_offset ):Distance( ply:GetPos() )
			local flDistanceToPlayer = self.current_ground_position:Distance( ply:GetPos() )

			local flPlayerSpeedRatio = math.Clamp( flPlayerSpeed / flPlayerMaxSpeed, 0, 1 )
			local flPathLengthRatio = math.Clamp( self.current_path_length_total / 800, 0, 1 )
			local flPlayerDistRatio = math.Clamp( flGoalDistanceToPlayer / 400, 0, 1 )

			local flRepathRatio = 1 - math.Remap( flPlayerDistRatio, 0, 1, 0, ( 0.8 * flPlayerSpeedRatio * flPathLengthRatio ) ) // min repath rate ratio of 0.2

			local flElevataion = math.abs( self.current_ground_position.z - ply:GetPos().z )
			if flElevataion > 64 then
				flRepathRatio = flRepathRatio * ( 1 - math.Clamp( ( flElevataion - 64) / 512, 0, 1 ) )
			end

			local flTurnRatio = 1

			// if the player is stood close enough to a node later on the path
			// see if we can path directly to it from our current node target

			local mFilter = { self }
			table.Add( mFilter, player.GetAll() )

			// dont shortcut if were going to climb up/down a ladder soon
			local bLadderAhead = self.next_ladder_step >= self.current_path_step
			if !bLadderAhead then
				bLadderAhead = IsValid( self.next_ladder ) and self.next_ladder_direction and self.current_ground_position:Distance( self.next_ladder_direction == LADDER_DOWN and self.next_ladder:GetTop() or self.next_ladder:GetBottom() ) < self.player_repath_distance
			end

			if ( self.next_ladder_step == 0 or !bLadderAhead ) and flGoalDistanceToPlayer > self.player_nearby_repath_distance then
				local playerPath
				local nNode = 0
				local nMaxs = #self.current_paths

				for i, pathData in pairs( self.current_paths ) do
					// dont shortcut if were about to be jumping/climbing
					if pathData.type > ON_GROUND and i <= ( self.current_path_step + 2 ) then
						break
					end
					if i == nMaxs then
						break
					end

					if pathData and pathData.startpos and ply:GetPos():Distance( pathData.startpos ) < self.player_nearby_repath_distance and pathData.pos:Distance( self.current_path_goal ) > self.repathing_distance then
						local trace2 = util_TraceLine({
							start = self.current_destination,
							endpos = pathData.pos,
							mask = MASK_NPCSOLID,
							filter = mFilter,
						})

						if !trace2.Hit then
							nNode = i
							playerPath = pathData
							break
						end
					end
				end

				if playerPath then
					if ShouldDisplayDebug( 1 ) then
						self:GetOwner():ChatPrint('[DRONE] Player stood near node with line of sight, taking shortcut')
					end

					local nNextStep = self.current_path_step + 1
					self.current_paths[ nNextStep ] = playerPath
					self.final_path_goal = playerPath.pos

					for i = 1, #self.current_paths do
						if i > nNextStep then
							table.remove( self.current_paths, i )
						end
					end
				end
			end

			// if were close to a node, and the player is close to us, finish pathing here
			if ( ( flDistanceToPlayer < self.player_nearby_repath_distance and flDistance < self.player_nearby_repath_node_distance ) or ( flDistanceToPlayer < self.player_nearby_repath_node_distance and self.current_path_distance > self.player_nearby_repath_total_distance ) ) and self.current_path_type <= 0 and !bLadderAhead then
				if ShouldDisplayDebug( 1 ) then
					self:GetOwner():ChatPrint('[DRONE] Player nearby current node, pathing stopped')
				end

				self.break_current_path = true
				self:CurrentPathCompleted()
				self.next_random_roam = CurTime() + math.random( 2, 4 )
				return
			end

			local flPlayerDirection = ( ply:GetPos() - self.current_ground_position ):GetNormalized()
			//flPlayerDirection:SetUnpacked( flPlayerDirection[1], flPlayerDirection[2], 0 )

			local flPlayerDot = ( self.final_path_goal - vecOrigin ):GetNormalized():Dot( flPlayerDirection )

			// repath quicker the further the player is, or if we pass the player while on our final step
			local bPassedPlayer = ( flPlayerDot < self.player_behind_repath_dot and ( flPlayerSpeed > ( flPlayerMaxSpeed * 0.75 ) or self.last_repath_time + self.player_behind_repath_time < CurTime() ) )

			/*if ( flGoalDistanceToPlayer > self.player_repath_distance and self.last_repath_time + ( self.repathing_time * flRepathRatio ) < CurTime() and #self.current_path_ladders == 0 ) or ( bPassedPlayer and self.current_path_step == #self.current_paths and self.current_path_length_total > self.player_behind_repath_distance ) then
				self.last_repath_time = CurTime()

				self.break_current_path = true
				if bPassedPlayer then
					if ShouldDisplayDebug( 1 ) then
						self:GetOwner():ChatPrint('[DRONE] Player is behind the current path and too far away, repathing')
					end

					self:CurrentPathCompleted()
				elseif ShouldDisplayDebug( 1 ) then
					self:GetOwner():ChatPrint('[DRONE] Path Expired after ' .. math.Round( CurTime() - self.current_path_start, 3 ) .. ', repathing')
				end

				// force next action immediately
				self.forced_action = DRONE_TO_FOLLOW_PLAYER
				self.time_to_next_action = 0
			end*/
		end

		// passed our goal, slow down
		if( flMoveDot < 0.25 ) and !self:IsBlocked() and !self.current_path_climbing then
			flSpeed = flSpeed * 0.35
		end

		// facing away from goal, move slower to allow for turning around ( maybe this will make turning smoother? )
		if ( flFacingDot < 0.5 ) and !self.current_path_climbing then
			flTurnRatio = math.Clamp( math.max( flFacingDot, 0 ) / 0.5, 0, 1 )
			flTurnRatio = easedLerpInCirc( flTurnRatio, IsValid( self:GetTarget() ) and 0.75 or 0.5, 1 )

			flSpeed = flSpeed * flTurnRatio
		end

		if flSpeed > ( flDistance / FrameTime() ) then
			flSpeed = ( flDistance / FrameTime() )
		end

		// being to slow down half way through total path
		if self.final_path_goal and !self.current_path_climbing then
			local flTotalDistance = math.max( self.current_path_length_total - self.current_path_distance, 0 )
			if flTotalDistance <= path_total_50_pecent then
				local flTotalRatio = math.Clamp( flDistance / path_total_50_pecent, 0, 1 )
				flTotalRatio = easedLerpOut( flTotalRatio, 0.5, 1)

				flSpeed = flSpeed * flTotalRatio
			end
		end

		// slow down when climbing a ladder and near the player
		if self.current_path_climbing then
			flRatio = math.Clamp( flDistance / ( self.current_ladder_length * 0.5 ), 0, 1 )
			flRatio = easedLerpOut( flRatio, 0, 1)
		else
			// slow down on a greater curve closer to the final step
			if flDistance <= path_length_25_percent and bLastStep and self.current_path_type < JUMP_OVER_GAP then
				flRatio = math.Clamp( flDistance / path_length_25_percent, 0, 1 )
				flRatio = easedLerpOutCirc( flRatio, 0.25, 1)
			end
		end

		self.current_speed = math.Clamp( self.current_speed + self.acceleration_speed, 0, flSpeed * flRatio )

		local flBlockingRatio = 1 - easedLerpInCirc( math.Clamp( self.current_blocking_mass / 350, 0, 1 ), 0, 0.9 )

		if self.current_blocking_entity ~= NULL and self.prop_blocked_start and self.prop_blocked_start + ( self.prop_blocked_wait * flBlockingRatio ) > CurTime() then
			// were stuck on an entity, set the cursor to move with our current velocity instead of desired velocity

			local flBlockingTime = self.prop_blocked_start + ( self.prop_blocked_wait * flBlockingRatio )
			local flTimeRatio = math.Clamp( ( flBlockingTime - CurTime() ) / self.prop_blocked_wait, 0, 1 )

			self.cursor_position = self.cursor_position + self.cursor_direction * ( self.current_speed * FrameTime() ) * ( 1 - self:GetVelocityKickRatio() ) * flTimeRatio
		else
			self.cursor_position = self.cursor_position + self.cursor_direction * ( self.current_speed * FrameTime() ) * ( 1 - self:GetVelocityKickRatio() )
		end

		// cursor that tells us where the drone *should be* currently along the path
		local flCursorDistance = vecOrigin:Distance( self.cursor_position )

		if ShouldDisplayDebug( 1 ) then
			debugoverlay.Text( self:GetPos() - vector_up * 40, math.Round( flCursorDistance, 2 ), FrameTime()*2 )
			debugoverlay.Line( vecOrigin, self.cursor_position, FrameTime() * 2, color_red )
		end

		if flCursorDistance > self.cursor_length_to_fail and !self:IsClimbingLadder() then
			if ShouldDisplayDebug( 1 ) then
				self:GetOwner():ChatPrint('[DRONE] Teleporting to Next Segment, Distance [' .. math.Round( flCursorDistance, 3 ) .. ']')
			end

			// deviated too far from path
			self:TeleportToNextPathSegment()
			return
		end

		if IsValid( self.current_door ) then
			debugoverlay.Text( self:GetPos() - vector_up * 40, math.Round( CurTime(), 2 ) .. " DOOR ALONG PATH ", FrameTime()*2 )
			debugoverlay.Text( self.current_door:WorldSpaceCenter(), "DOOR", FrameTime()*2 )
		end

		self.current_move_dir = LerpVector( ( self.current_path_type > JUMP_OVER_GAP or IsValid( self.current_door ) ) and 0.25 or self.turning_rate, self.current_move_dir, vecToGoal )

		if IsValid( self.current_door ) and !self.current_door_open then
			local flDistanceToDoor = ( vecOrigin - self.current_door:GetPos() ):Length2D()

			if flDistanceToDoor <= self.path_door_tolerance then
				local mFilter = { self }
				table.Add( mFilter, player.GetAll() )

				local trace2 = util_TraceLine({
					start = vecOrigin,
					endpos = self.current_door:WorldSpaceCenter(),
					mask = MASK_NPCSOLID,
					filter = mFilter,
				})

				if ShouldDisplayDebug( 1 ) then
					debugoverlay.Line( self.last_position, trace2.HitPos, 6, color_green, true )
				end

				if self.current_door:GetInternalVariable( "m_bLocked" ) then
					if flDistanceToDoor < self.goal_tolerance then
						if ShouldDisplayDebug( 1 ) then
							self:GetOwner():ChatPrint('[DRONE] Locked Door, Teleporting to Next Segment, Distance [' .. math.Round( flCursorDistance, 3 ) .. ']')
						end

						self:TeleportToNextPathSegment()
						return
					end
				elseif trace2.Hit then
					self:OpenDoor( self.current_door, trace2 )
				end
			end
		end

		// you have reached your final destination, hell
		if flDistance < ( self.current_path_type > JUMP_OVER_GAP and self.ladder_tolerance or tobool( self.current_path.scripted ) and self.scripted_tolerance or self.current_path_type > ON_GROUND and self.climb_goal_tolerance or self.goal_tolerance ) and !self:IsClimbingLadderWithPlayer() then
			self:CurrentPathCompleted()
		end

		if ShouldDisplayDebug( 1 ) then
			debugoverlay.Axis( self.cursor_position, self.cursor_direction:Angle(), 15, FrameTime() * 2, true )
		end
	else
		// no path, force idling
		if ShouldDisplayDebug( 1 ) then
			self:GetOwner():ChatPrint( "[DRONE] INVALID PATHING STATE FOR '" .. ( t_EnumNames[ self.forced_action or self.current_action ] or "ERROR" ) .. "'" )
		end

		if self.current_status ~= "idling" then
			self.current_status = "idling"
			self.current_path_completed = true

			self:TraceToGround()

			self.current_action = DRONE_TO_IDLE
			self.time_to_next_action = CurTime() + 0.5
		end
	end
end

function ENT:Movement()
	if self.HasShotDown then return end

	if !self.current_path_completed then
		self:Pathing()
	end

	if !self:IsPathing() then
		// decelerate once path is completed
		if self.current_speed > 0 then
			self.current_speed = math.Clamp( self.current_speed - self.deceleration_speed, 0, self.desired_speed )

			// face towards final goal faster after path is completed
			if self.current_path_completed and self.current_status == "idling" then
				local vecToGoal = ( self.cursor_position - self:GetPos() ):GetNormalized()
				self.current_move_dir = LerpVector( self.turning_rate, self.current_move_dir, vecToGoal )
			end
		end
	end

	local flOffset = 0
	local trace = {}

	util_TraceLine({
		start = self:GetPos(),
		endpos = self:GetPos() + vector_up * self.ceiling_distance,
		mask = MASK_NPCSOLID_BRUSHONLY,
		filter = self,
		output = trace,
	})

	if trace.Hit then
		flOffset = ( 1 - trace.Fraction ) * self.ceiling_distance
	end

	// desired distance from ground ( and ceiling ) used for path generation
	self.current_ground_distance = ( self:IsCrouching() and self.ground_crouch_distance or self.ground_distance ) - flOffset

	if self.next_ground_check < CurTime() or !self.current_ground_trace then
		self:TraceToGround()
		self.next_ground_check = CurTime() + ( self.current_ground_stairs and 0 or 0.2 )
	end

	// targeting follows the height of the enemy
	local target = self:GetTarget()
	if IsValid( target ) and ( self.current_action == DRONE_TO_FOLLOW_TARGET or ( nzombies and target:IsPlayer() and !target:GetNotDowned() ) ) then
		self.current_ground_distance = math.max( target:GetPos():Distance( target:EyePos() + vecOrbitOffset ), self.current_ground_distance / 2 )
	end

	// hover above revive target
	local revive_target = self.current_revive_player
	if IsValid( revive_target ) and self.current_action == DRONE_TO_FOLLOW_PLAYER and self.current_status == "idling" then
		self.current_ground_distance = revive_target:GetPos():Distance( revive_target:EyePos() + vecOrbitOffset )
	end

	local target = self:GetTarget()

	// turning system
	if IsValid( target ) then
		// face towards targeted entity and reset forced facing angle
		self.desired_angled = nil

	elseif self.current_action == DRONE_TO_SCRIPTED and self.current_scripted_goal and ( self.current_path_step == #self.current_paths ) and !self.current_path_completed then
		// face the script target when we are on the last step of our path but not yet completed
		self:FaceTowards( self.current_scripted_goal )

	elseif self.current_speed > 0 and !self.current_path_completed then
		// face towards next path pos
		if IsValid( self.current_ladder ) and self.current_path_climbing then
			// if climbing either face the current desired angle or along the ladders facing normal
			if self.current_path_climbing_with_player then
				self.last_yaw_direction = 0

				if self.desired_angled then
					self:FaceTowards( self.desired_angled )

					if math.Round( self:GetAngles()[2], 2 ) == math.Round( self.desired_angled[2], 2 ) then
						self.desired_angled = nil
					end
				end
			else
				local facing = self.current_ladder:GetNormal()
				if self.current_path_type < LADDER_DOWN then
					facing:GetNegated()
				end

				self:FaceTowards( facing:Angle() )
			end
		else
			self:FaceTowards( self.current_destination )
		end
	
	elseif self.current_status == "idling" then
		// reset
		self.last_yaw_direction = 0

		if self.desired_angled then
			// update
			self:FaceTowards( self.desired_angled )

			if math.Round( self:GetAngles()[2], 2 ) == math.Round( self.desired_angled[2], 2 ) then
				self.desired_angled = nil
			end
		end
	end

	local breath = math.sin( CurTime() )
	local breath2 = math.cos( CurTime() ) * 0.5

	local distance = self:GetPos():Distance( self.current_ground_position )

	local direction = self.last_yaw_direction

	local newRoll = 0
	if direction ~= 0 then
		// turning left or right
		newRoll = easedLerp( self.last_yaw_change / 3, 0, self.turning_roll * direction )
	end

	self.current_pitch = math.Approach( self.current_pitch, direction, 2 * FrameTime() )

	self.current_roll = math.Approach( self.current_roll, newRoll, 30 * FrameTime() )

	local roll_ratio = math.Clamp( math.abs( self.current_roll ) / self.turning_roll, 0, 1 )
	local pitch_ratio = math.Clamp( self.current_speed / self.desired_speed, 0, 1 )

	local angles = self:GetLocalAngles()

	// random breathing roll
	angles.r = self.current_roll + ( 2 * breath )

	if IsValid( self:GetTarget() ) then
		// limit pitch when targeting so the gun doesnt clip 
		self.target_pitch_adjust = math.Approach( self.target_pitch_adjust, 0.45, 2 * FrameTime() )
	else
		self.target_pitch_adjust = math.Approach( self.target_pitch_adjust, 1, 2 * FrameTime() )
	end

	// movespeed based pitch, plus random breathing pitch, plus additional turning lean-in pitch
	angles.p = Lerp( pitch_ratio, 0, self.moving_pitch * self.target_pitch_adjust ) + ( 4 * breath2 ) + ( Lerp( self.current_pitch, 0, self.turning_pitch * direction ) * roll_ratio )

	self:SetLocalAngles( angles )

	local vecVelocity = Vector()
	if self.current_move_dir then
		vecVelocity:Set( self.current_move_dir * self.current_speed )
	end

	// knockback from collisions / damage
	local flKickRatio = self:GetVelocityKickRatio()
	if flKickRatio > 0 then
		self.current_velocity_kick = self:GetVelocityKick() * flKickRatio

		vecVelocity:Add( self.current_velocity_kick )
	elseif self.current_velocity_kick and !self.current_velocity_kick:IsZero() then
		self.current_velocity_kick:SetUnpacked( 0, 0, 0 )
	end

	// ascension
	local flGroundRatio = math.Clamp( distance / self.current_ground_distance, 0, 1 )

	local flSpeed = easedLerpOutCirc( 1 - flGroundRatio, 0, self.hover_speed )
	if distance > self.current_ground_distance and !self:IsPathing() then
		// negate hover speed if were above ground distance
		flSpeed = easedLerpOutCirc( math.Clamp( ( distance - self.current_ground_distance ) / 28, 0, 1 ), 0, self.hover_speed * 2 ) * -1
	end

	vecVelocity:Add( vector_up * flSpeed )

	// up and down hovering

	local flHover = easedLerpOutCirc( flGroundRatio, 0, self.hover_weight )
	vecVelocity:Add( vector_up * ( math.sin( CurTime() * ( 1 / self.hover_cycle_time ) ) * flHover ) )

	self:SetLocalVelocity( vecVelocity )

	if ShouldDisplayDebug( 1 ) and self.current_destination and self:IsPathing() then
		debugoverlay.Sphere( self.current_destination, 20, 2, color_blue_box )
	end

	self.current_ground_offset = Vector( 0, 0, self.current_ground_distance )
end

function ENT:SetupSchedule()
	if self:GetDestroyed() or self.HasShotDown then return end
	if self.path_generator and IsValid( self.path_generator ) then return end

	if self.current_action == DRONE_TO_FOLLOW_TARGET and !self.marked_target and !IsValid( self:FindNearestEntity( self:GetPos() ) ) then
		self.time_to_next_action = 0
	end

	if IsValid( self.current_revive_player ) and self.current_revive_player:GetNotDowned() then
		self.revive_check_wait = CurTime()
		self.current_revive_player = NULL
	end

	if nzombies and self.current_action ~= DRONE_TO_SCRIPTED and ( !self.revive_check_wait or self.revive_check_wait < CurTime() ) and !IsValid( self.current_revive_player ) and navmesh.IsLoaded() then
		self.revive_check_wait = CurTime() + 1

		for _, ply in ipairs( player.GetAll() ) do
			if ply:Alive() and !ply:GetNotDowned() and ply:GetPos():DistToSqr( self.current_ground_position ) < 1440000 then
				self.current_revive_player = ply

				self.break_current_path = true
				self.forced_action = DRONE_TO_FOLLOW_PLAYER
				self.time_to_next_action = 0
				self.revive_check_wait = CurTime() + 4
				break
			end
		end
	end

	// default behavior loop

	if self.time_to_next_action < CurTime() and !self:IsPathing() and navmesh.IsLoaded() then
		// follow the player or do what was asked of us
		self.last_action = self.current_action
		self.current_action = self.forced_action or DRONE_TO_FOLLOW_PLAYER

		// failsafe
		if self.forced_action and self.current_action_retrys > self.action_retrys_max then
			self:ActionFailed()
			return
		end

		// if we have a valid target randomly choose to orbit them instead
		local target = self:GetTarget()
		if IsValid( target ) and ( target:IsNPC() or target:IsNextBot() ) and self.current_action == DRONE_TO_FOLLOW_PLAYER and math.random( 3 ) == 1 then
			self:SetNextVox( "Target" )

			self.current_action = DRONE_TO_FOLLOW_TARGET
		end

		if self.current_action ~= DRONE_TO_IDLE or self.current_status == "roaming" then
			self:StartPathing()
		end

		if self.current_action == DRONE_TO_FOLLOW_PLAYER then
			if IsValid( self.current_revive_player ) and !self.current_revive_player:GetNotDowned() then
				self.current_player_goal = self.current_revive_player
			elseif !IsValid( self.current_player_goal ) then
				local ply = self:GetOwner()
				if IsValid( ply ) and ply:Alive() and ply:IsInWorld() and t_ValidMoveTypes[ ply:GetMoveType() ] then
					self.current_player_goal = ply
				end
			end

			if IsValid( self.current_player_goal ) then
				self.time_to_next_action = CurTime() + self.action_delay
			else
				self.time_to_next_action = CurTime() + 0.05
			end
		else
			self.current_player_goal = NULL

			self.time_to_next_action = CurTime() + 1

			if self.current_action == DRONE_TO_FOLLOW_TARGET then
				self.time_to_next_action = CurTime() + math.Rand( 4, 8 )
			end
		end
	end

	if t_FollowEnums[ self.current_action ] then
		// target a random navsquare around the player/target to keep up with them
		if self.current_status == "idling" or self:IsClimbingLadder() /*self.current_status == "climbing"*/ then
			if self.generator_spot_valid and self:CanRandomlyRoam() then
				if IsValid( self.current_nav ) then
					self.last_nav = self.current_nav
				end

				self.current_status = "roaming"

				self:StartPathing()
			end

			if self.next_random_turn < CurTime() then
				self.next_random_turn = CurTime() + math.Rand( self.random_turn_delay_min, self.random_turn_delay_max )

				self.desired_angled = AngleRand(0, -180, 0, 180 )
			end
		end
	elseif self.current_action == DRONE_TO_IDLE then
		// random turning while idling
		if self.current_status == "idling" and ( self.next_random_turn < CurTime() ) then
			self.next_random_turn = CurTime() + math.Rand( self.random_turn_delay_min, self.random_turn_delay_max )

			self.desired_angled = AngleRand(0, -180, 0, 180 )
		end

		if !self.generator_spot_valid then
			if IsValid( self.current_nav ) then
				local tempNav = self:FindFreeSpot( self.current_ground_position, 0, 256, 64, 32, true, true, self.current_nav:GetID() )

				if IsValid( tempNav ) and ( tempNav:GetZ() + 64 ) >= self.current_ground_position.z then
					if !self:DirectPathToScripted( tempNav ) then
						self:TeleportToHome()
					end
				else
					self:TeleportToNearestNav()
				end
			else
				self:TeleportToNearestNav()
			end
		end
	end
end

function ENT:Targeting()
	if self.HasShotDown then return end

	if self.current_action == DRONE_TO_SCRIPTED and self.current_path_step == #self.current_paths then
		self.NextTargetAttempt = CurTime() + 0.22
		return
	end

	local entity = self:GetTarget()

	if IsValid( entity ) then
		// entity no longer valid for targeting
		if ( entity:Health() < 0 or entity:GetNoDraw() or entity.Invulnerable or entity.BeingNuked ) or !self:Visible( entity ) or ( entity.GetHidePop and entity:GetHidePop() ) then
			if self.marked_target then
				self.marked_target = false
			end

			self:SetTarget( NULL )

			entity = NULL

			self.NextTargetAttempt = CurTime() + 0.22
		end
	elseif self.marked_target then
		self.marked_target = false
	end

	if ( !self.NextTargetAttempt or self.NextTargetAttempt < CurTime() ) then
		if ( self:GetNextAttack() < CurTime() ) and !self.marked_target then
			local testEntity = self:FindNearestEntity( self:GetPos() )
			local bBlocked = hook.Call( "MaxisDroneTargetEnemy", nil, self, self:GetOwner(), testEntity )

			if !bBlocked or bBlocked == nil then
				self:SetTarget( testEntity )
			end

			entity = self:GetTarget()

			if IsValid( entity ) then
				// delay retargeting so we dont constantly swap between approaching targets
				self.NextTargetAttempt = CurTime() + 1.4
			end
		end
	end

	local ft = FrameTime() * game.GetTimeScale() * (sv_cheats:GetBool() and host_timescale:GetFloat() or 1)
	local flRate = ( self.aiming_speed * ft )
	local ply = self:GetOwner()

	if IsValid( entity ) then
		if math.random( 100 ) == 1 and math.random( 2 ) == 1 then
			self:ScheduleNextVox( "Scan" )
		end

		self.CurrentSweep = math.abs( math.sin( CurTime() * 2 ) )

		local aimbone = self:LookupBone( "tag_barrel" )
		local muzzle = self:GetAttachment(1)

		if aimbone and muzzle and muzzle.Pos then
			local hitbone = entity:LookupBone("ValveBiped.Bip01_Neck")
			if !hitbone then
				hitbone = entity:LookupBone("j_neck")
			end

			local vecFinal = entity:EyePos()
			if hitbone then
				local matrix = entity:GetBoneMatrix( hitbone )
				if matrix then
					vecFinal = matrix:GetTranslation()
				end
			end

			local vecToTarget = ( vecFinal - muzzle.Pos ):GetNormalized()
			vecToTarget:SetUnpacked( vecToTarget[1], vecToTarget[2], 0 )
			local vecDirection = self:GetForward()
			local flDot = vecDirection:Dot( vecToTarget )

			// turning body to face target

			self:FaceTowards( vecFinal, 120 + ( 80 * ( math.Clamp( entity:GetVelocity():Length2D() / 200, 0, 1 ) ) ) )

			// aiming gun towards target

			if flDot > 0.86 then
				if math.random( 5 ) == 1 then
					self:ScheduleNextVox( "Attack" )
				end

				local vecSweep = Lerp( self.CurrentSweep, entity:GetPos(), vecFinal )
				local angStart = self:GetManipulateBoneAngles( aimbone )
				local angFinal = WorldToLocal( vecSweep, angle_zero, muzzle.Pos, self:GetAngles() ):Angle()
				angFinal:SetUnpacked( angFinal[ 1 ], 0, 0 )

				local angCurrent = LerpAngle( flRate, angStart, angFinal )

				self:ManipulateBoneAngles( aimbone, angCurrent, false ) // dont network to client
			end

			muzzle = self:GetAttachment(1)

			local matrix = self:GetBoneMatrix( aimbone )
			local vecAimOrigin = matrix:GetTranslation()

			vecToTarget = ( vecFinal - vecAimOrigin ):GetNormalized()
			vecDirection = muzzle.Ang:Forward()
			flDot = vecDirection:Dot( vecToTarget )

			if ShouldDisplayDebug( 1 ) then
				debugoverlay.Axis( muzzle.Pos, muzzle.Ang, 5, 1, true )
				debugoverlay.Axis( vecAimOrigin, vecToTarget:Angle(), 5, 1, true )
			end

			if self:GetNextAttack() < CurTime() and !entity:IsPlayer() then
				self:Attack( entity, muzzle )

				local rapid = tobool( self.RapidFire )
				if nzombies and IsValid(ply) and ply:HasPerk("time") then
					rapid = true
				end

				self:SetNextAttack( CurTime() + ( 60 / ( rapid and self.RPMRapid or self.RPM ) ) )

				self.next_random_turn = CurTime() + math.Rand( self.random_turn_delay_min, self.random_turn_delay_max )

				self.maxis_vox_ambient_wait = math.max( self.maxis_vox_ambient_wait, CurTime() + math.Rand( 4, 12 ) )
			end
		end
	else
		// returning to default pose
		local aimbone = self:LookupBone("tag_barrel")

		if aimbone then
			local angStart = self:GetManipulateBoneAngles( aimbone )
			local angDesired = Angle( angDroneRest )

			// cheap way of detecting movement
			if self:GetAngles().p > 6 then
				self.current_move_ratio = math.Approach( self.current_move_ratio, 1, 4 * FrameTime() )
			elseif self.current_move_ratio > 0 then
				self.current_move_ratio = math.Approach( self.current_move_ratio, 0, 4 * FrameTime() )
			end

			if self.current_move_ratio > 0 then
				// TODO: use a variable thats reset and increases only when moving, as curtime causes an initial jitter b/c of time difference

				local flSway = math.sin( CurTime() * 2 * math.ease.InCirc( self.current_move_ratio ) )

				angDesired = LerpAngle( self.current_move_ratio, angDroneRest, angDroneMoving + Angle( 6 * flSway, 0, 0 ) )
			end

			if angStart ~= angDesired then
				local angCurrent = LerpAngle( flRate, angStart, angDesired )

				self:ManipulateBoneAngles( aimbone, angCurrent, false )
			end
		end
	end
end

function ENT:StuckThink()
	if self.HasShotDown then return end

	if self.next_stuck_check < CurTime() then
		self.last_trace_entity = self:GetTouchTrace().Entity

		local vecMins = self:OBBMins()
		local vecMaxs = self:OBBMaxs()

		local nHullHeight = ( vecMaxs[3] + math.abs(vecMins[3]) )

		local mFilter = { self }
		table.Add( mFilter, player.GetAll() )

		self.next_stuck_check = CurTime() + 0.15

		local vecCheckPos = self:GetPos() - Vector( 0, 0, 1 * ( nHullHeight ) )
		local trace = util_TraceLine({
			start = self:GetPos(),
			endpos = vecCheckPos,
			mask = MASK_NPCWORLDSTATIC,
			filter = mFilter
		})

		if self.prop_blocked_start and self.prop_blocked_path and self.current_blocking_entity ~= NULL and ( ( !IsValid( self.last_trace_entity ) and ( self.last_trace_entity == NULL or !self.last_trace_entity:IsWorld() ) ) or ( self.current_path_step ~= self.prop_blocked_path ) ) then // the wiki says not to do this :)
			if ShouldDisplayDebug( 2 ) then
				local strEntity = tostring( self.current_blocking_entity )
				self:GetOwner():ChatPrint('[DRONE] Stopped Touching [' .. strEntity .. '] - A')
			end

			self:ResetBlocked()
		end

		// stuck inside world
		if trace.StartSolid or trace.HitWorld then
			if ShouldDisplayDebug( 1 ) then
				self:GetOwner():ChatPrint('[DRONE] Stuck in World')
			end

			if self.current_status == "pathing" then
				self:TeleportToNextPathSegment()
			else
				self:TeleportToNearestNav()
			end
			return
		end

		if self.m_isStuck then
			if self.current_status ~= "pathing" or self:GetPos():Distance( self.current_stuck_position ) > STUCK_RADIUS then
				self.m_isStuck = false

				self.current_stuck_counter = 0
				self.current_stuck_start = CurTime()
			else
				self.current_stuck_counter = 1 + self.current_stuck_counter

				if ShouldDisplayDebug( 1 ) and self.m_isStuck and self.current_stuck_counter == 4 then
					debugoverlay.Sphere( self.current_stuck_position, 100, 1.5, color_green_box, false )

					self:GetOwner():ChatPrint("[DRONE] Stuck after " .. math.Round( CurTime() - self.current_stuck_start, 3 ) .. " seconds")
				end
			end
		elseif self.current_status == "pathing" then
			if self:GetPos():Distance( self.current_stuck_position ) > STUCK_RADIUS then
				self.current_stuck_position = self:GetPos()

				self.current_stuck_start = CurTime()

				if ShouldDisplayDebug( 2 ) then
					debugoverlay.Sphere( self.current_stuck_position, 100, 1.5, color_green_box, false )
				end
			else
				local minMoveSpeed = 0.1 * self.current_speed + 0.1
				local escapeTime = STUCK_RADIUS / minMoveSpeed;
				if ( CurTime() - self.current_stuck_start ) > escapeTime then
					self.m_isStuck = true
				end
			end
		end

		if navmesh.IsLoaded() then
			// target player is off the nav

			local ply = self.current_player_goal
			if self.current_action == DRONE_TO_FOLLOW_PLAYER and IsValid( ply ) then
				self.current_player_nav = navmesh.GetNearestNavArea( ply:GetPos(), false, 200, false )

				if !self.current_path_climbing and ply:GetMoveType() ~= MOVETYPE_LADDER and !IsValid( self.current_player_nav ) and self.generator_spot_valid then
					self.current_player_goal = NULL

					self.break_current_path = true
					self:CurrentPathCompleted()

					self.time_to_next_action = CurTime() + 0.5
					self.current_action = DRONE_TO_IDLE
				end

				if IsValid( self.current_player_nav ) then
					// player ladder climbing detection

					if IsValid( self.current_player_goal ) and self.current_player_goal:GetMoveType() == MOVETYPE_LADDER then
						local navLadder = self:GetPlayerLadder( self.current_player_goal, self.current_player_nav )

						if !self.current_path_climbing_with_player and IsValid( navLadder ) and IsValid( self.current_ladder ) and navLadder == self.current_ladder then
							self.current_path_climbing_with_player = true
							self.current_ladder_dismount = 0

							if ShouldDisplayDebug( 1 ) then
								self:GetOwner():ChatPrint("[DRONE] Climbing ladder with Player")
							end
						end

						self.current_player_ladder = navLadder
					else
						if self.current_path_climbing_with_player then
							self.current_path_climbing_with_player = false
						end

						self.current_player_ladder = NULL
					end
				end

				// TODO: to be used when the player is stood on a moving brush / prop
				// in conjunction with the player orbit action state as there will be no navmesh

				if IsValid(ply) and ply:IsOnGround() then
					local groundEnt = ply:GetGroundEntity()

					if IsValid( groundEnt ) and IsValid( groundEnt:GetMoveParent() ) and groundEnt:GetMoveParent():GetMoveType() == MOVETYPE_PUSH then
						groundEnt = groundEnt:GetMoveParent()
					end

					if IsValid( groundEnt ) and groundEnt:GetMoveType() == MOVETYPE_PUSH and !string_find( groundEnt:GetClass(), "_door_rotating" ) then
						self.current_player_ground_entity = groundEnt

					elseif IsValid( self.current_player_ground_entity ) then
						self.current_player_ground_entity = NULL
					end
				end
			end

			// were off the nav

			if !self:IsPathing() and !IsValid( self.current_nav ) and ( self:GetCreationTime() + engine.TickInterval() > CurTime() ) then
				local tempNav = navmesh.GetNearestNavArea( self.current_ground_position, false, 256, false )

				if IsValid( tempNav ) and ( tempNav:GetZ() + 64 ) >= self.current_ground_position.z then
					if !self:DirectPathToScripted( tempNav ) then
						self:TeleportToHome()
					end
				else
					self:TeleportToHome()
				end
			end
		end
	end
end

function ENT:AugerThink()
	if !self.HasShotDown or self:GetDestroyed() then
		return
	end

	if self.fl_AugerTime < CurTime() then
		PlaySound( "weapons/tfa_bo2/drone/exp/air_explo_0" .. math.random( 0, 2 ) .. ".wav", self:GetPos(), SNDLVL_TALKING, math.random( 97, 103 ), 1 )

		self:StopSound( "TFA_BO2_ZMDRONE.Idle" )
		self:StopSound( "TFA_BO2_ZMDRONE.Hum" )

		/*if IsValid( ply ) then
			ply:EmitSound( "TFA_BO2_SHIELD.Break" )
		end*/

		self:SetDestroyed( true )

		self:SetSaveValue( "m_lifeState", LIFE_DEAD )

		if !self:IsOnGround() then
			self:DropToFloor()
		end

		self:SetPos( self:GetPos() + vector_up * 2 )
		self:SetAngles( Angle( 0, self:GetAngles()[2], 0 ) )

		self:SetMoveType( MOVETYPE_NONE )
		self:SetLocalVelocity( vector_origin )

		self.fl_AugerTime = math.huge
	end

	local vecDirection = Vector( 0, 0, -1 ) + Vector( math.sin( CurTime() * 12 ) * 1.2, math.cos( CurTime() * 12 ) * 1.2, math.Rand( 0, 0.2 ) )

	local angles = self:GetLocalAngles()

	angles.y = angles.y + math.Rand( -AUGER_YDEVIANCE, AUGER_YDEVIANCE )
	angles.x = angles.x + math.Rand( -AUGER_XDEVIANCEDOWN, AUGER_XDEVIANCEUP )

	self:SetLocalAngles( angles )

	self.cursor_position = self:GetPos()
	self.current_move_dir = vecDirection

	local flRatio = 1 - math.Clamp( ( self.fl_AugerTime - CurTime() ) / self.AugerTime, 0, 1 )
	self:SetLocalVelocity( vecDirection * ( easedLerpOutQuad( flRatio, 0, self.AugerSpeed ) ) )
end

function ENT:TurbineDecay()
	if self:GetDestroyed() or self.HasShotDown then return end

	if self.DecayDelay < CurTime() then
		self:TakeDamage(5, self)

		self.DecayDelay = CurTime() + 1
	end
end

//////////////////////////// navigational functions ////////////////////////////

function ENT:UpdatePathStep( lastPath )
	self.next_ladder_direction = nil
	self.next_ladder_step = 0
	self.next_ladder = NULL

	if #self.current_path_ladders > 0 then
		for i, ladder in pairs( self.current_path_ladders ) do
			if IsValid( ladder ) and i > self.current_path_step and self.current_paths[ i ] then
				self.next_ladder_direction = self.current_paths[ i ].type
				self.next_ladder_step = i
				self.next_ladder = ladder
				break
			end
		end
	end

	self.current_ladder = NULL
	self.current_elevator = NULL
	self.current_door = NULL

	if lastPath then
		self.last_path = lastPath
		self.last_position = lastPath.pos
		self.last_nav = lastPath.area
	end

	self.last_path_step_complete_time = CurTime()

	self.cursor_position = self.current_status == "climbing" and self:GetPos() or self.last_position

	self.current_path_completed = false

	self.current_path = self.current_paths[ self.current_path_step ]
	self.current_path_nav = self.current_path.area
	self.current_path_goal = self.current_path.pos
	self.current_path_length = self.current_path.length
	self.current_path_distance = self.current_path.distanceFromStart
	self.current_path_type = self.current_path.type
	self.current_path_direction = ( self.current_path_goal - self.last_position ):GetNormalized()
	self.current_path_climbing = tobool( self.current_path.climbing )
end

function ENT:CurrentPathCompleted()
	if !self:IsPathing() then
		return
	end

	local lastPath = self.current_paths[ self.current_path_step ]
	local lastStep = self.current_path_step

	self.last_path_ladder_dismounted = self:IsDismountingLadder()

	if lastPath then
		self.last_goal_crouched = tobool( lastPath.crouch )
	end

	if ShouldDisplayDebug( 2 ) then
		self:GetOwner():ChatPrint("[DRONE] Completed Step [" .. self.current_path_step .. "]")
	end

	self.current_path_dismount_ladder = false

	self.current_path_step = self.current_path_step + 1

	if ( self.current_path_step > #self.current_paths ) or self.break_current_path then
		self.cursor_position = self.current_path_goal

		self.break_current_path = nil

		self.next_ladder_direction = nil
		self.next_ladder_step = 0
		self.next_ladder = NULL

		self.current_ladder = NULL
		self.current_elevator = NULL
		self.current_door = NULL

		self.current_ladder_dismount = DRONE_DISMOUNT_NONE

		self.current_path_completed = true
		self.current_path_climbing = false

		self.current_path_step = lastStep
		self.current_status = "idling"

		self.current_action_retrys = 0

		local newRandom = CurTime() + math.Rand( self.random_wait_delay_min, self.random_wait_delay_max )
		self.next_random_turn = math.max( self.next_random_turn, newRandom )

		if lastPath then
			self.desired_angled = ( self.current_path_goal - lastPath.pos ):Angle()
		end

		self.current_path_goal = nil

		self:ResetBlocked()
		self:ResetStuck()

		if self.ActionCompleted[ self.current_action ] then
			self.ActionCompleted[ self.current_action ]( self )
		end
	else
		self:ResetStuck()

		self:UpdatePathStep( lastPath )

		// reset climbing status
		if !self.current_path_climbing and self.current_status == "climbing" then
			self.current_status = "pathing"
			self.current_ladder_dismount = DRONE_DISMOUNT_NONE
		end
	end
end

function ENT:StartPathing()
	if IsValid( self.path_generator ) then
		self.path_generator:Remove()
		self.path_generator = nil
	end

	self:TraceToGround()

	if !self.generator_spot_valid then
		self.forced_action = self.current_action
		self.time_to_next_action = CurTime() + 0.05

		self.current_action = DRONE_TO_IDLE

		self.current_path_retrys = 1 + self.current_path_retrys

		// try to find a nearby square to path from instead
		// if all else fails, go home

		if self.current_path_retrys > 3 or self:GetDestroyed() then
			self:TeleportToHome()
		else
			self:TeleportToNearestNav()
		end
		return
	end

	self.current_path_retrys = 0

	local angForward = self:GetAngles()
	angForward:SetUnpacked( 0, angForward[ 2 ], 0 )

	self.path_generator = ents.Create( "bo2_drone_pathing" )
	self.path_generator:SetPos( self.generator_position )
	self.path_generator:SetAngles( angForward )

	self.path_generator:SetOwner( self )

	self.path_generator:SetHealth( 0 )
	self.path_generator:SetMaxHealth( 0 )

	self.path_generator:Spawn()
	self.path_generator:Activate()

	//self.path_generator:DropToFloor()

	self:DeleteOnRemove( self.path_generator )
end

function ENT:GeneratePath( PathFollower, nextbot )
	if !IsValid( PathFollower ) or !IsValid( nextbot ) then
		self.current_action_retrys = self.current_action_retrys + 1
		self.forced_action = self.current_action

		if self.current_status == "roaming" then
			if self.current_action == DRONE_TO_FOLLOW_PLAYER then
				// force retry pathing
				self.next_random_roam = CurTime() + 0.05
				self.next_random_turn = CurTime() + math.Rand( self.random_wait_delay_min, self.random_wait_delay_max )
			end
		else
			// force retry the current action, and reset to idle for calculations
			self.time_to_next_action = CurTime() + 0.05
			self.current_action = DRONE_TO_IDLE
		end

		// cannot schedule tasks unless idling
		print("DRONE FAILED '" .. t_EnumNames[self.forced_action] or "ERROR" .. "'\nINVALID PATH")
		self.current_status = "idling"
		return
	end

	local tempPaths = PathFollower:GetAllSegments()

	local mFilter = { self }
	table.Add( mFilter, player.GetAll() )

	// add final path going directly to scripted goal
	if self.current_action == DRONE_TO_SCRIPTED and self.current_scripted_goal then
		local position = self.current_scripted_goal
		if IsEntity( position ) then
			position = position:GetPos()
		end

		if IsEntity( self.current_scripted_goal ) then
			table.insert( mFilter, self.current_scripted_goal )
		end

		local trace = {}
		util_TraceLine({
			start = position,
			endpos = position + vector_down_64,
			mask = MASK_NPCSOLID_BRUSHONLY,
			filter = mFilter,
			output = trace,
		})

		local final_step = tempPaths[#tempPaths]
		local new_length = trace.HitPos:Distance( final_step.pos )

		local newPath = {
			area = navmesh.GetNearestNavArea( trace.HitPos, false, 200 ),
			curvature = 0,
			distanceFromStart = final_step.distanceFromStart + new_length,
			forward = ( final_step.pos - trace.HitPos ):GetNormalized(),
			how = 9,
			ladder = NULL,
			length = new_length,
			pos = position,
			type = 0,
			scripted = true,
		}

		tempPaths[#tempPaths + 1] = newPath
	end

	// for stopping the path at the point of failure
	local bSuccess = true

	// trace from initial path segment position to flying height, and from current pos to next pos
	local trace = {}

	// trace from fly path position to ceiling to adjust
	local trace2 = {}

	// hull trace from top to bottom of path segment ground position to flying position for final adjustment
	local tracehull = {}

	// CNavAreas that contains a door ( used to stop infinite recursion )
	local doorNavs = {}

	local vecLast = self:GetPos()
	local vecOrigin = Vector( vecLast )

	local nTotalLength = 0
	local nTotalPaths = #tempPaths

	local flHoverHeight = tonumber( self.current_ground_distance )
	local flCeilingHeight = tonumber( self.ceiling_distance )

	if ShouldDisplayDebug( 1 ) then
		debugoverlay.Cross( vecLast, 15, 6, color_white, true )
	end

	local revive_target = self.current_revive_player

	local vecMins, vecMaxs = self:GetCollisionBounds()
	local nHullHeight = ( vecMaxs[3] + math.abs( vecMins[3] ) )
	local nHullWidth = math.max( vecMaxs[1], vecMaxs[2] ) * 2

	vecMins:Sub( vecPadding )
	vecMaxs:Add( vecPadding )

	// reset ladders
	self.current_path_ladders = {}
	self.current_path_elevators = {}

	for i, data in pairs( tempPaths ) do
		if !bSuccess then
			data.failure = true
			continue
		end

		local navArea = data.area
		local bNavArea = IsValid( navArea )
		local navLadder = data.ladder
		local bLadderUp = ( data.type == LADDER_UP )
		local bDoorInterrupt = false
		local bCrouched = bNavArea and ( bit.band( navArea:GetAttributes(), NAV_MESH_CROUCH ) ~= 0 ) or false

		// final path height when reviving a player
		if i == nTotalPaths and IsValid( revive_target ) then
			flHoverHeight = revive_target:GetPos():Distance( revive_target:EyePos() + vecOrbitOffset )
		end

		if bNavArea and bCrouched then
			flHoverHeight = tonumber( self.ground_crouch_distance )
			flCeilingHeight = tonumber( self.ceiling_crouch_distance )
		elseif flHoverHeight < ( self.ground_distance - self.ground_crouch_distance ) then
			flHoverHeight = tonumber( self.ground_distance )
			flCeilingHeight = tonumber( self.ceiling_distance )
		end

		// exiting a crouch nav
		if !bCrouched then
			local last_path = tempPaths[ i - 1 ]
			if last_path and tobool( last_path.crouch ) then
				flHoverHeight = tonumber( self.ground_crouch_distance )
				flCeilingHeight = tonumber( self.ceiling_crouch_distance )
			end
		end

		// ground level where path node is
		local vecFloor = Vector()

		// what will end up being the fly path position
		local vecEnd = data.pos + vector_up

		// test position to calculate fly path position
		local vecHeight = data.pos + ( vector_up * flHoverHeight )

		// determine ladder position
		if IsValid( navLadder ) and data.type > JUMP_OVER_GAP then
			self.current_path_ladders[ i ] = navLadder

			vecEnd = ( bLadderUp and navLadder:GetBottom() or navLadder:GetTop() ) + ( navLadder:GetNormal() * ( nHullWidth - 4 ) ) + vector_up
			vecHeight = vecEnd + ( vector_up * flHoverHeight )
		end

		// uhhh, yeahhhhh
		if bNavArea and data.type == ON_GROUND then
			if IsValid( nextbot ) and nextbot.current_path_elevators_areas and nextbot.current_path_elevators_areas[ navArea ] then
				self.current_path_elevators[ i ] = nextbot.current_path_elevators_areas[ navArea ]
			end

			local sizeX = navArea:GetSizeX() / 2
			local sizeY = navArea:GetSizeY() / 2
			local vecCenter = navArea:GetCenter()
			local vecPathDir = Vector( data.forward )

			// find doors within navarea bounds
			if !doorNavs[ navArea:GetID() ] then
				local navMins = Vector( -sizeX, -sizeY, 0 )
				local navMaxs = Vector( sizeX, sizeY, flHoverHeight )

				navMins:Add( vecCenter )
				navMaxs:Add( vecCenter )

				for _, entity in ipairs( ents.FindInBox( navMins, navMaxs ) ) do
					if IsValid( entity ) and entity:GetMoveType() == MOVETYPE_PUSH and t_DoorClasses[ entity:GetClass() ] then
						local bDoorVisible = navArea:IsPartiallyVisible( entity:WorldSpaceCenter(), entity )
						if bDoorVisible then
							if !self.current_path_doors[ i ] then
								self.current_path_doors[ i ] = {}

								doorNavs[ navArea:GetID() ] = entity

								local class = entity:GetClass()

								local bFuncDoor = string_find( class, "func" )
								local bPropDoor = string_find( class, "prop" )

								local nToggleState = entity:GetInternalVariable( "m_toggle_state" ) or 0 // open or close
								local nDoorState = entity:GetInternalVariable( "m_eDoorState" ) or 0 // open or close (or other)

								local bOpen = false
								if bFuncDoor and ( nToggleState == TS_AT_TOP or nToggleState == TS_GOING_UP ) then
									bOpen = true
								end
								if bPropDoor and ( nDoorState == DOOR_STATE_OPEN or nDoorState == DOOR_STATE_OPENING ) then
									bOpen = true
								end

								if !bOpen then
									local vecSpot = entity:NearestPoint( vecCenter ) + vecPathDir * 48
									local nNavDir = navArea:ComputeDirection( Vector( vecSpot[1], vecSpot[2], vecCenter[3] ) )

									local new_length = vecSpot:Distance( data.pos )

									local newPath = {
										area = navmesh.GetNearestNavArea( vecSpot, false, 32 ),
										curvature = 0,
										distanceFromStart = data.distanceFromStart + new_length,
										forward = ( data.pos - vecSpot ):GetNormalized(),
										how = nNavDir,
										ladder = NULL,
										length = new_length,
										pos = vecSpot,
										type = 0,
									}

									tempPaths[ i + 1 ] = newPath
								end

								if ShouldDisplayDebug( 2 ) then
									debugoverlay.Box( vecCenter, Vector( -sizeX, -sizeY, 0 ), Vector( sizeX, sizeY, flHoverHeight ), 4, Color( 255, 255, 255, 10 ) )
								end
							end

							table.insert( self.current_path_doors[ i ], entity )

							if ShouldDisplayDebug( 2 ) then
								debugoverlay.Text( entity:NearestPoint(  entity:GetPos() ), "Door Position", 5)
								debugoverlay.Axis( entity:NearestPoint(  entity:GetPos() + self.current_ground_offset ), entity:GetAngles(), 15, 5, true)
							end
						end
					end
				end

				if self.current_path_doors[ i ] and #self.current_path_doors[ i ] > 1 then
					table.sort( self.current_path_doors[ i ], function( a, b )
						return a:GetPos():DistToSqr( vecEnd ) < b:GetPos():DistToSqr( vecEnd )
					end )
				end
			end

			// adjust our position relative to door
			local entity = doorNavs[ navArea:GetID() ]
			if IsValid( entity ) then
				local class = entity:GetClass()

				local bFuncDoor = string_find( class, "func" )
				local bPropDoor = string_find( class, "prop" )

				local nToggleState = entity:GetInternalVariable( "m_toggle_state" ) or 0 // open or close
				local nDoorState = entity:GetInternalVariable( "m_eDoorState" ) or 0 // open or close (or other)

				local bOpen = false
				if bFuncDoor and ( nToggleState == TS_AT_TOP or nToggleState == TS_GOING_UP ) then
					bOpen = true
				end
				if bPropDoor and ( nDoorState == DOOR_STATE_OPEN or nDoorState == DOOR_STATE_OPENING ) then
					bOpen = true
				end

				if !bOpen then
					local vecSpot = entity:NearestPoint( Vector( vecCenter[1], vecCenter[2], entity:WorldSpaceCenter()[3] + 8 ) ) + vecPathDir * 48
					local nNavDir = navArea:ComputeDirection( Vector( vecSpot[1], vecSpot[2], vecCenter[3] ) )

					local bOpposite = ( nNavDir == GO_SOUTH or nNavDir == GO_WEST )
					local bDirNorth = ( nNavDir == GO_NORTH or nNavDir == GO_SOUTH ) or false
					local flWidth = bDirNorth and sizeY or sizeX

					local vecNavDir = ( navArea:GetCorner( 1 ) - navArea:GetCorner( bDirNorth and 2 or 0 ) ):GetNormalized()
					if ( bOpposite ) then
						vecNavDir:Negate()
					end

					local vecPoint = PointOnSegmentNearestToPoint( vecCenter - vecNavDir * flWidth, vecCenter + vecNavDir * flWidth, vecEnd )

					vecEnd = vecPoint + vector_up

					vecHeight = Vector( vecPoint[1], vecPoint[2], entity:WorldSpaceCenter()[3] + 8 )

					if ShouldDisplayDebug( 1 ) then
						debugoverlay.Cross( vecSpot, 25, 6, color_yellow, true )

						debugoverlay.Line( vecCenter - vecNavDir * flWidth, vecCenter + vecNavDir * flWidth, 5, color_yellow, true )
					end
				end
			end
		end

		// current segment distance
		local flDistance = 0

		if ShouldDisplayDebug( 1 ) then
			debugoverlay.Text( vecEnd + vector_up * 10, "Movement [" .. t_MoveTypes[ data.type ] .. "]", 5 )
			debugoverlay.Text( vecEnd + vector_up * 15, "Traversal [" .. t_TraverseTypes[ data.how ] .. "]", 5 )

			debugoverlay.Cross( vecEnd, 10, 6, color_blue, true )
			debugoverlay.Cross( vecHeight, 10, 6, color_blue, true )

			debugoverlay.Text( vecHeight + vector_up * 5, "Path [" .. i .. "]", 5 )
		end

		// trace from top to bottom to determine actual floor position ( path segment can spawn on brushes placed under displacements )
		util_TraceLine({
			start = vecHeight,
			endpos = vecEnd,
			mask = MASK_NPCSOLID_BRUSHONLY,
			filter = mFilter,
			output = trace,
		})

		if ShouldDisplayDebug( 1 ) then
			debugoverlay.Line( vecEnd, vecHeight, 5, trace.Hit and color_red or color_blue, true )
		end

		if trace.StartSolid then
			// top position is inside world, trace from bottom to top

			util_TraceLine({
				start = vecEnd,
				endpos = vecHeight,
				mask = MASK_NPCSOLID_BRUSHONLY,
				filter = mFilter,
				output = trace,
			})

			vecFloor:Set( vecEnd )
			vecEnd = trace.HitPos
		else
			vecFloor:Set( trace.HitPos )
			vecEnd = trace.StartPos
		end

		if ( self.current_action == DRONE_TO_SCRIPTED and self.current_scripted_goal and data.scripted ) or data.climbing or data.use_original_pos then
			// fly to given endpos instead of generating one
			vecEnd = tempPaths[ i ].pos
		end

		util_TraceLine({
			start = vecEnd,
			endpos = vecEnd + vector_up * flCeilingHeight,
			mask = MASK_NPCSOLID_BRUSHONLY,
			filter = mFilter,
			output = trace2,
		})

		// offset from ceiling by set distance
		if trace2.Hit then
			local offset = ( ( 1 - trace2.Fraction ) * flCeilingHeight ) + vecMaxs[3]
			vecEnd = trace2.HitPos - vector_up * offset
		end

		//debugoverlay.Cross( vecEnd, 15, 6, color_red, true )

		util_TraceHull({
			start = vecEnd,
			endpos = vecEnd,
			maxs = vecMaxs,
			mins = vecMins,
			mask = MASK_NPCSOLID,
			collisiongroup = COLLISION_GROUP_WORLD,
			filter = mFilter,
			output = tracehull,
		})

		if tracehull.Hit then
			// not enough space at flying position
			// check at 4 different points vertically
			// to determine a new spot along the flight path

			debugoverlay.Text( tracehull.HitPos, "BLOCKED", 5 )

			//local bFound = false
			for i2 = 1, math.Round( 4 * trace.Fraction ) do
				local flGroundDist = ( flHoverHeight / i2 ) * trace.Fraction
				local vecCur = vecFloor + vector_up * flGroundDist

				util_TraceHull({
					start = vecCur,
					endpos = vecCur,
					maxs = vecMaxs,
					mins = vecMins,
					mask = MASK_NPCSOLID,
					collisiongroup = COLLISION_GROUP_WORLD,
					filter = mFilter,
					output = tracehull,
				})

				if ShouldDisplayDebug( 1 ) then
					debugoverlay.Box( vecCur, vecMins, vecMaxs, 6, tracehull.Hit and color_red_box or color_blue_box )
				end

				if !tracehull.Hit and !tracehull.StartSolid and util.IsInWorld( vecCur - vector_up * ( nHullHeight * 0.5 ) ) then
					vecEnd = vecCur
					//bFound = true
					break
				end
			end

			/*if !bFound then
				bSuccess = false
				data.failure = true
				continue
			end*/
		elseif ShouldDisplayDebug( 1 ) then
			debugoverlay.Box( vecEnd, vecMins, vecMaxs, 6, color_blue_box )
		end

		if !bSuccess then
			data.failure = true
			continue
		end

		local vecDirection = ( vecEnd - vecLast ):GetNormalized()

		util_TraceLine({
			start = vecLast,
			endpos = vecEnd,
			mask = MASK_NPCSOLID_BRUSHONLY,
			filter = mFilter,
			output = trace,
		})

		if trace.Hit then
			if ShouldDisplayDebug( 2 ) then
				debugoverlay.Line( vecLast, vecEnd, 6, color_red, true )
			end

			// if something is interupting our flight path
			// use crossproduct to deflect along the hit surface

			local vecUp = vecDirection:Cross( trace.HitNormal )
			local vecDeflect = trace.Normal:Cross( vecUp )
			vecDeflect:Normalize()

			util_TraceLine( {
				start = trace.HitPos,
				endpos = trace.HitPos + ( vecDeflect * ( nHullWidth * 1.25 ) ),          
				mask = MASK_NPCSOLID_BRUSHONLY,
				filter = mFilter,
				output = trace,
			} )

			if ShouldDisplayDebug( 2 ) then
				debugoverlay.Line( trace.StartPos, trace.HitPos, 6, trace.Hit and color_red or color_yellow, true )
			end

			util_TraceLine( {
				start = vecLast,
				endpos = trace.HitPos,          
				mask = MASK_NPCSOLID_BRUSHONLY,
				filter = mFilter,
				output = trace,
			} )

			if ShouldDisplayDebug( 2 ) then
				debugoverlay.Line( trace.StartPos, trace.HitPos, 6, trace.Hit and color_red or color_yellow, true )
			end

			// if were still blocked, give up
			if trace.Hit then
				bSuccess = false
				data.failure = true
				continue
			else
				vecEnd = trace.HitPos
			end
		end

		flDistance = vecLast:Distance( vecEnd )

		// trace bounding box along path segment to validate it
		nLayer = 0
		local nCount = math.Round( flDistance / 32 )
		for i2 = 1, nCount do
			local vecCur = vecLast + vecDirection * ( ( i2 * 32 ) - 16 )

			bSuccess = TraceHullAlongPath( vecCur, vecMins, vecMaxs, vecDirection, tracehull, mFilter )

			if !bSuccess then
				break
			end
		end

		if !bSuccess then
			data.failure = true
			continue
		end

		// new possible path end position
		vecDirection = ( vecEnd - vecLast ):GetNormalized()
		flDistance = vecLast:Distance( vecEnd )
		nTotalLength = nTotalLength + flDistance

		if ShouldDisplayDebug( 1 ) then
			local vectext = math.Truncate( vecEnd[1], 2 ) .. "," .. math.Truncate( vecEnd[2], 2 ) .. "," .. math.Truncate( vecEnd[3], 2 )
			debugoverlay.Text( vecEnd - vector_up * 5, "[" .. vectext .. "]", 5 )

			debugoverlay.Line( vecLast, vecEnd, 6, color_white, true )
		end

		vecLast:Set( vecEnd )

		tempPaths[ i ].startpos = tempPaths[ i ].pos
		tempPaths[ i ].pos = vecEnd
		tempPaths[ i ].forward = vecDirection
		tempPaths[ i ].length = flDistance
		tempPaths[ i ].distanceFromStart = nTotalLength
		tempPaths[ i ].crouch = bCrouched

		if IsValid( navLadder ) and data.type > JUMP_OVER_GAP and !data.climbing then
			local newNav = bLadderUp and navLadder:GetTopForwardArea() or navLadder:GetBottomArea()
			if !IsValid( newNav ) and bLadderUp then
				newNav = navLadder:GetTopBehindArea()
			end

			local vecTop = ( bLadderUp and navLadder:GetTop() or navLadder:GetBottom() ) + ( navLadder:GetNormal() * ( nHullWidth - 6 ) ) + ( vector_up * flHoverHeight )

			local newPath = {
				area = IsValid( newNav ) and newNav or navmesh.GetNearestNavArea( navLadder:GetTop(), false, 32 ),
				curvature = 0,
				distanceFromStart = nTotalLength + navLadder:GetLength(),
				forward = ( vecEnd - vecTop ):GetNormalized(),
				how = data.area:ComputeDirection( IsValid( newNav ) and newNav:GetCenter() or ( navLadder:GetTop() + navLadder:GetNormal() * ( data.type == LADDER_DOWN and nHullWidth or -nHullWidth ) ) ),
				ladder = navLadder,
				length = navLadder:GetLength(),
				pos = vecTop,
				type = data.type,
				climbing = true,
			}

			table.insert( tempPaths, i + 1, newPath )

			if ShouldDisplayDebug( 1 ) then
				debugoverlay.Line( vecEnd, vecTop, 6, color_green, true )
			end
		end
	end

	for i = 1, #tempPaths do
		local data = tempPaths[ i ]
		if data and data.failure then
			table.remove( tempPaths, i )
			continue
		end
	end

	PathFollower:Invalidate()

	if table.IsEmpty( tempPaths ) then
		self.current_action_retrys = self.current_action_retrys + 1
		self.forced_action = self.current_action

		if self.current_status == "roaming" then
			if self.current_action == DRONE_TO_FOLLOW_PLAYER then
				self.next_random_roam = CurTime() + 0.05
				self.next_random_turn = CurTime() + math.Rand( self.random_wait_delay_min, self.random_wait_delay_max )
			end
		else
			self.time_to_next_action = CurTime() + 0.05
			self.current_action = DRONE_TO_IDLE
		end

		if ShouldDisplayDebug( 1 ) then
			self:GetOwner():ChatPrint("[DRONE] FAILED '" .. t_EnumNames[self.forced_action] or "ERROR" .. "' NO VALID PATHING SPOTS")
		end
		self.current_status = "idling"
		return
	end

	// reset path data

	self.last_position = self:GetPos()

	self.current_path_completed = false

	self.current_ladder_dismount = 0
	self.break_current_path = nil
	self.forced_action = nil

	self.last_repath_time = CurTime()
	self.current_path_start = CurTime()

	// new path data

	self.current_paths = tempPaths
	self.current_path_step = 1
	self.current_path = self.current_paths[ 1 ]
	self.current_path_nav = self.current_path.area
	self.current_path_goal = self.current_path.pos
	self.current_path_length = self.current_path.length
	self.current_path_length_total = nTotalLength
	self.current_path_distance = self.current_path.distanceFromStart
	self.current_path_type = self.current_path.type
	self.current_path_direction = ( self.current_path_goal - self.last_position ):GetNormalized()
	self.current_path_climbing = tobool( self.current_path.climbing )

	self.cursor_position = self.last_position

	self.final_path = self.current_paths[ #self.current_paths ]
	self.final_path_goal = self.final_path.pos

	self.current_path_failure = self.final_path_goal:Distance( self.last_position ) < 16
	/*if IsValid( self.current_player_goal ) and self.current_path_direction:Dot( ( self.current_player_goal:GetPos() - self.last_position ):GetNormalized() ) <= 0.2 and #self.current_path_ladders <= 0 and self.current_path_length_total > self.player_repath_distance and self.current_player_goal:GetPos():Distance( self.current_path_goal ) > self.player_repath_distance then
		self.current_path_failure = true
	end*/

	local pathDoor = self:GetClosestPathDoor( self.current_path_step )
	local navLadder = self.current_path_ladders[ self.current_path_step ]
	local bClimbing = self.current_path_climbing and IsValid( navLadder )

	self.current_ladder = bClimbing and navLadder or NULL
	self.current_door = IsValid( pathDoor ) and pathDoor or NULL

	if #self.current_path_ladders > 0 then
		for i, ladder in pairs( self.current_path_ladders ) do
			if IsValid( ladder ) and i > self.current_path_step then
				self.next_ladder_step = i
				self.next_ladder = ladder
				break
			end
		end
	end

	self.current_status = "pathing"
end

function ENT:CanRandomlyRoam()
	if self.current_status == "climbing" then
		return false
	end

	// player is off the nav, dont roam
	if self.current_action == DRONE_TO_FOLLOW_PLAYER and not IsValid( self.current_player_nav ) then
		return false
	end

	local ply = self.current_player_goal
	if !IsValid( ply ) then
		return false
	end

	if ply:IsPlayer() and ply:GetPos():DistToSqr( self.current_ground_trace.Hit and self.current_ground_position or self.generator_position ) > self.player_force_roam_distance^2 then // 800^2
		// player is too far away, repath
		return true
	end

	return self.next_random_roam < CurTime()
end

//////////////////////////// vox functions ////////////////////////////

function ENT:SetNextVox( enum )
	if !enum or !isstring( enum ) or !self.MaxisVoxTable[ enum ] then return end

	self.maxis_vox_next = enum
end

function ENT:ScheduleNextVox( enum )
	if !enum or !isstring( enum ) or !self.MaxisVoxTable[ enum ] then return end

	if !self.last_scheduled_vox or self.last_scheduled_vox ~= enum then
		self.last_scheduled_vox = enum

		if timer.Exists( "MaxisDrone.VoxSchedule" ) then
			timer.Remove( "MaxisDrone.VoxSchedule" )
		end

		timer.Create( "MaxisDrone.VoxSchedule", 0, 0, function()
			if !IsValid( self ) then
				timer.Remove( "MaxisDrone.VoxSchedule" )
				return
			end

			if !self.maxis_vox_next and self.maxis_vox_current ~= enum then
				if self.maxis_vox_last and self.maxis_vox_last == enum and self.MaxisVoxTable[ self.maxis_vox_last ] and self.MaxisVoxTable[ self.maxis_vox_last ]["wait"] then
					if self.maxis_vox_wait + self.MaxisVoxTable[ self.maxis_vox_last ]["wait"] < CurTime() then
						return
					end
				end

				self.maxis_vox_next = enum

				timer.Remove( "MaxisDrone.VoxSchedule" )
			end
		end )
	end
end

function ENT:VoxThink()
	if self:GetDestroyed() then return end

	if !self.maxis_vox_next then
		if ( !self.maxis_vox_ambient_wait or self.maxis_vox_ambient_wait < CurTime() ) and math.random( 100 ) == 1 then
			self.maxis_vox_ambient_wait = CurTime() + self.MaxisVoxTable["Ambient"]["wait"] * math.Rand( 0.95, 1.05 )
			self.maxis_vox_next = "Ambient"
		else
			return
		end
	end

	if self.maxis_vox_next == "Attack" and !IsValid( self:GetTarget() ) then
		self.maxis_vox_next = nil
	end

	if self.maxis_vox_wait < CurTime() or ( self.maxis_vox_current and self.MaxisVoxTable[ self.maxis_vox_current ] and tobool( self.MaxisVoxTable[ self.maxis_vox_current ][ "interrupt" ] ) and self.maxis_vox_next ~= self.maxis_vox_current ) then
		self.maxis_vox_last = self.maxis_vox_current
		self.maxis_vox_current = self.maxis_vox_next

		if self.MaxisVoxTable[ self.maxis_vox_current ] then
			self.maxis_vox_wait = CurTime() + self.MaxisVoxTable[ self.maxis_vox_current ][ "length" ] or 3

			local voxData = self.MaxisVoxTable[ self.maxis_vox_current ][ "vox" ]
			if voxData then
				local finalSound = istable( voxData ) and voxData[ math.random( #voxData ) ] or voxData
				self:EmitSound( finalSound, SNDLVL_NORM, 100, 0.9, CHAN_VOICE )

				hook.Call( "MaxisDroneVoxEmit", nil, self, self:GetOwner(), self.maxis_vox_current, finalSound )
			end
		end

		self.maxis_vox_next = nil
	end
end
