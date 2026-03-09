local _, NS = ...

local Private = NS.Private
local CONFIG = Private.CONFIG
local state = Private.state

local Clamp = Private.Clamp
local FormatText = Private.FormatText
local GetNow = Private.GetNow
local dprint = Private.dprint
local PrintError = Private.PrintError
local PrintInfo = Private.PrintInfo

local trackedFrames = state.trackedFrames

local function RecordScanMetrics(source, mode, scanned, rootCount, fallbackDecision)
    local tracked = 0
    for frame in pairs(trackedFrames) do
        if frame and Private.HasTrackedPayload(frame) then
            tracked = tracked + 1
        end
    end
    state.scanMetrics.totalScans = state.scanMetrics.totalScans + 1
    state.scanMetrics.totalFramesScanned = state.scanMetrics.totalFramesScanned + (scanned or 0)
    state.scanMetrics.last.source = source or "unknown"
    state.scanMetrics.last.mode = mode or "none"
    state.scanMetrics.last.scanned = scanned or 0
    state.scanMetrics.last.tracked = tracked
    state.scanMetrics.last.roots = rootCount or 0
    state.scanMetrics.last.fallback = fallbackDecision or "none"
    state.scanMetrics.last.age = GetNow()

    dprint(("Scan source=%s mode=%s checked=%d tracked=%d roots=%d fallback=%s"):format(
        state.scanMetrics.last.source,
        state.scanMetrics.last.mode,
        state.scanMetrics.last.scanned,
        tracked,
        state.scanMetrics.last.roots,
        state.scanMetrics.last.fallback
    ))
end

local function GetScanAgeSeconds()
    if not state.scanMetrics.last.age or state.scanMetrics.last.age <= 0 then
        return nil
    end
    return math.max(0, GetNow() - state.scanMetrics.last.age)
end

local function GetScanSummaryText()
    local age = GetScanAgeSeconds()
    local ageText = age and ("%.1fs"):format(age) or FormatText("never")
    return FormatText("scan=%s mode=%s checked=%d tracked=%d roots=%d fallback=%s age=%s",
        state.scanMetrics.last.source or "none",
        state.scanMetrics.last.mode or "none",
        state.scanMetrics.last.scanned or 0,
        state.scanMetrics.last.tracked or 0,
        state.scanMetrics.last.roots or 0,
        state.scanMetrics.last.fallback or "none",
        ageText
    )
end

local function GetScanTotalsText()
    return FormatText("scanTotals=%d frames=%d startupRetries=%d fallback=%d/%d skipped=%d viewerFlush=%d viewerFrames=%d",
        state.scanMetrics.totalScans or 0,
        state.scanMetrics.totalFramesScanned or 0,
        state.scanMetrics.startupRetryAttempts or 0,
        state.scanMetrics.fallbackExecuted or 0,
        state.scanMetrics.fallbackAttempts or 0,
        state.scanMetrics.fallbackSkipped or 0,
        state.scanMetrics.viewerRootFlushes or 0,
        state.scanMetrics.viewerRootFramesScanned or 0
    )
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
        Private.TrackIconFrame(frame)

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
                Private.TrackIconFrame(frame)
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
        Private.TrackIconFrame(frame)
        frame = EnumerateFrames(frame)
    end

    return scanned
end

local function CountTrackedFrames()
    local n = 0
    for frame in pairs(trackedFrames) do
        if frame and Private.HasTrackedPayload(frame) then
            n = n + 1
        end
    end
    return n
end

local function HasTrackedFrames()
    for frame in pairs(trackedFrames) do
        if frame and Private.HasTrackedPayload(frame) then
            return true
        end
    end
    return false
end

local function HasConfiguredRootsPresent()
    return #FindConfiguredRoots() > 0
end

local function GetDetectionState()
    local hasTrackedFrames = HasTrackedFrames()
    local hasConfiguredRoots = HasConfiguredRootsPresent()

    if state.cdmLoadedByName then
        return true, hasTrackedFrames and "name+frame" or "name-match"
    end

    if hasTrackedFrames then
        return true, "frame-auto"
    end

    if hasConfiguredRoots then
        return true, "frame-root"
    end

    if CONFIG.EnableFallbackScanWithoutKnownAddon then
        return false, "fallback-scan"
    end

    return false, "not-detected"
end

local function ShouldRunScan()
    return state.cdmLoadedByName or HasTrackedFrames() or HasConfiguredRootsPresent() or CONFIG.EnableFallbackScanWithoutKnownAddon
end

