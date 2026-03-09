local _, NS = ...

local Private = NS.Private
local CONFIG = Private.CONFIG
local GLOW_COLOR_PRESETS = Private.GLOW_COLOR_PRESETS
local state = Private.state
local ICON_TEXTURE_PATH = Private.ICON_TEXTURE_PATH

local CopyRGB = Private.CopyRGB
local Clamp = Private.Clamp

local UI_STYLE = {
    frame = { 0.045, 0.050, 0.065, 0.98 },
    header = { 0.090, 0.070, 0.045, 0.98 },
    sidebar = { 0.060, 0.065, 0.085, 0.98 },
    panel = { 0.080, 0.085, 0.110, 0.94 },
    panelSoft = { 0.100, 0.105, 0.130, 0.88 },
    border = { 0.240, 0.210, 0.160, 1.00 },
    borderSoft = { 0.180, 0.190, 0.240, 1.00 },
    accent = { 0.950, 0.780, 0.320, 1.00 },
    accentMuted = { 0.700, 0.580, 0.260, 1.00 },
    text = { 0.980, 0.960, 0.920, 1.00 },
    subtle = { 0.780, 0.800, 0.860, 1.00 },
    faint = { 0.580, 0.620, 0.700, 1.00 },
    success = { 0.300, 0.900, 0.580, 1.00 },
}

local GLOW_TYPE_PREVIEW_DATA = {
    button = {
        icon = "Interface\\Icons\\Ability_Warrior_InnerRage",
        subtitle = "Classic alert ring.",
    },
    pixel = {
        icon = "Interface\\Icons\\INV_Enchant_EssenceCosmicGreater",
        subtitle = "Angular edge glow.",
    },
    autocast = {
        icon = "Interface\\Icons\\Ability_Hunter_Longevity",
        subtitle = "Orbiting spark trail.",
    },
    proc = {
        icon = "Interface\\Icons\\Spell_Shaman_LavaBurst",
        subtitle = "Burst proc frame.",
    },
}

local sliderSerial = 0
local CLASS_ICON_TEXTURE = "Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES"
local BuildAdvancedGroup

local function GetTriggerModeLabel()
    if CONFIG.TriggerOnSpellSent and CONFIG.TriggerOnSpellSucceeded then
        return "both"
    end
    if CONFIG.TriggerOnSpellSent then
        return "sent"
    end
    return "succeeded"
end

local function GetSettingsTabLabel()
    local locale = type(GetLocale) == "function" and GetLocale() or "enUS"
    if locale == "frFR" then
        return "Paramètres"
    end
    return "Option"
end

local function GetSettingsTabSubtitle()
    local locale = type(GetLocale) == "function" and GetLocale() or "enUS"
    if locale == "frFR" then
        return "Glow, flash, style"
    end
    return "Glow, flash, style"
end

GetSettingsTabLabel = function()
    local locale = type(GetLocale) == "function" and GetLocale() or "enUS"
    if locale == "frFR" then
        return "Param\195\168tres"
    end
    return "Option"
end

local function ApplyBackdrop(frame, bg, border)
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        tile = false,
        insets = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    frame:SetBackdropColor(unpack(bg or UI_STYLE.panel))
    frame:SetBackdropBorderColor(unpack(border or UI_STYLE.borderSoft))
end

local function SetTextColor(fontString, color)
    if fontString and color then
        fontString:SetTextColor(color[1], color[2], color[3], color[4] or 1)
    end
end

local function SetFontSize(fontString, size)
    if not fontString or not size then
        return
    end

    local fontPath, _, flags = fontString:GetFont()
    if fontPath then
        fontString:SetFont(fontPath, size, flags)
    end
end

local function ConfigureTextBlock(fontString, width, color, justify)
    if not fontString then
        return
    end

    if width then
        fontString:SetWidth(width)
    end
    fontString:SetJustifyH(justify or "LEFT")
    fontString:SetJustifyV("TOP")
    if fontString.SetWordWrap then
        fontString:SetWordWrap(true)
    end
    if fontString.SetNonSpaceWrap then
        fontString:SetNonSpaceWrap(false)
    end
    if color then
        SetTextColor(fontString, color)
    end
end

local function SetClassIcon(texture)
    if not texture then
        return
    end

    local _, classToken = UnitClass("player")
    local coords = classToken and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[classToken]
    if coords then
        texture:SetTexture(CLASS_ICON_TEXTURE)
        texture:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
    else
        texture:SetTexture(ICON_TEXTURE_PATH)
        texture:SetTexCoord(0, 1, 0, 1)
    end
end

local function CommitGlowOptionChanges()
    if Private.RefreshTrackedVisuals then
        Private.RefreshTrackedVisuals()
    end
    if Private.PersistActiveProfile then
        Private.PersistActiveProfile()
    end
    if Private.RefreshModernMenu then
        Private.RefreshModernMenu()
    end
end

local function SetGlowBooleanConfig(key, enabled)
    CONFIG[key] = enabled and true or false
    CommitGlowOptionChanges()
end

local function SetGlowColorConfig(color)
    CONFIG.GlowColor = CopyRGB(color)
    CommitGlowOptionChanges()
end

local function SetGlowUseClassColorConfig(enabled)
    CONFIG.GlowUseClassColor = enabled and true or false
    CommitGlowOptionChanges()
end

local function SetGlowTypeConfig(value)
    local normalized = Private.NormalizeGlowType and Private.NormalizeGlowType(value)
    if not normalized then
        return false
    end
    CONFIG.GlowType = normalized
    CommitGlowOptionChanges()
    return true
end

local function SetSliderConfigValue(key, value, minValue, maxValue, roundValue)
    value = Clamp(tonumber(value) or 0, minValue, maxValue)
    if roundValue then
        value = math.floor(value + 0.5)
    end
    CONFIG[key] = value
    CommitGlowOptionChanges()
end

local function SetFlashTimingConfig(key, value, minValue, maxValue)
    value = Clamp(tonumber(value) or 0, minValue, maxValue)

    if key == "PressedMinHoldSeconds" then
        CONFIG.PressedMinHoldSeconds = value
        if (CONFIG.PressedMaxHoldSeconds or value) < value then
            CONFIG.PressedMaxHoldSeconds = value
        end
    elseif key == "PressedMaxHoldSeconds" then
        local minHold = CONFIG.PressedMinHoldSeconds or minValue
        CONFIG.PressedMaxHoldSeconds = math.max(value, minHold)
    else
        CONFIG[key] = value
    end

    CommitGlowOptionChanges()
end

local function CreateModernButton(parent, text, width, onClick)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(width or 140, 30)
    ApplyBackdrop(button, { 0.125, 0.075, 0.055, 0.96 }, UI_STYLE.border)

    button.Fill = button:CreateTexture(nil, "ARTWORK")
    button.Fill:SetAllPoints()
    button.Fill:SetColorTexture(0.175, 0.090, 0.065, 0.85)

    button.HighlightFill = button:CreateTexture(nil, "HIGHLIGHT")
    button.HighlightFill:SetAllPoints()
    button.HighlightFill:SetColorTexture(UI_STYLE.accent[1], UI_STYLE.accent[2], UI_STYLE.accent[3], 0.12)

    button.Text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    button.Text:SetPoint("CENTER")
    button.Text:SetText(text or "")
    SetTextColor(button.Text, UI_STYLE.text)

    function button:SetButtonText(value)
        self.Text:SetText(value or "")
    end

    function button:SetEnabledState(enabled)
        self:SetAlpha(enabled and 1 or 0.45)
        self:EnableMouse(enabled)
        self.isEnabled = enabled and true or false
    end

    button:SetEnabledState(true)

    button:SetScript("OnEnter", function(self)
        if not self.isEnabled then
            return
        end
        self.Fill:SetColorTexture(0.220, 0.110, 0.080, 0.92)
        self:SetBackdropBorderColor(UI_STYLE.accent[1], UI_STYLE.accent[2], UI_STYLE.accent[3], 1)
    end)

    button:SetScript("OnLeave", function(self)
        self.Fill:SetColorTexture(0.175, 0.090, 0.065, 0.85)
        self:SetBackdropBorderColor(unpack(UI_STYLE.border))
    end)

    button:SetScript("OnMouseDown", function(self)
        if not self.isEnabled then
            return
        end
        self.Fill:SetColorTexture(0.120, 0.065, 0.050, 0.95)
    end)

    button:SetScript("OnMouseUp", function(self)
        if not self.isEnabled then
            return
        end
        self.Fill:SetColorTexture(0.220, 0.110, 0.080, 0.92)
    end)

    button:SetScript("OnClick", onClick)
    return button
