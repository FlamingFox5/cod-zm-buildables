SWEP.Base = "tfa_gun_base"

SWEP.BuildableDistance = 40
SWEP.BuildableWallOffset = 12
SWEP.BuildableHeightOffset = 0
SWEP.BuildableAligned = true

SWEP.BuildableMaxHealth = 500

SWEP.BuildableWallPlaceable = false
SWEP.BuildableWallOffset = 80

SWEP.BuildableSetupBones = true

SWEP.BuildableHologram = true

SWEP.BuildableDeployOrigin = false

SWEP.DrawViewModel = false
SWEP.ShowViewModel = false

SWEP.Instructions = "Place down with PrimaryAttack, Rotate with SecondaryAttack"

DEFINE_BASECLASS(SWEP.Base)

local cvarStyle = GetConVar("cl_tfa_fx_buildable_hologram_style")

local sp = game.SinglePlayer()
local nzombies = engine.ActiveGamemode() == "nzombies"

local color_red = Color(255, 0, 0, 0)
local color_red_full = Color(255, 0, 0, 255)
local vecPadding = Vector(2, 2, 1)

function SWEP:SetupDataTables()
	BaseClass.SetupDataTables(self)

	self:NetworkVarTFA("Bool", "Flipped")
	self:SetFlipped(false)
end

function SWEP:NotifyPlaceMessage()
	local ply = self:GetOwner()

	if IsValid(ply) and ply:IsPlayer() and IsFirstTimePredicted() and (not ply._TFA_LastJamMessage or ply._TFA_LastJamMessage < RealTime()) then
		ply:PrintMessage(HUD_PRINTCENTER, "COULD NOT FIND AREA TO PLACE")
		ply._TFA_LastJamMessage = RealTime() + 1
	end
end

function SWEP:CanPrimaryAttack(...)
	local ply = self:GetOwner()
	if not IsValid(ply) then return end

	local mSetupData = self:SetupPlaceable()
	if !mSetupData or !mSetupData["Valid"] then
		if SERVER then
			self:NotifyPlaceMessage()
		end
		return false
	end

	return BaseClass.CanPrimaryAttack(self, ...)
end

function SWEP:PreSpawnProjectile(ent)
	if self.BuildableMaxHealth and self.BuildableMaxHealth > 0 then
		local nMaxHealth = self.BuildableMaxHealth or 500
		local nHealthFac = math.max( nMaxHealth / 100, 0 )
		local flRatio = (self:Clip1() / self.Primary_TFA.ClipSize) * 100

		ent:SetMaxHealth( nMaxHealth )
		ent:SetHealth( math.Round( flRatio * nHealthFac ) )
	end

	if self.BuildableWallOffset then
		ent.BuildableWallOffset = self.BuildableWallOffset
	end

	if self.BuildableMaxBounds and self.BuildableMinBounds then
		ent:SetCollisionBounds(self.BuildableMinBounds, self.BuildableMaxBounds)
		ent.BuildableMaxBounds = self.BuildableMaxBounds
		ent.BuildableMinBounds = self.BuildableMinBounds
	end

	if ent.SetTrapClass then
		ent:SetTrapClass( self:GetClass() )
	end

	local mSetupData = self:SetupPlaceable()

	ent:SetPos( mSetupData["Position"] )
	ent:SetAngles( mSetupData["Angle"] - ( self.BuildableAngleOffset or angle_zero ) )

	local hitEntity = mSetupData["Entity"]
	if IsValid( hitEntity ) then
		// parent to vehicles / push movetype entities or dynamic models / brush models tied to one
		local hMoveParent = hitEntity:GetMoveParent()
		if ( hitEntity:IsVehicle() or hitEntity:GetMoveType() == MOVETYPE_PUSH ) or ( IsValid( hMoveParent ) and hMoveParent:GetMoveType() == MOVETYPE_PUSH ) then
			ent:SetParent( hitEntity )
		end
	end 
end

