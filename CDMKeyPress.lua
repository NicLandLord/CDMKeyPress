local ADDON_NAME, NS = ...

-- Runtime debug toggle via /cdmkp debug on|off
local DEBUG = false
local LOCK_MODE_TO_SENT = false
local LOCK_PRESET_TO_DEFAULT = false
local SAVED_VARIABLES_NAME = "CDMKeyPressDB"

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

    -- Legacy flash layer (quickslot glow). Disabled by default to keep pressed-only visuals.
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
    -- ElvUI-like "button pushed": flat additive yellow tint held while pressed.
    PressedTexturePath = "Interface\\Buttons\\WHITE8X8",
    PressedBlendMode = "ADD",
    PressedVertexColor = { 0.90, 0.80, 0.10 },
    PressedAlpha = 0.32,
    GlowEnabled = false,
    GlowTexturePath = "Interface\\Buttons\\UI-Quickslot2",
    GlowBlendMode = "ADD",
    GlowAlpha = 0.55,
    GlowBrightness = 1.00,
    GlowColor = { 1.00, 0.85, 0.25 },
    GlowLibFrameLevel = 8,
    GlowLibFrequency = 0,
    PressedMinHoldSeconds = 0.08,
    PressedMaxHoldSeconds = 0.20,
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
        PressedVertexColor = { 0.90, 0.80, 0.10 },
        PressedAlpha = 0.32,
        GlowEnabled = false,
        GlowAlpha = 0.55,
        GlowBrightness = 1.00,
        GlowColor = { 1.00, 0.85, 0.25 },
        GlowLibFrameLevel = 8,
        GlowLibFrequency = 0,
        PressedMinHoldSeconds = 0.08,
        PressedMaxHoldSeconds = 0.20,
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
        PressedVertexColor = { 0.95, 0.86, 0.18 },
        PressedAlpha = 0.40,
        GlowEnabled = true,
        GlowAlpha = 0.70,
        GlowBrightness = 1.10,
        GlowColor = { 1.00, 0.92, 0.45 },
        GlowLibFrameLevel = 8,
        GlowLibFrequency = 0,
        PressedMinHoldSeconds = 0.09,
        PressedMaxHoldSeconds = 0.18,
        FadeInDuration = 0.05,
        FadeOutDuration = 0.13,
    },
}

local PROFILE_CONFIG_KEYS = {
    "EnablePressFlash",
    "EnableTextureFallback",
    "PressBlendMode",
    "PressVertexColor",
    "PressPeakAlpha",
    "PressedTexturePath",
    "PressedBlendMode",
    "PressedVertexColor",
    "PressedAlpha",
    "GlowEnabled",
    "GlowAlpha",
    "GlowBrightness",
    "GlowColor",
    "GlowLibFrameLevel",
    "GlowLibFrequency",
    "PressedMinHoldSeconds",
    "PressedMaxHoldSeconds",
    "FadeInDuration",
    "FadeOutDuration",
}

