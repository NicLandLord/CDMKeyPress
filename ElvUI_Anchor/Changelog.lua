local E, L, V, P, G = unpack(ElvUI)
local S = E:GetModule('Skins')
local MyMod = E:GetModule('ElvUI_Anchor')

function MyMod:ShowChangelog()
    -- Create the Main Window
    local f = CreateFrame("Frame", "ElvUI_Anchor_Changelog", E.UIParent)
    f:SetSize(500, 350) -- Reduced height as requested
    f:SetPoint("CENTER")
    f:SetFrameStrata("HIGH")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:CreateBackdrop("Transparent")

    -- Title
    f.title = f:CreateFontString(nil, "OVERLAY")
    f.title:FontTemplate(nil, 20, "OUTLINE")
    f.title:SetPoint("TOP", 0, -10)
    f.title:SetText("|cff1784d1ElvUI|r Anchor - Changelog")

    -- Content Scroll Frame
    local sf = CreateFrame("ScrollFrame", "ElvUI_Anchor_ChangelogScrollFrame", f, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", 15, -45)
    sf:SetPoint("BOTTOMRIGHT", -35, 45)
    
    local scrollbar = _G["ElvUI_Anchor_ChangelogScrollFrameScrollBar"]
    S:HandleScrollBar(scrollbar)
    
    -- Logic to only show scrollbar if content is larger than view
    scrollbar:SetAlpha(0) 
    sf:SetScript("OnUpdate", function(self)
        local _, max = scrollbar:GetMinMaxValues()
        if max > 0 then
            scrollbar:SetAlpha(1)
        else
            scrollbar:SetAlpha(0)
        end
    end)

    local content = CreateFrame("Frame", nil, sf)
    content:SetSize(440, 1000)
    sf:SetScrollChild(content)

    f.text = content:CreateFontString(nil, "OVERLAY")
    f.text:FontTemplate(nil, 14)
    f.text:SetPoint("TOPLEFT", 5, -5)
    f.text:SetJustifyH("LEFT")
    f.text:SetWidth(430)
    f.text:SetText([[
|cffFFD100v1.4 |r
|cff1784d1Bug Fixes|r
- Reverted to older stable version

]])

    content:SetHeight(f.text:GetStringHeight() + 20)

    -- Close Button
    local close = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    close:SetSize(100, 25)
    close:SetPoint("BOTTOM", 0, 10)
    close:SetText("Close")
    close:SetScript("OnClick", function() f:Hide() end)
    S:HandleButton(close)
end

-- Version Check logic for 1.3.1
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
initFrame:SetScript("OnEvent", function()
    local currentVersion = "1.3.1"
    if ElvUI_Anchor_Version ~= currentVersion then
        E:Delay(5, function() MyMod:ShowChangelog() end) 
        ElvUI_Anchor_Version = currentVersion
    end
end)