local ADDON_NAME, NS = ...

-- Runtime debug toggle via /cdmkp debug on|off
local DEBUG = false
local LOCK_MODE_TO_SENT = true
local LOCK_PRESET_TO_DEFAULT = true

-- Placeholder config to adapt for your CDM build if naming differs.
local CONFIG = {
    CDMAddonNames = {
        "Midnight",
        "CooldownManager",
        "CDM",
    },

    RootFrameNames = {
        -- Add exact global root frame names here if known.
        "MidnightCooldownManagerFrame",
        "CooldownManagerFrame",
    },

    ViewerFrameNames = {
        -- Blizzard CDM
        "EssentialCooldownViewer",
        "UtilityCooldownViewer",
        -- BetterCooldownManager
        "BCDM_CustomCooldownViewer",
        "BCDM_AdditionalCustomCooldownViewer",
        "BCDM_CustomItemSpellBar",
        "BCDM_CustomItemBar",
        "BCDM_TrinketBar",
        -- Ayije_CDM
        "EssentialCooldownViewer_CDM_Container",
        "UtilityCooldownViewer_CDM_Container",
        "CDM_DefensivesContainer",
        "CDM_TrinketsContainer",
        "CDM_RacialsContainer",
    },

    IconNamePatterns = {
        "^MidnightCDM",
        "^CDM",
        "CooldownManager",
    },

    ParentNamePatterns = {
        "Midnight",
        "CooldownManager",
        "^CDM",
    },

    SpellIDKeys = {
        "spellID",
        "spellId",
        "SpellID",
        "spell_id",
        "spellid",
        "id",
        "actionID",
        "actionId",
        "action_id",
        "spell",
    },

    -- Keep false if you only want strict name/ancestor matching.
    AllowUnsafeHeuristics = true,

    -- If true, scan starts even when addon folder name is unknown.
    EnableFallbackScanWithoutKnownAddon = true,

    -- Legacy flash layer (quickslot glow). Disabled to keep only keypress-style pressed tint.
    EnablePressFlash = false,

    -- Texture fallback can match unrelated UI icons (e.g. achievement toasts).
    -- Keep disabled by default to avoid bleed outside CDM icons.
    EnableTextureFallback = true,

    ExcludedFrameNamePatterns = {
        "^AchievementAlertFrame",
        "^AlertFrame",
        "Achievement",
        "Toast",
        "BossBanner",
        "TalkingHead",
    },

    PressTexturePath = "Interface\\Buttons\\UI-Quickslot2",
    PressBlendMode = "ADD",
    PressVertexColor = { 1.00, 0.95, 0.55 },
    PressPeakAlpha = 1.00,
    PressedTexturePath = "Interface\\Buttons\\WHITE8X8",
    PressedBlendMode = "ADD",
    PressedVertexColor = { 1.00, 0.90, 0.25 },
    PressedAlpha = 0.50,
    PressedShadeTexturePath = "Interface\\Buttons\\WHITE8X8",
    PressedShadeBlendMode = "BLEND",
    PressedShadeVertexColor = { 0, 0, 0 },
    PressedShadeAlpha = 0.28,
    PressedIconVertexColor = { 0.84, 0.84, 0.84, 1.00 },
    PressedScale = 0.97,
    PressedMinHoldSeconds = 0.08,
    PressedMaxHoldSeconds = 0.20,
    PressedFadeOutDuration = 0.00,
    FadeInDuration = 0.10,
    FadeOutDuration = 0.20,
    MinReplayGapSeconds = 0.05,

    TriggerOnSpellSent = true,
    TriggerOnSpellSucceeded = false,
    SentSuppressSucceededWindow = 1.20,

    MaxFramesPerScan = 5000,
}

local VISUAL_PRESETS = {
    default = {
        EnablePressFlash = false,
        EnableTextureFallback = true,
        PressBlendMode = "ADD",
        PressVertexColor = { 1.00, 0.95, 0.55 },
        PressPeakAlpha = 1.00,
        PressedTexturePath = "Interface\\Buttons\\WHITE8X8",
        PressedBlendMode = "ADD",
        PressedVertexColor = { 1.00, 0.90, 0.25 },
        PressedAlpha = 0.50,
        PressedShadeTexturePath = "Interface\\Buttons\\WHITE8X8",
        PressedShadeBlendMode = "BLEND",
        PressedShadeVertexColor = { 0, 0, 0 },
        PressedShadeAlpha = 0.28,
        PressedIconVertexColor = { 0.84, 0.84, 0.84, 1.00 },
        PressedScale = 0.97,
        PressedMinHoldSeconds = 0.08,
        PressedMaxHoldSeconds = 0.20,
        PressedFadeOutDuration = 0.00,
        FadeInDuration = 0.10,
        FadeOutDuration = 0.20,
    },
    blizzard = {
        EnablePressFlash = false,
        EnableTextureFallback = true,
        PressBlendMode = "ADD",
        PressVertexColor = { 1.00, 0.98, 0.78 },
        PressPeakAlpha = 1.00,
        PressedTexturePath = "Interface\\Buttons\\WHITE8X8",
        PressedBlendMode = "ADD",
        PressedVertexColor = { 1.00, 0.97, 0.40 },
        PressedAlpha = 0.95,
        PressedShadeTexturePath = "Interface\\Buttons\\WHITE8X8",
        PressedShadeBlendMode = "BLEND",
        PressedShadeVertexColor = { 0, 0, 0 },
        PressedShadeAlpha = 0.36,
        PressedIconVertexColor = { 0.78, 0.78, 0.78, 1.00 },
        PressedScale = 0.93,
        PressedMinHoldSeconds = 0.09,
        PressedMaxHoldSeconds = 0.18,
        PressedFadeOutDuration = 0.00,
        FadeInDuration = 0.05,
        FadeOutDuration = 0.13,
    },
}

local Dispatcher = CreateFrame("Frame")

-- Weak-key cache of tracked icon frames.
local trackedFrames = setmetatable({}, { __mode = "k" })

-- Indices for matching cast -> icon.
local spellIndex = {}     -- spellID -> weak-key set(frame)
local nameIndex = {}      -- normalized spell name -> weak-key set(frame)
local textureIndex = {}   -- normalized texture key -> weak-key set(frame)

local lastSentSpellID
local lastSentAt = 0
local activePressedState

local cdmLoadedByName = false
local autoDetectedByFrame = false
local warnedFallbackScan = false
local quickMenu
local currentPresetName = "default"
local startupScanDone = false
local startupRetryTicker
local viewerScanHooked = {}
local ayijeQueueHooked = false
local ScheduleViewerRescan
local EnsureViewerScanHooks
local ReleaseActivePressed

local rootNameSet = {}
for _, name in ipairs(CONFIG.RootFrameNames) do
    rootNameSet[name] = true
end

local function dprint(...)
    if DEBUG then
        print("|cff33ff99CDMKeyPress:|r", ...)
    end
end

local function SetDebugEnabled(enabled)
    DEBUG = enabled and true or false
    print(("|cff33ff99CDMKeyPress:|r debug %s"):format(DEBUG and "ON" or "OFF"))
end

local function IsAddOnLoadedSafe(name)
    if C_AddOns and C_AddOns.IsAddOnLoaded then
        return C_AddOns.IsAddOnLoaded(name)
    end
    if IsAddOnLoaded then
        return IsAddOnLoaded(name)
    end
    return false
end

