-- Copyright (c) 2018-2020 TFA Base Devs

-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:

-- The above copyright notice and this permission notice shall be included in all
-- copies or substantial portions of the Software.

-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.

local nzombies = engine.ActiveGamemode() == "nzombies"

-- Info
TFA.ShieldDamageTypes = {
	[DMG_SLASH] = true,
	[DMG_CLUB] = true,
	[DMG_CRUSH] = true,
	[DMG_BULLET] = true,
	[DMG_AIRBOAT] = true,
	[DMG_BUCKSHOT] = true,
	[DMG_BLAST_SURFACE] = true,
	[DMG_GENERIC] = true,
	[DMG_SONIC] = true,
	[DMG_SHOCK] = true,
}

if nzombies and nzLevel then
	nzLevel.InvalidPlaceableClasses = nzLevel.InvalidPlaceableClasses or {}
	nzLevel.InvalidPlaceableClasses["random_box_spawns"] = true
	nzLevel.InvalidPlaceableClasses["perk_machine"] = true
	nzLevel.InvalidPlaceableClasses["random_box"] = true
	nzLevel.InvalidPlaceableClasses["prop_buys"] = true
end

-- Hooks
if SERVER then
	hook.Add( "OnEntityCreated", "FOXBUILDS.DieselDrone.Ping", function( entity )
		if entity:GetClass() == "ent_ping_marker" then
			timer.Simple( 0, function()
				if !IsValid( entity ) then return end

				local position = entity:GetPos()

				local trace = util_TraceLine({
					start = position,
					endpos = position + vector_down_128,
					mask = MASK_NPCWORLDSTATIC,
					filter = entity,
				})

				if trace.Hit then
					local owner = entity:GetNWString( "Owner" )
					local ply = NULL
					for _, player in ipairs( player.GetAll() ) do
						if player:Nick() == owner then
							ply = player
							break
						end
					end

					if !IsValid( ply ) then
						owner = entity:GetOwner()
						if IsValid( owner ) and owner:IsPlayer() then
							ply = owner
						end
					end

					if IsValid( ply ) then
						local drone = ply.MaxisDrone

						if IsValid( drone ) then
							local pingtype = entity:GetNWString( "PingType" )
							local pinged = entity:GetParent()

							if pingtype == "look" then
								local trace2 = {}
								util_TraceLine({
									start = drone:GetPos(),
									endpos = position + vecOrbitOffset,
									mask = MASK_NPCWORLDSTATIC,
									filter = entity,
									output = trace2,
								})

								if !trace2.Hit then
									drone:DirectPathToScripted( trace.HitPos + vecOrbitOffset )
								end
							elseif t_DronePings[ pingtype ] then
								if drone.marked_target then
									drone.marked_target = false
								end

								if pingtype == "assist" then
									if IsValid( pinged ) then
										drone:PathToPlayer( pinged )
									end
									return
								end

								if IsValid( pinged ) and pinged:GetClass() == "drop_powerup" then
									drone:PathToScripted( pinged )
								else
									for _, drop in ipairs( ents.FindInSphere( position, 100 ) ) do
										if IsValid( drop ) and drop:GetClass() == "drop_powerup" then
											drone:PathToScripted( drop )
											return
										end
									end

									if pingtype == "default" then
										return
									end

									drone:PathToScripted( trace.HitPos + drone.current_ground_offset, t_DronePings[ pingtype ] )
								end
							elseif pingtype == "enemy" then
								if IsValid( pinged ) then
									if ( pinged:IsNPC() or pinged:IsNextBot() ) and !drone.marked_target then
										drone.marked_target = true
										drone:SetTarget( pinged )
									else
										drone:PathToTarget( pinged )
									end
								end
							end
						end
					end
				end
			end )
		end
	end )

	concommand.Add("zm_maxis_drone_tp_home", function(ply)
		local drone = ply.MaxisDrone
		if !IsValid( drone ) then
			return
		end

		drone:TeleportToHome()
	end)

	concommand.Add("zm_maxis_drone_tp_end", function(ply)
		local drone = ply.MaxisDrone
		if !IsValid( drone ) then
			return
		end

		if !drone:IsPathing() then
			return
		end

		drone:TeleportToLastPathSegment()
	end)

	concommand.Add("zm_maxis_drone_tp_player", function(ply)
		local drone = ply.MaxisDrone
		if !IsValid( drone ) then
			return
		end

		drone:TeleportToPlayer()
	end)

	local function DropShield(ply, shield)
		if not IsValid(ply) then return end
		if ply.NextTrapUse and ply.NextTrapUse > CurTime() then return end
		if not IsValid(shield) then return end

		local wep = shield:GetWeapon()
		if not IsValid(wep) or not wep.SetupPlaceable then return end

		local mSetupData = wep:SetupPlaceable()

		if not mSetupData then return end

		if not mSetupData["Valid"] then
			if wep.NotifyShieldMessage then
				wep:NotifyShieldMessage()
			end
			return
		end

		local ent = ents.Create("cod_plantedshield")
		ent:SetModel( wep:GetWeaponWorldModel() )
		ent:SetPos( mSetupData["Position"] )
		ent:SetAngles( mSetupData["Angle"] )
		ent:SetOwner( ply )

		if wep.BuildableMinBounds and wep.BuildableMaxBounds then
			ent:SetCollisionBounds( wep.BuildableMinBounds, wep.BuildableMaxBounds )
			ent.BuildableMinBounds = wep.BuildableMinBounds
			ent.BuildableMaxBounds = wep.BuildableMaxBounds
		end

		ent:SetMaxHealth( shield:GetMaxHealth() )
		ent:SetHealth( shield:Health() )

		if ent.SetShieldClass then
			ent:SetShieldClass( wep:GetClass() )
		end

		ent.ElectricHitsMax = wep.ElectricHitsMax or 6
		ent.ElectricHitDamage = wep.ElectricHitDamage or 15

		local hitEntity = mSetupData["Entity"]
		if IsValid( hitEntity ) then
			// parent to vehicles / push movetype entities or dynamic models / brush models tied to one
			local hMoveParent = hitEntity:GetMoveParent()
			if ( hitEntity:IsVehicle() or hitEntity:GetMoveType() == MOVETYPE_PUSH ) or ( IsValid( hMoveParent ) and hMoveParent:GetMoveType() == MOVETYPE_PUSH ) then
				ent:SetParent( hitEntity )
			end
		end 

		ent:Spawn()
		ent:SetOwner( ply )

		if wep.GetElectrified and wep:GetElectrified() then
			ent:Electrify(wep.GetElectricHits and wep:GetElectricHits() or 0)
		end

		SafeRemoveEntity(shield)

		timer.Simple(0, function()
			if not IsValid(ply) or not IsValid(wep) then return end
			ply:StripWeapon(wep:GetClass())
		end)
	end

	local function DropTrap(ply, wep)
		if not IsValid(ply) then return end
		if ply.NextTrapUse and ply.NextTrapUse > CurTime() then return end
		if not IsValid( wep ) or not wep.SetupPlaceable or not wep.Primary.Projectile then return end

		local mSetupData = wep:SetupPlaceable()

		if not mSetupData then return end

		if not mSetupData["Valid"] then
			if wep.NotifyPlaceMessage then
				wep:NotifyPlaceMessage()
			end
			return
		end

		local ent = ents.Create( wep:GetStatL("Primary.Projectile") )
		ent:SetModel( wep:GetStatL("Primary.ProjectileModel") )
		ent:SetPos( mSetupData["Position"] )
		ent:SetAngles( mSetupData["Angle"] )
		ent:SetOwner( ply )

		if wep.BuildableMaxHealth then
			local nMaxHealth = wep.BuildableMaxHealth or 500
			local nHealthFac = math.max( nMaxHealth / 100, 0 )
			local flRatio = math.Clamp( wep:Clip1() / wep:GetMaxClip1(), 0, 1 ) * 100

			ent:SetMaxHealth( nMaxHealth )
			ent:SetHealth( math.Round( flRatio * nHealthFac ) )
		end

		if ent.SetTrapClass then
			ent:SetTrapClass(wep:GetClass())
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

		ply:StripWeapon(wep:GetClass())
	end

	if nzombies then
		concommand.Add("+dropshield", function(ply)
			if not ply.GetShield then return end
			local shield = ply:GetShield()
			if IsValid(shield) and IsValid(shield:GetWeapon()) and shield:GetWeapon().PlantShield and ply:GetActiveWeapon() ~= shield:GetWeapon() then
				DropShield(ply, shield)
			end
		end)
		concommand.Add("-dropshield", function(ply) end)

		concommand.Add("+droptrap", function(ply)
			if not ply.GetSpecialWeaponFromCategory then return end
			local wep = ply:GetSpecialWeaponFromCategory('trap')
			if IsValid(wep) and wep.TrapCanBePlaced and wep.IsTFAWeapon and ply:GetActiveWeapon() ~= wep then
				DropTrap(ply, wep)
			end
		end)
		concommand.Add("-droptrap", function(ply) end)

		local derriesetps = {
			["tp1relaytimer"] = true,
			["tp2relaytimer"] = true,
			["tp3relaytimer"] = true,
		}

		local moonpapdoors = {
			["pap_gatel"] = true,
			["pap_gatef"] = true,
			["pap_gater"] = true,
		}

		hook.Add("AcceptInput", "FOXBUILDS.theclock", function(ent, input, act, call, val)
			//Der Riese
			if act:IsPlayer() and ent:GetName() == "startcoundownPA" then
				for _, ply in ipairs(player.GetAll()) do
					if ply:GetNW2Float("nzStopWatch", 0) < CurTime() then
						ply.nzderriese_watch = true
						ply:SetNW2Float("nzStopWatch", CurTime() + 24.5) //PA has a 0.5 delay i think
					end
				end
			end
			if act:IsPlayer() and derriesetps[ent:GetName()] and input == "CancelPending" then
				for _, ply in ipairs(player.GetAll()) do
					if ply.nzderriese_watch then
						ply:SetNW2Float("nzStopWatch", 0)
					end
				end
			end

			//Moon
			if act:IsPlayer() and moonpapdoors[ent:GetName()] and input == "Open" and act:GetNW2Float("nzStopWatch", 0) < CurTime() then
				act:SetNW2Float("nzStopWatch", CurTime() + 30)
			end
		end)

		hook.Add("OnBossKilled", "FOXBUILDS.NZ.BossKill", function(ent, dmginfo)
			local attacker = dmginfo:GetAttacker()
			local inflictor = dmginfo:GetInflictor()
			if not IsValid(ent) or not IsValid(attacker) or not IsValid(inflictor) then return end
			for k, v in pairs(ents.FindByClass("nz_soulbox")) do
				if v.Enabled and (not v:GetCompleted()) and ent:GetPos():DistToSqr(v:GetPos()) <= v.RangeSqr and v:Condition(ent, dmginfo) and v:ZedCheck(attacker, inflictor, ent) then
					v:NotifyZombieDeath(attacker, inflictor, ent)
					break
				end
			end
		end)

		hook.Add("OnZombieKilled", "FOXBUILDS.NZ.ZobKill", function(ent, dmginfo)
			local attacker = dmginfo:GetAttacker()
			local inflictor = dmginfo:GetInflictor()
			if not IsValid(ent) or not IsValid(attacker) or not IsValid(inflictor) then return end
			for k, v in pairs(ents.FindByClass("nz_soulbox")) do
				if v.Enabled and (not v:GetCompleted()) and ent:GetPos():DistToSqr(v:GetPos()) <= v.RangeSqr and v:Condition(ent, dmginfo) and v:ZedCheck(attacker, inflictor, ent) then
					v:NotifyZombieDeath(attacker, inflictor, ent)
					break
				end
			end

			if attacker:IsPlayer() and inflictor:GetClass() == "tfa_bo3_rocketshield" and inflictor:GetDashing() then
				inflictor:SetKillCount(inflictor:GetKillCount() + 1)
			end
		end)

		hook.Add("OnPlayerPickupPowerUp", "FOXBUILDS.NZ.Shield.Recharge", function( _, id, ent)
			if id ~= "maxammo" then return end

			for i=1, player.GetCount() do
				local ply = Entity(i)
				if not IsValid(ply) or not ply:IsPlayer() then continue end

				for _, wep in pairs(ply:GetWeapons()) do
					if wep.IsTFAWeapon and wep.NZSpecialCategory == "shield" and wep.Secondary_TFA.ClipSize > 0 then
						wep:SetClip2(wep.Secondary_TFA.ClipSize)

						local msg1 = "surface.PlaySound('weapons/tfa_bo3/zm_common.all.sabl.4316.wav')"
						ply:SendLua(msg1)
					end
				end
			end
		end)

		/*if not nzWeps or not nzWeps.Updated then
			hook.Add("PlayerCanPickupWeapon", "FOXBUILDS.NZ.Buildable.Place", function(ply, wep)
				if not IsValid(ply) or not IsValid(wep) then return end
				if wep.IsTFAWeapon and wep.NZSpecialCategory == "trap" then
					for _, trap in pairs(ply:GetWeapons()) do
						if trap.IsTFAWeapon and trap.NZSpecialCategory == "trap" and wep:GetClass() ~= trap:GetClass() then
							local ang = ply:GetAimVector():Angle()

							local ent = ents.Create(trap.Primary.Projectile)
							ent:SetModel(trap.Primary.ProjectileModel)
							ent:SetPos(ply:GetPos() + Vector(0,0,1))
							ent:SetAngles(Angle(0, ang.yaw, ang.roll))
							ent:SetOwner(ply)

							local pct = math.Clamp(trap:Clip1() / trap:GetMaxClip1(), 0, 1)
							ent:SetMaxHealth(500)
							ent:SetHealth(math.Round(pct * 5))
							ent:SetTrapClass(trap:GetClass())

							ent:Spawn()
							ent:SetOwner(ply)

							ply:StripWeapon(trap:GetClass())
							break
						end
					end
				end
			end)
		end*/

		hook.Add("RespawnMaxisDrone", "FOXBUILDS.NZ.MaxisReset", function()
			print("The Maxis Drone has been respawned at its table")
			for k, v in pairs(ents.FindByClass("nz_buildtable")) do
				if v:GetNW2Bool("MaxisDeployed", false) then
					v:SetNW2Bool("MaxisDeployed", false)
					if IsValid(v.CraftedModel) and not (nzRound:InState(ROUND_CREATE) or nzRound:InState(ROUND_GO)) then
						ParticleEffect("nzr_building_poof", v.CraftedModel:WorldSpaceCenter(), angle_zero)
						v.CraftedModel:EmitSound("NZ.BO2.DigSite.Part")
						v.CraftedModel:Reset()
					end
					break
				end
			end
		end)

		hook.Add("PlayerKilled", "FOXBUILDS.NZ.MaxisReset", function(ply)
			if ply:IsPlayer() and ply:HasWeapon('tfa_bo2_drone') and !IsValid(ents.FindByClass("bo2_trap_drone")[1]) then
				hook.Call("RespawnMaxisDrone")
			end
		end)

		hook.Add("EntityRemoved", "FOXBUILDS.NZ.MaxisReset", function(ply)
			if ply:IsPlayer() and ply:HasWeapon('tfa_bo2_drone') and !IsValid(ents.FindByClass("bo2_trap_drone")[1]) then
				hook.Call("RespawnMaxisDrone")
			end
		end)

		hook.Add("OnRoundEnd", "FOXBUILDS.NZ.MaxisReset", function()
			if nzRound:InState(ROUND_CREATE) or nzRound:InState(ROUND_GO) then
				if IsValid(ents.FindByClass("bo2_trap_drone")[1]) then
					hook.Call("RespawnMaxisDrone")
				end
			end
		end)

		hook.Add("OnRoundEnd", "FOXBUILDS.NZ.AcidtableReset", function()
			for k, v in pairs(ents.FindByClass("nz_buildtable")) do
				if v:GetNW2Bool("SplatReady", false) then
					v:SetNW2Bool("SplatReady", false)
					v:SetNW2Int("SplatUser", 0)
					if IsValid(v.FakeBlundergat) then
						v.FakeBlundergat:Remove()
					end
					break
				end
			end
		end)

		/*hook.Add("PlayerPostThink", "FOXBUILDS.NZ.Rage", function(ply)
			if ply.PLEASEFIXNZSAWFULWEAPONSYSTEM and !ply:HasWeapon("tfa_bo3_rocketshield") then
				ply:Give("tfa_bo3_rocketshield")
			end
			if ply.PLEASEFIXNZSAWFULWEAPONSYSTEM2 and !ply:HasWeapon("tfa_bo3_dragonshield") then
				ply:Give("tfa_bo3_dragonshield")
			end
		end)*/
	end

	hook.Add( "FindUseEntity", "FOXBUILDS.NZ.UseFIX", function( ply, default )
		if not IsValid( ply ) then
			return
		end

		if IsValid( default ) and ( !default.GetTrapClass and !default.GetShieldClass ) then
			local trace = ply:GetEyeTrace()
			local hitEntity = trace.Entity

			if IsValid( hitEntity ) and ( hitEntity.GetTrapClass or hitEntity.GetShieldClass ) and trace.StartPos:DistToSqr( trace.HitPos ) <= 10000 then
				if !ply.NextTrapUse or !isnumber( ply.NextTrapUse ) or ply.NextTrapUse < CurTime() then
					//print('PENIS')
					hitEntity:Use( ply, ply )
					return true
				end
			end
		end
	end )

	hook.Add("PlayerCanPickupWeapon", "zzFOXBUILDS.TFA.Shield.Limit", function(ply, wep)
		if not IsValid(ply) or not IsValid(wep) then return end
		if ply.GetShield and IsValid(ply:GetShield()) and wep.ShieldEnabled then
			return false
		end
		if ply.CarryLantern and IsValid(ply.CarryLantern) and wep.IsLantern then
			return false
		end
	end)

	hook.Add("OnNPCKilled", "FOXBUILDS.TFA.Shield.Kill", function(npc, attacker, inflictor)
		if nzombies then return end
		if not IsValid(npc) or not IsValid(attacker) or not IsValid(inflictor) then return end

		if attacker:IsPlayer() and inflictor:GetClass() == "tfa_bo3_rocketshield" and inflictor:GetDashing() then
			inflictor:SetKillCount(inflictor:GetKillCount() + 1)
		end
		if IsValid(inflictor) and inflictor.ShieldEnabled and inflictor.GetElectrified and inflictor:GetElectrified() then
			npc:StopParticles()
			npc:SetNW2Int("WunderWaffeld", 1)
		end
	end)
