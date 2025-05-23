-- EzMage - A mage-specific addon for tracking procs and cooldowns

-- Create initialization frame first
local initFrame = CreateFrame("Frame", "EzMageInitFrame", UIParent)
initFrame:RegisterEvent("VARIABLES_LOADED")

-- Create main frame
local EzMage = CreateFrame("Frame", "EzMageFrame", UIParent)
EzMage:Hide() -- Hide initially until we're ready
EzMage.isInitialized = false -- Track initialization state
EzMage.icons = {} -- Initialize icons table

-- Create update frame for periodic updates
local updateFrame = CreateFrame("Frame", "EzMageUpdateFrame", UIParent)
updateFrame:Show()
updateFrame.UPDATE_INTERVAL = 0.1 -- Update every 0.1 seconds

-- Create aura frame for buff-based procs
local auraFrame = CreateFrame("Frame", "EzMageAuraFrame", UIParent)
auraFrame:Hide()

-- Create action frame for action-based procs and abilities
local actionFrame = CreateFrame("Frame", "EzMageActionFrame", UIParent)
actionFrame:Hide()

-- Create timer frame for buff duration tracking
local timerFrame = CreateFrame("Frame", "EzMageTimerFrame", UIParent)
timerFrame:Show()

-- Table to track active buffs and their durations
local activeBuffs = {}

-- Add this near the top with other tables
local availableSpells = {}
local isTestMode = false

-- Make main frame globally accessible
EzMageFrame = EzMage

-- Register only PLAYER_LOGIN initially
EzMage:RegisterEvent("PLAYER_LOGIN")

-- Function to get spell ID by name
local function GetSpellIDByName(spellName)
    local spellID = 0
    for i = 1, 1000 do
        local name, rank = GetSpellName(i, "spell")
        if name and name == spellName then
            spellID = i
            break
        end
    end
    if spellID == 0 then
        DEFAULT_CHAT_FRAME:AddMessage("EzMage: Could not find spell ID for " .. spellName, 1.0, 0.0, 0.0)
    end
    return spellID
end

-- Helper function to find an action slot by texture
local function FindActionSlotByTexture(texture)
    for i = 1, 120 do
        local actionTexture = GetActionTexture(i)
        if actionTexture and actionTexture == texture then
            return i
        end
    end
    return nil
end

-- Format time for display
local function FormatTimeText(remaining)
    if remaining >= 60 then
        return format("%d:%02d", floor(remaining/60), floor(math.mod(remaining, 60)))
    elseif remaining >= 10 then
        return format("%d", floor(remaining))
    else
        return format("%.1f", remaining)
    end
end

-- Update buff timer display
local function UpdateBuffTimer(buffName, remaining)
    local buffData = activeBuffs[buffName]
    if not buffData then return end
    for _, icon in ipairs(EzMage.icons) do
        if icon.ability.name == buffName then
            icon.activeTimer:SetText(FormatTimeText(remaining))
            break
        end
    end
end

-- Handle buff expiration
local function HandleBuffExpiration(buffName)
    local buffData = activeBuffs[buffName]
    if not buffData then return end
    
    -- Clear buff data
    activeBuffs[buffName] = nil
    
    -- Update icon display
    for _, icon in ipairs(EzMage.icons) do
        if icon.ability.name == buffName then
            icon.activeTimer:SetText("")
            icon:Hide()
            icon.glow:SetAlpha(0)
            break
        end
    end
end

-- Update or create buff entry
local function UpdateBuffEntry(ability, buffIndex, duration)
    local currentTime = GetTime()
    -- If buff already exists, log its current state
    if activeBuffs[ability.name] then
        local oldBuff = activeBuffs[ability.name]
    end
    
    activeBuffs[ability.name] = {
        index = buffIndex,
        duration = duration,
        startTime = currentTime,
        expirationTime = currentTime + duration,
        ability = ability
    }
end

timerFrame:SetScript("OnUpdate", function()
    local currentTime = GetTime()
        local buffName, buffData = next(activeBuffs, nil)
        while buffName do
            if buffData.expirationTime then
                local remaining = buffData.expirationTime - currentTime
                if remaining > 0 then
                    UpdateBuffTimer(buffName, remaining)
                else
                    HandleBuffExpiration(buffName)
                end
            end
            buffName, buffData = next(activeBuffs, buffName)
        end
end)

