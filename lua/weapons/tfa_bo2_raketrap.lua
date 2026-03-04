local nzombies = engine.ActiveGamemode() == "nzombies"

SWEP.Base = "tfa_melee_base"
SWEP.Category = "TFA Zombies Buildables"
SWEP.Spawnable = TFA_BASE_VERSION and TFA_BASE_VERSION >= 4.74
SWEP.AdminSpawnable = true
SWEP.UseHands = true
SWEP.Type_Displayed = "#tfa.weapontype.buildable.trap"
SWEP.Purpose = "Custom buildable trap by SirJammy. \nFrom the W@W map 'Nuketown Remastered'"
SWEP.Author = "FlamingFox, SirJammy"
SWEP.Slot = 0
SWEP.PrintName = nzombies and "Rake Trap | BO2" or "Rake Trap"
SWEP.DrawCrosshair = false
SWEP.DrawCrosshairIS = false
SWEP.AutoSwitchTo = false
SWEP.AutoSwitchFrom = true

--[Model]--
SWEP.ViewModel			= "models/weapons/tfa_bo2/raketrap/c_raketrap.mdl"
SWEP.ViewModelFOV = 65
SWEP.WorldModel			= "models/weapons/tfa_bo2/raketrap/w_raketrap.mdl"
SWEP.HoldType = "melee2"
SWEP.SprintHoldTypeOverride = "melee2"
SWEP.CameraAttachmentOffsets = {}
SWEP.CameraAttachmentScale = 2
SWEP.VMPos = Vector(0, 0, 0)
SWEP.VMAng = Vector(0, 0, 0)
SWEP.VMPos_Additive = true

SWEP.Offset = { --Procedural world model animation, defaulted for CS:S purposes.
	Pos = {
		Up = 42,
		Right = 1,
		Forward = 1,
	},
	Ang = {
		Up = -20,
		Right = -90,
		Forward = 0
	},
	Scale = 1
}

--[Gun Related]--
SWEP.Primary.Sound = "TFA_BO2_RAKETRAP.Slice"
SWEP.Primary.Sound_Hit = "TFA_BO2_RAKETRAP.Hit"
SWEP.Primary.Sound_HitFlesh = "TFA_BO3_GENERIC.Gib"
SWEP.Primary.DamageType = bit.bor(DMG_CLUB, DMG_PREVENT_PHYSICS_FORCE)
SWEP.Primary.RPM = 100
SWEP.Primary.Damage = 115
SWEP.Primary.MaxCombo = 0
SWEP.Secondary.Damage = 115
SWEP.Secondary.MaxCombo = 0
SWEP.Secondary.Automatic = false
SWEP.Delay = 0.35

SWEP.Primary.ClipSize = 100
SWEP.Primary.DefaultClip = 100
SWEP.Primary.AmmoConsumption = 0
SWEP.Primary.Ammo = "none"

--[Traces]--
SWEP.Primary.Attacks = {
	{
		["act"] = ACT_VM_HITCENTER, -- Animation; ACT_VM_THINGY, ideally something unique per-sequence
		["len"] = 70, -- Trace distance
		["src"] = Vector(0, 0, 0), -- Trace source; X ( +right, -left ), Y ( +forward, -back ), Z ( +up, -down )
		["dir"] = Vector(-60, 15, -40), -- Trace direction/length; X ( +right, -left ), Y ( +forward, -back ), Z ( +up, -down )
		["dmg"] = SWEP.Primary.Damage, --Damage
		["dmgtype"] = SWEP.Primary.DamageType,
		["delay"] = 4 / 30, --Delay
		["spr"] = true, --Allow attack while sprinting?
		["snd"] = SWEP.Primary.Sound, -- Sound ID
		["hitflesh"] = SWEP.Primary.Sound_Hit,
		["hitworld"] = SWEP.Primary.Sound_Hit,
		["viewpunch"] = Angle(0, 0, 0), --viewpunch angle
		["end"] = 1, --time before next attack
		["hull"] = 10, --Hullsize
	}
}

--[Projectile]--
SWEP.Primary.Projectile         = "bo2_trap_raketrap"
SWEP.Primary.ProjectileVelocity = 0
SWEP.Primary.ProjectileModel    = "models/weapons/tfa_bo2/raketrap/w_raketrap.mdl"