local function ShouldRunFallbackScan(source, allowBypass)
    state.scanMetrics.fallbackAttempts = state.scanMetrics.fallbackAttempts + 1

    local now = GetNow()
    if allowBypass then
        state.lastFallbackScanAt = now
        state.scanMetrics.fallbackExecuted = state.scanMetrics.fallbackExecuted + 1
        return true, "manual-bypass"
    end

    local minInterval = tonumber(CONFIG.FallbackAutoScanMinIntervalSeconds) or 2.50
    minInterval = Clamp(minInterval, 0, 30)

    if state.lastFallbackScanAt > 0 and (now - state.lastFallbackScanAt) < minInterval then
        state.scanMetrics.fallbackSkipped = state.scanMetrics.fallbackSkipped + 1
        dprint(("Fallback scan skipped (%s): %.2fs < %.2fs"):format(
            source or "unknown",
            now - state.lastFallbackScanAt,
            minInterval
        ))
        return false, "throttled"
    end

    state.lastFallbackScanAt = now
    state.scanMetrics.fallbackExecuted = state.scanMetrics.fallbackExecuted + 1
    return true, "executed"
end

local function ScanForCDMIcons(source, options)
    if not ShouldRunScan() then
        RecordScanMetrics(source or "unknown", "gated", 0, 0, "not-needed")
        return 0
    end

    local scanned = 0
    local roots = FindConfiguredRoots()
    local rootCount = #roots
    local mode = "none"
    local fallbackDecision = "not-used"

    if rootCount > 0 then
        mode = "roots"
        local budget = CONFIG.MaxFramesPerScan
        for i = 1, rootCount do
            if budget <= 0 then
                break
            end
            local used = RunScanForRoot(roots[i], budget)
            scanned = scanned + used
            budget = budget - used
        end
    else
        local allowFallbackBypass = options and options.allowFallbackBypass
        local shouldRunFallback
        shouldRunFallback, fallbackDecision = ShouldRunFallbackScan(source, allowFallbackBypass)

        if shouldRunFallback then
            mode = "fallback"
            scanned = FallbackGlobalScan()
            if not state.warnedFallbackScan then
                state.warnedFallbackScan = true
                dprint("Using fallback global scan. Set CONFIG.RootFrameNames for better performance.")
            end
        else
            mode = "fallback-throttled"
        end
    end

    RecordScanMetrics(source or "unknown", mode, scanned, rootCount, fallbackDecision)
    return scanned
end

local function RunScanNow(source)
    local ok, err = pcall(ScanForCDMIcons, source or "manual", { allowFallbackBypass = true })
    if not ok then
        PrintError("scan error (%s): %s", source or "unknown", tostring(err))
        return false
    end
    PrintInfo("tracked %d frame(s)", CountTrackedFrames())
    return true
end

local function RunAutoScan(source, announce)
    local ok, err = pcall(ScanForCDMIcons, source or "auto", nil)
    if not ok then
        PrintError("auto-scan error (%s): %s", source or "unknown", tostring(err))
        return false
    end
    if announce then
        PrintInfo("startup scan: tracked %d frame(s)", CountTrackedFrames())
    end
    return true
end

