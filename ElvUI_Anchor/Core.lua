local E, L, V, P, G = unpack(ElvUI)
local MyMod = E:NewModule('ElvUI_Anchor', 'AceEvent-3.0', 'AceHook-3.0')
local EP = LibStub("LibElvUIPlugin-1.0")

-- Localization for performance
local _G = _G
local pairs = pairs
local InCombatLockdown = InCombatLockdown
local lastEWidth, lastUWidth = 0, 0

-- Static tables to prevent memory bloat
local UNIT_LIST = { ["Player"] = "player", ["Target"] = "target", ["Focus"] = "focus", ["Pet"] = "pet", ["TargetTarget"] = "tot" }
local CAST_LIST = { ["Player"] = "playerCast", ["Target"] = "targetCast", ["Focus"] = "focusCast" }
local POWER_LIST = { ["Player"] = "playerPower", ["Target"] = "targetPower" }

-- 1. Full Settings
P['ElvUI_Anchor'] = {
    ['enabled'] = true,
    ['playerEnabled'] = true, ['playerParent'] = "EssentialCooldownViewer", ['playerPoint'] = "RIGHT", ['playerRelative'] = "LEFT", ['playerX'] = -20, ['playerY'] = 0,
    ['playerCastEnabled'] = true, ['playerCastParent'] = "ElvUF_Player", ['playerCastPoint'] = "CENTER", ['playerCastRelative'] = "BOTTOM", ['playerCastX'] = 0, ['playerCastY'] = -30,
    ['targetEnabled'] = true, ['targetParent'] = "EssentialCooldownViewer", ['targetPoint'] = "LEFT", ['targetRelative'] = "RIGHT", ['targetX'] = 20, ['targetY'] = 0,
    ['targetCastEnabled'] = true, ['targetCastParent'] = "ElvUF_Target", ['targetCastPoint'] = "CENTER", ['targetCastRelative'] = "BOTTOM", ['targetCastX'] = 0, ['targetCastY'] = -30,
    ['focusEnabled'] = true, ['focusParent'] = "UIParent", ['focusPoint'] = "CENTER", ['focusRelative'] = "CENTER", ['focusX'] = 0, ['focusY'] = -100,
    ['focusCastEnabled'] = true, ['focusCastParent'] = "ElvUF_Focus", ['focusCastPoint'] = "CENTER", ['focusCastRelative'] = "BOTTOM", ['focusCastX'] = 0, ['focusCastY'] = -30,
    ['playerPowerEnabled'] = true, ['playerPowerParent'] = "ElvUF_Player", ['playerPowerPoint'] = "CENTER", ['playerPowerRelative'] = "BOTTOM", ['playerPowerX'] = 0, ['playerPowerY'] = -5,
    ['targetPowerEnabled'] = true, ['targetPowerParent'] = "ElvUF_Target", ['targetPowerPoint'] = "CENTER", ['targetPowerRelative'] = "BOTTOM", ['targetPowerX'] = 0, ['targetPowerY'] = -5,
    ['petEnabled'] = true, ['petParent'] = "ElvUF_Player", ['petPoint'] = "CENTER", ['petRelative'] = "BOTTOM", ['petX'] = 0, ['petY'] = -10,
    ['totEnabled'] = true, ['totParent'] = "ElvUF_Target", ['totPoint'] = "CENTER", ['totRelative'] = "RIGHT", ['totX'] = 10, ['totY'] = 0,
}

local function IsPowerDetached(unit)
    if not (E.db.unitframe and E.db.unitframe.units and E.db.unitframe.units[unit]) then return false end
    local db = E.db.unitframe.units[unit]
    return db and db.power and db.power.detachFromFrame == true
end

-- 2. Optimized Collision Logic
local function GetHorizontalCollisionOffset(dbPrefix)
    local essential = _G["EssentialCooldownViewer"]
    local utility = _G["UtilityCooldownViewer"]
    local baseUX = E.db.ElvUI_Anchor[dbPrefix.."X"] or 0
    
    if not (essential and utility) then return baseUX end
    
    local eWidth, uWidth = essential:GetWidth(), utility:GetWidth()
    
    if uWidth > eWidth then
        local extraWidth = (uWidth - eWidth) / 2
        return (dbPrefix == "player") and (baseUX - extraWidth) or (baseUX + extraWidth)
    end
    return baseUX
end

