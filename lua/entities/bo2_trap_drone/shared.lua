
AddCSLuaFile()

--[Info]--
ENT.Type = "anim"
ENT.PrintName = "Maxis Drone"

ENT.Author = "FlamingFox"
ENT.Purpose = "Follows the player around."
ENT.Instructions = ""

ENT.DoNotDuplicate = true
ENT.DisableDuplicator = true

ENT.BuildableBoundsMins = Vector(-16, -16, -8)
ENT.BuildableBoundsMaxs = Vector( 16, 16, 4)

ENT.BlowbackCurrent = 0

ENT.AugerTime = 2.5
ENT.AugerSpeed = 400

ENT.RPM = 700
ENT.RPMRapid = 700

ENT.Delay = 60
ENT.TurnRate = 4

ENT.bIsTrap = true

ENT.GlowColor = Color( 200, 255, 128, 80 )
ENT.SoftGlowColor = Color(200*0.4, 255*0.4, 128*0.4, 24)
ENT.LightGlowColor = Color( 255, 127, 0, 32 )

ENT.MaxisVoxTable = {
	["Initial_A"] = {
		["vox"] = "weapons/tfa_bo2/drone/vo/maxi/vox_maxi_maxis_drone_1_d_0.wav",
		["length"] = 10.5,
		["stale"] = -1,
	},
	["Initial_B"] = {
		["vox"] = "weapons/tfa_bo2/drone/vo/maxi/vox_maxi_maxis_drone_4_d_0.wav",
		["length"] = 8,
		["stale"] = -1,
	},
	["Hover"] = {
		["vox"] = "weapons/tfa_bo2/drone/vo/vox_maxi_drone_hover_d_0.wav",
		["length"] = 3,
		["stale"] = -1,
	},
	["Target"] = {
		["vox"] = "weapons/tfa_bo2/drone/vo/vox_maxi_drone_holding_d_0.wav",
		["wait"] = 12,
		["length"] = 3,
		["stale"] = 4,
	},
	["Scan"] = {
		["vox"] = "weapons/tfa_bo2/drone/vo/vox_maxi_drone_scan_d_0.wav",
		["wait"] = 8,
		["length"] = 2.5,
		["stale"] = 4,
	},
	["Attack"] = { 
		["vox"] = { "weapons/tfa_bo2/drone/vo/attacking/vox_maxi_drone_attacking_d_0.wav", "weapons/tfa_bo2/drone/vo/attacking/vox_maxi_drone_attacking_d_1.wav", "weapons/tfa_bo2/drone/vo/attacking/vox_maxi_drone_attacking_d_2.wav" },
		["wait"] = 8,
		["length"] = 3,
		["stale"] = 2,
	},
	["Kill"] = {
		["vox"] = { "weapons/tfa_bo2/drone/vo/killed/vox_maxi_drone_killed_d_0.wav", "weapons/tfa_bo2/drone/vo/killed/vox_maxi_drone_killed_d_1.wav", "weapons/tfa_bo2/drone/vo/killed/vox_maxi_drone_killed_d_2.wav", "weapons/tfa_bo2/drone/vo/killed/vox_maxi_drone_killed_d_3.wav" },
		["length"] = 2.5,
		["stale"] = 2,
	},
	["Pickup"] = {
		["vox"] = { "weapons/tfa_bo2/drone/vo/pickups/vox_maxi_drone_pickups_d_0.wav", "weapons/tfa_bo2/drone/vo/pickups/vox_maxi_drone_pickups_d_1.wav", "weapons/tfa_bo2/drone/vo/pickups/vox_maxi_drone_pickups_d_2.wav", "weapons/tfa_bo2/drone/vo/pickups/vox_maxi_drone_pickups_d_3.wav", "weapons/tfa_bo2/drone/vo/pickups/vox_maxi_drone_pickups_d_4.wav" },
		["length"] = 3,
		["stale"] = -1,
	},
	["Revive"] = {
		["vox"] = { "weapons/tfa_bo2/drone/vo/revive/vox_maxi_drone_revive_d_0.wav", "weapons/tfa_bo2/drone/vo/revive/vox_maxi_drone_revive_d_1.wav", "weapons/tfa_bo2/drone/vo/revive/vox_maxi_drone_revive_d_2.wav", "weapons/tfa_bo2/drone/vo/revive/vox_maxi_drone_revive_d_3.wav", "weapons/tfa_bo2/drone/vo/revive/vox_maxi_drone_revive_d_4.wav" },
		["length"] = 3,
		["stale"] = -1,
	},
	["Upgrade"] = {
		["vox"] = "weapons/tfa_bo2/drone/vo/upgraded/vox_maxi_drone_upgraded_d_0.wav",
		["length"] = 3,
		["stale"] = -1,
	},
	["Ambient"] = {
		["vox"] = { "weapons/tfa_bo2/drone/vo/ambient/vox_maxi_drone_ambient_1_d_0.wav", "weapons/tfa_bo2/drone/vo/ambient/vox_maxi_drone_ambient_2_d_0.wav", "weapons/tfa_bo2/drone/vo/ambient/vox_maxi_drone_ambient_3_d_0.wav", "weapons/tfa_bo2/drone/vo/ambient/vox_maxi_drone_ambient_4_d_0.wav", "weapons/tfa_bo2/drone/vo/ambient/vox_maxi_drone_ambient_5_d_0.wav", "weapons/tfa_bo2/drone/vo/ambient/vox_maxi_drone_ambient_6_d_0.wav", "weapons/tfa_bo2/drone/vo/ambient/vox_maxi_drone_ambient_7_d_0.wav", "weapons/tfa_bo2/drone/vo/ambient/vox_maxi_drone_ambient_8_d_0.wav", "weapons/tfa_bo2/drone/vo/ambient/vox_maxi_drone_ambient_9_d_0.wav" },
		["wait"] = 24, // repeat protection
		["length"] = 4, // duration till another vox can play
		["stale"] = 4, // how long until we give up trying to play the vox, -1 for never
		["interrupt"] = true, // can we be interrupted by anything except ourselves
	}
}

