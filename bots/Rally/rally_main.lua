--[[
--Rally v0.1 by Schnarchnase

description:

credits:

versions history:
v.01: initial release

--	sightrangeday="1800"
--	sightrangenight="800"

--]]
local _G = getfenv(0)
local object = _G.object

object.myName = object:GetName()

object.bRunLogic 		= true
object.bRunBehaviors	= true
object.bUpdates 		= true
object.bUseShop 		= true

object.bRunCommands 	= true
object.bMoveCommands 	= true
object.bAttackCommands 	= true
object.bAbilityCommands = true
object.bOtherCommands 	= true

object.bReportBehavior = true
object.bDebugUtility = false
object.bDebugExecute = false

object.logger = {}
object.logger.bWriteLog = false
object.logger.bVerboseLog = false

object.core 		= {}
object.eventsLib 	= {}
object.metadata 	= {}
object.behaviorLib 	= {}
object.skills 		= {}

runfile "bots/core.lua"
runfile "bots/botbraincore.lua"
runfile "bots/eventsLib.lua"
runfile "bots/metadata.lua"
runfile "bots/behaviorLib.lua"
runfile "bots/Rally/survivalLib.lua"
local life = object.life
local shoppingLib = object.shoppingLib

local core, eventsLib, behaviorLib, metadata, skills = object.core, object.eventsLib, object.behaviorLib, object.metadata, object.skills

local print, ipairs, pairs, string, table, next, type, tinsert, tremove, tsort, format, tostring, tonumber, strfind, strsub
	= _G.print, _G.ipairs, _G.pairs, _G.string, _G.table, _G.next, _G.type, _G.table.insert, _G.table.remove, _G.table.sort, _G.string.format, _G.tostring, _G.tonumber, _G.string.find, _G.string.sub
local ceil, floor, pi, tan, atan, atan2, abs, cos, sin, acos, max, random
	= _G.math.ceil, _G.math.floor, _G.math.pi, _G.math.tan, _G.math.atan, _G.math.atan2, _G.math.abs, _G.math.cos, _G.math.sin, _G.math.acos, _G.math.max, _G.math.random

local BotEcho, VerboseLog, BotLog = core.BotEcho, core.VerboseLog, core.BotLog
local Clamp = core.Clamp

BotEcho('loading rally_main...')

object.heroName = 'Hero_Rally'


local tCompellDamage = {70,130,190,250}
--local tCompellStun = {1250,1500,1750,2000}
local tRoarDamage = {40,80,120,160}
local tBattleExpPierce = {0.15,0.30,0.45,0.60}
local tSlamDamage = {400,650,900}
local tSlamDamageBoosted = {600,850,1100}
--normal and boosted
local tSlamRadius = {250,500}

--------------------------------
-- Lanes
--------------------------------
core.tLanePreferences = {Jungle = 0, Mid = 5, ShortSolo = 4, LongSolo = 4, ShortSupport = 1, LongSupport = 1, ShortCarry = 4, LongCarry = 4}

--------------------------------
-- Skills
--------------------------------
--[[
Max Compel first
Slam whenever possible
Decide between BattleExp and Roar depending on enemy armor
Stats last
--]] 
local function funcGetCompellDamage (nLevel)
	if not nLevel or nLevel > 4 or nLevel < 1 then
		return 0
	end
	return tCompellDamage[nLevel]
end

local function funcGetRoarDamage (nLevel)
	if not nLevel or nLevel > 4 or nLevel < 1 then
		return 0
	end
	return tRoarDamage[nLevel]
end

local function funcGetBattleExpPierce (nLevel)
	if not nLevel or nLevel > 4 or nLevel < 1 then
		return 0
	end
	return tBattleExpPierce[nLevel]
end

local function funcGetSlamDamage (nLevel)
	if not nLevel or nLevel > 3 or nLevel < 1 then
		return 0
	end
	local itemStaffOfTheMaster = core.GetItem("Item_Intelligence7")
	if itemStaffOfTheMaster then
		return tSlamDamageBoosted[nLevel]
	else
		return tSlamDamage[nLevel]
	end
end

local function funcGetSlamRadius ()
	local itemStaffOfTheMaster = core.GetItem("Item_Intelligence7")
	if itemStaffOfTheMaster then
		return tSlamRadius[2]
	else
		return tSlamRadius[1]
	end
end

