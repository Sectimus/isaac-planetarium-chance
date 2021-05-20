local json = require("json")
local mod = RegisterMod("Planetarium Chance", 1)

mod.initialized=false;

function mod:onRender()
    if mod:shouldDeHook() then return end
    x = self.coordx; 
    y = self.coordy;
    local valueOutput = string.format("%.1s%%", "?")
    if self.storage.currentFloorSpawnChance then
        valueOutput = string.format("%.1f%%", self.storage.currentFloorSpawnChance)
    else
        mod:updatePlanetariumChance();
    end

    self.font:DrawString(valueOutput, x+16, y, KColor(1,1,1,0.45),0,true)
    self.hudSprite:Render(Vector(x,y), Vector(0,0), Vector(0,0))

    --differential popup
    if self.fontalpha and self.fontalpha>0 then
        local alpha = self.fontalpha
        if self.fontalpha > 0.45 then
            alpha = 0.45
        end
        if self.storage.previousFloorSpawnChance == nil then 
            self.storage.previousFloorSpawnChance = self.storage.currentFloorSpawnChance
        end
        local difference = self.storage.currentFloorSpawnChance - self.storage.previousFloorSpawnChance;
        local differenceOutput = string.format("%.1f%%", difference)
        if difference>0 then --positive difference
            self.font:DrawString("+"..differenceOutput, x+16+self.font:GetStringWidth(valueOutput)+3, y, KColor(0,1,0,alpha),0,true)
        elseif difference<0 then --negative difference
            self.font:DrawString(differenceOutput, x+16+self.font:GetStringWidth(valueOutput)+3, y, KColor(1,0,0,alpha),0,true)
        end
        self.fontalpha = self.fontalpha-0.01
    end
end

function mod:exit()
    if mod:shouldDeHook() then return end
    if self.storage then
        mod:SaveData(json.encode(self.storage))
    end
    --TODO cleanup sprite
end

function mod:init(continued)
    if not continued then
        self.storage.currentFloorSpawnChance = nil
        self.storage.visited = false
        --backup the notches
        if(mod:HasData()) then
            local tempstorage = json.decode(mod:LoadData())
            mod:RemoveData()
            self.storage.notches = tempstorage.notches
            mod:SaveData(json.encode(self.storage))
        end
        self:updatePlanetariumChance();
    elseif(mod:HasData()) then
        self.storage = json.decode(mod:LoadData())
    end

    --check char
    self:updateCheck();
    self:updatePosition();

    self.hudSprite = Sprite()
    self.hudSprite:Load("gfx/ui/hudstats2.anm2", true)
    self.hudSprite.Color = Color(1,1,1,0.45);
    self.hudSprite:SetFrame("Idle", 8)
    self.font = Font();
    self.font:Load("font/luaminioutlined.fnt")

    self.initialized = true;
end

