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

TrophyType.BRONZE = 1
TrophyType.SILVER = 2
TrophyType.GOLD = 3
TrophyType.PLATINUM = 4
TrophyType.SECRET = 5

WonderWeapons.AchievementPoints = {
	[1] = 950,
	[2] = 2250,
	[3] = 4500,
	[4] = 6000,
	[5] = 11500,
}

if SERVER then
	util.AddNetworkString("TFA.BO3.ACHIEVEMENT")
	util.AddNetworkString("TFA.BO3WW.FOX.Achievement")
end