local function funcCheckingRoarPrioity ()
	local bDebugEchos = true
	
	local teamBotBrain = core.teamBotBrain
	if teamBotBrain then
		local nArmorValueWeighted = 0
		local nWeighting = 0
		
		local tEnemyHeroes = teamBotBrain.tEnemyHeroes
		for _, unitEnemy in pairs(tEnemyHeroes) do
			
			local nID = unitEnemy:GetUniqueID()
			local tEnemyInformation = teamBotBrain.tEnemyInformationTable[nID]
			
			if tEnemyInformation then
				local nArmor = tEnemyInformation.nPArmor or 5
				local nLevelBonus = 35 - (tEnemyInformation.nLevel or 5)
				
				if bDebugEchos then BotEcho("unit: "..unitEnemy:GetTypeName().." armor: "..nArmor.." levelbonus "..nLevelBonus) end
				nArmorValueWeighted = nArmorValueWeighted + nArmor * nLevelBonus
				nWeighting = nWeighting + nLevelBonus
			end
		end
		
		if nWeighting > 0 then
			nArmorValueWeighted = nArmorValueWeighted / nWeighting
			if bDebugEchos then BotEcho("Average Armor: "..nArmorValueWeighted) end
			
			local nNumberOfAutoAttacks = 1
			local nAutoAttackDamageMin = core.unitSelf:GetFinalAttackDamageMin()
			
			local nLevelCompell = skills.abilCompell:GetLevel()
			local nCompellDamage = funcGetCompellDamage(nLevelCompell)
			if nLevelCompell > 2 then
				nNumberOfAutoAttacks = nNumberOfAutoAttacks +1
			end
			
			local nSlamDamage = funcGetSlamDamage(skills.abilSlam:GetLevel())
			
			local nDamageLevelingRoar = 0
			local nLevelRoar = skills.abilRoar:GetLevel()
			if nLevelRoar > 0 then
				nNumberOfAutoAttacks = nNumberOfAutoAttacks +1
			else
				nDamageLevelingRoar = nAutoAttackDamageMin
			end
			local nLevelBExp = skills.abilBattleExp:GetLevel()
			
			
			local nMaxDamage = nCompellDamage + nSlamDamage + nAutoAttackDamageMin*nNumberOfAutoAttacks
			
			nDamageLevelingRoar = nDamageLevelingRoar + nMaxDamage + funcGetRoarDamage(nLevelRoar+1)
			local nDamageLevelingBExp = nMaxDamage + funcGetRoarDamage(nLevelRoar)
			
			if bDebugEchos then 
				BotEcho("Compell-Damage: "..nCompellDamage)
				BotEcho("Slam-Damage: "..nSlamDamage)
				BotEcho("Number of Attacks: "..nNumberOfAutoAttacks.." and autohit damage "..nAutoAttackDamageMin)
				BotEcho("max damage: "..nMaxDamage)
				BotEcho("Roar-Damage before armor: "..nDamageLevelingRoar)
				BotEcho("BExp-Damage before armor: "..nDamageLevelingBExp)
			end
			--use armor values
			nDamageLevelingRoar = nDamageLevelingRoar *100/(100+nArmorValueWeighted*(1-funcGetBattleExpPierce(nLevelBExp))*6)
			nDamageLevelingBExp = nDamageLevelingBExp * 100/(100+nArmorValueWeighted*(1-funcGetBattleExpPierce(nLevelBExp+1))*6)
			
			if bDebugEchos then 
				BotEcho("Roar-Damage after armor: "..nDamageLevelingRoar)
				BotEcho("BExp-Damage after armor: "..nDamageLevelingBExp)
			end
			
			if nDamageLevelingRoar > nDamageLevelingBExp then
				if bDebugEchos then BotEcho("Roar damage is superior. Leveling Roar!") end
				return true
			else
				if bDebugEchos then BotEcho("BExp damage is superior. Leveling BExp!") end
				return false
			end
		end
		if bDebugEchos then BotEcho("No Enemies found.") end
	end
	if bDebugEchos then BotEcho("teamBotBrain not found.") end
	return true
end

function object:SkillBuild()

	local unitSelf = core.unitSelf

	if skills.webbedShot == nil then
		skills.abilCompell = unitSelf:GetAbility(0)
		skills.abilRoar = unitSelf:GetAbility(1)
		skills.abilBattleExp = unitSelf:GetAbility(2)
		skills.abilSlam = unitSelf:GetAbility(3)
		skills.abilAttributeBoost = unitSelf:GetAbility(4)
		skills.abilTaunt = unitSelf:GetAbility(8)
	end
		
	if unitSelf:GetAbilityPointsAvailable() <= 0 then
		return
	end
	
	local abilSlam = skills.abilSlam
	if abilSlam:CanLevelUp() then
		abilSlam:LevelUp()
		return
	end
	
	local abilCompell = skills.abilCompell
	if abilCompell:CanLevelUp() then
		abilCompell:LevelUp()
		return
	end
	
	local nMyLevel = unitSelf:GetLevel()
	
	if nMyLevel < 15 then 
		local bLevelRoarOverBExp = funcCheckingRoarPrioity()
		
		local abilRoar = skills.abilRoar
		local abilBattleExp = skills.abilBattleExp
		if bLevelRoarOverBExp then
			abilRoar:LevelUp()
			return
		else
			abilBattleExp:LevelUp()
			return
		end
	else
		skills.abilAttributeBoost:LevelUp()
	end	
end

---------------------------------------------------
--                   Overrides                   --
---------------------------------------------------

	
----------------------------------
--	Rally specific harass bonuses
--
--  Abilities off cd increase harass util
--  Ability use increases harass util for a time
----------------------------------

object.nCompellUp = 9
object.nRoarUp = 4
object.nSlamUp = 18
object.nFinishHim = 50
object.nSpeedBonus = 5

object.nCompellUse = 15
object.nRoarUse = 8
object.nSlamUse = 5

object.nCompellOffensiveThreshold = 40
object.nCompellDefensiveThreshold = 40
object.nRoarDefensiveThreshold = 35
object.nSlamThreshold = 70

----------------------------------
--CustomHarassUtility
----------------------------------

--ally bonus near yourself
object.nAllyBonus = 6
--Heroes near unitTarget
object.nHeroRangeSq = 1000*1000
-- utility malus per enemy hero near target
object.nEnemyThreat = 10

behaviorLib.nCreepPushbackMul = 0.5

	
	
--Arachna ability use gives bonus to harass util for a while
function object:oncombateventOverride(EventData)
	self:oncombateventOld(EventData)
	
	local nAddBonus = 0
	
	if EventData.Type == "Ability" then
		if EventData.InflictorName == "Ability_Rally1" and object.nCurrentBehavior == "HarassHero" then
			nAddBonus = nAddBonus + object.nCompellUse
			object.nGraveyardUseTime = EventData.TimeStamp
		elseif EventData.InflictorName == "Ability_Rally2" then
			nAddBonus = nAddBonus + object.nRoarUse
		elseif EventData.InflictorName == "Ability_Rally4" then
			nAddBonus = nAddBonus + object.nSlamUse
		end
	end
	
	if nAddBonus > 0 then
		--decay before we add
		core.DecayBonus(self)
	
		core.nHarassBonus = core.nHarassBonus + nAddBonus
	end
end
object.oncombateventOld = object.oncombatevent
object.oncombatevent 	= object.oncombateventOverride

