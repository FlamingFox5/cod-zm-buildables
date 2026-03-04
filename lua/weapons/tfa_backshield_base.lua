local nzombies = engine.ActiveGamemode() == "nzombies"
local sp = game.SinglePlayer()

SWEP.Base = "tfa_melee_base"
SWEP.StatCache_Blacklist = {
	["Bodygroups_V"] = true,
	["Bodygroups_W"] = true,
}
SWEP.ElectricHitsMax = nzombies and 12 or 6
SWEP.ElectricHitDamage = 15

DEFINE_BASECLASS(SWEP.Base)

local sp = game.SinglePlayer()

local color_red = Color(255, 0, 0, 0)

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

function SWEP:SetupDataTables()
	BaseClass.SetupDataTables(self)

	self:NetworkVarTFA("Int", "DamagedVariant")
	self:NetworkVarTFA("Int", "ElectricHits")
	self:NetworkVarTFA("Bool", "Electrified")
	self:NetworkVarTFA("Bool", "Flipped")
end

function SWEP:DrawWorldModel(...)
	if self:GetElectrified() then
		local ply = self:GetOwner()
		if ply.GetShield then
			local shield = ply:GetShield()
			if shield.CL_3PDrawFX and shield.CL_3PDrawFX:IsValid() then
				shield.CL_3PDrawFX:StopEmissionAndDestroyImmediately()
			end
		end

		if !self.CL_3PDrawFX or !self.CL_3PDrawFX:IsValid() then
			self.CL_3PDrawFX = CreateParticleSystem(self, "bo3_shield_electrify", PATTACH_ABSORIGIN_FOLLOW, 0)
		end
	elseif self.CL_3PDrawFX and self.CL_3PDrawFX:IsValid() then
		self.CL_3PDrawFX:StopEmissionAndDestroyImmediately()
	end

	return BaseClass.DrawWorldModel(self, ...)
end

function SWEP:PreDrawViewModel(vm, wep, ply)
	if self:GetElectrified() then
		if !self.CL_FPDrawFX or !self.CL_FPDrawFX:IsValid() then
			self.CL_FPDrawFX = CreateParticleSystem(vm, "bo3_shield_electrify", PATTACH_ABSORIGIN_FOLLOW, 0)
		end
	elseif self.CL_FPDrawFX and self.CL_FPDrawFX:IsValid() then
		self.CL_FPDrawFX:StopEmissionAndDestroyImmediately()
	end

	return BaseClass.PreDrawViewModel(self, vm, wep, ply)
end

function SWEP:CreateBackShield(ply)
	ply:SetShield(ents.Create("cod_backshield"))

	self.Shield = ply:GetShield()
	self.Shield:SetModel(self.ShieldModel)
	self.Shield:SetOwner(ply)
	self.Shield:SetWeapon(self)
	self.Shield:Spawn()
	self.Shield:SetOwner(ply)
end

function SWEP:CallWeaponSwap()
	if nzombies then
		self:GetOwner():SetUsingSpecialWeapon(false)
		self:GetOwner():EquipPreviousWeapon()
		return
	end

	if CLIENT and not sp then
		self:SwitchToPreviousWeapon()
	elseif SERVER then
		self:CallOnClient("SwitchToPreviousWeapon", "")
	end
end

function SWEP:SetDamage(value)
	if self:GetDamagedVariant() == value then return end

	self:SetDamagedVariant(value)
	if value > self:GetDamagedVariant() then
		self:EmitSound(self.ShieldHitSound or "TFA_BO3_SHIELD.Hit")
	end
	if value == 0 then
		self:SetClip1(self.Primary_TFA.ClipSize)
	end
end

