local _, NS = ...

local Private = NS.Private
local CONFIG = Private.CONFIG
local L = Private.L
local PROFILE_DEFAULTS = Private.PROFILE_DEFAULTS
local VISUAL_PRESETS = Private.VISUAL_PRESETS
local VISUAL_PRESET_ORDER = Private.VISUAL_PRESET_ORDER
local GLOW_COLOR_PRESETS = Private.GLOW_COLOR_PRESETS
local state = Private.state

local Clamp = Private.Clamp
local CopyRGB = Private.CopyRGB
local CopyArray = Private.CopyArray
local dprint = Private.dprint
local PrintError = Private.PrintError
local PrintInfo = Private.PrintInfo

local DEFAULT_PRESET_NAME = PROFILE_DEFAULTS.currentPresetName
local GLOW_KEY = "CDMKP"
local RefreshTrackedVisuals
local GLOW_TYPE_ORDER = { "button", "pixel", "autocast", "proc" }
local GLOW_TYPE_LABELS = {
    button = "Button",
    pixel = "Pixel",
    autocast = "Autocast",
    proc = "Proc",
}

local trackedFrames = state.trackedFrames
local spellIndex = state.spellIndex
local nameIndex = state.nameIndex
local textureIndex = state.textureIndex

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
            Private.ApplyGlowState(self)
        end)
    end

    Private.UpdateGlowOverlay(frame)
end

local function GetGlowTintRGBA()
    local color
    if CONFIG.GlowUseClassColor and type(UnitClass) == "function" then
        local _, classToken = UnitClass("player")
        local classColors = CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS
        local classColor = classColors and classToken and classColors[classToken]
        if classColor then
            color = CopyRGB({
                classColor.r or classColor[1] or 1,
                classColor.g or classColor[2] or 1,
                classColor.b or classColor[3] or 1,
            })
        end
    end
    color = color or CopyRGB(CONFIG.GlowColor)
    local brightness = Clamp(tonumber(CONFIG.GlowBrightness) or 1, 0.1, 3.0)
    local r = Clamp((color[1] or 1) * brightness, 0, 1)
    local g = Clamp((color[2] or 1) * brightness, 0, 1)
    local b = Clamp((color[3] or 1) * brightness, 0, 1)
    local a = Clamp(tonumber(CONFIG.GlowAlpha) or 0.55, 0, 1)
    return r, g, b, a
end

local function GetResolvedGlowColor()
    local r, g, b = GetGlowTintRGBA()
    local brightness = Clamp(tonumber(CONFIG.GlowBrightness) or 1, 0.1, 3.0)
    if brightness > 0 then
        r = Clamp(r / brightness, 0, 1)
        g = Clamp(g / brightness, 0, 1)
        b = Clamp(b / brightness, 0, 1)
    end
    return { r, g, b }
end

local function NormalizeGlowType(value)
    if type(value) ~= "string" then
        return nil
    end

    local normalized = value:lower()
    if normalized == "button" or normalized == "buttonglow" or normalized == "actionbutton" then
        return "button"
    end
    if normalized == "pixel" or normalized == "pixelglow" then
        return "pixel"
    end
    if normalized == "autocast" or normalized == "autocastglow" or normalized == "shine" then
        return "autocast"
    end
    if normalized == "proc" or normalized == "procglow" then
        return "proc"
    end
    return nil
end

local function GetGlowTypeKey()
    return NormalizeGlowType(CONFIG.GlowType) or "button"
end

local function GetGlowTypeLabel()
    local key = GLOW_TYPE_LABELS[GetGlowTypeKey()] or "Button"
    return L[key] or key
end

local function GetGlowTypeListText(separator)
    return table.concat(GLOW_TYPE_ORDER, separator or ", ")
end

local function PersistAndRefreshGlowSettings()
    RefreshTrackedVisuals()
    if Private.PersistActiveProfile then
        Private.PersistActiveProfile()
    end
end

local function StopLibGlow(frame, lib)
    local activeType = frame.__cdmkpGlowLibType
    if not activeType or not lib then
        frame.__cdmkpGlowUsingLib = nil
        frame.__cdmkpGlowLibType = nil
        return
    end

    if activeType == "pixel" and type(lib.PixelGlow_Stop) == "function" then
        pcall(lib.PixelGlow_Stop, frame, GLOW_KEY)
    elseif activeType == "autocast" and type(lib.AutoCastGlow_Stop) == "function" then
        pcall(lib.AutoCastGlow_Stop, frame, GLOW_KEY)
    elseif activeType == "proc" and type(lib.ProcGlow_Stop) == "function" then
        pcall(lib.ProcGlow_Stop, frame, GLOW_KEY)
    elseif activeType == "button" and type(lib.ButtonGlow_Stop) == "function" then
        pcall(lib.ButtonGlow_Stop, frame)
    end

    frame.__cdmkpGlowUsingLib = nil
    frame.__cdmkpGlowLibType = nil
