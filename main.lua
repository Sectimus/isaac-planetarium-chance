PlanetariumChance = RegisterMod("Planetarium Chance", 1)
local mod = PlanetariumChance

mod.initialized=false

function mod:onRender(shaderName)
	if shaderName ~= "UI_DrawPlanetariumChance_DummyShader" then return end
	if mod:shouldDeHook() then return end

	--check for notch update on pause
	if Game():IsPaused() then mod:updateCheck() end

	--account for screenshake offset
	local textCoords = self.coords+Game().ScreenShakeOffset;
	local valueOutput = string.format("%.1s%%", "?")
	if self.storage.currentFloorSpawnChance then
		valueOutput = string.format("%.1f%%", self.storage.currentFloorSpawnChance)
	else
		mod:updatePlanetariumChance();
	end
	self.font:DrawString(valueOutput, textCoords.X+16, textCoords.Y, KColor(1,1,1,0.5),0,true)
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
		local difference = self.storage.currentFloorSpawnChance - self.storage.previousFloorSpawnChance;
		local differenceOutput = string.format("%.1f%%", difference)
		if difference>0 then --positive difference
			self.font:DrawString("+"..differenceOutput, textCoords.X+16+self.font:GetStringWidth(valueOutput)+3, textCoords.Y, KColor(0,1,0,alpha),0,true)
		elseif difference<0 then --negative difference
			self.font:DrawString(differenceOutput, textCoords.X+16+self.font:GetStringWidth(valueOutput)+3, textCoords.Y, KColor(1,0,0,alpha),0,true)
		end
		self.fontalpha = self.fontalpha-0.01
	end
end

function mod:exit()
	if mod:shouldDeHook() then return end
	--TODO cleanup sprite
end

local achievementTrinket = Isaac.GetTrinketIdByName("Planetarium Unlock Checker")
-- hide helper trinket in Encyclopedia mod
if Encyclopedia then
	Encyclopedia.AddTrinket({
		ID = achievementTrinket,
		Hide = true,
	})
end

function mod:init(continued)
	self.storage.canPlanetariumsSpawn = nil
	if Game():GetItemPool():RemoveTrinket(achievementTrinket) then -- check if helper trinket is available to know if planetariums are unlocked
		if not Game():IsGreedMode() then -- check greed mode since planetariums cannot spawn in greed mode
			local rooms = Game():GetLevel():GetRooms()
			for i = 0, rooms.Size - 1 do
				local room = rooms:Get(i).Data
				if room.Type == RoomType.ROOM_TREASURE then -- check if there is a treasure room on the floor since planetariums require treasure rooms in the game to spawn (for challenges)
					self.storage.canPlanetariumsSpawn = true
					break
				end
			end
		end
	end
	
	self.storage.currentFloorSpawnChance = nil

	self:updatePlanetariumChance();

	self:updatePosition();

	self.hudSprite = Sprite()
	self.hudSprite:Load("gfx/ui/hudstats2.anm2", true)
	self.hudSprite.Color = Color(1,1,1,0.5);
	self.hudSprite:SetFrame("Idle", 8)
	self.font = Font();
	self.font:Load("font/luaminioutlined.fnt")

	self.initialized = true;
end

