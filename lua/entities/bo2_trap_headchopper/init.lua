
AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

DEFINE_BASECLASS( ENT.Base )

local color_red = Color(255,0,0,255)
local nzombies = engine.ActiveGamemode() == "nzombies"

function ENT:Initialize()
	BaseClass.Initialize( self )

	self:SetActivated( true )

	self:EmitSound("TFA_BO2_HEADCHOP.Start")

	self:SetLastAttack(CurTime() - (self.Delay * 0.5))
end

function ENT:Think()
	local ply = self:GetOwner()
	if not IsValid(ply) then
		self:SetHealth(1)
		self:TakeDamage(666, self, self)
		return false
	end

	if self:GetLastAttack() == 0 then
		local attData = self:GetAttachment(3)
		local attData2 = self:GetAttachment(2)

		if attData and attData.Pos and attData2 and attData2.Pos then
			local mFilter = { self }
			if nzombies then
				table.Add( mFilter, player.GetAll() )
			end

			local nHits = 0
			local vecStart = attData2.Pos
			local vecEnd = attData.Pos + attData.Ang:Up() * self.Range

			local tr = {
				start = vecStart,
				filter = mFilter,
				mask = MASK_SOLID,
			}

			//debugoverlay.Line( self:GetPos(), vecEnd, FrameTime()*2, color_white, true )
			//debugoverlay.Line( attData2.Pos, vecEnd, FrameTime()*2, color_white, true )

			local nearbyEnts = ents.FindAlongRay( self:GetPos(), vecEnd, self.TraceHullMins, self.TraceHullMaxs )
			for _, entity in ipairs( ents.FindAlongRay( attData2.Pos, vecEnd, self.TraceHullMins, self.TraceHullMaxs ) ) do
				if not table.HasValue( nearbyEnts, entity ) then
					table.insert( nearbyEnts, entity )
				end
			end

			for _, entity in ipairs( nearbyEnts ) do
				if entity:IsPlayer() or entity:IsNPC() or entity:IsNextBot() then
					if entity:Health() <= 0 then continue end
					if nzombies and entity:IsPlayer() then continue end
					if entity:IsPlayer() and entity:Crouching() then continue end

					if nHits > 4 then
						break
					end

					local vecCenter = entity:WorldSpaceCenter()
					tr.endpos = Vector( vecCenter[1], vecCenter[2], vecEnd[3] )

					local trace = util.TraceLine( tr )

					//debugoverlay.Line( trace.StartPos, trace.HitPos, 1, trace.Entity == entity and color_white or color_red, true )

					local bSuccess = false
					if trace.Entity == entity then
						bSuccess = true
					else
						tr.start = attData.Pos

						local trace = util.TraceLine( tr )

						if trace.Entity == entity then
							bSuccess = true
						end

						//debugoverlay.Line( trace.StartPos, trace.HitPos, 1, trace.Entity == entity and color_white or color_red, true )
					end

					if bSuccess then
						if nzombies and IsValid(ply) then
							self:ResetSequence(ply:HasPerk("time") and "swing_fast" or "swing")
						else
							self:ResetSequence("swing")
						end

						self:EmitSound("TFA_BO2_HEADCHOP.Start")
						self:EmitSound("TFA_BO2_HEADCHOP.Swing")

						self:SetLastAttack(CurTime())

						self:InflictDamage(entity, trace)
						self:TakeDamage(math.random(5)*5, entity, entity)

						table.insert( mFilter, entity )
						nHits = nHits + 1
					end
				end
			end
		end
	end

	local fuck = self.Delay
	if nzombies and IsValid(ply) then
		fuck = ply:HasPerk("time") and 1 or self.Delay
		fuck = math.min( fuck, self.Delay )
	end

	if self:GetLastAttack() ~= 0 and self:GetLastAttack() + fuck < CurTime() then
		self:SetLastAttack(0)
	end

	self:NextThink(CurTime())
	return true
end

