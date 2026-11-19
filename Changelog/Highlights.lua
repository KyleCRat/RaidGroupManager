local _, namespace = ...

namespace.ChangelogHighlights = {
    Unreleased = {
        {
            title = "Faster, confirmed group moves",
            body = "Apply now advances as each move is confirmed, including bench groups."
                .. " It stops if a move cannot be confirmed and checks the final player order.",
            emphasis = "featured",
        },
        {
            title = "Fewer inspections",
            body = "RGM uses assigned roles and class rules when they are enough to identify a role."
                .. " Cached specs survive reloads, with slower background refreshes for uncertain roles.",
        },
        {
            title = "Save assistant choices from Guild rows",
            body = "Middle-click members in the Guild or Roster tab to save who should be assistant."
                .. " Those choices are applied when you lead the raid; live assistant changes remain separate.",
        },
    },
}
