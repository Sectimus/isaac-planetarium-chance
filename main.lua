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
		local slide = TextAcceleration((2.9 - self.fontalpha)/(2 * 0.01))
		if difference>0 then --positive difference
			self.font:DrawString("+"..differenceOutput, textCoords.X + 46, textCoords.Y, KColor(0,1,0,alpha),0,true)
		elseif difference<0 then --negative difference
			self.font:DrawString(differenceOutput, textCoords.X + 46, textCoords.Y, KColor(1,0,0,alpha),0,true)
		end
		self.fontalpha = self.fontalpha-0.01
	end
end

function mod:exit()
	self.initialized = false
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

-- if the helper trinket somehow does spawn, replace it with a random trinket from the pool
function mod:preventHelperTrinketSpawn(pickup)
	if pickup.SubType == achievementTrinket then
		pickup:Morph(pickup.Type, pickup.Variant, Game():GetItemPool():GetTrinket())
	end
end

-- check if you start with the helper trinket and replace it, mostly for eden
function mod:preventHelperTrinketPickup(player)
	if player:HasTrinket(achievementTrinket, true) then
		player:TryRemoveTrinket(achievementTrinket)
		player:AddTrinket(Game():GetItemPool():GetTrinket())
	end
end

function mod:init(continued)
	if not continued then
		self.storage.canPlanetariumsSpawn = 0
		if Game():GetItemPool():RemoveTrinket(achievementTrinket) then -- check if helper trinket is available to know if planetariums are unlocked
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
		end
		mod:SaveData(json.encode(self.storage.canPlanetariumsSpawn)) -- this is the only thing that needs to be saved, everything else can be recalculated
	elseif continued then
		self.storage.canPlanetariumsSpawn = json.decode(mod:LoadData()) or 1
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
	
	local level = Game():GetLevel()
 
	self.storage.previousFloorSpawnChance = self.storage.currentFloorSpawnChance
	
	self.storage.currentFloorSpawnChance = level:GetPlanetariumChance()
	
	--Planetarium chance can never be more than 100%. (technically 99.9% as there is never a 100% guarantee)
	if self.storage.currentFloorSpawnChance>1 then
		self.storage.currentFloorSpawnChance = 1;
	elseif self.storage.currentFloorSpawnChance<0 then 
		self.storage.currentFloorSpawnChance = 0;
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
	local RedHeartShift = false
	local SoulHeartShift = false
	local PoopShift = false
	local BombShift = false
	local TrueCoopShift = (Game():GetNumPlayers() > 1)

	self.coords = Vector(0, 185) - Vector(0, 9) --Subtraction needed to correct for either bomb shift or poop shift
	
	for p = 1, Game():GetNumPlayers() do
		local player = Game():GetPlayer(p-1)
		local playerType = Isaac.GetPlayer(p-1):GetPlayerType()
		if p == 1 and playerType == PlayerType.PLAYER_JACOB then --Jacob always has Esau so no need to check for Esau
			self.coords = self.coords + Vector(0, 14)
		elseif playerType == PlayerType.PLAYER_BETHANY and not SoulHeartShift then -- Shifts Stats because of Soul Heart Counter
			self.coords = self.coords + Vector(0, 9)
			SoulHeartShift = true
		elseif playerType == PlayerType.PLAYER_BETHANY_B and not RedHeartShift then -- Shifts Stats because of Red Heart Counter
			self.coords = self.coords + Vector(0, 9)
			RedHeartShift = true
		elseif playerType == PlayerType.PLAYER_XXX_B and not PoopShift then -- Shifts Stats because of Poop Counter
			self.coords = self.coords + Vector(0, 9)
			PoopShift = true
		end
		if playerType ~= PlayerType.PLAYER_XXX_B and player:GetBabySkin() == -1 and not BombShift then -- Shifts Stats because of Bomb Counter, only needed if Tainted XXX plays with anyone else
			self.coords = self.coords + Vector(0, 9)
			BombShift = true
		end
		-- Ignores Coop Babies, Tainted Forgottens Soul, and Temporary players like Strawman or Soul of Forgotten/Jacob&Esau. Otherwise Shift to show 2nd player stats. Includes Esau
		if TrueCoopShift and  p > 1 and player:GetBabySkin() == -1 and playerType ~= PlayerType.PLAYER_THESOUL_B and player.Parent == nil then
			self.coords = self.coords + Vector(0, 16)
			TrueCoopShift = false
		end
	end

	if EveryoneHasCollectibleNum(CollectibleType.COLLECTIBLE_DUALITY) > 0 then
		self.coords = self.coords + Vector(0, -12)
	end

	--Checks if Normal Mode and not Seeded/Challenge/Daily; Seeded/Challenge have no achievements logo, and Daily Challenge has destination logo.
	if Game().Difficulty == Difficulty.DIFFICULTY_NORMAL and not Game():GetSeeds():IsCustomRun() and not SeedBlocksAchievements() then
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

	if self.storage.numplayers ~= activePlayers then
		updatePos = true
		self.storage.numplayers = activePlayers
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
mod:initStore();

mod:AddCallback(ModCallbacks.MC_POST_NEW_LEVEL, mod.updatePlanetariumChance)
	
mod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, mod.init)
mod:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, mod.exit)

mod:AddCallback(ModCallbacks.MC_GET_SHADER_PARAMS, mod.onRender)
--mod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, mod.test)

mod:AddCallback(ModCallbacks.MC_POST_UPDATE, mod.updateCheck)

mod:AddCallback(ModCallbacks.MC_POST_PICKUP_INIT, mod.preventHelperTrinketSpawn, PickupVariant.PICKUP_TRINKET)
mod:AddCallback(ModCallbacks.MC_POST_PLAYER_UPDATE, mod.preventHelperTrinketPickup)
--mod:AddCallback(ModCallbacks.MC_USE_ITEM, mod.rKeyCheck, CollectibleType.COLLECTIBLE_R_KEY)

--Custom Shader Fix by AgentCucco
mod:AddCallback(ModCallbacks.MC_POST_PLAYER_INIT, function()
	if #Isaac.FindByType(EntityType.ENTITY_PLAYER) == 0 then
		Isaac.ExecuteCommand("reloadshaders")
	end
end)