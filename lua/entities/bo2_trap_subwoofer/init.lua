
AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

DEFINE_BASECLASS( ENT.Base )

local nzombies = engine.ActiveGamemode() == "nzombies"

function ENT:Initialize()
	BaseClass.Initialize( self )

	self:SetNextAttack(CurTime() + 1)
end

function ENT:Think()
	local ply = self:GetOwner()
	if not IsValid(ply) then
		self:SetHealth(1)
		self:TakeDamage(666, self, self)
		return false
	end

	if self:GetActivated() and self:GetNextAttack() < CurTime() then
		self.Kills = 0
		if nzombies and IsValid(ply) then
			self:SetNextAttack(CurTime() + (ply:HasPerk("time") and 1 or 2))
		else
			self:SetNextAttack(CurTime() + 2)
		end

		self:EmitSound("TFA_BO2_WOOFER.Explo")
		self:EmitSound("TFA_BO2_WOOFER.Sweet")

		self:CylinderDamageCheck()

		self:TakeDamage(10, self, self)

		ParticleEffectAttach("bo3_thundergun_muzzleflash", PATTACH_POINT_FOLLOW, self, 1)

		util.ScreenShake(self:GetPos(), 10, 255, 1, 250)
	end

	self:NextThink(CurTime())
	return true
end

local function PointOnSegmentNearestToPoint(a, b, p)
	local ab = b - a
	local ap = p - a

	local t = ap:Dot(ab) / (ab.x^2 + ab.y^2 + ab.z^2)
		t = math.Clamp(t, 0, 1)
	return a + t*ab
end

function ENT:CylinderDamageCheck()
	local ply = self:GetOwner()
	if not IsValid(ply) then return end
	local wep = ply:GetActiveWeapon()
	if not IsValid(wep) then return end

	local outer_range = self.CylinderRange
	local cylinder_radius = self.CylinderRadius
	local kill_range = self.CylinderKillRange

	local ang = math.cos(math.rad(45))
	local view_pos = self:GetAttachment(1).Pos
	local forward_view_angles = self:GetForward()
	local end_pos = view_pos + (forward_view_angles * outer_range)

	local ball = ents.Create("bo3_ww_thundergun")
	ball:SetModel("models/dav0r/hoverball.mdl")
	ball:SetPos(view_pos)
	ball:SetOwner(ply)
	ball:SetAngles(forward_view_angles:Angle())
	ball.Delay = 0.4

	ball:Spawn()

	local dir = forward_view_angles
	dir:Mul(1500)

	ball:SetVelocity(dir)

	local phys = ball:GetPhysicsObject()
	if IsValid(phys) then
		phys:SetVelocity(dir)
	end

	ball:SetOwner(ply)
	ball.Inflictor = wep

	local outer_range_squared = outer_range * outer_range
	local cylinder_radius_squared = cylinder_radius * cylinder_radius
	local inner_range_squared = kill_range * kill_range
	local instant_kill_range_squared = 48^2

	for i, ent in pairs(ents.FindInSphere(view_pos, outer_range*1.1)) do
		if not (ent:IsPlayer() or ent:IsNPC() or ent:IsNextBot()) then continue end
		if nzombies and ent:IsPlayer() then continue end
		if ent == ply then continue end
		if ent:Health() <= 0 then continue end

		local test_origin = ent:WorldSpaceCenter()
		local test_range_squared = view_pos:DistToSqr(test_origin)
		if test_range_squared > outer_range_squared then
			continue // everything else in the list will be out of range
		end

		local normal = (test_origin - view_pos):GetNormalized()
		local dot = forward_view_angles:Dot(normal)
		if 0 > dot then
			continue // guy's behind us
		end

		local radial_origin = PointOnSegmentNearestToPoint( view_pos, end_pos, test_origin )
		if test_origin:DistToSqr(radial_origin) > cylinder_radius_squared then
			continue // guy's outside the range of the cylinder of effect
		end

		tr1 = util.TraceLine({
			start = view_pos,
			endpos = test_origin,
			filter = self,
			mask = MASK_SOLID_BRUSHONLY,
		})

		if tr1.HitWorld then
			continue // guy can't actually be hit from where we are
		end

		local dist_ratio = ( outer_range_squared - test_range_squared ) / ( outer_range_squared - instant_kill_range_squared )

		local in_kill_range = test_range_squared < inner_range_squared

		local delay = math.Clamp( ( 1 - dist_ratio ) * 50, 1, 50 )

		timer.Create( "WonderWeapons.Resonator.SVWait" .. ent:EntIndex(),  math.Clamp( engine.TickInterval() * delay, 0, 0.4 ), 1, function()
			if not IsValid(self) or not IsValid(ent) then return end

			local delayed_test_origin = ent:WorldSpaceCenter()
			local delayed_test_range_squared = view_pos:DistToSqr( delayed_test_origin )
			if delayed_test_range_squared > outer_range_squared then
				return
			end
			if delayed_test_origin:DistToSqr( radial_origin ) > cylinder_radius_squared then
				return
			end

			local trtest = util.TraceLine({
				start = radial_origin,
				endpos = delayed_test_origin,
				mask = MASK_SHOT,
				hitworld = true,
				filter = ent,
				whitelist = true
			})

			if trtest.HitWorld then return end

			self:DoCylinderDamage(ent, in_kill_range)
		end)
	end
end

function ENT:DoCylinderDamage(ent, kill)
	local norm = (ent:GetPos() - self:GetPos()):GetNormalized()
	local ply = self:GetOwner()

	local damage = DamageInfo()
	damage:SetDamage(kill and ent:Health() + 666 or 75)
	damage:SetAttacker(IsValid(ply) and ply or self)
	damage:SetInflictor(IsValid(self.Inflictor) and self.Inflictor or self)
	damage:SetDamageType(DMG_MISSILEDEFENSE)
	damage:SetDamageForce(ent:GetUp()*20000 + norm*50000)

	if nzombies and (ent.NZBossType or ent.IsMooBossZombie) then
		damage:SetDamage(math.max(600, ent:GetMaxHealth() / 12))
	end

	ent:TakeDamageInfo(damage)

	if (ent:IsNPC() or ent:IsNextBot()) and kill and IsValid(ply) and ply:IsPlayer() then
		self.Kills = self.Kills + 1
		if self.Kills == 10 and not ply.bo2subwooferachievment then
			TFA.BO3GiveAchievement("Death From Below", "vgui/overlay/achievment/basscannon.png", ply)
			ply.bo2subwooferachievment = true
		end
	end

	self:TakeDamage(math.random(3)*5, ent, ent)
end

function ENT:SetNextAttack( time )
	self.NextAttack = tonumber( time )
end

function ENT:GetNextAttack()
	return self.NextAttack
end

function ENT:TurnOn()
	if self:GetActivated() then return end
	self:SetActivated(true)
	self:SetNextAttack(CurTime() + 1)
end

function ENT:TurnOff()
	if not self:GetActivated() then return end
	self:SetActivated(false)
end