--[Stuff]--
SWEP.ImpactDecal = "ManhackCut"
SWEP.InspectPos = Vector(6, -2, -2)
SWEP.InspectAng = Vector(5, 25, 15)
SWEP.Secondary.CanBash = false
SWEP.AllowSprintAttack = false
SWEP.RunSightsPos = Vector(0, 1, 2)
SWEP.RunSightsAng = Vector(-20, 0, 15)

--[Buildable]--
SWEP.BuildableDistance = 40
SWEP.BuildableWallOffset = 8
SWEP.BuildableHeightOffset = 0

SWEP.BuildableAligned = false
SWEP.BuildableMaxBounds = Vector(64, 5, 12)
SWEP.BuildableMinBounds = Vector(-2, -5, 0)

SWEP.BuildableDeployOrigin = true

SWEP.BuildableMaxHealth = 500

--[NZombies]--
SWEP.NZWonderWeapon = false
SWEP.NZSpecialCategory = "trap"
SWEP.NZSpecialWeaponData = {MaxAmmo = 0, AmmoType = "none"}
SWEP.NZHudIcon = Material("vgui/icon/hud_icon_rake_trap.png", "unlitgeneric smooth")
SWEP.NZHudDimension = 64

SWEP.TrapCanBePlaced = true
SWEP.SpeedColaFactor = 1
SWEP.SpeedColaActivities = {
	[ACT_VM_RELOAD] = true,
	[ACT_VM_RELOAD_EMPTY] = true,
	[ACT_VM_RELOAD_SILENCED] = true,
}

function SWEP:NZSpecialHolster(wep)
	return true
end

--[Tables]--
SWEP.SequenceRateOverride = {
}

SWEP.EventTable = {
[ACT_VM_DRAW] = {
{ ["time"] = 5 / 30, ["type"] = "sound", ["value"] = Sound("TFA_BO2_SHIELD.Recover") },
},
[ACT_VM_HOLSTER] = {
{ ["time"] = 0, ["type"] = "sound", ["value"] = Sound("TFA_BO2_SHIELD.Recover") },
},
[ACT_VM_HITCENTER] = {
{ ["time"] = 0, ["type"] = "sound", ["value"] = Sound("TFA_BO2_RAKETRAP.Swing") },
},
}

--[Shit]--
SWEP.AllowViewAttachment = true --Allow the view to sway based on weapon attachment while reloading or drawing, IF THE CLIENT HAS IT ENABLED IN THEIR CONVARS.
SWEP.Sprint_Mode = TFA.Enum.LOCOMOTION_LUA -- ANI = mdl, HYBRID = ani + lua, Lua = lua only
SWEP.Sights_Mode = TFA.Enum.LOCOMOTION_HYBRID -- ANI = mdl, HYBRID = lua but continue idle, Lua = stop mdl animation
SWEP.Idle_Mode = TFA.Enum.IDLE_BOTH --TFA.Enum.IDLE_DISABLED = no idle, TFA.Enum.IDLE_LUA = lua idle, TFA.Enum.IDLE_ANI = mdl idle, TFA.Enum.IDLE_BOTH = TFA.Enum.IDLE_ANI + TFA.Enum.IDLE_LUA
SWEP.Idle_Blend = 0.25 --Start an idle this far early into the end of a transition
SWEP.Idle_Smooth = 0.05 --Start an idle this far early into the end of another animation
SWEP.SprintBobMult = 1

DEFINE_BASECLASS(SWEP.Base)

local color_red = Color(255, 0, 0, 0)
local vecPadding = Vector(2, 2, 1)

function SWEP:SecondaryAttack()
	local self2 = self:GetTable()
	local ply = self:GetOwner()
	if not IsValid(ply) then return end

	if not IsValid(self) then return end
	if ply:IsPlayer() and not self:VMIV() then return end
	if not self:CanPrimaryAttack() then return end

	self:SendViewModelAnim(ACT_VM_PULLPIN)
	self:ScheduleStatus(TFA.Enum.STATUS_GRENADE_PULL, self:GetActivityLength())
	self:SetNextPrimaryFire(self:GetStatusEnd())
end

function SWEP:Reload()
	if self:GetStatus() == TFA.Enum.STATUS_GRENADE_READY and self:GetOwner():KeyDown(IN_ATTACK2) then
		self:SendViewModelAnim(ACT_VM_DEPLOY)
		self:ScheduleStatus(TFA.Enum.STATUS_BASHING, self:GetActivityLength())
		self:SetNextPrimaryFire(self:GetStatusEnd())
	end
end

