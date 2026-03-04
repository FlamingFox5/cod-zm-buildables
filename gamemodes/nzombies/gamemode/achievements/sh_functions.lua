local nzombies = engine.ActiveGamemode() == "nzombies"
local pvp_cvar = GetConVar("sbox_playershurtplayers")
local SinglePlayer = game.SinglePlayer()

//-------------------------------------------------------------
// Achievements
//-------------------------------------------------------------

local WonderWeapons = TFA.WonderWeapon

WonderWeapons.Achievements = WonderWeapons.Achievements or {}

local AchievementTable = WonderWeapons.Achievements

AchievementTable.TrophyTypes = {}

local TrophyType = AchievementTable.TrophyTypes

function WonderWeapons.AddAchievement( id, data )
	AchievementTable[ id ] = data
end

function WonderWeapons.AchievementData( id )
	return AchievementTable[ id ] or nil
end

if SERVER then
	WonderWeapons.PlayerAchievements = WonderWeapons.PlayerAchievements or {}

	function WonderWeapons.GetAchievements( ply )
		if not IsValid( ply ) or not ply:IsPlayer() then
			return nil
		end

		if not WonderWeapons.PlayerAchievements[ ply:SteamID64() ] then
			WonderWeapons.PlayerAchievements[ ply:SteamID64() ] = {}
		end

		return WonderWeapons.PlayerAchievements[ ply:SteamID64() ]
	end

	function WonderWeapons.HasAchievement( ply, id )
		if not IsValid( ply ) or not ply:IsPlayer() then
			return true
		end

		local playerAchievements = WonderWeapons.GetAchievements( ply )

		return tobool( playerAchievements[ id ] )
	end

	function WonderWeapons.ResetAchievement( ply, id )
		if not IsValid( ply ) or not ply:IsPlayer() then return end

		local achievementData = WonderWeapons.AchievementData( id )
		if not achievementData then return end

		hook.Run( "TFA_WonderWeapon_PlayerResetAchievement", ply, id )

		achievementData.Reset( ply )
	end

	// TFA.WonderWeapon.GiveAchievement( Entity 'player', String 'achievement_id' )
	//  Use this inside of your .Call function to actually give the player the achievement
	//  when all (potential) requirements for the achievement are met.

	function WonderWeapons.GiveAchievement( ply, id )
		local achievementData = WonderWeapons.AchievementData( id )
		if not achievementData then return end

		if not IsValid( ply ) or not ply:IsPlayer() then return end

		local playerAchievements = WonderWeapons.GetAchievements( ply )
		if playerAchievements[ id ] then return end

		playerAchievements[ id ] = CurTime()

		ply:EmitSound( "TFA_BO3_GENERIC.Funny" )

		if not num then
			num = 1
		end

		num = math.Clamp( num, 1, 5 )

		hook.Run( "TFA_WonderWeapon_PlayerGetAchievement", ply, id )

		if nzombies and ply:Alive() then
			ply:GivePoints( achievementData.Points or WonderWeapons.AchievementPoints[num] or 0 )
		end

		net.Start( "TFA.BO3WW.FOX.Achievement" )
			net.WriteString( tostring(id) )
		net.Send( ply )
	end

	// TFA.WonderWeapon.NotifyAchievement( String 'achievement_id', Entity 'player', Any '...' )
	//  Use this to run the .Call function inside the achievement data table.
	//  The arguments you supply after the player entity depend on what achievement you are trying to call.
	//  Chances are if you're calling it, you made the achievement so you would already know what to supply.

	function WonderWeapons.NotifyAchievement( id, ply, ... )
		if not GetConVar("sv_tfa_bo3ww_achievements"):GetBool() then return end
		if not IsValid(ply) or not ply:IsPlayer() then return end

		local achievementData = WonderWeapons.AchievementData( id )
		if not achievementData then return end
		if not IsValid( attacker ) then return end

		// Return true to block achievement from being called
		//  please know what you are doing

		local hookOverride = hook.Run( "TFA_WonderWeapon_PlayerNotifyAchievement", ply, id, ... )
		if hookOverride ~= nil and tobool( hookOverride ) then
			return
		end

		achievementData.Call( ply, ... )
	end
end
