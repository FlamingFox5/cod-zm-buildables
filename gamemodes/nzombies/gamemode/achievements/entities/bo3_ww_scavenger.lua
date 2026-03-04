AddCSLuaFile()

ENT.Base = "tfa_ww_nophys_base"
ENT.PrintName = "Zombie Sniper Bolt"

// Custom Settings

ENT.RampUpSound = "TFA_BO3_SCAVENGER.RampUp"
ENT.RampUpDelay = 0.5

// Default Settings

ENT.DefaultModel = Model("models/weapons/tfa_bo3/scavenger/scavenger_projectile.mdl")

ENT.Delay = 3
ENT.Damage = 100
ENT.Range = 280

ENT.DesiredSpeed = 7000

ENT.HullMaxs = Vector(1.5, 0.5, 0.5)
ENT.HullMins = ENT.HullMaxs:GetNegated()

ENT.TrailEffect = "bo3_scavenger_trail"
ENT.TrailAttachType = PATTACH_ABSORIGIN_FOLLOW
ENT.TrailAttachPoint = 1

ENT.ShouldLodgeProjectile = true
ENT.ShouldDropProjectile = true

ENT.ParentOffset = 2

ENT.ImpactBubbles = true
ENT.ImpactBubblesSize = 32
ENT.ImpactBubblesMagnitude = 1

// Explosion Settings

ENT.ExplosionBubbles = true
ENT.ExplosionBubblesSize = 500
ENT.ExplosionBubblesMagnitude = 24

ENT.ExplodeOnKilltimeEnd = true

ENT.ExplosionMaxBlockingMass = 750
ENT.ExplosionDamageType = nzombies and DMG_BLAST or bit.bor( DMG_BLAST, DMG_AIRBOAT )
ENT.ExplosionHeadShotScale = 7
ENT.ExplosionHitsOwner = true
ENT.ExplosionOwnerDamage = 50
ENT.ExplosionScreenShake = true

ENT.WaterBlockExplosions = false

ENT.ScreenShakeAmplitude = 5
ENT.ScreenShakeFrequency = 255
ENT.ScreenShakeDuration = 1.6
ENT.ScreenShakeRange = 240

ENT.ExplosionEffectAngleCorrection = Angle( -90, 0, 0 )
ENT.ExplosionEffect = "bo3_scavenger_explosion"
ENT.ExplosionEffectPaP = "bo3_scavenger_explosion_2"

ENT.ExplosionSound = "TFA_BO3_SCAVENGER.Explode"
ENT.ExplosionSoundPaP = "TFA_BO3_SCAVENGER.ExplodePAP"

// DLight Settings

ENT.Color = Color( 255, 200, 20 )
ENT.ColorPaP = Color( 240, 100, 220 )

ENT.DLightBrightness = 0
ENT.DLightSize = 0

ENT.DLightFlashOnRemove = true

ENT.DLightFlashSize = 500
ENT.DLightFlashDecay = 500
ENT.DLightFlashBrightness = 1

// nZombies Settings

ENT.NZThrowIcon = Material("vgui/icon/hud_indicator_sniper_explosive.png", "unlitgeneric smooth")
ENT.NZHudIcon = Material("vgui/icon/hud_indicator_sniper_explosive.png", "unlitgeneric smooth")

local nzombies = engine.ActiveGamemode() == "nzombies"
local sv_true_damage = GetConVar("sv_tfa_bo3ww_cod_damage")

local CurTime = CurTime
local IsValid = IsValid

local MASK_SHOT = MASK_SHOT
local MOVETYPE_NONE = MOVETYPE_NONE

local ParticleEffectAttach = ParticleEffectAttach
local ParticleEffect = ParticleEffect
local PlaySound = sound.Play

local LIFE_ALIVE = 0
local BOLT_SPRITE_OFFSET = Vector( 0, 0, 0 )

local mImpactMaterials = TFA.WonderWeapon.BoltImpactSoundSurfaceMats

DEFINE_BASECLASS(ENT.Base)

function ENT:SetupDataTables()
	BaseClass.SetupDataTables(self)

	self:NetworkVarTFA("Bool", "Impacted")
end

if SERVER then
	function ENT:GravGunPickupAllowed()
		return not self:GetImpacted()
	end
end