end

local function CreateSidebarButton(parent, label, subtitle, onClick)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(160, 50)
    ApplyBackdrop(button, { 0.075, 0.080, 0.100, 0.92 }, UI_STYLE.borderSoft)

    button.Active = button:CreateTexture(nil, "BACKGROUND")
    button.Active:SetAllPoints()
    button.Active:SetColorTexture(UI_STYLE.accent[1], UI_STYLE.accent[2], UI_STYLE.accent[3], 0.10)

    button.Indicator = button:CreateTexture(nil, "ARTWORK")
    button.Indicator:SetPoint("TOPLEFT")
    button.Indicator:SetPoint("BOTTOMLEFT")
    button.Indicator:SetWidth(3)
    button.Indicator:SetColorTexture(UI_STYLE.accent[1], UI_STYLE.accent[2], UI_STYLE.accent[3], 1)

    local textWidth = button:GetWidth() - 24

    button.Label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    button.Label:SetPoint("TOPLEFT", 12, -7)
    SetFontSize(button.Label, 13)
    ConfigureTextBlock(button.Label, textWidth, UI_STYLE.subtle, "LEFT")
    button.Label:SetText(label or "")

    button.Subtitle = button:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    button.Subtitle:SetPoint("TOPLEFT", button.Label, "BOTTOMLEFT", 0, -2)
    SetFontSize(button.Subtitle, 11)
    ConfigureTextBlock(button.Subtitle, textWidth, UI_STYLE.faint, "LEFT")
    button.Subtitle:SetText(subtitle or "")

    local buttonHeight = 14 + button.Label:GetStringHeight() + 2 + button.Subtitle:GetStringHeight() + 10
    button:SetHeight(math.max(50, math.ceil(buttonHeight)))

    function button:SetActive(active)
        self.isActive = active and true or false
        self.Active:SetShown(self.isActive)
        self.Indicator:SetShown(self.isActive)
        if self.isActive then
            SetTextColor(self.Label, UI_STYLE.text)
            SetTextColor(self.Subtitle, UI_STYLE.subtle)
            self:SetBackdropBorderColor(UI_STYLE.accent[1], UI_STYLE.accent[2], UI_STYLE.accent[3], 1)
        else
            SetTextColor(self.Label, UI_STYLE.subtle)
            SetTextColor(self.Subtitle, UI_STYLE.faint)
            self:SetBackdropBorderColor(unpack(UI_STYLE.borderSoft))
        end
    end

    button:SetScript("OnEnter", function(self)
        if self.isActive then
            return
        end
        self:SetBackdropBorderColor(UI_STYLE.accentMuted[1], UI_STYLE.accentMuted[2], UI_STYLE.accentMuted[3], 1)
    end)

    button:SetScript("OnLeave", function(self)
        if self.isActive then
            self:SetBackdropBorderColor(UI_STYLE.accent[1], UI_STYLE.accent[2], UI_STYLE.accent[3], 1)
        else
            self:SetBackdropBorderColor(unpack(UI_STYLE.borderSoft))
        end
    end)

    button:SetScript("OnClick", onClick)
    button:SetActive(false)
    return button
end

local function CreateInfoTile(parent, title, width)
    local tile = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    tile:SetSize(width or 194, 74)
    ApplyBackdrop(tile, UI_STYLE.panelSoft, UI_STYLE.borderSoft)

    tile.Label = tile:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    tile.Label:SetPoint("TOPLEFT", 12, -10)
    SetFontSize(tile.Label, 11)
    ConfigureTextBlock(tile.Label, (width or 194) - 24, UI_STYLE.faint, "LEFT")
    tile.Label:SetText(title or "")

    tile.Value = tile:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    tile.Value:SetPoint("BOTTOMLEFT", 12, 12)
    SetFontSize(tile.Value, 13)
    ConfigureTextBlock(tile.Value, (width or 194) - 24, UI_STYLE.text, "LEFT")
    tile.Value:SetText("")

    tile.Accent = tile:CreateTexture(nil, "ARTWORK")
    tile.Accent:SetPoint("TOPLEFT")
    tile.Accent:SetPoint("TOPRIGHT")
    tile.Accent:SetHeight(2)
    tile.Accent:SetColorTexture(UI_STYLE.accent[1], UI_STYLE.accent[2], UI_STYLE.accent[3], 0.8)

    function tile:SetValueText(value, color)
        self.Value:SetText(value or "")
        SetTextColor(self.Value, color or UI_STYLE.text)
    end

    return tile
end

local function CreateToggle(parent, label, description, onChanged)
    local row = CreateFrame("Button", nil, parent)
    local rowWidth = 260
    local textWidth = rowWidth - 64
    row:SetSize(rowWidth, 58)

    row.Label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.Label:SetPoint("TOPLEFT", 0, -4)
    SetFontSize(row.Label, 13)
    ConfigureTextBlock(row.Label, textWidth, UI_STYLE.text, "LEFT")
    row.Label:SetText(label or "")

    row.Description = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.Description:SetPoint("TOPLEFT", row.Label, "BOTTOMLEFT", 0, -4)
    SetFontSize(row.Description, 11)
    ConfigureTextBlock(row.Description, textWidth, UI_STYLE.faint, "LEFT")
    row.Description:SetText(description or "")

    row.Switch = CreateFrame("Button", nil, row, "BackdropTemplate")
    row.Switch:SetSize(46, 24)
    row.Switch:SetPoint("RIGHT", 0, 0)
    ApplyBackdrop(row.Switch, { 0.120, 0.130, 0.170, 1.00 }, UI_STYLE.borderSoft)

    row.Track = row.Switch:CreateTexture(nil, "ARTWORK")
    row.Track:SetAllPoints()

    row.Knob = row.Switch:CreateTexture(nil, "ARTWORK")
    row.Knob:SetSize(18, 18)
    row.Knob:SetColorTexture(0.98, 0.98, 0.98, 1)

    function row:SetValue(value, silent)
        self.value = value and true or false
        if self.value then
            self.Track:SetColorTexture(UI_STYLE.accent[1], UI_STYLE.accent[2], UI_STYLE.accent[3], 0.92)
            self.Knob:ClearAllPoints()
            self.Knob:SetPoint("RIGHT", self.Switch, "RIGHT", -3, 0)
        else
            self.Track:SetColorTexture(0.200, 0.220, 0.270, 0.95)
            self.Knob:ClearAllPoints()
            self.Knob:SetPoint("LEFT", self.Switch, "LEFT", 3, 0)
        end

        if not silent and onChanged then
            onChanged(self.value)
        end
    end

    row:SetScript("OnClick", function()
        row:SetValue(not row.value)
    end)
    row.Switch:SetScript("OnClick", function()
        row:SetValue(not row.value)
    end)
    local rowHeight = 10 + row.Label:GetStringHeight() + 4 + row.Description:GetStringHeight() + 10
    row:SetHeight(math.max(58, math.ceil(rowHeight)))
    row:SetValue(false, true)
    return row
end

local function FormatSliderValue(step, value)
    if step and step < 1 then
        return ("%.2f"):format(value)
    end
    return tostring(math.floor(value + 0.5))
end