local function StartScanner()
    if state.startupScanDone then
        Private.EnsureViewerScanHooks()
        return
    end

    state.startupScanDone = true
    Private.EnsureViewerScanHooks()

    local startupDelays = { 0.0, 0.4, 1.0, 2.0 }
    for i = 1, #startupDelays do
        C_Timer.After(startupDelays[i], function()
            RunAutoScan("startup", i == #startupDelays)
        end)
    end

    local attemptsLeft = math.max(0, math.floor(tonumber(CONFIG.StartupRetryMaxAttempts) or 10))
    if attemptsLeft > 0 then
        state.startupRetryTicker = C_Timer.NewTicker(1.5, function()
            if CountTrackedFrames() > 0 then
                if state.startupRetryTicker then
                    state.startupRetryTicker:Cancel()
                    state.startupRetryTicker = nil
                end
                dprint("Startup scan retries stopped (frames detected)")
                return
            end

            state.scanMetrics.startupRetryAttempts = state.scanMetrics.startupRetryAttempts + 1
            RunAutoScan("startup-retry", attemptsLeft == 1)
            attemptsLeft = attemptsLeft - 1
            if attemptsLeft <= 0 and state.startupRetryTicker then
                state.startupRetryTicker:Cancel()
                state.startupRetryTicker = nil
                dprint("Startup scan retries exhausted")
            end
        end)
    else
        dprint("Startup scan retries disabled")
    end

    dprint("Startup scan complete (auto periodic scan disabled)")
end

local function FlushQueuedViewerRescans()
    state.viewerRescanTimer = nil
    state.viewerRescanDelay = nil

    local runFullScan = state.viewerRescanFullScanQueued
    local queuedRoots = state.queuedViewerRescanRoots

    state.viewerRescanFullScanQueued = false
    state.queuedViewerRescanRoots = setmetatable({}, { __mode = "k" })

    if runFullScan then
        pcall(ScanForCDMIcons, "viewer-full", nil)
        return
    end

    local budget = CONFIG.MaxFramesPerScan
    local scannedTotal = 0
    local rootCount = 0
    for root in pairs(queuedRoots) do
        if budget <= 0 then
            break
        end

        rootCount = rootCount + 1
        local ok, scanned = pcall(RunScanForRoot, root, budget)
        if ok and type(scanned) == "number" then
            scannedTotal = scannedTotal + scanned
            budget = budget - scanned
        end
    end

    state.scanMetrics.viewerRootFlushes = state.scanMetrics.viewerRootFlushes + 1
    state.scanMetrics.viewerRootFramesScanned = state.scanMetrics.viewerRootFramesScanned + scannedTotal
    RecordScanMetrics("viewer-root", "roots-batched", scannedTotal, rootCount, "not-used")
end

local function ScheduleViewerRescan(rootOrDelay, delaySeconds)
    local root = nil
    local delay = delaySeconds

    if type(rootOrDelay) == "number" then
        delay = rootOrDelay
    elseif type(rootOrDelay) == "table" then
        root = rootOrDelay
    end

    delay = delay or 0.05

    if root then
        state.queuedViewerRescanRoots[root] = true
    else
        state.viewerRescanFullScanQueued = true
    end

    if state.viewerRescanTimer and state.viewerRescanDelay and delay >= state.viewerRescanDelay then
        return
    end

    if state.viewerRescanTimer then
        state.viewerRescanTimer:Cancel()
        state.viewerRescanTimer = nil
    end

    state.viewerRescanDelay = delay
    state.viewerRescanTimer = C_Timer.NewTimer(delay, FlushQueuedViewerRescans)
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
        local parentName = Private.GetFrameName(parent)
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
    if state.viewerMixinHooked[mixinName] then
        return
    end
    state.viewerMixinHooked[mixinName] = true

    local function onMixinEvent(frame)
        if not frame or Private.IsForbiddenSafe(frame) then
            return
        end
        if expectedViewerName and not DoesFrameBelongToViewer(frame, expectedViewerName) then
            return
        end

        local tracked = Private.TrackIconFrame(frame)
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

local function EnsureViewerScanHooks()
    if not hooksecurefunc then
        return
    end

    for i = 1, #CONFIG.ViewerFrameNames do
        local viewerName = CONFIG.ViewerFrameNames[i]
        if not state.viewerScanHooked[viewerName] then
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
                    if not state.viewerPoolAcquireHooked[pool] and type(pool.Acquire) == "function" then
                        state.viewerPoolAcquireHooked[pool] = true
                        hooksecurefunc(pool, "Acquire", function(_, acquiredFrame)
                            if acquiredFrame then
                                Private.TrackIconFrame(acquiredFrame)
                            end
                            ScheduleViewerRescan(frame, 0.05)
                        end)
                    end
                    if not state.viewerPoolReleaseHooked[pool] and type(pool.Release) == "function" then
                        state.viewerPoolReleaseHooked[pool] = true
                        hooksecurefunc(pool, "Release", function(_, releasedFrame)
                            if releasedFrame then
                                Private.UntrackIconFrame(releasedFrame)
                            end
                        end)
                    end
                end

                state.viewerScanHooked[viewerName] = true
            end
        end
    end

    local ayije = _G["Ayije_CDM"]
    if ayije and not state.ayijeQueueHooked and type(ayije.QueueViewer) == "function" then
        state.ayijeQueueHooked = true
        hooksecurefunc(ayije, "QueueViewer", function(_, viewerName)
            if not viewerName or IsKnownViewerName(viewerName) then
                ScheduleViewerRescan(viewerName and _G[viewerName] or nil, 0.05)
            end
        end)
    end

    HookViewerItemMixin("CooldownViewerEssentialItemMixin", "EssentialCooldownViewer")
    HookViewerItemMixin("CooldownViewerUtilityItemMixin", "UtilityCooldownViewer")
end

local function GetLoadedCandidatesText()
    local parts = {}
    for _, name in ipairs(CONFIG.CDMAddonNames) do
        parts[#parts + 1] = ("%s=%s"):format(name, Private.IsAddOnLoadedSafe(name) and "1" or "0")
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
        PrintInfo("no loaded addon matched midnight/cooldown/cdm")
        return
    end
    PrintInfo("loaded addon hints: %s", table.concat(hits, ", "))
end

Private.RecordScanMetrics = RecordScanMetrics
Private.GetScanSummaryText = GetScanSummaryText
Private.GetScanTotalsText = GetScanTotalsText
Private.CountTrackedFrames = CountTrackedFrames
Private.GetDetectionState = GetDetectionState
Private.ScanForCDMIcons = ScanForCDMIcons
Private.RunScanNow = RunScanNow
Private.RunAutoScan = RunAutoScan
Private.StartScanner = StartScanner
Private.ScheduleViewerRescan = ScheduleViewerRescan
Private.EnsureViewerScanHooks = EnsureViewerScanHooks
Private.GetLoadedCandidatesText = GetLoadedCandidatesText
Private.PrintLoadedAddonHints = PrintLoadedAddonHints