object.nMeleeHarassBenousRangeSq = 200*200
--Util override
local function CustomHarassUtilityOverride(unitTarget)
	local nUtility = 0
	
	if not unitTarget then 
		return nUtility
	end
	
	--get unitTarget information from teamBotBrain
	local teamBotBrain = core.teamBotBrain
	if not teamBotBrain then
		return nUtility
	end
	
	local nID = unitTarget:GetUniqueID()
	local tEnemyInformation = teamBotBrain.tEnemyInformationTable[nID]
	local nEnemyCurrentHP = tEnemyInformation and tEnemyInformation.nCurrentHealth 
	
	
	--Allies Bonus
	local tAllies = core.localUnits["AllyHeroes"]
	local nAllies = core.NumberElements(tAllies)
	local nAllyBonus = object.nAllyBonus
	nUtility = nUtility + nAllies * nAllyBonus
	
	--Enemies near target decrease utility
	local nEnemyThreat = object.nEnemyThreat
	local nHeroRangeSq = object.nHeroRangeSq

	local tEnemyTeam = HoN.GetHeroes(core.enemyTeam)

	--units close to hero
	for _, unitEnemy in pairs(tEnemyTeam) do
		local nEnemyID = unitEnemy:GetUniqueID()
		local tAnotherEnemyInfo = teamBotBrain.tEnemyInformationTable[nEnemyID]
		if nID ~= nEnemyID and tAnotherEnemyInfo then
			local vecUnitEnemyPosition = tAnotherEnemyInfo.bIsValid and tAnotherEnemyInfo.vecCurrentPosition
			if vecUnitEnemyPosition and Vector3.Distance2DSq(tEnemyInformation.vecCurrentPosition, vecUnitEnemyPosition) < nHeroRangeSq then
				nUtility = nUtility - nEnemyThreat
			end
		end
	end
	
	local unitSelf = core.unitSelf
	
	--Check Damage utility
	if nEnemyCurrentHP then
		
		nUtility = nUtility + (1-nEnemyCurrentHP/tEnemyInformation.nMaxHealth) * 15
		
		
		
		local nMyMana = unitSelf:GetMana()
		local nNeededMana = 0
		
		local nDamage = 0
		local nNumberAutoAttacks = 0
		
		local nEnemyArmor = tEnemyInformation.nPArmor
		
		local nArmorPierce = funcGetBattleExpPierce(skills.abilBattleExp:GetLevel())
	
		nEnemyArmor = nEnemyArmor * (1-nArmorPierce)
		
		local nEnemyEHP = nEnemyCurrentHP * (100+nEnemyArmor*6)/100
				
		local abilCompell = skills.abilCompell
		if skills.abilCompell:CanActivate() then
			nNeededMana = abilCompell:GetManaCost()
			nDamage = funcGetCompellDamage(abilCompell:GetLevel())
			nUtility = nUtility + object.nCompellUp
			if nDamage >= nEnemyEHP then
				return nUtility+object.nFinishHim
			end
			nNumberAutoAttacks = nNumberAutoAttacks + 1
		end
		
		local abilSlam = skills.abilSlam
		if skills.abilSlam:CanActivate() then
			nNeededMana = nNeededMana + abilSlam:GetManaCost()
			if nNeededMana <= nMyMana then
				nDamage = funcGetSlamDamage(abilSlam:GetLevel())
				nUtility = nUtility + object.nSlamUp
				if nDamage >= nEnemyEHP then
					return nUtility+object.nFinishHim
				end
			end
		end
		
		local abilRoar = skills.abilRoar
		if skills.abilRoar:CanActivate() then
			nNeededMana = nNeededMana + abilRoar:GetManaCost()
			if nNeededMana <= nMyMana then
				nDamage = funcGetRoarDamage(abilRoar:GetLevel())
				nUtility = nUtility + object.nRoarUp
				if nDamage >= nEnemyEHP then
					return nUtility+object.nFinishHim
				end
				nNumberAutoAttacks = nNumberAutoAttacks + 2
			end
		end
		
		local nEnemyMovementSpeed = tEnemyInformation.nPArmor
		local nSpeeddifference = nEnemyMovementSpeed - unitSelf:GetMoveSpeed()
		
		if nSpeeddifference > 100 then
			nNumberAutoAttacks = nNumberAutoAttacks + 3
			nUtility = nUtility + object.nSpeedBonus*3
		elseif nSpeeddifference > 50 then
			nNumberAutoAttacks = nNumberAutoAttacks + 2
			nUtility = nUtility + object.nSpeedBonus*2
		elseif nSpeeddifference > 0 then
			nNumberAutoAttacks = nNumberAutoAttacks + 1
			nUtility = nUtility + object.nSpeedBonus
		end
		
		local nAutoAttackDamageMin = unitSelf:GetFinalAttackDamageMin()
		nDamage = nDamage + nAutoAttackDamageMin * nNumberAutoAttacks
		if nDamage >= nEnemyEHP then
			return nUtility+object.nFinishHim
		end
		
		local unitTargetPosition =  tEnemyInformation.vecCurrentPosition
		if Vector3.Distance2DSq(unitSelf:GetPosition(), unitTargetPosition) < object.nMeleeHarassBenousRangeSq then 
			nUtility = nUtility + 10
		end
	end
	
	if unitSelf:GetManaPercent() > 0.9 then
		nUtility = nUtility + 10
	end
	
	return nUtility
end
behaviorLib.CustomHarassUtility = CustomHarassUtilityOverride   