-- Check buff-based procs
function auraFrame:CheckProcs()
    if isTestMode then return end
    
    for _, icon in ipairs(EzMage.icons) do
        local ability = icon.ability
        if ability.isProc and not ability.isActionBased then
            local found = false
            local currentBuffIndex = -1
            
            -- First check if we already have this buff tracked
            if activeBuffs[ability.name] then
                currentBuffIndex = activeBuffs[ability.name].index
                -- Verify the buff is still active, checking both helpful and harmful
                local buffIndex = GetPlayerBuff(currentBuffIndex, "HELPFUL")
                if buffIndex < 0 then
                    buffIndex = GetPlayerBuff(currentBuffIndex, "HARMFUL")
                end
                if buffIndex >= 0 then
                    local buffTexture = GetPlayerBuffTexture(buffIndex)
                    if buffTexture == ability.texture then
                        found = true
                    end
                end
            end
            
            -- If not found in active buffs, check all buffs
            if not found then
                -- Check helpful buffs first
                for i = 0, 31 do
                    local buffIndex = GetPlayerBuff(i, "HELPFUL")
                    if buffIndex >= 0 then
                        local buffTexture = GetPlayerBuffTexture(buffIndex)
                        local altMatches = false
                        
                        if ability.alternateTextures then
                            for _, altTexture in ipairs(ability.alternateTextures) do
                                if buffTexture == altTexture then
                                    altMatches = true
                                    break
                                end
                            end
                        end
                        
                        if buffTexture == ability.texture or altMatches then
                            found = true
                            currentBuffIndex = buffIndex
                            local duration = GetPlayerBuffTimeLeft(buffIndex)
                            
                            -- Update buff tracking
                            if duration and duration > 0 then
                                UpdateBuffEntry(ability, buffIndex, duration)
                            end
                            break
                        end
                    end
                end
                
                -- If not found in helpful buffs, check harmful buffs
                if not found then
                    for i = 0, 31 do
                        local buffIndex = GetPlayerBuff(i, "HARMFUL")
                        if buffIndex >= 0 then
                            local buffTexture = GetPlayerBuffTexture(buffIndex)
                            local altMatches = false
                            
                            if ability.alternateTextures then
                                for _, altTexture in ipairs(ability.alternateTextures) do
                                    if buffTexture == altTexture then
                                        altMatches = true
                                        break
                                    end
                                end
                            end
                            
                            if buffTexture == ability.texture or altMatches then
                                found = true
                                currentBuffIndex = buffIndex
                                local duration = GetPlayerBuffTimeLeft(buffIndex)
                                
                                -- Update buff tracking
                                if duration and duration > 0 then
                                    UpdateBuffEntry(ability, buffIndex, duration)
                                end
                                break
                            end
                        end
                    end
                end
            end
            
            -- Update icon visibility
            if found then
                icon:Show()
                icon.glow:SetAlpha(1)
            else
                -- If buff not found and was previously tracked, handle expiration
                if activeBuffs[ability.name] then
                    HandleBuffExpiration(ability.name)
                else
                    icon:Hide()
                    icon.glow:SetAlpha(0)
                    icon.activeTimer:SetText("")
                end
            end
        end
    end
end

-- Check action-based procs
function actionFrame:CheckActionProcs()
    if isTestMode then return end
    
    for _, icon in ipairs(EzMage.icons) do
        local ability = icon.ability
        if ability.isProc and ability.isActionBased then
            local slot = FindActionSlotByTexture(ability.texture)
            if slot then
                local usable = IsUsableAction(slot)
                if usable then
                    icon:Show()
                    icon.glow:SetAlpha(1)
                else
                    icon:Hide()
                    icon.glow:SetAlpha(0)
                end
            else
                icon:Hide()
                icon.glow:SetAlpha(0)
            end
        end
    end
end

-- Define abilities to track
local abilities = {
    {
        name = "Arcane Power",
        texture = "Interface\\Icons\\Spell_Nature_Lightning",
        icon = "Interface\\Icons\\Spell_Nature_Lightning",
        isProc = false,
        hasDuration = true
    },
    {
        name = "Presence of Mind",
        texture = "Interface\\Icons\\Spell_Nature_EnchantArmor",
        icon = "Interface\\Icons\\Spell_Nature_EnchantArmor",
        isProc = false,
        hasDuration = false
    },
    {
        name = "Temporal Convergence",
        texture = "Interface\\Icons\\Spell_Nature_StormReach",
        icon = "Interface\\Icons\\Spell_Nature_StormReach",
        isProc = true,
        hasDuration = true
    },
    {
        name = "Arcane Rupture",
        texture = "Interface\\Icons\\Spell_Arcane_Blast",
        icon = "Interface\\Icons\\Spell_Arcane_Blast",
        isProc = true,
        hasDuration = true
    },
    {
        name = "Arcane Surge",
        texture = "Interface\\Icons\\INV_Enchant_EssenceMysticalLarge",
        icon = "Interface\\Icons\\INV_Enchant_EssenceMysticalLarge",
        isProc = true,
        isActionBased = true,
        hasDuration = false
    },
    {
        name = "Clearcasting",
        texture = "Interface\\Icons\\Spell_Shadow_ManaBurn",
        icon = "Interface\\Icons\\Spell_Shadow_ManaBurn",
        isProc = true,
        hasDuration = true
    },
    {
        name = "Combustion",
        texture = "Interface\\Icons\\Spell_Fire_SealOfFire",
        icon = "Interface\\Icons\\Spell_Fire_SealOfFire",
        isProc = false,
        hasDuration = false
    },
    {
        name = "Flash Freeze",
        texture = "Interface\\Icons\\Spell_Fire_FrostResistanceTotem",
        icon = "Interface\\Icons\\Spell_Fire_FrostResistanceTotem",
        isProc = true,
        hasDuration = true
    },
    {
        name = "Cold Snap",
        texture = "Interface\\Icons\\Spell_Frost_WizardMark",
        icon = "Interface\\Icons\\Spell_Frost_WizardMark",
        isProc = false,
        hasDuration = false
    },
    {
        name = "Ice Block",
        texture = "Interface\\Icons\\Spell_Frost_Frost",
        icon = "Interface\\Icons\\Spell_Frost_Frost",
        isProc = false,
        hasDuration = true
    },
    {
        name = "Ice Barrier",
        texture = "Interface\\Icons\\Spell_Ice_Lament",
        icon = "Interface\\Icons\\Spell_Ice_Lament",
        isProc = false,
        hasDuration = true
    },
    {
        name = "Mage Armor",
        texture = "Interface\\Icons\\Spell_MageArmor",
        icon = "Interface\\Icons\\Spell_MageArmor",
        isProc = false,
        hasDuration = true
    },
    {
        name = "Arcane Intellect",
        texture = "Interface\\Icons\\Spell_Holy_MagicalSentry",
        icon = "Interface\\Icons\\Spell_Holy_MagicalSentry",
        isProc = false,
        hasDuration = true,
        alternateTextures = {"Interface\\Icons\\Spell_Holy_ArcaneIntellect"}
    },
    {
        name = "Blood Fury",
        texture = "Interface\\Icons\\Racial_Orc_BerserkerStrength",
        icon = "Interface\\Icons\\Racial_Orc_BerserkerStrength",
        isProc = false,
        hasDuration = true,
        race = "Orc"
    },
    {
        name = "Netherwind Focus",
        texture = "Interface\\Icons\\Spell_Shadow_Teleport",
        icon = "Interface\\Icons\\Spell_Shadow_Teleport",
        isProc = true,
        hasDuration = true
    }
}