local function IsConfiguredCDMAddon(addonName)
    for _, name in ipairs(CONFIG.CDMAddonNames) do
        if addonName == name then
            return true
        end
    end
    return false
end

local function DetectLoadedCDMAddon()
    for _, name in ipairs(CONFIG.CDMAddonNames) do
        if IsAddOnLoadedSafe(name) then
            return true, name
        end
    end
    return false, nil
end

local function IsForbiddenSafe(frame)
    return frame and frame.IsForbidden and frame:IsForbidden()
end

local function IsProtectedSafe(frame)
    return frame and frame.IsProtected and frame:IsProtected()
end

local function MatchAnyPattern(value, patterns)
    if type(value) ~= "string" then
        return false
    end
    for _, pattern in ipairs(patterns) do
        if value:match(pattern) then
            return true
        end
    end
    return false
end

local function IsExcludedByName(name)
    if type(name) ~= "string" then
        return false
    end
    return MatchAnyPattern(name, CONFIG.ExcludedFrameNamePatterns)
end

local function ToSpellID(value)
    local n
    if type(value) == "number" then
        -- Convert via string round-trip to strip WoW "secret" wrappers.
        local ok, asString = pcall(function()
            return tostring(value)
        end)
        if ok then
            n = tonumber(asString)
        end
    elseif type(value) == "string" then
        n = tonumber(value)
    end

    if type(n) == "number" and n > 0 then
        return n
    end
    return nil
end

local function NormalizeSpellName(name)
    if type(name) ~= "string" or name == "" then
        return nil
    end
    return name:lower()
end

local function NormalizeTextureKey(texture)
    if texture == nil then
        return nil
    end
    if type(texture) == "number" then
        return tostring(texture)
    end
    if type(texture) == "string" and texture ~= "" then
        return texture:lower()
    end
    return nil
end

local function GetSpellNameSafe(spellID)
    spellID = ToSpellID(spellID)
    if not spellID then
        return nil
    end

    if C_Spell and C_Spell.GetSpellName then
        local name = C_Spell.GetSpellName(spellID)
        if type(name) == "string" and name ~= "" then
            return name
        end
    end

    if GetSpellInfo then
        local name = GetSpellInfo(spellID)
        if type(name) == "string" and name ~= "" then
            return name
        end
    end

    return nil
end

local function GetSpellTextureSafe(spellID)
    spellID = ToSpellID(spellID)
    if not spellID then
        return nil
    end

    if C_Spell and C_Spell.GetSpellTexture then
        local tex = C_Spell.GetSpellTexture(spellID)
        if tex then
            return tex
        end
    end

    if GetSpellTexture then
        return GetSpellTexture(spellID)
    end

    return nil
end

local function ResolveSpellIDFromSpellName(spellName)
    if type(spellName) ~= "string" or spellName == "" then
        return nil
    end

    if C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(spellName)
        if type(info) == "table" and info.spellID and info.spellID > 0 then
            return info.spellID
        end
    end

    if GetSpellInfo then
        local _, _, _, _, _, _, spellID = GetSpellInfo(spellName)
        if spellID and spellID > 0 then
            return spellID
        end
    end

    return nil
end

local function ResolveSpellIDFromEventArgs(...)
    local n = select("#", ...)

    -- Prefer numeric payloads first.
    for i = 1, n do
        local spellID = ToSpellID(select(i, ...))
        if spellID then
            return spellID
        end
    end

    -- Fallback to spell-name payloads.
    for i = 1, n do
        local v = select(i, ...)
        if type(v) == "string" and v ~= "" then
            local spellID = ResolveSpellIDFromSpellName(v)
            if spellID then
                return spellID
            end
        end
    end

    return nil
end

local function GetFrameName(frame)
    if frame and frame.GetName then
        return frame:GetName()
    end
    return nil
end

local function BCDMIDFromName(name)
    if type(name) ~= "string" then
        return nil
    end
    local id = name:match("^BCDM_Custom_(%d+)")
    if id then
        return ToSpellID(id)
    end
    id = name:match("^BCDM_AdditionalCustom_(%d+)")
    if id then
        return ToSpellID(id)
    end
    return nil
end

local function IsLikelyActionButtonName(name)
    if type(name) ~= "string" then
        return false
    end
    if name:match("^ActionButton%d+$") then return true end
    if name:match("^MultiBar") then return true end
    if name:match("^PetActionButton") then return true end
    if name:match("^StanceButton") then return true end
    if name:match("^OverrideActionBarButton") then return true end
    return false
end

local function ReadTextureFromCandidate(candidate)
    if not candidate then
        return nil
    end

    if type(candidate) == "string" or type(candidate) == "number" then
        return candidate
    end

    if type(candidate) == "table" then
        if candidate.GetTexture then
            local texture = candidate:GetTexture()
            if texture then
                return texture
            end
        end
        if candidate.texture then return candidate.texture end
        if candidate.icon then return candidate.icon end
        if candidate.iconTexture then return candidate.iconTexture end
    end

    return nil
end

local function ReadTextureObjectFromCandidate(candidate)
    if type(candidate) ~= "table" then
        return nil
    end
    if candidate.GetObjectType and candidate:GetObjectType() == "Texture" then
        return candidate
    end
    return nil
end

local function HasIconTexture(frame)
    if not frame then
        return false
    end
    if frame.icon or frame.Icon or frame.iconTexture or frame.Texture or frame.texture then
        return true
    end
    if frame.data and (frame.data.icon or frame.data.texture) then
        return true
    end
    if frame.GetNormalTexture then
        return frame:GetNormalTexture() ~= nil
    end
    return false
end

local function ExtractSpellIDFromTable(tbl)
    if type(tbl) ~= "table" then
        return nil
    end

    for _, key in ipairs(CONFIG.SpellIDKeys) do
        local spellID = ToSpellID(tbl[key])
        if spellID then
            return spellID
        end
    end

    local spellID = ToSpellID(tbl.spell and tbl.spell.id)
    if spellID then
        return spellID
    end

    local spellName = tbl.spellName or tbl.name
    return ResolveSpellIDFromSpellName(spellName)
end

local function ExtractSpellID(frame)
    if not frame then
        return nil
    end

    -- Ayije_CDM frequently exposes spell via GetCooldownInfo()
    if type(frame.GetCooldownInfo) == "function" then
        local ok, info = pcall(frame.GetCooldownInfo, frame)
        if ok and type(info) == "table" then
            local sid = ToSpellID(info.overrideSpellID or info.spellID or info.linkedSpellID)
            if sid then
                return sid
            end
        end
    end

    if type(frame.GetSpellID) == "function" then
        local ok, result = pcall(frame.GetSpellID, frame)
        if ok then
            local spellID = ToSpellID(result)
            if spellID then
                return spellID
            end
        end
    end

    local spellID = ExtractSpellIDFromTable(frame)
    if spellID then
        return spellID
    end

    spellID = ExtractSpellIDFromTable(frame.data)
    if spellID then
        return spellID
    end

    if frame.GetAttribute then
        spellID = ToSpellID(frame:GetAttribute("spellID"))
        if spellID then
            return spellID
        end

        spellID = ToSpellID(frame:GetAttribute("spell"))
        if spellID then
            return spellID
        end

        spellID = ResolveSpellIDFromSpellName(frame:GetAttribute("spell"))
        if spellID then
            return spellID
        end
    end

    -- Blizzard CDM uses cooldownID -> C_CooldownViewer lookup
    if frame.cooldownID and C_CooldownViewer and C_CooldownViewer.GetCooldownViewerCooldownInfo then
        local ok, info = pcall(C_CooldownViewer.GetCooldownViewerCooldownInfo, frame.cooldownID)
        if ok and type(info) == "table" then
            local sid = ToSpellID(info.spellID or info.overrideSpellID or info.linkedSpellID)
            if sid then
                return sid
            end
        end
    end

    -- BCDM custom bars often encode spell/item id in frame names.
    local frameName = GetFrameName(frame)
    local sid = BCDMIDFromName(frameName)
    if sid then
        return sid
    end

    if frame.GetParent then
        local parent = frame:GetParent()
        sid = BCDMIDFromName(GetFrameName(parent))
        if sid then
            return sid
        end
    end

    return nil