function ENT:InflictDamage(ent, trace)
	local ply = self:GetOwner()

	local self_pos = self:GetAttachment(3).Pos
	local eye_position = ent:EyePos()
	local head_position = eye_position[3] + 10
	local foot_position = ent:GetPos()[3]

	local length_head_to_toe = math.abs(head_position - foot_position)
	local length_head_to_toe_25_percent = length_head_to_toe * 0.25

	local is_headchop = tobool(self_pos[3] <= head_position and self_pos[3] >= head_position - length_head_to_toe_25_percent)
	local is_torsochop = tobool(self_pos[3] <= head_position - length_head_to_toe_25_percent and self_pos[3] >= foot_position + length_head_to_toe_25_percent)
	local is_footchop = tobool(math.abs(foot_position - self_pos[3]) <= length_head_to_toe_25_percent)

	local mydamage = 40
	if is_headchop then
		mydamage = ent:Health() + 666
	elseif is_torsochop then
		local rand = math.random( 5, 10 ) //10% to 20% base health as dmg

		if nzombies and ent:IsValidZombie() then
			local round = nzRound:GetNumber() > 0 and nzRound:GetNumber() or 1
			local health = tonumber( nzCurves.GenerateHealthCurve( round ) )

			mydamage = math.max( mydamage, health / rand )
		else
			mydamage = math.max( mydamage, ent:GetMaxHealth() / rand )
		end
	elseif is_footchop then
		if nzombies and ent:IsValidZombie() and ent.DeflateBones and ent.BecomeCrawler and !ent.IsMooSpecial and !ent.HasGibbed then //crawl
			timer.Simple( 0, function()
				if not IsValid(ent) then return end
				if ent.Alive and not ent:Alive() then return end
				if ent.IsAlive and not ent:IsAlive() then return end
				if ent:Health() <= 0 then return end
				if ent.ShouldCrawl then return end
				if ent.HasGibbed then return end

				local lleg = ent:LookupBone("j_knee_le")
				local rleg = ent:LookupBone("j_knee_ri")
				local randleggib = math.random(4)

				if (lleg and !ent.LlegOff) and (randleggib == 1 or randleggib == 3) then
					ent.LlegOff = true
					ent:DeflateBones({
						"j_knee_le",
						"j_knee_bulge_le",
						"j_ankle_le",
						"j_ball_le",
					})

					ParticleEffectAttach("ins_blood_dismember_limb", 4, ent, 7)
				end

				if (rleg and !ent.RlegOff) and (randleggib == 2 or randleggib == 3) then
					ent.RlegOff = true
	    			ent:DeflateBones({
						"j_knee_ri",
						"j_knee_bulge_ri",
						"j_ankle_ri",
						"j_ball_ri",
					})

					ParticleEffectAttach("ins_blood_dismember_limb", 4, ent, 8)
				end

				ent:EmitSound("nz_moo/zombies/gibs/bodyfall/fall_0"..math.random(2)..".mp3",100)
				ent.ShouldCrawl = true
				ent:BecomeCrawler()
			end )
		end

		mydamage = 20
	end

	local damage = DamageInfo()
	damage:SetDamage( mydamage )
	damage:SetAttacker( IsValid(ply) and ply or self )
	damage:SetInflictor( IsValid(self.Inflictor) and self.Inflictor or self )
	damage:SetDamageForce( (trace and trace.Normal or self:GetAttachment(2).Ang:Up())*10000 + ent:GetUp()*5000 )
	damage:SetDamagePosition( trace and trace.HitPos or ent:WorldSpaceCenter() )
	damage:SetDamageType( bit.bor(DMG_CRUSH, DMG_SLASH) )

	if ent.NZBossType then
		damage:SetDamage( math.max( 600, ent:GetMaxHealth() / 12 ) )
	end

	if ent == ply then
		damage:SetDamage( 20 )
	end

	if ent:IsPlayer() or ent:IsNPC() or ent:IsNextBot() then
		local vecHit = trace and trace.HitPos or ent:WorldSpaceCenter() + ( ent:OBBCenter() * 0.7 )
		ParticleEffect( "blood_impact_red_01", vecHit, ent:GetForward():Angle() )

		local rand = VectorRand( -12, 12 )
		rand = Vector( rand.x, rand.y, 1 )
		util.Decal( "Blood", ent:GetPos() + rand, ent:GetPos() - rand )
	end

	ent:TakeDamageInfo( damage )
	ent:EmitSound( "TFA_BO3_GENERIC.Gib" )
end

function ENT:SetLastAttack( time )
	self.LastAttack = tonumber( time )
end

function ENT:GetLastAttack()
	return self.LastAttack
end
