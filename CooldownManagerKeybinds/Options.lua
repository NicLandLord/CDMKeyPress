-- CooldownManagerKeybinds - Options (Ace3 dropdowns + standard color picker)
-- Requires: AceConfigRegistry-3.0, AceConfigDialog-3.0, AceGUI-3.0
-- Optional: LibSharedMedia-3.0
-- Note: Blizzard Settings panel is a launcher only (opens the AceConfigDialog window)

local ADDON_NAME, ns = ...

local AceConfigRegistry = LibStub("AceConfigRegistry-3.0", true)
local AceConfigDialog   = LibStub("AceConfigDialog-3.0", true)
local LSM               = LibStub("LibSharedMedia-3.0", true)

local APP_NAME = "CMK"
local registered = false

local anchorChoices = {
    TOPLEFT     = "Top Left",
    TOP         = "Top",
    TOPRIGHT    = "Top Right",
    LEFT        = "Left",
    CENTER      = "Center",
    RIGHT       = "Right",
    BOTTOMLEFT  = "Bottom Left",
    BOTTOM      = "Bottom",
    BOTTOMRIGHT = "Bottom Right",
}

local outlineChoices = {
    [""]                        = "None",
    ["OUTLINE"]                 = "Outline",
    ["THICKOUTLINE"]            = "Thick Outline",
    ["MONOCHROME"]              = "Monochrome",
    ["MONOCHROME,OUTLINE"]      = "Mono Outline",
    ["MONOCHROME,THICKOUTLINE"] = "Mono Thick",
}

local function IsBCDMLoaded()
    return C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("BetterCooldownManager")
end

local function IsAyijeCDMLoaded()
    return C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("Ayije_CDM")
end

local function GetViewer(viewerKey)
    if not ns.db or not ns.db.profile then return nil end
    ns.db.profile.viewers = ns.db.profile.viewers or {}
    ns.db.profile.viewers[viewerKey] = ns.db.profile.viewers[viewerKey] or {}
    return ns.db.profile.viewers[viewerKey]
end

local function NotifyChanged()
    if ns.Keybinds and ns.Keybinds.OnSettingChanged then
        ns.Keybinds:OnSettingChanged()
    end
end

-- Cache font list so the dropdown does not churn
local fontValuesCache
local function FontValues()
    if fontValuesCache then return fontValuesCache end

    local t = {}
    if LSM and LSM.List then
        local list = LSM:List("font")
        if list and #list > 0 then
            for _, name in ipairs(list) do
                t[name] = name
            end
        end
    end

    if not next(t) then
        t["Friz Quadrata TT"] = "Friz Quadrata TT"
    end

    fontValuesCache = t
    return t
end

local function DefaultFontSize(viewerKey)
    if viewerKey == "Essential" or viewerKey == "BCDMCustomItemSpellBar" then return 13 end
    return 12
end