local PROFILE_DEFAULTS = {
    currentPresetName = "default",
    triggerMode = "sent",
    config = {
        EnablePressFlash = false,
        EnableTextureFallback = true,
        PressBlendMode = "ADD",
        PressVertexColor = { 1.00, 0.95, 0.55 },
        PressPeakAlpha = 1.00,
        PressedTexturePath = "Interface\\Buttons\\WHITE8X8",
        PressedBlendMode = "ADD",
        PressedVertexColor = { 0.90, 0.80, 0.10 },
        PressedAlpha = 0.32,
        GlowEnabled = false,
        GlowAlpha = 0.55,
        GlowBrightness = 1.00,
        GlowColor = { 1.00, 0.85, 0.25 },
        GlowLibFrameLevel = 8,
        GlowLibFrequency = 0,
        PressedMinHoldSeconds = 0.08,
        PressedMaxHoldSeconds = 0.20,
        FadeInDuration = 0.10,
        FadeOutDuration = 0.20,
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
local viewerPoolAcquireHooked = setmetatable({}, { __mode = "k" })
local viewerPoolReleaseHooked = setmetatable({}, { __mode = "k" })
local viewerMixinHooked = {}
local ayijeQueueHooked = false
local queuedViewerRescanRoots = setmetatable({}, { __mode = "k" })
local viewerRescanTimer
local viewerRescanDelay
local viewerRescanFullScanQueued = false
local ScheduleViewerRescan
local EnsureViewerScanHooks
local ReleaseActivePressed
local UpdateGlowOverlay
local ApplyGlowState
local RefreshTrackedVisuals
local RefreshQuickMenu
local cachedCustomGlowLib
local savedDB
local activeProfile
local activeProfileName = "Default"
local activeProfileKey

local function GetCustomGlowLib()
    if cachedCustomGlowLib then
        return cachedCustomGlowLib
    end

    local libStub = _G.LibStub
    if type(libStub) == "table" and type(libStub.GetLibrary) == "function" then
        local ok, lib = pcall(libStub.GetLibrary, libStub, "LibCustomGlow-1.0", true)
        if ok and type(lib) == "table" then
            cachedCustomGlowLib = lib
            return lib
        end
    end

    if type(_G.LibCustomGlow) == "table" then
        cachedCustomGlowLib = _G.LibCustomGlow
        return cachedCustomGlowLib
    end

    return nil
end

local rootNameSet = {}
for _, name in ipairs(CONFIG.RootFrameNames) do
    rootNameSet[name] = true
end

local GLOW_COLOR_PRESETS = {
    { label = "Yellow", key = "yellow", color = { 1.00, 0.85, 0.25 } },
    { label = "White", key = "white", color = { 1.00, 1.00, 1.00 } },
    { label = "Orange", key = "orange", color = { 1.00, 0.62, 0.18 } },
    { label = "Red", key = "red", color = { 1.00, 0.20, 0.20 } },
    { label = "Green", key = "green", color = { 0.20, 0.95, 0.35 } },
    { label = "Cyan", key = "cyan", color = { 0.20, 0.90, 1.00 } },
    { label = "Blue", key = "blue", color = { 0.35, 0.55, 1.00 } },
    { label = "Purple", key = "purple", color = { 0.75, 0.45, 1.00 } },
}

local function Clamp(value, minValue, maxValue)
    if value < minValue then
        return minValue
    end
    if value > maxValue then
        return maxValue
    end
    return value
end

local function CopyRGB(color)
    if type(color) ~= "table" then
        return { 1, 1, 1 }
    end
    return {
        Clamp(tonumber(color[1]) or 1, 0, 1),
        Clamp(tonumber(color[2]) or 1, 0, 1),
        Clamp(tonumber(color[3]) or 1, 0, 1),
    }
end

local function CopyValue(value)
    if type(value) ~= "table" then
        return value
    end

    local out = {}
    for key, nestedValue in pairs(value) do
        out[key] = CopyValue(nestedValue)
    end
    return out
end

local function GetCharacterProfileKey()
    if type(GetUnitName) == "function" then
        local ok, fullName = pcall(GetUnitName, "player", true)
        if ok and type(fullName) == "string" and fullName ~= "" then
            return fullName
        end
    end

    local name
    local realm

    if type(UnitFullName) == "function" then
        local ok, resolvedName, resolvedRealm = pcall(UnitFullName, "player")
        if ok then
            name = resolvedName
            realm = resolvedRealm
        end
    end

    if (type(name) ~= "string" or name == "") and type(UnitName) == "function" then
        local ok, resolvedName = pcall(UnitName, "player")
        if ok then
            name = resolvedName
        end
    end

    if (type(realm) ~= "string" or realm == "") and type(GetRealmName) == "function" then
        local ok, resolvedRealm = pcall(GetRealmName)
        if ok then
            realm = resolvedRealm
        end
    end

    name = (type(name) == "string" and name ~= "") and name or "Unknown"
    realm = (type(realm) == "string" and realm ~= "") and realm or "UnknownRealm"
    return ("%s - %s"):format(name, realm)
end

local function EnsureProfileDefaults(profile)
    if type(profile) ~= "table" then
        profile = {}
    end

    if type(profile.config) ~= "table" then
        profile.config = {}
    end

    if type(profile.currentPresetName) ~= "string" or profile.currentPresetName == "" then
        profile.currentPresetName = PROFILE_DEFAULTS.currentPresetName
    end

    if type(profile.triggerMode) ~= "string" or profile.triggerMode == "" then
        profile.triggerMode = PROFILE_DEFAULTS.triggerMode
    end

    for i = 1, #PROFILE_CONFIG_KEYS do
        local key = PROFILE_CONFIG_KEYS[i]
        if profile.config[key] == nil then
            profile.config[key] = CopyValue(PROFILE_DEFAULTS.config[key])
        end
    end

    return profile
end

local function PersistActiveProfile()
    if type(activeProfile) ~= "table" then
        return
    end

    activeProfile.currentPresetName = currentPresetName
    if LOCK_MODE_TO_SENT then
        activeProfile.triggerMode = "sent"
    elseif CONFIG.TriggerOnSpellSent and CONFIG.TriggerOnSpellSucceeded then
        activeProfile.triggerMode = "both"
    elseif CONFIG.TriggerOnSpellSucceeded then
        activeProfile.triggerMode = "succeeded"
    else
        activeProfile.triggerMode = "sent"
    end

    if type(activeProfile.config) ~= "table" then
        activeProfile.config = {}
    end

    for i = 1, #PROFILE_CONFIG_KEYS do
        local key = PROFILE_CONFIG_KEYS[i]
        activeProfile.config[key] = CopyValue(CONFIG[key])
    end
end

local function CreateProfileSnapshot()
    local profile = EnsureProfileDefaults(CopyValue(PROFILE_DEFAULTS))
    activeProfile = profile
    PersistActiveProfile()
    activeProfile = nil
    return profile
end

local function RebindCharacterProfileKey()
    if type(savedDB) ~= "table" or type(savedDB.profileKeys) ~= "table" then
        return nil
    end

    local charKey = GetCharacterProfileKey()
    if type(charKey) ~= "string" or charKey == "" then
        return nil
    end

    if type(activeProfileKey) == "string"
        and activeProfileKey ~= charKey
        and savedDB.profileKeys[activeProfileKey] == activeProfileName then
        savedDB.profileKeys[activeProfileKey] = nil
    end

    savedDB.profileKeys[charKey] = activeProfileName
    activeProfileKey = charKey
    NS.ProfileKey = activeProfileKey
    return charKey
end

local function ApplyProfileToConfig(profile)
    if type(profile) ~= "table" then
        return
    end

    profile = EnsureProfileDefaults(profile)

    currentPresetName = profile.currentPresetName

    for i = 1, #PROFILE_CONFIG_KEYS do
        local key = PROFILE_CONFIG_KEYS[i]
        if profile.config[key] ~= nil then
            CONFIG[key] = CopyValue(profile.config[key])
        end
    end

    local triggerMode = profile.triggerMode
    if LOCK_MODE_TO_SENT then
        CONFIG.TriggerOnSpellSent = true
        CONFIG.TriggerOnSpellSucceeded = false
    elseif triggerMode == "both" then
        CONFIG.TriggerOnSpellSent = true
        CONFIG.TriggerOnSpellSucceeded = true
    elseif triggerMode == "succeeded" then
        CONFIG.TriggerOnSpellSent = false
        CONFIG.TriggerOnSpellSucceeded = true
    else
        CONFIG.TriggerOnSpellSent = true
        CONFIG.TriggerOnSpellSucceeded = false
    end
end

local function InitializeProfileDB()
    local db = _G[SAVED_VARIABLES_NAME]
    if type(db) ~= "table" then
        db = {}
        _G[SAVED_VARIABLES_NAME] = db
    end

    if type(db.profileKeys) ~= "table" then
        db.profileKeys = {}
    end
    if type(db.profiles) ~= "table" then
        db.profiles = {}
    end

    local charKey = GetCharacterProfileKey()
    local profileName = db.profileKeys[charKey]
    if type(profileName) ~= "string" or profileName == "" then
        profileName = "Default"
        db.profileKeys[charKey] = profileName
    end

    local profile = EnsureProfileDefaults(db.profiles[profileName])
    db.profiles[profileName] = profile

    savedDB = db
    activeProfileName = profileName
    activeProfile = profile
    activeProfileKey = charKey

    ApplyProfileToConfig(profile)
    PersistActiveProfile()
    RebindCharacterProfileKey()

    NS.DB = savedDB
    NS.Profile = activeProfile
    NS.ProfileName = activeProfileName
end

local function SwitchProfile(profileName)
    if type(profileName) ~= "string" then
        return false
    end

    profileName = profileName:gsub("^%s+", ""):gsub("%s+$", "")
    if profileName == "" then
        return false
    end

    if type(savedDB) ~= "table" then
        InitializeProfileDB()
    end

    local profile = savedDB.profiles[profileName]
    if type(profile) ~= "table" then
        profile = CreateProfileSnapshot()
    else
        profile = EnsureProfileDefaults(profile)
    end

    savedDB.profiles[profileName] = profile

    activeProfileName = profileName
    activeProfile = profile
    RebindCharacterProfileKey()

    ApplyProfileToConfig(profile)
    RefreshTrackedVisuals()
    PersistActiveProfile()
    RefreshQuickMenu()

    NS.Profile = activeProfile
    NS.ProfileName = activeProfileName

    print(("|cff33ff99CDMKeyPress:|r profile = %s"):format(activeProfileName))
    return true
end

local function ResetActiveProfile()
    if type(savedDB) ~= "table" then
        InitializeProfileDB()
    end

    local resetProfile = EnsureProfileDefaults(CopyValue(PROFILE_DEFAULTS))
    savedDB.profiles[activeProfileName] = resetProfile
    activeProfile = resetProfile

    ApplyProfileToConfig(resetProfile)
    RefreshTrackedVisuals()
    PersistActiveProfile()
    RebindCharacterProfileKey()
    RefreshQuickMenu()

    NS.Profile = activeProfile

    print(("|cff33ff99CDMKeyPress:|r profile %s reset"):format(activeProfileName))
end

local function FindGlowPresetIndexByColor(color)
    if type(color) ~= "table" then
        return nil
    end
    local r = tonumber(color[1]) or 0
    local g = tonumber(color[2]) or 0
    local b = tonumber(color[3]) or 0
    for i = 1, #GLOW_COLOR_PRESETS do
        local c = GLOW_COLOR_PRESETS[i].color
        if math.abs((c[1] or 0) - r) < 0.001
            and math.abs((c[2] or 0) - g) < 0.001
            and math.abs((c[3] or 0) - b) < 0.001 then
            return i
        end
    end
    return nil
end

local function GetGlowColorLabel()
    local index = FindGlowPresetIndexByColor(CONFIG.GlowColor)
    if index then
        return GLOW_COLOR_PRESETS[index].label
    end
    return "Custom"
end

local function GetGlowBackendLabel()
    local lib = GetCustomGlowLib()
    if lib and type(lib.ButtonGlow_Start) == "function" and type(lib.ButtonGlow_Stop) == "function" then
        return "libcustomglow"
    end
    return "overlay"
end

local function ParseColorTriple(r, g, b)
    local rr = tonumber(r)
    local gg = tonumber(g)
    local bb = tonumber(b)
    if not rr or not gg or not bb then
        return nil
    end

    if rr > 1 or gg > 1 or bb > 1 then
        rr = rr / 255
        gg = gg / 255
        bb = bb / 255
    end

    return {
        Clamp(rr, 0, 1),
        Clamp(gg, 0, 1),
        Clamp(bb, 0, 1),
    }
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

local function ToPlainString(value)
    if value == nil then
        return nil
    end

    local ok, asString = pcall(function()
        return tostring(value)
    end)
    if not ok or type(asString) ~= "string" then
        return nil
    end

    local okLen, length = pcall(string.len, asString)
    if not okLen or type(length) ~= "number" or length <= 0 then
        return nil
    end

    return asString
end

local function ToNormalizedString(value)
    local asString = ToPlainString(value)
    if not asString then
        return nil
    end

    local ok, lowered = pcall(string.lower, asString)
    if ok and type(lowered) == "string" then
        local okLen, length = pcall(string.len, lowered)
        if okLen and type(length) == "number" and length > 0 then
            return lowered
        end
    end

    local okLen, length = pcall(string.len, asString)
    if okLen and type(length) == "number" and length > 0 then
        return asString
    end

    return nil
end

local function SafeValuesEqual(left, right)
    local ok, result = pcall(function()
        return left == right
    end)
    return ok and result or false
end

local function ToPlainNumber(value)
    local asString = ToPlainString(value)
    if not asString then
        return nil
    end

    local ok, numberValue = pcall(tonumber, asString)
    if not ok or type(numberValue) ~= "number" then
        return nil
    end

    return numberValue
end

local function ToPositiveIntegerString(value)
    local numberValue = ToPlainNumber(value)
    if type(numberValue) ~= "number" then
        return nil
    end

    local rounded = tostring(math.floor(numberValue + 0.5))
    local okLen, length = pcall(string.len, rounded)
    if not okLen or type(length) ~= "number" or length <= 0 then
        return nil
    end

    if rounded == "0" or rounded == "-0" then
        return nil
    end

    local okSub, firstChar = pcall(string.sub, rounded, 1, 1)
    if not okSub or firstChar == "-" then
        return nil
    end

    return rounded
end

local function ToSpellID(value)
    local integerString = ToPositiveIntegerString(value)
    if integerString then
        return tonumber(integerString)
    end

    return nil
end

local function NormalizeSpellName(name)
    return ToNormalizedString(name)
end

local function NormalizeTextureKey(texture)
    if texture == nil then
        return nil
    end

    local numericTexture = ToPositiveIntegerString(texture)
    if numericTexture then
        return numericTexture
    end

    return ToNormalizedString(texture)
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
        if type(info) == "table" then
            local spellID = ToSpellID(info.spellID)
            if spellID then
                return spellID
            end
        end
    end

    if GetSpellInfo then
        local _, _, _, _, _, _, spellID = GetSpellInfo(spellName)
        spellID = ToSpellID(spellID)
        if spellID then
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

local function SpellIDFromCooldownInfo(info)
    if type(info) ~= "table" then
        return nil
    end

    local sid = ToSpellID(info.overrideSpellID or info.overrideTooltipSpellID or info.spellID or info.linkedSpellID)
    if sid then
        return sid
    end

    if type(info.linkedSpellIDs) == "table" then
        for i = 1, #info.linkedSpellIDs do
            sid = ToSpellID(info.linkedSpellIDs[i])
            if sid then
                return sid
            end
        end
    end

    return nil
end

local function ExtractSpellID(frame)
    if not frame then
        return nil
    end

    -- Ayije_CDM frequently exposes spell via GetCooldownInfo()
    if type(frame.GetCooldownInfo) == "function" then
        local ok, info = pcall(frame.GetCooldownInfo, frame)
        if ok and type(info) == "table" then
            local sid = SpellIDFromCooldownInfo(info)
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
            local sid = SpellIDFromCooldownInfo(info)
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

local function UntrackIconFrame(frame)
    if not frame then
        return
    end

    if SafeTableGet(trackedFrames, frame) then
        UnindexFrameAll(frame)
        SafeTableSet(trackedFrames, frame, nil)
    end

    if activePressedState and type(activePressedState.frames) == "table" and activePressedState.frames[frame] then
        activePressedState.frames[frame] = nil
    end

    if frame.__cdmkpPressedOverlay then
        frame.__cdmkpPressedOverlay:SetAlpha(0)
    end
    frame.__cdmkpGlowActive = nil
    if ApplyGlowState then
        ApplyGlowState(frame)
    end
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

    if previous and not SafeValuesEqual(previous, nameKey) then
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
    textureKey = NormalizeTextureKey(textureKey)
    local previous = frame.__cdmkpTextureKey

    if previous and not SafeValuesEqual(previous, textureKey) then
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

    local glowOverlay = frame:CreateTexture(nil, "OVERLAY")
    glowOverlay:SetAllPoints(frame)
    glowOverlay:SetDrawLayer("OVERLAY", 6)
    glowOverlay:SetTexture(CONFIG.GlowTexturePath or "Interface\\Buttons\\UI-Quickslot2")
    glowOverlay:SetBlendMode(CONFIG.GlowBlendMode or "ADD")
    glowOverlay:SetAlpha(0)

    local pressedOverlay = frame:CreateTexture(nil, "OVERLAY")
    pressedOverlay:SetAllPoints(frame)
    pressedOverlay:SetDrawLayer("OVERLAY", 7)
    pressedOverlay:SetTexture(CONFIG.PressedTexturePath)
    pressedOverlay:SetBlendMode(CONFIG.PressedBlendMode or "ADD")
    pressedOverlay:SetVertexColor(unpack(CONFIG.PressedVertexColor))
    pressedOverlay:SetAlpha(0)

    frame.__cdmkpPressOverlay = overlay
    frame.__cdmkpPressAnim = anim
    frame.__cdmkpPressFadeIn = fadeIn
    frame.__cdmkpPressFadeOut = fadeOut
    frame.__cdmkpGlowOverlay = glowOverlay
    frame.__cdmkpPressedOverlay = pressedOverlay

    -- ElvUI pattern 2: hard cleanup on frame hide to avoid stuck pressed state/glow.
    if frame.HookScript and not frame.__cdmkpOnHideHooked then
        frame.__cdmkpOnHideHooked = true
        frame:HookScript("OnHide", function(self)
            local pressAnim = self.__cdmkpPressAnim
            if pressAnim and pressAnim.Stop then
                pressAnim:Stop()
            end

            if self.__cdmkpPressOverlay then
                self.__cdmkpPressOverlay:SetAlpha(0)
            end
            if self.__cdmkpPressedOverlay then
                self.__cdmkpPressedOverlay:SetAlpha(0)
            end

            self.__cdmkpGlowActive = nil
            ApplyGlowState(self)
        end)
    end

    UpdateGlowOverlay(frame)
end

local function GetGlowTintRGBA()
    local color = CopyRGB(CONFIG.GlowColor)
    local brightness = Clamp(tonumber(CONFIG.GlowBrightness) or 1, 0.1, 3.0)
    local r = Clamp((color[1] or 1) * brightness, 0, 1)
    local g = Clamp((color[2] or 1) * brightness, 0, 1)
    local b = Clamp((color[3] or 1) * brightness, 0, 1)
    local a = Clamp(tonumber(CONFIG.GlowAlpha) or 0.55, 0, 1)
    return r, g, b, a
end

UpdateGlowOverlay = function(frame)
    local glow = frame.__cdmkpGlowOverlay
    if not glow then
        return
    end

    local r, g, b, a = GetGlowTintRGBA()

    glow:SetTexture(CONFIG.GlowTexturePath or "Interface\\Buttons\\UI-Quickslot2")
    glow:SetBlendMode(CONFIG.GlowBlendMode or "ADD")
    glow:SetVertexColor(r, g, b, 1)

    if frame.__cdmkpGlowUsingLib then
        glow:SetAlpha(0)
    elseif CONFIG.GlowEnabled and frame.__cdmkpGlowActive then
        glow:SetAlpha(a)
    else
        glow:SetAlpha(0)
    end
end

ApplyGlowState = function(frame)
    local wantGlow = CONFIG.GlowEnabled and frame.__cdmkpGlowActive
    local lib = GetCustomGlowLib()

    if wantGlow and lib and type(lib.ButtonGlow_Start) == "function" then
        local r, g, b, a = GetGlowTintRGBA()
        local color = { r, g, b, a }
        local frequency = tonumber(CONFIG.GlowLibFrequency)
        if frequency and frequency <= 0 then
            frequency = nil
        end

        local frameLevel = tonumber(CONFIG.GlowLibFrameLevel) or 8
        frameLevel = Clamp(math.floor(frameLevel + 0.5), 0, 32)

        local ok = pcall(lib.ButtonGlow_Start, frame, color, frequency, frameLevel)
        frame.__cdmkpGlowUsingLib = ok and true or nil
    else
        if frame.__cdmkpGlowUsingLib and lib and type(lib.ButtonGlow_Stop) == "function" then
            pcall(lib.ButtonGlow_Stop, frame)
        end
        frame.__cdmkpGlowUsingLib = nil
    end

    UpdateGlowOverlay(frame)
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
    if not overlay then
        return
    end

    overlay:SetAlpha(CONFIG.PressedAlpha)
    frame.__cdmkpGlowActive = true
    ApplyGlowState(frame)
end

local function HidePressedTint(frame)
    local overlay = frame.__cdmkpPressedOverlay
    if not overlay then
        return
    end
    overlay:SetAlpha(0)
    frame.__cdmkpGlowActive = nil
    ApplyGlowState(frame)
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
        return false
    end

    local objectType = frame.GetObjectType and frame:GetObjectType()
    if objectType ~= "Button" and objectType ~= "Frame" then
        return false
    end

    if not IsLikelyCDMContext(frame) then
        return false
    end

    local namedLikeIcon = MatchAnyPattern(GetFrameName(frame), CONFIG.IconNamePatterns)
    if not HasIconTexture(frame) and not namedLikeIcon then
        return false
    end

    local spellID = ExtractSpellID(frame)
    local spellName = ExtractSpellName(frame, spellID)
    local textureKey = ExtractFrameTextureKey(frame)
    local spellNameKey = NormalizeSpellName(spellName)

    -- Must have at least one useful link to cast payload.
    if not spellID and not spellNameKey and not textureKey then
        if SafeTableGet(trackedFrames, frame) then
            UnindexFrameAll(frame)
        end
        return false
    end

    local isNew = not SafeTableGet(trackedFrames, frame)

    if not isNew
        and SafeValuesEqual(frame.__cdmkpSpellID, spellID)
        and SafeValuesEqual(frame.__cdmkpSpellNameKey, spellNameKey)
        and SafeValuesEqual(frame.__cdmkpTextureKey, textureKey) then
        return true
    end

    SafeTableSet(trackedFrames, frame, true)

    EnsurePressAnimation(frame)

    if spellID then
        IndexFrameSpell(frame, spellID)
    else
        UnindexFrameSpell(frame)
    end
    IndexFrameName(frame, spellNameKey)
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

    return true
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

local function RunScanForRoot(root, budget)
    if not root or budget <= 0 then
        return 0
    end

    local scanned = 0
    local remaining = budget

    local poolUsed = ScanViewerPoolFrames(root, remaining)
    scanned = scanned + poolUsed
    remaining = remaining - poolUsed

    if remaining > 0 then
        local used = ScanSubtree(root, remaining)
        scanned = scanned + used
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
            local used = RunScanForRoot(roots[i], budget)
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

RefreshTrackedVisuals = function()
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

        ApplyGlowState(frame)
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
    PersistActiveProfile()
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

local function FlushQueuedViewerRescans()
    viewerRescanTimer = nil
    viewerRescanDelay = nil

    local runFullScan = viewerRescanFullScanQueued
    local queuedRoots = queuedViewerRescanRoots

    viewerRescanFullScanQueued = false
    queuedViewerRescanRoots = setmetatable({}, { __mode = "k" })

    if runFullScan then
        pcall(ScanForCDMIcons)
        return
    end

    local budget = CONFIG.MaxFramesPerScan
    for root in pairs(queuedRoots) do
        if budget <= 0 then
            break
        end

        local ok, scanned = pcall(RunScanForRoot, root, budget)
        if ok and type(scanned) == "number" then
            budget = budget - scanned
        end
    end
end

ScheduleViewerRescan = function(rootOrDelay, delaySeconds)
    local root = nil
    local delay = delaySeconds

    if type(rootOrDelay) == "number" then
        delay = rootOrDelay
    elseif type(rootOrDelay) == "table" then
        root = rootOrDelay
    end

    delay = delay or 0.05

    if root then
        queuedViewerRescanRoots[root] = true
    else
        viewerRescanFullScanQueued = true
    end

    if viewerRescanTimer and viewerRescanDelay and delay >= viewerRescanDelay then
        return
    end

    if viewerRescanTimer then
        viewerRescanTimer:Cancel()
        viewerRescanTimer = nil
    end

    viewerRescanDelay = delay
    viewerRescanTimer = C_Timer.NewTimer(delay, FlushQueuedViewerRescans)
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

local function ResolveViewerRoot(frame, expectedViewerName)
    if not frame then
        return nil
    end

    local viewer = frame.viewerFrame
    if not viewer and type(frame.GetViewerFrame) == "function" then
        local ok, result = pcall(frame.GetViewerFrame, frame)
        if ok then
            viewer = result
        end
    end

    if viewer then
        if not expectedViewerName or (viewer.GetName and viewer:GetName() == expectedViewerName) then
            return viewer
        end
    end

    local parent = frame.GetParent and frame:GetParent()
    local depth = 0
    while parent and depth < 5 do
        local parentName = GetFrameName(parent)
        if expectedViewerName then
            if parentName == expectedViewerName then
                return parent
            end
        elseif IsKnownViewerName(parentName) then
            return parent
        end

        parent = parent.GetParent and parent:GetParent()
        depth = depth + 1
    end

    if expectedViewerName then
        return _G[expectedViewerName]
    end

    return nil
end

local function DoesFrameBelongToViewer(frame, expectedViewerName)
    return ResolveViewerRoot(frame, expectedViewerName) ~= nil
end

local function HookViewerItemMixin(mixinName, expectedViewerName)
    local mixin = _G[mixinName]
    if type(mixin) ~= "table" then
        return
    end
    if viewerMixinHooked[mixinName] then
        return
    end
    viewerMixinHooked[mixinName] = true

    local function onMixinEvent(frame)
        if not frame or IsForbiddenSafe(frame) then
            return
        end
        if expectedViewerName and not DoesFrameBelongToViewer(frame, expectedViewerName) then
            return
        end

        local tracked = TrackIconFrame(frame)
        if not tracked then
            ScheduleViewerRescan(ResolveViewerRoot(frame, expectedViewerName), 0.05)
        end
    end

    if type(mixin.OnCooldownIDSet) == "function" then
        hooksecurefunc(mixin, "OnCooldownIDSet", onMixinEvent)
    end
    if type(mixin.OnActiveStateChanged) == "function" then
        hooksecurefunc(mixin, "OnActiveStateChanged", onMixinEvent)
    end
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
                        ScheduleViewerRescan(frame, 0.05)
                    end)
                end

                if frame.HookScript then
                    frame:HookScript("OnShow", function()
                        ScheduleViewerRescan(frame, 0.05)
                    end)
                end

                local pool = frame.itemFramePool
                if pool then
                    if not viewerPoolAcquireHooked[pool] and type(pool.Acquire) == "function" then
                        viewerPoolAcquireHooked[pool] = true
                        hooksecurefunc(pool, "Acquire", function(_, acquiredFrame)
                            if acquiredFrame then
                                TrackIconFrame(acquiredFrame)
                            end
                            ScheduleViewerRescan(frame, 0.05)
                        end)
                    end
                    if not viewerPoolReleaseHooked[pool] and type(pool.Release) == "function" then
                        viewerPoolReleaseHooked[pool] = true
                        hooksecurefunc(pool, "Release", function(_, releasedFrame)
                            if releasedFrame then
                                UntrackIconFrame(releasedFrame)
                            end
                        end)
                    end
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
                ScheduleViewerRescan(viewerName and _G[viewerName] or nil, 0.05)
            end
        end)
    end

    -- Ayije_CDM pattern: react immediately when Blizzard viewer item mixins set/activate cooldown IDs.
    HookViewerItemMixin("CooldownViewerEssentialItemMixin", "EssentialCooldownViewer")
    HookViewerItemMixin("CooldownViewerUtilityItemMixin", "UtilityCooldownViewer")
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
        InitializeProfileDB()
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
        if type(savedDB) ~= "table" then
            InitializeProfileDB()
        else
            RebindCharacterProfileKey()
        end
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
    PersistActiveProfile()
    print(("|cff33ff99CDMKeyPress:|r mode = %s"):format(mode))