-- Function to check spellbook availability
local function UpdateAvailableSpells()
    -- Reset all spells to unavailable first
    for _, ability in ipairs(abilities) do
        availableSpells[ability.name] = false
    end
    
    -- Check each spell in the spellbook
    for i = 1, 1000 do
        local name, rank = GetSpellName(i, "spell")
        if name then
            -- Check if this spell is in our abilities list
            for _, ability in ipairs(abilities) do
                if name == ability.name then
                    -- For non-proc, non-action-based abilities, mark as available
                    if not ability.isProc and not ability.isActionBased then
                        availableSpells[ability.name] = true
                    end
                    break
                end
            end
        end
    end
end

-- Function to resize EzMage frame based on available spells
local function ResizeEzMageFrame()
    local iconSize = 32
    local iconSpacing = 3  -- Space between icons
    local edgePadding = 5  -- Padding on left and right edges
    local topPadding = 15   -- Padding at top for title
    local bottomPadding = 5 -- Padding at bottom for timers
    local rowSpacing = 5   -- Space between rows
    
    -- Count available spells
    local availableCount = 0
    for _, ability in ipairs(abilities) do
        if ability.isProc or ability.isActionBased or availableSpells[ability.name] then
            availableCount = availableCount + 1
        end
    end
    
    -- Calculate number of icons per row
    local iconsPerRow = math.ceil(availableCount / EzMageDB.rows)
    
    -- Calculate frame dimensions
    local totalWidth = edgePadding * 2 + (iconsPerRow * (iconSize + iconSpacing)) - iconSpacing
    local totalHeight = topPadding + (EzMageDB.rows * (iconSize + rowSpacing)) - rowSpacing + bottomPadding
    
    -- Set frame size
    EzMage:SetWidth(totalWidth)
    EzMage:SetHeight(totalHeight)
    
    -- Reposition icons
    local iconIndex = 1
    for i, ability in ipairs(abilities) do
        if ability.isProc or ability.isActionBased or availableSpells[ability.name] then
            local row = math.floor((iconIndex-1) / iconsPerRow)
            local col = math.mod(iconIndex-1, iconsPerRow)
            
            EzMage.icons[i]:ClearAllPoints()
            EzMage.icons[i]:SetPoint("TOPLEFT", EzMage, "TOPLEFT", 
                edgePadding + col * (iconSize + iconSpacing),
                -topPadding - row * (iconSize + rowSpacing))
            
            iconIndex = iconIndex + 1
        end
    end
end