function SWEP:PostPrimaryAttack()
	local ply = self:GetOwner()

	if SERVER then
		if nzombies then
			ply:SetUsingSpecialWeapon(false)
			ply:EquipPreviousWeapon()
		end

		if ply.StripWeapon then
			ply:StripWeapon(self:GetClass())
		else
			self:Remove()
		end
	end
end

function SWEP:SecondaryAttack()
	local self2 = self:GetTable()
	local ply = self:GetOwner()
	if not IsValid(ply) then return end

	if not IsValid(self) then return end
	if ply:IsPlayer() and not self:VMIV() then return end
	if self:GetNextSecondaryFire() > CurTime() then return end

	self:SetFlipped(not self:GetFlipped())
	self:SetNextSecondaryFire(CurTime() + 0.1)
end

function SWEP:SwitchToPreviousWeapon()
	local wep = LocalPlayer():GetPreviousWeapon()

	if IsValid(wep) and wep:IsWeapon() and wep:GetOwner() == LocalPlayer() then
		input.SelectWeapon(wep)
	else
		wep = LocalPlayer():GetWeapon(cl_defaultweapon:GetString())

		if IsValid(wep) then
			input.SelectWeapon(wep)
		else
			local _
			_, wep = next(LocalPlayer():GetWeapons())

			if IsValid(wep) then
				input.SelectWeapon(wep)
			end
		end
	end
end

// we dont actually use the viewmodel but ill keep this anyways
function SWEP:CalcViewModelView(vm, oldeyepos, oldeyeang, eyepos, eyeang)
	local mSetupData = self:SetupPlaceable()

	return mSetupData[ "Position" ], mSetupData[ "Angle" ]
end

// we dont use the worldmodel either, but for the sake of NPCs and when not held by a player
function SWEP:DrawWorldModel( ... )
	local ply = self:GetOwner()

	if not IsValid( ply ) then
		return BaseClass.DrawWorldModel( self, ... )
	end

	if ply:IsPlayer() then
		return
	end

	if G_BuildableHologram:GetModel() ~= self:GetWeaponWorldModel() then
		G_BuildableHologram:SetModel( self:GetWeaponWorldModel() )
	end

	local mSetupData = self:SetupPlaceable()

	render.SetBlend( 1 )
	render.SetColorModulation( 1, 1, 1 )

	if mSetupData then
		G_BuildableHologram:SetPos( mSetupData[ "Position" ] )
		G_BuildableHologram:SetAngles( mSetupData[ "Angle" ] )

		G_BuildableHologram:SetupBones()

		if G_BuildableHologram.LastManipulatedBone then
			G_BuildableHologram:ManipulateBoneAngles( G_BuildableHologram.LastManipulatedBone, angle_zero )
		end
	else
		G_BuildableHologram:SetPos( self:GetPos() )
		G_BuildableHologram:SetAngles( self:GetAngles() )
	end

	if mSetupData[ "Valid" ] then
		G_BuildableHologram:SetMaterial( "" )

		G_BuildableHologram:DrawModel()
	end
end

// credit 'PlaasBoer' on roblox dev forums
local function intersection_point(line_1_start, line_1_end, line_2_start, line_2_end)
	local line_1_m = (line_1_end[2] - line_1_start[2]) / (line_1_end[1] - line_1_start[1])
	local line_2_m = (line_2_end[2] - line_2_start[2]) / (line_2_end[1] - line_2_start[1])
	local line_1_b = line_1_start[2] - (line_1_m * line_1_start[1])
	local line_2_b = line_2_start[2] - (line_2_m * line_2_start[1])
	local intersect_x = (line_2_b - line_1_b) / (line_1_m - line_2_m)
	local intersect_z = (line_1_m * intersect_x) + line_1_b
	return Vector(intersect_x, intersect_z, line_1_start[3])
end

local t_MovetypeIgnore = {
	[MOVETYPE_PUSH] = true,
	[MOVETYPE_NONE] = true,
}

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

