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

//-------------------------------------------------------------
// Visuals
//-------------------------------------------------------------

local cl_achievements = GetConVar("cl_tfa_bo3ww_achievements")

WonderWeapons.AchievementTrophies = {
	[1] = "vgui/overlay/achievement_bronze.png",
	[2] = "vgui/overlay/achievement_silver.png",
	[3] = "vgui/overlay/achievement_gold.png",
	[4] = "vgui/overlay/achievement_platinum.png",
	[5] = "vgui/overlay/achievement_secret.png"
}

function WonderWeapons.GiveAchievement( ply, id )
	if not IsValid( ply ) or not ply:IsPlayer() then return end

	local data = WonderWeapons.AchievementData( id )
	if data and data.Name then
		hook.Run( "TFA_WonderWeapon_PlayerGetAchievement", ply, id )

		WonderWeapons.DoAchievementOverlay( tostring(data.Name), tostring(data.IconPath), tonumber(data.Trophy) )
	end
end

local achievement, trophy, icon, text, text2

function WonderWeapons.DoAchievementOverlay( actext, acicon, actrophy )
	if not cl_achievements:GetBool() then return end

	LocalPlayer():EmitSound( "TFA_BO3_GENERIC.Funny" )
	
	if IsValid(achievement) then achievement:Remove() end
	local w, h = ScrW(), ScrH()
	local scale = (w/1920 + 1) / 2

	achievement = vgui.Create("DImage")
	achievement:SetImage("vgui/overlay/achievement_bkg2.png")
	achievement:SetSize(340*scale, 85*scale)
	achievement:SetPos(w - (480*scale), h * (0.05*scale))

	achievement.CreateTime = CurTime()
	achievement.Alpha = 0
	achievement.Offset = 0

	achievement.Think = function()
		if achievement.CreateTime + 6 < CurTime() then
			achievement.Alpha = math.Approach(achievement.Alpha, 0, FrameTime() * 2)
			if achievement.Alpha <= 0 then
				achievement:Remove()
			end
		elseif achievement.Alpha < 1 then
			achievement.Alpha = math.Approach(achievement.Alpha, 1, FrameTime() * 5)
		end

		achievement:SetAlpha(achievement.Alpha * 255)
	end

	if IsValid(trophy) then trophy:Remove() end
	trophy = vgui.Create("DImage", achievement)
	trophy:SetSize(30*scale, 30*scale)
	trophy:SetPos(95*scale, 46*scale)
	trophy:SetImage(WonderWeapons.AchievementTrophies[actrophy], "vgui/avatar_default")

	if IsValid(icon) then icon:Remove() end
	local icon = vgui.Create("DImage", achievement)
	icon:SetSize(72*scale, 72*scale)
	icon:SetPos(10*scale, 6*scale)
	icon:SetImage(acicon, "vgui/avatar_default")

	if IsValid(text) then text:Remove() end
	local text = vgui.Create("DLabel", achievement)
	text:SetSize(256*scale, 64*scale)
	text:SetPos(100*scale, -10*scale)
	text:SetFont("HudHintTextLarge")
	text:SetText("You have earned a trophy.")
	text:SetTextColor(color_white)

	if IsValid(text2) then text2:Remove() end
	local text2 = vgui.Create("DLabel", achievement)
	text2:SetSize(256*scale, 64*scale)
	text2:SetPos(135*scale, 30*scale)
	text2:SetFont("HudHintTextLarge")
	text2:SetText(actext)
	text2:SetTextColor(color_white)
end

net.Receive("TFA.BO3WW.FOX.Achievement", function( length, ply )
	WonderWeapons.GiveAchievement( LocalPlayer(), net.ReadString() )
end)
