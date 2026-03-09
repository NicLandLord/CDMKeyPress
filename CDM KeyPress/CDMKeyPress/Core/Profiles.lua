local _, NS = ...

local Private = NS.Private
local CONFIG = Private.CONFIG
local PROFILE_CONFIG_KEYS = Private.PROFILE_CONFIG_KEYS
local PROFILE_DEFAULTS = Private.PROFILE_DEFAULTS
local GLOW_COLOR_PRESETS = Private.GLOW_COLOR_PRESETS
local L = Private.L
local state = Private.state

local Clamp = Private.Clamp
local CopyRGB = Private.CopyRGB
local CopyValue = Private.CopyValue
local PrintInfo = Private.PrintInfo

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
    if profile.currentPresetName == "flash" then
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
    if profile.config.GlowButtonFrequency == nil then
        profile.config.GlowButtonFrequency = CopyValue(profile.config.GlowLibFrequency or PROFILE_DEFAULTS.config.GlowButtonFrequency)
    end
    profile.config.EnablePressFlash = true

    return profile
end

local function PersistActiveProfile()
    if type(state.activeProfile) ~= "table" then
        return
    end

    state.activeProfile.currentPresetName = state.currentPresetName
    if Private.LOCK_MODE_TO_SENT then
        state.activeProfile.triggerMode = "sent"
    elseif CONFIG.TriggerOnSpellSent and CONFIG.TriggerOnSpellSucceeded then
        state.activeProfile.triggerMode = "both"
    elseif CONFIG.TriggerOnSpellSucceeded then
        state.activeProfile.triggerMode = "succeeded"
    else
        state.activeProfile.triggerMode = "sent"
    end

    if type(state.activeProfile.config) ~= "table" then
        state.activeProfile.config = {}
    end

    for i = 1, #PROFILE_CONFIG_KEYS do
        local key = PROFILE_CONFIG_KEYS[i]
        state.activeProfile.config[key] = CopyValue(CONFIG[key])
    end
end

local function CreateProfileSnapshot()
    local profile = EnsureProfileDefaults(CopyValue(PROFILE_DEFAULTS))
    state.activeProfile = profile
    PersistActiveProfile()
    state.activeProfile = nil
    return profile
end

local function RebindCharacterProfileKey()
    if type(state.savedDB) ~= "table" or type(state.savedDB.profileKeys) ~= "table" then
        return nil
    end

    local charKey = GetCharacterProfileKey()
    if type(charKey) ~= "string" or charKey == "" then
        return nil
    end

    if type(state.activeProfileKey) == "string"
        and state.activeProfileKey ~= charKey
        and state.savedDB.profileKeys[state.activeProfileKey] == state.activeProfileName then
        state.savedDB.profileKeys[state.activeProfileKey] = nil
    end

    state.savedDB.profileKeys[charKey] = state.activeProfileName
    state.activeProfileKey = charKey
    NS.ProfileKey = state.activeProfileKey
    return charKey
end

local function ApplyProfileToConfig(profile)
    if type(profile) ~= "table" then
        return
    end

    profile = EnsureProfileDefaults(profile)
    state.currentPresetName = profile.currentPresetName

    for i = 1, #PROFILE_CONFIG_KEYS do
        local key = PROFILE_CONFIG_KEYS[i]
        if profile.config[key] ~= nil then
            CONFIG[key] = CopyValue(profile.config[key])
        end
    end

    local triggerMode = profile.triggerMode
    if Private.LOCK_MODE_TO_SENT then
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
    local db = _G[Private.SAVED_VARIABLES_NAME]
    if type(db) ~= "table" then
        db = {}
        _G[Private.SAVED_VARIABLES_NAME] = db
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

    state.savedDB = db
    state.activeProfileName = profileName
    state.activeProfile = profile
    state.activeProfileKey = charKey

    ApplyProfileToConfig(profile)
    PersistActiveProfile()
    RebindCharacterProfileKey()

    NS.DB = state.savedDB
    NS.Profile = state.activeProfile
    NS.ProfileName = state.activeProfileName
end

local function SwitchProfile(profileName)
    if type(profileName) ~= "string" then
        return false
    end

    profileName = profileName:gsub("^%s+", ""):gsub("%s+$", "")
    if profileName == "" then
        return false
    end

    if type(state.savedDB) ~= "table" then
        InitializeProfileDB()
    end

    local profile = state.savedDB.profiles[profileName]
    if type(profile) ~= "table" then
        profile = CreateProfileSnapshot()
    else
        profile = EnsureProfileDefaults(profile)
    end

    state.savedDB.profiles[profileName] = profile
    state.activeProfileName = profileName
    state.activeProfile = profile
    RebindCharacterProfileKey()

    ApplyProfileToConfig(profile)
    if Private.RefreshTrackedVisuals then
        Private.RefreshTrackedVisuals()
    end
    PersistActiveProfile()
    if Private.RefreshQuickMenu then
        Private.RefreshQuickMenu()
    end

    NS.Profile = state.activeProfile
    NS.ProfileName = state.activeProfileName

    PrintInfo("profile = %s", state.activeProfileName)
    return true
end

local function ResetActiveProfile()
    if type(state.savedDB) ~= "table" then
        InitializeProfileDB()
    end

    local resetProfile = EnsureProfileDefaults(CopyValue(PROFILE_DEFAULTS))
    state.savedDB.profiles[state.activeProfileName] = resetProfile
    state.activeProfile = resetProfile

    ApplyProfileToConfig(resetProfile)
    if Private.RefreshTrackedVisuals then
        Private.RefreshTrackedVisuals()
    end
    PersistActiveProfile()
    RebindCharacterProfileKey()
    if Private.RefreshQuickMenu then
        Private.RefreshQuickMenu()
    end

    NS.Profile = state.activeProfile
    PrintInfo("profile %s reset", state.activeProfileName)
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
        return L[GLOW_COLOR_PRESETS[index].label] or GLOW_COLOR_PRESETS[index].label
    end
    return L["Custom"]
end

local function GetGlowBackendLabel()
    local lib = Private.GetCustomGlowLib()
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

Private.GetCharacterProfileKey = GetCharacterProfileKey
Private.EnsureProfileDefaults = EnsureProfileDefaults
Private.PersistActiveProfile = PersistActiveProfile
Private.CreateProfileSnapshot = CreateProfileSnapshot
Private.RebindCharacterProfileKey = RebindCharacterProfileKey
Private.ApplyProfileToConfig = ApplyProfileToConfig
Private.InitializeProfileDB = InitializeProfileDB
Private.SwitchProfile = SwitchProfile
Private.ResetActiveProfile = ResetActiveProfile
Private.FindGlowPresetIndexByColor = FindGlowPresetIndexByColor
Private.GetGlowColorLabel = GetGlowColorLabel
Private.GetGlowBackendLabel = GetGlowBackendLabel
Private.ParseColorTriple = ParseColorTriple