-- update on new level
function mod:updatePlanetariumChance()
	if mod:shouldDeHook() then return end
	
	local level = Game():GetLevel()
 
	self.storage.previousFloorSpawnChance = self.storage.currentFloorSpawnChance
	
	self.storage.currentFloorSpawnChance = level:GetPlanetariumChance()
	
	--Planetarium chance can never be more than 100%. (technically 99.9% as there is never a 100% guarantee)
	if self.storage.currentFloorSpawnChance>0.999 then
		self.storage.currentFloorSpawnChance = 0.999;
	elseif self.storage.currentFloorSpawnChance<0 then 
		self.storage.currentFloorSpawnChance = 0;
	end
	
	if level:IsAscent() or not self.storage.canPlanetariumsSpawn then
		self.storage.currentFloorSpawnChance = 0
	end
		
	--make absolute
	self.storage.currentFloorSpawnChance = self.storage.currentFloorSpawnChance * 100

	--don't display popup if there is no change
	if self.storage.previousFloorSpawnChance and (self.storage.currentFloorSpawnChance - self.storage.previousFloorSpawnChance ) then
		self.fontalpha = 3
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
	self.coords = Vector(0, 185)
	
	for p = 1, Game():GetNumPlayers() do
		local playerType = Isaac.GetPlayer(p-1):GetPlayerType()
		if playerType == PlayerType.PLAYER_BETHANY or playerType == PlayerType.PLAYER_BETHANY_B then 
			self.coords = self.coords + Vector(0, 9)
			break
		elseif playerType == PlayerType.PLAYER_JACOB then --Jacob always has Esau so no need to check for Esau
			self.coords = self.coords + Vector(0, 14)
			break
		end
	end
	
	--check for co-op babies and t soul since they dont add stats
	local realPlayers = Game():GetNumPlayers()
	for p = 1, Game():GetNumPlayers() do
		local player = Game():GetPlayer(p)
		if player:GetBabySkin() ~= -1 or player:GetPlayerType() == PlayerType.PLAYER_THESOUL_B then
			realPlayers = realPlayers - 1
		end
	end
	if realPlayers > 1 then
		self.coords = self.coords + Vector(0, 16)
	end

	if EveryoneHasCollectibleNum(CollectibleType.COLLECTIBLE_DUALITY) > 0 then
		self.coords = self.coords + Vector(0, -12)
	end

	if Game().Difficulty == Difficulty.DIFFICULTY_NORMAL and Isaac.GetChallenge() == 0 then
		self.coords = self.coords + Vector(0, -16)
	end

	self.coords = self.coords + (Options.HUDOffset * Vector(20, 12))
end

function mod:updateCheck()
	local updatePos = false
	
	local activePlayers = Game():GetNumPlayers()
	
	for p = 1, activePlayers do
		local player = Isaac.GetPlayer(p-1)
		if player.FrameCount == 1 or DidPlayerCharacterJustChange(player) then
			updatePos = true
		end
	end

	if self.storage.hudoffset ~= Options.HUDOffset then
		updatePos = true
		self.storage.hudoffset = Options.HUDOffset
	end

	--duality can move the icon
	if(EveryoneHasCollectibleNum(CollectibleType.COLLECTIBLE_DUALITY) > 0) then
		self.storage.hadDuality = true
		updatePos = true;
	elseif self.storage.hadDuality then
		updatePos = true;
		self.storage.hadDuality = false
	end
			
	if updatePos then
		self:updatePosition();
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

function EveryoneHasCollectibleNum(collectibleID)
	local collectibleCount = 0
	for p = 1, Game():GetNumPlayers() do
		local player = Isaac.GetPlayer(p-1)
		collectibleCount = collectibleCount + player:GetCollectibleNum(collectibleID)
	end
	return collectibleCount
end

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

--init self storage from mod namespace before any callbacks by blocking.
function mod:initStore()
	self.storage = {} 
	self.coords = Vector(21, 197.5)
end
mod:initStore();

mod:AddCallback(ModCallbacks.MC_POST_NEW_LEVEL, mod.updatePlanetariumChance)

mod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, mod.init)
mod:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, mod.exit)

mod:AddCallback(ModCallbacks.MC_GET_SHADER_PARAMS, mod.onRender)
--mod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, mod.test)

mod:AddCallback(ModCallbacks.MC_POST_UPDATE, mod.updateCheck)

mod:AddCallback(ModCallbacks.MC_USE_ITEM, mod.rKeyCheck, CollectibleType.COLLECTIBLE_R_KEY)

--Custom Shader Fix by AgentCucco
mod:AddCallback(ModCallbacks.MC_POST_PLAYER_INIT, function()
	if #Isaac.FindByType(EntityType.ENTITY_PLAYER) == 0 then
		Isaac.ExecuteCommand("reloadshaders")
	end
end)