local function ViewerGroup(viewerKey, label, order)
    return {
        type  = "group",
        name  = label,
        order = order,
        args  = {
            showKeybinds = {
                type  = "toggle",
                name  = "Show keybinds",
                order = 1,
                get = function()
                    local v = GetViewer(viewerKey)
                    return v and (v.showKeybinds ~= false) or false
                end,
                set = function(_, val)
                    local v = GetViewer(viewerKey)
                    if not v then return end
                    v.showKeybinds = val
                    NotifyChanged()
                end,
            },

            fontName = {
                type   = "select",
                name   = "Font family",
                order  = 2,
                values = FontValues,
                get = function()
                    local v = GetViewer(viewerKey)
                    local current = (v and v.fontName) or "Friz Quadrata TT"
                    local values = FontValues()
                    if values[current] then return current end
                    return "Friz Quadrata TT"
                end,
                set = function(_, val)
                    local v = GetViewer(viewerKey)
                    if not v then return end
                    v.fontName = val
                    NotifyChanged()
                end,
            },

            fontSize = {
                type  = "range",
                name  = "Font size",
                order = 3,
                min   = 8,
                max   = 24,
                step  = 1,
                get = function()
                    local v = GetViewer(viewerKey)
                    return (v and v.fontSize) or DefaultFontSize(viewerKey)
                end,
                set = function(_, val)
                    local v = GetViewer(viewerKey)
                    if not v then return end
                    v.fontSize = val
                    NotifyChanged()
                end,
            },

            fontFlags = {
                type   = "select",
                name   = "Outline",
                order  = 4,
                values = outlineChoices,
                get = function()
                    local v = GetViewer(viewerKey)
                    local f = (v and v.fontFlags) or ""
                    if outlineChoices[f] ~= nil then return f end
                    return ""
                end,
                set = function(_, val)
                    local v = GetViewer(viewerKey)
                    if not v then return end
                    v.fontFlags = val
                    NotifyChanged()
                end,
            },

            color = {
                type     = "color",
                name     = "Font colour",
                order    = 5,
                hasAlpha = true,
                get = function()
                    local v = GetViewer(viewerKey)
                    local c = (v and v.color) or { 1, 1, 1, 1 }
                    return c[1], c[2], c[3], c[4]
                end,
                set = function(_, r, g, b, a)
                    local v = GetViewer(viewerKey)
                    if not v then return end
                    v.color = { r, g, b, a }
                    NotifyChanged()
                end,
            },

            posHeader = {
                type  = "header",
                name  = "Keybind position",
                order = 20,
            },

            anchor = {
                type   = "select",
                name   = "Anchor",
                order  = 21,
                values = anchorChoices,
                get = function()
                    local v = GetViewer(viewerKey)
                    local a = (v and v.anchor) or "TOPRIGHT"
                    if anchorChoices[a] then return a end
                    return "TOPRIGHT"
                end,
                set = function(_, val)
                    local v = GetViewer(viewerKey)
                    if not v then return end
                    v.anchor = val
                    NotifyChanged()
                end,
            },

            offsetX = {
                type  = "range",
                name  = "Offset X",
                order = 22,
                min   = -50,
                max   = 50,
                step  = 1,
                get = function()
                    local v = GetViewer(viewerKey)
                    if not v then return -1 end
                    return (v.offsetX ~= nil) and v.offsetX or -1
                end,
                set = function(_, val)
                    local v = GetViewer(viewerKey)
                    if not v then return end
                    v.offsetX = val
                    NotifyChanged()
                end,
            },

            offsetY = {
                type  = "range",
                name  = "Offset Y",
                order = 23,
                min   = -50,
                max   = 50,
                step  = 1,
                get = function()
                    local v = GetViewer(viewerKey)
                    if not v then return -1 end
                    return (v.offsetY ~= nil) and v.offsetY or -1
                end,
                set = function(_, val)
                    local v = GetViewer(viewerKey)
                    if not v then return end
                    v.offsetY = val
                    NotifyChanged()
                end,
            },
        },
    }
end