end

local function BlockDamage(ply, dmginfo)
	if nzombies then return end
	if not IsValid(ply) or not ply:IsPlayer() or not IsValid(dmginfo:GetAttacker()) then return end
	if not ply:IsPlayer() then return end
	if dmginfo:IsDamageType(DMG_DROWNRECOVER + DMG_DIRECT) then return end

	local shield = ply:GetShield()
	if not IsValid(shield) then return end

	local attacker = dmginfo:GetAttacker()
	local inflictor = dmginfo:GetInflictor()

	local dmgtype = dmginfo:GetDamageType()
	if not TFA.ShieldDamageTypes[dmgtype] then return end

	local ratio = 0.2
	local bonus = 0.5

	local dmg = dmginfo:GetDamage() * ratio
	local newdmg = (dmginfo:GetDamage() - dmg) * bonus

	local dot = (attacker:GetPos() - ply:GetPos()):Dot(ply:GetAimVector())
	local wep = ply:GetActiveWeapon()
	local active = IsValid(wep) and wep.ShieldEnabled

	if SERVER and shield.GetWeapon then
		local shieldwep = shield:GetWeapon()
		if IsValid(shieldwep) and bit.band(dmgtype, DMG_SHOCK) ~= 0 and shieldwep.Electrify and shieldwep.GetElectrified and !shieldwep:GetElectrified() then
			shieldwep:Electrify()
			shieldwep:EmitSound("weapons/tfa_bo2/etrap/electrap_zap_0"..math.random(0,3)..".wav", SNDLVL_NORM, math.random(97,103), 0.75, CHAN_STATIC)
			return true
		end
	end

	if ((dot < 0 and not active) or (dot >= 0 and active)) and bit.band(dmgtype, DMG_SHOCK) == 0 then
		if SERVER and attacker ~= ply and shield.GetWeapon then
			local shieldwep = shield:GetWeapon()
			if IsValid(shieldwep) and shieldwep.ShockBlock and shieldwep.GetElectrified and shieldwep:GetElectrified() and bit.band(dmgtype, DMG_SHOCK) == 0 and attacker:GetPos():DistToSqr(ply:GetPos()) < 14400 then
				shieldwep:ShockBlock(ply, attacker, dmginfo)
			end
		end

		shield:TakeDamage(newdmg, attacker, IsValid(inflictor) and inflictor or attacker)
		return true
	end