function ENT:GravGunPunt()
	if not self:GetImpacted() then
		if self.DesiredGravity then
			self.Gravity = math.max( self.DesiredGravity * 4, self.Gravity )
		else
			self.Gravity = math.max( self.Gravity, math.min( self.Gravity * 4, ( GetConVar( "sv_gravity" ):GetInt() / self.FrameTimeRate ) ) )
		end

		return true
	else
		return false
	end
end

function ENT:Draw( ... )
	local bHideTime = self:GetCreationTime() + 0.05 > CurTime()
	if bHideTime then
		self.NoDrawNoShadow = true
	else
		self.NoDrawNoShadow = false
	end

	BaseClass.Draw( self, ... )

	if bHideTime then return end

	self:DrawModel()

	if nzombies then return end
	if self:GetCreationTime() + 0.22 > CurTime() then return end

	local icon = surface.GetTextureID("models/weapons/tfa_bo3/scavenger/i_scavenger_indicator")
	local angle = LocalPlayer():EyeAngles()
	local pos = self:GetPos() + (self:GetUp() * 12) + (self:GetForward() * - 5)
	local totaldist = 350^2
	local distfade = 250^2
	local playerpos = LocalPlayer():GetPos():DistToSqr(self:GetPos())
	local fadefac = 1 - math.Clamp((playerpos - totaldist + distfade) / distfade, 0, 1)
	
	angle = Angle(angle.x, angle.y, 0)
	angle:RotateAroundAxis(angle:Up(), -90)
	angle:RotateAroundAxis(angle:Forward(), 90)
	
	if IsValid(LocalPlayer()) and self:GetImpacted() then
		cam.Start3D2D(pos, angle, 1)
			surface.SetTexture(icon)
			surface.SetDrawColor(255,255,255,255*fadefac)
			surface.DrawTexturedRect(-8, -8, 16,16)
		cam.End3D2D()
	end
end

function ENT:Think()
	if SERVER then
		if self.RampUpDelay and ( self:GetCreationTime() + self.RampUpDelay ) < CurTime() and !self.HasEmitSound then
			self:EmitSound( self.RampUpSound )
			self.HasEmitSound = true
		end
	end

	return BaseClass.Think( self )
end