local function BuildOptionsTable()
    local opts = {
        type = "group",
        name = "CooldownManagerKeybinds",
        args = {
            enabled = {
                type  = "toggle",
                name  = "Enable",
                order = 1,
                get = function()
                    return ns.db and ns.db.profile and ns.db.profile.enabled or false
                end,
                set = function(_, val)
                    if not ns.db or not ns.db.profile then return end
                    ns.db.profile.enabled = val
                    NotifyChanged()
                end,
            },

            essential = ViewerGroup("Essential", "Essential", 10),
            utility   = ViewerGroup("Utility", "Utility", 20),

            bcdmInfo = {
                type  = "description",
                name  = "Custom Spells, Custom Items, and Trinket Bar settings are available when BetterCooldownManager is installed and enabled.",
                order = 29,
                hidden = function()
                    return IsBCDMLoaded()
                end,
            },

            customSpells        = ViewerGroup("BCDMCustomSpells",        "Custom Spells",          30),
            customItemSpellBar  = ViewerGroup("BCDMCustomItemSpellBar",  "Custom Item Spell Bar", 35),
            customItems         = ViewerGroup("BCDMCustomItems",         "Custom Items",           40),
            trinkets            = ViewerGroup("BCDMTrinkets",            "Trinket Bar",            50),

            ayijeInfo = {
                type  = "description",
                name  = "Defensives, Trinkets, and Racials settings are available when Ayije_CDM is installed and enabled.",
                order = 59,
                hidden = function()
                    return IsAyijeCDMLoaded()
                end,
            },

            ayijeDefensives = ViewerGroup("Defensives", "Defensives", 60),
            ayijeTrinkets   = ViewerGroup("Trinkets",   "Trinkets",   70),
            ayijeRacials    = ViewerGroup("Racials",    "Racials",    80),
        },
    }

    -- Only show BCDM groups when BetterCooldownManager is loaded
    opts.args.customSpells.hidden = function()
        return not IsBCDMLoaded()
    end
    opts.args.customItemSpellBar.hidden = function()
        return not IsBCDMLoaded()
    end
    opts.args.customItems.hidden = function()
        return not IsBCDMLoaded()
    end
    opts.args.trinkets.hidden = function()
        return not IsBCDMLoaded()
    end

    -- Only show Ayije_CDM groups when Ayije_CDM is loaded
    opts.args.ayijeDefensives.hidden = function()
        return not IsAyijeCDMLoaded()
    end
    opts.args.ayijeTrinkets.hidden = function()
        return not IsAyijeCDMLoaded()
    end
    opts.args.ayijeRacials.hidden = function()
        return not IsAyijeCDMLoaded()
    end

    -- Keep reset at the end
    opts.args.reset = {
        type        = "execute",
        name        = "Reset to defaults",
        order       = 99,
        confirm     = true,
        confirmText = "Reset all CMK settings to defaults?",
        func = function()
            if ns.Keybinds and ns.Keybinds.ResetProfileToDefaults then
                ns.Keybinds:ResetProfileToDefaults()
            end
        end,
    }

    return opts
end

local function CreateBlizzardSettingsLauncher()
    local panel = CreateFrame("Frame")
    panel.name = "CooldownManagerKeybinds"

    local built = false
    panel:SetScript("OnShow", function(self)
        if built then return end
        built = true

        local title = self:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
        title:SetPoint("TOPLEFT", 16, -16)
        title:SetText("CooldownManagerKeybinds")

        local desc = self:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
        desc:SetWidth(560)
        desc:SetJustifyH("LEFT")
        desc:SetText("Open the CMK options window.")

        local btn = CreateFrame("Button", nil, self, "UIPanelButtonTemplate")
        btn:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -12)
        btn:SetSize(180, 24)
        btn:SetText("Open CMK Options")
        btn:SetScript("OnClick", function()
            ns.OpenOptions()
        end)
    end)

    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
        Settings.RegisterAddOnCategory(category)
        return
    end

    if InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
    end
end

function ns.RegisterOptions()
    if registered then return end

    if not AceConfigRegistry or not AceConfigDialog then
        print("CMK: Options libraries missing. Check TOC loads AceConfigRegistry-3.0, AceConfigDialog-3.0, and AceGUI-3.0.")
        return
    end

    AceConfigRegistry:RegisterOptionsTable(APP_NAME, BuildOptionsTable())
    CreateBlizzardSettingsLauncher()

    registered = true
end

function ns.OpenOptions()
    if not AceConfigDialog then
        print("CMK: Options UI not available.")
        return
    end

    local ok, err = pcall(function()
        AceConfigDialog:Open(APP_NAME)
    end)
    if not ok then
        print("CMK: Options UI failed to open. " .. tostring(err))
    end
end