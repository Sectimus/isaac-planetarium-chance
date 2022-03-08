PlanetariumChance = RegisterMod("Planetarium Chance", 1)
local mod = PlanetariumChance
local json = require("json")

mod.initialized=false

local NoTrophySeeds = {
	SeedEffect.SEED_INFINITE_BASEMENT, SeedEffect.SEED_PICKUPS_SLIDE, SeedEffect.SEED_ITEMS_COST_MONEY, SeedEffect.SEED_PACIFIST, SeedEffect.SEED_ENEMIES_RESPAWN, 
	SeedEffect.SEED_POOP_TRAIL, SeedEffect.SEED_INVINCIBLE, SeedEffect.SEED_KIDS_MODE, SeedEffect.SEED_PERMANENT_CURSE_LABYRINTH, SeedEffect.SEED_PREVENT_CURSE_DARKNESS, 
	SeedEffect.SEED_PREVENT_CURSE_LABYRINTH, SeedEffect.SEED_PREVENT_CURSE_LOST, SeedEffect.SEED_PREVENT_CURSE_UNKNOWN, SeedEffect.SEED_PREVENT_CURSE_MAZE, 
	SeedEffect.SEED_PREVENT_CURSE_BLIND, SeedEffect.SEED_PREVENT_ALL_CURSES, SeedEffect.SEED_GLOWING_TEARS, SeedEffect.SEED_ALL_CHAMPIONS, SeedEffect.SEED_ALWAYS_CHARMED, 
	SeedEffect.SEED_ALWAYS_CONFUSED, SeedEffect.SEED_ALWAYS_AFRAID, SeedEffect.SEED_ALWAYS_ALTERNATING_FEAR, SeedEffect.SEED_ALWAYS_CHARMED_AND_AFRAID, SeedEffect.SEED_SUPER_HOT
	}


function mod:onRender(shaderName)
	if shaderName ~= "UI_DrawPlanetariumChance_DummyShader" then return end
	if mod:shouldDeHook() then return end
	
	mod:updateCheck()
	
	--account for screenshake offset
	local textCoords = self.coords + Game().ScreenShakeOffset
	local valueOutput = string.format("%.1s%%", "?")
	if self.storage.currentFloorSpawnChance then
		valueOutput = string.format("%.1f%%", self.storage.currentFloorSpawnChance)
	else
		mod:updatePlanetariumChance()
	end
	self.font:DrawString(valueOutput, textCoords.X+16, textCoords.Y+1, KColor(1,1,1,0.5),0,true)
	self.hudSprite:Render(self.coords, Vector(0,0), Vector(0,0))

	--differential popup
	if self.fontalpha and self.fontalpha>0 then
		local alpha = self.fontalpha
		if self.fontalpha > 0.5 then
			alpha = 0.5
		end
		if self.storage.previousFloorSpawnChance == nil then 
			self.storage.previousFloorSpawnChance = self.storage.currentFloorSpawnChance
		end
		local difference = self.storage.currentFloorSpawnChance - self.storage.previousFloorSpawnChance
		local differenceOutput = string.format("%.1f%%", difference)
		local slide = TextAcceleration((2.9 - self.fontalpha)/(2 * 0.01))
		if difference>0 then --positive difference
			self.font:DrawString("+"..differenceOutput, textCoords.X + 46 + slide, textCoords.Y+1, KColor(0,1,0,alpha),0,true)
		elseif difference<0 then --negative difference
			self.font:DrawString(differenceOutput, textCoords.X + 46 + slide, textCoords.Y+1, KColor(1,0,0,alpha),0,true)
		end
		self.fontalpha = self.fontalpha-0.01
	end
end

function mod:exit()
	self.initialized = false
	if mod:shouldDeHook() then return end
	--TODO cleanup sprite
end

function mod:init(continued)
	if not continued then
		self.storage.canPlanetariumsSpawn = 0
		if not Game():IsGreedMode() then -- check greed mode since planetariums cannot spawn in greed mode
			local rooms = Game():GetLevel():GetRooms()
			for i = 0, rooms.Size - 1 do
				local room = rooms:Get(i).Data
				if room.Type == RoomType.ROOM_TREASURE then -- check if there is a treasure room on the floor since planetariums require treasure rooms in the game to spawn (for challenges)
					self.storage.canPlanetariumsSpawn = 1
					break
				end
			end
		end
		mod:SaveData(json.encode(self.storage.canPlanetariumsSpawn)) -- this is the only thing that needs to be saved, everything else can be recalculated
	elseif continued then
		self.storage.canPlanetariumsSpawn = json.decode(mod:LoadData()) or 1
	end
	
	self.storage.currentFloorSpawnChance = nil

	self:updatePlanetariumChance()

	self:updatePosition()

	self.hudSprite = Sprite()
	self.hudSprite:Load("gfx/ui/hudstats2.anm2", true)
	self.hudSprite.Color = Color(1,1,1,0.5)
	self.hudSprite:SetFrame("Idle", 8)
	self.font = Font()
	self.font:Load("font/luaminioutlined.fnt")
	
	self.initialized = true