function ENT:EntityCollide( trace )
	local hitEntity = trace.Entity
	local direction = self.Direction or trace.Normal

	local hitDamage = DamageInfo()
	hitDamage:SetDamage(10)
	hitDamage:SetAttacker(IsValid(self:GetOwner()) and self:GetOwner() or self)
	hitDamage:SetInflictor(IsValid(self.Inflictor) and self.Inflictor or self)
	hitDamage:SetDamageType(DMG_BULLET)
	hitDamage:SetDamageForce(direction*2000)
	hitDamage:SetDamagePosition(trace.HitPos)
	hitDamage:SetReportedPosition(trace.StartPos)

	local nLastHealth = hitEntity:Health()

	hitEntity:DispatchTraceAttack(hitDamage, trace, direction)

	if hitEntity:Health() < nLastHealth then
		self:SendHitMarker(hitEntity, hitDamage, trace)
	end

	self:DoImpactEffect(trace)

	local soundTab = mImpactMaterials[util.GetSurfacePropName(trace.SurfaceProps)]
	local finalSound = "weapons/tfa_bo3/scavenger/impacts/rock_00.wav"
	if soundTab and istable(soundTab) then
		finalSound = soundTab[math.random(#soundTab)]
	end

	PlaySound( finalSound, trace.HitPos, SNDLVL_NORM, math.random(97,103), 1 )

	local sprite = self:CreateGlowSprite( math.Clamp(self.killtime - CurTime(), 0, 3) )
	if sprite then
		sprite:SetParent(self)
		sprite:SetLocalPos(BOLT_SPRITE_OFFSET)
	end

	self:SetImpacted( true )

	sound.EmitHint( SOUND_DANGER, trace.HitPos, 512, 0.2, self:GetOwner() )

	// Must return true to stop projectile
	return true
end

function ENT:WorldCollide( trace )
	local hitEntity = trace.Entity
	local direction = self.Direction or trace.Normal

	local hitDamage = DamageInfo()
	hitDamage:SetDamage(10)
	hitDamage:SetAttacker(IsValid(self:GetOwner()) and self:GetOwner() or self)
	hitDamage:SetInflictor(IsValid(self.Inflictor) and self.Inflictor or self)
	hitDamage:SetDamageType(DMG_BULLET)
	hitDamage:SetDamageForce(direction*2000)
	hitDamage:SetDamagePosition(trace.HitPos)
	hitDamage:SetReportedPosition(trace.StartPos)

	local nLastHealth = hitEntity:Health()

	hitEntity:DispatchTraceAttack(hitDamage, trace, direction)

	if hitEntity:Health() < nLastHealth then
		self:SendHitMarker(hitEntity, hitDamage, trace)
	end

	self:DoImpactEffect(trace)

	local soundTab = mImpactMaterials[util.GetSurfacePropName(trace.SurfaceProps)]
	local finalSound = "weapons/tfa_bo3/scavenger/impacts/rock_00.wav"
	if soundTab and istable(soundTab) then
		finalSound = soundTab[math.random(#soundTab)]
	end

	PlaySound( finalSound, trace.HitPos, SNDLVL_NORM, math.random(97,103), 1 )

	local sprite = self:CreateGlowSprite( math.Clamp(self.killtime - CurTime(), 0, 3) )
	if sprite then
		sprite:SetParent(self)
		sprite:SetLocalPos(BOLT_SPRITE_OFFSET)
	end

	self:SetImpacted( true )

	sound.EmitHint( SOUND_DANGER, trace.HitPos, 512, 0.2, self:GetOwner() )

	// Must return true to stop projectile
	return true
end

function ENT:CallbackOnDrop()
	if not self:GetImpacted() then return end
	self:SetImpacted(false)

	self:SetMoveType( MOVETYPE_NONE )

	self.Gravity = self.Gravity*8
	self.Speed = 1
end

function ENT:DoExplosionEffect( ... )
	BaseClass.DoExplosionEffect( self, ... )

	if self.HitPos and self.HitNormal then
		util.Decal( "Scorch", self.HitPos, self.HitPos + self.HitNormal*4 )
	end
end

function ENT:Explode( vecSrc, radius, ... )
	BaseClass.Explode( self, vecSrc, radius, ... )

	if not vecSrc or not isvector( vecSrc ) or vecSrc:IsZero() then
		vecSrc = self:GetPos()
	end

	if not radius or not isnumber( radius ) or radius < 0 then
		radius = self.Range / 3
	end

	TFA.WonderWeapon.WavegunPopClientRagdolls( vecSrc, radius, 0, 3 )
end

function ENT:PreExplosionDamage( hitEntity, explosionTrace, damageinfo )
	local ply = self:GetOwner()

	local distfac = self:GetPos():Distance(hitEntity:GetPos())
	distfac = 1 - math.Clamp(distfac/self.Range, 0, 1)

	local bGibRange = distfac > 0.67

	if bGibRange then
		if ( sv_true_damage == nil or sv_true_damage:GetBool() ) or nzombies then
			damageinfo:SetDamage( hitEntity:Health() + 666 )
		elseif !nzombies then
			damageinfo:ScaleDamage( 3 )
		end
	end

	if nzombies and ( hitEntity.NZBossType or hitEntity.IsMooBossZombie or string.find( hitEntity:GetClass(), "zombie_boss" ) ) then
		damageinfo:ScaleDamage( math.Round( nzRound:GetNumber() / 10, 1 ) )
	elseif bGibRange and (hitEntity:IsPlayer() or hitEntity:IsNPC() or hitEntity:IsNextBot()) and hitEntity ~= ply then
		hitEntity:SetHealth( 1 )

		TFA.WonderWeapon.DoDeathEffect( hitEntity, "BO3_Wavegun_Pop" )

		local BloodColor = hitEntity.GetBloodColor and hitEntity:GetBloodColor() or DONT_BLEED
		local startVec = TFA.WonderWeapon.BodyTarget( hitEntity, explosionTrace.StartPos, true )
		timer.Simple( 0, function()
			local vecVelocity = Vector( math.random( -200, 200 ), math.random( -200, 200 ), math.random( 100, 200 ) )
			local vecAngleVelocity = Vector( 0, math.random( 1000, 2000 ), 0 )
			local randomFacingAngle = Angle(0, math.random( -180, 180 ), 0)

			TFA.WonderWeapon.CreateHorrorGib( startVec, randomFacingAngle, vecVelocity, vecAngleVelocity, math.Rand( 3, 4 ), BloodColor )
		end )
	end

	if IsValid( ply ) and ply:IsPlayer() then
		TFA.WonderWeapon.NotifyAchievement( "BO3_Scavenger_Long_Range", ply, hitEntity, self )
	end
end