-- Initialize function
function EzMage:Init()
    -- Set base size
    self:SetWidth(200)
    self:SetHeight(50)
    
    -- Set scale based on UIParent
    local uiScale = UIParent:GetScale()
    self:SetScale(1.0 / uiScale)
    
    self:SetFrameStrata("HIGH")
    self:SetFrameLevel(1)
    
    -- Load saved position or use default
    if EzMageDB and EzMageDB.position then
        self:ClearAllPoints()
        self:SetPoint("CENTER", UIParent, "CENTER", EzMageDB.position.x, EzMageDB.position.y)
    else
        self:ClearAllPoints()
        self:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
    
    self:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        tile = true,
        tileSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    
    -- Set background color based on lock state and hide background setting
    if EzMageDB.hideBackground then
        self:SetBackdropColor(0, 0, 0, 0)  -- Fully transparent background
    else
        if EzMageDB.isLocked then
            self:SetBackdropColor(0, 0, 0, 0.4)  -- Lighter background when locked
        else
            self:SetBackdropColor(0, 0, 0, 0.8)  -- Darker background when unlocked
        end
    end
    
    self:SetMovable(not EzMageDB.isLocked)
    self:EnableMouse(true)
    self:RegisterForDrag("LeftButton")
    self:SetScript("OnDragStart", function()
        if not EzMageDB.isLocked then
            this:StartMoving()
        end
    end)
    self:SetScript("OnDragStop", function()
        if not EzMageDB.isLocked then
            this:StopMovingOrSizing()
            local x, y = this:GetCenter()
            local scale = UIParent:GetEffectiveScale()
            local uiScale = UIParent:GetScale()
            EzMageDB.position = {
                x = (x * scale - UIParent:GetWidth() * uiScale / 2) / uiScale,
                y = (y * scale - UIParent:GetHeight() * uiScale / 2) / uiScale
            }
        end
    end)

    -- Create title
    local title = self:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", self, "TOP", 0, -5)
    title:SetText("EzMage")

end

-- Event handler for initialization frame
initFrame:SetScript("OnEvent", function()
    if event == "VARIABLES_LOADED" then
        
        -- Initialize database
        if not EzMageDB then
            EzMageDB = {}
        end
        if not EzMageDB.position then
            EzMageDB.position = {x = 0, y = 0}
        end
        if not EzMageDB.isLocked then
            EzMageDB.isLocked = false
        end
        if not EzMageDB.rows then
            EzMageDB.rows = 1
        end
        if not EzMageDB.hideBackground then
            EzMageDB.hideBackground = false
        end
        
        EzMage:Init()
        initFrame:UnregisterEvent("VARIABLES_LOADED")
    end
end)

-- Event handler for aura frame
auraFrame:SetScript("OnEvent", function()
    if event == "PLAYER_AURAS_CHANGED" then
        this:CheckProcs()
    end
end)

-- Event handler for action frame
actionFrame:SetScript("OnEvent", function()
    if event == "ACTIONBAR_UPDATE_USABLE" or 
       event == "ACTIONBAR_PAGE_CHANGED" or 
       event == "UPDATE_BONUS_ACTIONBAR" or 
       event == "PLAYER_TARGET_CHANGED" then
        this:CheckActionProcs()
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" and arg2 == "player" then
        local spellName = arg3
        for _, ability in ipairs(abilities) do
            if ability.isActionBased and spellName == ability.name then
                for _, icon in ipairs(EzMage.icons) do
                    if icon.ability == ability then
                        icon:Hide()
                        icon.glow:SetAlpha(0)
                        icon.cooldownTimer:SetText("")
                        icon.activeTimer:SetText("")
                        break
                    end
                end
            end
        end
    end
end)

-- Event handler for main frame
EzMage:SetScript("OnEvent", function()
    if event == "PLAYER_LOGIN" then
        if this.isInitialized then
            return -- Already initialized, ignore subsequent PLAYER_LOGIN events
        end
        
        -- Check if player is a mage
        local _, playerClass = UnitClass("player")
        
        if playerClass ~= "MAGE" then
            DEFAULT_CHAT_FRAME:AddMessage("EzMage: This addon is for mages only.", 1.0, 0.0, 0.0)
            return
        end
        
        -- Look up spell IDs for abilities that need it
        for _, ability in ipairs(abilities) do
            if ability.spellID == nil or ability.spellID == 0 then
                ability.spellID = GetSpellIDByName(ability.name)
            end
        end
        
        -- Update available spells
        UpdateAvailableSpells()
        
        -- Initialize addon for mage
        this:SetupUI()
        EzMage:UpdateAuras()
        this:UpdateCooldowns()
        
        -- Resize frame based on available spells
        ResizeEzMageFrame()
        
        -- Register events for aura frame
        auraFrame:RegisterEvent("PLAYER_AURAS_CHANGED")
        auraFrame:Show()
        
        -- Register events for action frame
        actionFrame:RegisterEvent("ACTIONBAR_UPDATE_USABLE")
        actionFrame:RegisterEvent("ACTIONBAR_PAGE_CHANGED")
        actionFrame:RegisterEvent("UPDATE_BONUS_ACTIONBAR")
        actionFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
        actionFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
        actionFrame:Show()
        
        -- Register cooldown update event
        this:RegisterEvent("SPELL_UPDATE_COOLDOWN")
        
        -- Register aura change event for non-proc buffs
        this:RegisterEvent("PLAYER_AURAS_CHANGED")
        this:RegisterEvent("UNIT_AURA")
        
        -- Register spell change event
        this:RegisterEvent("SPELLS_CHANGED")
        
        -- Mark as initialized and show
        this.isInitialized = true
        this:Show()
        DEFAULT_CHAT_FRAME:AddMessage("EzMage: Addon initialized and frame shown", 0.0, 1.0, 0.0)
        
        -- Unregister PLAYER_LOGIN after we're done with it
        this:UnregisterEvent("PLAYER_LOGIN")
    elseif event == "SPELL_UPDATE_COOLDOWN" then
        this:UpdateCooldowns()
        -- Check for buff durations when cooldowns update
        for _, ability in ipairs(abilities) do
            if not ability.isProc and not ability.isActionBased then
                -- Find the buff index for this ability
                for i = 0, 31 do
                    local buffIndex = GetPlayerBuff(i, "HELPFUL")
                    if buffIndex >= 0 then
                        local buffTexture = GetPlayerBuffTexture(buffIndex)
                        local altMatches = false
                        
                        if ability.alternateTextures then
                            for _, altTexture in ipairs(ability.alternateTextures) do
                                if buffTexture == altTexture then
                                    altMatches = true
                                    break
                                end
                            end
                        end
                        
                        if buffTexture == ability.texture or altMatches then
                            local duration = GetPlayerBuffTimeLeft(buffIndex)
                            if duration and duration > 0 then
                                UpdateBuffEntry(ability, buffIndex, duration)
                            end
                            break
                        end
                    end
                end
            end
        end
    elseif event == "PLAYER_AURAS_CHANGED" or (event == "UNIT_AURA" and arg1 == "player") then
        EzMage:UpdateAuras()
    elseif event == "SPELLS_CHANGED" then
        UpdateAvailableSpells()
        ResizeEzMageFrame()
        EzMage:UpdateAuras()
    end
end)