end

local function ExtractSpellNameFromTable(tbl)
    if type(tbl) ~= "table" then
        return nil
    end
    local candidates = {
        tbl.spellName,
        tbl.name,
        tbl.spell and tbl.spell.name,
    }
    for i = 1, #candidates do
        if type(candidates[i]) == "string" and candidates[i] ~= "" then
            return candidates[i]
        end
    end
    return nil
end

local function ExtractSpellName(frame, spellID)
    local spellName = ExtractSpellNameFromTable(frame)
    if spellName then
        return spellName
    end

    spellName = ExtractSpellNameFromTable(frame and frame.data)
    if spellName then
        return spellName
    end

    if frame and frame.GetAttribute then
        local attr = frame:GetAttribute("spell")
        if type(attr) == "string" and attr ~= "" then
            return attr
        end
    end

    return GetSpellNameSafe(spellID)
end

local function ExtractFrameTextureKey(frame)
    if not frame then
        return nil
    end

    local texture = ReadTextureFromCandidate(frame.icon)
        or ReadTextureFromCandidate(frame.Icon)
        or ReadTextureFromCandidate(frame.iconTexture)
        or ReadTextureFromCandidate(frame.Texture)
        or ReadTextureFromCandidate(frame.texture)
        or ReadTextureFromCandidate(frame.data and frame.data.icon)
        or ReadTextureFromCandidate(frame.data and frame.data.texture)

    if not texture and frame.GetNormalTexture then
        texture = ReadTextureFromCandidate(frame:GetNormalTexture())
    end

    return NormalizeTextureKey(texture)
end

local function ExtractFrameIconTextureObject(frame)
    if not frame then
        return nil
    end

    local texture = ReadTextureObjectFromCandidate(frame.icon)
        or ReadTextureObjectFromCandidate(frame.Icon)
        or ReadTextureObjectFromCandidate(frame.iconTexture)
        or ReadTextureObjectFromCandidate(frame.Texture)
        or ReadTextureObjectFromCandidate(frame.texture)
        or ReadTextureObjectFromCandidate(frame.data and frame.data.icon)
        or ReadTextureObjectFromCandidate(frame.data and frame.data.texture)

    if not texture and frame.GetNormalTexture then
        texture = ReadTextureObjectFromCandidate(frame:GetNormalTexture())
    end

    return texture
end

local function FrameNameLooksCDM(frame)
    local name = GetFrameName(frame)
    if not name then
        return false
    end

    if rootNameSet[name] then
        return true
    end

    return MatchAnyPattern(name, CONFIG.IconNamePatterns)
        or MatchAnyPattern(name, CONFIG.ParentNamePatterns)
end

local function HasCDMAncestor(frame)
    local parent = frame and frame.GetParent and frame:GetParent()
    local depth = 0

    while parent and depth < 6 do
        local parentName = GetFrameName(parent)
        if parentName then
            if rootNameSet[parentName] or MatchAnyPattern(parentName, CONFIG.ParentNamePatterns) then
                return true
            end
        end
        parent = parent.GetParent and parent:GetParent()
        depth = depth + 1
    end

    return false
end

local function HasExcludedAncestor(frame)
    local current = frame
    local depth = 0
    while current and depth < 6 do
        local name = GetFrameName(current)
        if IsExcludedByName(name) then
            return true
        end
        current = current.GetParent and current:GetParent()
        depth = depth + 1
    end
    return false
end

local function HasAnySpellHints(frame)
    if type(frame.GetSpellID) == "function" then
        return true
    end
    for _, key in ipairs(CONFIG.SpellIDKeys) do
        if frame[key] ~= nil then
            return true
        end
    end
    if type(frame.data) == "table" then
        for _, key in ipairs(CONFIG.SpellIDKeys) do
            if frame.data[key] ~= nil then
                return true
            end
        end
    end
    return false
end

local SafeTableGet
local SafeTableSet
local SafeBucketSet

local function IsLikelyCDMContext(frame)
    if HasExcludedAncestor(frame) then
        return false
    end

    if SafeTableGet(trackedFrames, frame) then
        return true
    end

    if FrameNameLooksCDM(frame) or HasCDMAncestor(frame) then
        return true
    end

    local name = GetFrameName(frame)
    if IsLikelyActionButtonName(name) then
        return false
    end

    if CONFIG.AllowUnsafeHeuristics and HasAnySpellHints(frame) then
        return true
    end

    return false
end

SafeTableGet = function(tbl, key)
    local ok, value = pcall(function()
        return tbl[key]
    end)
    if ok then
        return value
    end
    return nil
end

SafeTableSet = function(tbl, key, value)
    local ok = pcall(function()
        tbl[key] = value
    end)
    return ok
end

SafeBucketSet = function(bucket, frame, value)
    pcall(function()
        bucket[frame] = value
    end)
end

local function GetWeakBucket(container, key)
    local bucket = SafeTableGet(container, key)
    if not bucket then
        bucket = setmetatable({}, { __mode = "k" })
        if not SafeTableSet(container, key, bucket) then
            return nil
        end
    end
    return bucket
end

local function GetSpellBucket(spellID) return GetWeakBucket(spellIndex, spellID) end
local function GetNameBucket(nameKey) return GetWeakBucket(nameIndex, nameKey) end
local function GetTextureBucket(textureKey) return GetWeakBucket(textureIndex, textureKey) end

local function UnindexFrameSpell(frame)
    local previous = frame.__cdmkpSpellID
    if not previous then
        return
    end
    local bucket = SafeTableGet(spellIndex, previous)
    if bucket then
        SafeBucketSet(bucket, frame, nil)
    end
    frame.__cdmkpSpellID = nil
end

local function UnindexFrameName(frame)
    local previous = frame.__cdmkpSpellNameKey
    if not previous then
        return
    end
    local bucket = SafeTableGet(nameIndex, previous)
    if bucket then
        SafeBucketSet(bucket, frame, nil)
    end
    frame.__cdmkpSpellNameKey = nil
end

local function UnindexFrameTexture(frame)
    local previous = frame.__cdmkpTextureKey
    if not previous then
        return
    end
    local bucket = SafeTableGet(textureIndex, previous)
    if bucket then
        SafeBucketSet(bucket, frame, nil)
    end
    frame.__cdmkpTextureKey = nil
end

local function UnindexFrameAll(frame)
    UnindexFrameSpell(frame)
    UnindexFrameName(frame)
    UnindexFrameTexture(frame)
end