end

local function SetGlowEnabled(enabled)
    CONFIG.GlowEnabled = enabled and true or false
    if not CONFIG.GlowEnabled then
        for frame in pairs(trackedFrames) do
            frame.__cdmkpGlowActive = nil
            ApplyGlowState(frame)
        end
    else
        RefreshTrackedVisuals()
    end
    PersistActiveProfile()
    print(("|cff33ff99CDMKeyPress:|r glow = %s (%s)"):format(
        CONFIG.GlowEnabled and "on" or "off",
        GetGlowBackendLabel()
    ))
end

local function SetGlowAlpha(value)
    CONFIG.GlowAlpha = Clamp(tonumber(value) or CONFIG.GlowAlpha or 0.55, 0, 1)
    RefreshTrackedVisuals()
    PersistActiveProfile()
    print(("|cff33ff99CDMKeyPress:|r glow alpha = %.2f"):format(CONFIG.GlowAlpha))
end

local function SetGlowBrightness(value)
    CONFIG.GlowBrightness = Clamp(tonumber(value) or CONFIG.GlowBrightness or 1, 0.1, 3.0)
    RefreshTrackedVisuals()
    PersistActiveProfile()
    print(("|cff33ff99CDMKeyPress:|r glow brightness = %.2f"):format(CONFIG.GlowBrightness))