----------------------------------
--	Arachna harass actions
----------------------------------
object.nCompellTime = 0
local function HarassHeroExecuteOverride(botBrain)
	local unitTarget = behaviorLib.heroTarget
	if unitTarget == nil or not unitTarget:IsValid() then
		return false --can not execute, move on to the next behavior
	end
	
	local nLastHarassUtility = behaviorLib.lastHarassUtil
	
	--get unitTarget information from teamBotBrain
	local teamBotBrain = core.teamBotBrain
	if not teamBotBrain then
		return object.harassExecuteOld(botBrain)
	end
	
	local nID = unitTarget:GetUniqueID()
	local tEnemyInformation = teamBotBrain.tEnemyInformationTable[nID]
	local vecEnemyPosition = tEnemyInformation.vecCurrentPosition 
	
	local nTargetHP = tEnemyInformation.nCurrentHealth
	local nTargetArmor = tEnemyInformation.nPArmor * (1-funcGetBattleExpPierce(skills.abilBattleExp:GetLevel()))
	local nTargetEHP = nTargetHP * (100+nTargetArmor*6)/100
	
	local unitSelf = core.unitSelf
	local vecMyPosition = unitSelf:GetPosition()
	local nMyMana = unitSelf:GetMana()
	
	local nTargetDistanceSq = Vector3.Distance2DSq(vecEnemyPosition, vecMyPosition)
	
	local abilCompell = skills.abilCompell
	local nCompellStunRange = abilCompell:GetRange() - 150
	local nCompellStunRangeSq = nCompellStunRange * nCompellStunRange
	
	local vecTargetLocation = Vector3.Normalize(vecEnemyPosition - vecMyPosition) * nCompellStunRange
	
	local nNow = HoN.GetGameTime()
	local bActionTaken = false
	
	--use PK or GM
	local itemPK = core.GetItem("Item_PortalKey")
	if itemPK and itemPK:CanActivate() and nLastHarassUtility >= object.nCompellOffensiveThreshold then
		local nPortalKeyRange = itemPK:GetRange()
		local bCompell = abilCompell:CanActivate()
		local nPortalKeyRangeSq = nPortalKeyRange*nPortalKeyRange 
		if nMyMana >= 205 and nTargetDistanceSq > 650*650 
			and bCompell and nTargetDistanceSq < nPortalKeyRangeSq + nCompellStunRangeSq then
				bActionTaken = core.OrderItemPosition(botBrain, unitSelf, itemPK, vecEnemyPosition - vecTargetLocation)
		elseif not bCompell and nTargetDistanceSq < nPortalKeyRangeSq 
			and nTargetDistanceSq > 450*450 then
			local vecTargetPosition = (tEnemyInformation.vecRelativeMovement and tEnemyInformation.vecRelativeMovement *10 + 
										vecEnemyPosition) or vecEnemyPosition + vecTargetLocation					
			bActionTaken = core.OrderItemPosition(botBrain, unitSelf, itemPK, vecTargetPosition)
		end
	else
		local itemGhostMarchers = core.GetItem("Item_EnhancedMarchers")
		if itemGhostMarchers and itemGhostMarchers:CanActivate() and nTargetDistanceSq > 600*600 then
			bActionTaken = core.OrderItemClamp(botBrain, unitSelf, itemGhostMarchers)
		end
	end
	
	
	local bTargetRooted = unitTarget:IsStunned() or unitTarget:IsImmobilized() or unitTarget:GetMoveSpeed() < 200
	
	core.DrawDebugArrow(vecMyPosition, vecMyPosition + vecTargetLocation, 'teal')
	--use Compell
	if not bActionTaken and  abilCompell:CanActivate() and nLastHarassUtility >= object.nCompellOffensiveThreshold then
		--use compel to kill
		local nAutoHitDamage = unitSelf:GetFinalAttackDamageMin()
		if nTargetEHP < funcGetCompellDamage(abilCompell:GetLevel()) + 2*nAutoHitDamage and nTargetDistanceSq < 600*600 then
			core.OrderAbilityEntityVector(botBrain, abilCompell, unitSelf, vecTargetLocation)
			object.nCompellTime = nNow
		elseif not bTargetRooted and nTargetDistanceSq < nCompellStunRangeSq and nTargetDistanceSq > 300*300 then
			core.OrderAbilityEntityVector(botBrain, abilCompell, unitSelf, vecTargetLocation)
			object.nCompellTime = nNow
		end
	end
	
	--Taunting!!!
	if not bActionTaken and core.CanSeeUnit(botBrain, unitTarget) then		
		local abilTaunt = skills.abilTaunt
		if abilTaunt:CanActivate() and nLastHarassUtility > object.nSlamThreshold then
			local nRange = 500
			if nTargetDistanceSq < (nRange * nRange) then
				bActionTaken = core.OrderAbilityEntity(botBrain, abilTaunt, unitTarget)
			end
		end
	end
	
	--use Slam
	local abilSlam = skills.abilSlam
	if not bActionTaken and  abilSlam:CanActivate() and nLastHarassUtility >= object.nSlamThreshold and bTargetRooted then
		local nSlamRadius = funcGetSlamRadius()
		if nTargetDistanceSq < nSlamRadius*nSlamRadius then
			bActionTaken = core.OrderAbilityPosition(botBrain, abilSlam, vecEnemyPosition)
			object.nSlamTime = nNow
		end
	end
	
	--use Roar
	local abilRoar = skills.abilRoar
	if not bActionTaken and abilRoar:CanActivate() and not abilCompell:CanActivate() 
		and object.nCompellTime + 500 < nNow and  not bTargetRooted then
		local nRange = 500
		if nTargetDistanceSq < nRange*nRange then
			bActionTaken = core.OrderAbility(botBrain, abilRoar)
		end
	end
	
	if not bActionTaken then
		return object.harassExecuteOld(botBrain)
	end