local function CreateSlider(parent, label, minValue, maxValue, step, onChanged, width)
    sliderSerial = sliderSerial + 1

    local holderWidth = width or 270
    local holder = CreateFrame("Frame", "CDMKeyPressSlider" .. sliderSerial, parent)
    holder:SetSize(holderWidth, 54)

    holder.Label = holder:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    holder.Label:SetPoint("TOPLEFT", 0, 0)
    SetFontSize(holder.Label, 13)
    ConfigureTextBlock(holder.Label, holderWidth - 70, UI_STYLE.text, "LEFT")
    holder.Label:SetText(label or "")

    holder.Value = holder:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    holder.Value:SetPoint("TOPRIGHT", 0, 0)
    SetFontSize(holder.Value, 11)
    ConfigureTextBlock(holder.Value, 52, UI_STYLE.accent, "RIGHT")

    holder.Slider = CreateFrame("Slider", "CDMKeyPressSliderWidget" .. sliderSerial, holder, "OptionsSliderTemplate")
    holder.Slider:SetPoint("TOPLEFT", holder.Label, "BOTTOMLEFT", -14, -8)
    holder.Slider:SetPoint("TOPRIGHT", holder.Value, "BOTTOMRIGHT", 14, -8)
    holder.Slider:SetMinMaxValues(minValue, maxValue)
    holder.Slider:SetValueStep(step)
    holder.Slider:SetObeyStepOnDrag(true)

    local low = _G[holder.Slider:GetName() .. "Low"]
    local high = _G[holder.Slider:GetName() .. "High"]
    local text = _G[holder.Slider:GetName() .. "Text"]
    if low then
        low:SetText("")
    end
    if high then
        high:SetText("")
    end
    if text then
        text:SetText("")
    end

    local function Quantize(value)
        if not step or step <= 0 then
            return Clamp(value, minValue, maxValue)
        end
        local snapped = minValue + (math.floor(((value - minValue) / step) + 0.5) * step)
        if step < 1 then
            snapped = tonumber(("%.2f"):format(snapped)) or snapped
        else
            snapped = math.floor(snapped + 0.5)
        end
        return Clamp(snapped, minValue, maxValue)
    end

    function holder:SetValue(value, silent)
        local normalized = Quantize(tonumber(value) or minValue)
        self._silent = silent
        self.Slider:SetValue(normalized)
        self.Value:SetText(FormatSliderValue(step, normalized))
        self._silent = nil
    end

    holder.Slider:SetScript("OnValueChanged", function(_, value)
        local normalized = Quantize(value)
        holder.Value:SetText(FormatSliderValue(step, normalized))
        if holder._silent then
            return
        end
        if onChanged then
            onChanged(normalized)
        end
    end)

    holder:SetValue(minValue, true)
    return holder
end

local function CreateGlowTypeListButton(parent, width, title, subtitle, onClick)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(width or 268, 56)
    ApplyBackdrop(button, UI_STYLE.panelSoft, UI_STYLE.borderSoft)

    button.Fill = button:CreateTexture(nil, "ARTWORK")
    button.Fill:SetAllPoints()
    button.Fill:SetColorTexture(0.115, 0.120, 0.155, 0.36)

    button.Indicator = button:CreateTexture(nil, "OVERLAY")
    button.Indicator:SetPoint("TOPLEFT")
    button.Indicator:SetPoint("BOTTOMLEFT")
    button.Indicator:SetWidth(3)
    button.Indicator:SetColorTexture(UI_STYLE.accent[1], UI_STYLE.accent[2], UI_STYLE.accent[3], 1)

    button.Title = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    button.Title:SetPoint("TOPLEFT", 14, -9)
    SetFontSize(button.Title, 13)
    ConfigureTextBlock(button.Title, (width or 268) - 28, UI_STYLE.text, "LEFT")
    button.Title:SetText(title or "")

    button.Subtitle = button:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    button.Subtitle:SetPoint("TOPLEFT", button.Title, "BOTTOMLEFT", 0, -3)
    SetFontSize(button.Subtitle, 11)
    ConfigureTextBlock(button.Subtitle, (width or 268) - 28, UI_STYLE.faint, "LEFT")
    button.Subtitle:SetText(subtitle or "")

    local buttonHeight = 14 + button.Title:GetStringHeight() + 3 + button.Subtitle:GetStringHeight() + 11
    button:SetHeight(math.max(56, math.ceil(buttonHeight)))

    function button:SetSelected(selected, accentColor)
        local accent = accentColor or UI_STYLE.accent
        self.Indicator:SetShown(selected and true or false)
        if selected then
            self.Fill:SetColorTexture(accent[1], accent[2], accent[3], 0.12)
            self:SetBackdropBorderColor(accent[1], accent[2], accent[3], 1)
        else
            self.Fill:SetColorTexture(0.115, 0.120, 0.155, 0.36)
            self:SetBackdropBorderColor(unpack(UI_STYLE.borderSoft))
        end
    end

    button:SetScript("OnEnter", function(self)
        if self.Indicator:IsShown() then
            return
        end
        self:SetBackdropBorderColor(UI_STYLE.accentMuted[1], UI_STYLE.accentMuted[2], UI_STYLE.accentMuted[3], 1)
    end)

    button:SetScript("OnLeave", function(self)
        if self.Indicator:IsShown() then
            self:SetBackdropBorderColor(UI_STYLE.accent[1], UI_STYLE.accent[2], UI_STYLE.accent[3], 1)
        else
            self:SetBackdropBorderColor(unpack(UI_STYLE.borderSoft))
        end
    end)

    button:SetScript("OnClick", onClick)
    button:SetSelected(false)
    return button
end

local function OpenColorWheel(initialColor, callback)
    local color = CopyRGB(initialColor)
    local previous = { r = color[1], g = color[2], b = color[3] }

    local function ApplyCurrentColor()
        local r, g, b = ColorPickerFrame:GetColorRGB()
        callback(r, g, b)
    end

    if ColorPickerFrame and ColorPickerFrame.SetupColorPickerAndShow then
        ColorPickerFrame:SetupColorPickerAndShow({
            r = color[1],
            g = color[2],
            b = color[3],
            hasOpacity = false,
            swatchFunc = ApplyCurrentColor,
            cancelFunc = function(previousValues)
                callback(previousValues.r, previousValues.g, previousValues.b)
            end,
            previousValues = previous,
        })
        return
    end

    ColorPickerFrame.hasOpacity = false
    ColorPickerFrame.opacity = nil
    ColorPickerFrame.previousValues = previous
    ColorPickerFrame.func = ApplyCurrentColor
    ColorPickerFrame.cancelFunc = function(previousValues)
        callback(previousValues.r, previousValues.g, previousValues.b)
    end
    ColorPickerFrame:SetColorRGB(color[1], color[2], color[3])
    ColorPickerFrame:Hide()
    ColorPickerFrame:Show()
end

local function CreateColorSwatchRow(parent, onOpen)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(270, 42)

    row.Label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.Label:SetPoint("TOPLEFT", 0, -2)
    row.Label:SetText("Glow Color")
    SetTextColor(row.Label, UI_STYLE.text)

    row.Swatch = CreateFrame("Button", nil, row, "BackdropTemplate")
    row.Swatch:SetSize(32, 32)
    row.Swatch:SetPoint("TOPLEFT", 0, -18)
    ApplyBackdrop(row.Swatch, { 0.080, 0.085, 0.110, 1.00 }, UI_STYLE.borderSoft)

    row.Swatch.Fill = row.Swatch:CreateTexture(nil, "ARTWORK")
    row.Swatch.Fill:SetPoint("TOPLEFT", 2, -2)
    row.Swatch.Fill:SetPoint("BOTTOMRIGHT", -2, 2)

    row.Button = CreateModernButton(row, "Open RGB Wheel", 132, function()
        if onOpen then
            onOpen()
        end
    end)
    row.Button:SetPoint("LEFT", row.Swatch, "RIGHT", 12, 0)

    row.Swatch:SetScript("OnClick", function()
        if onOpen then
            onOpen()
        end
    end)

    function row:UpdateColor(color)
        local rgb = CopyRGB(color)
        self.Swatch.Fill:SetColorTexture(rgb[1], rgb[2], rgb[3], 1)
    end

    return row