end

local function SetGlowColor(color)
    CONFIG.GlowColor = CopyRGB(color)
    RefreshTrackedVisuals()
    PersistActiveProfile()
    print(("|cff33ff99CDMKeyPress:|r glow color = %.2f %.2f %.2f"):format(
        CONFIG.GlowColor[1] or 1,
        CONFIG.GlowColor[2] or 1,
        CONFIG.GlowColor[3] or 1
    ))
end

local function SetGlowColorByPresetIndex(index)
    if type(index) ~= "number" or index < 1 or index > #GLOW_COLOR_PRESETS then
        return
    end
    SetGlowColor(GLOW_COLOR_PRESETS[index].color)
end

RefreshQuickMenu = function()
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
    if quickMenu.glowBtn then
        quickMenu.glowBtn:SetText(("Glow: %s (%s)"):format(
            CONFIG.GlowEnabled and "ON" or "OFF",
            GetGlowBackendLabel()
        ))
    end
    if quickMenu.glowAlphaBtn then
        quickMenu.glowAlphaBtn:SetText(("Glow Alpha: %.2f"):format(CONFIG.GlowAlpha or 0))
    end
    if quickMenu.glowBrightnessBtn then
        quickMenu.glowBrightnessBtn:SetText(("Glow Brightness: %.2f"):format(CONFIG.GlowBrightness or 1))
    end
    if quickMenu.glowColorBtn then
        quickMenu.glowColorBtn:SetText("Glow Color: " .. GetGlowColorLabel())
    end