function SWEP:ApplyDamage(trace, dmginfo, attk)
	local ply = self:GetOwner()
	local ent = trace.Entity
	if not IsValid(ent) then return end

	local dam, force = dmginfo:GetBaseDamage(), dmginfo:GetDamageForce()
	dmginfo:SetDamagePosition(trace.HitPos)
	dmginfo:SetReportedPosition(trace.StartPos)
	dmginfo:SetDamageForce(ply:GetAimVector()*20000 + ent:GetUp()*15000)

	if nzombies then
		dam = math.huge
		if ent.NZBossType or ent.IsMooBossZombie or ent.IsMiniBoss or string.find(ent:GetClass(), "nz_zombie_boss") then
			dam = ent:GetMaxHealth() / 14
		end

		dmginfo:SetDamage(dam)

		if SERVER then
			ply:GetShield():TakeDamage(math.random(5)*5, ent, ent)
		end
	end

	if self:GetElectrified() then
		dmginfo:SetDamageType(DMG_SHOCK)

		ent:EmitSound("weapons/physcannon/superphys_small_zap"..math.random(4)..".wav", SNDLVL_NORM, math.random(97,103), 1, CHAN_AUTO)
		util.ParticleTracerEx("bo3_waffe_jump", trace.StartPos, trace.HitPos, false, ply:EntIndex(), 0)

		if nzombies and ent:IsValidZombie() then
			dmginfo:SetDamageForce(vector_up)
			ent:EmitSound("TFA_BO3_WAFFE.Sizzle")
			ParticleEffectAttach("bo3_shield_electrify_zomb", PATTACH_ABSORIGIN_FOLLOW, ent, 2)
		end
	end

	ent:DispatchTraceAttack(dmginfo, trace, ply:GetAimVector())

	dmginfo:SetDamage(dam)
	dmginfo:SetDamageForce(force)

	self:ApplyForce(ent, dmginfo:GetDamageForce(), trace.HitPos)

	if self:GetElectrified() then
		self:SetElectricHits(self:GetElectricHits() + 1)
		if self:GetElectricHits() >= self.ElectricHitsMax then
			self:DeElectrify()
		end
	end
end

function SWEP:Think2()
	local ply = self:GetOwner()
	local stat = self:GetStatus()
	local statusend = CurTime() >= self:GetStatusEnd()

	if !self.ShieldNoDamagedSkin and self.Bodygroups_V[0] ~= self:GetDamagedVariant() then
		self.Bodygroups_V = {[0] = self:GetDamagedVariant()}
		self.Bodygroups_W = {[0] = self:GetDamagedVariant()}
	end

	if stat == TFA.Enum.STATUS_HOLSTER and statusend then
		if SERVER then
			if IsValid(ply) and IsValid(self.Shield) then
				ply:GetShield():SetNoDraw(false)
			else
				if IsValid(ply:GetShield()) then
					self:Remove()
				end
			end
		end
	end

	return BaseClass.Think2(self)
end

function SWEP:Equip(ply)
	if ply:IsPlayer() and not IsValid(ply:GetShield()) then
		self:CreateBackShield(ply)
	end

	return BaseClass.Equip(self, ply)
end

function SWEP:Deploy(...)
	local ply = self:GetOwner()
	if SERVER then
		if IsValid(ply) and IsValid(ply:GetShield()) then
			ply:GetShield():SetNoDraw(true)
		else
			if IsValid(ply:GetShield()) then
				self:Remove()
			end
		end
	end

	return BaseClass.Deploy(self, ...)
end

function SWEP:OnRemove(...)
	if SERVER then
		if IsValid(self.Shield) then
			self:DeElectrify(true)
			self.Shield:Remove()
		end
	end

	return BaseClass.OnRemove(self, ...)
end

function SWEP:OnDrop(...)
	if SERVER then
		if IsValid(self.Shield) then
			self.Shield:Remove()
		end
	end

	return BaseClass.OnDrop(self, ...)
end

function SWEP:OwnerChanged(...)
	if SERVER then
		if IsValid(self.Shield) then
			self.Shield:Remove()
		end
	end

	return BaseClass.OwnerChanged(self, ...)
end