end

local function CreateColorChip(parent, preset, onClick)
    local chip = CreateFrame("Button", nil, parent, "BackdropTemplate")
    chip:SetSize(26, 26)
    ApplyBackdrop(chip, { 0.070, 0.075, 0.095, 1.00 }, UI_STYLE.borderSoft)

    chip.Fill = chip:CreateTexture(nil, "ARTWORK")
    chip.Fill:SetPoint("TOPLEFT", 2, -2)
    chip.Fill:SetPoint("BOTTOMRIGHT", -2, 2)
    chip.Fill:SetColorTexture(preset.color[1], preset.color[2], preset.color[3], 1)

    chip.Selection = chip:CreateTexture(nil, "OVERLAY")
    chip.Selection:SetPoint("TOPLEFT")
    chip.Selection:SetPoint("BOTTOMLEFT")
    chip.Selection:SetPoint("TOPRIGHT")
    chip.Selection:SetHeight(2)
    chip.Selection:SetColorTexture(UI_STYLE.accent[1], UI_STYLE.accent[2], UI_STYLE.accent[3], 1)

    chip:SetScript("OnClick", function()
        onClick(preset)
    end)

    chip:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(preset.label or preset.key or "Color", 1, 1, 1)
        GameTooltip:Show()
    end)

    chip:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    function chip:SetSelected(selected)
        self.Selection:SetShown(selected and true or false)
        if selected then
            self:SetBackdropBorderColor(UI_STYLE.accent[1], UI_STYLE.accent[2], UI_STYLE.accent[3], 1)
        else
            self:SetBackdropBorderColor(unpack(UI_STYLE.borderSoft))
        end
    end

    chip:SetSelected(false)
    return chip
end

local function CreateMenuScrollFrame(parent, name)
    local scrollFrame = CreateFrame("ScrollFrame", name, parent, "UIPanelScrollFrameTemplate")
    scrollFrame:SetClipsChildren(true)
    scrollFrame:EnableMouseWheel(true)

    local scrollBar = _G[name .. "ScrollBar"]
    scrollFrame.ScrollBar = scrollBar

    if scrollBar then
        scrollBar:ClearAllPoints()
        scrollBar:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -4, -18)
        scrollBar:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -4, 18)
    end

    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local bar = self.ScrollBar
        if not bar then
            return
        end

        local minValue, maxValue = bar:GetMinMaxValues()
        local nextValue = (bar:GetValue() or 0) - (delta * 36)
        bar:SetValue(Clamp(nextValue, minValue or 0, maxValue or 0))
    end)

    return scrollFrame
end

local function UpdatePreviewFrame(frame)
    if not frame then
        return
    end

    Private.EnsurePressAnimation(frame)
    if Private.UpdatePressAnimationAnchor then
        Private.UpdatePressAnimationAnchor(frame)
    end

    if frame.__cdmkpPreviewIcon then
        SetClassIcon(frame.__cdmkpPreviewIcon)
    end

    if frame.__cdmkpPressOverlay then
        frame.__cdmkpPressOverlay:SetTexture(CONFIG.PressTexturePath)
        frame.__cdmkpPressOverlay:SetBlendMode(CONFIG.PressBlendMode or "ADD")
        frame.__cdmkpPressOverlay:SetVertexColor(unpack(CONFIG.PressVertexColor))
        frame.__cdmkpPressOverlay:SetAlpha(0)
    end

    if frame.__cdmkpPressedOverlay then
        frame.__cdmkpPressedOverlay:SetTexture(CONFIG.PressedTexturePath)
        frame.__cdmkpPressedOverlay:SetBlendMode(CONFIG.PressedBlendMode or "ADD")
        frame.__cdmkpPressedOverlay:SetVertexColor(unpack(CONFIG.PressedVertexColor))
        frame.__cdmkpPressedOverlay:SetAlpha(0)
    end

    frame.__cdmkpGlowActive = nil
    Private.ApplyGlowState(frame)
end

local function PulsePreviewFrame(frame)
    if not frame then
        return
    end

    UpdatePreviewFrame(frame)

    if Private.UpdatePressAnimationAnchor then
        Private.UpdatePressAnimationAnchor(frame)
    end
    if frame.__cdmkpPressAnim and frame.__cdmkpPressOverlay then
        frame.__cdmkpPressAnim:Stop()
        frame.__cdmkpPressOverlay:SetAlpha(0)
        frame.__cdmkpPressAnim:Play()
    end
    if frame.__cdmkpPressedOverlay then
        frame.__cdmkpPressedOverlay:SetAlpha(CONFIG.PressedAlpha or 0.32)
    end
    frame.__cdmkpGlowActive = CONFIG.GlowEnabled and true or nil
    Private.ApplyGlowState(frame)

    C_Timer.After(CONFIG.PressedMaxHoldSeconds or 0.18, function()
        if frame and frame:IsShown() then
            UpdatePreviewFrame(frame)
        end
    end)
end

local function SelectQuickMenuPage(pageKey)
    local frame = state.quickMenu
    if not frame or not frame.pages then
        return
    end

    if not frame.pages[pageKey] then
        pageKey = "overview"
    end

    frame.currentPage = pageKey
    for key, page in pairs(frame.pages) do
        page:SetShown(key == pageKey)
    end

    for key, button in pairs(frame.controls.navButtons) do
        button:SetActive(key == pageKey)
    end

    local previewDock = frame.controls and frame.controls.glow and frame.controls.glow.previewDock
    if previewDock then
        previewDock:SetShown(pageKey == "glow")
    end
end