end
object.harassExecuteOld = behaviorLib.HarassHeroBehavior["Execute"]
behaviorLib.HarassHeroBehavior["Execute"] = HarassHeroExecuteOverride
--[[
--hunting/grouphunting util
function object.funcCheckRequirementsToGank()
	return 3000*3000
end

function object.GetGankingPower(unitEnemy)
	return 600, 55, 3, 10000
end

--hunting exec
function object.HuntingUtility(botBrain)
	return core.teamBotBrain.HuntingUtility(botBrain)
end
 
function object.HuntingExe(botBrain)
	local tHunting = core.teamBotBrain.GetHuntingStatus(botBrain)
	
	BotEcho("tHunting")
end
 
behaviorLib.Hunting = {}
behaviorLib.Hunting["Utility"] = object.HuntingUtility
behaviorLib.Hunting["Execute"] = object.HuntingExe
behaviorLib.Hunting["Name"] = "Hunting"
tinsert(behaviorLib.tBehaviors, behaviorLib.Hunting) 
--Push Exec
--]]
--Retreat exec
function behaviorLib.RetreatFromThreatExecuteOverride(botBrain)
	
	local unitSelf = core.unitSelf
	
	local unitTarget = behaviorLib.heroTarget
	if unitTarget == nil or not unitTarget:IsValid() then
		return false 
	end
	
	--get unitTarget information from teamBotBrain
	local teamBotBrain = core.teamBotBrain
	if not teamBotBrain then
		return false
	end
	
	
	local vecMyPosition = unitSelf:GetPosition()
	--Compell out
	local abilCompell = skills.abilCompell
	if abilCompell:CanActivate() and object.nCompellDefensiveThreshold < behaviorLib.lastRetreatUtil then
		local vecPos = (behaviorLib.PositionSelfBackUp() - vecMyPosition) 
		return core.OrderAbilityEntityVector(botBrain, abilCompell, unitSelf, vecPos)
	end		
	
	local nID = unitTarget:GetUniqueID()
	local tEnemyInformation = teamBotBrain.tEnemyInformationTable[nID]
	local vecEnemyPosition = tEnemyInformation.vecCurrentPosition 
	local nTargetDistanceSq = Vector3.Distance2DSq(vecEnemyPosition, vecMyPosition)
	
	--Slow down speedy
	local abilRoar = skills.abilRoar
	if not bActionTaken and abilRoar:CanActivate() and object.nRoarDefensiveThreshold < behaviorLib.lastRetreatUtil then
		local nRange = 500
		if nTargetDistanceSq < nRange*nRange then
			return core.OrderAbility(botBrain, abilRoar)
		end
	end
	
	return false
end
behaviorLib.CustomRetreatExecute = behaviorLib.RetreatFromThreatExecuteOverride


------------------------------------------------------------------
--Heal at well execute
------------------------------------------------------------------
local function HealAtWellExecuteFnOverride(botBrain)
	
	local unitSelf = core.unitSelf
	local vecMyPosition = unitSelf:GetPosition()
	local vecWellPos = core.allyWell and core.allyWell:GetPosition() or behaviorLib.PositionSelfBackUp()
	local nDistanceWellSq =  Vector3.Distance2DSq(vecMyPosition, vecWellPos)

	--marcher hom
	local itemGhostMarchers = core.GetItem("Item_EnhancedMarchers")
	if itemGhostMarchers and itemGhostMarchers:CanActivate() and nDistanceWellSq > (500 * 500) then
		return core.OrderItemClamp(botBrain, unitSelf, itemGhostMarchers)
	end

	--Portal Key: Port away
	local itemPK = core.GetItem("Item_PortalKey")
	if itemPK and itemPK:CanActivate() and nDistanceWellSq > (1000 * 1000)  then
		return core.OrderItemPosition(botBrain, unitSelf, itemPK, vecWellPos)
	end
	
	--Compell home
	local abilCompell = skills.abilCompell
	if abilCompell:CanActivate() and nDistanceWellSq > (600 * 600) then
		local vecPos = vecWellPos - vecMyPosition
		return core.OrderAbilityEntityVector(botBrain, abilCompell, unitSelf, vecPos)
	end	
	
	return core.OrderMoveToPosAndHoldClamp(botBrain, unitSelf, vecWellPos, false)
end
behaviorLib.HealAtWellBehavior["Execute"] = HealAtWellExecuteFnOverride

--no bottle on easy!!!

--runeing
behaviorLib.nRuneGrabRange = 1500
-- 30 if there is rune within 1000 and we see it
local function PickRuneUtilityOverride(botBrain)

	-- [Difficulty: Easy] Bots do not get runes on easy
	if core.nDifficulty == core.nEASY_DIFFICULTY then
		return 0
	end
	
	local nRuneGrabRange = behaviorLib.nRuneGrabRange
	--bottle? check rune frequently
	local itemBottle = core.GetItem("Item_Bottle")
	if itemBottle then
		nRuneGrabRange = nRuneGrabRange + 1500
	end
	
		
	local tRune = core.teamBotBrain.GetNearestRune(core.unitSelf:GetPosition(), false, true)
	if tRune == nil or Vector3.Distance2DSq(tRune.vecLocation, core.unitSelf:GetPosition()) > nRuneGrabRange * nRuneGrabRange then
		return 0
	end

	behaviorLib.tRuneToPick = tRune

	return 35
end
behaviorLib.PickRuneBehavior["Utility"] = PickRuneUtilityOverride

local function PickRuneExecuteOverride(botBrain)
	tRune = behaviorLib.tRuneToPick
	if tRune == nil or tRune.vecLocation == nil or tRune.bPicked then
		return false
	end
	local vecRunePosition = tRune.vecLocation
	local unitSelf = core.unitSelf
	--local nDistanceSQ = Vector3.Distance2DSq(vecRunePosition, unitSelf:GetPosition())
	
	if not HoN.CanSeePosition(vecRunePosition) or not tRune.unit then
		return behaviorLib.MoveExecute(botBrain, vecRunePosition)
	elseif tRune.unit and tRune.unit:IsValid() then
		BotEcho("Touching")
		return core.OrderTouch(botBrain, unitSelf, tRune.unit)
	else 
		return false
	end