end

local function StartLibGlow(frame, lib)
    local glowType = GetGlowTypeKey()
    local r, g, b, a = GetGlowTintRGBA()
    local color = { r, g, b, a }
    local frameLevel = tonumber(CONFIG.GlowLibFrameLevel) or 8
    frameLevel = Clamp(math.floor(frameLevel + 0.5), 0, 32)

    local ok = false
    if glowType == "pixel" and type(lib.PixelGlow_Start) == "function" then
        ok = pcall(
            lib.PixelGlow_Start,
            frame,
            color,
            math.max(1, math.floor((tonumber(CONFIG.GlowPixelLines) or 5) + 0.5)),
            tonumber(CONFIG.GlowPixelFrequency) or 0.25,
            tonumber(CONFIG.GlowPixelLength) or 2,
            tonumber(CONFIG.GlowPixelThickness) or 1,
            tonumber(CONFIG.GlowPixelXOffset) or -1,
            tonumber(CONFIG.GlowPixelYOffset) or -1,
            CONFIG.GlowPixelBorder and true or false,
            GLOW_KEY,
            frameLevel
        )
    elseif glowType == "autocast" and type(lib.AutoCastGlow_Start) == "function" then
        ok = pcall(
            lib.AutoCastGlow_Start,
            frame,
            color,
            math.max(1, math.floor((tonumber(CONFIG.GlowAutoCastParticles) or 10) + 0.5)),
            tonumber(CONFIG.GlowAutoCastFrequency) or 0.25,
            tonumber(CONFIG.GlowAutoCastScale) or 1,
            tonumber(CONFIG.GlowAutoCastXOffset) or -1,
            tonumber(CONFIG.GlowAutoCastYOffset) or -1,
            GLOW_KEY,
            frameLevel
        )
    elseif glowType == "proc" and type(lib.ProcGlow_Start) == "function" then
        ok = pcall(lib.ProcGlow_Start, frame, {
            key = GLOW_KEY,
            frameLevel = frameLevel,
            color = color,
            startAnim = CONFIG.GlowProcStartAnim and true or false,
            duration = tonumber(CONFIG.GlowProcDuration) or 1,
            xOffset = tonumber(CONFIG.GlowProcXOffset) or 0,
            yOffset = tonumber(CONFIG.GlowProcYOffset) or 0,
        })
    elseif type(lib.ButtonGlow_Start) == "function" then
        local frequency = tonumber(CONFIG.GlowButtonFrequency)
        if frequency and frequency <= 0 then
            frequency = nil
        end
        ok = pcall(lib.ButtonGlow_Start, frame, color, frequency, frameLevel)
        glowType = "button"
    end

    if ok then
        frame.__cdmkpGlowUsingLib = true
        frame.__cdmkpGlowLibType = glowType
        return true
    end

    frame.__cdmkpGlowUsingLib = nil
    frame.__cdmkpGlowLibType = nil
    return false
end

local function UpdateGlowOverlay(frame)
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

local function ApplyGlowState(frame)
    local wantGlow = CONFIG.GlowEnabled and frame.__cdmkpGlowActive
    local lib = Private.GetCustomGlowLib()
    local desiredType = GetGlowTypeKey()

    if wantGlow and lib then
        if frame.__cdmkpGlowUsingLib and frame.__cdmkpGlowLibType ~= desiredType then
            StopLibGlow(frame, lib)
        end
        if not StartLibGlow(frame, lib) then
            StopLibGlow(frame, lib)
        end
    else
        StopLibGlow(frame, lib)
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
        if frame and Private.HasTrackedPayload(frame) then
            HidePressedTint(frame)
        end
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
            if frame and frame.IsShown and frame:IsShown() and not Private.IsForbiddenSafe(frame) then
                if not seen[frame] then
                    seen[frame] = true
                    hits = hits + 1
                end
            end
        end
    end

    collect(Private.SafeTableGet(spellIndex, spellID))

    if hits == 0 then
        local spellName = Private.GetSpellNameSafe(spellID)
        local nameKey = Private.NormalizeSpellName(spellName)
        if nameKey then
            collect(Private.SafeTableGet(nameIndex, nameKey))
        end

        if CONFIG.EnableTextureFallback then
            local textureKey = Private.NormalizeTextureKey(Private.GetSpellTextureSafe(spellID))
            if textureKey then
                collect(Private.SafeTableGet(textureIndex, textureKey))
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

    if state.activePressedState then
        SetPressedForFrameSet(state.activePressedState.frames, false)
        state.activePressedState = nil
    end

    SetPressedForFrameSet(frameSet, true)

    local now = (GetTimePreciseSec and GetTimePreciseSec()) or GetTime()
    local pressedState = { sentAt = now, spellID = spellID, frames = frameSet }
    state.activePressedState = pressedState

    C_Timer.After(CONFIG.PressedMaxHoldSeconds, function()
        if state.activePressedState == pressedState then
            Private.ReleaseActivePressed("timeout", pressedState)
        end
    end)