local function BuildOverviewPage(frame, parent)
    local page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints()
    page:Hide()

    local controls = frame.controls.overview

    controls.hero = CreateFrame("Frame", nil, page, "BackdropTemplate")
    controls.hero:SetSize(620, 224)
    controls.hero:SetPoint("TOPLEFT", 0, 0)
    ApplyBackdrop(controls.hero, UI_STYLE.panel, UI_STYLE.border)

    controls.heroAccent = controls.hero:CreateTexture(nil, "ARTWORK")
    controls.heroAccent:SetPoint("BOTTOMLEFT")
    controls.heroAccent:SetPoint("BOTTOMRIGHT")
    controls.heroAccent:SetHeight(3)
    controls.heroAccent:SetColorTexture(UI_STYLE.accent[1], UI_STYLE.accent[2], UI_STYLE.accent[3], 1)

    controls.logo = controls.hero:CreateTexture(nil, "ARTWORK")
    controls.logo:SetSize(52, 52)
    controls.logo:SetPoint("TOPLEFT", 18, -18)
    controls.logo:SetTexture(ICON_TEXTURE_PATH)

    controls.title = controls.hero:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    controls.title:SetPoint("TOPLEFT", controls.logo, "TOPRIGHT", 14, -2)
    ConfigureTextBlock(controls.title, 250, UI_STYLE.text, "LEFT")
    controls.title:SetJustifyH("LEFT")
    controls.title:SetText("CDM KeyPress")

    controls.subtitle = controls.hero:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    controls.subtitle:SetPoint("TOPLEFT", controls.title, "BOTTOMLEFT", 0, -6)
    SetFontSize(controls.subtitle, 11)
    ConfigureTextBlock(controls.subtitle, 250, UI_STYLE.subtle, "LEFT")
    controls.subtitle:SetText("Focused key press feedback with quick visual tuning for Retail.")

    controls.statusBlock = CreateFrame("Frame", nil, controls.hero)
    controls.statusBlock:SetSize(160, 42)
    controls.statusBlock:SetPoint("TOPLEFT", 18, -108)

    controls.profileLabel = controls.statusBlock:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    controls.profileLabel:SetPoint("TOPLEFT", 0, 0)
    SetFontSize(controls.profileLabel, 11)
    controls.profileLabel:SetText("Active Profile")
    SetTextColor(controls.profileLabel, UI_STYLE.faint)

    controls.profileValue = controls.statusBlock:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    controls.profileValue:SetPoint("TOPLEFT", controls.profileLabel, "BOTTOMLEFT", 0, -2)
    SetFontSize(controls.profileValue, 13)
    ConfigureTextBlock(controls.profileValue, 150, UI_STYLE.text, "LEFT")
    controls.profileValue:SetText("")

    controls.actionsBlock = CreateFrame("Frame", nil, controls.hero)
    controls.actionsBlock:SetSize(124, 118)
    controls.actionsBlock:SetPoint("TOPRIGHT", -18, -18)

    controls.modeButton = CreateModernButton(controls.actionsBlock, "Mode", 120, function()
        if Private.LOCK_MODE_TO_SENT then
            return
        end

        local mode = GetTriggerModeLabel()
        if mode == "both" then
            CONFIG.TriggerOnSpellSent = true
            CONFIG.TriggerOnSpellSucceeded = false
        elseif mode == "sent" then
            CONFIG.TriggerOnSpellSent = false
            CONFIG.TriggerOnSpellSucceeded = true
        else
            CONFIG.TriggerOnSpellSent = true
            CONFIG.TriggerOnSpellSucceeded = true
        end

        if Private.PersistActiveProfile then
            Private.PersistActiveProfile()
        end
        CommitGlowOptionChanges()
    end)
    controls.modeButton:SetPoint("TOPLEFT", 0, 0)

    controls.scanButton = CreateModernButton(controls.actionsBlock, "Scan Now", 120, function()
        Private.RunScanNow("menu")
        if Private.RefreshModernMenu then
            Private.RefreshModernMenu()
        end
    end)
    controls.scanButton:SetPoint("TOPLEFT", controls.modeButton, "BOTTOMLEFT", 0, -10)

    controls.statusButton = CreateModernButton(controls.actionsBlock, "Send Status", 120, function()
        local loaded, detectionMode = Private.GetDetectionState()
        Private.PrintInfo("profile=%s cdmLoaded=%s detect=%s tracked=%d preset=%s mode=%s glow=%s backend=%s alpha=%.2f bright=%.2f color=%s",
            state.activeProfileName or "Default",
            loaded and "true" or "false",
            detectionMode,
            Private.CountTrackedFrames(),
            state.currentPresetName,
            GetTriggerModeLabel(),
            CONFIG.GlowEnabled and "on" or "off",
            Private.GetGlowBackendLabel(),
            CONFIG.GlowAlpha or 0,
            CONFIG.GlowBrightness or 1,
            Private.GetGlowColorLabel()
        )
        Private.PrintInfo("glow type = %s", Private.GetGlowTypeLabel())
        Private.PrintInfo("%s", Private.GetScanSummaryText())
        Private.PrintInfo("%s", Private.GetScanTotalsText())
    end)
    controls.statusButton:SetPoint("TOPLEFT", controls.scanButton, "BOTTOMLEFT", 0, -10)

    controls.debugToggle = CreateToggle(controls.hero, "Debug Output", "Toggle verbose logging for troubleshooting.", function(enabled)
        state.debug = enabled and true or false
    end)
    controls.debugToggle:SetPoint("TOPLEFT", 18, -162)

    return page
end

