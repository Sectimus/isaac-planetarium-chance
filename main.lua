PlanetariumChance = RegisterMod("Planetarium Chance", 1)
local mod = PlanetariumChance
local json = require("json")

mod.initialized=false;

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

function mod:init(continued)
	--challenges can still spawn planetariums if they can spawn treasure rooms, so detect if theres a treasure room on the first floor.
	self.storage.gameHasTreasure = nil
	local rooms = Game():GetLevel():GetRooms()
	for i = 0, rooms.Size - 1 do
		local room = rooms:Get(i).Data
		if room.Type == RoomType.ROOM_TREASURE then
			self.storage.gameHasTreasure = true
			break
		end
	end
	
	self.storage.currentFloorSpawnChance = nil

	self:updatePlanetariumChance();

	--check char
	self:updateCheck();
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
 
	self.storage.previousFloorSpawnChance = self.storage.currentFloorSpawnChance
	local game = Game();
	local level = game:GetLevel();
	local stage = level:GetStage();
	
	self.storage.currentFloorSpawnChance = level:GetPlanetariumChance()
	
	--Planetarium chance can never be more than 100%. (technically 99.9% as there is never a 100% guarantee)
	if self.storage.currentFloorSpawnChance>0.999 then
		self.storage.currentFloorSpawnChance = 0.999;
	elseif self.storage.currentFloorSpawnChance<0 then 
		self.storage.currentFloorSpawnChance = 0;
	end
	
	--Set to 0 during the Ascent
	if level:IsAscent() then
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
		not self.storage.gameHasTreasure,
		not Game():GetHUD():IsVisible(),
		Game():GetRoom():GetType() == RoomType.ROOM_DUNGEON and Game():GetLevel():GetAbsoluteStage() == LevelStage.STAGE8, --beast fight
		Game().Difficulty >= Difficulty.DIFFICULTY_GREED, --should be both greed and greedier
		Game():GetSeeds():HasSeedEffect(SeedEffect.SEED_NO_HUD)
	}

	return reqs[1] or reqs[2] or reqs[3] or reqs[4] or reqs[5] or reqs[6] or reqs[7]
end

--This callback is called 30 times per second. It will not be called, when its paused (for example on screentransitions or on the pause menu).
--Base coords are set here, they will be modified by hudoffset on another callback
--Multi stat display for coop only shows 2 lots of stats
function mod:updatePosition()
	self.coords = Vector(0, 185)
	--check for char differences (any player is a char with a different offset)

	for i = 1, #self.storage.character do
		if self.storage.character[i] == PlayerType.PLAYER_BETHANY or self.storage.character[i] == PlayerType.PLAYER_BETHANY_B then 
			self.coords = self.coords + Vector(0, 9)
			break;
		elseif self.storage.character[i] == PlayerType.PLAYER_THESOUL_B then 
			table.remove(self.storage.character, i)
			break;
		elseif self.storage.character[i] == PlayerType.PLAYER_JACOB then --Jacob always has Esau so no need to check for Esau
			self.coords = self.coords + Vector(0, 14)
			break;
		end
	end
	--two sets of stats are displayed on multiplayer
	if #self.storage.character > 1 then
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

--checks if char has been changed
function mod:updateCheck()
	local updatePos = false;
	if self.storage.character == nil or self.storage.character == 0 then self.storage.character = {} end

	local activePlayers = Game():GetNumPlayers()
	for p = 1, activePlayers do
		--remove babies as they do not have stats. 
		local isBaby = Game():GetPlayer(p):GetBabySkin() ~= -1
		if isBaby then
			activePlayers = activePlayers-1
		end
	end

	for p = 1, activePlayers do
		local playertype = Isaac.GetPlayer(p-1):GetPlayerType();
		if not (self.storage.character[p] == playertype) then
			self.storage.character[p] = playertype
			updatePos = true;
		end
	end

	local missingPlayers = 4 - activePlayers

	for p=1, missingPlayers do
		if(self.storage.character[activePlayers+p]) then
			table.remove(self.storage.character, activePlayers+p)
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

function GetPlayers(functionCheck, ...)

	local args = {...}
	local players = {}
	
	local game = Game()
	
	for i=1, game:GetNumPlayers() do
	
		local player = Isaac.GetPlayer(i-1)
		
		local argsPassed = true
		
		if type(functionCheck) == "function" then
		
			for j=1, #args do
			
				if args[j] == "player" then
					args[j] = player
				elseif args[j] == "currentPlayer" then
					args[j] = i
				end
				
			end
			
			if not functionCheck(table.unpack(args)) then
			
				argsPassed = false
				
			end
			
		end
		
		if argsPassed then
			players[#players+1] = player
		end
		
	end
	
	return players
	
end

function EveryoneHasCollectibleNum(collectibleID)
	local collectibleCount = 0
	for _, player in pairs(GetPlayers()) do
		collectibleCount = collectibleCount + player:GetCollectibleNum(collectibleID)
	end
	return collectibleCount
end

--init self storage from mod namespace before any callbacks by blocking.
function mod:initStore()
	self.storage = {} 
	self.coords = Vector(21, 197.5)
end
mod:initStore();

mod:AddCallback(ModCallbacks.MC_POST_NEW_LEVEL, mod.updatePlanetariumChance);

mod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, mod.init);
mod:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, mod.exit);

mod:AddCallback(ModCallbacks.MC_GET_SHADER_PARAMS, mod.onRender);
--mod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, mod.test)

--check for R Key use and run init if used
mod:AddCallback(ModCallbacks.MC_USE_ITEM, mod.rKeyCheck, CollectibleType.COLLECTIBLE_R_KEY);


