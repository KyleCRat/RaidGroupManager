local addon = LibStub("AceAddon-3.0"):GetAddon("RaidGroupManager")

function addon:SetupMinimapButton()
    local LDB = LibStub("LibDataBroker-1.1")
    local LDBIcon = LibStub("LibDBIcon-1.0")

    local dataObject = LDB:NewDataObject("RaidGroupManager", {
        type = "launcher",
        icon = "Interface\\Icons\\Achievement_General_StayClassy",
        OnClick = function(_, button)
            if button == "LeftButton" then
                addon:ToggleMainFrame()
            end
        end,
        OnTooltipShow = function(tooltip)
            tooltip:AddLine("Raid Group Manager")
            tooltip:AddLine("|cffffffffLeft-click|r to toggle window", 0.8, 0.8, 0.8)
        end,
    })

    LDBIcon:Register("RaidGroupManager", dataObject, self.db.profile.minimap)
end