end

-- update on new level
function mod:updatePlanetariumChance()
	
	local level = Game():GetLevel()
 
	self.storage.previousFloorSpawnChance = self.storage.currentFloorSpawnChance
	
	self.storage.currentFloorSpawnChance = level:GetPlanetariumChance()
	
	if self.storage.currentFloorSpawnChance>1 then
		self.storage.currentFloorSpawnChance = 1
	elseif self.storage.currentFloorSpawnChance<0 then 
		self.storage.currentFloorSpawnChance = 0
	end
	
	if level:IsAscent() or self.storage.canPlanetariumsSpawn == 0 then
		self.storage.currentFloorSpawnChance = 0
	end
		
	--make absolute
	self.storage.currentFloorSpawnChance = self.storage.currentFloorSpawnChance * 100

	--don't display popup if there is no change or if run new/continued
	if self.storage.previousFloorSpawnChance and (self.storage.currentFloorSpawnChance ~= self.storage.previousFloorSpawnChance ) then
		self.fontalpha = 2.9
	end
end

function mod:shouldDeHook()

	local reqs = {
		not self.initialized,
		not Options.FoundHUD,
		not Game():GetHUD():IsVisible(),
		Game():GetRoom():GetType() == RoomType.ROOM_DUNGEON and Game():GetLevel():GetAbsoluteStage() == LevelStage.STAGE8, --beast fight
		Game():GetSeeds():HasSeedEffect(SeedEffect.SEED_NO_HUD)
	}

	return reqs[1] or reqs[2] or reqs[3] or reqs[4] or reqs[5]
end

function mod:updatePosition()
	--Updates position of Chance Stat
	local JacobShift = false
	local RedHeartShift = false
	local SoulHeartShift = false
	local DualityShift = false
	
	local TruePlayerCount = 1 -- there is always at least 1 player
	local T_BlueBabyCount = 0
	local ShiftCount = 0

	self.coords = Vector(0, 168)
	
	for p = 1, Game():GetNumPlayers() do
		local player = Isaac.GetPlayer(p-1)
		local playerType = player:GetPlayerType()
		local twinType = player:GetMainTwin():GetPlayerType() -- should be the same as playertype unless j&e and t forgor
		
		-- Ignores Coop Babies, Tainted Forgottens Soul, Esau, and Temporary players like Strawman or Soul of Forgotten/Jacob&Esau. Otherwise Shift to show 2nd player stats
		if p > 1 and player:GetBabySkin() == -1 and playerType == twinType and player.Parent == nil then
			TruePlayerCount = TruePlayerCount + 1
		end
		if playerType == PlayerType.PLAYER_BLUEBABY_B then -- Count T Blue Babies for any co-op poop counter shenanigans
			T_BlueBabyCount = T_BlueBabyCount + 1
		end
		
		--For some reason whether or not Jacob&Esau are 1st player or another player matters, so I have to check specifically if its player 1. Regular co-op shift will be used if player 2
		if p == 1 and playerType == PlayerType.PLAYER_JACOB and not JacobShift then
			JacobShift = true
		end
		if playerType == PlayerType.PLAYER_BETHANY and not SoulHeartShift then -- Shifts Stats because of Soul Heart Counter
			SoulHeartShift = true
		end
		if playerType == PlayerType.PLAYER_BETHANY_B and not RedHeartShift then -- Shifts Stats because of Red Heart Counter
			RedHeartShift = true
		end
		
		if player:HasCollectible(CollectibleType.COLLECTIBLE_DUALITY) and not DualityShift then -- Shifts Stats because of Duality
			DualityShift = true
		end
	end
	
	-- Shift Stats because of T. Blue Baby in Co-op.
	local ExtraPoopShift = false
	if T_BlueBabyCount > 0 and TruePlayerCount ~= T_BlueBabyCount then
		ExtraPoopShift = true
	end
	
	if ExtraPoopShift then
		ShiftCount = ShiftCount + 1
	end
	if SoulHeartShift then
		ShiftCount = ShiftCount + 1
	end
	if RedHeartShift then
		ShiftCount = ShiftCount + 1
	end
	
	if ShiftCount > 0 then
		self.coords = self.coords + Vector(0, (8 * ShiftCount) + (2 * ShiftCount))
		
		-- I have to do these miniscule shifts to get it to look right. The initial algorithm looks clean, but there's something I'm missing...
		if ShiftCount == 1 then
			self.coords = self.coords + Vector(0, -1)..
		end
		if ShiftCount == 3 then
			self.coords = self.coords + Vector(0, 1)
		end
	end
	
	if JacobShift then
		self.coords = self.coords + Vector(0, 30)
	elseif TruePlayerCount > 1 then
		self.coords = self.coords + Vector(0, 16)
		if DualityShift then
			self.coords = self.coords + Vector(0, -2)
		end
	end
	if DualityShift then
		self.coords = self.coords + Vector(0, -12)
	end

	--Checks if Hard Mode and Seeded/Challenge/Daily; Seeded/Challenge have no achievements logo, and Daily Challenge has destination logo.
	if Game().Difficulty == Difficulty.DIFFICULTY_HARD or SeedBlocksAchievements() or Game():GetSeeds():IsCustomRun() then
		self.coords = self.coords + Vector(0, 16)
	end

	self.coords = self.coords + (Options.HUDOffset * Vector(20, 12))