-- update on level transition
function mod:updatePlanetariumChance()
    if mod:shouldDeHook() then return end
 
    self.storage.previousFloorSpawnChance = self.storage.currentFloorSpawnChance
    local game = Game();
    local level = game:GetLevel();
    local stage = level:GetStage();
    --Planetariums can also not normally be encountered after Depths II, though Telescope Lens allows them to appear in  Womb and  Corpse.
    if (stage <= LevelStage.STAGE3_2) or (stage > LevelStage.STAGE3_2 and stage < LevelStage.STAGE5 and Isaac.GetPlayer():HasTrinket(TrinketType.TRINKET_TELESCOPE_LENS)) then --Before Womb or Between Womb/Utero with Telescope Lens
        local treasureSkips = skippedRooms();
        -- log("----")
        -- log(stage)
        -- log(treasureSkips)
        -- log("----")
        self.storage.currentFloorSpawnChance = 1+(100*(0.2 * treasureSkips)); --chance before items

        --items
        if Isaac.GetPlayer():HasTrinket(TrinketType.TRINKET_TELESCOPE_LENS) then
            self.storage.currentFloorSpawnChance = self.storage.currentFloorSpawnChance + 9;
        end
        if Isaac.GetPlayer():HasCollectible(CollectibleType.COLLECTIBLE_MAGIC_8_BALL) then
            self.storage.currentFloorSpawnChance = self.storage.currentFloorSpawnChance + 15;
        end
        if Isaac.GetPlayer():HasCollectible(CollectibleType.COLLECTIBLE_CRYSTAL_BALL) then
            self.storage.currentFloorSpawnChance = self.storage.currentFloorSpawnChance + 15;
            if treasureSkips > 0 then --The Crystal Ball bonus is 100% if a Treasure Room has been skipped
                self.storage.currentFloorSpawnChance = 100;
            end
        end

        --visited already
        if self.storage.visited then
            self.storage.currentFloorSpawnChance = 1
            if Isaac.GetPlayer():HasTrinket(TrinketType.TRINKET_TELESCOPE_LENS) then
                --If Isaac enters a Planetarium, the chance will be set to 1% and can be increased only with a Telescope Lens, by 15%.
                self.storage.currentFloorSpawnChance = 15
            end
        end


    elseif stage > LevelStage.STAGE3_2 and not Isaac.GetPlayer():HasTrinket(TrinketType.TRINKET_TELESCOPE_LENS) then --After depths2 and no Telescope Lens
        self.storage.currentFloorSpawnChance = 0;
    end

    --Planetarium chance can never be more than 100%. (technically 99.9% as there is never a 100% guarantee)
    if self.storage.currentFloorSpawnChance>99.9 then
        self.storage.currentFloorSpawnChance = 99.9;
    elseif self.storage.currentFloorSpawnChance<0 then 
        self.storage.currentFloorSpawnChance = 0;
    end

    --don't display popup if there is no change
    if self.storage.previousFloorSpawnChance and (self.storage.currentFloorSpawnChance - self.storage.previousFloorSpawnChance ) then
        self.fontalpha = 3
    end
end

function mod:checkForPlanetarium()
    if mod:shouldDeHook() then return end
    local room = Game():GetRoom();
    if(room:GetType() == RoomType.ROOM_PLANETARIUM) then
        self.storage.visited = true;
    end
end