end
behaviorLib.PickRuneBehavior["Execute"] = PickRuneExecuteOverride

 object.nHelpTreshold = 40
function object.SavingAlliesUtility(botBrain)
	local nUtility = 0 
	
	if not skills.abilCompell:CanActivate() then 
		return nUtility
	end
	
	local tAlliesNear = core.localUnits["AllyHeroes"]
	local nAlliesNear = core.NumberElements(tAlliesNear)
	
	if nAlliesNear > 0 then
		local funcTimeToLive = life.funcTimeToLiveUtility
		for _, unitAlly in pairs(tAlliesNear) do
			--Isn't there a Restrained bool?or unitAlly:IsRestrained()
			local bAllyIsInvalid = unitAlly:IsImmobilized()  or object.isMagicImmune(unitAlly)
			local nUtilityAlly = not bAllyIsInvalid and funcTimeToLive(unitAlly)
			if nUtilityAlly and nUtilityAlly > nUtility then
				nUtility = nUtilityAlly
				object.unitToSave = unitAlly
			end
		end
	end
	
	if nUtility >= object.nHelpTreshold then
		return Clamp(nUtility, 0, 50) 
	else 
		return 0
	end
end

function object.SavingAlliesExecution(botBrain)
	
	local unitToSave = object.unitToSave
	if not object.unitToSave then
		return false
	end
	--or unitAlly:IsRestrained()
	local bAllyIsInvalid = unitToSave:IsImmobilized()  or object.isMagicImmune(unitToSave)
	local abilCompell = skills.abilCompell
	if not abilCompell:CanActivate() or bAllyIsInvalid then
		return false
	end
	
	local unitSelf = core.unitSelf
	local vecMyPosition = unitSelf:GetPosition()
	local vecAllyPosition = unitToSave:GetPosition()
	local nDistanceSq = Vector3.Distance2DSq(vecMyPosition, vecAllyPosition)
	
	local nCompellStunRange = abilCompell:GetRange()
		
	if nDistanceSq < nCompellStunRange*nCompellStunRange then
		local vecPos = (behaviorLib.PositionSelfBackUp() - vecAllyPosition) 
		return core.OrderAbilityEntityVector(botBrain, abilCompell, unitToSave, vecPos)
	else
		return core.OrderMoveToPos(botBrain, unitSelf, vecAllyPosition)
	end

end

behaviorLib.SavingAllies = {}
behaviorLib.SavingAllies["Utility"] = object.SavingAlliesUtility
behaviorLib.SavingAllies["Execute"] = object.SavingAlliesExecution
behaviorLib.SavingAllies["Name"] = "Saving Allies"
tinsert(behaviorLib.tBehaviors, behaviorLib.SavingAllies) 

--Shopping

--call setup function
--We have to wait for our lane to ensure that we get the right items for midlane (Bottle)
--We take care of the reservation ourself
shoppingLib.Setup({bWaitForLaneDecision = true, bReserveItems = false })

local function funcCheckSurvivalItem (tItemDecisions) 
	--"none", "magic", "physical", "hp"
	return "none"
end

