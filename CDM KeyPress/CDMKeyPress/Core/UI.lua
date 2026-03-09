local _, NS = ...

local Private = NS.Private
local CONFIG = Private.CONFIG
local GLOW_COLOR_PRESETS = Private.GLOW_COLOR_PRESETS
local PROFILE_DEFAULTS = Private.PROFILE_DEFAULTS
local state = Private.state

local ToggleQuickMenu
local RefreshQuickMenu

local PrintInfo = Private.PrintInfo

local function ParseSlash(msg)
    msg = (msg or ""):lower()
    msg = msg:gsub("^%s+", ""):gsub("%s+$", "")
    local cmd, rest = msg:match("^(%S+)%s*(.-)$")
    return cmd or "", rest or ""
end

local function GetLockedPresetName()
    return PROFILE_DEFAULTS.currentPresetName or "blizzard"
end

local function CommitGlowOptionChanges()
    if Private.RefreshTrackedVisuals then
        Private.RefreshTrackedVisuals()
    end
    if Private.PersistActiveProfile then
        Private.PersistActiveProfile()
    end
    RefreshQuickMenu()
end

local function SetGlowNumberOption(key, rawValue, minValue, maxValue, roundValue, messageKey)
    local value = tonumber(rawValue)
    if not value then
        return false
    end

    value = Private.Clamp(value, minValue, maxValue)
    if roundValue then
        value = math.floor(value + 0.5)
    end

    CONFIG[key] = value
    CommitGlowOptionChanges()
    if messageKey then
        PrintInfo(messageKey, value)
    end
    return true
end

local function SetGlowOffsetOption(xKey, yKey, rawX, rawY, messageKey)
    local x = tonumber(rawX)
    local y = tonumber(rawY)
    if not x or not y then
        return false
    end

    CONFIG[xKey] = Private.Clamp(x, -50, 50)
    CONFIG[yKey] = Private.Clamp(y, -50, 50)
    CommitGlowOptionChanges()
    if messageKey then
        PrintInfo(messageKey, CONFIG[xKey], CONFIG[yKey])
    end
    return true
end

local function ParseToggleValue(value)
    if value == "on" or value == "true" or value == "1" then
        return true
    end
    if value == "off" or value == "false" or value == "0" then
        return false
    end
    return nil
end

local function ApplyTriggerMode(mode)
    if Private.LOCK_MODE_TO_SENT and mode ~= "sent" then
        PrintInfo("mode locked to sent")
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

    if Private.PersistActiveProfile then
        Private.PersistActiveProfile()
    end
    PrintInfo("mode = %s", mode)
end

RefreshQuickMenu = function()
    if Private.RefreshModernMenu then
        Private.RefreshModernMenu()
    end
end

local function CreateQuickMenu()
    if Private.CreateModernMenu then
        return Private.CreateModernMenu()
    end
end

local function EnsureMinimapButton()
    if Private.EnsureModernMinimapButton then
        return Private.EnsureModernMinimapButton()
    end
end