function SWEP:Think2(...)
	if self:GetOwner():IsPlayer() then
		local stat = self:GetStatus()
		local statusend = CurTime() >= self:GetStatusEnd()
		local ply = self:GetOwner()

		if stat == TFA.Enum.STATUS_GRENADE_PULL and statusend then
			self:SetStatus(TFA.Enum.STATUS_GRENADE_READY, math.huge)
		end

		if stat == TFA.Enum.STATUS_GRENADE_READY and not ply:KeyDown(IN_ATTACK2) then
			self:ThrowStart()
		end

		if stat == TFA.Enum.STATUS_GRENADE_READY and self:GetSprinting() then
			self:SendViewModelAnim(ACT_VM_DEPLOY)
			self:ScheduleStatus(TFA.Enum.STATUS_BASHING, self:GetActivityLength())
			self:SetNextPrimaryFire(self:GetStatusEnd())
		end

		if stat == TFA.Enum.STATUS_GRENADE_THROW and statusend then
			if SERVER then
				self:PlantShield()
			end
			self:SetStatus(TFA.Enum.STATUS_IDLE)
		end
	end

	return BaseClass.Think2(self, ...)
end

function SWEP:ThrowStart()
	local ply = self:GetOwner()
	local success, tanim, animType = self:ChooseShootAnim()
	self:ScheduleStatus(TFA.Enum.STATUS_GRENADE_THROW, self.Delay)

	if success then
		self.LastNadeAnim = tanim
		self.LastNadeAnimType = animType
		self.LastNadeDelay = self.Delay
	end
end

function SWEP:ChooseShootAnim()
	if not self:OwnerIsValid() then return end

	if self:GetOwner():IsPlayer() then
		self:GetOwner():SetAnimation(PLAYER_ATTACK1)
	end

	local tanim = ACT_VM_THROW
	self:SendViewModelAnim(tanim)

	if sp then
		self:CallOnClient("AnimForce", tanim)
	end

	return true, tanim
end

function SWEP:NotifyPlaceMessage()
	local ply = self:GetOwner()

	if IsValid(ply) and ply:IsPlayer() and IsFirstTimePredicted() and (not ply._TFA_LastJamMessage or ply._TFA_LastJamMessage < RealTime()) then
		ply:PrintMessage(HUD_PRINTCENTER, "COULD NOT FIND AREA TO PLACE")
		ply._TFA_LastJamMessage = RealTime() + 1
	end
end

function SWEP:PlantShield()
	local mSetupData = self:SetupPlaceable()

	if not mSetupData["Valid"] then
		if self.NotifyPlaceMessage then
			self:NotifyPlaceMessage()
		end
		return
	end

	local ply = self:GetOwner()
	if not IsValid( ply ) then
		return
	end

	local ent = ents.Create(self.Primary_TFA.Projectile)
	ent:SetModel(self.Primary_TFA.ProjectileModel)
	ent:SetPos(mSetupData["Position"])
	ent:SetAngles(mSetupData["Angle"])
	ent:SetOwner(ply)

	if self.BuildableMaxBounds and self.BuildableMinBounds then
		local newMax = Vector(6.5, 10, 8)
		local newMin = Vector(-6.5, -10, 0)

		ent:SetCollisionBounds(newMin, newMax)
		ent.BuildableMaxBounds = newMax
		ent.BuildableMinBounds = newMin
	end

	local nMaxHealth = self.BuildableMaxHealth or 500
	local nHealthFac = math.max( nMaxHealth / 100, 0 )
	local flRatio = ( self:Clip1() / self:GetStatL("Primary.ClipSize") ) * 100

	ent:SetMaxHealth( nMaxHealth )
	ent:SetHealth( math.Round( flRatio * nHealthFac ) )

	if ent.SetTrapClass then
		ent:SetTrapClass( self:GetClass() )
	end

	local hitEntity = mSetupData["Entity"]
	if IsValid( hitEntity ) then
		// parent to vehicles / push movetype entities or dynamic models / brush models tied to one
		local hMoveParent = hitEntity:GetMoveParent()
		if ( hitEntity:IsVehicle() or hitEntity:GetMoveType() == MOVETYPE_PUSH ) or ( IsValid( hMoveParent ) and hMoveParent:GetMoveType() == MOVETYPE_PUSH ) then
			ent:SetParent( hitEntity )
		end
	end 

	ent:Spawn()

	ent:SetOwner(ply)

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

