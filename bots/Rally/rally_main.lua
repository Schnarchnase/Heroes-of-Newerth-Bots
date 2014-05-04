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
				local nLevelBonus = 10 + (tEnemyInformation.nLevel or 0)
				
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


----------------------------------
--      Gravekeeper Item Build
----------------------------------
--[[ list code:
	"# Item" is "get # of these"
	"Item #" is "get this level of the item" --]]

--ItemBuild

--1.Starting items
shoppingLib.tStartingItems = {"Item_LoggersHatchet", "Item_IronBuckler", "Item_RunesOfTheBlight", "Item_ManaPotion"}

--mid
shoppingLib.tLaneItems = 
	{"Item_Marchers", "Item_Lifetube", "Item_EnhancedMarchers"}
	
--late

shoppingLib.tMidItems = 
	{"Item_Shield2","Item_MysticVestments","Item_BloodChalice","Item_PortalKey"} 
shoppingLib.tLateItems = 
	{"Item_Intelligence7", "Item_SolsBulwark", "Item_DaemonicBreastplate","Item_BehemothsHeart" } 


--[[
--Gravekeeper Shopping function
local function RallyItemBuild()
	--called everytime your bot runs out of items, should return false if you are done with shopping
	local debugInfo = false
    
	if debugInfo then BotEcho("Checking itembuilder of Gravekeeper") end
	
	--variable for new items / keep shopping
	local bNewItems = false
	  
	--get itembuild decision table 
	local tItemDecisions = shoppingLib.tItemDecisions
	if debugInfo then BotEcho("Found ItemDecisions"..type(tItemDecisions)) end
	
	--decision helper
	local nGPM = object:GetGPM()
	
	--early game (start items and lane items
	
	--If tItemDecisions["bStartingItems"] is not set yet, choose start and lane items
		if not tItemDecisions.bStartingItems then
			--insert decisions into our itembuild-table
			core.InsertToTable(shoppingLib.tItembuild, shoppingLib.tStartingItems)
			core.InsertToTable(shoppingLib.tItembuild, shoppingLib.tLaneItems)
			
					
			--we have implemented new items, so we can keep shopping
			bNewItems = true
					
			--remember our decision
			tItemDecisions.bStartingItems = true
		
	--If tItemDecisions["bItemBuildRoute"] is not set yet, choose boots and item route
		elseif not tItemDecisions.bItemBuildRoute then
			
			local sBootsChosen = nil
			local tMidItems = nil
			
			--decision helper
			local nMatchTime = HoN.GetMatchTime()
			local nXPM = core.unitSelf:GetXPM()
			
			--check  for agressive or passive route
			if nXPM < 170 and nMatchTime > core.MinToMS(5) then
				--Bad early game: go for more defensive items
				sBootsChosen = "Item_Steamboots"
				tMidItems = {"Item_MysticVestments", "Item_Scarab",  "Item_SacrificialStone", "Item_Silence"}
			else
				--go aggressive
				sBootsChosen = "Item_EnhancedMarchers"
				tMidItems = {"Item_Silence"}
			end
			
			--insert decisions into our itembuild-table: the boots
			tinsert(shoppingLib.tItembuild, sBootsChosen)
			
			--insert items into default itemlist (Mid and Late-Game items)
			tItemDecisions.tItemList = {}
			tItemDecisions.nItemListPosition = 1
			core.InsertToTable(tItemDecisions.tItemList, tMidItems)
			core.InsertToTable(tItemDecisions.tItemList, shoppingLib.tLateItems)
					
			--we have implemented new items, so we can keep shopping
			bNewItems = true
					
			--remember our decision
			tItemDecisions.bItemBuildRoute = true
			
	--need Tablet?
		elseif not tItemDecisions.bGetTablet and core.unitSelf:GetLevel() > 10 and nGPM < 240 then
			--Mid game: Bad farm, so go for a tablet
			
			--insert decisions into our itembuild-table
			tinsert(shoppingLib.tItembuild, "Item_PushStaff")
			
			--we have implemented new items, so we can keep shopping
			bNewItems = true
			
			--remember our decision
			tItemDecisions.bGetTablet = true
			
	--need Portal Key?	
		elseif not tItemDecisions.bGetPK and nGPM >= 300 then
			--Mid game: High farm, so go for pk 
			
			--insert decisions into our itembuild-table
			tinsert(shoppingLib.tItembuild, "Item_PortalKey")
			
			--we have implemented new items, so we can keep shopping
			bNewItems = true
			--remember our decision
			tItemDecisions.bGetPK = true
			
	--all other items
		else
		
			--put default items into the item build list (One after another)
			local tItemList = tItemDecisions.tItemList
			local nItemListPosition = tItemDecisions.nItemListPosition
			
			local sItemCode = tItemList[nItemListPosition]
			if sItemCode then
				--got a new item code 
				
				--insert decisions into our itembuild-table
				tinsert(shoppingLib.tItembuild, sItemCode)
				
				--next item position
				tItemDecisions.nItemListPosition = nItemListPosition + 1
				
				--we have implemented new items, so we can keep shopping
				bNewItems = true
			end
			
		end
	   
	if debugInfo then BotEcho("Reached end of itembuilder-function. Keep shopping? "..tostring(bNewItems)) end
	return bNewItems
end
shoppingLib.CheckItemBuild = RallyItemBuild	

--]]

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
		nRuneGrabRange = nRuneGrabRange + 500
	end
	
		
	local tRune = core.teamBotBrain.GetNearestRune(core.unitSelf:GetPosition(), false, true)
	if tRune == nil or Vector3.Distance2DSq(tRune.vecLocation, core.unitSelf:GetPosition()) > nRuneGrabRange * nRuneGrabRange then
		return 0
	end

	behaviorLib.tRuneToPick = tRune

	return 30
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
	
	if not HoN.CanSeePosition(vecRunePosition) or tRune.unit == nil then
		return behaviorLib.MoveExecute(botBrain, vecRunePosition)
	elseif tRune.unit and tRune.unit:IsValid() then
		return core.OrderTouch(botBrain, unitSelf, tRune.unit)
	else 
		return false
	end
end
behaviorLib.PickRuneBehavior["Execute"] = PickRuneExecuteOverride


--####################################################################
--####################################################################
--#								 									##
--#   CHAT FUNCTIONSS					       						##
--#								 									##
--####################################################################
--####################################################################

object.tCustomKillKeys = {
	"Pain is a real motivator"  }

local function GetKillKeysOverride(unitTarget)
	local tChatKeys = object.funcGetKillKeysOld(unitTarget)
	core.InsertToTable(tChatKeys, object.tCustomKillKeys)
	return tChatKeys
end
object.funcGetKillKeysOld = core.GetKillKeys
core.GetKillKeys = GetKillKeysOverride


object.tCustomRespawnKeys = {
	"Rally!"	}

local function GetRespawnKeysOverride()
	local tChatKeys = object.funcGetRespawnKeysOld()
	core.InsertToTable(tChatKeys, object.tCustomRespawnKeys)
	return tChatKeys
end
object.funcGetRespawnKeysOld = core.GetRespawnKeys
core.GetRespawnKeys = GetRespawnKeysOverride


object.tCustomDeathKeys = {
	"Gettin' outrallied." }

local function GetDeathKeysOverride(unitSource)
	local tChatKeys = object.funcGetDeathKeysOld(unitSource)
	core.InsertToTable(tChatKeys, object.tCustomDeathKeys)
	return tChatKeys
end
object.funcGetDeathKeysOld = core.GetDeathKeys
core.GetDeathKeys = GetDeathKeysOverride


BotEcho('finished loading rally_main')