-- Returns the amount of skipped treasure rooms (does not count the current floor room if it has not been entered yet)
function skippedRooms()
    if mod:shouldDeHook() then return end
    local skippedTreasure = 0;
    local game = Game();
    local level = game:GetLevel();
    local treasurerooms_visited = game:GetTreasureRoomVisitCount();
    local stage = level:GetStage();
    --check for stagetype of C or D
    local variant = Game():GetLevel():GetStageType();
    if variant == 3 or variant == 4 then stage = stage+1 end


    --Gotta handle those XL floors somehow!!! >:(
    if(level:GetCurses() == LevelCurse.CURSE_OF_LABYRINTH) then stage = stage+1 end

    skippedTreasure = stage - treasurerooms_visited;

    local rooms = level:GetRooms();
    for i = 0, #rooms-1 do
        if rooms:Get(i).Data.Type == RoomType.ROOM_TREASURE then
            if rooms:Get(i).VisitedCount == 0 then
                --Room was NOT entered on this floor YET
                skippedTreasure = skippedTreasure -1
            end
        end
    end
    return skippedTreasure;
end

function mod:shouldDeHook()

    local reqs = {
        Game().Difficulty == Difficulty.DIFFICULTY_GREED,
        Game().Difficulty == Difficulty.DIFFICULTY_GREEDIER,
        Game():GetLevel():GetStage() > LevelStage.STAGE7,
        not self.initialized,
        Isaac.GetPlayer():HasCollectible(CollectibleType.COLLECTIBLE_DADS_NOTE)
    }

    return reqs[1] or reqs[2] or reqs[3] or reqs[4] or reqs[5]
end

--This callback is called 30 times per second. It will not be called, when its paused (for example on screentransitions or on the pause menu).
--Base coords are set here, they will be modified by hudoffset on another callback
--Multi stat display for coop only shows 2 lots of stats
function mod:updatePosition(notches)
    notches = notches or self.storage.notches or 11 --default to ingame default of 11
    self.coordx = 1;
    self.coordy = 184;
    --check for char differences (any player is a char with a different offset)

    for i = 1, #self.storage.character do
        if self.storage.character[i] == PlayerType.PLAYER_BETHANY or self.storage.character[i] == PlayerType.PLAYER_BETHANY_B then 
            self.coordy = self.coordy+12;
            break;
        elseif self.storage.character[i] == PlayerType.PLAYER_ESAU or self.storage.character[i] == PlayerType.PLAYER_JACOB then
            self.coordy = self.coordy+12;
            break;
        end
    end
    --two sets of stats are displayed on multiplayer
    if #self.storage.character > 1 then
        self.coordy = self.coordy+15;
    end

    if Isaac.GetPlayer():HasCollectible(CollectibleType.COLLECTIBLE_DUALITY) then
        self.coordy = self.coordy-10;
    end

    self.coordx, self.coordy = self:hudoffset(notches, self.coordx, self.coordy, "topleft");
end

--checks if char has been changed
function mod:updateCheck()
    local updatePos = false;
    if self.storage.character == nil or self.storage.character == 0 then self.storage.character = {} end

    local activePlayers = Game():GetNumPlayers()
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

    --duality can move the icon
    if(Isaac.GetPlayer():HasCollectible(CollectibleType.COLLECTIBLE_DUALITY)) then updatePos = true; end

    if updatePos then
        self:updatePosition();
    end
end

--[[
  @param {int} notches - the number of notches filled in on hud offset (default ingame is between 0-11)
  @param {float} x - original x coordinate
  @param {float} y - original y coordinate
  @param {string} anchor - the anchoring position of the element: "topleft", "topright", "bottomleft", "bottomright" IE. stats are "topleft", minimap is "topright"
]]
function mod:hudoffset(notches, x, y, anchor)
    local xoffset = (notches*2)
    local yoffset = ((1/8)*(10*notches+(-1)^notches+7))
    if anchor == "topleft" then
        xoffset = x+xoffset
        yoffset = y+yoffset
    elseif anchor == "topright" then
        xoffset = x-xoffset
        yoffset = y+yoffset
    elseif anchor == "bottomleft" then
        xoffset = x+xoffset
        yoffset = y-yoffset
    elseif anchor == "bottomright" then
        xoffset = x-xoffset
        yoffset = y-yoffset
    else
        error("invalid anchor provided. Must be one of: \"topleft\", \"topright\", \"bottomleft\", \"bottomright\"", 2)
    end
    -- log(xoffset)
    -- log(yoffset)
    return xoffset, yoffset
end
---------------------------------------------------------------------------------------------------------

-- Custom Log Command
function log(text)
    Isaac.DebugString(tostring(text))
end

function mod:keyboardCheck()
    if Input.IsButtonTriggered(Keyboard.KEY_K, 0) and Game():IsPaused() then
        if not self.storage.notches then
            self.storage.notches = 11
        else
            if self.storage.notches <= 0 then return end
            self.storage.notches = self.storage.notches -1
        end
        self:updatePosition()
    elseif Input.IsButtonTriggered(Keyboard.KEY_L, 0) and Game():IsPaused() then
        if not self.storage.notches then
            self.storage.notches = 11
        else
            if self.storage.notches >= 10 then return end
            self.storage.notches = self.storage.notches +1
        end
        self:updatePosition()
    end
end

--init self storage from mod namespace before any callbacks by blocking.
function mod:initStore()
    self.storage = {} 
    self.coordx = 21;
    self.coordy = 197.5
end
mod:initStore();

mod:AddCallback(ModCallbacks.MC_POST_NEW_LEVEL, mod.updatePlanetariumChance);
mod:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, mod.checkForPlanetarium);

mod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, mod.init);
mod:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, mod.exit);

mod:AddCallback(ModCallbacks.MC_POST_RENDER, mod.onRender);
--mod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, mod.test)

--update used to check for a char change (could use clicker? outside of render)
mod:AddCallback(ModCallbacks.MC_POST_UPDATE, mod.updateCheck)

--keyboard check for HUD scale changes
mod:AddCallback(ModCallbacks.MC_POST_RENDER, mod.keyboardCheck)