end

if nzombies then
	hook.Add("EntityTakeDamage", "FOXBUILDS.TFA.Shield.BlockFire", function( ply, dmginfo )
		if not IsValid(ply) then return end
		if not ply:IsPlayer() then return end

		if bit.band(dmginfo:GetDamageType(), bit.bor(DMG_BURN, DMG_SLOWBURN)) == 0 then return end

		local wep = ply:GetActiveWeapon()
		local active = IsValid(wep) and wep.ShieldEnabled and wep.ShieldFireBlock

		if active then
			if !ply.DragonShieldPAP and ply.DragonShieldFireKills and ply.DragonShieldFireKills >= 48 then
				if not ply.DragonShieldDamageBlocked then ply.DragonShieldDamageBlocked = 0 end

				if ply.DragonShieldDamageBlocked >= 400 then
					if nzWeps.Updated then
						wep:ApplyNZModifier("pap")

						wep:ResetFirstDeploy()
						wep:CallOnClient("ResetFirstDeploy", "")
						wep:Deploy()
						wep:CallOnClient("Deploy", "")
					else
						ply.DragonShieldPAP = true
						ply.PLEASEFIXNZSAWFULWEAPONSYSTEM2 = true
						ply:StripWeapon(wep:GetClass())
					end

					local msg1 = "surface.PlaySound('weapons/tfa_bo3/dragonshield/dragon_arrival_01.wav')"
					ply:SendLua(msg1)
				end
				ply.DragonShieldDamageBlocked = ply.DragonShieldDamageBlocked + math.min(dmginfo:GetDamage(), 100)
			end
			return true
		end
	end)

	hook.Add("EntityTakeDamage", "FOXBUILDS.TFA.Shield.ShockNZ", function( ply, dmginfo )
		if not IsValid(ply) then return end
		if not ply:IsPlayer() then return end

		local dmgtype = dmginfo:GetDamageType()
		if not TFA.ShieldDamageTypes[dmgtype] then return end

		local attacker = dmginfo:GetAttacker()
		if not IsValid(attacker) then return end

		local shield = ply:GetShield()
		if not IsValid(shield) then return end

		local shieldwep = shield.GetWeapon and shield:GetWeapon() or NULL
		if not IsValid(shieldwep) then return end

		if bit.band(dmgtype, DMG_SHOCK) ~= 0 and shieldwep.Electrify and shieldwep.GetElectrified and !shieldwep:GetElectrified() then
			shieldwep:Electrify()
			shieldwep:EmitSound("weapons/tfa_bo2/etrap/electrap_zap_0"..math.random(0,3)..".wav", SNDLVL_NORM, math.random(97,103), 0.75, CHAN_STATIC)
			return true
		end

		if attacker:IsValidZombie() and bit.band(dmgtype, DMG_SHOCK) == 0 and shieldwep.GetElectrified and shieldwep:GetElectrified() then
			local dot = (attacker:GetPos() - ply:GetPos()):Dot(ply:GetAimVector())
			local wep = ply:GetActiveWeapon()
			local active = IsValid(wep) and wep.ShieldEnabled

			if ((dot < 0 and not active) or (dot > 0 and active)) and attacker:GetPos():DistToSqr(ply:GetPos()) < 14400 then
				shieldwep:ShockBlock(ply, attacker, dmginfo)
			end
		end
	end)

	hook.Add("InitPostEntity", "FOXBUILDS.NZ.Traps.Key", function()
		nzSpecialWeapons:RegisterSpecialWeaponCategory("trap", KEY_T)
		if not nzPowerUps:Get("bloodmoney") then
			nzPowerUps:NewPowerUp("bloodmoney", {
				name = "Blood Money",
				model = "models/powerups/w_zmoney.mdl",
				global = false,
				angle = Angle(0,0,0),
				scale = 1,
				chance = 0,
				duration = 0,
				natural = false,
				icon_t5 = Material("vgui/bo1_bonus.png", "unlitgeneric"),
				icon_t6 = Material("vgui/bo2_bonus.png", "unlitgeneric"),
				icon_t7 = Material("vgui/bo3_bonus.png", "unlitgeneric"),
				icon_t7zod = Material("vgui/bo3_bonus.png", "unlitgeneric"),
				icon_t8 = Material("vgui/bo4_bonus.png", "unlitgeneric"),
				icon_t9 = Material("vgui/robit_cw_powerup_bonus_points.png", "unlitgeneric"),
				announcement = "nz/powerups/blood_money.wav",
				condition = function(id, pos)
					return false //never spawn naturally
				end,
				func = (function(self, ply)
					ply:GivePoints(math.random(1,6)*50)
				end),
			})
		end

		nzSpecialWeapons:AddDisplay("tfa_cotd_wunderwaffe", false, function(wep) return false end)
		nzSpecialWeapons:AddDisplay("tfa_chalkdrawing", false, function(wep)
			return SERVER and (!wep:GetOwner().TimedUseEntity or !wep:GetOwner():KeyDown(IN_USE))
		end)

		nzPerks:AddVultureClass("nz_blankchalk")
		nzDisplay:AddVultureIcon("nz_blankchalk", Material("vgui/icon/zom_hud_icon_buildable_weap_chalk.png", "smooth unlitgeneric"))
	end)