-- Update frame OnUpdate handler
updateFrame:SetScript("OnShow", function()
    this.startTime = GetTime()
end)

updateFrame:SetScript("OnUpdate", function()
    if isTestMode then return end  -- Skip updates during test mode
    
    if not this.startTime then this.startTime = GetTime() end
    local plus = this.UPDATE_INTERVAL
    local gt = GetTime() * 1000
    local st = (this.startTime + plus) * 1000
    if gt >= st then
        this.startTime = GetTime()
        if EzMage.isInitialized then
            EzMage:UpdateAuras()
            EzMage:UpdateCooldowns()
        end
    end
end)

-- Remove the old OnUpdate handler from EzMage frame
EzMage:SetScript("OnUpdate", nil)

-- Create ability icons
function EzMage:CreateAbilityIcon(ability, index)
    local icon = CreateFrame("Button", "EzMageIcon"..index, self)
    icon:SetWidth(32)
    icon:SetHeight(32)
    icon:SetPoint("LEFT", self, "LEFT", 5 + (index-1)*35, 0)
    
    -- Create icon texture
    local texture = icon:CreateTexture(nil, "BACKGROUND")
    texture:SetAllPoints()
    texture:SetTexture(ability.icon)
    
    -- Create cooldown frame
    local cooldown = CreateFrame("Frame", nil, icon)
    cooldown:SetAllPoints()
    cooldown:SetFrameLevel(icon:GetFrameLevel() + 1)
    
    -- Create cooldown texture
    local cooldownTexture = cooldown:CreateTexture(nil, "OVERLAY")
    cooldownTexture:SetAllPoints()
    cooldownTexture:SetTexture("Interface\\Cooldown\\UI-Cooldown-Indicator")
    cooldownTexture:SetTexCoord(0, 1, 0, 1)
    cooldownTexture:Hide()
    
    -- Create cooldown text
    local cooldownText = cooldown:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    cooldownText:SetPoint("CENTER", cooldown, "CENTER", 0, 0)
    cooldownText:Hide()
    
    -- Create glow frame
    local glow = icon:CreateTexture(nil, "OVERLAY")
    glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    glow:SetBlendMode("ADD")
    glow:SetAlpha(0)
    glow:SetPoint("CENTER", icon, "CENTER", 0, 0)
    glow:SetWidth(50)
    glow:SetHeight(50)
    glow:SetVertexColor(0.5, 0.8, 1.0)
    glow:SetTexCoord(0, 1, 0, 1)  -- Ensure full texture is shown
    
    -- Create cooldown timer text
    local cooldownTimer = icon:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    cooldownTimer:SetPoint("BOTTOM", icon, "BOTTOM", 0, -2)
    cooldownTimer:SetText("")
    
    -- Create active timer text
    local activeTimer = icon:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    activeTimer:SetPoint("TOP", icon, "TOP", 0, 2)
    activeTimer:SetText("")
    
    icon.texture = texture
    icon.cooldown = cooldown
    icon.glow = glow
    icon.cooldownTimer = cooldownTimer
    icon.activeTimer = activeTimer
    icon.ability = ability
    
    cooldown.texture = cooldownTexture
    cooldown.text = cooldownText
    
    return icon
end