--Rally Shopping function
local function RallyItemBuild()
	--called everytime your bot runs out of items, should return false if you are done with shopping
	local bDebugInfo = true
    
	if bDebugInfo then BotEcho("Checking itembuilder of Rally") end

	  
	--get itembuild decision table 
	local tItemDecisions = shoppingLib.tItemDecisions
	if bDebugInfo then BotEcho("Found ItemDecisions"..type(tItemDecisions)) end
		
	if not tItemDecisions.nBigItems then
		tItemDecisions.nBigItems = 0
	end
	local nBigItems = tItemDecisions.nBigItems
	if nBigItems == 6 then
		--inventory is full stop shopping 
		if bDebugInfo then BotEcho("Done Shopping") end
		return false
	end
	
	--decision helper
	local nGPM = object:GetGPM()
	
	
	--start items
	if not tItemDecisions.bLane then
		local bNewItems = false
		--check our lane
		local tLane = core.tMyLane
		if tLane then
		--we found our lane, checkout its information
			if bDebugInfo then BotEcho("Found my Lane") end
			
			local tStartingItems = nil
			if tLane.sLaneName == "middle" then
				--our bot was assigned to the middle lane
				if bDebugInfo then BotEcho("I will take the Mid-Lane.") end
				tStartingItems = {"Item_LoggersHatchet", "Item_IronBuckler", "Item_RunesOfTheBlight", "Item_Bottle", "Item_Marchers"}
				tItemDecisions.bSkipRegen = true
			else
				--our bot was assigned to a side-lane lane
				if bDebugInfo then BotEcho("Got on a sidelane") end
				tStartingItems = {"Item_LoggersHatchet", "Item_IronBuckler", "Item_RunesOfTheBlight", "Item_ManaPotion", "Item_Marchers"}
			end
			
			--insert decisions into our itembuild-table
			core.InsertToTable(shoppingLib.tItembuild, tStartingItems)
			
			--we have implemented new items, so we can keep shopping
			bNewItems = true
		else
			--lane is not set yet, this will cause issues in further item developement
			if bDebugInfo then BotEcho("Error! No Lane set. No more shopping!") end
		end
			
		--remember our decision
		tItemDecisions.bLane = true
		if bDebugInfo then BotEcho("Starting items finished. Keep shopping? "..tostring(bNewItems)) end
		return bNewItems
	end
	
	local sSurvivalattribute = funcCheckSurvivalItem(tItemDecisions)

	
	if sSurvivalattribute == "magic" and not tItemDecisions.bBarrierIdol then
		if not tItemDecisions.bVestment then
			tinsert(shoppingLib.tItembuild, "Item_MysticVestments")
			if bDebugInfo then BotEcho("Need Vestments") end
			tItemDecisions.bVestment = true
			return true
		elseif not tItemDecisions.bShamans then
			tinsert(shoppingLib.tItembuild, "Item_MagicArmor2")
			if bDebugInfo then BotEcho("Need Shamans") end
			tItemDecisions.bShamans = true
			return true		
		else
			tItemDecisions.bBarrierIdol = true
			local teamBotBrain = core.teamBotBrain
			local sBarrierIdol = "Item_BarrierIdol"
			if teamBotBrain and teamBotBrain.ReserveItem(sBarrierIdol) then
				tinsert(shoppingLib.tItembuild, sBarrierIdol)
				if bDebugInfo then BotEcho("Need Barrier") end
				tItemDecisions.nBigItems = nBigItems + 1
				return true
			end
		end
	elseif sSurvivalattribute == "physical" and tItemDecisions.bBootsFinished then
		if tItemDecisions.bSolsBulwark == nil then 
			local teamBotBrain = core.teamBotBrain
			local sSolsBulwark = "Item_SolsBulwark"
			if teamBotBrain and teamBotBrain.ReserveItem(sSolsBulwark) and teamBotBrain.ReserveItem("Item_DaemonicBreastplate") then
				tinsert(shoppingLib.tItembuild, sSolsBulwark)
				tItemDecisions.bSolsBulwark = true
				if bDebugInfo then BotEcho("Need Sols") end
				return true
			else
				if bDebugInfo then BotEcho("Sols or Daemonic is already taken... Going for something else") end
				tItemDecisions.bSolsBulwark = false --keep in mind we have to check the other options here --> no elseif
			end
		end
		
		if tItemDecisions.bSolsBulwark and not tItemDecisions.bDaemonic then
			tinsert(shoppingLib.tItembuild, "Item_DaemonicBreastplate")
			tItemDecisions.bDaemonic = true
			if bDebugInfo then BotEcho("Need Daemonic!") end
			tItemDecisions.nBigItems = nBigItems + 1
			return true
		elseif not tItemDecisions.bFrostfield then
			tinsert(shoppingLib.tItembuild, "Item_FrostfieldPlate")
			tItemDecisions.bFrostfield = true
			if bDebugInfo then BotEcho("Need FrostfieldPlate!") end
			tItemDecisions.nBigItems = nBigItems +1
			return true
		elseif not tItemDecisions.bAbyssal then
			tItemDecisions.bAbyssal = true
			local teamBotBrain = core.teamBotBrain
			local sAbyssal = "Item_LifeSteal5"
			if teamBotBrain and teamBotBrain.ReserveItem(sAbyssal) then
				tinsert(shoppingLib.tItembuild, sAbyssal)
				if bDebugInfo then BotEcho("Need Abyssal") end
				tItemDecisions.nBigItems = nBigItems + 1
				return true
			end ----keep in mind we have to check the other options here --> no elseif
		end
		
		if not tItemDecisions.bBarbed then
			tinsert(shoppingLib.tItembuild, "Item_Excruciator")
			tItemDecisions.bBarbed = true
			if bDebugInfo then BotEcho("Need Barbed!") end
			return true
		end
	elseif sSurvivalattribute == "hp" then
		if nGPM > 350 then
			tItemDecisions.bSkipHelm = true
		end
		if not tItemDecisions.bSkipHelm and not tItemDecisions.bManaSupply and not tItemDecisions.bHelm then
			tinsert(shoppingLib.tItembuild, "Item_Shield2")
			tItemDecisions.bHelm = true
			if bDebugInfo then BotEcho("Need Helm!") end
			return true
		elseif not tItemDecisions.bStaff and not tItemDecisions.bGlowStone then
			tinsert(shoppingLib.tItembuild, "Item_Glowstone")
			tItemDecisions.bGlowStone = true
			if bDebugInfo then BotEcho("Need GlowStone!") end
			return true
		elseif not tItemDecisions.bHeart then
			tinsert(shoppingLib.tItembuild, "Item_BehemothsHeart")
			tItemDecisions.bHeart = true
			tItemDecisions.nBigItems = nBigItems +1
			if bDebugInfo then BotEcho("Need Behemoth!") end
			return true	
		end
	end
	
	if not tItemDecisions.bSkipRegen and not tItemDecisions.bRegen then
		if tItemDecisions.bHelm and not tItemDecisions.bBloodChalice then
			core.InsertToTable(shoppingLib.tItembuild, {"Item_Scarab","Item_BloodChalice"})
			tItemDecisions.bBloodChalice = true
			if bDebugInfo then BotEcho("Need BloodChalice!") end
			return true	
		elseif not tItemDecisions.bManaSupply then
			tinsert(shoppingLib.tItembuild, "Item_ManaBattery")
			tItemDecisions.bManaSupply = true
			if bDebugInfo then BotEcho("Need Mana Battery!") end
			return true			
		end
		tItemDecisions.bRegen = true
	end
	
	if not tItemDecisions.bBootsFinished then
		local tItems = {}
		--incredible farm go straight for posthaste
		if nGPM > 400 then
			tinsert(tItems, "Item_PostHaste")
			tItemDecisions.bPostHaste = true
			tItemDecisions.nBigItems = nBigItems +1
		elseif tItemDecisions.bHelm or nGPM > 250 then
			tinsert(tItems, "Item_EnhancedMarchers")
		elseif nGPM > 180 then
			tinsert(tItems, "Item_Steamboots")
		else --Stider Time!
			tinsert(tItems, "Item_Striders")
		end
		if tItemDecisions.bManaSupply then
			tinsert(tItems, "Item_PowerSupply")
		end
		core.InsertToTable(shoppingLib.tItembuild, tItems)
		tItemDecisions.bBootsFinished = true
		if bDebugInfo then BotEcho("Need better boots!") end
		return true	
	end
	
	if not tItemDecisions.bMovementEnhancer then
		--go for shroud if good farm, else pk
		local sItemName = "Item_PortalKey"
		if nGPM > 350 then
			--go for shroud
			sItemName = "Item_Stealth"
			tItemDecisions.bShroud = true
		end
		tinsert(shoppingLib.tItembuild, sItemName)
		tItemDecisions.bMovementEnhancer = true
		tItemDecisions.nBigItems = nBigItems +1
		if bDebugInfo then BotEcho("Need MovementEnhancer! PK: "..tostring(not tItemDecisions.bShroud).."Shroud: "..tostring(tItemDecisions.bShroud)) end
		return true		
	end
	
	if not  tItemDecisions.bStaff then
		tinsert(shoppingLib.tItembuild, "Item_Intelligence7")
		tItemDecisions.bStaff = true
		if bDebugInfo then BotEcho("Getting my STAFF!") end
		tItemDecisions.nBigItems = nBigItems +1
		return true	
	end
	
	if tItemDecisions.bShroud and not tItemDecisions.bGenjuro then
		tinsert(shoppingLib.tItembuild, "Item_Sasuke")
		tItemDecisions.bGenjuro = true
		if bDebugInfo then BotEcho("Genjuro I am coming.") end
		return true	
	end
	
	if tItemDecisions.bShamans and not tItemDecisions.bBarrierIdol then
		tinsert(shoppingLib.tItembuild, "Item_BarrierIdol")
		tItemDecisions.bBarrierIdol = true
		if bDebugInfo then BotEcho("Upgrading my Shamans!") end
		tItemDecisions.nBigItems = tItemDecisions.nBigItems +1
		return true	
	end
	
	
	if tItemDecisions.bSolsBulwark == nil then 
		local teamBotBrain = core.teamBotBrain
		local sSolsBulwark = "Item_SolsBulwark"
		if teamBotBrain and teamBotBrain.ReserveItem(sSolsBulwark) and teamBotBrain.ReserveItem("Item_DaemonicBreastplate") then
			tinsert(shoppingLib.tItembuild, sSolsBulwark)
			tItemDecisions.bSolsBulwark = true
			if bDebugInfo then BotEcho("Getting Sols") end
			return true
		else
			if bDebugInfo then BotEcho("Sols or Daemonic is already taken... Going for something else") end
			tItemDecisions.bSolsBulwark = false --keep in mind we have to check the other options here --> no elseif
		end
	elseif tItemDecisions.bSolsBulwark and not tItemDecisions.bDaemonic then
		tinsert(shoppingLib.tItembuild, "Item_DaemonicBreastplate")
		tItemDecisions.nBigItems = tItemDecisions.nBigItems +1
		tItemDecisions.bDaemonic = true
		if bDebugInfo then BotEcho("Getting Daemonic!") end
		return true	
	end
			
	if not tItemDecisions.bPostHaste then
		tinsert(shoppingLib.tItembuild, "Item_PostHaste")
		tItemDecisions.bPostHaste = true
		if bDebugInfo then BotEcho("Just getting Posthaste. Tired of buying Tps") end
		tItemDecisions.nBigItems = nBigItems +1
		return true		
	elseif not tItemDecisions.bFrostfield  and not tItemDecisions.bDaemonic then
		tinsert(shoppingLib.tItembuild, "Item_FrostfieldPlate")
		tItemDecisions.bFrostfield = true
		tItemDecisions.nBigItems = nBigItems +1
		if bDebugInfo then BotEcho("Getting a Frostfield") end
		return true	
	elseif not tItemDecisions.bHeart then
		tinsert(shoppingLib.tItembuild, "Item_BehemothsHeart")
		tItemDecisions.bHeart = true
		tItemDecisions.nBigItems = nBigItems +1
		if bDebugInfo then BotEcho("MY last item will be a behemoth heart") end
		return true		
	end
	   
	if debugInfo then BotEcho("I have no more items to buy") end
	return false