local function BuildGlowPage(frame, parent)
    local page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints()
    page:Hide()

    local controls = frame.controls.glow
    controls.typeCards = {}
    controls.colorChips = {}
    controls.groups = {}
    controls.flash = {}

    controls.scrollFrame = CreateMenuScrollFrame(page, "CDMKeyPressGlowScrollFrame")
    controls.scrollFrame:SetPoint("TOPLEFT", page, "TOPLEFT", 0, 0)
    controls.scrollFrame:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", 0, 0)

    controls.scrollChild = CreateFrame("Frame", nil, controls.scrollFrame)
    controls.scrollChild:SetSize(596, 1380)
    controls.scrollFrame:SetScrollChild(controls.scrollChild)

    controls.colorPanel = CreateFrame("Frame", nil, controls.scrollChild, "BackdropTemplate")
    controls.colorPanel:SetSize(288, 560)
    controls.colorPanel:SetPoint("TOPLEFT", 0, 0)
    ApplyBackdrop(controls.colorPanel, UI_STYLE.panel, UI_STYLE.borderSoft)

    controls.colorHeader = controls.colorPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    controls.colorHeader:SetPoint("TOPLEFT", 16, -16)
    controls.colorHeader:SetText("Glow Color")
    SetTextColor(controls.colorHeader, UI_STYLE.text)

    controls.colorSubheader = controls.colorPanel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    controls.colorSubheader:SetPoint("TOPLEFT", controls.colorHeader, "BOTTOMLEFT", 0, -6)
    SetFontSize(controls.colorSubheader, 11)
    ConfigureTextBlock(controls.colorSubheader, 252, UI_STYLE.faint, "LEFT")
    controls.colorSubheader:SetText("Use a custom RGB color or automatically follow your class color.")

    controls.glowEnabledToggle = CreateToggle(controls.colorPanel, "Glow Enabled", "Master switch for glow rendering around the icon.", function(enabled)
        SetGlowBooleanConfig("GlowEnabled", enabled)
    end)
    controls.glowEnabledToggle:SetPoint("TOPLEFT", 16, -84)

    controls.classColorToggle = CreateToggle(controls.colorPanel, "Class Color", "Override the custom RGB color with your class color.", function(enabled)
        SetGlowUseClassColorConfig(enabled)
    end)
    controls.classColorToggle:SetPoint("TOPLEFT", controls.glowEnabledToggle, "BOTTOMLEFT", 0, -12)

    controls.swatchRow = CreateColorSwatchRow(controls.colorPanel, function()
        OpenColorWheel(CONFIG.GlowColor, function(r, g, b)
            if CONFIG.GlowUseClassColor then
                CONFIG.GlowUseClassColor = false
            end
            SetGlowColorConfig({ r, g, b })
        end)
    end)
    controls.swatchRow:SetPoint("TOPLEFT", controls.classColorToggle, "BOTTOMLEFT", 0, -16)

    controls.paletteLabel = controls.colorPanel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    controls.paletteLabel:SetPoint("TOPLEFT", controls.swatchRow, "BOTTOMLEFT", 0, -14)
    SetFontSize(controls.paletteLabel, 11)
    controls.paletteLabel:SetText("Quick Palette")
    SetTextColor(controls.paletteLabel, UI_STYLE.faint)

    local paletteRows = math.max(1, math.ceil(#GLOW_COLOR_PRESETS / 4))
    for index, preset in ipairs(GLOW_COLOR_PRESETS) do
        local chip = CreateColorChip(controls.colorPanel, preset, function(entry)
            if CONFIG.GlowUseClassColor then
                CONFIG.GlowUseClassColor = false
            end
            SetGlowColorConfig(entry.color)
        end)

        local rowIndex = math.floor((index - 1) / 4)
        local columnIndex = (index - 1) % 4
        chip:SetPoint("TOPLEFT", controls.paletteLabel, "BOTTOMLEFT", columnIndex * 32, -(rowIndex * 32) - 8)
        controls.colorChips[index] = chip
    end

    controls.brightnessSlider = CreateSlider(controls.colorPanel, "Glow Intensity", 0.10, 3.00, 0.05, function(value)
        SetSliderConfigValue("GlowBrightness", value, 0.10, 3.00, false)
    end, 256)
    controls.brightnessSlider:SetPoint("TOPLEFT", controls.paletteLabel, "BOTTOMLEFT", 0, -(paletteRows * 32) - 14)

    controls.alphaSlider = CreateSlider(controls.colorPanel, "Glow Opacity", 0.00, 1.00, 0.01, function(value)
        SetSliderConfigValue("GlowAlpha", value, 0.00, 1.00, false)
    end, 256)
    controls.alphaSlider:SetPoint("TOPLEFT", controls.brightnessSlider, "BOTTOMLEFT", 0, -12)

    controls.previewDock = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    controls.previewDock:SetSize(228, 232)
    controls.previewDock:SetPoint("TOPLEFT", frame, "TOPRIGHT", 18, -94)
    ApplyBackdrop(controls.previewDock, UI_STYLE.panel, UI_STYLE.border)
    controls.previewDock:Hide()

    controls.previewHeader = controls.previewDock:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    controls.previewHeader:SetPoint("TOPLEFT", 16, -16)
    controls.previewHeader:SetText("Live Preview")
    SetTextColor(controls.previewHeader, UI_STYLE.text)

    controls.previewFrame = CreateFrame("Frame", nil, controls.previewDock, "BackdropTemplate")
    controls.previewFrame:SetSize(90, 90)
    controls.previewFrame:SetPoint("TOP", 0, -52)
    ApplyBackdrop(controls.previewFrame, { 0.040, 0.045, 0.060, 1.00 }, UI_STYLE.border)

    controls.previewIcon = controls.previewFrame:CreateTexture(nil, "ARTWORK")
    controls.previewIcon:SetPoint("TOPLEFT", 4, -4)
    controls.previewIcon:SetPoint("BOTTOMRIGHT", -4, 4)
    controls.previewFrame.__cdmkpPreviewIcon = controls.previewIcon
    SetClassIcon(controls.previewIcon)

    controls.previewButton = CreateModernButton(controls.previewDock, "Pulse Preview", 132, function()
        PulsePreviewFrame(controls.previewFrame)
    end)
    controls.previewButton:SetPoint("TOP", controls.previewFrame, "BOTTOM", 0, -18)

    controls.stylePanel = CreateFrame("Frame", nil, controls.scrollChild, "BackdropTemplate")
    controls.stylePanel:SetSize(288, 344)
    controls.stylePanel:SetPoint("TOPRIGHT", 0, 0)
    ApplyBackdrop(controls.stylePanel, UI_STYLE.panel, UI_STYLE.borderSoft)

    controls.typeHeader = controls.stylePanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    controls.typeHeader:SetPoint("TOPLEFT", 16, -16)
    SetFontSize(controls.typeHeader, 12)
    controls.typeHeader:SetText("Glow Style")
    SetTextColor(controls.typeHeader, UI_STYLE.text)

    controls.typeSubheader = controls.stylePanel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    controls.typeSubheader:SetPoint("TOPLEFT", controls.typeHeader, "BOTTOMLEFT", 0, -6)
    SetFontSize(controls.typeSubheader, 11)
    ConfigureTextBlock(controls.typeSubheader, 252, UI_STYLE.faint, "LEFT")
    controls.typeSubheader:SetText("Choose the glow style used by the live preview.")

    local glowTypes = { "button", "pixel", "autocast", "proc" }
    local previousButton
    for index, glowType in ipairs(glowTypes) do
        local preview = GLOW_TYPE_PREVIEW_DATA[glowType] or {}
        local title = glowType:gsub("^%l", string.upper)
        local card = CreateGlowTypeListButton(controls.stylePanel, 256, title, preview.subtitle or "", function()
            SetGlowTypeConfig(glowType)
        end)
        if previousButton then
            card:SetPoint("TOPLEFT", previousButton, "BOTTOMLEFT", 0, -10)
        else
            card:SetPoint("TOPLEFT", 16, -74)
        end
        controls.typeCards[glowType] = card
        previousButton = card
    end

    controls.flashGroup = BuildAdvancedGroup(controls.scrollChild, 596, 300, "Flash Settings", "Tune the key press flash strength and hold timings.")
    controls.flashGroup:SetPoint("TOPLEFT", controls.colorPanel, "BOTTOMLEFT", 0, -20)

    controls.flash.pressPeakAlpha = CreateSlider(controls.flashGroup, "Flash Peak", 0.10, 1.00, 0.05, function(value)
        SetSliderConfigValue("PressPeakAlpha", value, 0.10, 1.00, false)
    end)
    controls.flash.pressPeakAlpha:SetPoint("TOPLEFT", 18, -62)

    controls.flash.pressedAlpha = CreateSlider(controls.flashGroup, "Hold Alpha", 0.00, 1.00, 0.01, function(value)
        SetSliderConfigValue("PressedAlpha", value, 0.00, 1.00, false)
    end)
    controls.flash.pressedAlpha:SetPoint("TOPLEFT", 320, -62)

    controls.flash.fadeIn = CreateSlider(controls.flashGroup, "Fade In", 0.00, 0.30, 0.01, function(value)
        SetFlashTimingConfig("FadeInDuration", value, 0.00, 0.30)
    end)
    controls.flash.fadeIn:SetPoint("TOPLEFT", 18, -138)

    controls.flash.fadeOut = CreateSlider(controls.flashGroup, "Fade Out", 0.00, 0.40, 0.01, function(value)
        SetFlashTimingConfig("FadeOutDuration", value, 0.00, 0.40)
    end)
    controls.flash.fadeOut:SetPoint("TOPLEFT", 320, -138)

    controls.flash.minHold = CreateSlider(controls.flashGroup, "Min Hold", 0.00, 0.30, 0.01, function(value)
        SetFlashTimingConfig("PressedMinHoldSeconds", value, 0.00, 0.30)
    end)
    controls.flash.minHold:SetPoint("TOPLEFT", 18, -214)

    controls.flash.maxHold = CreateSlider(controls.flashGroup, "Max Hold", 0.05, 0.40, 0.01, function(value)
        SetFlashTimingConfig("PressedMaxHoldSeconds", value, 0.05, 0.40)
    end)
    controls.flash.maxHold:SetPoint("TOPLEFT", 320, -214)

    controls.typeSettingsHeader = controls.scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    controls.typeSettingsHeader:SetPoint("TOPLEFT", controls.flashGroup, "BOTTOMLEFT", 0, -20)
    controls.typeSettingsHeader:SetText("Glow Details")
    SetTextColor(controls.typeSettingsHeader, UI_STYLE.text)

    controls.typeSettingsSubheader = controls.scrollChild:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    controls.typeSettingsSubheader:SetPoint("TOPLEFT", controls.typeSettingsHeader, "BOTTOMLEFT", 0, -6)
    SetFontSize(controls.typeSettingsSubheader, 11)
    ConfigureTextBlock(controls.typeSettingsSubheader, 596, UI_STYLE.subtle, "LEFT")
    controls.typeSettingsSubheader:SetText("Per-style sliders and toggles now live directly in this page.")

    controls.typeValueLabel = controls.scrollChild:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    controls.typeValueLabel:SetPoint("TOPLEFT", controls.typeSettingsSubheader, "BOTTOMLEFT", 0, -14)
    SetFontSize(controls.typeValueLabel, 11)
    controls.typeValueLabel:SetText("Selected Glow Type")
    SetTextColor(controls.typeValueLabel, UI_STYLE.faint)

    controls.typeValue = controls.scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    controls.typeValue:SetPoint("LEFT", controls.typeValueLabel, "RIGHT", 12, 0)
    controls.typeValue:SetText("")
    SetTextColor(controls.typeValue, UI_STYLE.accent)

    controls.groups.button = BuildAdvancedGroup(controls.scrollChild, 596, 146, "Button Settings", "Best for the Blizzard-like action-button spell alert ring.")
    controls.groups.button:SetPoint("TOPLEFT", controls.typeValueLabel, "BOTTOMLEFT", 0, -20)
    controls.groups.button.frequency = CreateSlider(controls.groups.button, "Frequency", 0.01, 10.00, 0.01, function(value)
        SetSliderConfigValue("GlowButtonFrequency", value, 0.01, 10.00, false)
    end, 270)
    controls.groups.button.frequency:SetPoint("TOPLEFT", 18, -62)

    controls.groups.pixel = BuildAdvancedGroup(controls.scrollChild, 596, 360, "Pixel Settings", "Control line count, motion speed, and edge geometry.")
    controls.groups.pixel:SetPoint("TOPLEFT", controls.typeValueLabel, "BOTTOMLEFT", 0, -20)
    controls.groups.pixel.lines = CreateSlider(controls.groups.pixel, "Lines", 1, 32, 1, function(value)
        SetSliderConfigValue("GlowPixelLines", value, 1, 32, true)
    end)
    controls.groups.pixel.lines:SetPoint("TOPLEFT", 18, -62)
    controls.groups.pixel.frequency = CreateSlider(controls.groups.pixel, "Frequency", -10.00, 10.00, 0.05, function(value)
        SetSliderConfigValue("GlowPixelFrequency", value, -10.00, 10.00, false)
    end)
    controls.groups.pixel.frequency:SetPoint("TOPLEFT", 320, -62)
    controls.groups.pixel.length = CreateSlider(controls.groups.pixel, "Length", 0.10, 20.00, 0.10, function(value)
        SetSliderConfigValue("GlowPixelLength", value, 0.10, 20.00, false)
    end)
    controls.groups.pixel.length:SetPoint("TOPLEFT", 18, -138)
    controls.groups.pixel.thickness = CreateSlider(controls.groups.pixel, "Thickness", 0.10, 20.00, 0.10, function(value)
        SetSliderConfigValue("GlowPixelThickness", value, 0.10, 20.00, false)
    end)
    controls.groups.pixel.thickness:SetPoint("TOPLEFT", 320, -138)
    controls.groups.pixel.offsetX = CreateSlider(controls.groups.pixel, "Offset X", -50, 50, 1, function(value)
        SetSliderConfigValue("GlowPixelXOffset", value, -50, 50, true)
    end)
    controls.groups.pixel.offsetX:SetPoint("TOPLEFT", 18, -214)
    controls.groups.pixel.offsetY = CreateSlider(controls.groups.pixel, "Offset Y", -50, 50, 1, function(value)
        SetSliderConfigValue("GlowPixelYOffset", value, -50, 50, true)
    end)
    controls.groups.pixel.offsetY:SetPoint("TOPLEFT", 320, -214)
    controls.groups.pixel.border = CreateToggle(controls.groups.pixel, "Inner Border", "Adds the darker inset border used by the pixel glow style.", function(enabled)
        SetGlowBooleanConfig("GlowPixelBorder", enabled)
    end)
    controls.groups.pixel.border:SetPoint("TOPLEFT", 18, -292)

    controls.groups.autocast = BuildAdvancedGroup(controls.scrollChild, 596, 294, "Autocast Settings", "Adjust spark count, travel speed, and orbit scaling.")
    controls.groups.autocast:SetPoint("TOPLEFT", controls.typeValueLabel, "BOTTOMLEFT", 0, -20)
    controls.groups.autocast.particles = CreateSlider(controls.groups.autocast, "Particles", 1, 64, 1, function(value)
        SetSliderConfigValue("GlowAutoCastParticles", value, 1, 64, true)
    end)
    controls.groups.autocast.particles:SetPoint("TOPLEFT", 18, -62)
    controls.groups.autocast.frequency = CreateSlider(controls.groups.autocast, "Frequency", -10.00, 10.00, 0.05, function(value)
        SetSliderConfigValue("GlowAutoCastFrequency", value, -10.00, 10.00, false)
    end)
    controls.groups.autocast.frequency:SetPoint("TOPLEFT", 320, -62)
    controls.groups.autocast.scale = CreateSlider(controls.groups.autocast, "Scale", 0.10, 5.00, 0.05, function(value)
        SetSliderConfigValue("GlowAutoCastScale", value, 0.10, 5.00, false)
    end)
    controls.groups.autocast.scale:SetPoint("TOPLEFT", 18, -138)
    controls.groups.autocast.offsetX = CreateSlider(controls.groups.autocast, "Offset X", -50, 50, 1, function(value)
        SetSliderConfigValue("GlowAutoCastXOffset", value, -50, 50, true)
    end)
    controls.groups.autocast.offsetX:SetPoint("TOPLEFT", 18, -214)
    controls.groups.autocast.offsetY = CreateSlider(controls.groups.autocast, "Offset Y", -50, 50, 1, function(value)
        SetSliderConfigValue("GlowAutoCastYOffset", value, -50, 50, true)
    end)
    controls.groups.autocast.offsetY:SetPoint("TOPLEFT", 320, -214)

    controls.groups.proc = BuildAdvancedGroup(controls.scrollChild, 596, 302, "Proc Settings", "Tune the burst duration and entrance behavior of the proc frame.")
    controls.groups.proc:SetPoint("TOPLEFT", controls.typeValueLabel, "BOTTOMLEFT", 0, -20)
    controls.groups.proc.duration = CreateSlider(controls.groups.proc, "Duration", 0.10, 10.00, 0.05, function(value)
        SetSliderConfigValue("GlowProcDuration", value, 0.10, 10.00, false)
    end)
    controls.groups.proc.duration:SetPoint("TOPLEFT", 18, -62)
    controls.groups.proc.offsetX = CreateSlider(controls.groups.proc, "Offset X", -50, 50, 1, function(value)
        SetSliderConfigValue("GlowProcXOffset", value, -50, 50, true)
    end)
    controls.groups.proc.offsetX:SetPoint("TOPLEFT", 18, -138)
    controls.groups.proc.offsetY = CreateSlider(controls.groups.proc, "Offset Y", -50, 50, 1, function(value)
        SetSliderConfigValue("GlowProcYOffset", value, -50, 50, true)
    end)
    controls.groups.proc.offsetY:SetPoint("TOPLEFT", 320, -138)
    controls.groups.proc.startAnim = CreateToggle(controls.groups.proc, "Start Animation", "Play the proc intro animation when the glow appears.", function(enabled)
        SetGlowBooleanConfig("GlowProcStartAnim", enabled)
    end)
    controls.groups.proc.startAnim:SetPoint("TOPLEFT", 18, -222)

    return page
end

BuildAdvancedGroup = function(parent, width, height, title, subtitle)
    local group = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    group:SetSize(width or 620, height or 348)
    ApplyBackdrop(group, UI_STYLE.panel, UI_STYLE.borderSoft)

    group.Title = group:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    group.Title:SetPoint("TOPLEFT", 16, -16)
    group.Title:SetText(title)
    SetTextColor(group.Title, UI_STYLE.text)

    group.Subtitle = group:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    group.Subtitle:SetPoint("TOPLEFT", group.Title, "BOTTOMLEFT", 0, -6)
    SetFontSize(group.Subtitle, 11)
    ConfigureTextBlock(group.Subtitle, (width or 620) - 40, UI_STYLE.faint, "LEFT")
    group.Subtitle:SetText(subtitle or "")

    return group
end

local function RefreshModernMenu()
    if not state.quickMenu then
        return
    end

    local frame = state.quickMenu
    local controls = frame.controls
    local resolvedColor = (Private.GetResolvedGlowColor and Private.GetResolvedGlowColor()) or CopyRGB(CONFIG.GlowColor)
    local glowType = Private.NormalizeGlowType and Private.NormalizeGlowType(CONFIG.GlowType) or "button"
    local colorPresetIndex = Private.FindGlowPresetIndexByColor(CONFIG.GlowColor)
    for key, button in pairs(controls.navButtons) do
        button:SetActive(key == frame.currentPage)
    end

    controls.overview.profileValue:SetText(state.activeProfileName or "Default")
    controls.overview.modeButton:SetButtonText("Mode: " .. GetTriggerModeLabel())
    controls.overview.debugToggle:SetValue(state.debug and true or false, true)

    controls.glow.glowEnabledToggle:SetValue(CONFIG.GlowEnabled and true or false, true)
    controls.glow.classColorToggle:SetValue(CONFIG.GlowUseClassColor and true or false, true)
    controls.glow.swatchRow:UpdateColor(resolvedColor)
    controls.glow.swatchRow.Button:SetEnabledState(not CONFIG.GlowUseClassColor)
    controls.glow.brightnessSlider:SetValue(CONFIG.GlowBrightness or 1.0, true)
    controls.glow.alphaSlider:SetValue(CONFIG.GlowAlpha or 0.55, true)
    UpdatePreviewFrame(controls.glow.previewFrame)
    if controls.glow.previewDock then
        controls.glow.previewDock:SetShown(frame.currentPage == "glow")
    end

    for index, chip in ipairs(controls.glow.colorChips) do
        chip:SetSelected(not CONFIG.GlowUseClassColor and colorPresetIndex == index)
    end

    for key, card in pairs(controls.glow.typeCards) do
        card:SetSelected(key == glowType, resolvedColor)
    end

    controls.glow.flash.pressPeakAlpha:SetValue(CONFIG.PressPeakAlpha or 1.0, true)
    controls.glow.flash.pressedAlpha:SetValue(CONFIG.PressedAlpha or 0.32, true)
    controls.glow.flash.fadeIn:SetValue(CONFIG.FadeInDuration or 0.05, true)
    controls.glow.flash.fadeOut:SetValue(CONFIG.FadeOutDuration or 0.13, true)
    controls.glow.flash.minHold:SetValue(CONFIG.PressedMinHoldSeconds or 0.09, true)
    controls.glow.flash.maxHold:SetValue(CONFIG.PressedMaxHoldSeconds or 0.18, true)

    controls.glow.typeValue:SetText(Private.GetGlowTypeLabel())
    for key, group in pairs(controls.glow.groups) do
        group:SetShown(key == glowType)
    end

    controls.glow.groups.button.frequency:SetValue(CONFIG.GlowButtonFrequency or 0.125, true)
    controls.glow.groups.pixel.lines:SetValue(CONFIG.GlowPixelLines or 5, true)
    controls.glow.groups.pixel.frequency:SetValue(CONFIG.GlowPixelFrequency or 0.25, true)
    controls.glow.groups.pixel.length:SetValue(CONFIG.GlowPixelLength or 2, true)
    controls.glow.groups.pixel.thickness:SetValue(CONFIG.GlowPixelThickness or 1, true)
    controls.glow.groups.pixel.offsetX:SetValue(CONFIG.GlowPixelXOffset or -1, true)
    controls.glow.groups.pixel.offsetY:SetValue(CONFIG.GlowPixelYOffset or -1, true)
    controls.glow.groups.pixel.border:SetValue(CONFIG.GlowPixelBorder and true or false, true)
    controls.glow.groups.autocast.particles:SetValue(CONFIG.GlowAutoCastParticles or 10, true)
    controls.glow.groups.autocast.frequency:SetValue(CONFIG.GlowAutoCastFrequency or 0.25, true)
    controls.glow.groups.autocast.scale:SetValue(CONFIG.GlowAutoCastScale or 1, true)
    controls.glow.groups.autocast.offsetX:SetValue(CONFIG.GlowAutoCastXOffset or -1, true)
    controls.glow.groups.autocast.offsetY:SetValue(CONFIG.GlowAutoCastYOffset or -1, true)
    controls.glow.groups.proc.duration:SetValue(CONFIG.GlowProcDuration or 1, true)
    controls.glow.groups.proc.offsetX:SetValue(CONFIG.GlowProcXOffset or 0, true)
    controls.glow.groups.proc.offsetY:SetValue(CONFIG.GlowProcYOffset or 0, true)
    controls.glow.groups.proc.startAnim:SetValue(CONFIG.GlowProcStartAnim and true or false, true)
end

local function CreateModernMenu()
    if state.quickMenu then
        return state.quickMenu
    end

    local frame = CreateFrame("Frame", "CDMKeyPressOptionsFrame", UIParent, "BackdropTemplate")
    frame:SetSize(840, 560)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("HIGH")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()
    table.insert(UISpecialFrames, "CDMKeyPressOptionsFrame")

    ApplyBackdrop(frame, UI_STYLE.frame, UI_STYLE.border)

    frame.Header = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    frame.Header:SetPoint("TOPLEFT")
    frame.Header:SetPoint("TOPRIGHT")
    frame.Header:SetHeight(70)
    ApplyBackdrop(frame.Header, UI_STYLE.header, UI_STYLE.border)

    frame.HeaderIcon = frame.Header:CreateTexture(nil, "ARTWORK")
    frame.HeaderIcon:SetSize(40, 40)
    frame.HeaderIcon:SetPoint("TOPLEFT", 18, -15)
    frame.HeaderIcon:SetTexture(ICON_TEXTURE_PATH)

    frame.Title = frame.Header:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.Title:SetPoint("LEFT", frame.HeaderIcon, "RIGHT", 12, 0)
    frame.Title:SetText("CDM KeyPress")
    SetTextColor(frame.Title, UI_STYLE.text)

    frame.Close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    frame.Close:SetPoint("TOPRIGHT", 4, 4)

    frame.Sidebar = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    frame.Sidebar:SetPoint("TOPLEFT", frame.Header, "BOTTOMLEFT", 0, 0)
    frame.Sidebar:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    frame.Sidebar:SetWidth(184)
    ApplyBackdrop(frame.Sidebar, UI_STYLE.sidebar, UI_STYLE.border)

    frame.Content = CreateFrame("Frame", nil, frame)
    frame.Content:SetPoint("TOPLEFT", frame.Sidebar, "TOPRIGHT", 18, -18)
    frame.Content:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -18, 18)

    frame.controls = {
        navButtons = {},
        overview = {},
        glow = {},
    }
    frame.pages = {}

    local navDefinitions = {
        { key = "overview", label = "Overview", subtitle = "Status and quick actions" },
        { key = "glow", label = GetSettingsTabLabel(), subtitle = GetSettingsTabSubtitle() },
    }

    local previousButton
    for _, definition in ipairs(navDefinitions) do
        local button = CreateSidebarButton(frame.Sidebar, definition.label, definition.subtitle, function()
            SelectQuickMenuPage(definition.key)
            RefreshModernMenu()
        end)
        if previousButton then
            button:SetPoint("TOPLEFT", previousButton, "BOTTOMLEFT", 0, -8)
        else
            button:SetPoint("TOPLEFT", 12, -18)
        end
        previousButton = button
        frame.controls.navButtons[definition.key] = button
    end

    frame.pages.overview = BuildOverviewPage(frame, frame.Content)
    frame.pages.glow = BuildGlowPage(frame, frame.Content)

    frame.currentPage = "overview"
    SelectQuickMenuPage("overview")
    state.quickMenu = frame
    RefreshModernMenu()
    return state.quickMenu
end

local function EnsureModernMinimapButton()
    if state.minimapButton or not Minimap then
        return state.minimapButton
    end

    local button = CreateFrame("Button", "CDMKeyPressMinimapButton", Minimap)
    button:SetSize(32, 32)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    button:SetPushedTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:SetPoint("TOPLEFT", Minimap, "TOPLEFT", -6, 6)

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(30, 30)
    icon:SetPoint("CENTER", 0, 0)
    icon:SetTexture(ICON_TEXTURE_PATH)
    button.icon = icon

    button:SetScript("OnClick", function(_, mouseButton)
        if mouseButton == "RightButton" then
            Private.RunScanNow("minimap")
            return
        end
        if Private.ToggleQuickMenu then
            Private.ToggleQuickMenu()
        end
    end)

    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("CDM KeyPress", 1, 1, 1)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Left Click: Menu", 1, 1, 1)
        GameTooltip:AddLine("Right Click: Scan", 1, 1, 1)
        GameTooltip:Show()
    end)

    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    state.minimapButton = button
    return button
end

Private.CreateModernMenu = CreateModernMenu
Private.RefreshModernMenu = RefreshModernMenu
Private.SelectModernMenuPage = SelectQuickMenuPage
Private.EnsureModernMinimapButton = EnsureModernMinimapButton