-- Setup UI elements
function EzMage:SetupUI()
    self.icons = {}
    
    local iconSize = 32
    local iconSpacing = 3  -- Space between icons
    local edgePadding = 5  -- Padding on left and right edges
    local topPadding = 15   -- Padding at top for title
    local bottomPadding = 5 -- Padding at bottom for timers
    local rowSpacing = 5   -- Space between rows
    
    -- Calculate number of icons per row
    local totalIcons = table.getn(abilities)
    local iconsPerRow = math.ceil(totalIcons / EzMageDB.rows)
    
    -- Create icons with row-based positioning
    for i, ability in ipairs(abilities) do
        local row = math.floor((i-1) / iconsPerRow)
        local col = math.mod(i-1, iconsPerRow)
        
        self.icons[i] = self:CreateAbilityIcon(ability, i)
        self.icons[i]:ClearAllPoints()
        self.icons[i]:SetPoint("TOPLEFT", self, "TOPLEFT", 
            edgePadding + col * (iconSize + iconSpacing),
            -topPadding - row * (iconSize + rowSpacing))
            
        -- Hide the icon by default
        self.icons[i]:Hide()
        self.icons[i].glow:SetAlpha(0)
        self.icons[i].cooldownTimer:SetText("")
        self.icons[i].activeTimer:SetText("")
        self.icons[i].texture:SetVertexColor(1, 1, 1)  -- Reset color
    end
    
    -- Calculate frame dimensions based on icon size and count
    local totalWidth = edgePadding * 2 + (iconsPerRow * (iconSize + iconSpacing)) - iconSpacing
    local totalHeight = topPadding + (EzMageDB.rows * (iconSize + rowSpacing)) - rowSpacing + bottomPadding
    
    self:SetWidth(totalWidth)
    self:SetHeight(totalHeight)
end

-- Update auras
function EzMage:UpdateAuras()
    if isTestMode then return end
    
    for _, icon in ipairs(self.icons) do
        local ability = icon.ability
        local found = false
        local currentBuffIndex = -1
        local shouldContinue = false
        
        -- Only process non-proc abilities
        if not ability.isProc then
            -- For non-proc, non-action-based abilities, check if they exist in spellbook
            if not ability.isActionBased and not availableSpells[ability.name] then
                icon:Hide()
                icon.glow:SetAlpha(0)
                icon.activeTimer:SetText("")
                icon.texture:SetVertexColor(1, 1, 1)
                shouldContinue = true
            end
            
            if not shouldContinue then
                -- First check if we already have this buff tracked
                if activeBuffs[ability.name] then
                    currentBuffIndex = activeBuffs[ability.name].index
                    -- Verify the buff is still active
                    local buffTexture = GetPlayerBuffTexture(currentBuffIndex)
                    if buffTexture == ability.texture then
                        found = true
                        local duration = GetPlayerBuffTimeLeft(currentBuffIndex)
                        if duration and duration > 0 then
                            UpdateBuffEntry(ability, currentBuffIndex, duration)
                        end
                    end
                end
                
                -- If not found in active buffs, check all buffs
                if not found then
                    for i = 0, 31 do
                        local buffTexture = GetPlayerBuffTexture(i)
                        if buffTexture then
                            local altMatches = false
                            
                            if ability.alternateTextures then
                                for _, altTexture in ipairs(ability.alternateTextures) do
                                    if buffTexture == altTexture then
                                        altMatches = true
                                        break
                                    end
                                end
                            end
                            
                            if buffTexture == ability.texture or altMatches then
                                found = true
                                currentBuffIndex = i
                                local duration = GetPlayerBuffTimeLeft(i)
                                
                                -- Update buff tracking
                                if duration and duration > 0 then
                                    UpdateBuffEntry(ability, i, duration)
                                end
                                break
                            end
                        end
                    end
                end
                
                -- Update icon visibility
                if found then
                    icon:Show()
                    icon.glow:SetAlpha(1)
                    icon.texture:SetVertexColor(1, 1, 1)  -- Reset color to normal
                else
                    -- For non-proc, non-action-based abilities, show the icon but greyed out
                    if not ability.isActionBased then
                        -- If buff was previously tracked, handle expiration
                        if activeBuffs[ability.name] then
                            HandleBuffExpiration(ability.name)
                        end
                        
                        icon:Show()
                        icon.glow:SetAlpha(0)  -- No glow when not active
                        icon.activeTimer:SetText("")
                        icon.texture:SetVertexColor(0.7, 0.7, 0.7)  -- Grey out the icon
                    else
                        icon:Hide()
                        icon.glow:SetAlpha(0)
                        icon.activeTimer:SetText("")
                        icon.texture:SetVertexColor(1, 1, 1)  -- Reset color when hidden
                    end
                end
            end
        end
    end
end

-- Update cooldowns
function EzMage:UpdateCooldowns()
    for _, icon in ipairs(self.icons) do
        local ability = icon.ability
        if not ability.isProc then
            -- Find the action slot by texture
            local slot = FindActionSlotByTexture(ability.texture)
            if slot then
                local start, duration, enabled = GetActionCooldown(slot)
                if enabled then
                    icon:Show()
                    if duration > 0 then
                        local remaining = duration - (GetTime() - start)
                        if remaining > 0 then
                            icon.cooldown.texture:Show()
                            icon.cooldown.text:Show()
                            icon.cooldown.text:SetText(format("%.1f", remaining))
                            
                            -- Update cooldown texture
                            local progress = remaining / duration
                            icon.cooldown.texture:SetTexCoord(0, 1, 0, progress)
                        else
                            icon.cooldown.texture:Hide()
                            icon.cooldown.text:Hide()
                        end
                    else
                        icon.cooldown.texture:Hide()
                        icon.cooldown.text:Hide()
                    end
                else
                    icon:Hide()
                    icon.cooldown.texture:Hide()
                    icon.cooldown.text:Hide()
                end
            else
                -- Action not found on action bars
                icon:Hide()
                icon.cooldown.texture:Hide()
                icon.cooldown.text:Hide()
            end
        end
    end