end
shoppingLib.CheckItemBuild = RallyItemBuild	


object.nSlamTime = 0	
function object:onthinkOverride(tGameVariables)
	self:onthinkOld(tGameVariables)
	
	--toDo Radius check if we hit ult
	local teamBotBrain = core.teamBotBrain
	if teamBotBrain then
		local nNow = HoN.GetGameTime()
		local unitHeroTarget = behaviorLib.heroTarget
		local nSlamTime = object.nSlamTime
		if unitHeroTarget and nSlamTime +1000 > nNow then
			local vecExpectedPositon = teamBotBrain.funcGetUnitPosition (unitHeroTarget, nSlamTime+1250)
			local vecMyPosition = core.unitSelf:GetPosition()
			local nSlamRadius = funcGetSlamRadius()
			if not vecExpectedPositon or Vector3.Distance2DSq(vecExpectedPositon, vecMyPosition) >
				nSlamRadius*nSlamRadius then
			object.nSlamTime = core.OrderStop(object, core.unitSelf, true) and 0
			end
		end
	end

end
object.onthinkOld = object.onthink
object.onthink 	= object.onthinkOverride

--------------------
-- Magic immunity --
--------------------
function object.isMagicImmune(unit)
	local tStates = { "State_Item3E", "State_Predator_Ability2", "State_Jereziah_Ability2", "State_Rampage_Ability1_Self", "State_Rhapsody_Ability4_Buff", "State_Hiro_Ability1" }
	for _, sState in ipairs(tStates) do
		if unit:HasState(sState) then
			return true
		end
	end
	return false
end

--####################################################################
--####################################################################
--#								 									##
--#   CHAT FUNCTIONSS					       						##
--#								 									##
--####################################################################
--####################################################################

core.tKillChatKeys = {
	"Pain is a real motivator"  }

core.tDeathChatKeys = {
	"Rally!"	}

core.tRespawnChatKeys = {
	"Gettin' outrallied." }

--enable taunt for practice mode (hehe)
Echo("g_perks 1")

BotEcho('finished loading rally_main')