local function IndexFrameSpell(frame, spellID)
    local previous = frame.__cdmkpSpellID
    if previous == spellID then
        return
    end
    if previous then
        local previousBucket = SafeTableGet(spellIndex, previous)
        if previousBucket then
            SafeBucketSet(previousBucket, frame, nil)
        end
    end
    frame.__cdmkpSpellID = spellID
    local bucket = GetSpellBucket(spellID)
    if bucket then
        SafeBucketSet(bucket, frame, true)
    end
end

local function IndexFrameName(frame, spellName)
    local nameKey = NormalizeSpellName(spellName)
    local previous = frame.__cdmkpSpellNameKey

    if previous and previous ~= nameKey then
        local previousBucket = SafeTableGet(nameIndex, previous)
        if previousBucket then
            SafeBucketSet(previousBucket, frame, nil)
        end
    end

    frame.__cdmkpSpellNameKey = nameKey
    if nameKey then
        local bucket = GetNameBucket(nameKey)
        if bucket then
            SafeBucketSet(bucket, frame, true)
        end
    end
end

local function IndexFrameTexture(frame, textureKey)
    local previous = frame.__cdmkpTextureKey

    if previous and previous ~= textureKey then
        local previousBucket = SafeTableGet(textureIndex, previous)
        if previousBucket then
            SafeBucketSet(previousBucket, frame, nil)
        end
    end

    frame.__cdmkpTextureKey = textureKey
    if textureKey then
        local bucket = GetTextureBucket(textureKey)
        if bucket then
            SafeBucketSet(bucket, frame, true)
        end
    end
end

local function EnsurePressAnimation(frame)
    if frame.__cdmkpPressAnim then
        return
    end

    local overlay = frame:CreateTexture(nil, "OVERLAY")
    overlay:SetAllPoints(frame)
    overlay:SetDrawLayer("OVERLAY", 7)
    overlay:SetTexture(CONFIG.PressTexturePath)
    overlay:SetBlendMode(CONFIG.PressBlendMode or "ADD")
    overlay:SetVertexColor(unpack(CONFIG.PressVertexColor))
    overlay:SetAlpha(0)

    local anim = overlay:CreateAnimationGroup()

    local fadeIn = anim:CreateAnimation("Alpha")
    fadeIn:SetOrder(1)
    fadeIn:SetDuration(CONFIG.FadeInDuration)
    fadeIn:SetFromAlpha(0)
    fadeIn:SetToAlpha(CONFIG.PressPeakAlpha)

    local fadeOut = anim:CreateAnimation("Alpha")
    fadeOut:SetOrder(2)
    fadeOut:SetDuration(CONFIG.FadeOutDuration)
    fadeOut:SetFromAlpha(CONFIG.PressPeakAlpha)
    fadeOut:SetToAlpha(0)

    local pressedShadeOverlay = frame:CreateTexture(nil, "OVERLAY")
    pressedShadeOverlay:SetAllPoints(frame)
    pressedShadeOverlay:SetDrawLayer("OVERLAY", 6)
    pressedShadeOverlay:SetTexture(CONFIG.PressedShadeTexturePath)
    pressedShadeOverlay:SetBlendMode(CONFIG.PressedShadeBlendMode or "BLEND")
    pressedShadeOverlay:SetVertexColor(unpack(CONFIG.PressedShadeVertexColor))
    pressedShadeOverlay:SetAlpha(0)

    local pressedOverlay = frame:CreateTexture(nil, "OVERLAY")
    pressedOverlay:SetAllPoints(frame)
    pressedOverlay:SetDrawLayer("OVERLAY", 7)
    pressedOverlay:SetTexture(CONFIG.PressedTexturePath)
    pressedOverlay:SetBlendMode(CONFIG.PressedBlendMode or "ADD")
    pressedOverlay:SetVertexColor(unpack(CONFIG.PressedVertexColor))
    pressedOverlay:SetAlpha(0)

    local pressedFadeOutAnim = pressedOverlay:CreateAnimationGroup()
    local pressedFadeOut = pressedFadeOutAnim:CreateAnimation("Alpha")
    pressedFadeOut:SetOrder(1)
    pressedFadeOut:SetDuration(CONFIG.PressedFadeOutDuration)
    pressedFadeOut:SetFromAlpha(CONFIG.PressedAlpha)
    pressedFadeOut:SetToAlpha(0)

    frame.__cdmkpPressOverlay = overlay
    frame.__cdmkpPressAnim = anim
    frame.__cdmkpPressFadeIn = fadeIn
    frame.__cdmkpPressFadeOut = fadeOut
    frame.__cdmkpPressedOverlay = pressedOverlay
    frame.__cdmkpPressedShadeOverlay = pressedShadeOverlay
    frame.__cdmkpPressedFadeOutAnim = pressedFadeOutAnim
    frame.__cdmkpPressedFadeOut = pressedFadeOut
    frame.__cdmkpIconTextureObject = ExtractFrameIconTextureObject(frame)
end

local function PlayPressAnimation(frame)
    local anim = frame.__cdmkpPressAnim
    local overlay = frame.__cdmkpPressOverlay
    if not anim or not overlay then
        return
    end

    local now = (GetTimePreciseSec and GetTimePreciseSec()) or GetTime()
    local previousTime = frame.__cdmkpLastPlay
    if previousTime and (now - previousTime) < CONFIG.MinReplayGapSeconds then
        return
    end
    frame.__cdmkpLastPlay = now

    anim:Stop()
    overlay:SetAlpha(0)
    anim:Play()
end

local function ShowPressedTint(frame)
    local overlay = frame.__cdmkpPressedOverlay
    local shadeOverlay = frame.__cdmkpPressedShadeOverlay
    local fadeOutAnim = frame.__cdmkpPressedFadeOutAnim
    if not overlay and not shadeOverlay then
        return
    end

    if fadeOutAnim then
        fadeOutAnim:Stop()
    end
    if overlay then
        overlay:SetAlpha(CONFIG.PressedAlpha)
    end
    if shadeOverlay then
        shadeOverlay:SetAlpha(CONFIG.PressedShadeAlpha or 0)
    end

    local icon = frame.__cdmkpIconTextureObject or ExtractFrameIconTextureObject(frame)
    if icon and icon.SetVertexColor and icon.GetVertexColor then
        local r, g, b, a = icon:GetVertexColor()
        if not frame.__cdmkpBaseIconVertexColor then
            frame.__cdmkpBaseIconVertexColor = { r or 1, g or 1, b or 1, a or 1 }
        end
        local tint = CONFIG.PressedIconVertexColor
        if type(tint) == "table" then
            icon:SetVertexColor(
                tint[1] or 1,
                tint[2] or 1,
                tint[3] or 1,
                tint[4] or 1
            )
            frame.__cdmkpIconTintActive = true
        end
        frame.__cdmkpIconTextureObject = icon
    end

    if CONFIG.PressedScale and CONFIG.PressedScale > 0 and frame.SetScale then
        if not frame.__cdmkpBaseScale then
            frame.__cdmkpBaseScale = frame:GetScale() or 1
        end
        frame:SetScale(frame.__cdmkpBaseScale * CONFIG.PressedScale)
        frame.__cdmkpPressedScaleActive = true
    end
end