//Electric shield shit
function SWEP:ShockBlock(ply, ent, dmginfo)
	if CLIENT then return end
	if not IsValid(ply) or not IsValid(ent) then return end
	if not dmginfo then return end

	if ent.WasShockedThisTick then return end //shitty protection against inf loops
	if nzombies and !ent:IsValidZombie() then return end

	local hurtpos = dmginfo:GetReportedPosition()
	if hurtpos == vector_origin then
		hurtpos = ent:IsPlayer() and ent:GetShootPos() or ent:EyePos()
	end

	local shockdmg = DamageInfo()
	shockdmg:SetDamage(self.ElectricHitDamage or 15)
	shockdmg:SetAttacker(ply)
	shockdmg:SetInflictor(self)
	shockdmg:SetDamageType(DMG_SHOCK)
	shockdmg:SetDamagePosition(hurtpos)
	shockdmg:SetReportedPosition(ply:GetShootPos())
	shockdmg:SetDamageForce(dmginfo:GetDamageForce()*-1.5)

	if nzombies and (ent:Health() - shockdmg:GetDamage()) > 0 then
		if ent.NZBossType or ent.IsMooBossZombie or string.find(ent:GetClass(), "nz_zombie_boss") then
			shockdmg:SetDamage(math.max(200, ent:GetMaxHealth() / 18))
		elseif ent.TempBehaveThread and ent.SparkySequences then
			ParticleEffectAttach("bo3_shield_electrify_zomb", PATTACH_ABSORIGIN_FOLLOW, ent, 2)
			if ent.PlaySound and ent.ElecSounds then
				ent:PlaySound(ent.ElecSounds[math.random(#ent.ElecSounds)], ent.SoundVolume or SNDLVL_NORM, math.random(ent.MinSoundPitch or 97, ent.MaxSoundPitch or 103), 1, 2)
			end

			ent:TempBehaveThread(function(ent)
				local seq = ent.SparkySequences[math.random(#ent.SparkySequences)]
				local id, time = ent:LookupSequence(seq)
				ent:PlaySequenceAndWait(seq)
				ent:StopParticles()
			end)
		end
	end

	ent.WasShockedThisTick = true
	ent:EmitSound("weapons/physcannon/superphys_small_zap"..math.random(4)..".wav", SNDLVL_NORM, math.random(97,103), 1, CHAN_AUTO)
	util.ParticleTracerEx("bo3_waffe_jump", ply:GetShootPos(), hurtpos, false, ply:EntIndex(), 0)

	ent:TakeDamageInfo(shockdmg)

	timer.Simple(0, function()
		if not IsValid(ent) then return end
		ent.WasShockedThisTick = nil
	end)

	self:SetElectricHits(self:GetElectricHits() + 1)
	if self:GetElectricHits() >= (self.ElectricHitsMax or 6) then
		self:DeElectrify()
	end
end

function SWEP:Electrify(amount)
	if self:GetElectrified() then return end
	self:SetElectrified(true)
	self:SetElectricHits(amount or 0)
end

function SWEP:DeElectrify(nosound)
	if !self:GetElectrified() then return end
	self:SetElectrified(false)
	self:SetElectricHits(0)
	self:CleanParticles()

	if !nosound then
		self:EmitSound("weapons/tfa_bo2/etrap/electrap_stop.wav", SNDLVL_NORM, math.random(97,103), 1, CHAN_STATIC)
	end
end

function SWEP:ProcessHoldType(...)
	if self:GetStatus() == TFA.Enum.STATUS_GRENADE_READY then
		self:SetHoldType("camera")
		return "camera"
	end

	if self:GetStatus() == TFA.Enum.STATUS_DRAW and self:GetStatusProgress() > 0.5 and self.IsFirstDeploy then
		if self:GetStatusProgress() < 0.55 then
			self:SetHoldType("camera")
			return "camera"
		else
			return BaseClass.ProcessHoldType(self, ...)
		end
	else
		return BaseClass.ProcessHoldType(self, ...)
	end
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

	if self.PlantShield and t_ShieldStatuses[self:GetStatus()] then
		local mSetupData = self:SetupPlaceable()
		if mSetupData and !mSetupData[ "Valid" ] then
			G_BuildableHologram:SetModel( self:GetWeaponViewModel() )

			// horrible z-fighting on the viewmodel, this doesnt fix it but helps a tiny bit
			local vecOffset = vm:GetAngles():Forward()*0.005

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
	if not IsValid(ply) then
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
	local bFlipped = ( self.GetFlipped and self:GetFlipped() ) or false
	local vecFinal = ply:GetPos()
	local vecHull, vecFloor, bGrounded, flDot
	local nStepHeight = 16
	local vecStart = ply.GetShootPos and ply:GetShootPos() or ply:EyePos()
	local qAngAim = ply:EyeAngles()
	local qAngFwd = Angle( 0, qAngAim[2], 0 )
	local qAngFinal = Angle()

	local mFilter = { self }
	table.Add( mFilter, player.GetAll() )

	local vecMins = Vector( -5, -14, -26.9 )
	local vecMaxs = Vector( 14, 14, 32 )

	if self.BuildableMaxBounds then
		vecMaxs:Set( self.BuildableMaxBounds )
	end
	if self.BuildableMinBounds then
		vecMins:Set( self.BuildableMinBounds )
	end

	local nHullHalf = vecMaxs[3] / 2
	local vecUpHalf = Vector( 0, 0, nHullHalf )

	// trace from eyes
	local trace = {}

	// trace from feet
	local trace2 = {}

	// criss cross trace for OOB check
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
		endpos = vecStart + qAngFwd:Forward() * ( self.BuildableDistance + vecMaxs[1] ),
		filter = mFilter,
		mask = MASK_PLAYERSOLID,
		output = trace,
	})

	local vecStart2 = ply:GetPos() + vector_up * 4

	// ground level
	util.TraceLine({
		start = vecStart2,
		endpos = vecStart2 + qAngFwd:Forward() * ( self.BuildableDistance + vecMaxs[1] ),
		filter = mFilter,
		mask = MASK_PLAYERSOLID,
		output = trace2,
	})

	--debugoverlay.Line(vecStart, trace.HitPos, FrameTime(), trace.Hit and color_red or color_white, true)

	--debugoverlay.Line(vecStart2, trace2.HitPos, FrameTime(), trace2.Hit and color_red or color_white, true)

	// prioritize lower trace
	if trace2.Hit then
		trace = trace2
	end

	// align 2D against surface, facing towards the player
	if trace.Hit then
		qAngFwd = Angle( 0, trace.HitNormal:Angle()[2], 0 )

		// custom wall offsets cause yeah
		vecStart = trace.HitPos + trace.HitNormal * ( self.BuildableWallOffset )
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

	// down trace must hit floor and the player must be either grounded, within stepheight of the hitpos, or on a ladder
	bGrounded = trace.Hit and ( ply:IsOnGround() or ply:GetMoveType() == MOVETYPE_LADDER or ( ply:GetPos()[3] <= ( trace.HitPos[3] + nStepHeight ) ) )
	bSuccess = bGrounded and IsValidToPlaceOn( trace.Entity, trace.HitWorld )

	// level with the bottom of the players hull
	vecFloor = vecStart - Vector( 0, 0, ( ply:EyePos()[3] - ply:GetPos()[3] ) ) + ( vector_up * ( self.BuildableHeightOffset or 0 ) )

	// level with the floor
	vecStart = trace.HitPos + vector_up * ( self.BuildableHeightOffset or 0 )

	vecFinal:Set( bGrounded and vecStart or vecFloor )

	flDot = trace.HitNormal:Dot( vector_up )

	bSuccess = flDot > 0.84

	// align with the floor normal
	qAngFinal:Set( qAngFwd )
	if trace.Hit and flDot > 0.81 then
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

	// half-assed check to make sure the 4 corners are unobstructed
	local corner1 = vecFinal + ( qAngFwd:Forward() * vecMaxs[1] ) + ( qAngFwd:Right() * -vecMins[2] )
	local corner2 = vecFinal + ( qAngFwd:Forward() * vecMins[1] ) + ( qAngFwd:Right() * -vecMaxs[2] )

	--debugoverlay.Axis( corner1, angle_zero, 5, FrameTime(), true )
	--debugoverlay.Axis( corner2, angle_zero, 5, FrameTime(), true )

	vecMins:Rotate( qAngFwd )
	vecMaxs:Rotate( qAngFwd )

	local corner3 = vecFinal + Vector( vecMins[1], vecMins[2], 0 )
	local corner4 = vecFinal + Vector( vecMaxs[1], vecMaxs[2], 0 )

	--debugoverlay.Axis( corner3, angle_zero, 5, FrameTime(), true )
	--debugoverlay.Axis( corner4, angle_zero, 5, FrameTime(), true )

	if bSuccess then
		// make sure the end doesnt clip through a thin wall
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
	end

	--debugoverlay.EntityTextAtPosition( vecFinal + vecUpHalf, 1, math.Round( flDot, 4 ), FrameTime(), flDot > 0.84 and color_white or color_red_full)

	// invalid floor angle
	if flDot < 0.84 then
		--debugoverlay.Text( vecFinal + vecUpHalf, "X", FrameTime(), false)
	end

	--debugoverlay.Axis( vecFinal, qAngFinal, 10, FrameTime(), true)

	self.PlaceableSetup = { ["Position"] = vecFinal, ["Angle"] = qAngFinal, ["Normal"] = trace.HitNormal, ["Valid"] = bSuccess and bGrounded, ["Entity"] = trace.Entity }

	return self.PlaceableSetup
end