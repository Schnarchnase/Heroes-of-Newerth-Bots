local _G = getfenv(0)
local object = _G.object

local print, ipairs, pairs, string, table, next, type, tinsert, tremove, tsort, format, tostring, tonumber, strfind, strsub
	= _G.print, _G.ipairs, _G.pairs, _G.string, _G.table, _G.next, _G.type, _G.table.insert, _G.table.remove, _G.table.sort, _G.string.format, _G.tostring, _G.tonumber, _G.string.find, _G.string.sub
local ceil, floor, pi, tan, atan, atan2, abs, cos, sin, acos, max, random
	= _G.math.ceil, _G.math.floor, _G.math.pi, _G.math.tan, _G.math.atan, _G.math.atan2, _G.math.abs, _G.math.cos, _G.math.sin, _G.math.acos, _G.math.max, _G.math.random

object.life = object.life or {}
local life, core, behaviorLib, eventsLib = object.life, object.core, object.behaviorLib, object.eventsLib
local BotEcho = core.BotEcho
local Clamp = core.Clamp

---------------------------------------------------
---------------------------------------------------
-- Life functions
---------------------------------------------------
---------------------------------------------------

-----------------------------------------------------------
--threat stuff
-----------------------------------------------------------

--Base Threat (altered by level difference and distance
life.nEnemyBaseThreat = 6

--level parameters
life.nMinLevelDifference = 0	-- level advantage over enemy hero
life.nMaxLevelDifference = 4	-- level disadvantage

--Threat Multiplier Parameters
life.nThreatValueX1 = 500		--min Range Value (no increase below)
life.nThreatValueY1 = 2		--max Threat-Factor
life.nThreatValueX2 = 2000 	--max Range Value (zero threat afterwards)
life.nThreatValueY2 = 0.75	--min Threat-Factor
		
local function CreateThreatMultiplier()
	
	local nX1 = life.nThreatValueX1
	local nY1 = life.nThreatValueY1
	local nX2 = life.nThreatValueX2
	local nY2 = life.nThreatValueY2
	
	life.nMultiplier = (nY2-nY1) / (nX2 - nX1)
	life.nAdder = nY1 - life.nMultiplier * nX1
end
CreateThreatMultiplier()

--get threat of enemy
function life.funcGetThreatOfEnemy (unitEnemy, unitMyself)
	local bDebugEchoes = false
	
	if not unitEnemy or not unitEnemy:IsAlive() then 
		return 0 
	end
	
	local teamBotBrain = core.teamBotBrain
	local vecEnemyPosition = teamBotBrain and teamBotBrain.funcGetUnitPosition (unitEnemy)
	
	if not vecEnemyPosition then 
		return 0 
	end
	
	local unitSelf = unitMyself or core.unitSelf
	local vecDistance = vecEnemyPosition - unitSelf:GetPosition()
	
	--Get Length of vector
	local nDistanceY = vecDistance.y
	local nDistanceX = vecDistance.x
	local nDistance = nDistanceY / sin(atan2(nDistanceY, nDistanceX)) 
	
	--BotEcho("Vectorlänge: "..tostring(nDistance).." vec "..tostring(vecDistance))
	
	--distance greater than max-range?
	if nDistance > life.nThreatValueX2 then 
		return 0 
	end
	
	local nMyLevel = unitSelf:GetLevel()
	local nEnemyLevel = unitEnemy:GetLevel()
	
	--Level differences increase / decrease actual nThreat
	local nThreat = life.nEnemyBaseThreat + Clamp(nEnemyLevel - nMyLevel, life.nMinLevelDifference , life.nMaxLevelDifference)
	
	--distance lower than min range?
	if nDistance <= life.nThreatValueX1 then 
		return nThreat * life.nThreatValueY1 
	end
	
	local nMultiplier = nDistance * life.nMultiplier + life.nAdder
	
	if bDebugEchoes then BotEcho("Found Distance. Enemy: "..tostring(unitEnemy:GetTypeName()).." Distance: "..tostring(nDistance).." Threat: "..tostring(nThreat).." Multiplier "..tostring(nMultiplier).." Result Threat: "..tostring(nThreat*nMultiplier)) end
	
	return nThreat * nMultiplier
end

---------------------------------------
--Time to Live stuff
---------------------------------------

life.nTime2LiveTimeSpan = 2000
life.nTime2LiveNumberOfSlots = math.ceil((life.nTime2LiveTimeSpan + behaviorLib.nBehaviorAssessInterval) / behaviorLib.nBehaviorAssessInterval)
life.nTime2LivePointOfInterest = 3 -- (number-1)*250 = point of interest --> 5=1s
life.nPointOfInterestTimeSpan = life.nTime2LiveTimeSpan * life.nTime2LivePointOfInterest / life.nTime2LiveNumberOfSlots

--Create a new instance for Health observation
function life.CreateNewHealthObservation(nLife)
	
	local tLife = {}
	
	local nNumberOfSlots = life.nTime2LiveNumberOfSlots
	for i = 1, nNumberOfSlots, 1 do
		tinsert(tLife, nLife)
	end
	
	return tLife
end

--Update  table of HealthObservation
function life.UpdateHealthObservation(tLife, nNewLifeValue)
	tremove(tLife)
	tinsert(tLife,1,nNewLifeValue)
end

life.nTimeToLiveAlarmTreshold = 0.8
life.nTimeToLiveRelaxTreshold = 0.20
--Returns the time the unit will probably die
function life.GetLifeTimeTendency(tLife)	  
	local nLastSlot = life.nTime2LiveNumberOfSlots
	local nPointOfInterest = life.nTime2LivePointOfInterest
	
	local nCurrentHealth = tLife[1]
	local nHPLostInTimeSpan = tLife[nLastSlot] - nCurrentHealth
	local nHPInteretingHPLost = tLife[nPointOfInterest] - nCurrentHealth
	
	if nHPLostInTimeSpan < 0 then 
		nHPLostInTimeSpan = 0 
	end
	
	if nHPInteretingHPLost < 0  then 
		nHPInteretingHPLost = 0 
	end
	
	local nTimeSpan = life.nTime2LiveTimeSpan
	local nPointOfInterestTimeSpan = life.nPointOfInterestTimeSpan
	
	local nTendenz = nHPInteretingHPLost * nTimeSpan / nPointOfInterestTimeSpan
	if nTendenz *  life.nTimeToLiveAlarmTreshold > nHPLostInTimeSpan then
		--We getting heavy damage all of a sudden
		nTendenz = (nTendenz + nHPLostInTimeSpan) / 2
	elseif nTendenz < nHPLostInTimeSpan * life.nTimeToLiveRelaxTreshold then
		--We getting less and less damage
		nTendenz = (2*nHPLostInTimeSpan + nTendenz) / 3
	else
		nTendenz = nHPLostInTimeSpan 
	end
	  
	if nTendenz > 0 then 
		return nTimeSpan / 1000 * nCurrentHealth / nTendenz
	end
end

------------------------------------------------------------------
--Returns the saved TimeToLive value
------------------------------------------------------------------
life.tHealthMemory = {}
local function funcTimeToLive (unit)

	if unit == nil  then return end 
	
	local nUnitHP = unit:GetHealth()
	
	local nUnitID = unit:GetUniqueID()
	
	--BotEcho(unitEnemy:GetTypeName())
	local tHealthMemory = life.tHealthMemory
	
	--delete entry if invalid
	if not nUnitHP or not unit:IsAlive() then
		tHealthMemory[nUnitID] = nil
		return
	elseif not tHealthMemory[nUnitID] then
		tHealthMemory[nUnitID] = {life.CreateNewHealthObservation(nUnitHP),unit}
	end
	
	
	return life.GetLifeTimeTendency(tHealthMemory[nUnitID][1])
end

--Return a threatening value and the TimeToLive-value
function life.funcTimeToLiveUtility(unitHero)
	--Increases as your time to live based on your damage velocity decreases
	
	local nTimeToLive = funcTimeToLive(unitHero)
	if not nTimeToLive then 
		return 0
	end
	
	local nYIntercept = 75
	local nXIntercept = 60
	local nOrder = 2
	
	local nUtility = core.ExpDecay(nTimeToLive, nYIntercept, nXIntercept, nOrder)
	
	nUtility = Clamp(nUtility, 0, 75)
	
	--BotEcho(format("%d timeToLive: %g  utility: %g", HoN.GetGameTime(), nTimeToLive, nUtility))

	return nUtility, nTimeToLive
end

------------------------------------------
--dangerous state
----------------------------------------
function life.funcUnitDangerousStatesApplied(unitThis)
	
	if not unitThis then return end
	
	local tResult = {}
	--[[
	--todo dangerous states: Cursed Ground, Salforis R, Slither R
	if unitThis:HasState("statname") then
		tinsert(tResult, "statename")
	end
	--]]
	return tResult
end

---------------------------------------------------
---------------------------------------------------
-- Retreat
---------------------------------------------------
---------------------------------------------------

life.nTowerAggroUtility = 15
life.CreepThreatMultiplicator = 4
life.nDangerousStatesMalus = 15
local function CustomRetreatFromThreatUtilityFnOverride(botBrain)
	local bDebugEchos = false
	local bCompareOldToNew = false
	
	local unitSelf = core.unitSelf
	
	--[[
	local bDebugExpectedDamage=true
	--Expected damage in near future -- IMPOSSIBLE ATM! No damage information on projectiles
	-------------------------------------
	local nExpectedDamage = 0
	local nUtilityDamageExpected = 0
	
	local nDamageTrue = 0
	local nDamagePhysical = 0
	local nDamagenMagical = 0
	local tIncomingProjectiles = eventsLib.incomingProjectiles["all"]
	for _, tEventData in pairs (tIncomingProjectiles) do
			eventsLib.printCombatEvent(tEventData)
		local nDamage = tEventData.DamageAttempted
		if nDamage then
			local sType = tEventData.DamageType
			if sType =="Physical" or sType=="SuperiorMagic" then
				nDamagePhysical = nDamagePhysical + nDamage
				if bDebugExpectedDamage then BotEcho("Physical Damage: "..tostring(nDamage)) end
			elseif sType =="Magic" or sType=="SuperiorPhysical" then
				nDamagenMagical = nDamagenMagical + nDamage
				if bDebugExpectedDamage then BotEcho("Magical Damage: "..tostring(nDamage)) end
			elseif sType=="Attack" or sType=="Returned" then
				nDamageTrue = nDamageTrue + nDamage
				if bDebugExpectedDamage then BotEcho("True Damage: "..tostring(nDamage)) end
			end
		end
	end
	nExpectedDamage = nDamageTrue + nDamagePhysical*(1-unitSelf:GetPhysicalResistance())+
						nDamagenMagical*(1-unitSelf:GetMagicResistance())
						
	if bDebugExpectedDamage then BotEcho("Expected Damage after reduction: "..tostring(nExpectedDamage)) end

	if nExpectedDamage > 0 then
		local nHP = unitSelf:GetHealth()
		nUtilityDamageExpected = 150 * nHP / nExpectedDamage
		if bDebugExpectedDamage then BotEcho("utility damage expected"..tostring(nUtilityDamageExpected)) end
	end
	
	
	-------------------------------------
	--]]
	
	local nUtilityLifeTime, nTimeToLive = life.funcTimeToLiveUtility(core.unitSelf)
	
	if bDebugEchos then BotEcho("RetreatUtility: TimeToLive:"..tostring(nTimeToLive).." Utility Points: "..tostring(nUtilityLifeTime)) end
	
	local nMyID = unitSelf:GetUniqueID()
	--local tDangerousStates = life.funcUnitDangerousStatesApplied(unitSelf)
	--local nDangerousStates = core.NumberElements(tDangerousStates) * object.nDangerousStatesMalus
	
	--if bDebugEchos then BotEcho("..Dangerous State Utility: "..tostring(nDangerousStates)) end
	
	local tEnemyCreeps = core.localUnits["EnemyCreeps"]
	local tEnemyTowers = core.localUnits["EnemyTowers"]
	
	--Creep aggro
	local nCreepAggro = 0
	for _, unitEnemyCreep in pairs(tEnemyCreeps) do
		local unitAggroTarget = unitEnemyCreep:GetAttackTarget()
		if unitAggroTarget and unitAggroTarget:GetUniqueID() == nMyID then
			nCreepAggro = nCreepAggro + 1
		end
	end
	local nCreepAggroUtility = nCreepAggro * life.CreepThreatMultiplicator

	if bDebugEchos then BotEcho("..Number of Creeps:"..tostring(nCreepAggro).." Utility Points: +"..tostring(nCreepAggroUtility)) end
	
	--Tower Aggro
	local nTowerAggroUtility = 0
	for id, unitTower in pairs(tEnemyTowers) do
		local unitAggroTarget = unitTower:GetAttackTarget()
		if unitAggroTarget and unitAggroTarget == nMyID then
			nTowerAggroUtility = life.nTowerAggroUtility
			break
		end
	end
	
	local nUtility  = nUtilityLifeTime + nCreepAggroUtility + nTowerAggroUtility --+ nDangerousStates + nUtilityDamageExpected
	
	if bDebugEchos then BotEcho("..Tower Aggro: +"..tostring(nTowerAggroUtility)) end
	
	--bonus of allies decrease fear
	local allies = core.localUnits["AllyHeroes"]
	local nAllies = core.NumberElements(allies) + 1 
	
	--get enemy heroes
	local tEnemyTeam = HoN.GetHeroes(core.enemyTeam)
	local funcGetThreatOfEnemy = life.funcGetThreatOfEnemy
	
	local nUtilityThreat = 0
	
	--calculate the threat-value and increase utility value
	for id, unitEnemy in pairs(tEnemyTeam) do
	--BotEcho (id.." Hero "..unitEnemy:GetTypeName())
		nUtilityThreat = nUtilityThreat + funcGetThreatOfEnemy(unitEnemy) 
	end
	
	
	nUtility = nUtility + Clamp(nUtilityThreat / nAllies, 0, 30)
	
	if bDebugEchos then BotEcho("..Threat: "..tostring(nUtilityThreat).." End Utility +"..tostring(nUtility)) end
	
	--[[
	local nlastRetreatUtil = life.lastRetreatUtil or 0 
	
	if nUtility +10 < nlastRetreatUtil then
		nUtility = life.lastRetreatUtil - 10
		if bDebugEchos then BotEcho("..Warning: Utility value is dropping too fast. New Value : "..tostring(nUtility).." Value of last cycle"..tostring(nlastRetreatUtil)) end
	end
	--]]
	life.lastRetreatUtil = nUtility
	
	if bCompareOldToNew then
		local nOld =life.RetreatFromThreatUtilityOld(botBrain)
		BotEcho("Utility new Retreat function: "..nUtility)
		BotEcho("Utility old Retreat function: "..nOld)
	end
	
	return nUtility
	
end
life.RetreatFromThreatUtilityOld =  behaviorLib.RetreatFromThreatUtility
behaviorLib.RetreatFromThreatBehavior["Utility"] = CustomRetreatFromThreatUtilityFnOverride

------------------------------------------------------------------
--Heal at well utility
------------------------------------------------------------------
local function CustomHealAtWellUtilityFnOverride(botBrain)
	local nUtility = 0
	
	local unitSelf = core.unitSelf
	local nHPPercent = unitSelf:GetHealthPercent()
	local nMPPercentMissing = 1-unitSelf:GetManaPercent()

	--low hp increases wish to go home
	if nHPPercent < 0.90 then
		local wellPos = core.allyWell and core.allyWell:GetPosition() or Vector3.Create()
		local nDist = Vector3.Distance2D(wellPos, unitSelf:GetPosition())

		nUtility = behaviorLib.WellHealthUtility(nHPPercent) + behaviorLib.WellProximityUtility(nDist)
	end
	
	--low mana increases wish to go home
	if nMPPercentMissing > 0.10 then
		nUtility = nUtility + nMPPercentMissing * 15
	end

	return Clamp(nUtility, 0, 50)
end
behaviorLib.HealAtWellBehavior["Utility"] = CustomHealAtWellUtilityFnOverride

---------------------------------------------------
-- On think: TeambotBrain  and Courier Control
---------------------------------------------------
life.nHPUpdate = 0
function life:onThinkLife(tGameVariables)

	local nNow = HoN.GetGameTime()
	
	--Update tracked life data
	if life.nHPUpdate <= nNow then
	
		life.nHPUpdate = nNow + behaviorLib.nBehaviorAssessInterval
		
		local tHealthMemory = life.tHealthMemory
		
		local tDelete = {}
		
		for nID, tHeroInfo in pairs(tHealthMemory) do
			local unitHero = tHeroInfo[2]
			local nUnitHP = unitHero and unitHero:GetHealth()
			if nUnitHP then
				life.UpdateHealthObservation(tHeroInfo[1], nUnitHP)
			else
				--entry obsolet, delete it
				tinsert(tDelete, nID)
			end
		end
		
		for _, nID in pairs(tDelete) do
			tHealthMemory[nID] = nil
		end
	end
	
	--old onThink
	self:onthinkPreLife(tGameVariables)
end
object.onthinkPreLife = object.onthink
object.onthink 	= life.onThinkLife