function MyMod:UpdateLayout(force)
    -- CRITICAL: Prevent execution during combat to avoid ADDON_ACTION_BLOCKED
    if InCombatLockdown() or not E.db.ElvUI_Anchor.enabled then return end

    local essential = _G["EssentialCooldownViewer"]
    local utility = _G["UtilityCooldownViewer"]
    
    local eW = essential and essential:GetWidth() or 0
    local uW = utility and utility:GetWidth() or 0
    
    if not force and eW == lastEWidth and uW == lastUWidth then return end
    lastEWidth, lastUWidth = eW, uW

    -- Unit Frames
    for frameName, db in pairs(UNIT_LIST) do
        local uf = _G["ElvUF_"..frameName]
        if uf and E.db.ElvUI_Anchor[db.."Enabled"] then
            local parentName = E.db.ElvUI_Anchor[db.."Parent"]
            local parent = _G[parentName] or E.UIParent 
            local x = E.db.ElvUI_Anchor[db.."X"]
            local y = E.db.ElvUI_Anchor[db.."Y"]

            if parentName == "EssentialCooldownViewer" and (db == "player" or db == "target") then
                x = GetHorizontalCollisionOffset(db)
            end

            uf:ClearAllPoints()
            uf:SetPoint(E.db.ElvUI_Anchor[db.."Point"], parent, E.db.ElvUI_Anchor[db.."Relative"], x, y)
            
            local mover = _G["ElvUF_"..frameName.."Mover"]
            if mover then mover:ClearAllPoints(); mover:SetPoint(E.db.ElvUI_Anchor[db.."Point"], parent, E.db.ElvUI_Anchor[db.."Relative"], x, y) end
        end
    end

    -- Castbars
    for unit, dbPrefix in pairs(CAST_LIST) do
        local uf = _G["ElvUF_"..unit]
        if uf and uf.Castbar and E.db.ElvUI_Anchor[dbPrefix.."Enabled"] then
            local tc = uf.Castbar
            local parent = _G[E.db.ElvUI_Anchor[dbPrefix.."Parent"]] or uf
            tc:ClearAllPoints()
            tc:SetPoint(E.db.ElvUI_Anchor[dbPrefix.."Point"], parent, E.db.ElvUI_Anchor[dbPrefix.."Relative"], E.db.ElvUI_Anchor[dbPrefix.."X"], E.db.ElvUI_Anchor[dbPrefix.."Y"])
            local tcMover = _G[unit.." CastbarMover"]
            if tcMover then tcMover:ClearAllPoints(); tcMover:SetPoint(E.db.ElvUI_Anchor[dbPrefix.."Point"], parent, E.db.ElvUI_Anchor[dbPrefix.."Relative"], E.db.ElvUI_Anchor[dbPrefix.."X"], E.db.ElvUI_Anchor[dbPrefix.."Y"]) end
        end
    end

    -- Powerbars
    for unit, dbPrefix in pairs(POWER_LIST) do
        local uf = _G["ElvUF_"..unit]
        if uf and uf.Power and IsPowerDetached(unit:lower()) and E.db.ElvUI_Anchor[dbPrefix.."Enabled"] then
            local pb = uf.Power
            local parent = _G[E.db.ElvUI_Anchor[dbPrefix.."Parent"]] or uf
            pb:ClearAllPoints()
            pb:SetPoint(E.db.ElvUI_Anchor[dbPrefix.."Point"], parent, E.db.ElvUI_Anchor[dbPrefix.."Relative"], E.db.ElvUI_Anchor[dbPrefix.."X"], E.db.ElvUI_Anchor[dbPrefix.."Y"])
            local pbMover = _G[unit.." PowerbarMover"]
            if pbMover then pbMover:ClearAllPoints(); pbMover:SetPoint(E.db.ElvUI_Anchor[dbPrefix.."Point"], parent, E.db.ElvUI_Anchor[dbPrefix.."Relative"], E.db.ElvUI_Anchor[dbPrefix.."X"], E.db.ElvUI_Anchor[dbPrefix.."Y"]) end
        end
    end
end