end

local function ReleaseActivePressed(reason, expectedState)
    local pressedState = state.activePressedState
    if not pressedState then
        return
    end

    if expectedState and expectedState ~= pressedState then
        return
    end

    local now = (GetTimePreciseSec and GetTimePreciseSec()) or GetTime()
    local elapsed = now - pressedState.sentAt
    local remaining = CONFIG.PressedMinHoldSeconds - elapsed

    local function finish(stateRef)
        if state.activePressedState ~= stateRef then
            return
        end
        state.activePressedState = nil
        SetPressedForFrameSet(stateRef.frames, false)
        ClearAllPressedVisuals()
        dprint(("Pressed %s: released (%s)"):format(tostring(stateRef.spellID or "?"), reason))
    end

    if remaining > 0 then
        C_Timer.After(remaining, function()
            finish(pressedState)
        end)
    else
        finish(pressedState)
    end
end

RefreshTrackedVisuals = function()
    for frame in pairs(trackedFrames) do
        if frame and Private.HasTrackedPayload(frame) then
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
end

local function ApplyVisualPreset(name)
    if Private.LOCK_PRESET_TO_DEFAULT and name ~= DEFAULT_PRESET_NAME then
        PrintInfo("preset locked to %s", DEFAULT_PRESET_NAME)
        return false
    end

    local preset = VISUAL_PRESETS[name]
    if not preset then
        PrintError("unknown preset: %s", name)
        return false
    end

    for key, value in pairs(preset) do
        CONFIG[key] = CopyArray(value)
    end

    state.currentPresetName = name
    RefreshTrackedVisuals()
    if Private.PersistActiveProfile then
        Private.PersistActiveProfile()
    end
    PrintInfo("preset = %s", name)
    return true
end

local function FindVisualPresetIndex(name)
    if type(name) ~= "string" then
        return nil
    end

    for i = 1, #VISUAL_PRESET_ORDER do
        if VISUAL_PRESET_ORDER[i] == name then
            return i
        end
    end

    return nil
end

local function GetVisualPresetListText(separator)
    return table.concat(VISUAL_PRESET_ORDER, separator or ", ")
end

local function CycleVisualPreset(step)
    if Private.LOCK_PRESET_TO_DEFAULT then
        PrintInfo("preset locked to %s", DEFAULT_PRESET_NAME)
        return false
    end

    local currentIndex = FindVisualPresetIndex(state.currentPresetName) or 1
    local direction = (step and step < 0) and -1 or 1
    local nextIndex = currentIndex + direction

    if nextIndex < 1 then
        nextIndex = #VISUAL_PRESET_ORDER
    elseif nextIndex > #VISUAL_PRESET_ORDER then
        nextIndex = 1
    end

    return ApplyVisualPreset(VISUAL_PRESET_ORDER[nextIndex])
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
    if Private.PersistActiveProfile then
        Private.PersistActiveProfile()
    end
    PrintInfo("glow = %s (%s)",
        CONFIG.GlowEnabled and "on" or "off",
        Private.GetGlowBackendLabel()
    )
end

local function SetGlowAlpha(value)
    CONFIG.GlowAlpha = Clamp(tonumber(value) or CONFIG.GlowAlpha or 0.55, 0, 1)
    RefreshTrackedVisuals()
    if Private.PersistActiveProfile then
        Private.PersistActiveProfile()
    end
    PrintInfo("glow alpha = %.2f", CONFIG.GlowAlpha)
end

local function SetGlowBrightness(value)
    CONFIG.GlowBrightness = Clamp(tonumber(value) or CONFIG.GlowBrightness or 1, 0.1, 3.0)
    RefreshTrackedVisuals()
    if Private.PersistActiveProfile then
        Private.PersistActiveProfile()
    end
    PrintInfo("glow brightness = %.2f", CONFIG.GlowBrightness)
end

local function SetGlowColor(color)
    CONFIG.GlowColor = CopyRGB(color)
    RefreshTrackedVisuals()
    if Private.PersistActiveProfile then
        Private.PersistActiveProfile()
    end
    PrintInfo("glow color = %.2f %.2f %.2f",
        CONFIG.GlowColor[1] or 1,
        CONFIG.GlowColor[2] or 1,
        CONFIG.GlowColor[3] or 1
    )