else
	hook.Add("EntityTakeDamage", "FOXBUILDS.TFA.Shield.TakeDamage", function( ply, dmginfo )
		return BlockDamage( ply, dmginfo )
	end)

	hook.Add("ScalePlayerDamage", "FOXBUILDS.TFA.Shield.ScaleDamage", function( ply, _, dmginfo )
		return BlockDamage( ply, dmginfo )
	end)
end

if CLIENT then
	local cvarStyle = GetConVar("nz_placeable_hologram_style")

	local t_ShieldStatuses = {
		[TFA.Enum.STATUS_GRENADE_THROW] = true,
		[TFA.Enum.STATUS_GRENADE_READY] = true,
		[TFA.Enum.STATUS_GRENADE_PULL] = true,
	}

	local t_DrawStatuses = {
		[TFA.Enum.STATUS_GRENADE_PULL] = true,
		[TFA.Enum.STATUS_DRAW] = true,
	}

	G_BuildableHologram = ClientsideModel( "models/weapons/tfa_bo2/tranzitshield/w_tranzitshield.mdl" )
	G_BuildableHologram:SetNoDraw( true )
	G_BuildableHologram:DrawShadow( false )

	hook.Add( "PostDrawTranslucentRenderables", "FOXBUILDS.TFA.Shield.Draw", function( bDepth, bSkybox, _ )
		if bSkybox then
			return
		end
		if not IsValid( G_BuildableHologram ) then
			return
		end

		local nStyle = cvarStyle and cvarStyle:GetInt() or 0

		for _, ply in player.Iterator() do
			if not IsValid( ply ) or not ply:Alive() then continue end

			local weapon = ply:GetActiveWeapon()
			if IsValid( weapon ) and weapon.IsTFAWeapon then
				local bIsShield = ( weapon.ShieldEnabled and weapon.ShieldModel ) and t_ShieldStatuses[ weapon:GetStatus() ]
				local bIsBuildable = weapon.BuildableHologram or ( !bIsShield and weapon.PlantShield and t_ShieldStatuses[ weapon:GetStatus() ] )

				if ( bIsShield or bIsBuildable ) and weapon.SetupPlaceable then
					local mSetupData = weapon:SetupPlaceable()

					if not mSetupData then
						continue
					end

					local bDrawStatus = false
					if t_DrawStatuses[weapon:GetStatus()] then
						bDrawStatus = true
					end

					local strModel = weapon:GetWeaponWorldModel()

					if G_BuildableHologram:GetModel() ~= strModel then
						G_BuildableHologram:SetModel( strModel )
					end

					// TODO: recode this so that theres a global table with each players placeable setupdata for that frame to be compared against instead
					local flRate = 12 * FrameTime()
					if bDrawStatus then
						flRate = 1
					end

					local vecFinalAng = mSetupData["Angle"] - ( weapon.BuildableAngleOffset or angle_zero )
					local vecStartAng = G_BuildableHologram:GetAngles() //this doesnt work due to the models position and angles being modified multiple times per frame

					local vecCurAng = LerpAngle( flRate, vecStartAng, vecFinalAng )
					vecCurAng:SetUnpacked(vecCurAng[1], vecFinalAng[2], vecCurAng[3])

					G_BuildableHologram:SetPos( mSetupData["Position"] )
					G_BuildableHologram:SetAngles( vecCurAng )

					if weapon.BuildableSetupBones then
						G_BuildableHologram:SetupBones()
					end

					if G_BuildableHologram.LastManipulatedBone then
						G_BuildableHologram:ManipulateBoneAngles( G_BuildableHologram.LastManipulatedBone, angle_zero )
					end

					render.SetBlend( 1 )

					render.SetColorModulation( 1, 1, 1 )

					G_BuildableHologram:SetMaterial( "" )

					if bIsShield and nStyle ~= 1 then
						if !mSetupData["Valid"] then
							continue
						else
							render.SetBlend( 0.5 )
						end
					end

					if nStyle == 3 and !bIsShield then
						if mSetupData["Valid"] then
							render.SetBlend( 0.8 )
						else
							G_BuildableHologram:SetMaterial( "models/weapons/v_slam/new light1.vmt" )

							render.SetBlend( 0.2 )

							render.SetColorModulation( 1, 0.1, 0.1 )
						end
					end

					if weapon.PreDrawBuildableModel then
						weapon:PreDrawBuildableModel( G_BuildableHologram )
					end

					if nStyle ~= 2  then
						G_BuildableHologram:DrawModel()
					end

					if weapon.PostDrawBuildableModel then
						weapon:PostDrawBuildableModel( G_BuildableHologram )
					end

					if bIsShield or nStyle == 3 then
						render.SetBlend( 1 )
					end

					if nStyle == 1 or nStyle == 2 then
						if !mSetupData["Valid"] then
							render.SetColorModulation( 1, 0.1, 0.1 )
						elseif nStyle ~= 2 then
							render.SetColorModulation( 0.1, 1, 0.1 )
						end

						G_BuildableHologram:SetMaterial( "models/wireframe" )

						G_BuildableHologram:DrawModel()
					elseif nStyle == 0 then
						render.SetBlend( 0.5 )

						if !mSetupData["Valid"] then
							G_BuildableHologram:SetMaterial( "models/weapons/v_slam/new light1.vmt" )

							G_BuildableHologram:DrawModel()
						end

						render.SetBlend( 1 )
					end
				end
			end
		end
	end )

	local color_black_100 = Color(0, 0, 0, 100)

	if nzombies then
		hook.Add("HUDPaint","FOXBUILDS.NZ.Buildable.Health", function()
			local ply = LocalPlayer()
			if not IsValid(ply) then return end

			local trace = ply:GetEyeTrace()
			local ent = trace.Entity
			local wep = ply:GetActiveWeapon()

			if IsValid(wep) and wep.NZSpecialCategory then
				ent = NULL
			end

			if IsValid(ent) and (ent.GetTrapClass or ent.GetShieldClass) and trace.StartPos:DistToSqr(trace.HitPos) < 14400 then
				local w, h = ScrW(), ScrH()
				local scale = ((w/1920)+1)/2
				local lowres = scale < 0.96

				draw.SimpleTextOutlined("HP - "..ent:Health(), ("nz.points."..GetFontType(nzMapping.Settings.mainfont)), w/2, h - 420*scale, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, 2, color_black_100)
			end
		end)
	else
		hook.Add("HUDPaint","FOXBUILDS.TFA.Buildable.Health", function()
			local ply = LocalPlayer()
			if not IsValid(ply) then return end

			local trace = ply:GetEyeTrace()
			local ent = trace.Entity
			local wep = ply:GetActiveWeapon()

			if IsValid(wep) and wep.BO3CanHack then
				ent = NULL
			end

			if IsValid(ent) and (ent.GetTrapClass or ent.GetShieldClass) and trace.StartPos:DistToSqr(trace.HitPos) < 14400 then
				local w, h = ScrW(), ScrH()
				local scale = ((w/1920)+1)/2

				draw.SimpleTextOutlined("Press "..string.upper(input.LookupBinding("+USE")).." - Pickup", "DermaLarge", w/2, h/2 + 100 * scale, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, 2, color_black_100)
				draw.SimpleTextOutlined("HP - "..ent:Health(), "DermaLarge", w/2, h/2 + 60 * scale, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, 2, color_black_100)
			end
		end)
	end
end