local function HidePressedTint(frame)
    local overlay = frame.__cdmkpPressedOverlay
    local shadeOverlay = frame.__cdmkpPressedShadeOverlay
    local fadeOutAnim = frame.__cdmkpPressedFadeOutAnim

    if fadeOutAnim then
        fadeOutAnim:Stop()
    end
    if overlay then
        overlay:SetAlpha(0)
    end
    if shadeOverlay then
        shadeOverlay:SetAlpha(0)
    end

    if frame.__cdmkpIconTintActive then
        local icon = frame.__cdmkpIconTextureObject
        if icon and icon.SetVertexColor then
            local base = frame.__cdmkpBaseIconVertexColor
            if type(base) == "table" then
                icon:SetVertexColor(base[1] or 1, base[2] or 1, base[3] or 1, base[4] or 1)
            else
                icon:SetVertexColor(1, 1, 1, 1)
            end
        end
        frame.__cdmkpIconTintActive = nil
    end

    if frame.__cdmkpPressedScaleActive and frame.SetScale then
        frame:SetScale(frame.__cdmkpBaseScale or 1)
        frame.__cdmkpPressedScaleActive = nil
    end
end

local function ClearAllPressedVisuals()
    for frame in pairs(trackedFrames) do
        if frame then
            HidePressedTint(frame)
        end
    end
end

local function TrackIconFrame(frame)
    if not frame or IsForbiddenSafe(frame) or IsProtectedSafe(frame) then
        return
    end

    local objectType = frame.GetObjectType and frame:GetObjectType()
    if objectType ~= "Button" and objectType ~= "Frame" then
        return
    end

    if not IsLikelyCDMContext(frame) then
        return
    end

    local namedLikeIcon = MatchAnyPattern(GetFrameName(frame), CONFIG.IconNamePatterns)
    if not HasIconTexture(frame) and not namedLikeIcon then
        return
    end

    local spellID = ExtractSpellID(frame)
    local spellName = ExtractSpellName(frame, spellID)
    local textureKey = ExtractFrameTextureKey(frame)

    -- Must have at least one useful link to cast payload.
    if not spellID and not spellName and not textureKey then
        if SafeTableGet(trackedFrames, frame) then
            UnindexFrameAll(frame)
        end
        return
    end

    local isNew = not SafeTableGet(trackedFrames, frame)
    SafeTableSet(trackedFrames, frame, true)

    EnsurePressAnimation(frame)

    if spellID then
        IndexFrameSpell(frame, spellID)
    else
        UnindexFrameSpell(frame)
    end
    IndexFrameName(frame, spellName)
    IndexFrameTexture(frame, textureKey)

    if not autoDetectedByFrame then
        autoDetectedByFrame = true
        dprint("CDM context auto-detected from frame scan")
    end

    if isNew then
        dprint(("Tracked frame: %s -> id=%s name=%s tex=%s"):format(
            GetFrameName(frame) or "<unnamed>",
            spellID and tostring(spellID) or "nil",
            spellName or "nil",
            textureKey or "nil"
        ))
    end
end