end

local function SetGlowUseClassColor(enabled)
    CONFIG.GlowUseClassColor = enabled and true or false
    RefreshTrackedVisuals()
    if Private.PersistActiveProfile then
        Private.PersistActiveProfile()
    end
    PrintInfo("glow class color = %s", CONFIG.GlowUseClassColor and "on" or "off")
end

local function SetGlowColorByPresetIndex(index)
    if type(index) ~= "number" or index < 1 or index > #GLOW_COLOR_PRESETS then
        return
    end
    SetGlowColor(GLOW_COLOR_PRESETS[index].color)
end

local function SetGlowType(value)
    local normalized = NormalizeGlowType(value)
    if not normalized then
        PrintError("unknown glow type: %s", tostring(value))
        return false
    end

    CONFIG.GlowType = normalized
    PersistAndRefreshGlowSettings()
    PrintInfo("glow type = %s", GetGlowTypeLabel())
    return true
end

local function CycleGlowType(step)
    local currentType = GetGlowTypeKey()
    local currentIndex = 1
    for i = 1, #GLOW_TYPE_ORDER do
        if GLOW_TYPE_ORDER[i] == currentType then
            currentIndex = i
            break
        end
    end

    local direction = (step and step < 0) and -1 or 1
    local nextIndex = currentIndex + direction
    if nextIndex < 1 then
        nextIndex = #GLOW_TYPE_ORDER
    elseif nextIndex > #GLOW_TYPE_ORDER then
        nextIndex = 1
    end

    return SetGlowType(GLOW_TYPE_ORDER[nextIndex])
end

local function OnSpellcastSent(unitToken, ...)
    if unitToken ~= "player" or not CONFIG.TriggerOnSpellSent then
        return
    end

    local spellID = Private.ResolveSpellIDFromEventArgs(...)
    if not spellID then
        dprint("Sent: unable to resolve spellID")
        return
    end

    local hits, seen = TriggerForSpellID(spellID, "Sent")
    if hits > 0 then
        ActivatePressedState(spellID, seen)
        local now = (GetTimePreciseSec and GetTimePreciseSec()) or GetTime()
        state.lastSentSpellID = spellID
        state.lastSentAt = now
    else
        if state.activePressedState and state.activePressedState.spellID == spellID then
            ReleaseActivePressed("sent-no-hit")
        end
    end
end

local function OnSpellcastSucceeded(unitToken, ...)
    if unitToken ~= "player" or not CONFIG.TriggerOnSpellSucceeded then
        return
    end

    local spellID = Private.ResolveSpellIDFromEventArgs(...)
    if not spellID then
        dprint("Succeeded: unable to resolve spellID")
        return
    end

    if CONFIG.TriggerOnSpellSent and state.lastSentSpellID == spellID then
        local now = (GetTimePreciseSec and GetTimePreciseSec()) or GetTime()
        if (now - state.lastSentAt) <= CONFIG.SentSuppressSucceededWindow then
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

local function OnSpellcastEnded(reasonTag, unitToken)
    if unitToken ~= "player" then
        return
    end

    ReleaseActivePressed(reasonTag)
end

Private.EnsurePressAnimation = EnsurePressAnimation
Private.UpdateGlowOverlay = UpdateGlowOverlay
Private.ApplyGlowState = ApplyGlowState
Private.RefreshTrackedVisuals = RefreshTrackedVisuals
Private.ApplyVisualPreset = ApplyVisualPreset
Private.GetVisualPresetListText = GetVisualPresetListText
Private.CycleVisualPreset = CycleVisualPreset
Private.NormalizeGlowType = NormalizeGlowType
Private.GetGlowTypeLabel = GetGlowTypeLabel
Private.GetGlowTypeListText = GetGlowTypeListText
Private.GetResolvedGlowColor = GetResolvedGlowColor
Private.SetGlowEnabled = SetGlowEnabled
Private.SetGlowAlpha = SetGlowAlpha
Private.SetGlowBrightness = SetGlowBrightness
Private.SetGlowColor = SetGlowColor
Private.SetGlowUseClassColor = SetGlowUseClassColor
Private.SetGlowColorByPresetIndex = SetGlowColorByPresetIndex
Private.SetGlowType = SetGlowType
Private.CycleGlowType = CycleGlowType
Private.ReleaseActivePressed = ReleaseActivePressed
Private.TriggerForSpellID = TriggerForSpellID
Private.OnSpellcastSent = OnSpellcastSent
Private.OnSpellcastSucceeded = OnSpellcastSucceeded
Private.OnSpellcastEnded = OnSpellcastEnded
