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

local PLAYER = FindMetaTable("Player")

if PLAYER then
	if nzombies then
		function PLAYER:GetShovel()
			return self:GetNW2Entity("NZ.Shovel")
		end

		function PLAYER:SetShovel(ent)
			return self:SetNW2Entity("NZ.Shovel", ent)
		end
	else
		function PLAYER:GetShield()
			return self:GetNW2Entity("BO3.Shield")
		end

		function PLAYER:SetShield(ent)
			return self:SetNW2Entity("BO3.Shield", ent)
		end
	end
end

if nzombies then
	if GetConVar("nz_placeable_hologram_style") == nil then
		CreateClientConVar("nz_placeable_hologram_style", 0, true, false, "Change how the visuals of the Buildables placement hologram looks. \n0 for default, 1 for wireframe, 2 for transparent, Default is 0", 0, 2)
	end
end

// Models
util.PrecacheModel("models/weapons/tfa_bo3/dg4/build_dg4_body.mdl")
util.PrecacheModel("models/weapons/tfa_bo3/dg4/build_dg4_guards.mdl")
util.PrecacheModel("models/weapons/tfa_bo3/dg4/build_dg4_handle.mdl")

util.PrecacheModel("models/weapons/tfa_bo3/idgun/build_idgun_heart.mdl")
util.PrecacheModel("models/weapons/tfa_bo3/idgun/build_idgun_tentacle.mdl")
util.PrecacheModel("models/weapons/tfa_bo3/idgun/build_idgun_xenomatter.mdl")

util.PrecacheModel("models/weapons/tfa_bo3/mirg2000/build_mirg2000_plant.mdl")
util.PrecacheModel("models/weapons/tfa_bo3/mirg2000/build_mirg2000_venom.mdl")
util.PrecacheModel("models/weapons/tfa_bo3/mirg2000/build_mirg2000_vial.mdl")

util.PrecacheModel("models/weapons/tfa_bo3/scavenger/build_scavenger_gun.mdl")
util.PrecacheModel("models/weapons/tfa_bo3/scavenger/build_scavenger_scope.mdl")
util.PrecacheModel("models/weapons/tfa_bo3/scavenger/build_scavenger_wire.mdl")

util.PrecacheModel("models/weapons/tfa_bo3/wunderwaffe/build_wunderwaffe_bulbs.mdl")
util.PrecacheModel("models/weapons/tfa_bo3/wunderwaffe/build_wunderwaffe_front.mdl")
util.PrecacheModel("models/weapons/tfa_bo3/wunderwaffe/build_wunderwaffe_powerbox.mdl")

util.PrecacheModel("models/weapons/tfa_bo3/rocketshield/build_rocketshield_eagle.mdl")
util.PrecacheModel("models/weapons/tfa_bo3/rocketshield/build_rocketshield_tanks.mdl")
util.PrecacheModel("models/weapons/tfa_bo3/rocketshield/build_rocketshield_window.mdl")

util.PrecacheModel("models/weapons/tfa_bo3/tombshield/build_tombshield_door.mdl")
util.PrecacheModel("models/weapons/tfa_bo3/tombshield/build_tombshield_frame.mdl")
util.PrecacheModel("models/weapons/tfa_bo3/tombshield/build_tombshield_window.mdl")

util.PrecacheModel("models/weapons/tfa_bo3/dragonshield/build_dragonshield_head.mdl")
util.PrecacheModel("models/weapons/tfa_bo3/dragonshield/build_dragonshield_pelvis.mdl")
util.PrecacheModel("models/weapons/tfa_bo3/dragonshield/build_dragonshield_window.mdl")

util.PrecacheModel("models/weapons/tfa_bo3/vineshield/build_vineshield_door.mdl")
util.PrecacheModel("models/weapons/tfa_bo3/vineshield/build_vineshield_frame.mdl")
util.PrecacheModel("models/weapons/tfa_bo3/vineshield/build_vineshield_window.mdl")

util.PrecacheModel("models/weapons/tfa_bo2/tranzitshield/build_tranzitshield_dolly.mdl")
util.PrecacheModel("models/weapons/tfa_bo2/tranzitshield/build_tranzitshield_door.mdl")

util.PrecacheModel("models/weapons/tfa_bo2/prisonshield/build_prisonshield_dolly.mdl")
util.PrecacheModel("models/weapons/tfa_bo2/prisonshield/build_prisonshield_door.mdl")
util.PrecacheModel("models/weapons/tfa_bo2/prisonshield/build_prisonshield_shackles.mdl")