ToggleQuickMenu = function()
    local menu = CreateQuickMenu()
    if not menu then
        return
    end

    if menu:IsShown() then
        menu:Hide()
    else
        if Private.SelectModernMenuPage then
            Private.SelectModernMenuPage("overview")
        end
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
        local cdmLoaded, detectionMode = Private.GetDetectionState()
        PrintInfo("profile=%s", state.activeProfileName or "Default")
        PrintInfo("cdmLoaded=%s (%s) tracked=%d", cdmLoaded and "true" or "false", detectionMode, Private.CountTrackedFrames())
        PrintInfo("candidates: %s", Private.GetLoadedCandidatesText())
        PrintInfo("%s", Private.GetScanSummaryText())
        PrintInfo("%s", Private.GetScanTotalsText())
        PrintInfo("trigger: sent=%s succeeded=%s", CONFIG.TriggerOnSpellSent and "1" or "0", CONFIG.TriggerOnSpellSucceeded and "1" or "0")
        PrintInfo("preset=%s", state.currentPresetName)
        PrintInfo("glow=%s backend=%s alpha=%.2f brightness=%.2f color=%.2f %.2f %.2f (%s)",
            CONFIG.GlowEnabled and "on" or "off",
            Private.GetGlowBackendLabel(),
            CONFIG.GlowAlpha or 0,
            CONFIG.GlowBrightness or 1,
            (CONFIG.GlowColor and CONFIG.GlowColor[1]) or 1,
            (CONFIG.GlowColor and CONFIG.GlowColor[2]) or 1,
            (CONFIG.GlowColor and CONFIG.GlowColor[3]) or 1,
            Private.GetGlowColorLabel()
        )
        PrintInfo("glow type = %s", Private.GetGlowTypeLabel())
        PrintInfo("glow class color = %s", CONFIG.GlowUseClassColor and "on" or "off")
        return
    end

    if cmd == "addons" then
        Private.PrintLoadedAddonHints()
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
            PrintInfo("profile = %s", state.activeProfileName or "Default")
            return
        end

        if action == "set" then
            if Private.SwitchProfile(arg) then
                PrintInfo("reload not required")
            else
                PrintInfo("usage: /cdmkp profile set <name>")
            end
            return
        end

        if action == "reset" then
            Private.ResetActiveProfile()
            return
        end

        PrintInfo("profile commands: profile status, profile set <name>, profile reset")
        return
    end

    if cmd == "debug" and rest == "on" then
        Private.SetDebugEnabled(true)
        RefreshQuickMenu()
        return
    end

    if cmd == "debug" and rest == "off" then
        Private.SetDebugEnabled(false)
        RefreshQuickMenu()
        return
    end

    if cmd == "glow" then
        local action, arg1, arg2, arg3 = rest:match("^(%S*)%s*(%S*)%s*(%S*)%s*(%S*)$")
        action = action or ""

        if action == "on" then
            Private.SetGlowEnabled(true)
            RefreshQuickMenu()
            return
        end

        if action == "off" then
            Private.SetGlowEnabled(false)
            RefreshQuickMenu()
            return
        end

        if action == "type" then
            if not arg1 or arg1 == "" then
                PrintInfo("glow types: %s", Private.GetGlowTypeListText(", "))
                return
            end
            if Private.SetGlowType(arg1) then
                RefreshQuickMenu()
            end
            return
        end

        if action == "classcolor" or action == "class" then
            local enabled = ParseToggleValue(arg1)
            if enabled == nil then
                PrintInfo("usage: /cdmkp glow classcolor <on|off>")
                return
            end
            if Private.SetGlowUseClassColor then
                Private.SetGlowUseClassColor(enabled)
            end
            RefreshQuickMenu()
            return
        end

        if action == "alpha" then
            local value = tonumber(arg1)
            if not value then
                PrintInfo("usage: /cdmkp glow alpha <0-1>")
                return
            end
            Private.SetGlowAlpha(value)
            RefreshQuickMenu()
            return
        end

        if action == "brightness" or action == "bright" then
            local value = tonumber(arg1)
            if not value then
                PrintInfo("usage: /cdmkp glow brightness <0.1-3>")
                return
            end
            Private.SetGlowBrightness(value)
            RefreshQuickMenu()
            return
        end

        if action == "color" then
            if arg1 and arg2 and arg3 and arg1 ~= "" and arg2 ~= "" and arg3 ~= "" then
                local color = Private.ParseColorTriple(arg1, arg2, arg3)
                if not color then
                    PrintInfo("usage: /cdmkp glow color <r g b> (0-1 or 0-255)")
                    return
                end
                Private.SetGlowColor(color)
                RefreshQuickMenu()
                return
            end

            local presetKey = arg1 and arg1:lower() or ""
            for i = 1, #GLOW_COLOR_PRESETS do
                if GLOW_COLOR_PRESETS[i].key == presetKey then
                    Private.SetGlowColorByPresetIndex(i)
                    RefreshQuickMenu()
                    return
                end
            end

            PrintInfo("usage: /cdmkp glow color <r g b> or /cdmkp glow color <yellow|white|orange|red|green|cyan|blue|purple>")
            return
        end

        if action == "button" then
            if arg1 == "frequency" and SetGlowNumberOption("GlowButtonFrequency", arg2, 0.01, 10, false, "glow button frequency = %.2f") then
                return
            end
            PrintInfo("usage: /cdmkp glow button frequency <0.01-10>")
            return
        end

        if action == "pixel" then
            if arg1 == "lines" and SetGlowNumberOption("GlowPixelLines", arg2, 1, 32, true, "glow pixel lines = %d") then
                return
            end
            if arg1 == "frequency" and SetGlowNumberOption("GlowPixelFrequency", arg2, -10, 10, false, "glow pixel frequency = %.2f") then
                return
            end
            if arg1 == "length" and SetGlowNumberOption("GlowPixelLength", arg2, 0.1, 20, false, "glow pixel length = %.2f") then
                return
            end
            if arg1 == "thickness" and SetGlowNumberOption("GlowPixelThickness", arg2, 0.1, 20, false, "glow pixel thickness = %.2f") then
                return
            end
            if arg1 == "offset" and SetGlowOffsetOption("GlowPixelXOffset", "GlowPixelYOffset", arg2, arg3, "glow pixel offset = %.2f %.2f") then
                return
            end
            if arg1 == "border" then
                local enabled = ParseToggleValue(arg2)
                if enabled ~= nil then
                    CONFIG.GlowPixelBorder = enabled
                    CommitGlowOptionChanges()
                    PrintInfo("glow pixel border = %s", enabled and "on" or "off")
                    return
                end
            end
            PrintInfo("usage: /cdmkp glow pixel <lines|frequency|length|thickness|offset|border> ...")
            return
        end

        if action == "autocast" then
            if arg1 == "particles" and SetGlowNumberOption("GlowAutoCastParticles", arg2, 1, 64, true, "glow autocast particles = %d") then
                return
            end
            if arg1 == "frequency" and SetGlowNumberOption("GlowAutoCastFrequency", arg2, -10, 10, false, "glow autocast frequency = %.2f") then
                return
            end
            if arg1 == "scale" and SetGlowNumberOption("GlowAutoCastScale", arg2, 0.1, 5, false, "glow autocast scale = %.2f") then
                return
            end
            if arg1 == "offset" and SetGlowOffsetOption("GlowAutoCastXOffset", "GlowAutoCastYOffset", arg2, arg3, "glow autocast offset = %.2f %.2f") then
                return
            end
            PrintInfo("usage: /cdmkp glow autocast <particles|frequency|scale|offset> ...")
            return
        end

        if action == "proc" then
            if arg1 == "duration" and SetGlowNumberOption("GlowProcDuration", arg2, 0.1, 10, false, "glow proc duration = %.2f") then
                return
            end
            if arg1 == "offset" and SetGlowOffsetOption("GlowProcXOffset", "GlowProcYOffset", arg2, arg3, "glow proc offset = %.2f %.2f") then
                return
            end
            if arg1 == "startanim" or arg1 == "start" then
                local enabled = ParseToggleValue(arg2)
                if enabled ~= nil then
                    CONFIG.GlowProcStartAnim = enabled
                    CommitGlowOptionChanges()
                    PrintInfo("glow proc startanim = %s", enabled and "on" or "off")
                    return
                end
            end
            PrintInfo("usage: /cdmkp glow proc <duration|offset|startanim> ...")
            return
        end

        PrintInfo("glow commands: glow on|off, glow classcolor <on|off>, glow type <%s>, glow alpha <0-1>, glow brightness <0.1-3>, glow color <r g b|preset>, glow button frequency <value>, glow pixel ..., glow autocast ..., glow proc ...", Private.GetGlowTypeListText("|"))
        return
    end

    if cmd == "mode" and rest == "sent" then
        ApplyTriggerMode("sent")
        RefreshQuickMenu()
        return
    end

    if cmd == "mode" and rest == "succeeded" then
        if Private.LOCK_MODE_TO_SENT then
            PrintInfo("mode locked to sent")
            return
        end
        ApplyTriggerMode("succeeded")
        RefreshQuickMenu()
        return
    end

    if cmd == "mode" and rest == "both" then
        if Private.LOCK_MODE_TO_SENT then
            PrintInfo("mode locked to sent")
            return
        end
        ApplyTriggerMode("both")
        RefreshQuickMenu()
        return
    end

    if cmd == "preset" then
        local presetName = rest:gsub("^%s+", ""):gsub("%s+$", "")

        if presetName == "" or presetName == "status" then
            PrintInfo("preset = %s", state.currentPresetName)
            PrintInfo("presets: %s", Private.GetVisualPresetListText(", "))
            return
        end

        if presetName == "next" then
            Private.CycleVisualPreset(1)
            RefreshQuickMenu()
            return
        end

        if presetName == "prev" or presetName == "previous" then
            Private.CycleVisualPreset(-1)
            RefreshQuickMenu()
            return
        end

        if Private.ApplyVisualPreset(presetName) then
            RefreshQuickMenu()
        else
            PrintInfo("presets: %s", Private.GetVisualPresetListText(", "))
        end
        return
    end

    if cmd == "scan" then
        Private.RunScanNow("slash")
        return
    end

    if cmd == "test" then
        local spellID = Private.ToSpellID(rest)
        if not spellID then
            PrintInfo("usage: /cdmkp test <spellID>")
            return
        end
        local hits = Private.TriggerForSpellID and select(1, Private.TriggerForSpellID(spellID, "Test")) or 0
        PrintInfo("test %d -> %d frame(s)", spellID, hits)
        return
    end

    local modeHelp = Private.LOCK_MODE_TO_SENT and "mode sent" or "mode sent|succeeded|both"
    local presetHelp = Private.LOCK_PRESET_TO_DEFAULT and ("preset " .. GetLockedPresetName()) or "preset <" .. Private.GetVisualPresetListText("|") .. "|next|prev>"
    PrintInfo("commands: menu, status, addons, scan, profile status|set|reset, %s, %s, glow on|off|classcolor|type|alpha|brightness|color|button|pixel|autocast|proc, debug on|off, test <spellID>", presetHelp, modeHelp)
end

SLASH_CDMKEYPRESSSCAN1 = "/cdmkpscan"
SlashCmdList.CDMKEYPRESSSCAN = function()
    Private.RunScanNow("slash-alias")
end

Private.RefreshQuickMenu = RefreshQuickMenu
Private.ToggleQuickMenu = ToggleQuickMenu
Private.EnsureMinimapButton = EnsureMinimapButton
