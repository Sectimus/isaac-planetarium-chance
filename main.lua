PlanetariumChance = RegisterMod("Planetarium Chance", 1)
local mod = PlanetariumChance
local json = require("json")

mod.initialized = false

function mod:onRender(shaderName)
	if mod:shouldDeHook() then return end

	local isShader = shaderName == "UI_DrawPlanetariumChance_DummyShader" and true or false

	if not (Game():IsPaused() and Isaac.GetPlayer(0).ControlsEnabled) and not isShader then return end -- no render when unpaused
	if (Game():IsPaused() and Isaac.GetPlayer(0).ControlsEnabled) and isShader then return end -- no shader when paused

	if shaderName ~= nil and not isShader then return end -- final failsafe

	mod:updateCheck()

	--account for screenshake offset
	local textCoords = self.coords + Game().ScreenShakeOffset
	local valueOutput = string.format("%.1s%%", "?")
	if self.storage.currentFloorSpawnChance then
		valueOutput = string.format("%.1f%%", self.storage.currentFloorSpawnChance)
	else
		mod:updatePlanetariumChance()
	end
	self.font:DrawString(valueOutput, textCoords.X + 16, textCoords.Y + 1, KColor(1, 1, 1, 0.5), 0, true)
	self.hudSprite:Render(self.coords, Vector(0, 0), Vector(0, 0))

	--differential popup
	if self.fontalpha and self.fontalpha > 0 then
		local alpha = self.fontalpha
		if self.fontalpha > 0.5 then
			alpha = 0.5
		end
		if self.storage.previousFloorSpawnChance == nil then
			self.storage.previousFloorSpawnChance = self.storage.currentFloorSpawnChance
		end
		local difference = self.storage.currentFloorSpawnChance - self.storage.previousFloorSpawnChance
		local differenceOutput = string.format("%.1f%%", difference)
		local slide = TextAcceleration((2.9 - self.fontalpha) / (2 * 0.01))
		if difference > 0 then --positive difference
			self.font:DrawString("+" .. differenceOutput, textCoords.X + 46 + slide, textCoords.Y + 1, KColor(0, 1, 0, alpha), 0, true)
		elseif difference < 0 then --negative difference
			self.font:DrawString(differenceOutput, textCoords.X + 46 + slide, textCoords.Y + 1, KColor(1, 0, 0, alpha), 0, true)
		end
		self.fontalpha = self.fontalpha - 0.01
	end
end

function mod:exit()
	self.initialized = false
	if mod:shouldDeHook() then return end
	--TODO cleanup sprite
end

function mod:init(continued)
	self.storage.available = Isaac.GetItemConfig():GetTrinket(TrinketType.TRINKET_TELESCOPE_LENS):IsAvailable() and 1 or 0
	if not continued then
		self.storage.canPlanetariumsSpawn = 0
		if self.storage.available == 1 then -- check if telescope lens is available, since if it isn't its either greed mode or planetariums are not unlocked
			local rooms = Game():GetLevel():GetRooms()
			for i = 0, rooms.Size - 1 do
				local room = rooms:Get(i).Data
				if room.Type == RoomType.ROOM_TREASURE then -- check if there is a treasure room on the floor since planetariums require treasure rooms in the game to spawn (for challenges)
					self.storage.canPlanetariumsSpawn = 1
					break
				end
			end
		end
		local savestate = {Available = self.storage.available, CanSpawn = self.storage.canPlanetariumsSpawn}
		mod:SaveData(json.encode(savestate)) -- this is the only thing that needs to be saved, everything else can be recalculated
	elseif continued then
		local loadstate = type(json.decode(mod:LoadData())) == "table" and json.decode(mod:LoadData()) or {}
		self.storage.available = tonumber(loadstate.Available or self.storage.available)
		self.storage.canPlanetariumsSpawn = tonumber(loadstate.CanSpawn or self.storage.available) -- if no save data, display chance if Telescope Lens available
	end

	self.storage.currentFloorSpawnChance = nil

	self:updatePlanetariumChance()

	self:updatePosition()

	self.hudSprite = Sprite()
	self.hudSprite:Load("gfx/ui/hudstats2.anm2", true)
	self.hudSprite.Color = Color(1, 1, 1, 0.5)
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

	if self.storage.currentFloorSpawnChance > 1 then
		self.storage.currentFloorSpawnChance = 1
	elseif self.storage.currentFloorSpawnChance < 0 then
		self.storage.currentFloorSpawnChance = 0
	end
	
	--Checks if planetariums were unlocked mid run, Only possible in Normal/Hard
	if self.storage.available == 0 and Isaac.GetItemConfig():GetTrinket(TrinketType.TRINKET_TELESCOPE_LENS):IsAvailable() then
		self.storage.available = 1
		self.storage.canPlanetariumsSpawn = 1
		local savestate = {Available = self.storage.available, CanSpawn = self.storage.canPlanetariumsSpawn}
		mod:SaveData(json.encode(savestate))
	end
	
	if level:IsAscent() or self.storage.canPlanetariumsSpawn == 0 then
		self.storage.currentFloorSpawnChance = 0
	end

	--make absolute
	self.storage.currentFloorSpawnChance = self.storage.currentFloorSpawnChance * 100

	--don't display popup if there is no change or if run new/continued
	if self.storage.previousFloorSpawnChance and (self.storage.currentFloorSpawnChance ~= self.storage.previousFloorSpawnChance) then
		self.fontalpha = 2.9
	end
end