end

function mod:updateCheck()
	local updatePos = false
	
	local activePlayers = Game():GetNumPlayers()
	
	for p = 1, activePlayers do
		local player = Isaac.GetPlayer(p-1)
		if player.FrameCount == 0 or DidPlayerCharacterJustChange(player) or DidPlayerCollectibleCountJustChange(player) then
			updatePos = true
		end
	end

	if self.storage.numplayers ~= activePlayers then
		updatePos = true
		self.storage.numplayers = activePlayers
	end
	
	if self.storage.hudoffset ~= Options.HUDOffset then
		updatePos = true
		self.storage.hudoffset = Options.HUDOffset
	end
		
	--Was a Victory Lap Completed, Runs completed on Normal Difficulty Will switch to HARD upon start of a Victory Lap
	if self.storage.VictoryLap ~= Game():GetVictoryLap() then
		updatePos = true
		self.storage.VictoryLap = Game():GetVictoryLap()
	end
	
	--Certain Seed Effects block achievements
	if self.storage.NumSeedEffects ~= Game():GetSeeds():CountSeedEffects() then
		updatePos = true
		self.storage.NumSeedEffects = Game():GetSeeds():CountSeedEffects()
	end
		
	if updatePos then
		self:updatePosition()
	end
end

function mod:rKeyCheck()
	mod:init(false) --this should be good enough
end

---------------------------------------------------------------------------------------------------------

-- Custom Log Command
function log(text)
	Isaac.DebugString(tostring(text))
end

function GetMaxTrinketID()
    return Isaac.GetItemConfig():GetTrinkets().Size -1
end

--collectible count just change
function DidPlayerCollectibleCountJustChange(player)
	local data = player:GetData()
	if data.didCollectibleCountJustChange then
		return true
	end
	return false
end
mod:AddCallback(ModCallbacks.MC_POST_PLAYER_UPDATE, function(_, player)
	local data = player:GetData()
	local currentCollectibleCount = player:GetCollectibleCount()
	if not data.lastCollectibleCount then
		data.lastCollectibleCount = currentCollectibleCount
	end
	data.didCollectibleCountJustChange = false
	if data.lastCollectibleCount ~= currentCollectibleCount then
		data.didCollectibleCountJustChange = true
	end
	data.lastCollectibleCount = currentCollectibleCount
end)

--character just change
function DidPlayerCharacterJustChange(player)
	local data = player:GetData()
	if data.playerTypeJustChanged then
		return true
	end
	return false
end

mod:AddCallback(ModCallbacks.MC_POST_PLAYER_UPDATE, function(_, player)
	local data = player:GetData()
	local playerType = player:GetPlayerType()
	if not data.lastPlayerType then
		data.lastPlayerType = playerType
	end
	data.playerTypeJustChanged = false
	if data.lastPlayerType ~= playerType then
		data.playerTypeJustChanged = true
	end
	data.lastPlayerType = playerType
end)

function SeedBlocksAchievements()
	local seed = Game():GetSeeds()
	for _,effect in pairs(NoTrophySeeds) do
		if seed:HasSeedEffect(effect) then
			return true
		end
	end
	return false
end

function TextAcceleration(frame) --Overfit distance profile for difference text slide in
	frame = frame - 14
	if frame > 0 then
		return 0
	end
	return -(15.1/(13*13))*frame*frame
end


--init self storage from mod namespace before any callbacks by blocking.
function mod:initStore()
	self.storage = {} 
	self.coords = Vector(21, 197.5)
end
mod:initStore()

mod:AddCallback(ModCallbacks.MC_POST_NEW_LEVEL, mod.updatePlanetariumChance)
	
mod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, mod.init)
mod:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, mod.exit)

mod:AddCallback(ModCallbacks.MC_GET_SHADER_PARAMS, mod.onRender)

--mod:AddCallback(ModCallbacks.MC_USE_ITEM, mod.rKeyCheck, CollectibleType.COLLECTIBLE_R_KEY)

--Custom Shader Fix by AgentCucco
mod:AddCallback(ModCallbacks.MC_POST_PLAYER_INIT, function()
	if #Isaac.FindByType(EntityType.ENTITY_PLAYER) == 0 then
		Isaac.ExecuteCommand("reloadshaders")
	end
end)