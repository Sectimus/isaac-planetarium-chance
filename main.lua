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
    self.planetariumChance = 1+(100*(0.2 * (stage - treasurerooms_visited -1))); --chance before items

    --items
    if Isaac.GetPlayer():HasCollectible(CollectibleType.COLLECTIBLE_MAGIC_8_BALL) then
        self.planetariumChance = self.planetariumChance + 15;
    end
    if Isaac.GetPlayer():HasCollectible(CollectibleType.COLLECTIBLE_CRYSTAL_BALL) then
        self.planetariumChance = self.planetariumChance + 15;
        
        --TODO The Crystal Ball bonus is 100% if a Treasure Room has been skipped
    end
    if Isaac.GetPlayer():HasTrinket(TrinketType.TRINKET_TELESCOPE_LENS) then
        self.planetariumChance = self.planetariumChance + 9;

        --TODO If Isaac enters a Planetarium, the chance will be set to 1% and can be increased only with a Telescope Lens, by 15%.
        --TODO Planetariums can also not normally be encountered after Depths Depths II, though Telescope Lens allows them to appear in Womb and Corpse.
    end

    

    --Planetarium chance can never be less than 1% or more than 100%.
    if self.planetariumChance<1 then
        self.planetariumChance = 1;
    elseif self.planetariumChance>100 then
        self.planetariumChance = 100;
    end

    Isaac.RenderText(tostring(self.planetariumChance), 50, 60, 1, 1, 1, 255);
end

mod:AddCallback(ModCallbacks.MC_POST_RENDER, onRender);