function SWEP:ApplyDamage(trace, dmginfo, attk)
	local ply = self:GetOwner()
	local ent = trace.Entity
	local dam, force = dmginfo:GetBaseDamage(), dmginfo:GetDamageForce()
	dmginfo:SetDamagePosition(trace.HitPos)
	dmginfo:SetReportedPosition(trace.StartPos)
	dmginfo:SetDamageForce(force*4)

	if nzombies and IsValid(ent) then
		dam = ent:Health() + 666
		if ent.NZBossType or ent.IsMooBossZombie then
			dam = ent:GetMaxHealth() / 8
		end

		dmginfo:SetDamage(dam)

		if SERVER and ply:IsPlayer() then
			self:TakePrimaryAmmo(math.random(5))
			if self:Clip1() <= 0 then
				self:EmitSound("TFA_BO2_SHIELD.Break")
				ply:SetUsingSpecialWeapon(false)
				ply:EquipPreviousWeapon()
				timer.Simple(0, function()
					if not IsValid(ply) or not IsValid(self) then return end
					ply:StripWeapon(self:GetClass())
				end)
			end
		end
	end

	ent:DispatchTraceAttack(dmginfo, trace, fwd)

	dmginfo:SetDamage(dam)

	self:ApplyForce(ent, dmginfo:GetDamageForce(), trace.HitPos)
end

local t_ShieldStatuses = {
	[TFA.Enum.STATUS_GRENADE_THROW] = true,
	[TFA.Enum.STATUS_GRENADE_READY] = true,
}

local color_warning = Color( 255, 255, 255, 127 )

