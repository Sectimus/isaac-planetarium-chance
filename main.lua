local mod = RegisterMod("Planetarium Chance Display", 1)

function mod:onRender()
    x = 21; 
    y = 197;
    local valueOutput = string.format("%.1s%%", "?")
    if self.currentFloorSpawnChance then
        valueOutput = string.format("%.1f%%", self.currentFloorSpawnChance)
    end

    self.Font:DrawString(valueOutput, x+16, y, KColor(1,1,1,0.45),0,true)
    self.HudSprite:Render(Vector(x,y), Vector(0,0), Vector(0,0))

    --green popup
    if self.Fontalpha and self.Fontalpha>0 then
        local alpha = self.Fontalpha
        if self.Fontalpha > 0.45 then
            alpha = 0.45
        end
        local difference = self.currentFloorSpawnChance - self.previousFloorSpawnChance;
        local differenceOutput = string.format("%.1f%%", difference)
        if difference>0 then --positive difference
            self.Font:DrawString("+"..differenceOutput, x+16+self.Font:GetStringWidth(differenceOutput)+3, y, KColor(0,1,0,alpha),0,true)
        elseif difference<0 then --negative difference
            self.Font:DrawString(differenceOutput, x+16+self.Font:GetStringWidth(differenceOutput)+3, y, KColor(1,0,0,alpha),0,true)
        end
        self.Fontalpha = self.Fontalpha-0.01
    end
end

function mod:init(continued)
    if not continued then
        self.currentFloorSpawnChance = nil
        self.visited = false
    end

    self.HudSprite = Sprite()
    self.HudSprite:Load("gfx/ui/hudstats2.anm2", true)
    self.HudSprite.Color = Color(1,1,1,0.45);
    self.HudSprite:SetFrame("Idle", 8)
    self.Font = Font();
    self.Font:Load("font/luaminioutlined.fnt")

    self:updatePlanetariumChance();
end

-- update on level transition
function mod:updatePlanetariumChance()
    self.previousFloorSpawnChance = self.currentFloorSpawnChance
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
        self.currentFloorSpawnChance = 1+(100*(0.2 * treasureSkips)); --chance before items

        --items
        if Isaac.GetPlayer():HasCollectible(CollectibleType.COLLECTIBLE_MAGIC_8_BALL) then
            self.currentFloorSpawnChance = self.currentFloorSpawnChance + 15;
        end
        if Isaac.GetPlayer():HasCollectible(CollectibleType.COLLECTIBLE_CRYSTAL_BALL) then
            self.currentFloorSpawnChance = self.currentFloorSpawnChance + 15;
            -- if treasureSkips > 0 then --The Crystal Ball bonus is 100% if a Treasure Room has been skipped (THIS IS FALSE)
            --     self.currentFloorSpawnChance = 100;
            -- end
        end
        if Isaac.GetPlayer():HasTrinket(TrinketType.TRINKET_TELESCOPE_LENS) then
            self.currentFloorSpawnChance = self.currentFloorSpawnChance + 9;
        end

        --visited already
        if self.visited then
            self.currentFloorSpawnChance = 1
            if Isaac.GetPlayer():HasTrinket(TrinketType.TRINKET_TELESCOPE_LENS) then
                --If Isaac enters a Planetarium, the chance will be set to 1% and can be increased only with a Telescope Lens, by 15%.
                self.currentFloorSpawnChance = 15
            end
        end


    elseif stage > LevelStage.STAGE3_2 and not Isaac.GetPlayer():HasTrinket(TrinketType.TRINKET_TELESCOPE_LENS) then --After depths2 and no Telescope Lens
        self.currentFloorSpawnChance = 0;
    end

    --Planetarium chance can never be more than 100%.
    if self.currentFloorSpawnChance>100 then
        self.currentFloorSpawnChance = 100;
    end

    --don't display popup if there is no change
    if self.previousFloorSpawnChance and (self.currentFloorSpawnChance - self.previousFloorSpawnChance ) then
        self.Fontalpha = 3
    end
end

function mod:checkForPlanetarium()
    local room = Game():GetRoom();
    if(room:GetType() == RoomType.ROOM_PLANETARIUM) then
        self.visited = true;
    end
end

-- Returns the amount of skipped treasure rooms (does not count the current floor room if it has not been entered yet)
function skippedRooms()
    local skippedTreasure = 0;
    local game = Game();
    local level = game:GetLevel();
    local treasurerooms_visited = game:GetTreasureRoomVisitCount();
    local stage = level:GetStage();

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


---------------------------------------------------------------------------------------------------------

-- Custom Log Command
function log(text)
    Isaac.DebugString(tostring(text))
end

local function test()

end

mod:AddCallback(ModCallbacks.MC_POST_NEW_LEVEL, mod.updatePlanetariumChance);
mod:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, mod.checkForPlanetarium);

mod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, mod.init);

mod:AddCallback(ModCallbacks.MC_POST_RENDER, mod.onRender);
mod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, test)