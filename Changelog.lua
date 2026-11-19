local addonName, namespace = ...
local addon = LibStub("AceAddon-3.0"):GetAddon("RaidGroupManager")
local controller

function addon:InitializeChangelog()
    local release = CopyTable(namespace.ReleaseNotes)
    release.highlights = namespace.ChangelogHighlights[release.version] or {}

    controller = LibStub("LibChangelog-1.0"):Register(addonName, {
        displayName = "Raid Group Manager",
        release = release,
        -- Read status and notice preferences are shared across characters/profiles.
        storage = {
            get = function(key)
                return self.db.global.changelog[key]
            end,
            set = function(key, value)
                self.db.global.changelog[key] = value
            end,
        },
    })

    local page = controller:CreateSettingsPage({
        measurementFrame = SettingsPanel:GetSettingsCanvas(),
    })
    local category =
        Settings.RegisterCanvasLayoutCategory(page, "Raid Group Manager")
    Settings.RegisterAddOnCategory(category)
end

function addon:ShowChangelog()
    local shown, reason = controller:Show()
    if shown then return end

    local message = reason == "batch-open"
            and "Close the current update window or use /changelog to browse all addon updates."
        or "Update notes are available after combat, loading, cinematics, and ready checks."
    self:Print(message)
end