util.PrecacheModel("models/weapons/tfa_bo2/tombshield/build_tombshield_bracket.mdl")
util.PrecacheModel("models/weapons/tfa_bo2/tombshield/build_tombshield_door.mdl")
util.PrecacheModel("models/weapons/tfa_bo2/tombshield/build_tombshield_top.mdl")

// Particles
game.AddParticles("particles/bo3_dragonshield.pcf")
game.AddParticles("particles/bo2_turbine.pcf")
game.AddParticles("particles/bo2_etrap.pcf")
game.AddParticles("particles/bo2_flinger.pcf")
game.AddParticles("particles/bo2_headchopper.pcf")
game.AddParticles("particles/bo2_mowerturret.pcf")
game.AddParticles("particles/bo2_build.pcf")
game.AddParticles("particles/bo2_soulbox.pcf")
game.AddParticles("particles/bo2_digsite.pcf")
game.AddParticles("particles/bo3_shield.pcf")

// NZobies
PrecacheParticleSystem("nzr_build_magmagat")
PrecacheParticleSystem("nzr_build_acidgat")
PrecacheParticleSystem("nzr_build_blunderhoff")
PrecacheParticleSystem("nzr_build_teslagat")

PrecacheParticleSystem("nzr_building_poof")
PrecacheParticleSystem("nzr_building_model")
PrecacheParticleSystem("nzr_building_loop")

PrecacheParticleSystem("nzr_soulbox_loop")

PrecacheParticleSystem("nzr_digsite_loop")

PrecacheParticleSystem("nzr_skullfire_loop")
PrecacheParticleSystem("nzr_skullfire_al_loop")

PrecacheParticleSystem("nzr_key_loop")

PrecacheParticleSystem("nzr_chalks_loop")
PrecacheParticleSystem("nzr_chalks_poof")

// Dragon Shield
PrecacheParticleSystem("bo3_dragonshield_impact")
PrecacheParticleSystem("bo3_dragonshield_trail")

// Turbine
PrecacheParticleSystem("bo2_turbine_flare")
PrecacheParticleSystem("bo2_turbine_pulse")
PrecacheParticleSystem("bo2_turbine_smoke")
PrecacheParticleSystem("bo2_turbine_spark")
PrecacheParticleSystem("bo2_turbine_death")

// Electric Trap
PrecacheParticleSystem("bo2_etrap_tv")
PrecacheParticleSystem("bo2_etrap_orb")
PrecacheParticleSystem("bo2_etrap_arcs")
PrecacheParticleSystem("ghosts_teslatrap")

// Flinger
PrecacheParticleSystem("bo2_flinger_leak")
PrecacheParticleSystem("bo2_flinger_launch")

// Headchopper ( Steam )
PrecacheParticleSystem("bo2_headchopper_leak")

// Lawnmower Turret ( Diesel )
PrecacheParticleSystem("bo2_mowerturret_leak")
PrecacheParticleSystem("bo2_mowerturret_muzzleflash")
PrecacheParticleSystem("bo2_mowerturret_tracer")

// Maxis
PrecacheParticleSystem("bo2_maxisdrone_muzzleflash")
PrecacheParticleSystem("bo2_maxisdrone_light")
PrecacheParticleSystem("bo2_maxisdrone_damaged_trail")
PrecacheParticleSystem("bo2_maxisdrone_critical_trail")
PrecacheParticleSystem("bo2_maxisdrone_dying_trail")
PrecacheParticleSystem("bo2_maxisdrone_dead_trail")

// Shield Electricity
PrecacheParticleSystem("bo3_shield_electrify")
PrecacheParticleSystem("bo3_shield_electrify_fp")
PrecacheParticleSystem("bo3_shield_electrify_zomb")

if SERVER and nzombies then
	if TFA.WWNoTargetIngore == nil then
		local function WonderWeaponNoTarget(ply)
			if ply.BO3IsTransfur and ply:BO3IsTransfur() then
				return false
			end
			if ply.BO4IsStealth and ply:BO4IsStealth() then
				return false
			end
			if ply.HasVultureStink and ply:HasVultureStink() then
				return false
			end

			return true
		end
		TFA.WWNoTargetIngore = WonderWeaponNoTarget
	end
end

if not matproxy then return end

matproxy.Add({
	name = "TFA_MaxisGlow",

	init = function( self, mat, values )
		self.ResultTo = values.resultvar
	end,

	bind = function( self, mat, ent )
		if not IsValid( ent ) or not ent.GetDestroyed then
			return
		end

		local int = 1
		if ent:GetDestroyed() and !ent.DestroyedFlicker then
			int = 0
		end

		mat:SetInt( self.ResultTo, int )
	end
})