ENT.NZHudIcon = Material("vgui/icon/hud_quadrotor_tomb.png", "smooth unlitgeneric")
ENT.NZThrowIcon = Material("vgui/icon/hud_quadrotor_tomb.png", "smooth unlitgeneric")

local nzombies = engine.ActiveGamemode() == "nzombies"
local sp = game.SinglePlayer()

function ENT:SetupDataTables()
	self:NetworkVar("Entity", "Target")

	self:NetworkVar("String", "TrapClass")
	self:NetworkVar("Bool", "Destroyed")
	self:NetworkVar("Bool", "Upgraded")

	self:SetDestroyed( false )
	self:SetUpgraded( false )

	if ( CLIENT ) then
		self:NetworkVarNotify( "Destroyed", function( myself, name, old, new )
			if name == "Destroyed" then
				// stop old firing sound loop
				if tobool( new ) and !tobool( old ) then
					myself.DestroyedTime = CurTime()
				end
			end
		end )

		self:NetworkVarNotify( "Upgraded", function( myself, name, old, new )
			if name == "Upgraded" then
				// stop old firing sound loop
				if tobool( new ) and !tobool( old ) then
					myself:StopSound( "TFA_BO2_ZMDRONE.Shoot" )
				else
					myself:StopSound( "TFA_BO2_ZMDRONE.Shoot.Upg" )
				end

				// if we were firing mid upgrade, somehow, restart
				if IsValid( myself:GetTarget() ) then
					myself:EmitSound( tobool( new ) and "TFA_BO2_ZMDRONE.Shoot.Upg" or "TFA_BO2_ZMDRONE.Shoot" )
				end
			end
		end )
	end
end

function ENT:OnRemove()
	self:StopSound( "TFA_BO2_ZMDRONE.Idle" )
	self:StopSound( "TFA_BO2_ZMDRONE.Hum" )
	self:StopSound( "TFA_BO2_ZMDRONE.Damaged" )
	self:StopSound( "TFA_BO2_ZMDRONE.Shoot" )
	self:StopSound( "TFA_BO2_ZMDRONE.Shoot.Upg" )

	if CLIENT then
		if self.Trail and IsValid( self.Trail ) then
			self.Trail:StopEmissionAndDestroyImmediately()
		end
		if self.Light and IsValid( self.Light ) then
			self.Light:StopEmissionAndDestroyImmediately()
		end
		if self.Lamp and IsValid( self.Lamp ) then
			self.Lamp:Remove()
		end
		if self.IdleLoopSound and self.IdleLoopSound:IsPlaying() then
			self.IdleLoopSound:Stop()
		end
		if self.HumLoopSound and self.HumLoopSound:IsPlaying() then
			self.HumLoopSound:Stop()
		end
		if self.DamagedLoopSound and self.DamagedLoopSound:IsPlaying() then
			self.DamagedLoopSound:Stop()
		end
		if self.BurningLoopSound and self.BurningLoopSound:IsPlaying() then
			self.BurningLoopSound:Stop()
		end
	end

	self:StopParticles()

	if SERVER then
		if nzombies and self:GetDestroyed() then
			self:EmitSound("TFA_BO2_ZMDRONE.Teleport")
			ParticleEffect("bo3_qed_explode_1", self:GetPos(), angle_zero)

			for k, v in pairs( ents.FindByClass( "nz_buildtable" ) ) do
				if v:GetNW2Bool( "MaxisDeployed", false ) then
					sound.Play( "TFA_BO2_ZMDRONE.Recharging", v:GetPos() + ( vector_up * v:OBBMaxs()[3] ), SNDLVL_TALKING, 100, 1 )
					v:SetNW2Float( "MaxisCooldown", CurTime() + 100 )
					break
				end
			end

			hook.Call("RespawnMaxisDrone")
		end

		local ply = self:GetOwner()
		if nzombies and IsValid(ply) and ply:IsPlayer() then
			ply:RemoveBuildable(self)
		end

		util.ScreenShake(self:GetPos(), 10, ( 0.5 / engine.TickInterval() ), 0.5, 150)
	end
end
