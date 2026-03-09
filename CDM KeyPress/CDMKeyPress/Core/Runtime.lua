local ADDON_NAME, NS = ...

local Private = NS.Private or {}
local L = NS.L or {}
NS.Private = Private

Private.ADDON_NAME = ADDON_NAME
Private.SAVED_VARIABLES_NAME = "CDMKeyPressDB"
Private.LOCK_MODE_TO_SENT = false
Private.LOCK_PRESET_TO_DEFAULT = false
Private.ICON_TEXTURE_PATH = ("Interface\\AddOns\\%s\\cdm_keypress_icon_64.tga"):format(ADDON_NAME)

local CONFIG = {
    CDMAddonNames = {
        "Midnight",
        "CooldownManager",
        "CDM",
    },

    RootFrameNames = {
        "MidnightCooldownManagerFrame",
        "CooldownManagerFrame",
    },

    ViewerFrameNames = {
        "EssentialCooldownViewer",
        "UtilityCooldownViewer",
        "BCDM_CustomCooldownViewer",
        "BCDM_AdditionalCustomCooldownViewer",
        "BCDM_CustomItemSpellBar",
        "BCDM_CustomItemBar",
        "BCDM_TrinketBar",
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

    AllowUnsafeHeuristics = true,
    EnableFallbackScanWithoutKnownAddon = true,
    EnablePressFlash = true,
    EnableTextureFallback = true,

    ExcludedFrameNamePatterns = {
        "^AchievementAlertFrame",
        "^AlertFrame",
        "Achievement",
        "Toast",
        "BossBanner",
        "TalkingHead",
    },

    PressTexturePath = "Interface\\Buttons\\WHITE8X8",
    PressBlendMode = "ADD",
    PressVertexColor = { 1.00, 0.95, 0.55 },
    PressPeakAlpha = 1.00,
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
    GlowUseClassColor = false,
    GlowType = "button",
    GlowButtonFrequency = 0.125,
    GlowLibFrameLevel = 8,
    GlowLibFrequency = 0,
    GlowPixelLines = 5,
    GlowPixelFrequency = 0.25,
    GlowPixelLength = 2,
    GlowPixelThickness = 1,
    GlowPixelXOffset = -1,
    GlowPixelYOffset = -1,
    GlowPixelBorder = false,
    GlowAutoCastParticles = 10,
    GlowAutoCastFrequency = 0.25,
    GlowAutoCastScale = 1,
    GlowAutoCastXOffset = -1,
    GlowAutoCastYOffset = -1,
    GlowProcStartAnim = true,
    GlowProcDuration = 1,
    GlowProcXOffset = 0,
    GlowProcYOffset = 0,
    PressedMinHoldSeconds = 0.08,
    PressedMaxHoldSeconds = 0.20,
    FadeInDuration = 0.10,
    FadeOutDuration = 0.20,
    MinReplayGapSeconds = 0.05,
    TriggerOnSpellSent = true,
    TriggerOnSpellSucceeded = false,
    SentSuppressSucceededWindow = 1.20,
    MaxFramesPerScan = 5000,
    FallbackAutoScanMinIntervalSeconds = 2.50,
    StartupRetryMaxAttempts = 10,
}

local VISUAL_PRESETS = {
    default = {
        EnablePressFlash = true,
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
        GlowUseClassColor = false,
        GlowType = "button",
        GlowButtonFrequency = 0.125,
        GlowLibFrameLevel = 8,
        GlowLibFrequency = 0,
        GlowPixelLines = 5,
        GlowPixelFrequency = 0.25,
        GlowPixelLength = 2,
        GlowPixelThickness = 1,
        GlowPixelXOffset = -1,
        GlowPixelYOffset = -1,
        GlowPixelBorder = false,
        GlowAutoCastParticles = 10,
        GlowAutoCastFrequency = 0.25,
        GlowAutoCastScale = 1,
        GlowAutoCastXOffset = -1,
        GlowAutoCastYOffset = -1,
        GlowProcStartAnim = true,
        GlowProcDuration = 1,
        GlowProcXOffset = 0,
        GlowProcYOffset = 0,
        PressedMinHoldSeconds = 0.08,
        PressedMaxHoldSeconds = 0.20,
        FadeInDuration = 0.10,
        FadeOutDuration = 0.20,
    },
    blizzard = {
        EnablePressFlash = true,
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
        GlowUseClassColor = false,
        GlowType = "button",
        GlowButtonFrequency = 0.125,
        GlowLibFrameLevel = 8,
        GlowLibFrequency = 0,
        GlowPixelLines = 5,
        GlowPixelFrequency = 0.25,
        GlowPixelLength = 2,
        GlowPixelThickness = 1,
        GlowPixelXOffset = -1,
        GlowPixelYOffset = -1,
        GlowPixelBorder = false,
        GlowAutoCastParticles = 10,
        GlowAutoCastFrequency = 0.25,
        GlowAutoCastScale = 1,
        GlowAutoCastXOffset = -1,
        GlowAutoCastYOffset = -1,
        GlowProcStartAnim = true,
        GlowProcDuration = 1,
        GlowProcXOffset = 0,
        GlowProcYOffset = 0,
        PressedMinHoldSeconds = 0.09,
        PressedMaxHoldSeconds = 0.18,
        FadeInDuration = 0.05,
        FadeOutDuration = 0.13,
    },
    arcane = {
        EnablePressFlash = true,
        EnableTextureFallback = true,
        PressBlendMode = "ADD",
        PressVertexColor = { 0.45, 0.85, 1.00 },
        PressPeakAlpha = 0.90,
        PressedTexturePath = "Interface\\Buttons\\WHITE8X8",
        PressedBlendMode = "ADD",
        PressedVertexColor = { 0.25, 0.55, 1.00 },
        PressedAlpha = 0.26,
        GlowEnabled = true,
        GlowAlpha = 0.50,
        GlowBrightness = 1.20,
        GlowColor = { 0.35, 0.75, 1.00 },
        GlowUseClassColor = false,
        GlowType = "button",
        GlowButtonFrequency = 0.125,
        GlowLibFrameLevel = 8,
        GlowLibFrequency = 0,
        GlowPixelLines = 5,
        GlowPixelFrequency = 0.25,
        GlowPixelLength = 2,
        GlowPixelThickness = 1,
        GlowPixelXOffset = -1,
        GlowPixelYOffset = -1,
        GlowPixelBorder = false,
        GlowAutoCastParticles = 10,
        GlowAutoCastFrequency = 0.25,
        GlowAutoCastScale = 1,
        GlowAutoCastXOffset = -1,
        GlowAutoCastYOffset = -1,
        GlowProcStartAnim = true,
        GlowProcDuration = 1,
        GlowProcXOffset = 0,
        GlowProcYOffset = 0,
        PressedMinHoldSeconds = 0.08,
        PressedMaxHoldSeconds = 0.18,
        FadeInDuration = 0.04,
        FadeOutDuration = 0.16,
    },
    ember = {
        EnablePressFlash = true,
        EnableTextureFallback = true,
        PressBlendMode = "ADD",
        PressVertexColor = { 1.00, 0.45, 0.15 },
        PressPeakAlpha = 1.00,
        PressedTexturePath = "Interface\\Buttons\\WHITE8X8",
        PressedBlendMode = "ADD",
        PressedVertexColor = { 1.00, 0.35, 0.10 },
        PressedAlpha = 0.22,
        GlowEnabled = true,
        GlowAlpha = 0.60,
        GlowBrightness = 1.20,
        GlowColor = { 1.00, 0.45, 0.15 },
        GlowUseClassColor = false,
        GlowType = "button",
        GlowButtonFrequency = 0.125,
        GlowLibFrameLevel = 8,
        GlowLibFrequency = 0,
        GlowPixelLines = 5,
        GlowPixelFrequency = 0.25,
        GlowPixelLength = 2,
        GlowPixelThickness = 1,
        GlowPixelXOffset = -1,
        GlowPixelYOffset = -1,
        GlowPixelBorder = false,
        GlowAutoCastParticles = 10,
        GlowAutoCastFrequency = 0.25,
        GlowAutoCastScale = 1,
        GlowAutoCastXOffset = -1,
        GlowAutoCastYOffset = -1,
        GlowProcStartAnim = true,
        GlowProcDuration = 1,
        GlowProcXOffset = 0,
        GlowProcYOffset = 0,
        PressedMinHoldSeconds = 0.06,
        PressedMaxHoldSeconds = 0.14,
        FadeInDuration = 0.02,
        FadeOutDuration = 0.08,
    },
}

local VISUAL_PRESET_ORDER = {
    "blizzard",
    "default",
    "arcane",
    "ember",
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
    "GlowUseClassColor",
    "GlowType",
    "GlowButtonFrequency",
    "GlowLibFrameLevel",
    "GlowLibFrequency",
    "GlowPixelLines",
    "GlowPixelFrequency",
    "GlowPixelLength",
    "GlowPixelThickness",
    "GlowPixelXOffset",
    "GlowPixelYOffset",
    "GlowPixelBorder",
    "GlowAutoCastParticles",
    "GlowAutoCastFrequency",
    "GlowAutoCastScale",
    "GlowAutoCastXOffset",
    "GlowAutoCastYOffset",
    "GlowProcStartAnim",
    "GlowProcDuration",
    "GlowProcXOffset",
    "GlowProcYOffset",
    "PressedMinHoldSeconds",
    "PressedMaxHoldSeconds",
    "FadeInDuration",
    "FadeOutDuration",
}

local PROFILE_DEFAULTS = {
    currentPresetName = "blizzard",
    triggerMode = "sent",
    config = {
        EnablePressFlash = true,
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
        GlowUseClassColor = false,
        GlowType = "button",
        GlowButtonFrequency = 0.125,
        GlowLibFrameLevel = 8,
        GlowLibFrequency = 0,
        GlowPixelLines = 5,
        GlowPixelFrequency = 0.25,
        GlowPixelLength = 2,
        GlowPixelThickness = 1,
        GlowPixelXOffset = -1,
        GlowPixelYOffset = -1,
        GlowPixelBorder = false,
        GlowAutoCastParticles = 10,
        GlowAutoCastFrequency = 0.25,
        GlowAutoCastScale = 1,
        GlowAutoCastXOffset = -1,
        GlowAutoCastYOffset = -1,
        GlowProcStartAnim = true,
        GlowProcDuration = 1,
        GlowProcXOffset = 0,
        GlowProcYOffset = 0,
        PressedMinHoldSeconds = 0.09,
        PressedMaxHoldSeconds = 0.18,
        FadeInDuration = 0.05,
        FadeOutDuration = 0.13,
    },
}

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

local function GetNow()
    return (GetTimePreciseSec and GetTimePreciseSec()) or GetTime()
end

local function Translate(key)
    local value = L[key]
    if value == nil then
        return key
    end
    return value
end

local function FormatText(key, ...)
    local text = Translate(key)
    if select("#", ...) > 0 then
        return text:format(...)
    end
    return text
end

local function PrintInfo(key, ...)
    print("|cff33ff99CDMKeyPress:|r " .. FormatText(key, ...))
end

local function PrintError(key, ...)
    print("|cffff5555CDMKeyPress:|r " .. FormatText(key, ...))
end

local state = {
    debug = false,
    trackedFrames = setmetatable({}, { __mode = "k" }),
    spellIndex = {},
    nameIndex = {},
    textureIndex = {},
    lastSentSpellID = nil,
    lastSentAt = 0,
    activePressedState = nil,
    cdmLoadedByName = false,
    warnedFallbackScan = false,
    lastFallbackScanAt = 0,
    scanMetrics = {
        totalScans = 0,
        totalFramesScanned = 0,
        startupRetryAttempts = 0,
        viewerRootFlushes = 0,
        viewerRootFramesScanned = 0,
        fallbackAttempts = 0,
        fallbackExecuted = 0,
        fallbackSkipped = 0,
        last = {
            source = "none",
            mode = "none",
            scanned = 0,
            tracked = 0,
            roots = 0,
            fallback = "none",
            age = 0,
        },
    },
    quickMenu = nil,
    currentPresetName = "blizzard",
    startupScanDone = false,
    startupRetryTicker = nil,
    viewerScanHooked = {},
    viewerPoolAcquireHooked = setmetatable({}, { __mode = "k" }),
    viewerPoolReleaseHooked = setmetatable({}, { __mode = "k" }),
    viewerMixinHooked = {},
    ayijeQueueHooked = false,
    queuedViewerRescanRoots = setmetatable({}, { __mode = "k" }),
    viewerRescanTimer = nil,
    viewerRescanDelay = nil,
    viewerRescanFullScanQueued = false,
    cachedCustomGlowLib = nil,
    savedDB = nil,
    activeProfile = nil,
    activeProfileName = "Default",
    activeProfileKey = nil,
}

local rootNameSet = {}
for _, name in ipairs(CONFIG.RootFrameNames) do
    rootNameSet[name] = true
end

local function dprint(...)
    if state.debug then
        print("|cff33ff99CDMKeyPress:|r", ...)
    end
end

local function SetDebugEnabled(enabled)
    state.debug = enabled and true or false
    PrintInfo("debug %s", state.debug and "ON" or "OFF")
end

local function GetCustomGlowLib()
    if state.cachedCustomGlowLib then
        return state.cachedCustomGlowLib
    end

    local libStub = _G.LibStub
    if type(libStub) == "table" and type(libStub.GetLibrary) == "function" then
        local ok, lib = pcall(libStub.GetLibrary, libStub, "LibCustomGlow-1.0", true)
        if ok and type(lib) == "table" then
            state.cachedCustomGlowLib = lib
            return lib
        end
    end

    if type(_G.LibCustomGlow) == "table" then
        state.cachedCustomGlowLib = _G.LibCustomGlow
        return state.cachedCustomGlowLib
    end

    return nil
end

Private.CONFIG = CONFIG
Private.VISUAL_PRESETS = VISUAL_PRESETS
Private.VISUAL_PRESET_ORDER = VISUAL_PRESET_ORDER
Private.PROFILE_CONFIG_KEYS = PROFILE_CONFIG_KEYS
Private.PROFILE_DEFAULTS = PROFILE_DEFAULTS
Private.GLOW_COLOR_PRESETS = GLOW_COLOR_PRESETS
Private.rootNameSet = rootNameSet
Private.state = state
Private.Clamp = Clamp
Private.CopyRGB = CopyRGB
Private.CopyValue = CopyValue
Private.CopyArray = CopyArray
Private.GetNow = GetNow
Private.L = L
Private.Translate = Translate
Private.FormatText = FormatText
Private.PrintInfo = PrintInfo
Private.PrintError = PrintError
Private.dprint = dprint
Private.SetDebugEnabled = SetDebugEnabled
Private.GetCustomGlowLib = GetCustomGlowLib

NS.CONFIG = CONFIG
