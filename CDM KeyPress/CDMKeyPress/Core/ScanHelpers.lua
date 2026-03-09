local _, NS = ...

local Private = NS.Private
local CONFIG = Private.CONFIG
local rootNameSet = Private.rootNameSet
local state = Private.state

local dprint = Private.dprint

local trackedFrames = state.trackedFrames
local spellIndex = state.spellIndex
local nameIndex = state.nameIndex
local textureIndex = state.textureIndex

local CountTrackedFrames = function()
    return Private.CountTrackedFrames and Private.CountTrackedFrames() or 0
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
    for i = 1, n do
        local spellID = ToSpellID(select(i, ...))
        if spellID then
            return spellID
        end
    end

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

    if frame.cooldownID and C_CooldownViewer and C_CooldownViewer.GetCooldownViewerCooldownInfo then
        local ok, info = pcall(C_CooldownViewer.GetCooldownViewerCooldownInfo, frame.cooldownID)
        if ok and type(info) == "table" then
            local sid = SpellIDFromCooldownInfo(info)
            if sid then
                return sid
            end
        end
    end

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

local function IsFrameTracked(frame)
    if not frame then
        return false
    end
    return SafeTableGet(trackedFrames, frame) and true or false
end

local function HasTrackingPayload(spellID, spellNameKey, textureKey)
    return spellID ~= nil or spellNameKey ~= nil or textureKey ~= nil
end

local function HasTrackedPayload(frame)
    if not frame then
        return false
    end
    return HasTrackingPayload(frame.__cdmkpSpellID, frame.__cdmkpSpellNameKey, frame.__cdmkpTextureKey)
end

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

    if IsFrameTracked(frame) then
        UnindexFrameAll(frame)
        SafeTableSet(trackedFrames, frame, nil)
    end

    if state.activePressedState and type(state.activePressedState.frames) == "table" and state.activePressedState.frames[frame] then
        state.activePressedState.frames[frame] = nil
        if not next(state.activePressedState.frames) then
            state.activePressedState = nil
        end
    end

    if frame.__cdmkpPressedOverlay then
        frame.__cdmkpPressedOverlay:SetAlpha(0)
    end
    frame.__cdmkpGlowActive = nil
    if Private.ApplyGlowState then
        Private.ApplyGlowState(frame)
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

local function TrackIconFrame(frame)
    local wasTracked = IsFrameTracked(frame)

    if not frame then
        return false
    end

    if IsForbiddenSafe(frame) or IsProtectedSafe(frame) then
        if wasTracked then
            UntrackIconFrame(frame)
        end
        return false
    end

    local objectType = frame.GetObjectType and frame:GetObjectType()
    if objectType ~= "Button" and objectType ~= "Frame" then
        if wasTracked then
            UntrackIconFrame(frame)
        end
        return false
    end

    if not IsLikelyCDMContext(frame) then
        if wasTracked then
            UntrackIconFrame(frame)
        end
        return false
    end

    local namedLikeIcon = MatchAnyPattern(GetFrameName(frame), CONFIG.IconNamePatterns)
    if not HasIconTexture(frame) and not namedLikeIcon then
        if wasTracked then
            UntrackIconFrame(frame)
        end
        return false
    end

    local spellID = ExtractSpellID(frame)
    local spellName = ExtractSpellName(frame, spellID)
    local textureKey = ExtractFrameTextureKey(frame)
    local spellNameKey = NormalizeSpellName(spellName)

    if not HasTrackingPayload(spellID, spellNameKey, textureKey) then
        if wasTracked then
            UntrackIconFrame(frame)
        end
        return false
    end

    local isNew = not wasTracked

    if not isNew
        and SafeValuesEqual(frame.__cdmkpSpellID, spellID)
        and SafeValuesEqual(frame.__cdmkpSpellNameKey, spellNameKey)
        and SafeValuesEqual(frame.__cdmkpTextureKey, textureKey) then
        return true
    end

    SafeTableSet(trackedFrames, frame, true)

    if Private.EnsurePressAnimation then
        Private.EnsurePressAnimation(frame)
    end

    if spellID then
        IndexFrameSpell(frame, spellID)
    else
        UnindexFrameSpell(frame)
    end
    IndexFrameName(frame, spellNameKey)
    IndexFrameTexture(frame, textureKey)

    if isNew and not state.cdmLoadedByName and CountTrackedFrames() == 1 then
        dprint("CDM context auto-detected from active tracked frame")
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

Private.IsAddOnLoadedSafe = IsAddOnLoadedSafe
Private.IsConfiguredCDMAddon = IsConfiguredCDMAddon
Private.DetectLoadedCDMAddon = DetectLoadedCDMAddon
Private.IsForbiddenSafe = IsForbiddenSafe
Private.IsProtectedSafe = IsProtectedSafe
Private.MatchAnyPattern = MatchAnyPattern
Private.ToPlainString = ToPlainString
Private.ToNormalizedString = ToNormalizedString
Private.SafeValuesEqual = SafeValuesEqual
Private.ToPlainNumber = ToPlainNumber
Private.ToPositiveIntegerString = ToPositiveIntegerString
Private.ToSpellID = ToSpellID
Private.NormalizeSpellName = NormalizeSpellName
Private.NormalizeTextureKey = NormalizeTextureKey
Private.GetSpellNameSafe = GetSpellNameSafe
Private.GetSpellTextureSafe = GetSpellTextureSafe
Private.ResolveSpellIDFromSpellName = ResolveSpellIDFromSpellName
Private.ResolveSpellIDFromEventArgs = ResolveSpellIDFromEventArgs
Private.GetFrameName = GetFrameName
Private.ReadTextureFromCandidate = ReadTextureFromCandidate
Private.ReadTextureObjectFromCandidate = ReadTextureObjectFromCandidate
Private.ExtractFrameIconTextureObject = ExtractFrameIconTextureObject
Private.SafeTableGet = SafeTableGet
Private.SafeTableSet = SafeTableSet
Private.SafeBucketSet = SafeBucketSet
Private.HasTrackedPayload = HasTrackedPayload
Private.UntrackIconFrame = UntrackIconFrame
Private.TrackIconFrame = TrackIconFrame