-- 3. Options Menu
function MyMod:InsertOptions()
    local frameValues = { ["UIParent"] = "Screen Center", ["ElvUF_Player"] = "Player Frame", ["ElvUF_Target"] = "Target Frame", ["ElvUF_Focus"] = "Focus Frame", ["EssentialCooldownViewer"] = "Essential CDs" }
    local pointValues = { ["TOP"]="Top", ["BOTTOM"]="Bottom", ["LEFT"]="Left", ["RIGHT"]="Right", ["CENTER"]="Center", ["TOPLEFT"]="Top Left", ["TOPRIGHT"]="Top Right", ["BOTTOMLEFT"]="Bottom Left", ["BOTTOMRIGHT"]="Bottom Right" }
    local fullHint = "|cffFFD100Hint:|r Because of the way ElvUI handles the castbar icon, I recommend anchoring from the side opposite the icon."

    local function CreateInlineAnchorGroup(name, dbPrefix, order, ownerFrame, isSubElement, isCastbar, unitForPowerCheck)
        return {
            order = order, type = "group", name = name, guiInline = true,
            args = {
                warning = {
                    order = 0, type = "description", 
                    name = function()
                        if unitForPowerCheck and not IsPowerDetached(unitForPowerCheck) then
                            return "\n|cffFF0000Warning:|r Enable 'Detach From Frame' in ElvUI Power settings."
                        end
                        return ""
                    end,
                    hidden = function() return not unitForPowerCheck or IsPowerDetached(unitForPowerCheck) end,
                },
                enabled = { order = 1, type = "toggle", name = "Enable", get = function(i) return E.db.ElvUI_Anchor[dbPrefix.."Enabled"] end, set = function(i,v) E.db.ElvUI_Anchor[dbPrefix.."Enabled"]=v; MyMod:UpdateLayout(true) end },
                hintBox = isCastbar and {
                    order = 2, type = "group", name = "", guiInline = true,
                    args = { text = { order = 1, type = "description", name = fullHint } },
                } or nil,
                parent = { order = 3, type = "select", name = "Anchor Frame to :", values = frameValues, get = function(i) return E.db.ElvUI_Anchor[dbPrefix.."Parent"] end, set = function(i,v) E.db.ElvUI_Anchor[dbPrefix.."Parent"]=v; MyMod:UpdateLayout(true) end },
                point = { order = 4, type = "select", name = "Anchor from :", values = pointValues, get = function(i) return E.db.ElvUI_Anchor[dbPrefix.."Point"] end, set = function(i,v) E.db.ElvUI_Anchor[dbPrefix.."Point"]=v; MyMod:UpdateLayout(true) end },
                relative = { order = 5, type = "select", name = "Anchor to :", values = pointValues, get = function(i) return E.db.ElvUI_Anchor[dbPrefix.."Relative"] end, set = function(i,v) E.db.ElvUI_Anchor[dbPrefix.."Relative"]=v; MyMod:UpdateLayout(true) end },
                x = { order = 6, type = "range", name = "X", min=-500, max=500, step=1, get = function(i) return E.db.ElvUI_Anchor[dbPrefix.."X"] end, set = function(i,v) E.db.ElvUI_Anchor[dbPrefix.."X"]=v; MyMod:UpdateLayout(true) end },
                y = { order = 7, type = "range", name = "Y", min=-500, max=500, step=1, get = function(i) return E.db.ElvUI_Anchor[dbPrefix.."Y"] end, set = function(i,v) E.db.ElvUI_Anchor[dbPrefix.."Y"]=v; MyMod:UpdateLayout(true) end },
            }
        }
    end

    E.Options.args.ElvUI_Anchor = {
        type = "group", name = "ElvUI Anchor", childGroups = "tab",
        args = {
            changelog = {
                order = 0,
                type = "execute",
                name = "Show Changelog",
                func = function() MyMod:ShowChangelog() end,
            },
            player = { order = 1, type = "group", name = "Player", args = { frame = CreateInlineAnchorGroup("Player Frame", "player", 1, "ElvUF_Player", false), castbar = CreateInlineAnchorGroup("Player Castbar", "playerCast", 2, "ElvUF_Player", true, true) } },
            target = { order = 2, type = "group", name = "Target", args = { frame = CreateInlineAnchorGroup("Target Frame", "target", 1, "ElvUF_Target", false), castbar = CreateInlineAnchorGroup("Target Castbar", "targetCast", 2, "ElvUF_Target", true, true) } },
            focus = { order = 3, type = "group", name = "Focus", args = { frame = CreateInlineAnchorGroup("Focus Frame", "focus", 1, "ElvUF_Focus", false), castbar = CreateInlineAnchorGroup("Focus Castbar", "focusCast", 2, "ElvUF_Focus", true, true) } },
            power = { order = 4, type = "group", name = "Power Bars", args = { playerPower = CreateInlineAnchorGroup("Player Power", "playerPower", 1, "ElvUF_Player", true, false, "player"), targetPower = CreateInlineAnchorGroup("Target Power", "targetPower", 2, "ElvUF_Target", true, false, "target") } },
            pet = { order = 5, type = "group", name = "Pet", args = { frame = CreateInlineAnchorGroup("Pet Frame", "pet", 1, "ElvUF_Pet", false) } },
            tot = { order = 6, type = "group", name = "Target of Target", args = { frame = CreateInlineAnchorGroup("ToT Frame", "tot", 1, "ElvUF_TargetTarget", false) } },
        }
    }
end

function MyMod:Initialize()
    EP:RegisterPlugin('ElvUI_Anchor', function() MyMod:InsertOptions() end)
    
    local frame = CreateFrame("Frame")
    -- Register to catch updates missed during combat
    frame:RegisterEvent("PLAYER_REGEN_ENABLED")
    
    frame:SetScript("OnEvent", function(self, event)
        if event == "PLAYER_REGEN_ENABLED" then
            MyMod:UpdateLayout(true)
        end
    end)

    frame:SetScript("OnUpdate", function(self, elapsed)
        -- Skip calculations entirely if in combat
        if InCombatLockdown() then return end

        self.timer = (self.timer or 0) + elapsed
        if self.timer >= 0.05 then 
            MyMod:UpdateLayout()
            self.timer = 0
        end
    end)
end

E:RegisterModule(MyMod:GetName())