function SWEP:PostDrawViewModel(vm, wep, ply, ...)
	if BaseClass.PostDrawViewModel then
		BaseClass.PostDrawViewModel( self, vm, wep, ply, ... )
	end

	if t_ShieldStatuses[self:GetStatus()] then
		local mSetupData = self:SetupPlaceable()
		if mSetupData and !mSetupData[ "Valid" ] then
			G_BuildableHologram:SetModel( self:GetWeaponViewModel() )

			// horrible z-fighting on the viewmodel, this doesnt fix it but helps a tiny bit
			local vecOffset = vm:GetAngles():Forward()*0.004

			G_BuildableHologram:SetPos( vm:GetPos() - vecOffset )
			G_BuildableHologram:SetAngles( vm:GetAngles() )
			G_BuildableHologram:SetSequence( vm:GetSequence() )
			G_BuildableHologram:SetPlaybackRate( vm:GetPlaybackRate() )
			G_BuildableHologram:SetCycle( vm:GetCycle() )

			if self.BuildableSetupBones then
				G_BuildableHologram:SetupBones()
			end

			G_BuildableHologram:SetMaterial( "models/weapons/v_slam/new light1.vmt" )

			render.SetBlend( 0.5 )

			render.SetColorModulation( 1, 1, 1 )

			G_BuildableHologram:DrawModel()

			render.SetBlend( 1 )
		end
	end
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

	if not self.BuildableDistance then
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
	local vecFinal = Vector()
	local vecHull, vecFloor, bGrounded, bHitWall, flDot
	local nStepHeight = 16
	local vecStart = ply.GetShootPos and ply:GetShootPos() or ply:EyePos()
	local qAngAim = ply:EyeAngles()
	local qAngFwd = Angle( 0, qAngAim.yaw, 0 )

	local mFilter = { self }
	table.Add( mFilter, player.GetAll() )

	local vecMins = Vector(-2, -5, 0)
	local vecMaxs = Vector(64, 5, 12)

	local nHullHalf = vecMaxs[3] / 2

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

	// eye level
	util.TraceLine({
		start = vecStart,
		endpos = vecStart + qAngFwd:Forward() * ( self.BuildableDistance ),
		filter = mFilter,
		mask = MASK_PLAYERSOLID,
		output = trace,
	})

	local vecStart2 = ply:GetPos() + vector_up * nStepHeight

	// ground level
	util.TraceLine({
		start = vecStart2,
		endpos = vecStart2 + qAngFwd:Forward() * ( self.BuildableDistance ),
		filter = mFilter,
		mask = MASK_PLAYERSOLID,
		output = trace2,
	})

	debugoverlay.Line( vecStart, trace.HitPos, FrameTime(), trace.Hit and color_red or color_white, true )

	debugoverlay.Line( vecStart2, trace2.HitPos, FrameTime(), trace2.Hit and color_red or color_white, true )

	// prioritize lower trace
	if trace2.Hit then
		trace = table.Copy( trace2 )
	end

	// align with the wall, facing towards the player
	if trace.Hit then
		bHitWall = true
		qAngFwd = Angle( 0, trace.HitNormal:Angle()[2], 0 )

		// custom wall offsets cause yeah
		vecStart = trace.HitPos + qAngFwd:Forward() * ( self.BuildableWallOffset )
	else
		// move the starting point of the ground trace back by the width of the model
		vecStart = trace.HitPos - trace.Normal * 6
	end

	// downwards trace from the endpos of the previous trace(s)
	util.TraceLine({
		start = vecStart,
		endpos = vecStart - Vector( 0, 0, vecHull[3] ),
		filter = mFilter,
		mask = MASK_PLAYERSOLID,
		output = trace,
	})

	debugoverlay.Line( trace.StartPos, trace.HitPos, FrameTime(), trace.Hit and color_white or color_red, true )

	// first check at mid point
	bSuccess = trace.Hit and IsValidToPlaceOn( trace.Entity, trace.HitWorld )

	vecFloor = ply:GetPos()

	// downwards trace from player position
	util.TraceLine({
		start = ply:EyePos(),
		endpos = vecFloor - ( Vector( 0, 0, nStepHeight ) ),
		filter = mFilter,
		mask = MASK_PLAYERSOLID,
		output = trace,
	})

	debugoverlay.Line( trace.StartPos, trace.HitPos, FrameTime(), trace.Hit and color_white or color_red, true )

	flDot = trace.HitNormal:Dot( vector_up )

	// second check at player origin
	bSuccess = bSuccess and trace.Hit and IsValidToPlaceOn( trace.Entity, trace.HitWorld ) and flDot > 0.84

	bGrounded = bSuccess and ( ( ply:IsOnGround() or ply:GetMoveType() == MOVETYPE_LADDER ) or ( ply:GetPos()[3] <= ( trace.HitPos[3] + 12 ) ) )
	bSuccess = bGrounded

	if bSuccess then
		if bHitWall then
			vecStart = Vector( vecStart[1], vecStart[2], trace.HitPos[3] )
		else
			vecStart = trace.HitPos + trace.HitNormal*0.1
		end

		vecMins:Add( vecPadding )
		vecMaxs:Sub( vecPadding )

		debugoverlay.BoxAngles( vecStart, vecMins, vecMaxs, qAngFwd, FrameTime(), color_red )

		// half-assed check to make sure the 4 corners are unobstructed
		local corner1 = vecStart + ( qAngFwd:Forward() * vecMaxs[1] ) + vector_up * nHullHalf + ( qAngFwd:Right() * -vecMins[2] )
		local corner2 = vecStart + ( qAngFwd:Forward() * vecMins[1] ) + vector_up * nHullHalf + ( qAngFwd:Right() * -vecMaxs[2] )

		debugoverlay.Axis( corner1, qAngFwd, 5, FrameTime(), true )
		debugoverlay.Axis( corner2, qAngFwd, 5, FrameTime(), true )

		vecMins:Rotate( qAngFwd )
		vecMaxs:Rotate( qAngFwd )

		local corner3 = vecStart + Vector( vecMins[1], vecMins[2], nHullHalf )
		local corner4 = vecStart + Vector( vecMaxs[1], vecMaxs[2], nHullHalf )

		debugoverlay.Axis( corner3, qAngFwd, 5, FrameTime(), true )
		debugoverlay.Axis( corner4, qAngFwd, 5, FrameTime(), true )

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

		debugoverlay.Line( corner1, corner2, FrameTime(), trace3.Hit and color_red or color_white, true )

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

		debugoverlay.Line( corner2, corner3, FrameTime(), trace3.Hit and color_red or color_white, true )

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

		debugoverlay.Line( corner2, corner4, FrameTime(), trace3.Hit and color_red or color_white, true )

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

		debugoverlay.Line( corner1, corner3, FrameTime(), trace3.Hit and color_red or color_white, true )

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

		debugoverlay.Line( corner1, corner4, FrameTime(), trace3.Hit and color_red or color_white, true )
	end

	self.PlaceableSetup = { ["Position"] = bGrounded and vecStart or vecFloor, ["Angle"] = qAngFwd, ["Normal"] = trace.HitNormal, ["Valid"] = bSuccess and bGrounded, ["Entity"] = trace.Entity }

	return self.PlaceableSetup
end