local function ScanSubtree(root, budget)
    if not root or budget <= 0 then
        return 0
    end

    local queue = { root }
    local head = 1
    local scanned = 0

    while queue[head] and scanned < budget do
        local frame = queue[head]
        queue[head] = nil
        head = head + 1

        scanned = scanned + 1
        TrackIconFrame(frame)

        if frame.GetChildren and frame.GetNumChildren then
            local childCount = frame:GetNumChildren()
            if childCount and childCount > 0 then
                local children = { frame:GetChildren() }
                for i = 1, #children do
                    queue[#queue + 1] = children[i]
                end
            end
        end
    end

    return scanned
end

local function FindConfiguredRoots()
    local roots = {}
    local seen = {}

    local function addRoot(root)
        if type(root) ~= "table" then
            return
        end
        if seen[root] then
            return
        end
        seen[root] = true
        roots[#roots + 1] = root
    end

    for _, name in ipairs(CONFIG.RootFrameNames) do
        addRoot(_G[name])
    end

    -- Import explicit viewer roots from CDM/BCDM conventions.
    for _, name in ipairs(CONFIG.ViewerFrameNames) do
        addRoot(_G[name])
    end

    return roots
end

local function ScanViewerPoolFrames(root, budget)
    if not root or not root.itemFramePool or budget <= 0 then
        return 0
    end

    local scanned = 0
    local ok = pcall(function()
        for frame in root.itemFramePool:EnumerateActive() do
            if not frame or not frame.IsShown or frame:IsShown() then
                TrackIconFrame(frame)
                scanned = scanned + 1
                if scanned >= budget then
                    break
                end
            end
        end
    end)

    if not ok then
        return 0
    end
    return scanned
end

local function FallbackGlobalScan()
    local frame = EnumerateFrames()
    local scanned = 0

    while frame and scanned < CONFIG.MaxFramesPerScan do
        scanned = scanned + 1
        TrackIconFrame(frame)
        frame = EnumerateFrames(frame)
    end

    return scanned
end

local function ShouldRunScan()
    return cdmLoadedByName or autoDetectedByFrame or CONFIG.EnableFallbackScanWithoutKnownAddon
end

local function CountTrackedFrames()
    local n = 0
    for _ in pairs(trackedFrames) do
        n = n + 1
    end
    return n
end

local function ScanForCDMIcons()
    if not ShouldRunScan() then
        return 0
    end

    local scanned = 0
    local roots = FindConfiguredRoots()

    if #roots > 0 then
        local budget = CONFIG.MaxFramesPerScan
        for i = 1, #roots do
            if budget <= 0 then
                break
            end
            local root = roots[i]
            local poolUsed = ScanViewerPoolFrames(root, budget)
            scanned = scanned + poolUsed
            budget = budget - poolUsed
            if budget <= 0 then
                break
            end

            local used = ScanSubtree(root, budget)
            scanned = scanned + used
            budget = budget - used
        end
    else
        scanned = FallbackGlobalScan()
        if not warnedFallbackScan then
            warnedFallbackScan = true
            dprint("Using fallback global scan. Set CONFIG.RootFrameNames for better performance.")
        end
    end

    dprint(("Scan complete (checked %d frames, tracked %d)"):format(scanned, CountTrackedFrames()))
    return scanned
end

local function RunScanNow(source)
    local ok, err = pcall(ScanForCDMIcons)
    if not ok then
        print(("|cffff5555CDMKeyPress:|r scan error (%s): %s"):format(source or "unknown", tostring(err)))
        return false
    end
    print(("|cff33ff99CDMKeyPress:|r tracked %d frame(s)"):format(CountTrackedFrames()))
    return true
end

local function RunAutoScan(source, announce)
    local ok, err = pcall(ScanForCDMIcons)
    if not ok then
        print(("|cffff5555CDMKeyPress:|r auto-scan error (%s): %s"):format(source or "unknown", tostring(err)))
        return false
    end
    if announce then
        print(("|cff33ff99CDMKeyPress:|r startup scan: tracked %d frame(s)"):format(CountTrackedFrames()))
    end
    return true
end

local function CopyArray(values)
    if type(values) ~= "table" then
        return values
    end
    local out = {}
    for i = 1, #values do
        out[i] = values[i]
    end
    return out
end

local function RefreshTrackedVisuals()
    for frame in pairs(trackedFrames) do
        local overlay = frame.__cdmkpPressOverlay
        if overlay then
            overlay:SetTexture(CONFIG.PressTexturePath)
            overlay:SetBlendMode(CONFIG.PressBlendMode or "ADD")
            overlay:SetVertexColor(unpack(CONFIG.PressVertexColor))
        end

        local fadeIn = frame.__cdmkpPressFadeIn
        if fadeIn then
            fadeIn:SetDuration(CONFIG.FadeInDuration)
            fadeIn:SetFromAlpha(0)
            fadeIn:SetToAlpha(CONFIG.PressPeakAlpha)
        end

        local fadeOut = frame.__cdmkpPressFadeOut
        if fadeOut then
            fadeOut:SetDuration(CONFIG.FadeOutDuration)
            fadeOut:SetFromAlpha(CONFIG.PressPeakAlpha)
            fadeOut:SetToAlpha(0)
        end

        local pressed = frame.__cdmkpPressedOverlay
        if pressed then
            pressed:SetTexture(CONFIG.PressedTexturePath)
            pressed:SetBlendMode(CONFIG.PressedBlendMode or "ADD")
            pressed:SetVertexColor(unpack(CONFIG.PressedVertexColor))
            if pressed:GetAlpha() > 0 then
                pressed:SetAlpha(CONFIG.PressedAlpha)
            end
        end

        local shade = frame.__cdmkpPressedShadeOverlay
        if shade then
            shade:SetTexture(CONFIG.PressedShadeTexturePath)
            shade:SetBlendMode(CONFIG.PressedShadeBlendMode or "BLEND")
            shade:SetVertexColor(unpack(CONFIG.PressedShadeVertexColor))
            if shade:GetAlpha() > 0 then
                shade:SetAlpha(CONFIG.PressedShadeAlpha or 0)
            end
        end

        local pressedFadeOut = frame.__cdmkpPressedFadeOut
        if pressedFadeOut then
            pressedFadeOut:SetDuration(CONFIG.PressedFadeOutDuration)
            pressedFadeOut:SetFromAlpha(CONFIG.PressedAlpha)
            pressedFadeOut:SetToAlpha(0)
        end

        if frame.__cdmkpIconTintActive then
            local icon = frame.__cdmkpIconTextureObject or ExtractFrameIconTextureObject(frame)
            local tint = CONFIG.PressedIconVertexColor
            if icon and tint and icon.SetVertexColor then
                icon:SetVertexColor(
                    tint[1] or 1,
                    tint[2] or 1,
                    tint[3] or 1,
                    tint[4] or 1
                )
                frame.__cdmkpIconTextureObject = icon
            end
        end
    end
end

local function ApplyVisualPreset(name)
    if LOCK_PRESET_TO_DEFAULT and name ~= "default" then
        print("|cff33ff99CDMKeyPress:|r preset locked to default")
        return false
    end

    local preset = VISUAL_PRESETS[name]
    if not preset then
        print("|cffff5555CDMKeyPress:|r unknown preset:", name)
        return false
    end

    for key, value in pairs(preset) do
        CONFIG[key] = CopyArray(value)
    end

    currentPresetName = name
    RefreshTrackedVisuals()
    print(("|cff33ff99CDMKeyPress:|r preset = %s"):format(name))
    return true
end

local function StartScanner()
    if startupScanDone then
        EnsureViewerScanHooks()
        return
    end

    startupScanDone = true
    EnsureViewerScanHooks()

    -- Startup burst only (reload/login), then manual scans only.
    local startupDelays = { 0.0, 0.4, 1.0, 2.0 }
    for i = 1, #startupDelays do
        C_Timer.After(startupDelays[i], function()
            RunAutoScan("startup", i == #startupDelays)
        end)
    end

    -- Finite retry window: stop once CDM frames are tracked or attempts are exhausted.
    local attemptsLeft = 20
    startupRetryTicker = C_Timer.NewTicker(1.5, function()
        if CountTrackedFrames() > 0 then
            if startupRetryTicker then
                startupRetryTicker:Cancel()
                startupRetryTicker = nil
            end
            dprint("Startup scan retries stopped (frames detected)")
            return
        end

        RunAutoScan("startup-retry", attemptsLeft == 1)
        attemptsLeft = attemptsLeft - 1
        if attemptsLeft <= 0 and startupRetryTicker then
            startupRetryTicker:Cancel()
            startupRetryTicker = nil
            dprint("Startup scan retries exhausted")
        end
    end)

    dprint("Startup scan complete (auto periodic scan disabled)")
end

ScheduleViewerRescan = function(delaySeconds)
    C_Timer.After(delaySeconds or 0.05, function()
        pcall(ScanForCDMIcons)
    end)
end

local function IsKnownViewerName(name)
    if type(name) ~= "string" then
        return false
    end
    for i = 1, #CONFIG.ViewerFrameNames do
        if CONFIG.ViewerFrameNames[i] == name then
            return true
        end
    end
    return false
end

EnsureViewerScanHooks = function()
    if not hooksecurefunc then
        return
    end

    for i = 1, #CONFIG.ViewerFrameNames do
        local viewerName = CONFIG.ViewerFrameNames[i]
        if not viewerScanHooked[viewerName] then
            local frame = _G[viewerName]
            if frame then
                if type(frame.RefreshLayout) == "function" then
                    hooksecurefunc(frame, "RefreshLayout", function()
                        ScheduleViewerRescan(0.05)
                    end)
                end

                if frame.HookScript then
                    frame:HookScript("OnShow", function()
                        ScheduleViewerRescan(0.05)
                    end)
                end

                viewerScanHooked[viewerName] = true
            end
        end
    end

    local ayije = _G["Ayije_CDM"]
    if ayije and not ayijeQueueHooked and type(ayije.QueueViewer) == "function" then
        ayijeQueueHooked = true
        hooksecurefunc(ayije, "QueueViewer", function(_, viewerName)
            if not viewerName or IsKnownViewerName(viewerName) then
                ScheduleViewerRescan(0.05)
            end
        end)
    end
end

local function CollectFramesForSpell(spellID)
    local seen = {}
    local hits = 0

    local function collect(bucket)
        if not bucket then
            return
        end
        for frame in pairs(bucket) do
            if frame and frame.IsShown and frame:IsShown() and not IsForbiddenSafe(frame) then
                if not seen[frame] then
                    seen[frame] = true
                    hits = hits + 1
                end
            end
        end
    end

    collect(SafeTableGet(spellIndex, spellID))

    if hits == 0 then
        local spellName = GetSpellNameSafe(spellID)
        local nameKey = NormalizeSpellName(spellName)
        if nameKey then
            collect(SafeTableGet(nameIndex, nameKey))
        end

        if CONFIG.EnableTextureFallback then
            local textureKey = NormalizeTextureKey(GetSpellTextureSafe(spellID))
            if textureKey then
                collect(SafeTableGet(textureIndex, textureKey))
            end
        end
    end

    return seen, hits
end

local function TriggerForSpellID(spellID, sourceTag)
    local seen, hits = CollectFramesForSpell(spellID)

    if CONFIG.EnablePressFlash then
        for frame in pairs(seen) do
            PlayPressAnimation(frame)
        end
    end

    if hits == 0 then
        dprint(("%s %d: no tracked CDM icon"):format(sourceTag, spellID))
    else
        if CONFIG.EnablePressFlash then
            dprint(("%s %d: animated %d frame(s)"):format(sourceTag, spellID, hits))
        else
            dprint(("%s %d: matched %d frame(s)"):format(sourceTag, spellID, hits))
        end
    end

    return hits, seen
end

local function SetPressedForFrameSet(frameSet, pressed)
    if type(frameSet) ~= "table" then
        return
    end
    for frame in pairs(frameSet) do
        if pressed then
            ShowPressedTint(frame)
        else
            HidePressedTint(frame)
        end
    end
end

local function ActivatePressedState(spellID, frameSet)
    if type(frameSet) ~= "table" then
        return
    end

    if activePressedState then
        SetPressedForFrameSet(activePressedState.frames, false)
        activePressedState = nil
    end

    SetPressedForFrameSet(frameSet, true)

    local now = (GetTimePreciseSec and GetTimePreciseSec()) or GetTime()
    local state = { sentAt = now, spellID = spellID, frames = frameSet }
    activePressedState = state

    C_Timer.After(CONFIG.PressedMaxHoldSeconds, function()
        if activePressedState == state then
            ReleaseActivePressed("timeout", state)
        end
    end)
end

ReleaseActivePressed = function(reason, expectedState)
    local state = activePressedState
    if not state then
        return
    end

    if expectedState and expectedState ~= state then
        return
    end

    local now = (GetTimePreciseSec and GetTimePreciseSec()) or GetTime()
    local elapsed = now - state.sentAt
    local remaining = CONFIG.PressedMinHoldSeconds - elapsed

    local function finish(stateRef)
        if activePressedState ~= stateRef then
            return
        end
        activePressedState = nil
        SetPressedForFrameSet(stateRef.frames, false)
        ClearAllPressedVisuals()
        dprint(("Pressed %s: released (%s)"):format(tostring(stateRef.spellID or "?"), reason))
    end

    if remaining > 0 then
        C_Timer.After(remaining, function()
            finish(state)
        end)
    else
        finish(state)
    end
end

local function OnSpellcastSent(unitToken, ...)
    if unitToken ~= "player" or not CONFIG.TriggerOnSpellSent then
        return
    end

    local spellID = ResolveSpellIDFromEventArgs(...)
    if not spellID then
        dprint("Sent: unable to resolve spellID")
        return
    end

    local hits, seen = TriggerForSpellID(spellID, "Sent")
    if hits > 0 then
        ActivatePressedState(spellID, seen)
        local now = (GetTimePreciseSec and GetTimePreciseSec()) or GetTime()
        lastSentSpellID = spellID
        lastSentAt = now
    else
        if activePressedState and activePressedState.spellID == spellID then
            ReleaseActivePressed("sent-no-hit")
        end
    end
end

local function OnSpellcastSucceeded(unitToken, ...)
    if unitToken ~= "player" or not CONFIG.TriggerOnSpellSucceeded then
        return
    end

    local spellID = ResolveSpellIDFromEventArgs(...)
    if not spellID then
        dprint("Succeeded: unable to resolve spellID")
        return
    end

    if CONFIG.TriggerOnSpellSent and lastSentSpellID == spellID then
        local now = (GetTimePreciseSec and GetTimePreciseSec()) or GetTime()
        if (now - lastSentAt) <= CONFIG.SentSuppressSucceededWindow then
            dprint(("Succeeded %d: suppressed (already animated on Sent)"):format(spellID))
            ReleaseActivePressed("succeeded")
            return
        end
    end

    ReleaseActivePressed("succeeded")
    local hits, seen = TriggerForSpellID(spellID, "Succeeded")
    if hits > 0 then
        ActivatePressedState(spellID, seen)
    end
end

local function OnSpellcastEnded(reasonTag, unitToken, ...)
    if unitToken ~= "player" then
        return
    end

    ReleaseActivePressed(reasonTag)
end

local function OnAddonLoaded(loadedAddonName)
    if loadedAddonName == ADDON_NAME then
        local loaded, foundName = DetectLoadedCDMAddon()
        if loaded then
            cdmLoadedByName = true
            dprint("Detected CDM addon by configured name:", foundName)
        else
            dprint("No configured CDM addon name matched; fallback scan is active.")
        end

        StartScanner()
        return
    end

    if IsConfiguredCDMAddon(loadedAddonName) then
        cdmLoadedByName = true
        dprint("Detected CDM addon load:", loadedAddonName)
        EnsureViewerScanHooks()
        if startupScanDone then
            pcall(ScanForCDMIcons)
        else
            StartScanner()
        end
        return
    end

    -- If any viewer addon loads later, retry hooks + scan.
    if startupScanDone then
        EnsureViewerScanHooks()
        ScheduleViewerRescan(0.10)
    end
end

Dispatcher:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        OnAddonLoaded(...)
    elseif event == "PLAYER_LOGIN" then
        StartScanner()
    elseif event == "UNIT_SPELLCAST_SENT" then
        OnSpellcastSent(...)
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        OnSpellcastSucceeded(...)
    elseif event == "UNIT_SPELLCAST_FAILED" then
        OnSpellcastEnded("failed", ...)
    elseif event == "UNIT_SPELLCAST_FAILED_QUIET" then
        OnSpellcastEnded("failed_quiet", ...)
    elseif event == "UNIT_SPELLCAST_INTERRUPTED" then
        OnSpellcastEnded("interrupted", ...)
    elseif event == "UNIT_SPELLCAST_STOP" then
        OnSpellcastEnded("stop", ...)
    end
end)

Dispatcher:RegisterEvent("ADDON_LOADED")
Dispatcher:RegisterEvent("PLAYER_LOGIN")
Dispatcher:RegisterEvent("UNIT_SPELLCAST_SENT")
Dispatcher:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
Dispatcher:RegisterEvent("UNIT_SPELLCAST_FAILED")
Dispatcher:RegisterEvent("UNIT_SPELLCAST_FAILED_QUIET")
Dispatcher:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
Dispatcher:RegisterEvent("UNIT_SPELLCAST_STOP")

local function GetLoadedCandidatesText()
    local parts = {}
    for _, name in ipairs(CONFIG.CDMAddonNames) do
        parts[#parts + 1] = ("%s=%s"):format(name, IsAddOnLoadedSafe(name) and "1" or "0")
    end
    return table.concat(parts, " ")
end

local function GetLoadedAddonNames()
    local names = {}

    if C_AddOns and C_AddOns.GetNumAddOns and C_AddOns.GetAddOnInfo then
        local count = C_AddOns.GetNumAddOns() or 0
        for i = 1, count do
            local info = C_AddOns.GetAddOnInfo(i)
            if type(info) == "table" then
                if info.name then
                    names[#names + 1] = info.name
                end
            elseif type(info) == "string" then
                names[#names + 1] = info
            else
                local name = select(1, C_AddOns.GetAddOnInfo(i))
                if type(name) == "string" then
                    names[#names + 1] = name
                end
            end
        end
        return names
    end

    if GetNumAddOns and GetAddOnInfo then
        local count = GetNumAddOns() or 0
        for i = 1, count do
            local name = GetAddOnInfo(i)
            if name then
                names[#names + 1] = name
            end
        end
    end

    return names
end

local function PrintLoadedAddonHints()
    local names = GetLoadedAddonNames()
    local hits = {}
    for i = 1, #names do
        local lower = names[i]:lower()
        if lower:find("midnight", 1, true) or lower:find("cooldown", 1, true) or lower:find("cdm", 1, true) then
            hits[#hits + 1] = names[i]
        end
    end
    if #hits == 0 then
        print("|cff33ff99CDMKeyPress:|r no loaded addon matched midnight/cooldown/cdm")
        return
    end
    print("|cff33ff99CDMKeyPress:|r loaded addon hints:", table.concat(hits, ", "))
end

local function ParseSlash(msg)
    msg = (msg or ""):lower()
    msg = msg:gsub("^%s+", ""):gsub("%s+$", "")
    local cmd, rest = msg:match("^(%S+)%s*(.-)$")
    return cmd or "", rest or ""
end

local function GetTriggerModeLabel()
    if CONFIG.TriggerOnSpellSent and CONFIG.TriggerOnSpellSucceeded then
        return "both"
    end
    if CONFIG.TriggerOnSpellSent then
        return "sent"
    end
    return "succeeded"
end

local function ApplyTriggerMode(mode)
    if LOCK_MODE_TO_SENT and mode ~= "sent" then
        print("|cff33ff99CDMKeyPress:|r mode locked to sent")
        mode = "sent"
    end

    if mode == "sent" then
        CONFIG.TriggerOnSpellSent = true
        CONFIG.TriggerOnSpellSucceeded = false
    elseif mode == "succeeded" then
        CONFIG.TriggerOnSpellSent = false
        CONFIG.TriggerOnSpellSucceeded = true
    else
        CONFIG.TriggerOnSpellSent = true
        CONFIG.TriggerOnSpellSucceeded = true
        mode = "both"
    end
    print(("|cff33ff99CDMKeyPress:|r mode = %s"):format(mode))
end

local function RefreshQuickMenu()
    if not quickMenu then
        return
    end
    quickMenu.debugBtn:SetText(DEBUG and "Debug: ON" or "Debug: OFF")
    if LOCK_MODE_TO_SENT then
        quickMenu.modeBtn:SetText("Mode: sent (locked)")
    else
        quickMenu.modeBtn:SetText("Mode: " .. GetTriggerModeLabel())
    end
    if LOCK_PRESET_TO_DEFAULT then
        quickMenu.presetBtn:SetText("Preset: default (locked)")
    else
        quickMenu.presetBtn:SetText("Preset: " .. currentPresetName)
    end
end

local function CreateQuickMenu()
    if quickMenu then
        return quickMenu
    end

    local frame = CreateFrame("Frame", nil, UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(230, 198)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("TOP", 0, -8)
    title:SetText("CDMKeyPress")

    local function createButton(text, topOffset, onClick)
        local button = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        button:SetSize(182, 24)
        button:SetPoint("TOP", 0, topOffset)
        button:SetText(text)
        button:SetScript("OnClick", onClick)
        return button
    end

    frame.debugBtn = createButton("Debug: OFF", -30, function()
        SetDebugEnabled(not DEBUG)
        RefreshQuickMenu()
    end)

    frame.scanBtn = createButton("Scan", -58, function()
        RunScanNow("menu")
    end)

    frame.modeBtn = createButton("Mode: sent", -86, function()
        if LOCK_MODE_TO_SENT then
            print("|cff33ff99CDMKeyPress:|r mode locked to sent")
            RefreshQuickMenu()
            return
        end
        local mode = GetTriggerModeLabel()
        if mode == "both" then
            ApplyTriggerMode("sent")
        elseif mode == "sent" then
            ApplyTriggerMode("succeeded")
        else
            ApplyTriggerMode("both")
        end
        RefreshQuickMenu()
    end)

    frame.presetBtn = createButton("Preset: default", -114, function()
        if LOCK_PRESET_TO_DEFAULT then
            print("|cff33ff99CDMKeyPress:|r preset locked to default")
            RefreshQuickMenu()
            return
        end
        if currentPresetName == "blizzard" then
            ApplyVisualPreset("default")
        else
            ApplyVisualPreset("blizzard")
        end
        RefreshQuickMenu()
    end)

    frame.statusBtn = createButton("Status", -142, function()
        local loaded = cdmLoadedByName or autoDetectedByFrame
        print(("|cff33ff99CDMKeyPress:|r cdmLoaded=%s tracked=%d preset=%s mode=%s"):format(
            loaded and "true" or "false",
            CountTrackedFrames(),
            currentPresetName,
            GetTriggerModeLabel()
        ))
    end)

    quickMenu = frame
    RefreshQuickMenu()
    return quickMenu
end

local function ToggleQuickMenu()
    local menu = CreateQuickMenu()
    if menu:IsShown() then
        menu:Hide()
    else
        RefreshQuickMenu()
        menu:Show()
    end
end

SLASH_CDMKEYPRESS1 = "/cdmkp"
SlashCmdList.CDMKEYPRESS = function(msg)
    local cmd, rest = ParseSlash(msg)

    if cmd == "" then
        ToggleQuickMenu()
        return
    end

    if cmd == "status" then
        local cdmLoaded = cdmLoadedByName or autoDetectedByFrame
        local mode = autoDetectedByFrame and "frame-auto" or "name-match"
        print(("|cff33ff99CDMKeyPress:|r cdmLoaded=%s (%s) tracked=%d"):format(cdmLoaded and "true" or "false", mode, CountTrackedFrames()))
        print("|cff33ff99CDMKeyPress:|r candidates:", GetLoadedCandidatesText())
        print(("|cff33ff99CDMKeyPress:|r trigger: sent=%s succeeded=%s"):format(CONFIG.TriggerOnSpellSent and "1" or "0", CONFIG.TriggerOnSpellSucceeded and "1" or "0"))
        print(("|cff33ff99CDMKeyPress:|r preset=%s"):format(currentPresetName))
        return
    end

    if cmd == "addons" then
        PrintLoadedAddonHints()
        return
    end

    if cmd == "menu" then
        ToggleQuickMenu()
        return
    end

    if cmd == "debug" and rest == "on" then
        SetDebugEnabled(true)
        RefreshQuickMenu()
        return
    end

    if cmd == "debug" and rest == "off" then
        SetDebugEnabled(false)
        RefreshQuickMenu()
        return
    end

    if cmd == "mode" and rest == "sent" then
        ApplyTriggerMode("sent")
        RefreshQuickMenu()
        return
    end

    if cmd == "mode" and rest == "succeeded" then
        if LOCK_MODE_TO_SENT then
            print("|cff33ff99CDMKeyPress:|r mode locked to sent")
            return
        end
        ApplyTriggerMode("succeeded")
        RefreshQuickMenu()
        return
    end

    if cmd == "mode" and rest == "both" then
        if LOCK_MODE_TO_SENT then
            print("|cff33ff99CDMKeyPress:|r mode locked to sent")
            return
        end
        ApplyTriggerMode("both")
        RefreshQuickMenu()
        return
    end

    if cmd == "preset" and rest == "default" then
        ApplyVisualPreset(rest)
        RefreshQuickMenu()
        return
    end

    if cmd == "preset" and rest == "blizzard" then
        print("|cff33ff99CDMKeyPress:|r preset locked to default")
        return
    end

    if cmd == "scan" then
        RunScanNow("slash")
        return
    end

    if cmd == "test" then
        local spellID = ToSpellID(rest)
        if not spellID then
            print("|cff33ff99CDMKeyPress:|r usage: /cdmkp test <spellID>")
            return
        end
        local hits = TriggerForSpellID(spellID, "Test")
        print(("|cff33ff99CDMKeyPress:|r test %d -> %d frame(s)"):format(spellID, hits))
        return
    end

    print("|cff33ff99CDMKeyPress:|r commands: menu, status, addons, scan, preset default, mode sent, debug on|off, test <spellID>")
end

SLASH_CDMKEYPRESSSCAN1 = "/cdmkpscan"
SlashCmdList.CDMKEYPRESSSCAN = function()
    RunScanNow("slash-alias")
end

NS.CONFIG = CONFIG
NS.ScanForCDMIcons = ScanForCDMIcons
