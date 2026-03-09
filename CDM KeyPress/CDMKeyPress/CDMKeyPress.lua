local ADDON_NAME, NS = ...

local Private = NS.Private

local Dispatcher = CreateFrame("Frame")

local function OnAddonLoaded(loadedAddonName)
    if loadedAddonName == ADDON_NAME then
        Private.InitializeProfileDB()
        if Private.EnsurePredictiveActionButtonHooks then
            Private.EnsurePredictiveActionButtonHooks()
        end

        local loaded, foundName = Private.DetectLoadedCDMAddon()
        if loaded then
            Private.state.cdmLoadedByName = true
            Private.dprint("Detected CDM addon by configured name:", foundName)
        else
            Private.dprint("No configured CDM addon name matched; fallback scan is active.")
        end

        Private.StartScanner()
        return
    end

    if Private.IsConfiguredCDMAddon(loadedAddonName) then
        Private.state.cdmLoadedByName = true
        Private.dprint("Detected CDM addon load:", loadedAddonName)
        Private.EnsureViewerScanHooks()
        if Private.state.startupScanDone then
            pcall(Private.ScanForCDMIcons, "addon-load", nil)
        else
            Private.StartScanner()
        end
        return
    end

    if Private.state.startupScanDone then
        if Private.EnsurePredictiveActionButtonHooks then
            Private.EnsurePredictiveActionButtonHooks()
        end
        Private.EnsureViewerScanHooks()
        Private.ScheduleViewerRescan(0.10)
    end
end

Dispatcher:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        OnAddonLoaded(...)
    elseif event == "PLAYER_LOGIN" then
        if type(Private.state.savedDB) ~= "table" then
            Private.InitializeProfileDB()
        else
            Private.RebindCharacterProfileKey()
        end
        if Private.EnsureMinimapButton then
            Private.EnsureMinimapButton()
        end
        if Private.EnsurePredictiveActionButtonHooks then
            Private.EnsurePredictiveActionButtonHooks()
        end
        Private.StartScanner()
    elseif event == "UNIT_SPELLCAST_SENT" then
        Private.OnSpellcastSent(...)
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        Private.OnSpellcastSucceeded(...)
    elseif event == "UNIT_SPELLCAST_FAILED" then
        Private.OnSpellcastEnded("failed", ...)
    elseif event == "UNIT_SPELLCAST_FAILED_QUIET" then
        Private.OnSpellcastEnded("failed_quiet", ...)
    elseif event == "UNIT_SPELLCAST_INTERRUPTED" then
        Private.OnSpellcastEnded("interrupted", ...)
    elseif event == "UNIT_SPELLCAST_STOP" then
        Private.OnSpellcastEnded("stop", ...)
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

NS.CONFIG = Private.CONFIG
NS.ScanForCDMIcons = Private.ScanForCDMIcons
NS.SwitchProfile = Private.SwitchProfile