end

-- Show action-based proc
function EzMage:ShowActionProc(ability)
    for _, icon in ipairs(self.icons) do
        if icon.ability == ability then
            icon:Show()
            icon.glow:SetAlpha(1)
            icon.cooldownTimer:SetText("")
            icon.activeTimer:SetText("")
            break
        end
    end
end

-- Hide action-based proc
function EzMage:HideActionProc(ability)
    for _, icon in ipairs(self.icons) do
        if icon.ability == ability then
            icon:Hide()
            icon.glow:SetAlpha(0)
            icon.cooldownTimer:SetText("")
            icon.activeTimer:SetText("")
            break
        end
    end
end

-- Create options frame
local function CreateOptionsFrame()
    if not EzMageOptionsFrame then
        local f = CreateFrame("Frame", "EzMageOptionsFrame", UIParent)
        f:SetWidth(300)
        f:SetHeight(300)  -- Increased height for new test button
        f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        f:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 }
        })
        f:SetBackdropColor(0, 0, 0, 0.8)
        f:EnableMouse(true)
        f:SetMovable(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", function() f:StartMoving() end)
        f:SetScript("OnDragStop", function() f:StopMovingOrSizing() end)

        -- Title
        local titleFrame = CreateFrame("Frame", nil, f)
        titleFrame:SetPoint("BOTTOM", f, "TOP", 0, 0)
        titleFrame:SetWidth(256)
        titleFrame:SetHeight(64)

        local titleTex = titleFrame:CreateTexture(nil, "OVERLAY")
        titleTex:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
        titleTex:SetAllPoints()

        local title = titleFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetText("|cff00ff00[EzMage]|r Options")
        title:SetPoint("TOP", 0, -14)

        -- Store pending changes
        local pendingChanges = {
            isLocked = EzMageDB.isLocked,
            rows = EzMageDB.rows,
            hideBackground = EzMageDB.hideBackground
        }

        -- Lock/Unlock Checkbox
        local lockCheck = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
        lockCheck:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -40)
        lockCheck:SetWidth(24)
        lockCheck:SetHeight(24)

        local lockLabel = lockCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        lockLabel:SetPoint("LEFT", lockCheck, "RIGHT", 4, 0)
        lockLabel:SetText("Lock Frame")

        lockCheck:SetChecked(pendingChanges.isLocked)
        lockCheck:SetScript("OnClick", function()
            pendingChanges.isLocked = lockCheck:GetChecked()
        end)

        -- Hide Background Checkbox
        local hideBgCheck = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
        hideBgCheck:SetPoint("TOPLEFT", lockCheck, "BOTTOMLEFT", 0, -10)
        hideBgCheck:SetWidth(24)
        hideBgCheck:SetHeight(24)

        local hideBgLabel = hideBgCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        hideBgLabel:SetPoint("LEFT", hideBgCheck, "RIGHT", 4, 0)
        hideBgLabel:SetText("Hide Background")

        hideBgCheck:SetChecked(pendingChanges.hideBackground)
        hideBgCheck:SetScript("OnClick", function()
            pendingChanges.hideBackground = hideBgCheck:GetChecked()
        end)

        -- Rows Slider
        local rowsLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        rowsLabel:SetPoint("TOPLEFT", hideBgCheck, "BOTTOMLEFT", 0, -20)
        rowsLabel:SetText("Number of Rows:")

        local rowsSlider = CreateFrame("Slider", "EzMageRowsSlider", f, "OptionsSliderTemplate")
        rowsSlider:SetPoint("TOPLEFT", rowsLabel, "BOTTOMLEFT", 0, -10)
        rowsSlider:SetWidth(260)
        rowsSlider:SetMinMaxValues(1, 3)
        rowsSlider:SetValueStep(1)
        rowsSlider:SetValue(pendingChanges.rows)

        local low = getglobal(rowsSlider:GetName().."Low")
        local high = getglobal(rowsSlider:GetName().."High")
        local txt = getglobal(rowsSlider:GetName().."Text")

        if low then low:SetText("1") end
        if high then high:SetText("3") end
        if txt then txt:SetText(tostring(pendingChanges.rows)) end

        rowsSlider:SetScript("OnValueChanged", function()
            local value = math.floor(this:GetValue())
            pendingChanges.rows = value
            if txt then
                txt:SetText(tostring(value))
            end
        end)

        -- Test Icons Button
        local testButton = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        testButton:SetPoint("TOP", rowsSlider, "BOTTOM", 0, -20)
        testButton:SetWidth(120)
        testButton:SetHeight(25)
        testButton:SetText("Test Icons")
        testButton:SetScript("OnClick", function()
            -- Enable test mode
            isTestMode = true
            
            -- Show all icons
            for _, icon in ipairs(EzMage.icons) do
                icon:Show()
                icon.glow:SetAlpha(1)
                icon.texture:SetVertexColor(1, 1, 1)
                icon.activeTimer:SetText("TEST")
                icon.cooldownTimer:SetText("")
            end
            
            -- Create a timer to hide icons after 10 seconds
            local testTimer = CreateFrame("Frame", nil, UIParent)
            testTimer:SetScript("OnUpdate", function()
                if not testTimer.startTime then
                    testTimer.startTime = GetTime()
                end
                
                if GetTime() - testTimer.startTime >= 10 then
                    -- Disable test mode
                    isTestMode = false
                    
                    -- Clear test text from all icons
                    for _, icon in ipairs(EzMage.icons) do
                        icon.activeTimer:SetText("")
                    end
                    
                    -- Restore normal icon visibility
                    EzMage:UpdateAuras()
                    EzMage:UpdateCooldowns()
                    auraFrame:CheckProcs()
                    actionFrame:CheckActionProcs()
                    
                    -- Properly clean up the test timer
                    testTimer:SetScript("OnUpdate", nil)
                    testTimer:Hide()
                    testTimer = nil
                end
            end)
        end)

        -- Reset Position Button
        local resetButton = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        resetButton:SetPoint("TOP", testButton, "BOTTOM", 0, -10)
        resetButton:SetWidth(120)
        resetButton:SetHeight(25)
        resetButton:SetText("Reset Position")
        resetButton:SetScript("OnClick", function()
            if EzMage and EzMageDB then
                EzMage:ClearAllPoints()
                EzMage:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
                EzMageDB.position = {x = 0, y = 0}
                DEFAULT_CHAT_FRAME:AddMessage("EzMage position reset", 1.0, 1.0, 0.0)
            end
        end)

        -- Confirm Button
        local confirmButton = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        confirmButton:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 20, 10)
        confirmButton:SetWidth(120)
        confirmButton:SetHeight(25)
        confirmButton:SetText("Confirm")
        confirmButton:SetScript("OnClick", function()
            -- Apply pending changes
            EzMageDB.isLocked = pendingChanges.isLocked
            EzMageDB.rows = pendingChanges.rows
            EzMageDB.hideBackground = pendingChanges.hideBackground

            -- First hide all icons
            for _, icon in ipairs(EzMage.icons) do
                icon:Hide()
                icon.glow:SetAlpha(0)
                icon.cooldownTimer:SetText("")
                icon.activeTimer:SetText("")
                icon.texture:SetVertexColor(1, 1, 1)  -- Reset color
            end

            -- Calculate frame dimensions based on icon size and count
            local iconSize = 32
            local iconSpacing = 3  -- Space between icons
            local edgePadding = 5  -- Padding on left and right edges
            local topPadding = 15   -- Padding at top for title
            local bottomPadding = 5 -- Padding at bottom for timers
            local rowSpacing = 5   -- Space between rows

            -- Calculate number of icons per row
            local totalIcons = table.getn(abilities)
            local iconsPerRow = math.ceil(totalIcons / EzMageDB.rows)

            -- Calculate frame dimensions
            local totalWidth = edgePadding * 2 + (iconsPerRow * (iconSize + iconSpacing)) - iconSpacing
            local totalHeight = topPadding + (EzMageDB.rows * (iconSize + rowSpacing)) - rowSpacing + bottomPadding

            -- Set frame size
            EzMage:SetWidth(totalWidth)
            EzMage:SetHeight(totalHeight)

            -- Reinitialize the frame
            EzMage:Init()
            EzMage:SetupUI()

            -- Check and update icon visibility
            EzMage:UpdateAuras()
            EzMage:UpdateCooldowns()

            -- Show feedback
            if EzMageDB.isLocked then
                DEFAULT_CHAT_FRAME:AddMessage("EzMage frame locked", 1.0, 1.0, 0.0)
            else
                DEFAULT_CHAT_FRAME:AddMessage("EzMage frame unlocked", 1.0, 1.0, 0.0)
            end
            DEFAULT_CHAT_FRAME:AddMessage("Number of rows set to " .. EzMageDB.rows, 1.0, 1.0, 0.0)
        end)

        -- Close Button
        local closeButton = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        closeButton:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -20, 10)
        closeButton:SetWidth(120)
        closeButton:SetHeight(25)
        closeButton:SetText("Close")
        closeButton:SetScript("OnClick", function()
            f:Hide()
        end)

        table.insert(UISpecialFrames, "EzMageOptionsFrame")
    end
    return EzMageOptionsFrame
end

-- Slash commands
SLASH_EZMAGE1 = "/ezmage"
SlashCmdList["EZMAGE"] = function(msg)
    if msg == "reset" then
        if EzMage and EzMageDB then
            EzMage:ClearAllPoints()
            EzMage:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
            EzMageDB.position = {x = 0, y = 0}
            DEFAULT_CHAT_FRAME:AddMessage("EzMage position reset", 1.0, 1.0, 0.0)
        end
    elseif msg == "config" or msg == "" then
        local f = CreateOptionsFrame()
        f:Show()
    end
end
