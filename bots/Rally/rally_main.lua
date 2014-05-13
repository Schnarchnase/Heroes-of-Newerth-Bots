--[[
item:GetOwnerPlayerID()
luafunctions
--Rally v0.1 by Schnarchnase

description:

credits:
DarkFire: GetAbilPosition (basis version from Wretched Hag
St0l3n_ID: Angle Between (basis version from Chronos)

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

object.bReportBehavior = false
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
local itemHandler = object.itemHandler

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
local tCompellStun = {1250,1500,1750,2000}
local tRoarDamage = {40,80,120,160}
local tBattleExpPierce = {0.15,0.30,0.45,0.60}
local tSlamDamage = {400,650,900}
local tSlamDamageBoosted = {600,850,1100}
--normal and boosted
local tSlamRadius = {250,500}
	
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

object.nCompellUse = 20
object.nRoarUse = 8
object.nSlamUse = 60

object.nCompellOffensiveThreshold = 40
object.nCompellDefensiveThreshold = 70
object.nRoarDefensiveThreshold = 60
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

object.nMeleeHarassBenousRangeSq = 200*200

behaviorLib.nCreepPushbackMul = 0.5

--Compell time for Roar-Use
object.nCompellTime = 0
--Slam time for miss-prediction
object.nSlamTime = 0	

--event damge
object.nTrueDamgaTaken = 0
object.nMagicalDamageTaken = 0
object.nPhysicalDamageTaken = 0
object.nItemuilddamageTime = 0

--Rune Grab Range without bottle
behaviorLib.nRuneGrabRange = 2000

--Minimum treshold to help allies
object.nHelpTreshold = 40

--damage per minute greater than hp-percent
object.nHPFactor = 0.2

--Bottle utility modifiers
object.tBottleStats = {
	bottle_empty = 0,
	bottle_1 = 1,
	bottle_2 = 1,
	bottle_3 = 1,
	bottle_damage = 0.8,
	bottle_illusion = 0.9,
	bottle_movespeed = 0.6,
	bottle_regen = 0.5,
	bottle_stealth = 0.55
}

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

local function funcGetCompellStun (nLevel)
	if not nLevel or nLevel > 4 or nLevel < 1 then
		return 0
	end
	return tCompellStun[nLevel]
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
	local bDebugEchos = false
	
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

--Update damage taken for itembuild
function object.UpdateDamageObservation(EventData)
	
	local sDamageType = EventData.DamageType
	local nDamageApplied = EventData.DamageApplied
	if sDamageType == "Physical" then
		--BotEcho("Getting hit by physical damage!")
		object.nPhysicalDamageTaken= object.nPhysicalDamageTaken + nDamageApplied
	elseif sDamageType == "Magic" then
		--BotEcho("Getting hit by magical damage!")
		object.nMagicalDamageTaken = object.nMagicalDamageTaken + nDamageApplied
	else
		--True Damage?
		object.nTrueDamgaTaken = object.nTrueDamgaTaken + nDamageApplied
		--BotEcho("Is this true damage?")
	end
	--BotEcho("Damage Attempted: "..tostring(EventData.DamageAttempted).." and Applied: "..tostring(nDamageApplied))
end

--Rally ability use gives bonus to harass util for a while
function object:oncombateventOverride(EventData)
	self:oncombateventOld(EventData)
	
	local nAddBonus = 0
	
	if EventData.Type == "Damage" then
		local unitSource = EventData.SourceUnit
		if unitSource and unitSource:IsHero()then
			object.UpdateDamageObservation(EventData)
			--eventsLib.printCombatEvent(EventData)
		end
	end
	
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

----------------------------------
--	Rally harass
----------------------------------
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
	local vecCurrentPos = tEnemyInformation and tEnemyInformation.vecCurrentPosition
	
	--Allies Bonus
	local tAllies = core.localUnits["AllyHeroes"]
	local nAllies = core.NumberElements(tAllies)
	local nAllyBonus = object.nAllyBonus
	nUtility = nUtility + nAllies * nAllyBonus
	
	if vecCurrentPos then
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
				if vecUnitEnemyPosition and Vector3.Distance2DSq(vecCurrentPos, vecUnitEnemyPosition) < nHeroRangeSq then
					nUtility = nUtility - nEnemyThreat
				end
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
	if not tEnemyInformation then
		object.harassExecuteOld(botBrain)
	end
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
	
	local nMoveSpeed = unitTarget:GetMoveSpeed()
	local bSlowed = nMoveSpeed and nMoveSpeed < 200
	local bTargetRooted = unitTarget:IsStunned() or unitTarget:IsImmobilized() or bSlowed
	local tLocalHeroes = core.localUnits["EnemyHeroes"]
	
	--use Compell
	if not bActionTaken and  abilCompell:CanActivate() and nLastHarassUtility >= object.nCompellOffensiveThreshold then
		--use compel to kill
		local nAutoHitDamage = unitSelf:GetFinalAttackDamageMin()
		if nTargetEHP < funcGetCompellDamage(abilCompell:GetLevel()) + 2*nAutoHitDamage and nTargetDistanceSq < 600*600 then
			bActionTaken = core.OrderAbilityEntityVector(botBrain, abilCompell, unitSelf, vecTargetLocation)
			object.nCompellTime = nNow
		else 
			local vecTargetPosition = object.GetCompellPosition (tLocalHeroes, vecMyPosition, 600, 120, 2)
			if vecTargetPosition or (nTargetDistanceSq >= 360*360  and  nTargetDistanceSq <= 550*500) then 
				bActionTaken = core.OrderAbilityEntityVector(botBrain, abilCompell, unitSelf, vecTargetPosition or vecTargetLocation)
				object.nCompellTime = nNow
			end
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
	
	--
	--
	--use Slam
	local abilSlam = skills.abilSlam
	if not bActionTaken and  abilSlam:CanActivate() and nLastHarassUtility >= object.nSlamThreshold then
		
		local nSlamRadius = funcGetSlamRadius()
		local vecTargetPosition = object.GetSlamPosition (tLocalHeroes, vecMyPosition, nSlamRadius, 120, 1, nNow+1250)
		if vecTargetPosition then
			core.DrawXPosition(vecTargetPosition)
			bActionTaken = core.OrderAbilityPosition(botBrain, abilSlam, vecTargetPosition+vecMyPosition)
			object.nSlamTime = nNow
		end
		
		--[[
		if nTargetDistanceSq < nSlamRadius*nSlamRadius then
			bActionTaken = core.OrderAbilityPosition(botBrain, abilSlam, vecEnemyPosition)
			object.nSlamTime = nNow
		end
		--]]
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


--push utility
local function PushOverride(botBrain)
	local bDebug = false
	local nUtility = object.PushOldUtility(botBrain)
	
	object.bPushHeavy = false
	
	--Push hard if the rune will spawn
	local itemBottle = core.GetItem("Item_Bottle")
	if itemBottle then
		local nNow = HoN.GetMatchTime()
	
		local nCurrentTwoMinuteCycle = floor(nNow / 1000)%120
	
		if bDebug then BotEcho("Funzt das hier? Current Stuff:"..tostring(nNow).." "..tostring(nCurrentTwoMinuteCycle)) end
	
		if nCurrentTwoMinuteCycle > 100 then
			--push hard for rune
			if bDebug then BotEcho("Pushing hard for rune spwaen! ") end
			nUtility = nUtility + 20 
			object.bPushHeavy = true
		end
	end
	
	local nMyMana = core.unitSelf:GetMana()
	if nMyMana > 400 then
		object.bPushHeavy = true
	end
	
	return nUtility
end
object.PushOldUtility = behaviorLib.PushUtility
behaviorLib.PushBehavior["Utility"] = PushOverride

-- Find the angle in degrees between two targets. Modified from St0l3n_ID's AngToTarget code
local function AngleBetween(vecSelf, vecTarget)
	local nDeltaY = vecTarget.y - vecSelf.y
	local nDeltaX = vecTarget.x - vecSelf.x
 
	return floor(core.RadToDeg(atan2(nDeltaY, nDeltaX)))
end

--Credits to DarkFire for his basis version 
function object.GetSlamPosition (tTargets, vecCenter, nRange, nDegree, nMin, nNow)
	
	if not tTargets or not nRange or not nDegree then
		return
	end
	
	if not nNow then
		nNow = HoN.GetGameTime()
	end
	
	if not nMin then
		nMin = 1
	end
	
	if core.NumberElements(tTargets) < nMin then 
		return
	end
	
	local unitSelf = core.unitSelf
	local vecMyPosition = vecCenter or unitSelf:GetPosition()
	
	--getTembot
	local teamBotBrain = core.teamBotBrain
	if not teamBotBrain then 
		return 
	end
	
	--Get all units in range
	local tUnitsInRangeVectors = {}
	local nRangesq = nRange*nRange
	for _, unit in pairs (tTargets) do
		local vecPosition = teamBotBrain.funcGetUnitPosition(unit, nNow)
		if vecPosition and Vector3.Distance2DSq(vecPosition, vecCenter) <= nRangesq then
			tinsert(tUnitsInRangeVectors, vecPosition)
		end
	end
	
	if #tUnitsInRangeVectors < nMin then
		return
	end
	
	local tAnglesOfUnits = {}
	local nLoopDegree = nDegree / 2
	for _, vecPosition in ipairs (tUnitsInRangeVectors) do
		local nMidAngle = AngleBetween(vecMyPosition, vecPosition)
		tinsert(tAnglesOfUnits, {nMidAngle+nLoopDegree, nMidAngle, nMidAngle-nLoopDegree})
	end
		
	local tBestGroup = {}
	local tCurrentGroup = {}
	
	for _,tStartAngles in ipairs (tAnglesOfUnits) do
		local nStartAngle = tStartAngles[1]
		local nEndAngle = tStartAngles[3]
		if nStartAngle <= -90 then
			nStartAngle = nStartAngle + 360
			nEndAngle = nEndAngle + 360
		end
		
		for _,tAngles in ipairs (tAnglesOfUnits) do
		
			local nHighAngle = tAngles[1]
			local nMidAngle = tAngles[2]
			local nLowAngle = tAngles[3]
			
			if nStartAngle > 90 and nStartAngle < 270  then
				-- Avoid doing calculations near the break in numbers
				if nHighAngle < 0 then
					nHighAngle = nHighAngle + 360
				end
				   
				if nMidAngle < 0 then
					nMidAngle = nMidAngle + 360
				end
				   
				if nLowAngle < 0 then
					nLowAngle = nLowAngle + 360
				end
			end
			
			if (nStartAngle <= nMidAngle and nMidAngle <= nEndAngle) 
				or (nHighAngle >= nStartAngle and nLowAngle <= nStartAngle) 
				or (nHighAngle >= nEndAngle and nLowAngle <= nEndAngle) then
				
				tinsert(tCurrentGroup, nMidAngle)
			end
		end
	
		if #tCurrentGroup > #tBestGroup then
			tBestGroup = tCurrentGroup
		end
		
		tCurrentGroup = {}
	end
	
	local nBestGroupSize = #tBestGroup
	
	if  nBestGroupSize >= nMin then
		tsort(tBestGroup)
			 
		local nAvgAngle = core.DegToRad((tBestGroup[1] + tBestGroup[nBestGroupSize]) / 2)
		return Vector3.Create(cos(nAvgAngle), sin(nAvgAngle)) * nRange
	end	
end

function object.GetCompellPosition (tTargets, vecCenter, nRange, nWidth, nMin, nNow)
	
	if not tTargets or not nRange or not nWidth then
		return
	end
	
	if not nNow then
		nNow = HoN.GetGameTime()
	end
	
	if not nMin then
		nMin = 1
	end
	
	if core.NumberElements(tTargets) < nMin then 
		return
	end
	
	local unitSelf = core.unitSelf
	local vecMyPosition = vecCenter or unitSelf:GetPosition()
	
	--getTembot
	local teamBotBrain = core.teamBotBrain
	if not teamBotBrain then 
		return 
	end
	
	--Get all units in range
	local tUnitsInRangeVectors = {}
	local nRangeSq = nRange*nRange
	for _, unit in pairs (tTargets) do
		local vecPosition = teamBotBrain.funcGetUnitPosition(unit, nNow) or unit:GetPosition()
		if vecPosition and Vector3.Distance2DSq(vecPosition, vecCenter) <= nRangeSq then
			tinsert(tUnitsInRangeVectors, vecPosition)
		end
	end
	
	if #tUnitsInRangeVectors < nMin then
		return
	end
	
	local tVectorsOfUnits = {}
	--do sth
	for _, vecPosition in ipairs (tUnitsInRangeVectors) do
		local vecToTarget = vecPosition - vecMyPosition
		local vecDirection = vecMyPosition+Vector3.Normalize(vecToTarget) * nRange / 2
		tinsert(tVectorsOfUnits, {vecPosition, vecDirection, vecToTarget})
	end
	
			
	--------------
		
	local tBestGroup = {nNumber=0}
	
	local nRangeMid = (nRange + nWidth) / 2
	local nRangeSqBig = nRangeMid * nRangeMid
	local nRangesqSmall = nWidth * nWidth
	
	for _,tVectors in ipairs (tVectorsOfUnits) do
		local vecMid = tVectors[2]
		local vecToUnit = tVectors[3]
		local nCurrentNumber = 0
		for _,tOtherVectors in ipairs (tVectorsOfUnits) do
			local vecTarget = tOtherVectors[1]
			local vecLength = tOtherVectors[3] - Vector3.Project(vecToUnit, tOtherVectors[3])
			local nDistanceSq = vecLength.x*vecLength.x + vecLength.y*vecLength.y
			
			local nDistanceFromMidSq = Vector3.Distance2DSq(vecTarget, vecMid)
			if nDistanceFromMidSq <= nRangeSqBig and nDistanceSq <= nRangesqSmall then
				nCurrentNumber = nCurrentNumber + 1
			end
		end
	
		if nCurrentNumber > tBestGroup.nNumber then
			tBestGroup.nNumber = nCurrentNumber
			tBestGroup.vecDirection = vecToUnit
		end
	end
		
	if  tBestGroup.nNumber >= nMin then
		return tBestGroup.vecDirection
	end	
end

--PushExec
local function PushExecuteOverride(botBrain) 
	local bActionTaken = false
	
	if object.bPushHeavy then
		local unitSelf = core.unitSelf
		local nMyMana = unitSelf:GetMana()
		
		local tLocalHeroes = core.localUnits["EnemyHeroes"]
		local tLocalEnemyCreeps = core.localUnits["EnemyCreeps"]
		core.InsertToTable(tLocalEnemyCreeps, tLocalHeroes)
		local vecMyPosition = unitSelf:GetPosition()
		
		
		--Stun
		local abilCompell = skills.abilCompell
		--not working
		if abilCompell:CanActivate() and nMyMana > 260 then
			
			local vecPosition = object.GetCompellPosition (tLocalEnemyCreeps,vecMyPosition, 600, 120, 3)
			if vecPosition then
				bActionTaken = core.OrderAbilityEntityVector(botBrain, abilCompell, unitSelf, vecPosition)
			end
		end
		
		--Roar
		local abilRoar = skills.abilRoar
		if not bActionTaken and abilRoar:CanActivate() and nMyMana > 200 
			and core.NumberElements(tLocalEnemyCreeps) > 4 then
			local vecCenter = core.GetGroupCenter(tLocalEnemyCreeps)
			if vecCenter and Vector3.Distance2DSq(vecMyPosition, vecCenter) < 80*80 then
				bActionTaken = core.OrderAbility(botBrain, abilRoar)
			else
				bActionTaken = vecCenter and core.OrderMoveToPos(botBrain, unitSelf, vecCenter)
			end
		end
		
		--Frostfield
		local itemFrostfieldPlate = itemHandler:GetItem("Item_FrostfieldPlate")
		if not bActionTaken and itemFrostfieldPlate and abilRoar:CanActivate() and nMyMana > 240 
			and core.NumberElements(tLocalEnemyCreeps) > 4 then
			local vecCenter = core.GetGroupCenter(tLocalEnemyCreeps)
			if vecCenter and Vector3.Distance2DSq(vecMyPosition, vecCenter) < 80*80 then
				bActionTaken = core.OrderItemClamp(botBrain, unitSelf, itemFrostfieldPlate)
			else
				bActionTaken = vecCenter and core.OrderMoveToPos(botBrain, unitSelf, vecCenter)
			end
		end
	end
	
	if not bActionTaken then
		return object.PushOldExecute(botBrain)
	end	
end
object.PushOldExecute = behaviorLib.PushExecute
behaviorLib.PushBehavior["Execute"] = PushExecuteOverride

--Retreat exec
local function RetreatFromThreatExecuteOverride(botBrain)
	
	local unitSelf = core.unitSelf
	local bActionTaken = false
	
	if unitSelf:IsStealth() then
		local vecPos = behaviorLib.PositionSelfBackUp()
		bActionTaken = vecPos and core.OrderMoveToPosAndHoldClamp(botBrain, unitSelf, vecPos, false)
	end
	
	--Portal Key: Port away
	bActionTaken = not bActionTaken and core.OrderBlinkItemToEscape(botBrain, unitSelf, itemHandler:GetItem("Item_PortalKey"))
		
	local vecMyPosition = unitSelf:GetPosition()
	
	--Compell home
	local abilCompell = skills.abilCompell
	if not bActionTaken and abilCompell:CanActivate() and object.nCompellDefensiveThreshold < life.lastRetreatUtil then
		local vecBackUp= behaviorLib.PositionSelfBackUp()
		local vecPos = behaviorLib.GetSafeBlinkPosition(vecBackUp, 600) - vecMyPosition
		bActionTaken = core.OrderAbilityEntityVector(botBrain, abilCompell, unitSelf, vecPos)
	end	
		
	if bActionTaken then 
		return bActionTaken
	end
		
	local unitTarget = behaviorLib.heroTarget
	local teamBotBrain = core.teamBotBrain
	if unitTarget == nil or not unitTarget:IsValid() or not teamBotBrain then
		return false 
	end
	
	local nID = unitTarget:GetUniqueID()
	local tEnemyInformation = teamBotBrain.tEnemyInformationTable[nID]
	if not tEnemyInformation then
		return false
	end
	local vecEnemyPosition = tEnemyInformation.vecCurrentPosition 
	local nTargetDistanceSq = Vector3.Distance2DSq(vecEnemyPosition, vecMyPosition)
	
	--Slow down speedy
	local abilRoar = skills.abilRoar
	if abilRoar:CanActivate() and object.nRoarDefensiveThreshold < life.lastRetreatUtil then
		local nRange = 500
		if nTargetDistanceSq < nRange*nRange then
			return core.OrderAbility(botBrain, abilRoar)
		end
	end
	
	return false
end
behaviorLib.CustomRetreatExecute = RetreatFromThreatExecuteOverride


------------------------------------------------------------------
--Heal at well execute
------------------------------------------------------------------
local function ReturnToHealAtWell(botBrain)
	local unitSelf = core.unitSelf
	
	local bActionTaken = false
	if unitSelf:IsStealth() then
		local vecPos = behaviorLib.PositionSelfBackUp()
		bActionTaken = vecPos and core.OrderMoveToPosAndHoldClamp(botBrain, unitSelf, vecPos, false)
	end
	
	--Portal Key: Port away
	bActionTaken = not bActionTaken and core.OrderBlinkItemToEscape(botBrain, unitSelf, core.GetItem("Item_PortalKey"))
	
	--Compell home
	local abilCompell = skills.abilCompell
	if not bActionTaken and abilCompell:CanActivate() then
		local vecTarget = behaviorLib.GetSafeBlinkPosition(core.allyWell:GetPosition(), 600)
		local vecMyPosition = unitSelf:GetPosition()
		local vecPos = vecTarget - vecMyPosition
		bActionTaken = core.OrderAbilityEntityVector(botBrain, abilCompell, unitSelf, vecPos)
	end	
	
	return bActionTaken
end
behaviorLib.CustomReturnToWellExecute = ReturnToHealAtWell

local function HealAtWellExecute(botBrain)
	local unitSelf = core.unitSelf
	local itemBottle = itemHandler:GetItem("Item_Bottle")
	if itemBottle and not unitSelf:IsStealth() and not unitSelf:HasState("State_Bottle") and itemBottle:GetActiveModifierKey() ~= "bottle_empty" then
		return core.OrderItemClamp(botBrain, core.unitSelf, itemBottle)
	end
	
	return false
end
behaviorLib.CustomHealAtWellExecute = HealAtWellExecute

--runeing
local function PickRuneUtilityOverride(botBrain)
	
	local nUtility = 0
	
	--certain runes
	local vecMyPosition = core.unitSelf:GetPosition()
	local tRune = core.teamBotBrain.GetNearestRune(vecMyPosition, true, true)
	
	--uncertain ones
	if not tRune then
		nUtility = -5
		tRune = core.teamBotBrain.GetNearestRune(vecMyPosition, false, true)
	end
	
	--no rune?
	if not tRune then
		return nUtility
	end
		
	--decision making
	if not object.bPickRune then
		--bottle
		local itemBottle = itemHandler:GetItem("Item_Bottle")
		
		--near rune?
		local nRuneGrabRange = behaviorLib.nRuneGrabRange
		if core.nDifficulty ~= core.nEASY_DIFFICULTY and Vector3.Distance2DSq(tRune.vecLocation, core.unitSelf:GetPosition()) <= nRuneGrabRange * nRuneGrabRange then
			nUtility = nUtility + 25
		elseif itemBottle then
			--BotEcho("Yeah I have a bottle!")
			sBottleContent = itemBottle:GetActiveModifierKey()
			if sBottleContent == "bottle_empty" then
				nUtility = nUtility + 15
			elseif sBottleContent == "bottle_1" or sBottleContent == "bottle_2" then
				nUtility = nUtility + 5
			else--bottle full or with power-up!
				if nUtility < 0 then
					--BotEcho("Bottle full")
					return 0 --we don't know if the rune is a good one, so don't bother
				elseif not tRune.bBetter then
					--BotEcho("No certain ruen and is full")
					return 0 --we know it is a shitty one, don't bother
				end
			end
		
			--check lane status (can we go to rune?)
			local teamBotBrain = core.teamBotBrain
			local tLane = core.tMyLane
			if teamBotBrain and tLane then
				local sLanename = tLane.sLaneName
				local vecCreepLocation = teamBotBrain:GetFrontOfCreepWavePosition(sLanename)
				local nCreepY = vecCreepLocation.y
				--BotEcho("nCreepY is "..tostring(nCreepY).." and Lanename: "..sLanename)
				local nMyTeam = core.unitSelf:GetTeam()
				if nMyTeam == 1 then --Legion
					if (sLanename == "top" and nCreepY > 11500) or 
						(sLanename == "bottom" and nCreepY > 3000) or
						(sLanename == "middle" and nCreepY > 7500) then
						--we can leave the lane, becuase it is pushed
						--BotEcho("Legion!!!")
						nUtility = nUtility + 20
					end
				else --Hellbourne
					if (sLanename == "top" and nCreepY < 12500) or
						(sLanename == "bottom" and nCreepY < 4600) or
						(sLanename == "middle" and nCreepY < 7250) then
						--we can leave the lane, becuase it is pushed
						--BotEcho("Hellbourne!!!")
						nUtility = nUtility + 20
					end				
				end
			end
		end
		
		--are we in lane and is it a good moment to leave it for rune? (mid or bottle)
	else
		--go get it / abort
		nUtility = behaviorLib.nLastRuneUtility
	end

	behaviorLib.tRuneToPick = tRune
	behaviorLib.nLastRuneUtility = nUtility
	
	return nUtility
end
behaviorLib.PickRuneBehavior["Utility"] = PickRuneUtilityOverride

local function PickRuneExecuteOverride(botBrain)
	tRune = behaviorLib.tRuneToPick
	if tRune == nil or tRune.vecLocation == nil or tRune.bPicked then
		object.bPickRune = false
		return false
	end
		
	local vecRunePosition = tRune.vecLocation
	local unitSelf = core.unitSelf
	--local nDistanceSQ = Vector3.Distance2DSq(vecRunePosition, unitSelf:GetPosition())
	
	if not HoN.CanSeePosition(vecRunePosition) or not tRune.unit then
		object.bPickRune = true
		return behaviorLib.MoveExecute(botBrain, vecRunePosition)
	elseif tRune.unit and tRune.unit:IsValid() then
		return core.OrderTouch(botBrain, unitSelf, tRune.unit)
	else 
		object.bPickRune = false
		return false
	end
end
behaviorLib.PickRuneBehavior["Execute"] = PickRuneExecuteOverride

local function funcBottlePowerModifier (sSatus)
		return object.tBottleStats[sSatus]
end

local function BottleUtility(botBrain)
	local bDebug = false
	
	--ToDo: Don't drink, when dotted
	--ToDo: Drink in Critical moments
	
	local unitSelf = core.unitSelf
	local nUniqueID = unitSelf:GetUniqueID()
	local vecMyPosition = unitSelf:GetPosition()
	local nMinDistanceSq = 300*300
	
	local bCanDrink=true
	
	local tProjectiles = eventsLib.incomingProjectiles["all"]
	for _,tEventDate in pairs (tProjectiles) do
		if bDebug then BotEcho("Incoming Projectiles! Do not drink") end
		bCanDrink = false
		break
	end
	
	local tEnemies = core.localUnits["EnemyUnits"]
	for _,unitEnemy in pairs (tEnemies) do
		local unitEnemyTarget = unitEnemy:GetAttackTarget()
		if unitEnemyTarget and unitEnemyTarget:GetUniqueID() == nUniqueID and 
			(Vector3.Distance2DSq(vecMyPosition, unitEnemy:GetPosition()) < nMinDistanceSq or
			unitEnemy:IsTower()) then
			if bDebug then BotEcho("Enemies attacking me! Do not drink") end
			bCanDrink = false
			break
		end
	end
	
	local nUtility = behaviorLib.UseBottleUtility(botBrain)
	if nUtility > 0 then
		local itemBottle = behaviorLib.itemBottle
		sItemBottleState = itemBottle and itemBottle:GetActiveModifierKey()
		if sItemBottleState then
			nUtility = nUtility * funcBottlePowerModifier(sItemBottleState) 
		end
	end
	
	behaviorLib.bCanDrink = bCanDrink
	
	return nUtility
end
behaviorLib.tItemBehaviors["Item_Bottle"]["Utility"] = BottleUtility

local function BottleExecute(botBrain)
	
	if not behaviorLib.bCanDrink then
		return behaviorLib.RetreatFromThreatBehavior["Execute"]
	end
	
	local unitSelf = core.unitSelf
	local itemBottle = itemHandler:GetItem("Item_Bottle")
	if itemBottle and not unitSelf:HasState("State_Bottle") and 
		not unitSelf:HasState("State_PowerupRegen") and
		itemBottle:GetActiveModifierKey() ~= "bottle_empty" then
		return core.OrderItemClamp(botBrain, unitSelf, itemBottle)
	end
	
	return false
end
behaviorLib.tItemBehaviors["Item_Bottle"]["Execute"] = BottleExecute

--saving allies
function object.SavingAlliesUtility(botBrain)
	local nUtility = 0 
	
	--do not save illusions, so save the teamheroes at the beginning of the match
	if not object.tSaveAllies then
		local tMyTeam = HoN.GetHeroes(core.myTeam)
		if tMyTeam then
			object.tSaveAllies = {}
			for _, unitAlly in pairs (tMyTeam) do
				local nAllyID = unitAlly:GetUniqueID()
				--skip ourself
				if nAllyID ~= core.unitSelf:GetUniqueID() then
					object.tSaveAllies[nAllyID] = true
				end
			end
		else
			return nUtility
		end
	end
	
	if not skills.abilCompell:CanActivate() then 
		return nUtility
	end
	
	local tAlliesNear = core.localUnits["AllyHeroes"]
	local nAlliesNear = core.NumberElements(tAlliesNear)
	local tSaveAllies = object.tSaveAllies
	
	if nAlliesNear > 0 then
		local funcTimeToLive = life.funcTimeToLiveUtility
		for _, unitAlly in pairs(tAlliesNear) do
			if tSaveAllies[unitAlly:GetUniqueID()] then
				--Isn't there a Restrained bool?or unitAlly:IsRestrained()
				local bAllyIsInvalid = unitAlly:IsImmobilized()  or core.isMagicImmune(unitAlly)
				local nUtilityAlly = not bAllyIsInvalid and funcTimeToLive(unitAlly)
				if nUtilityAlly and nUtilityAlly > nUtility then
					nUtility = nUtilityAlly
					object.unitToSave = unitAlly
				end
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
	local bAllyIsInvalid = unitToSave:IsImmobilized()  or core.isMagicImmune(unitToSave)
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
BotEcho("Wait for Lane decision? .."..tostring(shoppingLib.bWaitForLaneDecision))

local function funcCheckSurvivalItem (tItemDecisions) 
	local bDebug = true

	local nTrueDamgaTaken = object.nTrueDamgaTaken
	local nMagicalDamageTaken = object.nMagicalDamageTaken
	local nPhysicalDamageTaken = object.nPhysicalDamageTaken
	
	local nSum = nTrueDamgaTaken + nMagicalDamageTaken + nPhysicalDamageTaken
	local nMagicPercent = nMagicalDamageTaken / nSum
	local nPhysicalPercent = nPhysicalDamageTaken / nSum
	
	local nNow = HoN.GetMatchTime()
	local nItemuilddamageTime = object.nItemuilddamageTime
	object.nTrueDamgaTaken = 0
	object.nMagicalDamageTaken = 0
	object.nPhysicalDamageTaken = 0
	
	local unitSelf = core.unitSelf
	local nMaxHP = unitSelf:GetMaxHealth()
	
	if nNow and nNow > nItemuilddamageTime then
		local nTimeSpan = (nNow - nItemuilddamageTime)/60000 --damage per minute
		object.nItemuilddamageTime = nNow
		if bDebug then BotEcho("Damage sum: "..tostring(nSum).." Result: "..tostring(nSum / nTimeSpan)) end
		if nMagicPercent > 0.65 and nMaxHP >= 1000 then
			if bDebug then BotEcho("Magic Percent :"..tostring(nMagicPercent)) end
			return "magic"
		elseif nPhysicalPercent > 0.65 and tItemDecisions.bBootsFinished then
			if bDebug then BotEcho("Physical Percent :"..tostring(nPhysicalPercent)) end
			return "physical"
		elseif nSum / nTimeSpan > nMaxHP * object.nHPFactor then
			if bDebug then BotEcho("Damage sum: "..tostring(nSum).." Result: "..tostring(nSum / nTimeSpan)) end
			return "hp"
		else
			if bDebug then BotEcho("Nothing to worry about") end
			return "none"
		end
	end
	
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
		elseif not tItemDecisions.bPlateMail and not tItemDecisions.bFrostfield then
			tinsert(shoppingLib.tItembuild, "Item_Platemail")
			tItemDecisions.bPlateMail = true
			if bDebugInfo then BotEcho("Need Platemail!!") end
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
		elseif tItemDecisions.bHelm or nGPM > 220 then
			tinsert(tItems, "Item_EnhancedMarchers")
		elseif nGPM > 150 then
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
	
	if not tItemDecisions.bGlowStone then
			tinsert(shoppingLib.tItembuild, "Item_Glowstone")
			tItemDecisions.bGlowStone = true
			if bDebugInfo then BotEcho("Need GlowStone!") end
			return true
	elseif not  tItemDecisions.bStaff then
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
	elseif not tItemDecisions.bFrostfield  and (not tItemDecisions.bDaemonic or tItemDecisions.bPlateMail) then
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


---------------------------------------------------------
---------------------------------------------------------
-- Hunting!!
---------------------------------------------------------
---------------------------------------------------------


--hunting/grouphunting util
function object.funcCheckRequirementsToGank()
	local unitSelf = core.unitSelf
	local nHPPercent = unitSelf:GetHealthPercent()
	local nMana =  unitSelf:GetMana()
	

	if nHPPercent < 0.4 or nMana < 130 then
		return 0
	end
	
	local nGankRange = 0
	
	local abilCompell = skills.abilCompell
	local abilRoar = skills.abilRoar
	local abilSlam = skills.abilSlam
	
	local nCompellManaCost = abilCompell:GetManaCost()
	if abilCompell:CanActivate() and nMana >= nCompellManaCost then
		nGankRange = nGankRange + 600
		nMana = nMana - nCompellManaCost
	end
	
	local itemRange = core.GetItem("Item_PortalKey") or core.GetItem("Item_Stealth") or core.GetItem("Item_Sasuke")
	local nItemRangeManaCost = itemRange and itemRange:GetManaCost() 
	if itemRange and itemRange:CanActivate() and nMana >= nItemRangeManaCost then
		nGankRange = nGankRange + 1500
		nMana = nMana - nItemRangeManaCost
	end
	
	local nSlamManaCost = abilSlam:GetManaCost()
	if abilSlam:CanActivate() and nMana >= nSlamManaCost then
		nGankRange = nGankRange + 2000
		nMana = nMana - nSlamManaCost
	end
	
	local nRoarManaCost = abilRoar:GetManaCost()
	if abilRoar:CanActivate() and nMana >= nRoarManaCost then
		nGankRange = nGankRange + 400
	end
	
	if nHPPercent > 0.9 then
		nGankRange  = nGankRange + 1000
	end
	
	return nGankRange
end

function object.GetGankingPower(unitEnemy, tEnemyInformation)
	
	for sID,data in pairs (tEnemyInformation) do
		BotEcho(sID..": "..tostring(data))
	end
	local unitSelf = core.unitSelf
	
	local vecEnemyPosition = tEnemyInformation.vecCurrentPosition
	local vecMyPosition = unitSelf:GetPosition()
	
	local vecDistance = vecEnemyPosition - vecMyPosition
	
	--Get Length of vector
	local nDistanceY = vecDistance.y
	local nDistance = nDistanceY / sin(atan2(nDistanceY, vecDistance.x))
	
	--Basic Arrival Time
	local nArrivalTime = nDistance / unitSelf:GetMoveSpeed() * 1000
	local nBurst = 0
	local nDPS = 0
	local nLockDown = 0
	
	local abilCompell = skills.abilCompell
	local abilRoar = skills.abilRoar
	local abilSlam = skills.abilSlam
	
	local nMana = unitSelf:GetMana()
	
	local nCompellManaCost = abilCompell:GetManaCost()
	if abilCompell:CanActivate() and nMana >= nCompellManaCost then
		local nLevel = abilCompell:GetLevel()
		nLockDown = funcGetCompellStun(nLevel)
		nBurst = funcGetCompellDamage(nLevel)
		nMana = nMana - nCompellManaCost
	end
		
	local nSlamManaCost = abilSlam:GetManaCost()
	if abilSlam:CanActivate() and nMana >= nSlamManaCost then
		nBurst = nBurst + funcGetCompellDamage(abilSlam:GetLevel())
		nLockDown = nLockDown > 0 and nLockDown - 750 or 0
		nMana = nMana - nSlamManaCost
	end
	
	local nRoarManaCost = abilRoar:GetManaCost()
	if abilRoar:CanActivate() and nMana >= nRoarManaCost then
		nBurst = nBurst + funcGetRoarDamage(abilRoar:GetLevel())
		nLockDown = nLockDown + 500 
	end
	
	local nDamage = core.GetFinalAttackDamageAverage(unitSelf)
	local nAttacksPerSecond = core.GetAttacksPerSecond(unitSelf)
	local nDPS = nDamage * nAttacksPerSecond
	
	local nTargetArmor = tEnemyInformation.nPArmor * (1-funcGetBattleExpPierce(skills.abilBattleExp:GetLevel()))
	if nTargetArmor > 0 then
		local nModifier = 100 / (100+nTargetArmor*6)
		nBurst = nBurst * nModifier
		nDPS = nDPS * nModifier
	end
	
	--burst, dps, lockdown, TimeToArrive
	return {nBurst, nDPS, nLockDown, nArrivalTime}
end

--hunting exec
function object.HuntingUtility(botBrain)
	local teamBotBrain = core.teamBotBrain
	local funcHuntingUtility = teamBotBrain and teamBotBrain.HuntingUtility
	return funcHuntingUtility and funcHuntingUtility(botBrain) or 0
end
 
function object.HuntingExe(botBrain)
	local sStatus = core.teamBotBrain.GetHuntingStatus(botBrain)
	
	BotEcho("tHunting")
	if sStatus == "move" then
		return behaviorLib.MoveExecute(botBrain, object.vecHuntingArea)
	elseif sStatus == "Hunt" then
		behaviorLib.heroTarget = object.unitHuntingTarget
		behaviorLib.lastHarassUtil = 70
		return HarassHeroExecuteOverride(botBrain)
	end
	return false
end
 
behaviorLib.Hunting = {}
behaviorLib.Hunting["Utility"] = object.HuntingUtility
behaviorLib.Hunting["Execute"] = object.HuntingExe
behaviorLib.Hunting["Name"] = "Hunting"
tinsert(behaviorLib.tBehaviors, behaviorLib.Hunting) 



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
			local nRangeSq = vecExpectedPositon and Vector3.Distance2DSq(vecExpectedPositon, vecMyPosition)
			if not unitHeroTarget:IsAlive() or not nRangeSq or nRangeSq  > nSlamRadius*nSlamRadius or nRangeSq < 900 then
				object.nSlamTime = core.OrderStop(object, core.unitSelf, true) and 0
			end
			core.DrawXPosition(vecExpectedPositon)
		end
	end
	
end
object.onthinkOld = object.onthink
object.onthink 	= object.onthinkOverride


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

SetBotDifficulty(3)

BotEcho('finished loading rally_main')