function SWEP:SetupPlaceable()	
	local ply = self:GetOwner()
	if not IsValid( ply ) then
		return
	end

	// cache the variables for that frame, ala PLAYER:GetEyeTrace()
	if CLIENT then
		local framenum = FrameNumber()

		if self.LastPlaceableSetup == framenum then
			return self.PlaceableSetup
		end

		self.LastPlaceableSetup = framenum
	end

	local bSuccess = true
	local bFlipped = ( self.GetFlipped and self:GetFlipped() ) or false
	local vecFinal = ply:GetPos()
	local vecHull, vecFloor, bGrounded, bFloater, flDot
	local nRange = self.BuildableDistance or 40
	local nStepHeight = 16
	local vecStart = ply.GetShootPos and ply:GetShootPos() or ply:EyePos()
	local qAngAim = ply:EyeAngles()
	local qAngFwd = Angle( 0, qAngAim[2], 0 )
	local qAngFinal = Angle()

	local mFilter = { self }
	table.Add( mFilter, player.GetAll() )

	local vecMins, vecMaxs = self:GetModelBounds()
	if self.BuildableMaxBounds then
		vecMaxs:Set( self.BuildableMaxBounds )
	end
	if self.BuildableMinBounds then
		vecMins:Set( self.BuildableMinBounds )
	end

	local nHullHalf = vecMaxs[3] / 2
	local vecUpHalf = Vector( 0, 0, nHullHalf )

	// trace from eyes & trace to floor
	local trace = {}

	// trace from feet & floater check
	local trace2 = {}

	// criss cross trace for OOB & floater check
	local trace3 = {}

	if ply.GetHull then
		_, vecHull = ply:GetHull()

		if ply.GetStepSize then
			nStepHeight = ply:GetStepSize()
		elseif ply.GetStepHeight then
			nStepHeight = ply:GetStepHeight()
		end
	else
		_, vecHull = ply:GetCollisionBounds()
		if ply.GetStepHeight then
			nStepHeight = ply:GetStepHeight()
		end
	end

	// wall placeables check
	if self.BuildableWallPlaceable then
		local trace1 = {}

		util.TraceLine({
			start = vecStart,
			endpos = vecStart + qAngAim:Forward() * ( self.BuildableWallReach or nRange ),
			filter = mFilter,
			mask = bit.bor( MASK_SHOT, CONTENTS_GRATE ),
			output = trace1,
		})

		flDot = trace1.HitNormal:Dot( vector_up )
		local hitEntity = trace1.Entity

		bSuccess = IsValidToPlaceOn( hitEntity, trace1.HitWorld ) and ( trace.MatType ~= MAT_SLOSH )

		local bMoveableEnt = false
		if IsValid( hitEntity ) then
			local hMoveParent = hitEntity:GetMoveParent()
			if ( hitEntity:IsVehicle() or hitEntity:GetMoveType() == MOVETYPE_PUSH ) or ( IsValid( hMoveParent ) and hMoveParent:GetMoveType() == MOVETYPE_PUSH ) then
				bMoveableEnt = true
			end
		end

		if ( trace1.HitWorld or bMoveableEnt ) and ( flDot <= 0.5 ) and ( flDot >= -0.1 ) then
			vecStart = trace1.HitPos + trace1.HitNormal*0.1

			--debugoverlay.Line( trace1.StartPos, vecStart, FrameTime(), trace1.Hit and color_red or color_white, true )

			local qAngWall = trace1.HitNormal:Angle() + ( bFlipped and Angle( -90, 180, 0 ) or Angle( 90, 0, 0 ) )
			qAngWall:RotateAroundAxis( trace1.HitNormal, qAngWall.z - trace1.HitNormal:Angle().z )

			vecMins:Add( vecPadding )
			vecMaxs:Sub( vecPadding )

			--debugoverlay.BoxAngles( vecStart, vecMins, vecMaxs, qAngWall, FrameTime(), color_red )

			// half-assed check to make sure the 4 corners are unobstructed
			local corner1 = vecStart + ( qAngWall:Forward() * vecMaxs[1] ) + ( qAngWall:Right() * -vecMins[2] ) + ( qAngWall:Up() * nHullHalf )
			local corner2 = vecStart + ( qAngWall:Forward() * vecMins[1] ) + ( qAngWall:Right() * -vecMins[2] ) + ( qAngWall:Up() * nHullHalf )

			--debugoverlay.Axis( corner1, qAngWall, 5, FrameTime(), true )
			--debugoverlay.Axis( corner2, qAngWall, 5, FrameTime(), true )

			vecMins:Rotate( qAngWall )
			vecMaxs:Rotate( qAngWall )

			local corner3 = vecStart + Vector( vecMaxs[1], vecMaxs[2], vecMins[3] ) - ( qAngWall:Up() * nHullHalf )
			local corner4 = vecStart + Vector( vecMaxs[1], vecMaxs[2], vecMaxs[3] ) - ( qAngWall:Up() * nHullHalf )

			--debugoverlay.Axis( corner3, qAngWall, 5, FrameTime(), true )
			--debugoverlay.Axis( corner4, qAngWall, 5, FrameTime(), true )

			if bSuccess then
				util.TraceLine( {
					start = corner1,
					endpos = corner3,
					filter = mFilter,
					mask = MASK_SOLID,
					output = trace3,
				} )

				if trace3.Hit then
					bSuccess = false
				end

				--debugoverlay.Line( corner1, corner3, FrameTime(), trace3.Hit and color_red or color_white, true )

				util.TraceLine( {
					start = corner2,
					endpos = corner3,
					filter = mFilter,
					mask = MASK_SOLID,
					output = trace3,
				} )

				if trace3.Hit then
					bSuccess = false
				end

				--debugoverlay.Line( corner2, corner3, FrameTime(), trace3.Hit and color_red or color_white, true )

				util.TraceLine( {
					start = corner3,
					endpos = corner4,
					filter = mFilter,
					mask = MASK_SOLID,
					output = trace3,
				} )

				if trace3.Hit then
					bSuccess = false
				end

				--debugoverlay.Line( corner3, corner4, FrameTime(), trace3.Hit and color_red or color_white, true )

				util.TraceLine( {
					start = corner1,
					endpos = corner2,
					filter = mFilter,
					mask = MASK_SOLID,
					output = trace3,
				} )

				if trace3.Hit then
					bSuccess = false
				end

				--debugoverlay.Line( corner1, corner2, FrameTime(), trace3.Hit and color_red or color_white, true )

				util.TraceLine( {
					start = corner1,
					endpos = corner4,
					filter = mFilter,
					mask = MASK_SOLID,
					output = trace3,
				} )

				if trace3.Hit then
					bSuccess = false
				end

				--debugoverlay.Line( corner1, corner4, FrameTime(), trace3.Hit and color_red or color_white, true )
			end

			self.PlaceableSetup = { ["Position"] = vecStart, ["Angle"] = qAngWall, ["Normal"] = trace.HitNormal, ["Valid"] = trace1.Hit and bSuccess, ["Entity"] = hitEntity }

			return self.PlaceableSetup
		end
	end

	// player origin placeable check
	if self.BuildableDeployOrigin then
		util.TraceLine({
			start = vecStart,
			endpos = ply:GetPos() - ( vector_up * nStepHeight ),
			filter = mFilter,
			mask = MASK_PLAYERSOLID,
			output = trace,
		})

		flDot = trace.HitNormal:Dot( vector_up )
		bSuccess = IsValidToPlaceOn( trace.Entity, trace.HitWorld ) and flDot > 0.84 and ( trace.MatType ~= MAT_SLOSH )

		if trace.HitWorld then
			vecStart = trace.HitPos + trace.HitNormal*0.1

			vecMins:Add( vecPadding )
			vecMaxs:Sub( vecPadding )

			--debugoverlay.BoxAngles( vecStart, vecMins, vecMaxs, qAngFwd, FrameTime(), color_red )

			// half-assed check to make sure the 4 corners are unobstructed
			local corner1 = vecStart + ( qAngFwd:Forward() * vecMaxs[1] ) + vecUpHalf + ( qAngFwd:Right() * -vecMins[2] )
			local corner2 = vecStart + ( qAngFwd:Forward() * vecMins[1] ) + vecUpHalf + ( qAngFwd:Right() * -vecMaxs[2] )

			--debugoverlay.Axis( corner1, qAngFwd, 5, FrameTime(), true )
			--debugoverlay.Axis( corner2, qAngFwd, 5, FrameTime(), true )

			vecMins:Rotate( qAngFwd )
			vecMaxs:Rotate( qAngFwd )

			local corner3 = vecStart + Vector( vecMins[1], vecMins[2], nHullHalf )
			local corner4 = vecStart + Vector( vecMaxs[1], vecMaxs[2], nHullHalf )

			--debugoverlay.Axis( corner3, qAngFwd, 5, FrameTime(), true )
			--debugoverlay.Axis( corner4, qAngFwd, 5, FrameTime(), true )

			bGrounded = bSuccess and ( ply:IsOnGround() or ply:GetMoveType() == MOVETYPE_LADDER ) or ( ply:GetPos()[3] <= ( trace.HitPos[3] + 24 ) )
			bSuccess = bGrounded

			if bSuccess then
				util.TraceLine( {
					start = corner1,
					endpos = corner2,
					filter = mFilter,
					mask = MASK_SOLID,
					output = trace3,
				} )

				if trace3.Hit then
					bSuccess = false
				end

				--debugoverlay.Line( corner1, corner2, FrameTime(), trace3.Hit and color_red or color_white, true )

				util.TraceLine( {
					start = corner2,
					endpos = corner3,
					filter = mFilter,
					mask = MASK_SOLID,
					output = trace3,
				} )

				if trace3.Hit then
					bSuccess = false
				end

				--debugoverlay.Line( corner2, corner3, FrameTime(), trace3.Hit and color_red or color_white, true )

				util.TraceLine( {
					start = corner2,
					endpos = corner4,
					filter = mFilter,
					mask = MASK_SOLID,
					output = trace3,
				} )

				if trace3.Hit then
					bSuccess = false
				end

				--debugoverlay.Line( corner2, corner4, FrameTime(), trace3.Hit and color_red or color_white, true )

				util.TraceLine( {
					start = corner1,
					endpos = corner3,
					filter = mFilter,
					mask = MASK_SOLID,
					output = trace3,
				} )

				if trace3.Hit then
					bSuccess = false
				end

				--debugoverlay.Line( corner1, corner3, FrameTime(), trace3.Hit and color_red or color_white, true )

				util.TraceLine( {
					start = corner1,
					endpos = corner4,
					filter = mFilter,
					mask = MASK_SOLID,
					output = trace3,
				} )

				if trace3.Hit then
					bSuccess = false
				end

				--debugoverlay.Line( corner1, corner4, FrameTime(), trace3.Hit and color_red or color_white, true )
			end

			self.PlaceableSetup = { ["Position"] = vecStart, ["Angle"] = qAngFwd, ["Normal"] = trace.HitNormal, ["Valid"] = bSuccess }

			return self.PlaceableSetup
		end
	end

	// eye level
	util.TraceLine({
		start = vecStart,
		endpos = vecStart + qAngFwd:Forward() * ( nRange + vecMaxs[1] ),
		filter = mFilter,
		mask = MASK_PLAYERSOLID,
		output = trace,
	})

	local vecStart2 = ply:GetPos() + vector_up * nStepHeight

	// ground level
	util.TraceLine({
		start = vecStart2,
		endpos = vecStart2 + qAngFwd:Forward() * ( nRange + vecMaxs[1] ),
		filter = mFilter,
		mask = MASK_PLAYERSOLID,
		output = trace2,
	})

	--debugoverlay.Line( vecStart, trace.HitPos, FrameTime(), trace.Hit and color_red or color_white, true )

	--debugoverlay.Line( vecStart2, trace2.HitPos, FrameTime(), trace2.Hit and color_red or color_white, true )

	// prioritize lower trace
	if trace2.Hit then
		trace = table.Copy( trace2 )
	end

	// align with the wall, facing towards the player
	if trace.Hit then
		qAngFwd = Angle( 0, trace.HitNormal:Angle()[2], 0 )

		// custom wall offsets cause yeah
		vecStart = trace.HitPos + qAngFwd:Forward() * ( self.BuildableWallOffset )
	else
		// move the starting point of the ground trace back by the width of the model
		vecStart = trace.HitPos - trace.Normal * ( vecMaxs[1] + 1 )
	end

	// downwards trace from the endpos of the previous trace(s)
	util.TraceLine({
		start = vecStart,
		endpos = vecStart - Vector( 0, 0, vecHull[3] + ( math.max( nStepHeight, 24 ) ) ),
		filter = mFilter,
		mask = MASK_PLAYERSOLID,
		output = trace,
	})

	--debugoverlay.Line( trace.StartPos, trace.HitPos, FrameTime(), trace.Hit and color_white or color_red, true )

	bSuccess = trace.Hit
	flDot = trace.HitNormal:Dot( vector_up )

	// if we dont hit the floor, check to see if were stood on intersecting walls and if theres enough support to place
	if not bSuccess then
		local vecEnd = trace.HitPos + qAngFwd:Forward() * ( vecMaxs[1] / 2 )

		util.TraceLine( {
			start = trace.HitPos + qAngFwd:Forward() * ( vecMins[1] / 2 ),
			endpos = vecEnd,
			filter = mFilter,
			mask = MASK_SOLID,
			output = trace2,
		} )

		--debugoverlay.Line( trace2.StartPos, trace2.HitPos, FrameTime(), trace2.Hit and color_red or color_white, true )

		vecEnd = trace.HitPos - qAngFwd:Right() * ( vecMaxs[2] / 2 )

		util.TraceLine( {
			start = trace.HitPos - qAngFwd:Right() * ( vecMins[2] / 2 ),
			endpos = vecEnd,
			filter = mFilter,
			mask = MASK_SOLID,
			output = trace3,
		} )

		if (!trace2.StartSolid and !trace3.StartSolid) and trace2.HitWorld and trace3.HitWorld and ( trace2.HitNormal:Dot( trace3.HitNormal ) < 0.9 ) then
			bFloater = true
			bSuccess = true
		end

		--debugoverlay.Line( trace3.StartPos, trace3.HitPos, FrameTime(), trace3.Hit and color_red or color_white, true )
	end

	// down trace must hit floor and the player must be either grounded, within stepheight of the hitpos, or on a ladder
	bGrounded = bSuccess and ( trace.MatType ~= MAT_SLOSH ) and ( ply:IsOnGround() or ply:GetMoveType() == MOVETYPE_LADDER or ( ply:GetPos()[3] <= ( trace.HitPos[3] + math.max( nStepHeight, 24 ) ) ) )
	bSuccess = bGrounded and IsValidToPlaceOn( trace.Entity, trace.HitWorld ) and ( flDot > 0.84 or flDot == 0 )

	vecMins:Add( vecPadding )
	vecMaxs:Sub( vecPadding )

	// level with the bottom of the players hull
	vecFloor = vecStart - Vector( 0, 0, ( ply:EyePos()[3] - ply:GetPos()[3] ) )

	if bFloater then
		trace.HitPos = Vector( trace.HitPos[1], trace.HitPos[2], vecFloor[3] )
	end

	// level with the floor
	vecStart = trace.HitPos + ( vector_up * ( self.BuildableHeightOffset or 0 ) )

	vecFinal:Set( bGrounded and vecStart or vecFloor )

	// align with the floor normal
	qAngFinal:Set( qAngFwd )
	if trace.Hit and flDot > 0.81 and bSuccess then
		qAngFinal = trace.HitNormal:Angle()
		qAngFinal:RotateAroundAxis( trace.HitNormal:Angle():Right(), -90 )

		// we should kill whoever invented vector math
		local nDiff = qAngFwd[2] - qAngFinal[2]
		qAngFinal:RotateAroundAxis( trace.HitNormal:Angle():Forward(), nDiff )

		if bFlipped then
			qAngFinal:RotateAroundAxis( trace.HitNormal:Angle():Forward(), 180 )
		end
	elseif bFlipped then
		qAngFinal:RotateAroundAxis( vector_up, 180 )
	end

	if bFlipped then
		qAngFwd:RotateAroundAxis( vector_up, -180 )
	end

	--debugoverlay.BoxAngles( vecFinal, vecMins, vecMaxs, qAngFwd, FrameTime(), color_red )

	// half-assed check to make sure 4 corners are unobstructed
	local corner1 = vecFinal + ( qAngFwd:Forward() * vecMaxs[1] ) + vecUpHalf + ( qAngFwd:Right() * -vecMins[2] )
	local corner2 = vecFinal + ( qAngFwd:Forward() * vecMins[1] ) + vecUpHalf + ( qAngFwd:Right() * -vecMaxs[2] )

	--debugoverlay.Axis( corner1, qAngFwd, 5, FrameTime(), true )
	--debugoverlay.Axis( corner2, qAngFwd, 5, FrameTime(), true )

	vecMins:Rotate( qAngFwd )
	vecMaxs:Rotate( qAngFwd )

	local corner3 = vecFinal + Vector( vecMins[1], vecMins[2], nHullHalf )
	local corner4 = vecFinal + Vector( vecMaxs[1], vecMaxs[2], nHullHalf )

	--debugoverlay.Axis( corner3, qAngFwd, 5, FrameTime(), true )
	--debugoverlay.Axis( corner4, qAngFwd, 5, FrameTime(), true )

	if bSuccess then
		util.TraceLine( {
			start = corner1,
			endpos = corner2,
			filter = mFilter,
			mask = MASK_SOLID,
			output = trace3,
		} )

		if trace3.Hit then
			bSuccess = false
		end

		--debugoverlay.Line( corner1, corner2, FrameTime(), trace3.Hit and color_red or color_white, true )

		util.TraceLine( {
			start = corner2,
			endpos = corner3,
			filter = mFilter,
			mask = MASK_SOLID,
			output = trace3,
		} )

		if trace3.Hit then
			bSuccess = false
		end

		--debugoverlay.Line( corner2, corner3, FrameTime(), trace3.Hit and color_red or color_white, true )

		util.TraceLine( {
			start = corner2,
			endpos = corner4,
			filter = mFilter,
			mask = MASK_SOLID,
			output = trace3,
		} )

		if trace3.Hit then
			bSuccess = false
		end

		--debugoverlay.Line( corner2, corner4, FrameTime(), trace3.Hit and color_red or color_white, true )

		util.TraceLine( {
			start = corner1,
			endpos = corner3,
			filter = mFilter,
			mask = MASK_SOLID,
			output = trace3,
		} )

		if trace3.Hit then
			bSuccess = false
		end

		--debugoverlay.Line( corner1, corner3, FrameTime(), trace3.Hit and color_red or color_white, true )

		util.TraceLine( {
			start = corner1,
			endpos = corner4,
			filter = mFilter,
			mask = MASK_SOLID,
			output = trace3,
		} )

		if trace3.Hit then
			bSuccess = false
		end

		--debugoverlay.Line( corner1, corner4, FrameTime(), trace3.Hit and color_red or color_white, true )
	end

	--debugoverlay.EntityTextAtPosition( vecFinal + vecUpHalf, 1, math.Round( flDot, 4 ), FrameTime(), flDot > 0.84 and color_white or color_red_full)

	// invalid floor angle
	if flDot < 0.84 then
		--debugoverlay.Text( vecFinal + vecUpHalf, "X", FrameTime(), false)
	end

	--debugoverlay.Axis( vecFinal, qAngFinal, 10, FrameTime(), true)

	self.PlaceableSetup = { ["Position"] = vecFinal, ["Angle"] = qAngFinal, ["Normal"] = trace.HitNormal, ["Valid"] = bSuccess, ["Entity"] = trace.Entity }

	return self.PlaceableSetup
end