function mod:shouldDeHook()

	local reqs = {
		not self.initialized,
		not Options.FoundHUD,
		not Game():GetHUD():IsVisible(),
		Game():GetRoom():GetType() == RoomType.ROOM_DUNGEON and Game():GetLevel():GetAbsoluteStage() == LevelStage.STAGE8, --beast fight
		Game():GetSeeds():HasSeedEffect(SeedEffect.SEED_NO_HUD),
		-- Game():IsGreedMode() //The chance should still display on Greed Mode even if its 0 for consistency with the rest of the HUD.
	}

	return reqs[1] or reqs[2] or reqs[3] or reqs[4] or reqs[5]
end

function mod:updatePosition()
	--Updates position of Chance Stat
	local TrueCoopShift = false
	local BombShift = false
	local PoopShift = false
	local RedHeartShift = false
	local SoulHeartShift = false
	local DualityShift = false

	local ShiftCount = 0

	self.coords = Vector(0, 168)

	for i = 0, Game():GetNumPlayers() - 1 do
		local player = Isaac.GetPlayer(i)
		local playerType = player:GetPlayerType()

		if player:GetBabySkin() == -1 then
			if i > 0 and player.Parent == nil and playerType == player:GetMainTwin():GetPlayerType() and not TrueCoopShift then
				TrueCoopShift = true
			end

			if playerType ~= PlayerType.PLAYER_BLUEBABY_B and not BombShift then -- Shift Stats because of Bomb Counter
				BombShift = true
			end
		end
		if playerType == PlayerType.PLAYER_BLUEBABY_B and not PoopShift then -- Shift Stats because of Poop Spell Counter
			PoopShift = true
		end
		if playerType == PlayerType.PLAYER_BETHANY_B and not RedHeartShift then -- Shifts Stats because of Red Heart Counter
			RedHeartShift = true
		end
		if playerType == PlayerType.PLAYER_BETHANY and not SoulHeartShift then -- Shifts Stats because of Soul Heart Counter
			SoulHeartShift = true
		end

		if player:HasCollectible(CollectibleType.COLLECTIBLE_DUALITY) and not DualityShift then -- Shifts Stats because of Duality
			DualityShift = true
		end
	end

	if BombShift then
		ShiftCount = ShiftCount + 1
	end
	if PoopShift then
		ShiftCount = ShiftCount + 1
	end
	if RedHeartShift then
		ShiftCount = ShiftCount + 1
	end
	if SoulHeartShift then
		ShiftCount = ShiftCount + 1
	end
	ShiftCount = ShiftCount - 1 -- There will always be 1 ShiftCount due to bombs and poop, so its safe to do this
	if ShiftCount > 0 then
		self.coords = self.coords + Vector(0, (11 * ShiftCount) - 2)
	end

	--For some reason whether or not Jacob&Esau are 1st player or another player matters, so I have to check specifically if Jacob is player 1 here
	if Isaac.GetPlayer(0):GetPlayerType() == PlayerType.PLAYER_JACOB then
		self.coords = self.coords + Vector(0, 30)
	elseif TrueCoopShift then
		self.coords = self.coords + Vector(0, 16)
		if DualityShift then
			self.coords = self.coords + Vector(0, -2) -- I hate this
		end
	end
	if DualityShift then
		self.coords = self.coords + Vector(0, -12)
	end

	--Checks if Hard Mode and Seeded/Challenge/Daily; Seeded/Challenge have no achievements logo, and Daily Challenge has destination logo.
	if Game().Difficulty == Difficulty.DIFFICULTY_HARD or Game():IsGreedMode() or not CanRunUnlockAchievements() then
		self.coords = self.coords + Vector(0, 16)
	end

	self.coords = self.coords + (Options.HUDOffset * Vector(20, 12))
end

function mod:updateCheck()
	local updatePos = false

	local activePlayers = Game():GetNumPlayers()

	for p = 1, activePlayers do
		local player = Isaac.GetPlayer(p - 1)
		if player.FrameCount == 0 or DidPlayerCharacterJustChange(player) or DidPlayerDualityCountJustChange(player) then
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
	return Isaac.GetItemConfig():GetTrinkets().Size - 1
end

function DidPlayerDualityCountJustChange(player)
	local data = player:GetData()
	if data.didDualityCountJustChange then
		return true
	end
	return false
end

mod:AddCallback(ModCallbacks.MC_POST_PLAYER_UPDATE, function(_, player)
	local data = player:GetData()
	local currentDualityCount = player:GetCollectibleNum(CollectibleType.COLLECTIBLE_DUALITY)
	if not data.lastDualityCount then
		data.lastDualityCount = currentDualityCount
	end
	data.didDualityCountJustChange = false
	if data.lastDualityCount ~= currentDualityCount then
		data.didDualityCountJustChange = true
	end
	data.lastDualityCount = currentDualityCount
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

function CanRunUnlockAchievements() -- by Xalum
	local machine = Isaac.Spawn(6, 11, 0, Vector.Zero, Vector.Zero, nil)
	local achievementsEnabled = machine:Exists()
	machine:Remove()

	return achievementsEnabled
end

function TextAcceleration(frame) --Overfit distance profile for difference text slide in
	frame = frame - 14
	if frame > 0 then
		return 0
	end
	return -(15.1 / (13 * 13)) * frame * frame
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
mod:AddCallback(ModCallbacks.MC_POST_RENDER, mod.onRender)

--mod:AddCallback(ModCallbacks.MC_USE_ITEM, mod.rKeyCheck, CollectibleType.COLLECTIBLE_R_KEY)

--Custom Shader Fix by AgentCucco
mod:AddCallback(ModCallbacks.MC_POST_PLAYER_INIT, function()
	if #Isaac.FindByType(EntityType.ENTITY_PLAYER) == 0 then
		Isaac.ExecuteCommand("reloadshaders")
	end
end)