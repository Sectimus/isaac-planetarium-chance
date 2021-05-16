local mod = RegisterMod("Planetarium Chance Display", 1)

local function onRender(self, t)
    self:updatePlanetariumChance();

    --planetariumChance = [1, 21 ] --Index for stage is stage-1
end

function mod:updatePlanetariumChance()
    local game = Game();
    local level = game:GetLevel();
    local treasurerooms_visited = game:GetTreasureRoomVisitCount();
    local stage = level:GetStage();

    --Planetariums can also not normally be encountered after Depths II, though Telescope Lens allows them to appear in  Womb and  Corpse.
    if stage <= LevelStage.STAGE3_2 or (stage > LevelStage.STAGE3_2 and stage < LevelStage.STAGE5) then --Before Womb or Between Womb/Utero with Telescope Lens
        local game = Game();
        local level = game:GetLevel();
        local stage = level:GetStage();
        self.currentFloorSpawnChance = 1+(100*(0.2 * (stage - skippedRooms() -1))); --chance before items

        --items
        if Isaac.GetPlayer():HasCollectible(CollectibleType.COLLECTIBLE_MAGIC_8_BALL) then
            self.currentFloorSpawnChance = self.currentFloorSpawnChance + 15;
        end
        if Isaac.GetPlayer():HasCollectible(CollectibleType.COLLECTIBLE_CRYSTAL_BALL) then
            self.currentFloorSpawnChance = self.currentFloorSpawnChance + 15;
            
            --TODO The Crystal Ball bonus is 100% if a Treasure Room has been skipped
        end
        if Isaac.GetPlayer():HasTrinket(TrinketType.TRINKET_TELESCOPE_LENS) then
            self.currentFloorSpawnChance = self.currentFloorSpawnChance + 9;

            --TODO If Isaac enters a Planetarium, the chance will be set to 1% and can be increased only with a Telescope Lens, by 15%.
            --TODO Planetariums can also not normally be encountered after Depths Depths II, though Telescope Lens allows them to appear in Womb and Corpse.
        end

    elseif stage > LevelStage.STAGE3_2 and not Isaac.GetPlayer():HasTrinket(TrinketType.TRINKET_TELESCOPE_LENS) then --After depths2 and no Telescope Lens
        self.currentFloorSpawnChance = 0;
    end

    

    --Planetarium chance can never be less than 1% or more than 100%.
    if self.currentFloorSpawnChance<1 then
        self.currentFloorSpawnChance = 1;
    elseif self.currentFloorSpawnChance>100 then
        self.currentFloorSpawnChance = 100;
    end

    
    Isaac.RenderText(string.format( "%.1f%%", self.currentFloorSpawnChance ), 50, 60, 1, 1, 1, 255);

    
end

-- Returns the amount of skipped treasure rooms (does not count the current floor room if it has not been entered yet)
function skippedRooms()
    local skippedTreasure = 0;
    local game = Game();
    local level = game:GetLevel();
    local treasurerooms_visited = game:GetTreasureRoomVisitCount();
    local stage = level:GetStage();

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

mod:AddCallback(ModCallbacks.MC_POST_RENDER, onRender);
mod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, test)