
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
	},
	["Initial_B"] = {
		["vox"] = "weapons/tfa_bo2/drone/vo/maxi/vox_maxi_maxis_drone_4_d_0.wav",
		["length"] = 8,
	},
	["Hover"] = {
		["vox"] = "weapons/tfa_bo2/drone/vo/vox_maxi_drone_hover_d_0.wav",
		["length"] = 3,
	},
	["Target"] = {
		["vox"] = "weapons/tfa_bo2/drone/vo/vox_maxi_drone_holding_d_0.wav",
		["wait"] = 12,
		["length"] = 3,
	},
	["Scan"] = {
		["vox"] = "weapons/tfa_bo2/drone/vo/vox_maxi_drone_scan_d_0.wav",
		["wait"] = 8,
		["length"] = 2.5,
	},
	["Attack"] = { 
		["vox"] = { "weapons/tfa_bo2/drone/vo/attacking/vox_maxi_drone_attacking_d_0.wav", "weapons/tfa_bo2/drone/vo/attacking/vox_maxi_drone_attacking_d_1.wav", "weapons/tfa_bo2/drone/vo/attacking/vox_maxi_drone_attacking_d_2.wav" },
		["wait"] = 8,
		["length"] = 3,
	},
	["Kill"] = {
		["vox"] = { "weapons/tfa_bo2/drone/vo/killed/vox_maxi_drone_killed_d_0.wav", "weapons/tfa_bo2/drone/vo/killed/vox_maxi_drone_killed_d_1.wav", "weapons/tfa_bo2/drone/vo/killed/vox_maxi_drone_killed_d_2.wav", "weapons/tfa_bo2/drone/vo/killed/vox_maxi_drone_killed_d_3.wav" },
		["length"] = 2.5,
	},
	["Pickup"] = {
		["vox"] = { "weapons/tfa_bo2/drone/vo/pickups/vox_maxi_drone_pickups_d_0.wav", "weapons/tfa_bo2/drone/vo/pickups/vox_maxi_drone_pickups_d_1.wav", "weapons/tfa_bo2/drone/vo/pickups/vox_maxi_drone_pickups_d_2.wav", "weapons/tfa_bo2/drone/vo/pickups/vox_maxi_drone_pickups_d_3.wav", "weapons/tfa_bo2/drone/vo/pickups/vox_maxi_drone_pickups_d_4.wav" },
		["length"] = 3,
	},
	["Revive"] = {
		["vox"] = { "weapons/tfa_bo2/drone/vo/revive/vox_maxi_drone_revive_d_0.wav", "weapons/tfa_bo2/drone/vo/revive/vox_maxi_drone_revive_d_1.wav", "weapons/tfa_bo2/drone/vo/revive/vox_maxi_drone_revive_d_2.wav", "weapons/tfa_bo2/drone/vo/revive/vox_maxi_drone_revive_d_3.wav", "weapons/tfa_bo2/drone/vo/revive/vox_maxi_drone_revive_d_4.wav" },
		["length"] = 3,
	},
	["Upgrade"] = {
		["vox"] = "weapons/tfa_bo2/drone/vo/upgraded/vox_maxi_drone_upgraded_d_0.wav",
		["length"] = 3,
	},
	["Ambient"] = {
		["vox"] = { "weapons/tfa_bo2/drone/vo/ambient/vox_maxi_drone_ambient_1_d_0.wav", "weapons/tfa_bo2/drone/vo/ambient/vox_maxi_drone_ambient_2_d_0.wav", "weapons/tfa_bo2/drone/vo/ambient/vox_maxi_drone_ambient_3_d_0.wav", "weapons/tfa_bo2/drone/vo/ambient/vox_maxi_drone_ambient_4_d_0.wav", "weapons/tfa_bo2/drone/vo/ambient/vox_maxi_drone_ambient_5_d_0.wav", "weapons/tfa_bo2/drone/vo/ambient/vox_maxi_drone_ambient_6_d_0.wav", "weapons/tfa_bo2/drone/vo/ambient/vox_maxi_drone_ambient_7_d_0.wav", "weapons/tfa_bo2/drone/vo/ambient/vox_maxi_drone_ambient_8_d_0.wav", "weapons/tfa_bo2/drone/vo/ambient/vox_maxi_drone_ambient_9_d_0.wav" },
		["wait"] = 24, // repeat protection
		["length"] = 4, // duration till another vox can play
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
end

function ENT:EmitSoundNet(sound)
	if CLIENT or sp then
		if sp and not IsFirstTimePredicted() then return end

		self:EmitSound(sound)
		return
	end

	local filter = RecipientFilter()
	filter:AddPAS(self:GetPos())
	if IsValid(self:GetOwner()) then
		filter:RemovePlayer(self:GetOwner())
	end

	net.Start("tfaSoundEvent", true)
	net.WriteEntity(self)
	net.WriteString(sound)
	net.Send(filter)
end

function ENT:OnRemove()
	self:StopSound( "TFA_BO2_ZMDRONE.Idle" )
	self:StopSound( "TFA_BO2_ZMDRONE.Hum" )
	self:StopSound( "TFA_BO2_ZMDRONE.Shoot" )

	if CLIENT then
		if self.Lamp and IsValid( self.Lamp ) then
			self.Lamp:Remove()
		end
		if self.Light and IsValid( self.Light ) then
			self.Light:StopEmissionAndDestroyImmediately()
		end
		if self.IdleLoopSound and self.IdleLoopSound:IsPlaying() then
			self.IdleLoopSound:Stop()
		end
		if self.HumLoopSound and self.HumLoopSound:IsPlaying() then
			self.HumLoopSound:Stop()
		end
	end

	if SERVER then
		if nzombies and self:GetDestroyed() then
			self:EmitSound("TFA_BO2_ZMDRONE.Teleport")
			ParticleEffect("bo3_qed_explode_1", self:GetPos(), angle_zero)

			for k, v in pairs(ents.FindByClass("nz_buildtable")) do
				if v:GetNW2Bool("MaxisDeployed", false) then
					v:EmitSound("TFA_BO2_ZMDRONE.Recharging")
					v:SetNW2Float("MaxisCooldown", CurTime() + 100)
					if IsValid(v.CraftedModel) then
						ParticleEffect("nzr_building_poof", v.CraftedModel:WorldSpaceCenter(), angle_zero)
					end
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