end

local function CreateQuickMenu()
    if quickMenu then
        return quickMenu
    end

    local frame = CreateFrame("Frame", nil, UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(230, 314)
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
        button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
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

    frame.glowBtn = createButton("Glow: OFF", -142, function()
        SetGlowEnabled(not CONFIG.GlowEnabled)
        RefreshQuickMenu()
    end)

    frame.glowAlphaBtn = createButton("Glow Alpha: 0.55", -170, function(_, mouseButton)
        local step = (mouseButton == "RightButton") and -0.05 or 0.05
        SetGlowAlpha((CONFIG.GlowAlpha or 0.55) + step)
        RefreshQuickMenu()
    end)

    frame.glowBrightnessBtn = createButton("Glow Brightness: 1.00", -198, function(_, mouseButton)
        local step = (mouseButton == "RightButton") and -0.10 or 0.10
        SetGlowBrightness((CONFIG.GlowBrightness or 1.00) + step)
        RefreshQuickMenu()
    end)

    frame.glowColorBtn = createButton("Glow Color: Yellow", -226, function(_, mouseButton)
        local index = FindGlowPresetIndexByColor(CONFIG.GlowColor) or 1
        if mouseButton == "RightButton" then
            index = index - 1
            if index < 1 then
                index = #GLOW_COLOR_PRESETS
            end
        else
            index = index + 1
            if index > #GLOW_COLOR_PRESETS then
                index = 1
            end
        end
        SetGlowColorByPresetIndex(index)
        RefreshQuickMenu()
    end)

    frame.statusBtn = createButton("Status", -254, function()
        local loaded = cdmLoadedByName or autoDetectedByFrame
        print(("|cff33ff99CDMKeyPress:|r profile=%s cdmLoaded=%s tracked=%d preset=%s mode=%s glow=%s backend=%s alpha=%.2f bright=%.2f color=%s"):format(
            activeProfileName or "Default",
            loaded and "true" or "false",
            CountTrackedFrames(),
            currentPresetName,
            GetTriggerModeLabel(),
            CONFIG.GlowEnabled and "on" or "off",
            GetGlowBackendLabel(),
            CONFIG.GlowAlpha or 0,
            CONFIG.GlowBrightness or 1,
            GetGlowColorLabel()
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
        print(("|cff33ff99CDMKeyPress:|r profile=%s"):format(activeProfileName or "Default"))
        print(("|cff33ff99CDMKeyPress:|r cdmLoaded=%s (%s) tracked=%d"):format(cdmLoaded and "true" or "false", mode, CountTrackedFrames()))
        print("|cff33ff99CDMKeyPress:|r candidates:", GetLoadedCandidatesText())
        print(("|cff33ff99CDMKeyPress:|r trigger: sent=%s succeeded=%s"):format(CONFIG.TriggerOnSpellSent and "1" or "0", CONFIG.TriggerOnSpellSucceeded and "1" or "0"))
        print(("|cff33ff99CDMKeyPress:|r preset=%s"):format(currentPresetName))
        print(("|cff33ff99CDMKeyPress:|r glow=%s backend=%s alpha=%.2f brightness=%.2f color=%.2f %.2f %.2f (%s)"):format(
            CONFIG.GlowEnabled and "on" or "off",
            GetGlowBackendLabel(),
            CONFIG.GlowAlpha or 0,
            CONFIG.GlowBrightness or 1,
            (CONFIG.GlowColor and CONFIG.GlowColor[1]) or 1,
            (CONFIG.GlowColor and CONFIG.GlowColor[2]) or 1,
            (CONFIG.GlowColor and CONFIG.GlowColor[3]) or 1,
            GetGlowColorLabel()
        ))
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

    if cmd == "profile" then
        local action, arg = rest:match("^(%S*)%s*(.-)$")
        action = action or ""
        arg = arg or ""

        if action == "" or action == "status" then
            print(("|cff33ff99CDMKeyPress:|r profile = %s"):format(activeProfileName or "Default"))
            return
        end

        if action == "set" then
            if SwitchProfile(arg) then
                print("|cff33ff99CDMKeyPress:|r reload not required")
            else
                print("|cff33ff99CDMKeyPress:|r usage: /cdmkp profile set <name>")
            end
            return
        end

        if action == "reset" then
            ResetActiveProfile()
            return
        end

        print("|cff33ff99CDMKeyPress:|r profile commands: profile status, profile set <name>, profile reset")
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

    if cmd == "glow" then
        local action, arg1, arg2, arg3 = rest:match("^(%S*)%s*(%S*)%s*(%S*)%s*(%S*)$")
        action = action or ""

        if action == "on" then
            SetGlowEnabled(true)
            RefreshQuickMenu()
            return
        end

        if action == "off" then
            SetGlowEnabled(false)
            RefreshQuickMenu()
            return
        end

        if action == "alpha" then
            local value = tonumber(arg1)
            if not value then
                print("|cff33ff99CDMKeyPress:|r usage: /cdmkp glow alpha <0-1>")
                return
            end
            SetGlowAlpha(value)
            RefreshQuickMenu()
            return
        end

        if action == "brightness" or action == "bright" then
            local value = tonumber(arg1)
            if not value then
                print("|cff33ff99CDMKeyPress:|r usage: /cdmkp glow brightness <0.1-3>")
                return
            end
            SetGlowBrightness(value)
            RefreshQuickMenu()
            return
        end

        if action == "color" then
            if arg1 and arg2 and arg3 and arg1 ~= "" and arg2 ~= "" and arg3 ~= "" then
                local color = ParseColorTriple(arg1, arg2, arg3)
                if not color then
                    print("|cff33ff99CDMKeyPress:|r usage: /cdmkp glow color <r g b> (0-1 or 0-255)")
                    return
                end
                SetGlowColor(color)
                RefreshQuickMenu()
                return
            end

            local presetKey = arg1 and arg1:lower() or ""
            for i = 1, #GLOW_COLOR_PRESETS do
                if GLOW_COLOR_PRESETS[i].key == presetKey then
                    SetGlowColorByPresetIndex(i)
                    RefreshQuickMenu()
                    return
                end
            end

            print("|cff33ff99CDMKeyPress:|r usage: /cdmkp glow color <r g b> or /cdmkp glow color <yellow|white|orange|red|green|cyan|blue|purple>")
            return
        end

        print("|cff33ff99CDMKeyPress:|r glow commands: glow on|off, glow alpha <0-1>, glow brightness <0.1-3>, glow color <r g b|preset>")
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
        if LOCK_PRESET_TO_DEFAULT then
            print("|cff33ff99CDMKeyPress:|r preset locked to default")
            return
        end
        ApplyVisualPreset(rest)
        RefreshQuickMenu()
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

    local modeHelp = LOCK_MODE_TO_SENT and "mode sent" or "mode sent|succeeded|both"
    local presetHelp = LOCK_PRESET_TO_DEFAULT and "preset default" or "preset default|blizzard"
    print(("|cff33ff99CDMKeyPress:|r commands: menu, status, addons, scan, profile status|set|reset, %s, %s, glow on|off|alpha|brightness|color, debug on|off, test <spellID>"):format(presetHelp, modeHelp))
end

SLASH_CDMKEYPRESSSCAN1 = "/cdmkpscan"
SlashCmdList.CDMKEYPRESSSCAN = function()
    RunScanNow("slash-alias")
end

NS.CONFIG = CONFIG
NS.ScanForCDMIcons = ScanForCDMIcons
NS.SwitchProfile = SwitchProfile
